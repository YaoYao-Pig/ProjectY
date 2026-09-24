-- 局部地图生成注册器。入口只提供大地图上下文，各类型策略独立生成静态布局。
local Class=require('Core.Class')
local Random=require('Game.Map.SeededRandom')
local Layout=require('Game.MapArea.MapAreaLayout')
local Generator=Class('MapAreaGenerator')
local function color(value)
    assert(type(value)=='string' and value:match('^#%x%x%x%x%x%x$'),'Invalid MapArea color')
    return {tonumber(value:sub(2,3),16)/255,tonumber(value:sub(4,5),16)/255,tonumber(value:sub(6,7),16)/255}
end
function Generator:ctor(config)
    self.config=config;self.definitions=config:GetTable('MapAreaTable');self.strategies={}
end
function Generator:Register(areaType,strategy,tableName,themeTableName)
    assert(not self.strategies[areaType],'Duplicate MapArea strategy')
    local profiles=self.config:GetTable(tableName)
    for _,definition in ipairs(self.definitions:All()) do
        if definition.areaType==areaType then strategy.Validate(profiles:Get(definition.profileId)) end
    end
    local themes={}
    for _,row in ipairs(self.config:GetTable(themeTableName or 'MapAreaThemeTable'):All()) do
        assert(not themes[row.regionType],'Duplicate MapArea region theme')
        color(row.floorColor);color(row.wallColor);self.config:GetTable('MapAssetTable'):Get(row.assetId)
        themes[row.regionType]=row
    end
    self.strategies[areaType]={strategy=strategy,profiles=profiles,themes=themes}
end
function Generator:CanGenerate(areaId) return self.strategies[self.definitions:Get(areaId).areaType]~=nil end
function Generator:Generate(areaId,worldSeed,pointId,source)
    local definition=self.definitions:Get(areaId)
    local implementation=assert(self.strategies[definition.areaType],'MapArea strategy is not implemented')
    Random(worldSeed)
    assert(math.tointeger(pointId) and pointId>0,'MapArea needs a stable positive point ID')
    local theme=assert(implementation.themes[source.regionType],'Missing theme for source Region')
    local seed=((math.tointeger(worldSeed) ~ (pointId*2654435761)) + definition.seedSalt) & 0xffffffff
    local random=Random(seed)
    local area=Layout.New(definition,seed,source,theme)
    implementation.strategy.Generate(area,implementation.profiles:Get(definition.profileId),random,self.config)
    if area.areaType==2 then require('Game.MapArea.TownSurfaces').Apply(area,implementation.profiles:Get(definition.profileId),self.config) end
    local floor,wall,total={0,0,0},{0,0,0},0
    for _,weight in ipairs(source.biomeWeights) do
        local blend=assert(implementation.themes[weight.regionType],'Missing boundary MapArea theme')
        local a,b=color(blend.floorColor),color(blend.wallColor)
        for i=1,3 do floor[i]=floor[i]+a[i]*weight.weight;wall[i]=wall[i]+b[i]*weight.weight end
        total=total+weight.weight
    end
    assert(math.abs(total-1)<0.00001,'MapArea source biome weights must sum to one')
    for _,cell in ipairs(area.cells) do
        local noise=random:Noise(cell.q,cell.r,4,2897)
        if cell.height==nil then cell.height=(noise-0.5)*theme.heightNoise end
        cell.wallHeight=theme.wallHeight*(0.94+noise*0.12)
        cell.color={}
        local base=cell.kind=='wall' and wall or floor
        if cell.floorAccent then
            local accent=color(cell.floorAccent);base={}
            local weight=cell.floorAccentWeight or .45
            for i=1,3 do base[i]=floor[i]*(1-weight)+accent[i]*weight end
        end
        for i=1,3 do cell.color[i]=base[i]*(0.94+noise*0.12) end
    end
    return Layout.Freeze(area)
end
return Generator
