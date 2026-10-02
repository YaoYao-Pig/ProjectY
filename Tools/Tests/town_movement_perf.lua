-- Bounded Edit Mode benchmark: production planning + real C# occupancy, no expedition or Play.
local config=require('Config.ConfigSystem')();config:OnInit({services=Services})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local base=generator:Generate(6,20260925,11,{regionId=7,regionConfigId=2,regionType=2,q=0,r=0,height=1,biomeWeights={{regionType=2,weight=1}}})
local AreaSystem=require('Game.MapArea.MapAreaSystem');local Squad=require('Game.MapArea.SquadMovement')
local construction=require('Game.Battle.Construction').New(config,{})
local calls=0;local record=construction.Record
construction.Record=function(self,site,index)calls=calls+1;return record(self,site,index)end
local actors={{Id=1,TemplateId=1,HP=1},{Id=2,TemplateId=1,HP=1},{Id=3,TemplateId=1,HP=1},{Id=4,TemplateId=1,HP=1}}
local results={}
local function measure(area,name)
    local state=CS.ProjectY.Data.MapAreaStateData(1,#area.cells,area.entryIndex)
    for _,npc in ipairs(area.npcs) do state:AddNpc(npc.id,npc.spawnIndex) end
    local all={};for i=1,#area.cells do all[i]=i end;state:Reveal(all)
    local system=AreaSystem();system.data={Active=state,ActiveSiteId=1};system.layouts={[1]=area}
    system.adventure={Phase='area',PartyCount=4,GetPartyAt=function(_,i)return actors[i+1]end}
    system.combatStats={animals=require('Game.Animals.AnimalRules').New(config)}
    system.context={systems={Get=function()return {gameEffects={Tick=function()end}}end},services={}}
    -- Isolate navigation cost; periodic effects are outside this benchmark.
    system.townType=2;system.explorationRoundSeconds=3600
    local ids={1,2,3,4};local shape=system:SquadFootprint(area,ids)
    local allowed=function(cell)return not state:IsNpcOccupied(cell.index) end
    local positions=Squad.Deploy(area,area.entryIndex,4,allowed,shape)
    state:DeployMembers(ids,positions)
    local direction,near
    for d,index in ipairs(area.cells[positions[1]].neighbors) do
        local cell=area.cells[index]
        if area:CanStep(area.cells[positions[1]],cell) and allowed(cell) then direction,near=d,index;break end
    end
    assert(direction)
    local queue,dist,head={positions[1]},{[positions[1]]=0},1;local far
    while head<=#queue do
        local index=queue[head];head=head+1
        if dist[index]>=10 then far=index;break end
        for _,cell in ipairs(area:Neighbors(area.cells[index])) do if dist[cell.index]==nil and allowed(cell) then
            dist[cell.index]=dist[index]+1;queue[#queue+1]=cell.index
        end end
    end
    assert(far)
    local function run(label,count,action)
        state:DeployMembers(ids,positions);assert(action()) -- JIT/bridge warmup outside timing.
        collectgarbage('collect');calls=0
        local watch=CS.System.Diagnostics.Stopwatch.StartNew()
        for _=1,count do state:DeployMembers(ids,positions);local ok,reason=action();assert(ok,reason) end
        watch:Stop()
        results[#results+1]={name=name..' '..label,iterations=count,ms=watch.ElapsedTicks*1000/CS.System.Diagnostics.Stopwatch.Frequency,
            constructionLookups=calls,cells=#area.cells}
    end
    run('WASD one cell',12,function()return system:Walk(direction)end)
    run('click ten cells',3,function()return system:MoveToIndex(far,false)end)
    if name=='static' then
        run('snapshot + C# read',8,function()
            local snapshot=system:Snapshot()
            snapshot.constructionRevision=construction.data.Revision
            local view=CS.ProjectY.Samples.MapAreaViewData.ReadState({area=snapshot})
            assert(view.Known.Length==#area.cells and view.Visible.Length==#area.cells)
            return true
        end)
    end
end
measure(base,'static')
measure(construction:Layout(base,1),'construction overlay')
return results
