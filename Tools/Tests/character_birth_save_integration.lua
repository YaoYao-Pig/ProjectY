-- Host: isolated FrameworkServices with an unused explicit save path under the OS temp directory.
-- Host must inject CheckBirthLegacy(service,data,player). That callback constructs a separate template-mode
-- party-only fixture with an explicit empty profession-1 snapshot, saves v25, structurally changes its JSON
-- to v23 and removes initialAttributes/professionAttributes, then checks Prepare preserves template values,
-- Growth profession, correctly calculated HP, and restores the old profession as an assigned zero-bonus snapshot.
-- The callback must not change this script's live data or v26 file, and must throw on any failed assertion.
-- No Play, scene changes, user saves, or 12 repeated world generations. The host owns temporary-file cleanup.
local disk,path=CS.System.IO.File,CS.System.IO.Path
local service=assert(Services.CharacterSaves)
local savePath=service.FilePath
local function normalized(value)return value:gsub('\\','/'):lower()end
local tempRoot=normalized(path.GetFullPath(path.GetTempPath())):gsub('/+$','')..'/'
assert(normalized(path.GetFullPath(savePath)):sub(1,#tempRoot)==tempRoot,'Birth save regression requires an OS-temporary save path')
assert(not disk.Exists(savePath) and not disk.Exists(savePath..'.bak'),'Birth save fixture must use a fresh path')
assert(CheckBirthLegacy,'Host must provide the isolated, structurally edited legacy save check')

local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local closed=false
function CloseCharacterBirthSaveTesting()
    if closed then return end
    closed=true
    registry:Shutdown()
end
local messages={}
local function test(name,run)run();messages[#messages+1]='PASS '..name end
local function birthSnapshot(actor)
    local entries={}
    for i=0,actor.InitialAttributeCount-1 do
        local name=actor:GetInitialAttributeNameAt(i)
        entries[#entries+1]=name..'='..actor:GetInitialAttribute(name)
    end
    table.sort(entries)
    return tostring(actor.InitialAttributesAssigned)..':'..tostring(actor.HasInitialAttributes)..':'..
        actor.InitialProfessionId..':'..table.concat(entries,',')
end
local function professions(actor)
    local ids={}
    for i=0,actor.Growth.ProfessionCount-1 do ids[#ids+1]=actor.Growth:GetProfessionAt(i) end
    table.sort(ids)
    return actor.Growth.CurrentProfessionId..':'..table.concat(ids,',')
end
local function professionSnapshot(actor)
    local sets={}
    for i=0,actor.ProfessionAttributeSetCount-1 do
        local professionId=actor:GetProfessionAttributeProfessionAt(i)
        assert(actor:HasProfessionAttributes(professionId))
        local entries={}
        for j=0,actor:GetProfessionAttributeCount(professionId)-1 do
            local name=actor:GetProfessionAttributeNameAt(professionId,j)
            entries[#entries+1]=name..'='..actor:GetProfessionAttribute(professionId,name)
        end
        table.sort(entries)
        sets[#sets+1]=professionId..':{'..table.concat(entries,',')..'}'
    end
    table.sort(sets)
    return table.concat(sets,';')
end
local ok,err=xpcall(function()
    registry:Start()
    local adventure=registry:Get('Adventure')
    local config=registry:Get('Config')
    local birth=adventure.battle.stats.birth
    local growth=adventure.growth
    local data,player,inventory=adventure.data,adventure.player,adventure.equipment.data
    local save=require('Game.Adventure.CharacterSave')
    local expedition=require('Game.Adventure.ExpeditionSave')
    local primary={vitality=true,endurance=true,intellect=true,strength=true,speed=true,defense=true}
    local expectedOrigins={[1]=1,[2]=2,[3]=3,[4]=4,[7]=13}
    local function checkRanges(actor,professionId)
        assert(actor.InitialAttributesAssigned and actor.HasInitialAttributes and actor.InitialProfessionId==professionId)
        birth:Validate(actor)
        local unit=config:GetTable('CombatUnitTable'):Get(actor.TemplateId)
        local template={}
        for i,name in ipairs(unit.attributeNames)do template[name]=unit.attributeValues[i]end
        for _,name in ipairs(birth.names)do
            local value=actor:GetInitialAttribute(name)
            local minimum,maximum
            if primary[name]then
                minimum,maximum=2,6
            else
                minimum,maximum=math.max(0,(template[name] or 0)-1),(template[name] or 0)+1
            end
            assert(value==math.floor(value) and value>=minimum and value<=maximum,'Birth range mismatch: '..name)
        end
        assert(actor:HasProfessionAttributes(professionId),'Initial profession snapshot was not recorded')
        local modifier=professionId==12 and 'strength' or professionId==13 and 'speed' or nil
        assert(actor:GetProfessionAttributeCount(professionId)==(modifier and 1 or 0),'Profession modifier set differs from current config')
        for _,name in ipairs(birth.names)do
            local value=actor:GetProfessionAttribute(professionId,name)
            assert(value==math.floor(value) and value>=0 and value<=(name==modifier and 2 or 0),'Profession bonus range mismatch: '..name)
        end
    end

    test('one real default expedition creates farmer actors with stored bounded initial attributes',function()
        adventure:Start(815)
        assert(data.PartyCount==#adventure.recipe.partyIds,'Default expedition roster differs from its recipe')
        for i=0,data.PartyCount-1 do
            local actor=data:GetPartyAt(i)
            assert(actor.TemplateId==adventure.recipe.partyIds[i+1] and actor.Growth.CurrentProfessionId==12)
            checkRanges(actor,12)
        end
    end)

    test('same seed and stable actor ID reproduce the roll while a different ID changes it',function()
        local template=data:GetPartyAt(0).TemplateId
        local first=CS.ProjectY.Data.CombatActorData(90001,template)
        local repeatActor=CS.ProjectY.Data.CombatActorData(90001,template)
        local other=CS.ProjectY.Data.CombatActorData(90002,template)
        birth:Initialize(first,815,12);birth:Initialize(repeatActor,815,12);birth:Initialize(other,815,12)
        assert(birthSnapshot(first)==birthSnapshot(repeatActor) and professionSnapshot(first)==professionSnapshot(repeatActor),
            'Stable identity did not reproduce its initial and profession rolls')
        assert(birthSnapshot(first)~=birthSnapshot(other),'Distinct actor IDs unexpectedly share every rolled value')
        local before,beforeProfessions=birthSnapshot(first),professionSnapshot(first)
        birth:Initialize(first,999)
        birth:EnsureProfession(first,999,12)
        assert(birthSnapshot(first)==before and professionSnapshot(first)==beforeProfessions,'Already initialized actor or profession rerolled')
    end)

    test('all 12 configured opening leaders receive their approved profession and ordinary companions default to farmer',function()
        local starts=require('Game.Adventure.CampaignStarts').List(config)
        assert(#starts==12,'Expected the approved 12 opening configurations')
        local seen={}
        for _,profile in ipairs(starts)do
            assert(profile.id>=1 and profile.id<=12 and not seen[profile.id]);seen[profile.id]=true
            local expected=expectedOrigins[profile.id] or 12
            assert(profile.initialProfessionId==expected,'Opening profession mapping differs: '..profile.id)
            local recipe=config:GetTable('AdventureDemoTable'):Get(profile.adventureRecipeId)
            assert(#recipe.partyIds==3,'Campaign opening must retain its three-member roster')
            for index,template in ipairs(recipe.partyIds)do
                local actor=CS.ProjectY.Data.CombatActorData(index,template)
                growth:PrepareActor(actor,index==1 and profile.initialProfessionId or nil)
                local initial=index==1 and expected or 12
                assert(actor.Growth.CurrentProfessionId==initial and actor.Growth.ProfessionCount==1)
                checkRanges(actor,initial)
            end
        end
    end)

    test('only the current profession bonus applies, switching back reuses its roll, and noble cannot be added as a secondary profession',function()
        local actor=data:GetPartyAt(0)
        for i=0,data.PartyCount-1 do
            local candidate=data:GetPartyAt(i)
            if candidate:GetProfessionAttribute(12,'strength')>0 then actor=candidate;break end
        end
        local before=birthSnapshot(actor)
        local farmerBonus=actor:GetProfessionAttribute(12,'strength')
        local farmerStrength=adventure.battle.stats:Get(actor,'strength')
        local learning,talents,attributes=actor.Growth.PendingCount,actor.Growth.TalentPoints,actor.Growth.AttributePoints
        assert(growth:ChangeProfession(actor.Id,1))
        assert(actor.Growth.CurrentProfessionId==1 and actor.Growth:HasProfession(12) and actor.InitialProfessionId==12)
        assert(birthSnapshot(actor)==before)
        assert(actor:HasProfessionAttributes(1) and actor:GetProfessionAttributeCount(1)==0,'Warrior must record its zero-bonus snapshot')
        assert(actor:GetProfessionAttribute(12,'strength')==farmerBonus,'Joining another profession replaced the farmer roll')
        assert(adventure.battle.stats:Get(actor,'strength')==farmerStrength-farmerBonus,'Inactive farmer strength bonus still applies')
        local recordedProfessions=professionSnapshot(actor)
        local revision=actor.Growth.Revision
        local changed,reason=growth:ChangeProfession(actor.Id,13)
        assert(not changed and reason and reason~='' and not actor.Growth:HasProfession(13) and not actor:HasProfessionAttributes(13))
        assert(actor.Growth.Revision==revision and actor.Growth.CurrentProfessionId==1 and birthSnapshot(actor)==before and
            professionSnapshot(actor)==recordedProfessions)
        assert(growth:ChangeProfession(actor.Id,12))
        assert(actor.Growth.CurrentProfessionId==12 and adventure.battle.stats:Get(actor,'strength')==farmerStrength,
            'Returning to farmer did not restore the original strength bonus')
        assert(actor:GetProfessionAttribute(12,'strength')==farmerBonus and birthSnapshot(actor)==before and
            professionSnapshot(actor)==recordedProfessions,'Returning to a profession rerolled its result')
        assert(growth:ChangeProfession(actor.Id,1))
        assert(adventure.battle.stats:Get(actor,'strength')==farmerStrength-farmerBonus and birthSnapshot(actor)==before and
            professionSnapshot(actor)==recordedProfessions,'Repeated switches changed the stored results')
        assert(actor.Growth.PendingCount==learning and actor.Growth.TalentPoints==talents and actor.Growth.AttributePoints==attributes)
    end)

    local snapshots,worldSnapshots={},{}
    local retainedUnderqualifiedWeapon
    for i=0,data.PartyCount-1 do
        local actor=data:GetPartyAt(i)
        local values={}
        for _,name in ipairs(birth.names)do values[name]=adventure.battle.stats:Get(actor,name)end
        snapshots[actor.Id]={birth=birthSnapshot(actor),professionAttributes=professionSnapshot(actor),professions=professions(actor),
            hp=actor.HP,maximum=actor.MaxHP,values=values}
    end
    local liveParties=CS.ProjectY.Data.WorldPartiesData.For(data)
    for i=0,liveParties.Count-1 do
        local party=liveParties:GetAt(i)
        for j=0,party.MemberCount-1 do
            local actor=party:GetMemberAt(j)
            birth:Validate(actor)
            worldSnapshots[actor.Id]={birth=birthSnapshot(actor),professionAttributes=professionSnapshot(actor),hp=actor.HP,maximum=actor.MaxHP}
            if not retainedUnderqualifiedWeapon then
                for _,weapon in pairs({inventory:Equipped(actor.Id),inventory:Offhand(actor.Id)})do
                    local requirement=adventure.equipment.rules:Requirements(actor,weapon,adventure.battle.stats)
                    if requirement.missing>0 then
                        retainedUnderqualifiedWeapon={actor=actor,weapon=weapon}
                        break
                    end
                end
            end
        end
    end
    test('initial world loadouts retain underqualified weapons while manual equip checks and existing combat penalties remain active',function()
        local sample=assert(retainedUnderqualifiedWeapon,'Expected at least one real world member holding a weapon above its rolled attributes')
        local actor,weapon=sample.actor,sample.weapon
        assert(weapon.OwnerActorId==actor.Id and (inventory:Equipped(actor.Id)==weapon or inventory:Offhand(actor.Id)==weapon),
            'The underqualified starting weapon was not actually equipped')
        local rules,stats=adventure.equipment.rules,adventure.battle.stats
        local allowed,reason=rules:CanEquip(actor,weapon.ItemId,stats)
        assert(not allowed and reason and reason~='','Manual equipment requirements were bypassed')
        local requirement=rules:Requirements(actor,weapon,stats)
        assert(requirement.missing>0 and not requirement.met,'The retained weapon no longer has an unmet requirement')
        assert(requirement.damageScale<1 or requirement.hitLoss>0,'Underqualified weapon lost its existing damage or hit penalty')
    end)
    test('v26 disk preparation validates the complete world and restores base values, every profession snapshot, active stats and health',function()
        service:Save(data,player)
        local bytes=disk.ReadAllText(savePath)
        assert(bytes:find('"version":26',1,true),'Expected the complete v26 save format')
        local prepared=service:Prepare(inventory)
        save.Validate(adventure,prepared)
        local world=expedition.Prepare(adventure,prepared)
        assert(world and world.map and CS.ProjectY.Data.ExpeditionPersistence.HasWorld(prepared))
        assert(prepared.ActorCount==data.PartyCount)
        local restoredStats=require('Game.Battle.CombatStats')(config,prepared.Equipment)
        for i=0,prepared.ActorCount-1 do
            local actor=prepared:GetActorAt(i)
            local expected=assert(snapshots[actor.Id])
            assert(birthSnapshot(actor)==expected.birth and professionSnapshot(actor)==expected.professionAttributes and
                professions(actor)==expected.professions)
            assert(actor.HP==expected.hp and actor.MaxHP==expected.maximum)
            for name,value in pairs(expected.values)do assert(restoredStats:Get(actor,name)==value,'Restored attribute differs: '..name)end
        end
        local parties=CS.ProjectY.Data.WorldPartiesData.Prepared(prepared)
        local seen={}
        for i=0,parties.Count-1 do
            local party=parties:GetAt(i)
            for j=0,party.MemberCount-1 do
                local actor=party:GetMemberAt(j);local expected=assert(worldSnapshots[actor.Id])
                assert(not seen[actor.Id]);seen[actor.Id]=true
                assert(birthSnapshot(actor)==expected.birth and professionSnapshot(actor)==expected.professionAttributes and
                    actor.HP==expected.hp and actor.MaxHP==expected.maximum)
            end
        end
        for id in pairs(worldSnapshots)do assert(seen[id],'World-party member disappeared during preparation')end
        for i=0,data.PartyCount-1 do
            local actor=data:GetPartyAt(i);local expected=snapshots[actor.Id]
            assert(birthSnapshot(actor)==expected.birth and professionSnapshot(actor)==expected.professionAttributes)
        end
        assert(disk.ReadAllText(savePath)==bytes,'Preparing a save must not rewrite its source file')
    end)

    test('structurally migrated pre-birth save preserves original template values and records zero bonuses for existing professions',function()
        local bytes=disk.ReadAllText(savePath)
        CheckBirthLegacy(service,data,player)
        assert(service.FilePath==savePath and disk.ReadAllText(savePath)==bytes,'Legacy fixture must not overwrite the v26 source')
        for i=0,data.PartyCount-1 do
            local actor=data:GetPartyAt(i);local expected=snapshots[actor.Id]
            assert(birthSnapshot(actor)==expected.birth and professionSnapshot(actor)==expected.professionAttributes and
                professions(actor)==expected.professions)
            assert(actor.HP==expected.hp and actor.MaxHP==expected.maximum)
        end
    end)
end,debug.traceback)
CloseCharacterBirthSaveTesting()
if not ok then error(err)end
return table.concat(messages,'\n')
