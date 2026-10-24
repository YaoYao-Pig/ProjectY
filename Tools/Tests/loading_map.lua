package.path='Lua/?.lua;'..package.path
local registry=require('Core.SystemRegistry')({ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end,LogError=error})
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
registry:Start()
local config,mapSystem=registry:Get('Config'),registry:Get('Map')
local expected=mapSystem:GenerateSeeded(42,2500)
local previous,count=0,0
local thread=coroutine.create(function()
    return mapSystem:GenerateSeeded(42,2500,function(value,stage)
        assert(value>=previous and value<=1 and type(stage)=='string')
        previous=value;count=count+1;coroutine.yield()
    end)
end)
local actual
repeat
    local ok,result=coroutine.resume(thread);assert(ok,result);actual=result
until coroutine.status(thread)=='dead'
assert(previous==1 and count>10 and #actual:GetCells()==2500)
local render=require('Game.Map.MapRenderSnapshot')
local function equal(a,b,path)
    assert(type(a)==type(b),'Type mismatch: '..path)
    if type(a)~='table' then assert(a==b,'Value mismatch: '..path);return end
    for key,value in pairs(a)do equal(value,b[key],path..'.'..tostring(key))end
    for key in pairs(b)do assert(a[key]~=nil,'Extra key: '..path..'.'..tostring(key))end
end
equal(render(expected),render(actual),'snapshot')
assert(config:GetTable('LoadingTipTable').Count==6)
registry:Shutdown()
print('PASS real 2500-cell map: yielding and synchronous render snapshots match exactly; '..count..' progress checkpoints')
