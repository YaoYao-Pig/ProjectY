-- Real FrameworkServices, exported configuration, generated town residents and saved UI prefabs.
-- The native host suppresses renderer-only snapshots; no game service/model is replaced with a double.
local disk,path=CS.System.IO.File,CS.System.IO.Path
local saves=assert(Services.CharacterSaves)
local filename=path.GetFullPath(saves.FilePath)
local function normalize(value)return value:gsub('\\','/'):lower()end
local tempRoot=normalize(path.GetFullPath(path.GetTempPath())):gsub('/+$','')..'/'
assert(normalize(filename):sub(1,#tempRoot)==tempRoot,'People integration requires an OS-temporary save path')
for _,suffix in ipairs({'','.bak','.tmp'})do assert(not disk.Exists(filename..suffix),'Never overwrite an existing save fixture')end
local main=require('Main')
local adventure,ui,story=main:Get('Adventure'),main:Get('UI'),main:Get('Narrative')
local L=require('Language')
local bridge,roster=CS.ProjectY.Data.PeopleState,CS.ProjectY.Data.PartyRoster
local save=require('Game.Adventure.CharacterSave')
local notes={}
local function passed(message)notes[#notes+1]='PASS '..message end
local ok,err=xpcall(function()
    adventure:Start(815,1,2500)
    local data=adventure.data
    assert(roster.Count(data)>0 and roster.Count(data)<roster.ActiveLimit+roster.ReserveLimit)
    local townId=story.npcs.locations[1]
    if not townId then for _,site in ipairs(adventure.sites)do
        if site.areaConfigId and site.areaConfigId>=2 and site.areaConfigId<=5 then townId=site.id;break end
    end end
    assert(townId,'The deterministic native fixture requires a generated town')
    assert(adventure:EnterSite(townId))
    local layout,state=adventure.areas:ActiveLayout(),data.Areas.Active
    local chosen,person,nearCell
    local free=require('Game.Adventure.PeopleRules').FreeResident
    -- Select a generated livelihood resident whose actual position has a free neighboring cell.
    for _,definition in ipairs(layout.npcs)do
        if free(definition)then
            local profile=adventure.people.rules:Cast(data.Seed,townId,definition.stableId,definition.templateId)
            local live=state:GetNpcAt(definition.id-1)
            if profile==1 and live.Present then
                for _,index in ipairs(layout.cells[live.CellIndex].neighbors)do
                    local cell=layout.cells[index]
                    local occupied=state:IsNpcOccupied(index)
                    for member=1,state.MemberCount-1 do if state:GetMemberCellAt(member)==index then occupied=true end end
                    if cell and not cell.blocked and not occupied then
                        local route=layout:FindPath(index,live.CellIndex)
                        if route and #route<=1 then chosen=definition;nearCell=index;break end
                    end
                end
            end
            if chosen then break end
        end
    end
    assert(chosen and nearCell,'The deterministic town needs a reachable livelihood resident')
    person=adventure.people:EnsureResident(chosen,townId)
    local key,actor=person.Key,person.Actor
    assert(not person.Known and not person.Joined and person.BondKey~='')
    local linked=assert(adventure.people:Find(person.BondKey));assert(linked.BondKey==key)
    local projected=adventure.inspection.targets:ProjectNpc(chosen,townId)
    assert(projected.key==key and projected.actor==actor,'Inspection must project the persisted actor instance')
    local original={id=actor.Id,template=actor.TemplateId,hp=actor.HP,maxHP=actor.MaxHP,
        profession=actor.Growth.CurrentProfessionId,traits=actor.TraitCount,appearance=actor.CustomizationJson}
    passed('full registry boot, real generated resident and reciprocal acquaintance, inspection shares the native actor')

    -- Fixture placement only: validated free cells, real native formation state and normal interaction gates.
    local ids,cells={},{}
    for index=0,state.MemberCount-1 do ids[#ids+1]=state:GetMemberIdAt(index);cells[#cells+1]=index==0 and nearCell or state:GetMemberCellAt(index)end
    state:DeployMembers(ids,cells);adventure.areas:RevealSquad(layout,state)
    local opened,why=adventure:AreaCommand('area_interact',2,chosen.id)
    assert(opened,why)
    assert(person.Known and adventure.peopleDialogue:Active() and story.data.DialogueId==-2)
    assert(CS.ProjectY.Data.PeopleDialogueSession.Key(story.data)==key and story.data.DialogueNpcId==0)
    assert(story.data.LineCount==1 and story.data:GetLineAt(0).Speaker==adventure.people:Name(person))
    local version=story.data.DialogueVersion
    assert(story.dialogue:Choose(10,version));assert(not story.dialogue:Choose(10,version),'Native dialogue must reject a stale click')
    assert(story.dialogue:Close() and not story.data.DialogueOpen and state.InteractionKind==0)
    passed('normal resident interaction opens the native special session, records acquaintance and rejects stale choices')

    -- Preserve the pre-existing commission entry using an actual generated publisher and contract.
    local publisher,contract,publisherCell
    for index=0,story.townMissions.data.Count-1 do local mission=story.townMissions.data:GetAt(index)
        if mission.SiteId==townId and story.townMissions:HasPublisher(townId,mission.NpcId)then
            for _,definition in ipairs(layout.npcs)do if free(definition) and definition.stableId==mission.NpcId then
                local live=state:GetNpcAt(definition.id-1)
                if live.Present then for _,neighbor in ipairs(layout.cells[live.CellIndex].neighbors)do
                    local cell=layout.cells[neighbor];local occupied=state:IsNpcOccupied(neighbor)
                    for member=1,state.MemberCount-1 do if state:GetMemberCellAt(member)==neighbor then occupied=true end end
                    if cell and not cell.blocked and not occupied then
                        local route=layout:FindPath(neighbor,live.CellIndex)
                        if route and #route<=1 then publisher,contract,publisherCell=definition,mission,neighbor;break end
                    end
                end end
            end end
            if publisher then break end
        end
    end
    assert(publisher and contract and publisherCell,'Generated town must expose a reachable actual commission publisher')
    local publisherCells={};for index=1,#cells do publisherCells[index]=index==1 and publisherCell or cells[index]end
    state:DeployMembers(ids,publisherCells);adventure.areas:RevealSquad(layout,state)
    local publisherPerson=adventure.people:EnsureResident(publisher,townId)
    local publisherOpened,publisherError=adventure.peopleDialogue:OpenTarget(publisherPerson.Key);assert(publisherOpened,publisherError)
    assert(story.data.DialogueLocalNpcId==publisher.id and state.InteractionId==publisher.id,
        'Opening a resident from details must establish the real nearby interaction')
    local commissionChoice
    for _,choice in ipairs(adventure.peopleDialogue:Choices())do if choice.id==12 then commissionChoice=choice end end
    assert(commissionChoice and commissionChoice.available)
    assert(story.dialogue:Choose(12,story.data.DialogueVersion))
    assert(not story.data.DialogueOpen and state.InteractionKind==2 and state.InteractionId==publisher.id,
        'Commission transition must close dialogue while retaining its real publisher interaction')
    local nearPublisher,nearError=story.townMissions:NearPublisher(contract);assert(nearPublisher,nearError)
    local journal=ui:Open('MissionJournal',{demo=PeopleNativeDemo,townSiteId=townId,townNpcId=publisher.stableId})
    assert(journal.visible and journal.category=='town' and Services.UI.IsWorldPaused and story.townMissions:NearPublisher(contract))
    ui:Close('MissionJournal');assert(state.InteractionKind==0 and not Services.UI.IsWorldPaused)
    state:DeployMembers(ids,cells);adventure.areas:RevealSquad(layout,state)
    passed('actual generated commission publisher remains reachable from details dialogue, preserves NearPublisher and opens the existing town journal')

    local inspectionRevision=adventure.inspection:Data().Revision
    local details=ui:Open('UnitDetails',{demo=PeopleNativeDemo,key=key})
    assert(Services.UI.IsWorldPaused and PeopleNativeInputOpen())
    assert(details.view.Talk.gameObject.activeInHierarchy and details.view.Talk.interactable)
    assert(details.view.TalkText.DefaultText==L.PeopleDialogueTalkOther)
    assert(details.view.Observe~=details.view.Talk and details.view.Observe.gameObject.activeInHierarchy)
    details.reference:ValidateBindings()
    CapturePeopleUi(details.reference,'details')
    details.view.Talk.onClick:Invoke()
    assert(not ui:IsOpen('UnitDetails') and not PeopleNativeInputOpen() and adventure.peopleDialogue:Active())
    assert(adventure.inspection:Data().Revision==inspectionRevision,'Talk must not spend the scouting attempt')
    -- Mirrors the dialogue branch of AdventureUIBridge.sync; renderer snapshots are intentionally suppressed by the host.
    local dialogue=ui:Open('Dialogue',{demo=PeopleNativeDemo})
    assert(ui:IsOpen('Dialogue') and Services.UI.IsWorldPaused and dialogue.view.Title.text==adventure.people:Name(person))
    assert(dialogue.view.Caption.text==adventure.peopleDialogue:Caption() and #dialogue.choices>=4)
    assert(dialogue.view.Hint.text==L.PeopleDialogueHint)
    passed('saved UnitDetails Talk button is visible and invokes the real model, releases details input, and saved Dialogue shows that person')

    adventure.player:AddCoins(500)
    local profile=adventure.people.rules.profiles:Get(person.ProfileId)
    local beforeCoins,beforeRoster=adventure.player.Coins,roster.Count(data)
    local hire
    for _,choice in ipairs(adventure.peopleDialogue:Choices())do if choice.id==101 then hire=choice end end
    assert(hire and hire.available,hire and hire.reason or 'Missing livelihood advance route')
    assert(story.dialogue:Choose(hire.id,story.data.DialogueVersion))
    assert(person.Joined and roster.Count(data)==beforeRoster+1 and roster.Find(data,actor.Id)==actor)
    assert(person.Actor==actor and actor.Id==original.id and actor.TemplateId==original.template)
    assert(actor.HP==original.hp and actor.MaxHP==original.maxHP and actor.TraitCount==original.traits)
    assert(actor.Growth.CurrentProfessionId==original.profession and actor.CustomizationJson==original.appearance)
    assert(adventure.player.Coins==beforeCoins-profile.fee)
    assert(not story.dialogue:Choose(hire.id,story.data.DialogueVersion),'Joined residents cannot be bought twice')
    dialogue:Refresh()
    CapturePeopleUi(dialogue.reference,'growth')
    local growth=adventure.personalGrowth:Choices(actor.Id)
    assert(#growth==2 and type(growth[1].body)=='string' and type(growth[2].reason)=='string')
    assert(adventure.personalGrowth:Summary(actor.Id) and person.Stage==0)
    ui:Close('Dialogue')
    assert(not story.data.DialogueOpen and not Services.UI.IsWorldPaused and not state:GetNpcAt(chosen.id-1).Present)
    passed('native recruitment charges once, transfers the exact actor into the roster, preserves appearance/stats and exposes two growth choices')

    person:AddTrust(7)
    local storedTrust,bondKey=person.Trust,person.BondKey
    local wrote,writeError=save.Write(adventure);assert(wrote,writeError)
    assert(disk.Exists(filename))
    local saved=disk.ReadAllText(filename)
    local read,readError=save.Read(adventure);assert(read,readError)
    local restored=assert(adventure.people:Find(key))
    local restoredActor=assert(roster.Find(data,original.id))
    assert(restored.Actor==restoredActor and restored.Joined and restored.Known and restored.Trust==storedTrust)
    assert(restored.BondKey==bondKey and adventure.people:Find(bondKey).BondKey==key)
    assert(restoredActor.TemplateId==original.template and restoredActor.HP==original.hp and restoredActor.MaxHP==original.maxHP)
    assert(restoredActor.TraitCount==original.traits and restoredActor.Growth.CurrentProfessionId==original.profession)
    assert(restoredActor.CustomizationJson==original.appearance and not data.Narrative.DialogueOpen)
    assert(disk.ReadAllText(filename)==saved,'Reading must not rewrite the snapshot')
    local found
    for _,row in ipairs(adventure.inspection:Targets())do if row.key==key then
        assert(not found and row.owned and row.actor==restoredActor,'Restoration duplicated or replaced the resident identity');found=row
    end end
    assert(found,'Recruited resident must remain visible in owned-unit details after load')
    assert(#adventure.personalGrowth:Choices(restoredActor.Id)==2)
    passed('real temporary Save/Read rebuilds the world and restores one shared person/roster actor, bonds, knowledge and untouched growth choices')
    assert(bridge.Get(data):Find(key)==restored)
    notes[#notes+1]=assert(loadfile('Tools/Tests/people_world_integration.lua'))()
end,debug.traceback)
if ui:IsOpen('UnitDetails')then ui:Close('UnitDetails')end
if ui:IsOpen('Dialogue')then ui:Close('Dialogue')end
if ui:IsOpen('MissionJournal')then ui:Close('MissionJournal')end
if not ok then error(err,0)end
return table.concat(notes,'\n')
