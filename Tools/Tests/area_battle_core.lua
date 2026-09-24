-- 定向纯 Lua：真实地牢敌群部署、隔墙技能和战后散队收拢。
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=f:read('*a');f:close();return bytes
end}})
local Hex=require('Game.Map.HexGrid')
local Layout=require('Game.MapArea.MapAreaLayout')
local Generator=require('Game.MapArea.MapAreaGenerator')
local Encounters=require('Game.MapArea.DungeonEncounters')
local generator=Generator(config)
generator:Register(1,require('Game.MapArea.DungeonGenerator'),'MapAreaDungeonTable')
local source={regionId=7,regionType=2,regionConfigId=2,q=0,r=0,height=1,biomeWeights={{regionType=2,weight=1}}}
local area=generator:Generate(1,20260924,11,source)
local rule=config:GetTable('MapAreaEncounterTable'):Get(1)
local encounter=config:GetTable('CombatEncounterTable'):Get(rule.encounterId)
local function signature(plans)
    local cells,used,rooms={},{},{}
    for _,group in ipairs(plans) do
        assert(#group.cells==#encounter.enemyIds)
        local room=group.cells[1].roomId;assert(not rooms[room]);rooms[room]=true
        for _,cell in ipairs(group.cells) do
            assert(not cell.blocked and cell.layer==0 and not used[cell.index])
            assert(cell.roomId~=area.cells[area.entryIndex].roomId)
            used[cell.index]=true;cells[#cells+1]=cell.index
        end
    end
    assert(#plans==rule.groupCount);return table.concat(cells,',')
end
math.randomseed(31);local expected=math.random();math.randomseed(31)
assert(signature(Encounters.Plan(area,rule,encounter))==signature(Encounters.Plan(area,rule,encounter)))
assert(math.random()==expected)
print('PASS seeded enemy groups occupy distinct safe rooms without changing global RNG')

local flat=Layout.New({id=1,name='battle check',areaType=1,width=12,height=12,hexRadius=1.5,visionRadius=9,moveStepSeconds=.1},1,source,area.theme)
for _,cell in ipairs(flat.cells) do cell.blocked=false;cell.blocksSight=false end
local board=require('Game.Battle.BattleBoard').FromArea(flat,4,4,7)
local hero={Id=1,TemplateId=2,Team=1,HP=38,AP=4,MainUsed=false,Moved=false,Q=3,R=4}
local enemy={Id=101,TemplateId=4,Team=2,HP=34,Q=5,R=4}
local battle=require('Game.Battle.BattleSystem')()
battle.board=board;battle.skills=config:GetTable('CombatSkillTable');battle.stats=require('Game.Battle.CombatStats')(config)
battle.data={Winner='',ActiveId=1,UnitCount=2,GetUnitAt=function(_,i) return ({hero,enemy})[i+1] end}
flat:Find(4,4).blocked=true;flat:Find(4,4).blocksSight=true
local ok,reason=battle:CanUseSkill(2,101);assert(not ok and reason:find('遮挡') and hero.AP==4)
flat:Find(4,4).blocked=false;flat:Find(4,4).blocksSight=false
assert(battle:CanUseSkill(2,101))
board.externalOccupied={[Hex.Key(4,4)]=true}
board.allowed=function(cell) return cell.r<=4 end
for _,cell in ipairs(battle:Reachable()) do assert(cell.r<=4 and not (cell.q==4 and cell.r==4)) end
print('PASS area skill line of sight, external enemy occupancy and discovered movement')

local Squad=require('Game.MapArea.SquadMovement')
local positions={flat:Find(2,2).index,flat:Find(8,2).index,flat:Find(8,3).index,flat:Find(7,4).index}
local path={flat:Find(3,2).index}
local frames,why=Squad.Plan(flat,positions,path,function(cell) return not cell.blocked end)
assert(frames,why);assert(#frames>4)
for offset=1,#frames,4 do
    local used={};local nextPositions={}
    for i=1,4 do
        local index=frames[offset+i-1];local from,to=flat.cells[positions[i]],flat.cells[index]
        assert(not used[index] and (index==from.index or flat:CanStep(from,to)))
        for j=1,i-1 do assert(not (index==positions[j] and nextPositions[j]==positions[i])) end
        used[index]=true;nextPositions[i]=index
    end
    positions=nextPositions
end
assert(positions[1]==path[1])
for _,index in ipairs(positions) do assert(#flat:FindPath(positions[1],index)<=4) end
print('PASS dispersed survivors regroup on real navigation edges before continuing exploration')
config:OnShutdown()
