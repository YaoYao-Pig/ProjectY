return function(command,demo)
    local main=require('Main')
    if command=='open' then
        local data=main:Get('Adventure').data
        if data.Phase~='map' and data.Phase~='area' then return end
        if data.Phase=='area' then main:Get('MapArea'):Stop() end
        main:Get('UI'):Open('Inventory',{demo=demo})
    elseif command=='close' then main:Get('UI'):Close('EquipmentWorkbench');main:Get('UI'):Close('Inventory')
    else error('Unknown equipment UI command: '..tostring(command)) end
end
