-- Single registration entry point. Dependencies determine initialization and reverse teardown order.
return function(registry)
    registry:Register('Config', require('Config.ConfigSystem'))
    registry:Register('Localization', require('Config.LocalizationSystem'), { 'Config' })
    registry:Register('PlayerModel', require('Game.PlayerModelSystem'), { 'Config' })
    registry:Register('UI', require('UI.UISystem'), { 'PlayerModel', 'Localization' })
end
