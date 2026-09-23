-- 定向检查真实导出配置、装备挂点和固定人物/可调地格尺度，不启动 Unity。
package.path='Lua/?.lua;'..package.path
local Config=require('Config.ConfigSystem')
local config=Config()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Appearance=require('Game.Adventure.PawnAppearance')
local appearance=Appearance.New(config)
local count=0
for _,template in ipairs(config:GetTable('PawnTemplateTable'):All()) do
    local snapshot=appearance:Template(template.unitId)
    assert(snapshot.templateId==template.id and #snapshot.parts==#template.partIds)
    for _,part in ipairs(snapshot.parts) do
        local file=assert(io.open(part.path,'rb'),'Missing pawn part: '..part.path)
        assert(file:seek('end')>100);file:close()
    end
    count=count+1
end
assert(count>=3)
assert(not pcall(function() appearance:Resolve({1,2,6,7}) end),'Two head items must conflict')
assert(not pcall(function() appearance:Resolve({1,9}) end),'Base is mandatory')
assert(not pcall(function() appearance:Template(99999) end),'Unknown actor template must fail explicitly')
local unarmed=appearance:Resolve({1,2})
assert(#unarmed==2,'Empty equipment slots are valid')
assert(config:GetTable('MapAreaTable'):Get(1).hexRadius==1.5)
print('PASS pawn appearance: '..count..' templates, resources, slot conflicts, unarmed loadout, 1.5 cell radius')
