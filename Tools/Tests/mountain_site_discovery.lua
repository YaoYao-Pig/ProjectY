-- Mountain territory can be discovered before its fixed foot entry. No Editor/native Data needed.
package.path='Lua/?.lua;'..package.path
local Fog=require('Game.Adventure.WorldFog')
local Hex=require('Game.Map.HexGrid')
local cells={{q=0,r=0,regionId=12},{q=1,r=0,regionId=12},{q=5,r=0,regionId=1}}
local map={cells=cells,GetCells=function(self)return self.cells end}
local known,order,calls={},{},0
local data={KnownCount=0,IsKnown=function(_,index)return known[index]==true end,
    GetKnownAt=function(_,index)calls=calls+1;return order[index+1] end}
local fog=setmetatable({data=data},Fog);fog:Bind(map)
assert(not fog:Known(0,0,12))
known[2]=true;order[1]=2;data.KnownCount=1
assert(not fog:Known(0,0),'The foot entry must remain individually undiscovered')
assert(fog:Known(0,0,12),'Seeing a mountain slope must make the mountain site discoverable')
assert(not fog:Known(5,0,1),'A different unknown region must remain hidden')
for _=1,20 do assert(fog:Known(0,0,12)) end
assert(calls==1,'Region discovery query rescanned previously indexed native cells')
known[3]=true;order[2]=3;data.KnownCount=2
assert(fog:Known(6,0,1) and calls==2)
known={};order={};data.KnownCount=0
assert(not fog:Known(0,0,12),'Reset discovery leaked the previous mountain site')
known[3]=true;order[1]=3;data.KnownCount=1;fog:Bind(map)
assert(not fog:Known(0,0,12) and fog:Known(5,0,1),'Rebinding a restored world must reconstruct the region query index')
print('PASS mountain territory discovery before foot entry, unknown-region isolation, incremental native queries and rebind')
