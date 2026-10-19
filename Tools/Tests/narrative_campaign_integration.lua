-- 仅由调用方在已授权的独立 Edit Mode LuaEnv 中运行；Services 必须使用临时存档路径。
-- 不进入 Play，不启动 Editor，不接触用户存档；剧情分支的完整路径由 narrative_campaign_core 覆盖。
local registry=require('Core.SystemRegistry')(Services)
-- 与既有 narrative_integration 相同的业务系统集合，不注册 UI / GM，不需要 UIHost。
for _,spec in ipairs({
    {'Config','Config.ConfigSystem'}, {'Condition','Game.Condition.ConditionSystem',{'Config'}},
    {'PlayerModel','Game.PlayerModelSystem',{'Config'}}, {'Map','Game.Map.MapSystem',{'Config'}},
    {'MapArea','Game.MapArea.MapAreaSystem',{'Config'}}, {'Battle','Game.Battle.BattleSystem',{'Config'}},
    {'Equipment','Game.Equipment.EquipmentSystem',{'Config'}}, {'Growth','Game.Progression.GrowthSystem',{'Battle'}},
    {'AdventureEvents','Game.Adventure.EventSystem',{'Battle','PlayerModel','Growth','Equipment'}},
    {'Adventure','Game.Adventure.AdventureSystem',{'Map','MapArea','AdventureEvents','Equipment'}},
    {'Narrative','Game.Narrative.NarrativeSystem',{'Adventure','Condition'}},
})do registry:Register(spec[1],require(spec[2]),spec[3])end
local ok,result=xpcall(function()
    registry:Start()
    local adventure=registry:Get('Adventure');adventure:Start(20261016,3,10000)
    local story=registry:Get('Narrative');local data=story.data
    local file=adventure.characterSaves.FilePath:gsub('\\','/'):lower()
    assert(file:find('project%-y%-') and not file:find('/characters/party%-'), 'Campaign integration requires an isolated temporary save')
    assert(data:Status('mission',300)=='active' and data:Status('mission',400)=='active')
    for id=1,6 do assert(story.npcs.locations[id],'Missing NPC site '..id)end
    -- 此项只验地点生成/交互链；旅行另有测试，不把 Visit 的异步启程误当作到站。
    assert(adventure:EnterSite(story.npcs.locations[3]))
    local areas=adventure.areas;local layout,state=areas:ActiveLayout(),adventure.data.Areas.Active
    local localId,named=0,0
    for _,npc in ipairs(layout.npcs)do
        if npc.narrativeId then named=named+1 end
        if npc.narrativeId==3 then localId=npc.id end
    end
    assert(named==6 and localId>0,'Generated market must contain all story NPCs')
    local target=state:GetNpcAt(localId-1).CellIndex;local anchor
    for _,cell in ipairs(layout:Neighbors(layout.cells[target]))do if not state:IsNpcOccupied(cell.index)then anchor=cell.index;break end end
    assert(anchor)
    local ids={};for i=0,adventure.data.PartyCount-1 do ids[#ids+1]=adventure.data:GetPartyAt(i).Id end
    local cells=require('Game.MapArea.SquadMovement').Deploy(layout,anchor,#ids,function(cell)return not state:IsNpcOccupied(cell.index)end)
    state:Stop();state:DeployMembers(ids,cells)
    assert(adventure:AreaCommand('area_interact',2,localId));assert(data.DialogueOpen)
    local function choose(fragment)
        local row
        for _,id in ipairs(story.rules.nodes:Get(data.DialogueNodeId).choiceIds)do local candidate=story.rules.choices:Get(id);if candidate.text:find(fragment,1,true)then assert(not row);row=candidate end end
        assert(row,fragment);local version=data.DialogueVersion
        local allowed,reason=story.dialogue:Choose(row.id,version);assert(allowed,reason)
        assert(not story.dialogue:Choose(row.id,version))
    end
    choose('这封烧焦');choose('我会把账');story.dialogue:Close()
    assert(data:Status('quest',301)=='completed' and data:Status('quest',305)=='active')
    local battle=adventure.battle;battle.data:Reset(1,30)
    local enemy=battle.data:AddEnemy(9901,4,0,0);enemy:SetMaxHP(10);enemy:Restore();enemy:Damage(10)
    battle:Emit('defeated','campaign integration',ids[1],enemy.Id)
    assert(data:KillCount('quest',305,4)==1,'Actual defeated event must update campaign baseline')
    local member=adventure.data:GetPartyAt(0);local beforeExp,beforeLevel=member.Growth.Experience,member.Growth.Level
    local actions=require('Game.Narrative.NarrativeActions')
    assert(actions.Prepare(story,story.rules.missions:Get(300).actionIds))
    assert(member.Growth.Experience==beforeExp and member.Growth.Level==beforeLevel,'Preflight mutated real C# growth')
    -- 此夹具只定位新奖励契约；完整达成条件已由离线 12 路线检查，不伪装实机完成剧情。
    data:Ready('mission',300);assert(story:Claim('mission',300));assert(not story:Claim('mission',300));story:Refresh()
    assert(data:Status('mission',500)=='active' and data:Status('mission',300)=='completed')
    local savedExp,savedLevel=member.Growth.Experience,member.Growth.Level
    assert(savedExp~=beforeExp or savedLevel~=beforeLevel,'Real C# experience was not granted')
    local save=require('Game.Adventure.CharacterSave')
    assert(save.Write(adventure));assert(save.Read(adventure))
    member=adventure.data:GetPartyAt(0)
    assert(member.Growth.Experience==savedExp and member.Growth.Level==savedLevel)
    assert(data:Status('mission',300)=='completed' and not story:Claim('mission',300))
    assert(data:KillCount('quest',305,4)==1 and data:GetValue('flag:ash_brief')==1)
    return 'PASS campaign real Data: formal start, six placed NPCs, nearby dialogue, stale click, enemy event baseline, nonmutating XP preflight, one-time reward and temporary-save round trip'
end,debug.traceback)
registry:Shutdown()
if not ok then error(result)end
return result
