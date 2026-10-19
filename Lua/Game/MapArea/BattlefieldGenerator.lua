-- 事件战斗转为可保留的局部战场，复用原小战场半径、障碍与敌方部署坐标。
local Hex=require('Game.Map.HexGrid')
local Elevation=require('Game.MapArea.BattlefieldElevation')
local Generator={}
function Generator.Validate(row) assert(row.surfaceId>0,'Battlefield surface is required');Elevation.Validate(row) end
function Generator.Generate(area,profile,random,config)
    local encounter=config:GetTable('CombatEncounterTable'):Get(assert(area.source.encounterId))
    local board=require('Game.Battle.BattleBoard').Create(encounter.radius,area.seed,area.source.obstacleChance or encounter.obstacleChance)
    area.highland=Elevation.Apply(board,profile,random)
    area.name=encounter.name..' · 战场';area.width=board.radius*2+1;area.height=area.width
    area.cells={};area.cellsByKey={};area.props={};area.corridorRadius=0;area.encounterPlans={}
    local surface=area.source.surfaceId or profile.surfaceId
    local props=area.source.propIds
    for _,old in ipairs(board.cells) do
        local cell={index=#area.cells+1,q=old.q,r=old.r,layer=0,height=old.height,elevation=old.elevation,walkMask=63,blocked=old.blocked,
            blocksSight=old.blocked and props~=nil and #props>0,kind=old.blocked and 'wall' or 'floor',roomId=1,roomOwner=1,roomTier=1,obstacleId=0,
            reserved=true,neighbors={},surfaceId=surface,sideSurfaceId=surface}
        area.cells[cell.index]=cell;area.cellsByKey[Hex.Key(cell.q,cell.r)]=cell
        if old.blocked and props and #props>0 then
            cell.kind='floor';local scale=.82+random:Integer(0,10000)/10000*.25
            area.props[#area.props+1]={assetId=props[random:Integer(1,#props)],q=cell.q,r=cell.r,
                rotation=random:Integer(0,5),scale=scale/area.hexRadius,scaleX=scale,scaleY=scale,scaleZ=scale,cells={cell.index}}
        end
        if not cell.blocked then area.walkableCount=area.walkableCount+1 end
    end
    for _,cell in ipairs(area.cells) do for direction=1,6 do
        local q,r=Hex.Neighbor(cell.q,cell.r,direction);local other=area:Find(q,r)
        cell.neighbors[direction]=other and other.index or 0
    end end
    area.entryIndex=assert(area:Find(-board.radius,0)).index
    area.goalIndex=assert(area:Find(board.radius,0)).index
    area.rooms={{id=1,name='战场',tier=1,presetId=0,center=area:Find(0,0).index}}
    local enemies=require('Game.Battle.BodyFootprints').Deploy(area,encounter,require('Game.Animals.AnimalRules').New(config))
    area.encounterPlans[1]={id=1,encounterId=encounter.id,cells=enemies,team=2}
end
return Generator
