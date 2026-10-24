-- 骑士审判场的真实配置生成、南北连通与四人支援部署；不启动 Unity。
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(config:GetEnum('MapArea','E_MapAreaType').TrialGround,
    require('Game.MapArea.TrialGroundGenerator'),'MapAreaTrialGroundTable','MapAreaTrialGroundThemeTable')
local Hex=require('Game.Map.HexGrid')
local Squad=require('Game.MapArea.SquadMovement')
local function generate(kind,seed)
    return generator:Generate(60,seed,3060,{regionType=kind,biomeWeights={{regionType=kind,weight=1}}})
end
local function signature(area)
    local result={}
    for _,cell in ipairs(area.cells) do result[#result+1]=cell.kind..':'..tostring(cell.blocked)..':'..cell.height end
    for _,prop in ipairs(area.props) do result[#result+1]=table.concat({prop.assetId,prop.q,prop.r,prop.height,prop.yaw},':') end
    for _,npc in ipairs(area.decorativeNpcs) do result[#result+1]=table.concat({npc.id,npc.spawnIndex,npc.x,npc.y,npc.z,npc.yaw},':') end
    return table.concat(result,'|')
end
local checked=0
for _,theme in ipairs(config:GetTable('MapAreaTrialGroundThemeTable'):All()) do
    local area=generate(theme.regionType,20261024)
    local queue,seen,head={area.entryIndex},{[area.entryIndex]=true},1
    while head<=#queue do
        local cell=area.cells[queue[head]];head=head+1
        assert(cell.layer==0 and cell.height==0,'Combat navigation must remain on one flat layer')
        for _,other in ipairs(area:Neighbors(cell)) do if not seen[other.index] then seen[other.index]=true;queue[#queue+1]=other.index end end
    end
    assert(#queue==area.walkableCount and #queue>=100 and seen[area.goalIndex],'Trial arena or entrances are disconnected')
    local plan=assert(area.encounterPlans[1]);assert(#area.encounterPlans==1 and plan.encounterId==301 and #plan.cells==4)
    local occupied={}
    for _,cell in ipairs(plan.cells) do
        assert(seen[cell.index] and not occupied[cell.index] and not cell.blocked)
        occupied[cell.index]=true
    end
    local entry=area.cells[area.entryIndex];local knight=plan.cells[4]
    assert(entry.r<knight.r and Hex.Distance(entry.q,entry.r,knight.q,knight.r)<=4,'Knight must be within immediate support distance')
    for i=1,3 do assert(plan.cells[i].r>knight.r and area:CanSee(knight,plan.cells[i])) end
    local deployed=Squad.Deploy(area,area.entryIndex,4,function(cell) return not cell.blocked and not occupied[cell.index] end)
    for _,index in ipairs(deployed) do assert(not occupied[index] and seen[index]);occupied[index]=true end
    local benches,gates,judge=0,0,0
    for _,prop in ipairs(area.props) do
        assert(prop.layer==0 and prop.scaleX>0 and prop.scaleY>0 and prop.scaleZ>0)
        if prop.assetId==27 then
            benches=benches+1
            assert(area.cells[prop.cells[1]].blocked and prop.height>0,'Audience benches must stay outside navigation')
        elseif prop.assetId==110 then gates=gates+1
        elseif prop.assetId==34 then judge=judge+1 end
    end
    assert(benches==36 and gates==2 and judge==1,'Trial scene is missing its stands, gates or judging table')
    assert(#area.npcs==0,'Decorative spectators must not change persistent NPC count in existing trial saves')
    assert(#area.decorativeNpcs==14,'Trial spectators and judging party are incomplete')
    local displays,labels,western,eastern,entrance={},{},0,0,0
    local originX,_,originZ=Hex.ToWorld(16,16,0,area.hexRadius)
    for _,npc in ipairs(area.decorativeNpcs) do
        local cell=area.cells[npc.spawnIndex]
        assert(npc.id<0 and not displays[npc.id] and cell.blocked and cell.renderGround and not occupied[cell.index])
        assert(math.abs(npc.y-cell.height-.015)<.00001,'Display NPC floats above or clips through its scenery floor')
        displays[npc.id]=true
        if npc.showName then labels[npc.name]=true end
        if npc.x-originX<-9 then western=western+1;assert(npc.yaw==90)
        elseif npc.x-originX>9 then eastern=eastern+1;assert(npc.yaw==270)
        elseif npc.z<originZ-10 then entrance=entrance+1 end
    end
    assert(western==4 and eastern==5 and entrance==2,'Spectators must be dispersed around both stands and the southern approach')
    assert(labels['主持审判的领主'] and labels['领主侍卫'] and labels['审判书记'],'Judging party identities must remain readable')
    assert(not pcall(function() area.cells[area.entryIndex].blocked=true end),'Generated trial layout must remain immutable')
    checked=checked+1
end
local a=generate(1,20261024)
assert(signature(a)==signature(generate(1,20261024)),'Repeated trial generation must be deterministic')
assert(signature(a)==signature(generate(1,7)),'A fixed trial arena must preserve fair positions across seeds')
local window=require('Game.Battle.BattleBoard').FromArea(a,16,16,12,0)
for _,cell in ipairs(a.encounterPlans[1].cells) do assert(window:Find(cell.q,cell.r)==cell,'Battle window must preserve trial terrain') end
local snapshot=require('Game.MapArea.MapAreaSystem').LayoutSnapshot({config=config,appearance=require('Game.Adventure.PawnAppearance').New(config),ActiveLayout=function() return a end})
assert(#snapshot.npcs==#a.decorativeNpcs and #a.npcs==0,'Display snapshot must not mutate the saved NPC layout')
for _,npc in ipairs(snapshot.npcs) do assert(npc.decorative and npc.id<0 and npc.narrativeId==0 and #npc.appearance.parts>=2) end
print(string.format('PASS trial ground: %d themes, %d walkable cells, 4 support spawns, %d scene props, %d decorative NPCs, saved NPC count unchanged',checked,a.walkableCount,#a.props,#a.decorativeNpcs))
