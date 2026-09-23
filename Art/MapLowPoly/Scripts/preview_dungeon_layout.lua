-- Edit Mode 美术验收入口：复用真实远征配方、地牢入口和生产生成器，返回一次性显示快照。
local Registry=require('Core.SystemRegistry')
local registry=Registry(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
local ok,layout,state=xpcall(function()
    registry:Start()
    local config,areas=registry:Get('Config'),registry:Get('MapArea')
    local recipe=config:GetTable('AdventureDemoTable'):Get(1)
    local map=registry:Get('Map'):Generate(recipe.seed,recipe.regionIds)
    Services.Adventure:Reset(recipe.seed)
    for i,id in ipairs(recipe.partyIds) do
        local actor=Services.Adventure:AddPartyActor(i,id);actor:SetMaxHP(1);actor:Restore()
    end
    for i,site in ipairs(areas:Entrances(map)) do
        site.id=i
        if areas:CanEnter(site) then
            assert(areas:Enter(site,recipe.seed))
            return areas:LayoutSnapshot(),{area=areas:Snapshot()}
        end
    end
    error('The preview world recipe contains no implemented MapArea entrance')
end,debug.traceback)
registry:Shutdown()
if not ok then error(layout,0) end
return layout,state
