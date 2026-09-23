-- 系统统一注册入口；依赖关系决定初始化顺序，关闭时按相反顺序释放。
return function(registry)
    registry:Register('Config', require('Config.ConfigSystem'))
    registry:Register('Localization', require('Config.LocalizationSystem'), { 'Config' })
    registry:Register('PlayerModel', require('Game.PlayerModelSystem'), { 'Config' })
    registry:Register('Map', require('Game.Map.MapSystem'), { 'Config' })
    registry:Register('MapArea', require('Game.MapArea.MapAreaSystem'), { 'Config' })
    registry:Register('Battle', require('Game.Battle.BattleSystem'), { 'Config' })
    registry:Register('AdventureEvents', require('Game.Adventure.EventSystem'), { 'Battle', 'PlayerModel' })
    registry:Register('Adventure', require('Game.Adventure.AdventureSystem'), { 'Map', 'MapArea', 'AdventureEvents' })
    registry:Register('UI', require('UI.UISystem'), { 'PlayerModel', 'Localization' })
end
