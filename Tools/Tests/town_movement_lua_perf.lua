-- 有限纯 Lua 基准；使用真实城镇配置，不启动 Unity、不初始化完整远征。
-- 毫秒数不含真实 xLua/C# 开销；Revision/角色字段计数用于量化桥接放大。
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local data=file:read('*a');file:close();return data
end}})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local AreaSystem=require('Game.MapArea.MapAreaSystem')
local Squad=require('Game.MapArea.SquadMovement')
local Residents=require('Game.MapArea.TownResidents')
local Construction=require('Game.Battle.Construction')
local Terrain=require('Game.MapArea.ConstructionTerrain')
local function profile(base,projected)
    local counts={records=0,revisions=0,shapes=0,finds=0,canStep=0,pathMs=0,planMs=0,actorReads=0,npcReads=0,npcMoves=0}
    local data=setmetatable({Count=0},{__index=function(_,key)assert(key=='Revision');counts.revisions=counts.revisions+1;return 0 end})
    local construction={data=data,cache={},cacheRevision=-1,Records=Construction.Records,Record=function(self,...)
        counts.records=counts.records+1;return Construction.Record(self,...)
    end}
    local function measure(source)
        local area=setmetatable({}, {__index=source})
        function area:Find(...)counts.finds=counts.finds+1;return source.Find(self,...) end
        function area:CanStep(...)counts.canStep=counts.canStep+1;return source.CanStep(self,...) end
        function area:FindPath(...)local time=os.clock();local result=source.FindPath(self,...);counts.pathMs=counts.pathMs+(os.clock()-time)*1000;return result end
        if source.NavigationView then function area:NavigationView()return measure(source:NavigationView()) end end
        return area
    end
    local area=measure(projected and Terrain.Wrap(base,construction,1) or base)
    local animals=require('Game.Animals.AnimalRules').New(config)
    local actors={};for i=1,4 do
        local values={Id=i,HP=1,TemplateId=1}
        actors[i]=setmetatable({},{__index=function(_,key)counts.actorReads=counts.actorReads+1;return values[key] end})
    end
    local initialNpc={};for _,npc in ipairs(base.npcs) do initialNpc[npc.spawnIndex]=true end
    local deployAllowed=function(cell)return not initialNpc[cell.index] end
    local positions=Squad.Deploy(base,base.entryIndex,4,deployAllowed)
    local npcRows={};for _,definition in ipairs(base.npcs) do
        local npc={Id=definition.id,CellIndex=definition.spawnIndex,Present=true,PatrolCursor=0,elapsed=0}
        function npc:Due(dt,interval)self.elapsed=self.elapsed+dt;if self.elapsed<interval then return false end;self.elapsed=0;return true end
        npcRows[#npcRows+1]=npc
    end
    local state={CellIndex=positions[1],MemberCount=4,NpcCount=#npcRows,EncounterCount=0,InteractionKind=0,InteractionId=0}
    function state:GetMemberIdAt(i)return i+1 end
    function state:GetMemberCellAt(i)return positions[i+1] end
    function state:GetNpcAt(i)counts.npcReads=counts.npcReads+1;return npcRows[i+1] end
    function state:IsKnown()return true end
    function state:IsNpcOccupied(index)for _,npc in ipairs(npcRows) do if npc.CellIndex==index then return true end end;return false end
    function state:IsSquadReserved(index)for _,cell in ipairs(positions) do if cell==index then return true end end;return false end
    function state:SetSquadRoute(frames)self.frames=frames end
    function state:MoveNpc(id,index,cursor,pause)local npc=npcRows[id];npc.CellIndex=index;npc.PatrolCursor=cursor;npc.elapsed=-pause;counts.npcMoves=counts.npcMoves+1 end
    local system=AreaSystem();system.data={Active=state,ActiveSiteId=1};system.layouts={[1]=area};system.townType=2
    system.adventure={Phase='area',PartyCount=4,GetPartyAt=function(_,index)return actors[index+1] end};system.combatStats={animals=animals}
    system.AdvanceMovement=function()end -- 只计命令规划，不模拟 C# 路线推进。
    function system:SquadFootprint(...)
        local shape=AreaSystem.SquadFootprint(self,...)
        return function(...)counts.shapes=counts.shapes+1;return shape(...) end
    end
    local originalPlan=Squad.Plan
    Squad.Plan=function(...)local time=os.clock();local a,b=originalPlan(...);counts.planMs=counts.planMs+(os.clock()-time)*1000;return a,b end
    local function reset()for key in pairs(counts) do counts[key]=0 end end
    local function report(label,time,n)
        print(string.format('area=%d %s %s samples=%d totalMs=%.3f avgMs=%.3f pathMs=%.3f planMs=%.3f shapes=%d Find=%d CanStep=%d Record=%d Revision=%d actorFields=%d npcReads=%d npcMoves=%d',
            base.configId,projected and 'projection' or 'static',label,n,time,time/n,counts.pathMs,counts.planMs,counts.shapes,counts.finds,counts.canStep,counts.records,counts.revisions,counts.actorReads,counts.npcReads,counts.npcMoves))
    end
    local allowed=function(cell)return not state:IsNpcOccupied(cell.index) end
    local path
    for _,facility in ipairs(base.facilities) do
        local candidate=base:FindPath(base.entryIndex,facility.entryIndex,allowed)
        if candidate and (not path or #candidate>#path) then path=candidate end
    end
    assert(path and #path>=12,'Performance fixture needs a nontrivial connected route')
    local prefix={};for i=1,math.min(20,#path) do prefix[i]=path[i] end
    collectgarbage('collect');reset();local time=os.clock()
    for _,index in ipairs(prefix) do
        local ok,reason=system:MoveToIndex(index,false);assert(ok,reason)
        local frames=state.frames;for i=1,4 do positions[i]=frames[#frames-4+i] end;state.CellIndex=positions[1]
    end
    report('adjacent-commands',(os.clock()-time)*1000,#prefix)
    positions=Squad.Deploy(base,base.entryIndex,4,deployAllowed);state.CellIndex=positions[1]
    collectgarbage('collect');reset();time=os.clock()
    local ok,reason=system:MoveToIndex(prefix[#prefix],false);assert(ok,reason)
    report('click-20-steps',(os.clock()-time)*1000,1)
    Squad.Plan=originalPlan
    collectgarbage('collect');reset();time=os.clock()
    for _=1,120 do Residents.Tick(area,state,1/60) end
    report('resident-120-ticks',(os.clock()-time)*1000,120)
end
local requested=rawget(_G,'TownMovementPerfArea')
for _,id in ipairs(requested and {requested} or {2,6}) do
    local area=generator:Generate(id,20260924,11,{regionId=1,regionType=1,regionConfigId=1,q=0,r=0,height=1,biomeWeights={{regionType=1,weight=1}}})
    print(string.format('fixture area=%d cells=%d walkable=%d NPCs=%d',id,#area.cells,area.walkableCount,#area.npcs))
    profile(area,false);profile(area,true)
end
