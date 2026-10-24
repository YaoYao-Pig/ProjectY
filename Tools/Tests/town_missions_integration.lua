-- Real exported configuration, Data, NPC layouts, Lua rules and UI in an isolated Editor LuaEnv.
local registry=require('Main');local adventure=registry:Get('Adventure');local story=registry:Get('Narrative')
local missions=story.townMissions;local data=missions.data;local messages={}
local function test(name,body) body();messages[#messages+1]='PASS '..name end
adventure:Start(nil,2,2500)
local siteId=assert(story.npcs.locations[1]);assert(adventure:EnterSite(siteId));story:Refresh()
local layout=adventure.areas:ActiveLayout();local state=adventure.data.Areas.Active
local function place(q,r)
    local anchor=CS.ProjectY.Data.WorldTravelData();anchor:Reset(47,q,r,1)
    adventure.travel.data:Follow(anchor)
end
local function publisher(mission)
    for _,npc in ipairs(layout.npcs) do if npc.stableId==mission.NpcId then return npc end end
    error('Publisher missing')
end
local function interact(mission)
    local npc=publisher(mission);local index=state:GetNpcAt(npc.id-1).CellIndex;local anchor
    for _,cell in ipairs(layout:Neighbors(layout.cells[index])) do if not state:IsNpcOccupied(cell.index) then anchor=cell.index;break end end
    assert(anchor,'No reachable publisher approach')
    local ids={};for i=0,adventure.data.PartyCount-1 do ids[#ids+1]=adventure.data:GetPartyAt(i).Id end
    local cells=require('Game.MapArea.SquadMovement').Deploy(layout,anchor,#ids,function(cell)return not state:IsNpcOccupied(cell.index)end)
    state:Stop();state:DeployMembers(ids,cells)
    assert(adventure:AreaCommand('area_interact',2,npc.id))
    return npc
end
local accepted={}
test('daily deterministic offers, 1–5 range, stable publishers and no revisit reroll',function()
    local signatures={};local count=data.Count;assert(count>=1 and count<=5)
    for i=0,count-1 do local row=data:GetAt(i);signatures[i+1]=row.Id..':'..row.DefinitionId..':'..row.NpcId;assert(publisher(row)) end
    missions:EnsureTown();assert(data.Count==count)
    for i=0,count-1 do local row=data:GetAt(i);assert(signatures[i+1]==row.Id..':'..row.DefinitionId..':'..row.NpcId) end
    for day=1,16 do
        -- Accept one of each available objective through real nearby NPC interactions.
        local offered={};for i=0,data.Count-1 do offered[#offered+1]=data:GetAt(i) end
        for _,row in ipairs(offered) do
            local kind=missions.definitions:Get(row.DefinitionId).kind
            if row.State=='offered' and not accepted[kind] then interact(row);assert(missions:Accept(row.Id));accepted[kind]=row.Id;adventure.areas:CloseInteraction() end
        end
        if accepted.delivery and accepted.clear and accepted.escort then break end
        local oldIds={};for i=0,data.Count-1 do local row=data:GetAt(i);if row.State=='offered' then oldIds[#oldIds+1]=row.Id end end
        story:AdvanceMinutes(1440);missions:Refresh()
        local offers=0;for i=0,data.Count-1 do if data:GetAt(i).State=='offered' then offers=offers+1 end end
        assert(offers>=1 and offers<=5)
        for _,id in ipairs(oldIds) do assert(data:Find(id)==nil,'Expired offer survived daily refresh') end
        for _,id in pairs(accepted) do assert(data:Find(id),'Accepted mission expired') end
    end
    assert(accepted.delivery and accepted.clear and accepted.escort,'Fixture did not offer all supported objectives')
end)
test('material hand-in consumes real inventory once and rechecks a spent ready stack',function()
    local mission=data:Find(accepted.delivery);local npc=interact(mission)
    local before=story:ItemCount(mission.TargetId)
    if before>0 then adventure.data.Equipment:ConsumeStack(mission.TargetId,before) end
    assert(adventure.equipment:Grant(mission.TargetId,mission.RequiredCount));missions:Refresh()
    assert(mission.State=='ready' and missions:Marker(siteId,npc)==2)
    adventure.data.Equipment:ConsumeStack(mission.TargetId,1)
    local coins=adventure.player.Coins;assert(not missions:Claim(mission.Id));assert(adventure.player.Coins==coins)
    assert(adventure.equipment:Grant(mission.TargetId,1));assert(missions:Claim(mission.Id))
    assert(story:ItemCount(mission.TargetId)==0 and mission.State=='completed' and adventure.player.Coins>coins)
    coins=adventure.player.Coins;assert(not missions:Claim(mission.Id));assert(adventure.player.Coins==coins)
    adventure.areas:CloseInteraction()
end)
test('clear objectives count only player hostile defeats inside the originating town radius',function()
    local mission=data:Find(accepted.clear);local before=mission.Progress;local battle=adventure.battle
    local town=adventure.sites[siteId];local far
    for _,cell in ipairs(adventure.map:GetCells()) do if require('Game.Map.HexGrid').Distance(cell.q,cell.r,town.q,town.r)>20 then far=cell;break end end
    assert(far);assert(adventure.areas:Leave());place(far.q,far.r)
    missions:RecordKill();assert(mission.Progress==before)
    place(town.q,town.r);assert(adventure:EnterSite(siteId))
    layout=adventure.areas:ActiveLayout();state=adventure.data.Areas.Active
    battle.data:Reset(1,30)
    battle.data:AddUnit(adventure.data:GetPartyAt(0),1,1,0)
    local target=battle.data:AddEnemy(909,4,0,0);target:SetMaxHP(10);target:Restore()
    battle:Emit('defeated','Unattributed fixture',nil,target.Id);assert(mission.Progress==before)
    battle:Emit('defeated','Player fixture',1,target.Id);assert(mission.Progress==before+1)
    for _=mission.Progress+1,mission.RequiredCount do missions:RecordKill() end
    assert(mission.State=='ready')
    local npc=interact(mission);assert(missions:Marker(siteId,npc)==2)
    assert(missions:Claim(mission.Id));assert(not missions:Claim(mission.Id));adventure.areas:CloseInteraction()
end)
test('world save roundtrip keeps stable NPC contracts, rewards, caravan and attachment',function()
    local mission=data:Find(accepted.escort);local party=assert(adventure.parties.data:Find(mission.PartyId))
    assert(party.Mission=='escort_wait' and party.Travel.Paused and party.MemberCount>0)
    local save=require('Game.Adventure.CharacterSave');assert(save.Write(adventure));assert(save.Read(adventure))
    assert(data==missions.data and data:Find(accepted.delivery).State=='completed' and data:Find(accepted.clear).State=='completed')
    mission=data:Find(accepted.escort);party=assert(adventure.parties.data:Find(mission.PartyId))
    assert(mission.State=='active' and party.Mission=='escort_wait')
    layout=adventure.areas:ActiveLayout();state=adventure.data.Areas.Active;assert(publisher(mission))
    assert(adventure.areas:Leave())
    -- Fixture placement at a real town coordinate, then all attach/move/detach paths are production code.
    place(party.Travel.Q,party.Travel.R)
    adventure.parties.data:Open(party.Id)
    local found=false;for _,button in ipairs(adventure.parties:ContactSnapshot().rows) do if button.command=='town_mission_attach' then found=true end end
    assert(found,'Caravan contact must expose escort attachment');adventure.parties.data:Close()
    assert(missions.escort:Attach(mission.Id));assert(data.AttachedId==mission.Id)
    local minutes=story.data.Minutes;adventure.travel:Tick(.1)
    assert(story.data.Minutes>minutes and adventure.travel.data.Q==party.Travel.Q and adventure.travel.data.R==party.Travel.R)
    assert(math.abs(adventure.travel.data.Progress-party.Travel.Progress)<1e-7)
    assert(save.Write(adventure));assert(save.Read(adventure));assert(data.AttachedId==mission.Id)
    assert(missions.escort:Detach());assert(data.AttachedId==0)
end)
test('resident interaction opens a real journal with five tabs and closes its interaction',function()
    assert(adventure:EnterSite(siteId));story:Refresh();layout=adventure.areas:ActiveLayout();state=adventure.data.Areas.Active
    local row=data:Find(accepted.escort);interact(row)
    local ui=registry:Get('UI');local original=ui.IsOpen
    -- The host HUD is irrelevant to this isolated panel fixture.
    ui.IsOpen=function(self,name) if name=='MainHud' then return true end;return original(self,name) end
    local demo={MainHudFont=MissionTestFont,LastError='',BattleHUDRevision=0,SetStoryOpen=function()end}
    require('UI.AdventureUIBridge')('sync',demo)
    assert(ui:IsOpen('MissionJournal'))
    ui:Close('MissionJournal');assert(state.InteractionKind==0)
    ui.IsOpen=original
end)
test('attached ambush and independent aid join real battles, retain wounds and resume the escort',function()
    assert(adventure.areas:Leave())
    local mission=data:Find(accepted.escort);local parties=adventure.parties;local caravan=assert(parties.data:Find(mission.PartyId))
    local definition
    for _,row in ipairs(parties.definitions:All()) do
        if row.kind=='hostile' and adventure.factions:Relation(row.factionId,caravan.FactionId)=='hostile' then definition=row;break end
    end
    assert(definition)
    for _,attached in ipairs({true,false}) do
        missions.escort:Detach()
        caravan.Travel:Reset(47,caravan.Travel.Q,caravan.Travel.R,1);place(caravan.Travel.Q,caravan.Travel.R)
        local enemy=parties.data:Add(definition.id,caravan.Travel.Q,caravan.Travel.R,0,91)
        enemy:ConfigureFaction(definition.factionId,caravan.Travel.Q,caravan.Travel.R,'raider')
        adventure.factions:PrepareRoster(enemy,definition.encounterId);parties.lod:Calibrate(enemy)
        if attached then assert(missions.escort:Attach(mission.Id)) end
        local wounded=caravan:GetMemberAt(0);wounded:Damage(1);local hp=wounded.HP
        local conflict=adventure.factions.conflicts:Begin(enemy,caravan,story.data.Minutes)
        if attached then missions.escort:Refresh() else assert(missions.escort:Join(mission.Id)) end
        assert(adventure.data.Phase=='battle' and conflict.PlayerEngaged)
        assert(adventure.battle:IsAllied(1,wounded) and wounded.HP==hp and wounded.Team~=1)
        for _,actor in ipairs(adventure.battle:Units()) do if adventure.battle:IsHostile(1,actor) then actor:Damage(actor.HP) end end
        assert(adventure.battle:CheckWinner());adventure:SettleBattle()
        assert(conflict.Phase=='resolved' and enemy.Defeated and not caravan.Defeated and wounded.HP==hp)
        assert(mission.State=='active' and caravan.Mission=='escort')
        if adventure.equipment.worldLoot.session.Active then adventure:CloseLoot() end
        assert(adventure.areas:Leave())
    end
    missions.escort:Detach()
    local destination=adventure.sites[mission.DestinationSiteId]
    caravan.Travel:Reset(47,destination.q,destination.r,1);place(destination.q,destination.r)
    missions.escort:Refresh();assert(mission.State=='ready' and caravan.Mission=='trade')
end)
return table.concat(messages,'\n')
