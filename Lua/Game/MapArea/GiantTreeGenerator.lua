local Terrain=require('Game.MapArea.NaturalTerrain')
local Hex=require('Game.Map.HexGrid')
local Tree={}
function Tree.Validate(row)
    Terrain.Validate(row)
    assert(row.rootHeight>=6 and row.trunkHeight>=30 and row.rootAssetId>0 and row.trunkAssetId>0,'Giant tree requires partial roots and trunk-base assets')
end
function Tree.Generate(area,row,random,config)
    Tree.Validate(row)
    local rootR=area.height-12
    local function rootCenter(v,side) return side*(4+(area.height/2-v)*.24) end
    Terrain.Begin(area,row,function(u,v,cell)
        local ridge=math.max(math.exp(-((u-rootCenter(v,-1))/2.3)^2),math.exp(-((u-rootCenter(v,1))/2.3)^2))
        local h=1+random:Noise(u,v,8,711)*1.5+ridge*row.rootHeight*(.4+cell.r/area.height*.6)
        local trunk=cell.r>rootR and math.abs(u)<18
        return h,(trunk or ridge>=.18) and row.rootSurfaceId or row.groundSurfaceId,trunk
    end)
    local anchors={{cell=Terrain.At(area,-3,7),height=2},{cell=Terrain.At(area,3,18),height=2.6},
        {cell=Terrain.At(area,-2,30),height=3.2},{cell=Terrain.At(area,1,42),height=4},
        {cell=Terrain.At(area,0,rootR-3),height=4.5}}
    Terrain.Trail(area,row,anchors)
    area.entryIndex=anchors[1].cell.index;area.goalIndex=anchors[#anchors].cell.index
    area.rooms={{id=1,name=row.entryName,tier=1,presetId=0,center=area.entryIndex},
        {id=2,name=row.rootName,tier=1,presetId=0,center=area.goalIndex}}
    -- The trunk continues beyond the far boundary: only its huge base and roots belong to this local scene.
    local base=Terrain.At(area,0,rootR+3);local footprint={}
    for _,cell in ipairs(area.cells) do
        local u=Terrain.Local(area,cell.q,cell.r)
        if cell.r>=rootR and math.abs(u)<18 then footprint[#footprint+1]=cell.index;cell.naturalBarrier=true;cell.blocksSight=true end
    end
    Terrain.Prop(area,config,base,row.trunkAssetId,1,0,footprint)
    local rootEmbed=config:GetTable('MapAssetTable'):Get(row.rootAssetId).referenceHeight*.6
    for _,side in ipairs({-1,1}) do for _,r in ipairs({20,34,48}) do
        local v=r-area.height/2;local cell=Terrain.At(area,rootCenter(v,side),r)
        local x,_,z=Hex.ToWorld(cell.q,cell.r,0,area.hexRadius)
        local yaw=side*-18;local angle=math.rad(yaw);local occupied={}
        for _,part in ipairs(area.cells) do
            local px,_,pz=Hex.ToWorld(part.q,part.r,0,area.hexRadius);local dx,dz=px-x,pz-z
            local across=dx*math.cos(angle)-dz*math.sin(angle)
            local along=dx*math.sin(angle)+dz*math.cos(angle)
            if math.abs(across)<=2.4 and math.abs(along)<=6.4 then
                assert(not part.reserved,'Giant root overlaps the exploration route')
                occupied[#occupied+1]=part.index;part.naturalBarrier=true;part.blocksSight=true;part.surfaceId=row.rootSurfaceId
            end
        end
        local prop=Terrain.Prop(area,config,cell,row.rootAssetId,1,yaw,occupied)
        -- The raised ground supplies the root's buried mass; expose only the sculpted upper bark.
        prop.height=cell.height-rootEmbed
    end end
    -- Ordinary trees remain at ordinary scale so the giant base has an unmistakable size reference.
    for _,r in ipairs({11,23,37,49}) do for _,side in ipairs({-1,1}) do
        local cell=Terrain.At(area,side*19,r)
        assert(not cell.reserved,'Scale-reference tree overlaps the root path')
        cell.blocked=true;cell.blocksSight=true
        Terrain.Prop(area,config,cell,row.treeAssetId,.85+random:Integer(0,25)/100,random:Integer(0,359))
    end end
    -- Reserve the actual ordinary-tree footprints before deriving the reachable domain.
    for _,prop in ipairs(area.props) do if prop.assetId==row.treeAssetId then area.cells[prop.cells[1]].naturalBarrier=true end end
    Terrain.Finish(area,row,config)
end
return Tree
