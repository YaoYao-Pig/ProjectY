-- Read-only HUD projection of the authoritative clock and weather at the party's world position.
local Weather=require('Game.Adventure.Weather')
local Model={};Model.__index=Model
local refreshSeconds=.25

function Model.New(adventure)
    local self=setmetatable({adventure=assert(adventure,'Weather dial requires an adventure')},Model)
    self:Reset()
    return self
end

function Model:Periods()
    local config=self.adventure.config
    local profile=config:GetTable('MapEnvironmentTable'):Get(1)
    local keys=config:GetTable('MapLightKeyTable')
    local day=keys:Get(profile.dialDayKeyId).hour
    local dusk=keys:Get(profile.dialDuskKeyId).hour
    local night=keys:Get(profile.dialNightKeyId).hour
    assert(day>=0 and day<dusk and dusk<night and night<24,'Weather dial light keys must be ordered within a day')
    return day,dusk,night
end

function Model:Reset()
    self.elapsed=0;self.lastSample=nil
end

function Model:Read(unscaledDt)
    assert(unscaledDt>=0 and unscaledDt<math.huge,'Weather dial requires finite unscaled delta time')
    local adventure=self.adventure
    local minutes=adventure.narrative.data.Minutes
    self.elapsed=self.elapsed+unscaledDt
    if not self.lastSample or self.elapsed>=refreshSeconds then
        -- Never catch up with several queries after a long frame, or carry excess time into the next query.
        self.elapsed=0
        local map=assert(adventure.map,'Weather dial requires an active world map')
        local phase=adventure.data.Phase
        local siteId=phase~='map' and adventure.data.Areas.ActiveSiteId or 0
        local x,z
        if siteId>0 then
            local site=assert(adventure.sites[siteId],'Active area lacks a world weather origin')
            x,z=site.x,site.z
        else
            -- Event/legacy battle/result phases retain the travel anchor. Water travel only changes
            -- the visual height; its world X/Z use this same map-coordinate contract.
            local travel=adventure.travel.data
            local y;x,y,z=map:GetCellWorldPosition(travel.Q,travel.R)
        end
        assert(type(x)=='number' and type(z)=='number','Weather dial requires a real world position')
        if not self.lastSample or self.map~=map or self.field~=adventure.weatherField or self.phase~=phase or
            self.siteId~=siteId or self.x~=x or self.z~=z or self.minutes~=minutes then
            self.lastSample=Weather.Query(adventure,x,z,minutes)
            self.cloud,self.rain=self.lastSample.Cloud,self.lastSample.Rain
            self.map,self.field,self.phase,self.siteId=map,adventure.weatherField,phase,siteId
            self.x,self.z,self.minutes=x,z,minutes
        end
    end
    -- Fractional minutes reach the needle every visible frame; the cached weather adds no per-frame table.
    return minutes,self.cloud,self.rain
end

return Model
