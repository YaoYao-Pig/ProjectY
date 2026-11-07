-- Real FrameworkServices/Data and exported configuration, in the host's isolated LuaEnv.
-- The host must supply an explicit, unused characterSavePath beneath the OS temporary directory.
-- This script never starts an Editor/Player, exports configuration, or accesses the user's save folder.
local disk,path=CS.System.IO.File,CS.System.IO.Path
local service=assert(Services.CharacterSaves,'Inspection integration requires real FrameworkServices')
local filename=path.GetFullPath(service.FilePath)
local function normalize(value)return value:gsub('\\','/'):lower()end
local tempRoot=normalize(path.GetFullPath(path.GetTempPath())):gsub('/+$','')..'/'
assert(normalize(filename):sub(1,#tempRoot)==tempRoot,'Inspection integration requires an explicit OS-temporary save path')
for _,suffix in ipairs({'','.bak','.tmp'})do
    assert(not disk.Exists(filename..suffix),'Inspection integration must not overwrite an existing save or backup')
end

local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local messages={}
local function passed(message)messages[#messages+1]='PASS '..message end
local ok,err=xpcall(function()
    registry:Start()
    local adventure=registry:Get('Adventure')
    adventure:Start(815)
    local data,player=adventure.data,adventure.player
    local inspection=assert(adventure.inspection)
    local bridge=CS.ProjectY.Data.UnitInspections
    local roster=CS.ProjectY.Data.PartyRoster
    local knowledge=inspection:Data()
    local resources={health=true,actionPoints=true,guard=true,casting=true}
    local function checkResources(record)
        for field in pairs(resources)do assert(record:HasField(field),'Encounter resource was not retained: '..field)end
    end
    assert(knowledge.Count==0)
    local rosterCount=roster.Count(data)
    assert(rosterCount>0 and rosterCount<=roster.ActiveLimit+roster.ReserveLimit)
    local observerId=assert(inspection:Observers()[1]).id
    local ownRows=inspection:Targets()
    local ownedCount=0
    for _,row in ipairs(ownRows)do if row.owned then
        ownedCount=ownedCount+1
        local view=assert(inspection:Build(row.key,observerId))
        assert(view.owned and view.revealedCount==view.totalCount and not view.canObserve)
        for _,item in ipairs(view.attributes)do assert(item.known)end
        for _,item in ipairs(view.traits)do assert(item.known)end
        for _,item in ipairs(view.skills)do assert(item.known)end
        assert(inspection:Known(row.actor,'health') and inspection:Known(row.actor,'attribute:scouting'))
    end end
    assert(ownedCount>=rosterCount and knowledge.Count==0,'Owned-unit disclosure must not consume an attempt')
    passed('full registry boot, real initial roster and complete owned-unit disclosure without inspection records')

    -- Prefer the existing small story town; its open visibility exercises both real NPC kinds.
    local townId=adventure.narrative.npcs.locations[1]
    if not townId then
        for _,site in ipairs(adventure.sites)do
            if site.areaConfigId and site.areaConfigId>=2 and site.areaConfigId<=5 then townId=site.id;break end
        end
    end
    local successTarget,failureTarget
    if townId then
        assert(adventure:EnterSite(townId))
        assert(data.Phase=='area' and data.Areas.ActiveSiteId==townId)
        local rows=inspection:Targets()
        for _,row in ipairs(rows)do
            if not row.owned and row.kind=='npc' and not successTarget then successTarget=row end
            if not row.owned and row.kind=='resident' and not failureTarget then failureTarget=row end
        end
        if not successTarget then
            for _,row in ipairs(rows)do if not row.owned and (not failureTarget or row.key~=failureTarget.key) then successTarget=row;break end end
        end
        assert(successTarget and failureTarget,'Generated town needs two visible real NPC identities')
        for _,row in ipairs({successTarget,failureTarget})do
            assert(not row.owned and row.actor.TraitCount>0)
            assert(inspection.targets:Key(row.actor)==row.key)
            local template=adventure.battle.stats.units:Get(row.actor.TemplateId)
            for _,id in ipairs(template.traitIds)do assert(row.actor:HasTrait(id),'NPC projection lost an innate trait')end
            local profile=adventure.battle.stats.growth.profileByUnit[row.actor.TemplateId]
            if profile then for _,id in ipairs(profile.traitIds)do assert(row.actor:HasTrait(id),'NPC projection lost a growth-profile trait')end end
            local view=assert(inspection:Build(row.key,observerId))
            assert(view.revealedCount==4 and view.canObserve)
            local record=assert(knowledge:Find(row.key));checkResources(record)
            assert(not record.Observed and record.ObserverId==0 and record.ObserverRoll==0 and record.TargetRoll==0)
            for _,item in ipairs(view.attributes)do assert(item.known==(resources[item.field]==true))end
            for _,item in ipairs(view.traits)do assert(not item.known)end
            for _,item in ipairs(view.skills)do assert(not item.known)end
        end
        passed('real small-town NPC and resident projections, stable identities, merged traits, known resources and masked deeper details')
    else
        -- The seed can legitimately lack a small town. Use two actual world-roster members for persistence.
        local seen={}
        for i=0,adventure.parties.data.Count-1 do
            local party=adventure.parties.data:GetAt(i)
            for j=0,party.MemberCount-1 do
                local actor=party:GetMemberAt(j);local key,owned=inspection.targets:Identity(actor)
                if not owned and not seen[key] then
                    seen[key]=true
                    local row={key=key,actor=actor,owned=false}
                    if not successTarget then successTarget=row elseif not failureTarget then failureTarget=row end
                end
            end
        end
        assert(successTarget and failureTarget,'Default world needs two distinct real non-owned units')
        passed('full boot validated NPC mappings; this seed has no small town, so persistence uses actual world-roster members')
    end
    assert(successTarget.key~=failureTarget.key)

    local successKey,failureKey=successTarget.key,failureTarget.key
    local traitField='trait:'..successTarget.actor:GetTraitAt(0)
    -- The no-town branch supplies real world actors directly at the same discovery boundary.
    inspection:Encounter(successTarget.actor);inspection:Encounter(failureTarget.actor)
    local savedCount=knowledge.Count
    assert(savedCount>=2)
    for _,key in ipairs({successKey,failureKey})do
        local record=assert(knowledge:Find(key));checkResources(record)
        assert(not record.Observed and record.FieldCount==4)
    end
    local passiveKeys={}
    for i=0,knowledge.Count-1 do
        local record=knowledge:GetAt(i)
        if record.Key~=successKey and record.Key~=failureKey then
            assert(not record.Observed);passiveKeys[#passiveKeys+1]=record.Key
        end
    end
    -- Supply settled results directly to the authoritative data boundary, keeping this a persistence test.
    -- Advance the real isolated stream first so restoration cannot pass by merely resetting it to its seed.
    for _=1,4 do local roll=knowledge:Roll(20);assert(roll>=1 and roll<=20)end
    knowledge:Record(successKey,observerId,20,1,19,{'attribute:scouting',traitField})
    knowledge:Record(failureKey,observerId,1,20,-19,{})
    assert(knowledge.Count==savedCount and knowledge:Find(successKey).Observed and knowledge:Find(failureKey).Observed)
    assert(inspection:Known(successTarget.actor,'health') and inspection:Known(successTarget.actor,traitField))
    assert(not inspection:Known(successTarget.actor,'attribute:speed') and inspection:Known(failureTarget.actor,'health'))
    local canRetry,reason=inspection:CanObserve(failureTarget,observerId)
    assert(not canRetry and reason==require('Language').InspectionAlreadyObserved)
    assert(not pcall(function()knowledge:Record(failureKey,observerId,20,1,19,{'health'})end),
        'A failed first attempt must block a second native record')

    service:Save(data,player)
    assert(service.FilePath==filename and disk.Exists(filename))
    local savedBytes=disk.ReadAllText(filename)
    local expected={};for i=1,12 do expected[i]=knowledge:Roll(20)end
    local prepared=service:Prepare(data.Equipment)
    require('Game.Adventure.CharacterSave').Validate(adventure,prepared)
    local preparedKnowledge=bridge.Prepared(prepared)
    assert(preparedKnowledge.Count==savedCount and knowledge.Count==savedCount)
    assert(preparedKnowledge:Find(successKey):HasField(traitField) and preparedKnowledge:Find(failureKey).FieldCount==4)
    checkResources(preparedKnowledge:Find(successKey));checkResources(preparedKnowledge:Find(failureKey))
    for _,key in ipairs(passiveKeys)do
        local record=assert(preparedKnowledge:Find(key));checkResources(record)
        assert(not record.Observed and record.ObserverId==0 and record.FieldCount==4)
    end
    assert(roster.Count(data)==rosterCount,'Preparing a save must not alter active or reserve membership')
    passed('real temporary Save/Prepare and full CharacterSave validation preserve passive knowledge, successful checks and failed attempts')

    if data.Phase=='area' then assert(adventure.areas:Leave())end
    assert(data.Phase=='map','Save service Apply requires the map staging phase')
    local notified=0
    local function onChanged()
        notified=notified+1
        assert(inspection:Data().Count==savedCount and inspection:Data():Find(failureKey).Observed
            and inspection:Data():Find(failureKey).FieldCount==4,
            'Player notification must observe committed inspection knowledge')
    end
    player:AddChangedListener(onChanged)
    local applied,applyError=pcall(function()service:Apply(prepared,data,player)end)
    player:RemoveChangedListener(onChanged)
    assert(applied,applyError)
    assert(notified==1 and roster.Count(data)==rosterCount)
    knowledge=inspection:Data()
    assert(knowledge.Count==savedCount)
    local success,failure=knowledge:Find(successKey),knowledge:Find(failureKey)
    assert(success.Observed and success.ObserverId==observerId and success.ObserverRoll==20 and success.TargetRoll==1 and success.Margin==19)
    assert(success.FieldCount==6 and success:HasField('attribute:scouting') and success:HasField(traitField));checkResources(success)
    assert(failure.Observed and failure.ObserverId==observerId and failure.ObserverRoll==1 and failure.TargetRoll==20
        and failure.Margin==-19 and failure.FieldCount==4);checkResources(failure)
    for _,key in ipairs(passiveKeys)do
        local record=assert(knowledge:Find(key));checkResources(record)
        assert(not record.Observed and record.ObserverId==0 and record.FieldCount==4)
    end
    for i=1,#expected do assert(knowledge:Roll(20)==expected[i],'Inspection RNG did not resume from the saved state')end
    assert(not pcall(function()service:Apply(prepared,data,player)end),'A prepared save must remain single-use')
    if townId then
        local unknown=assert(inspection:Build(failureKey,observerId))
        assert(unknown.revealedCount==4 and not unknown.canObserve)
        for _,item in ipairs(unknown.attributes)do
            assert(item.known==(resources[item.field]==true))
            if not item.known then assert(item.value==require('Language').InspectionUnknown)end
        end
        for _,item in ipairs(unknown.traits)do assert(not item.known and item.title==require('Language').InspectionUnknown)end
        for _,item in ipairs(unknown.skills)do assert(not item.known and item.title==require('Language').InspectionUnknown)end
        local minutes,revision=data.Narrative.Minutes,knowledge.Revision
        local retried,retryReason=inspection:Observe(failureKey,observerId)
        assert(not retried and retryReason==require('Language').InspectionAlreadyObserved)
        assert(data.Narrative.Minutes==minutes and knowledge.Revision==revision,'Rejected retry consumed time or randomness')
    else
        local retried,retryReason=inspection:CanObserve(failureTarget,observerId)
        assert(not retried and retryReason==require('Language').InspectionAlreadyObserved)
    end
    assert(disk.ReadAllText(filename)==savedBytes,'Prepare/Apply must not rewrite the saved snapshot')
    passed('native Apply commits knowledge before notification, blocks failed retries and resumes the exact RNG sequence')

    data:Reset(816)
    assert(inspection:Data().Count==0 and inspection:Data():Find(successKey)==nil and inspection:Data():Find(failureKey)==nil)
    assert(roster.Count(data)==0 and disk.ReadAllText(filename)==savedBytes)
    passed('new-world AdventureData.Reset clears inspection history and roster without modifying the previous save')
end,debug.traceback)
registry:Shutdown()
if not ok then error(err)end
return table.concat(messages,'\n')
