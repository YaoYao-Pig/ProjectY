-- 山腰云带只描述显示布局，独立位置噪声不会影响地形与玩法随机序列。
local Class=require('Core.Class')
local Hex=require('Game.Map.HexGrid')
local Random=require('Game.Map.SeededRandom')
local Atmosphere=Class('MapAtmosphere')
function Atmosphere:ctor(config)
    self.rows=config:GetTable('MapAtmosphereTable'):All()
    for _,row in ipairs(self.rows) do
        assert(row.altitudeFraction>0 and row.altitudeFraction<1 and row.spacing>=1 and row.opacity>0 and row.opacity<1,'Invalid mountain atmosphere profile')
    end
end
function Atmosphere:Build(map)
    local random=Random(map.seed ~ 0x436c6f75)
    for _,row in ipairs(self.rows) do for _,region in ipairs(map:GetRegionsByType(row.regionType)) do
        local peak,base=-math.huge,math.huge
        for _,cell in ipairs(region.cells) do peak=math.max(peak,cell.height);base=math.min(base,cell.height) end
        if peak>=row.minPeakHeight and peak-base>=row.minRelief then
            local altitude=base+(peak-base)*row.altitudeFraction
            local buckets={}
            for _,cell in ipairs(region.cells) do
                if cell.height>altitude-row.width and cell.height<altitude+row.height then
                    local key=math.floor(cell.q/row.spacing)..':'..math.floor(cell.r/row.spacing)
                    local rank=random:Noise(cell.q,cell.r,1,431)
                    if not buckets[key] or rank>buckets[key].rank then buckets[key]={cell=cell,rank=rank} end
                end
            end
            -- 以region.cells稳定顺序输出，不依赖pairs迭代顺序。
            for _,cell in ipairs(region.cells) do
                local key=math.floor(cell.q/row.spacing)..':'..math.floor(cell.r/row.spacing)
                if buckets[key] and buckets[key].cell==cell then
                    local x,_,z=Hex.ToWorld(cell.q,cell.r,0,map.hexRadius)
                    local phase=random:Noise(cell.q,cell.r,1,439)
                    map.clouds[#map.clouds+1]={x=x,y=altitude+(phase-.5)*row.height,z=z,
                        width=row.width*map.hexRadius,height=row.height*map.hexRadius,opacity=row.opacity,phase=phase*6.2831853,
                        drift=row.drift*map.hexRadius}
                end
            end
        end
    end end
end
return Atmosphere
