-- 独立 Edit Mode LuaEnv、真实 C# Data 和导表；不改变用户队伍/存档/编辑场景。
local registry=require('Core.SystemRegistry')(Services)
for _,spec in ipairs({
    {'Config','Config.ConfigSystem'}, {'Condition','Game.Condition.ConditionSystem',{'Config'}},
    {'PlayerModel','Game.PlayerModelSystem',{'Config'}}, {'Map','Game.Map.MapSystem',{'Config'}},
    {'MapArea','Game.MapArea.MapAreaSystem',{'Config'}}, {'Battle','Game.Battle.BattleSystem',{'Config'}},
    {'Equipment','Game.Equipment.EquipmentSystem',{'Config'}}, {'Growth','Game.Progression.GrowthSystem',{'Battle'}},
    {'AdventureEvents','Game.Adventure.EventSystem',{'Battle','PlayerModel','Growth','Equipment'}},
    {'Adventure','Game.Adventure.AdventureSystem',{'Map','MapArea','AdventureEvents','Equipment'}},
    {'Narrative','Game.Narrative.NarrativeSystem',{'Adventure','Condition'}},
}) do registry:Register(spec[1],require(spec[2]),spec[3]) end
function CloseNarrativeFixture() registry:Shutdown() end
registry:Start()
local adventure,story=registry:Get('Adventure'),registry:Get('Narrative')
adventure:Start(nil,story.rules.settings.demoRecipeId)
local data=story.data;assert(adventure.data.PartyCount==3)
assert(story.npcs.locations[1] and story.npcs.locations[2],'Demo map needs narrative NPC sites')
assert(story:Accept(100));assert(not story:Accept(100))
assert(data:Status('quest',101)=='active' and data:Status('quest',104)=='active','Parallel stages must activate together')
data:RecordKill(4);data:RecordKill(4) -- 阶段激活前的真实计数不得回溯计入。
assert(adventure.equipment:Grant(31,12));story:Refresh();assert(data:Status('quest',101)=='completed')
local actions=require('Game.Narrative.NarrativeActions')
actions.Apply(story,assert(actions.Prepare(story,{11,14})));story:Refresh()
assert(data:Status('quest',102)=='active' and data:Status('quest',103)=='inactive')
assert(data:KillCount('quest',102,4)==0 and data:GetValue('relation:1')==10)
-- 从战斗系统的实际击败事件进入任务计数。
local battle=adventure.battle;battle.data:Reset(1,30);local target=battle.data:AddEnemy(901,4,0,0)
target:SetMaxHP(10);target:Restore();target:Damage(10);battle:Emit('defeated','fixture defeat',1,target.Id)
assert(data:KillCount('quest',102,4)==1)
data:RecordKill(4);story:Refresh();assert(data:Status('mission',100)=='ready')
local coins=adventure.player.Coins
assert(story:Claim('mission',100));assert(not story:Claim('mission',100));assert(adventure.player.Coins==coins+40)
assert(data:GetValue('reputation:1')==5 and story:Accept(200))
data:SetValue('flag:lya_invited',1);story:Refresh();assert(data:Status('mission',200)=='ready')
local save=require('Game.Adventure.CharacterSave')
assert(save.Write(adventure))
local fourth=adventure.data:PrepareRecruitActor(999,1);adventure.characterAppearances:Party(fourth,adventure.data.Seed)
adventure.growth:PrepareActor(fourth);fourth:SetMaxHP(adventure.battle.stats:MaximumHP(fourth));fourth:Restore();adventure.data:AddPreparedRecruit(fourth)
local ok,reason=story:Claim('mission',200)
assert(not ok and reason:find('队伍已满') and data:Status('mission',200)=='ready' and data:GetValue('recruited:1')==0)
assert(save.Read(adventure));assert(adventure.data.PartyCount==3 and data:Status('mission',200)=='ready')
assert(data:KillCount('quest',102,4)==2 and data:GetValue('relation:1')==10,'Save must preserve baselines and social state')
local journalCount=adventure.data.JournalCount
assert(actions.Prepare(story,{18}));assert(actions.Prepare(story,{18}))
assert(adventure.data.PartyCount==3 and adventure.data.JournalCount==journalCount and data:GetValue('recruited:1')==0,'Recruit preflight must not mutate party or chronicle')
assert(story:Claim('mission',200));assert(adventure.data.PartyCount==4 and data:GetValue('recruited:1')==10001)
assert(not story:Claim('mission',200))
assert(save.Write(adventure));assert(save.Read(adventure));assert(adventure.data.PartyCount==4 and data:Status('mission',200)=='completed')

-- 第二条路线及真实城镇 NPC、日程、距离校验、对话回环与陈旧选项。
adventure:Start(nil,story.rules.settings.demoRecipeId)
assert(story:Accept(100));assert(adventure.equipment:Grant(31,12))
actions.Apply(story,assert(actions.Prepare(story,{12,14})));story:Refresh()
assert(data:Status('quest',103)=='active' and data:Status('quest',102)=='inactive')
assert(adventure:Visit(story.npcs.locations[2]))
local areas=adventure.areas;local layout,state=areas:ActiveLayout(),adventure.data.Areas.Active
local localId
for _,npc in ipairs(layout.npcs) do if npc.narrativeId==2 then localId=npc.id end end
assert(localId,'Named NPC must be present in generated town')
local old={};for i=0,state.NpcCount-1 do old[i]=state:GetNpcAt(i).CellIndex end
areas:Tick(2)
for i=0,state.NpcCount-1 do local a,b=layout.cells[old[i]],layout.cells[state:GetNpcAt(i).CellIndex];assert(a.index==b.index or layout:CanStep(a,b),'Scheduled NPC crossed an invalid edge') end
local targetIndex=state:GetNpcAt(localId-1).CellIndex
-- 测试夹具只用合法道路格布置小队，然后仍走实际距离检查和交互命令。
local anchor
for _,cell in ipairs(layout:Neighbors(layout.cells[targetIndex])) do if not state:IsNpcOccupied(cell.index) then anchor=cell.index;break end end
assert(anchor)
local ids={};for i=0,adventure.data.PartyCount-1 do ids[#ids+1]=adventure.data:GetPartyAt(i).Id end
local cells=require('Game.MapArea.SquadMovement').Deploy(layout,anchor,#ids,function(cell)return not state:IsNpcOccupied(cell.index) end)
state:Stop();state:DeployMembers(ids,cells)
assert(adventure:AreaCommand('area_interact',2,localId));assert(data.DialogueOpen and data.DialogueNodeId==20)
local version=data.DialogueVersion
assert(story.dialogue:Choose(20,version));assert(not story.dialogue:Choose(20,version))
assert(data.DialogueNodeId==21 and data:Status('quest',103)=='completed' and data:Status('mission',100)=='ready')
local at=state:GetNpcAt(localId-1).CellIndex;areas:Tick(10);assert(state:GetNpcAt(localId-1).CellIndex==at,'Talking NPC must remain stationary')
assert(not save.Write(adventure),'Do not save transient dialogue sessions')
story.dialogue:Close();assert(not data.DialogueOpen and state.InteractionKind==0)
local before=data.Minutes;story:Tick(1);assert(data.Minutes>before)
local snapshot=adventure:Snapshot();assert(type(snapshot.area.npcs[1].present)=='boolean')
registry:Shutdown()
return 'PASS narrative: parallel stages, branch alternatives, activation kill baselines, one-time rewards, full-party deferral, recruitment, save round-trip, named NPCs, road-bound schedules, dialogue replay and lifecycle'
