-- Compatibility entry point for existing menu/origin native checks.
local previous=CaptureMenuScene
if CaptureStartMenu and not previous then
    CaptureMenuScene=function(name)if name=='create' then CaptureStartMenu()end end
end
local ok,result=xpcall(function()
    local source=CS.System.IO.File.ReadAllText('Tools/Tests/start_menu_scene_integration.lua')
    return assert(load(source,'@start_menu_scene_integration'))()
end,debug.traceback)
CaptureMenuScene=previous
if not ok then error(result)end
return result
