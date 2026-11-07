-- Native companion scenario, executed by people_integration.lua in the same isolated Services/UIHost.
-- Uses the real contact/command/session/recruitment path. Coins, battle facts and leader experience are
-- fixture prerequisites only; this check does not claim to validate battle victory progression.
local main=require('Main')
local adventure,story,ui=main:Get('Adventure'),main:Get('Narrative'),main:Get('UI')
local roster=CS.ProjectY.Data.PartyRoster
local combatEquipment=CS.ProjectY.Data.EquipmentCombatState
local Life=require('Game.Battle.ActorLife')
local notes={}
local function passed(message)notes[#notes+1]='PASS '..message end
local ok,err=xpcall(function()
    assert(not Services.UI.IsWorldPaused and not story.data.DialogueOpen)
    adventure:Start(815,1,2500)
    local data,parties=adventure.data,adventure.parties
    local world,travel,bag=parties.data,adventure.travel.data,adventure.equipment.data
    assert(data.Phase=='map' and not travel.Active and not world.IsOpen)
    local targetParty,targetActor
    -- Find an actual equipped human in a hostile non-legendary party with survivors left after transfer.
    -- Moving only the player preserves the enemy's real roster, travel state, equipment and faction.
    for index=0,world.Count-1 do
        local candidate=world:GetAt(index)
        if not candidate.Defeated and candidate.Role~='garrison' and candidate.Mission~='occupy' and
            candidate.Travel.Progress==0 and adventure.people:CanParley(candidate) and
            adventure.factions:Relation(0,candidate.FactionId)=='hostile' then
            local actor
            for member=0,candidate.MemberCount-1 do local current=candidate:GetMemberAt(member)
                if Life.Alive(current) and adventure.battle.stats:Template(current).bodyInjuries and
                    current.AnimalSpeciesId==0 and combatEquipment.IsInitialized(bag,current.Id) and bag:Equipped(current.Id) then actor=current;break end
            end
            if actor then
                travel:Relocate(candidate.Travel.Q,candidate.Travel.R)
                local earlierContact=false
                for previous=0,index-1 do local other=world:GetAt(previous)
                    if not other.Defeated and other.Role~='garrison' and other.Mission~='occupy' and other.BattleSiteId==0 and
                        adventure.factions:Relation(0,other.FactionId)=='hostile' and world.Clock>=other.SafeUntil and parties:Near(other)then
                        earlierContact=true;break
                    end
                end
                if not earlierContact and parties:Near(candidate)then targetParty,targetActor=candidate,actor;break end
            end
        end
    end
    assert(targetParty and targetActor,'Fixed seed must contain a contactable equipped multi-member human hostile party')
    local partyId,actorId=targetParty.Id,targetActor.Id
    local beforeMembers,beforeLiving=targetParty.MemberCount,targetParty.LivingCount
    local originalMembers={}
    for index=0,beforeMembers-1 do local member=targetParty:GetMemberAt(index);originalMembers[member.Id]=member end
    local weapons,wearables={},{}
    for index=0,bag.WeaponCount-1 do local item=bag:GetWeaponAt(index)
        if item.OwnerActorId==actorId then weapons[#weapons+1]={item=item,id=item.Id,hand=item.Hand,magazine=item.MagazineId}end
    end
    for index=0,bag.WearableCount-1 do local item=bag:GetWearableAt(index)
        if item.OwnerActorId==actorId then wearables[#wearables+1]={item=item,id=item.Id,slot=item.Slot}end
    end
    assert(#weapons>0)
    local weaponCount,wearableCount=bag.WeaponCount,bag.WearableCount
    local initialTemplate=targetActor.TemplateId
    -- Target is deliberately established before the real CheckContact; Open clears it inside that call.
    world:Target(partyId);assert(world.TargetId==partyId)
    assert(parties:CheckContact())
    assert(data.Phase=='map' and world.IsOpen and world.ContactId==partyId and world.TargetId==0,
        'Pursued hostile humans must offer parley even though native Open clears TargetId')
    assert(targetParty.BattleSiteId==0 and not story.data.DialogueOpen and travel.Paused)
    local snapshot=parties:ContactSnapshot();local offered=false
    for _,row in ipairs(snapshot.rows)do if row.command=='world_person' and row.id==actorId then offered=row.available end end
    assert(offered,'Actual contact rows must expose the selected human')
    passed('real targeted CheckContact opens hostile-human parley, clears TargetId without starting battle, and exposes the human row')

    local worldPanel=ui:Open('WorldParty',{demo=PeopleNativeDemo})
    assert(worldPanel.visible and Services.UI.IsWorldPaused)
    local stale=world.Revision-1
    assert(not parties:Command('world_person',actorId,stale),'Stale native world-contact choice must be rejected')
    assert(world.IsOpen and not story.data.DialogueOpen)
    local opened,why=parties:Command('world_person',actorId,world.Revision);assert(opened,why)
    assert(not world.IsOpen and world.ContactId==0 and story.data.DialogueOpen and story.data.DialogueLocalNpcId==partyId,
        'WorldParty.Close clears ContactId, so the person session must retain the validated source party')
    local person=assert(adventure.people:ForActor(targetActor));local key=person.Key
    local initialHP=targetActor.HP
    assert(person.Actor==targetActor and person.OriginKind=='world' and not person.Joined and person.Known)
    assert(CS.ProjectY.Data.PeopleDialogueSession.Key(story.data)==key and adventure.peopleDialogue:CanContinue())
    local inspected=assert(adventure.inspection.targets:Find(key),'The active session must keep its real world target inspectable')
    assert(inspected.actor==targetActor and not inspected.owned)
    -- The production sync order closes WorldParty before opening Dialogue; neither panel replaces game state.
    ui:Close('WorldParty')
    assert(story.data.DialogueOpen and story.data.DialogueLocalNpcId==partyId)
    local dialogue=ui:Open('Dialogue',{demo=PeopleNativeDemo})
    assert(ui:IsOpen('Dialogue') and Services.UI.IsWorldPaused and dialogue.view.Title.text==adventure.people:Name(person))
    assert(story.dialogue:Choose(10,story.data.DialogueVersion),'Background remains callable after ContactId was cleared')
    passed('real world_person command rejects stale revisions, survives ContactId reset, retains inspection access, and transfers modal presentation to Dialogue')

    adventure.player:AddCoins(500)
    story.data:SetValue('flag:people_victories',2)
    local leader=data:GetPartyAt(0)
    for _=1,adventure.growth.rules.maxLevel do
        if leader.Growth.Level>=targetActor.Growth.Level then break end
        local nextLevel=adventure.growth.rules.levels:Get(leader.Growth.Level+1)
        adventure.growth:AddExperience(leader,math.max(1,nextLevel.experience-leader.Growth.Experience),'Native world-parley prerequisite')
    end
    assert(leader.Growth.Level>=targetActor.Growth.Level)
    local hire
    for _,row in ipairs(adventure.peopleDialogue:Choices())do if row.id==101 then hire=row end end
    assert(hire and hire.available,hire and hire.reason or 'Missing battle-respect recruitment route')
    local coins,beforeRoster=adventure.player.Coins,roster.Count(data)
    local fee=adventure.people.rules.profiles:Get(person.ProfileId).fee
    local oldVersion=story.data.DialogueVersion
    assert(story.dialogue:Choose(hire.id,oldVersion))
    assert(person.Joined and person.Actor==targetActor and roster.Find(data,actorId)==targetActor and roster.Count(data)==beforeRoster+1)
    assert(targetActor.Team==1 and targetActor.TemplateId==initialTemplate and targetActor.HP==initialHP)
    assert(targetParty.MemberCount==beforeMembers-1 and targetParty.LivingCount==beforeLiving-1 and not targetParty.Defeated)
    assert(targetParty.StrengthReady and targetParty.StrategicPower>0,'Remaining party strengths must retain their member alignment')
    local remaining={}
    for index=0,targetParty.MemberCount-1 do local member=targetParty:GetMemberAt(index)
        assert(member.Id~=actorId and originalMembers[member.Id]==member,'Only the recruited member may leave the original world party')
        remaining[member.Id]=true
    end
    for id in pairs(originalMembers)do assert(id==actorId or remaining[id],'A second original member disappeared')end
    assert(bag.WeaponCount==weaponCount and bag.WearableCount==wearableCount)
    for _,row in ipairs(weapons)do
        assert(bag:GetWeapon(row.id)==row.item and row.item.OwnerActorId==actorId and row.item.Hand==row.hand and row.item.MagazineId==row.magazine)
    end
    for _,row in ipairs(wearables)do
        assert(bag:Worn(actorId,row.slot)==row.item and row.item.Id==row.id and row.item.OwnerActorId==actorId)
    end
    assert(not combatEquipment.IsInitialized(bag,actorId),'Joined equipment must leave temporary combat-owner cleanup')
    assert(adventure.player.Coins==coins-fee)
    assert(not story.dialogue:Choose(hire.id,oldVersion) and adventure.player.Coins==coins-fee and targetParty.MemberCount==beforeMembers-1)
    assert(adventure.peopleDialogue:CanContinue(),'Joined people remain callable after leaving the source roster')
    dialogue:Refresh()
    ui:Close('Dialogue')
    assert(not story.data.DialogueOpen and story.data.DialogueLocalNpcId==0 and not ui:IsOpen('WorldParty') and not ui:IsOpen('Dialogue'))
    assert(not Services.UI.IsWorldPaused and not PeopleNativeInputOpen() and not world.IsOpen and world.ContactId==0)
    assert(travel.Paused,'Closing a parley must not silently resume travel into the remaining hostile party')
    local details=ui:Open('UnitDetails',{demo=PeopleNativeDemo,key=key})
    assert(details.view.Talk.interactable and details.view.TalkText.DefaultText==require('Language').PeopleDialogueTalkOwned)
    ui:Close('UnitDetails');assert(not Services.UI.IsWorldPaused and not PeopleNativeInputOpen())
    passed('dialogue recruitment transfers the original actor and all equipment once, preserves remaining world members/strength, and releases modal/input state')
end,debug.traceback)
for _,name in ipairs({'UnitDetails','Dialogue','WorldParty'})do if ui:IsOpen(name)then ui:Close(name)end end
if not ok then error(err,0)end
return table.concat(notes,'\n')
