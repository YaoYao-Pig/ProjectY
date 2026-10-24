return function(demo,mode,errorMessage)
    local main=require('Main')
    local adventure=main:Get('Adventure')
    if adventure.map and adventure.data.Phase=='area' then main:Get('MapArea'):Stop()end
    main:Get('UI'):Open('StartMenu',{demo=assert(demo),mode=mode or 'home',errorMessage=errorMessage})
end
