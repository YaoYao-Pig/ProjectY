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

-- The rider uses the same static body/seat and fixed multi-cell projection as the wild legend.
CS={ProjectY={Data={AnimalCompanionState={Independent=function()return false end}}}}
local animals=require('Game.Animals.AnimalRules').New(config)
local stats={animals=animals,traits=config:GetTable('CombatTraitTable'),equipment={ActorVisual=function()return nil end},
    Template=function(_,actor)return config:GetTable('CombatUnitTable'):Get(actor.TemplateId)end}
local area={Find=function(_,q,r,layer)return {q=q,r=r,index=1+q+2*r,layer=layer or 0}end}
local snapshot=require('Game.Battle.CombatSnapshot')
local rider={Id=1,TemplateId=1,TraitCount=0,Q=0,R=0,Team=1,HP=20,MaxHP=20}
for _,unit in ipairs({701,702,703,704}) do
    local species=assert(animals.byUnit[unit],'Legendary animal must have a configured species')
    rider.MountedAnimal={Id=unit,TemplateId=unit,AnimalSpeciesId=species.id}
    local row=snapshot(rider,stats,appearance,area)
    assert(row.fixedFootprint and #row.occupiedCells==#species.footprintQ)
    assert(row.appearance.riding.body.id==(unit<=702 and 401 or 402),'Mounted body must preserve the legendary static model')
    for i,value in ipairs(species.riderSeat) do assert(row.appearance.riding.seat[i]==value) end
end
rider.MountedAnimal={Id=201,TemplateId=201,AnimalSpeciesId=animals.byUnit[201].id}
assert(not snapshot(rider,stats,appearance,area).fixedFootprint,'Ordinary mounts retain normal facing')
rider.MountedAnimal=nil
local unmounted=snapshot(rider,stats,appearance,area)
assert(not unmounted.fixedFootprint and not unmounted.appearance.riding and #unmounted.occupiedCells==1)
print('PASS legendary riding projection: original models, configured seats, full fixed footprint and ordinary mount/dismount regression')
config:OnShutdown()
