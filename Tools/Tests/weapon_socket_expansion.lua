-- Real config/rules and effect execution, with scalar C# adapters only.
-- Run after the root's unified export. No Editor, compilation or real save is used.
package.path='Lua/?.lua;'..package.path
local Gear=assert(loadfile('Tools/Tests/equipment_read_fixture.lua'))()
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local original={
    [1]={1,2},[601]={101,102},[602]={103,104},[603]={105,106},
    [2]={3},[40]={6},[41]={7},[42]={},[43]={},[44]={4},[45]={5},[46]={},
    [70]={},[71]={},[72]={},[73]={},[74]={},
    [604]={107,108},[605]={109,110},[606]={111,112},[607]={113,114},[608]={115,116},[609]={117,118},
    [610]={119},[611]={120},[612]={121},[613]={122,123},[614]={124,125},[615]={126,127},
    [616]={128},[617]={129},[618]={130},[619]={131},[620]={132},
}
local expected={
    [2]={'magazine','rail','muzzle','stock'},[3]={'catalyst','edge','grip','pommel'},
    [4]={'edge','grip','pommel'},[5]={'thruster','edge','grip','pommel'},
    [6]={'rail','bowlimb','bowstring'},[7]={'edge','grip','pommel'},
}
local sockets=config:GetTable('EquipmentSocketTable');local weapons=config:GetTable('EquipmentWeaponTable')
local newSockets,nonStaff,staffCount=0,0,0
for _,weapon in ipairs(weapons:All())do
    local before=assert(original[weapon.id],'Unexpected weapon scope')
    for i,id in ipairs(before)do assert(weapon.socketIds[i]==id,'Existing socket order/identity changed: '..weapon.id)end
    if weapon.categoryId==1 then
        staffCount=staffCount+1;assert(#weapon.socketIds==#before,'Staff sockets must remain unchanged')
    else
        nonStaff=nonStaff+1;local wanted=assert(expected[weapon.categoryId]);local kinds={}
        assert(#weapon.socketIds==#wanted and #weapon.socketIds<=4)
        for _,id in ipairs(weapon.socketIds)do
            local socket=sockets:Get(id);assert(socket.weaponItemId==weapon.id and not kinds[socket.kind]);kinds[socket.kind]=true
            if id>=201 then assert(id<=273);newSockets=newSockets+1 end
            assert(#socket.position==3 and #socket.rotation==3)
        end
        for _,kind in ipairs(wanted)do assert(kinds[kind],'Missing classified socket '..kind..' on '..weapon.id)end
    end
end
assert(nonStaff==30 and staffCount==4 and newSockets==73)
print('PASS all 30 non-staff weapons have their classified 3/4 sockets; 73 new IDs preserve every original prefix and all four staves')

local function collection()
    local result={Count=0,nextId=1,rows={}}
    function result:GetAt(i)return assert(self.rows[i+1])end
    function result:Find(id)for _,row in ipairs(self.rows)do if row.EffectId==id then return row end end end
    function result:Add(id,source,name,amount,duration)
        local row={Id=self.nextId,EffectId=id,SourceId=source,SourceName=name,Amount=amount,Remaining=duration,Elapsed=0,Stacks=1}
        self.nextId=self.nextId+1;self.rows[#self.rows+1]=row;self.Count=#self.rows;return row
    end
    function result:Refresh(id,source,name,amount,duration)
        for _,row in ipairs(self.rows)do if row.Id==id then row.SourceId=source;row.SourceName=name;row.Amount=amount;row.Remaining=duration;row.Elapsed=0;return end end
        error('Unknown fixture effect')
    end
    function result:Remove(id)
        for i,row in ipairs(self.rows)do if row.Id==id then table.remove(self.rows,i);self.Count=#self.rows;return end end
        error('Unknown fixture effect')
    end
    return result
end
local worn={}
CS.ProjectY.Data.EquipmentCombatState={DamageArmor=function(_,id,amount)worn[id]=(worn[id] or 0)+amount;return amount end,RefreshMaximum=function()end}
CS.ProjectY.Data.GameBuffState={Configure=function(row,ids,amounts,expiry,nextTick)
    row.ids={};row.amounts={};for i,id in ipairs(ids)do row.ids[i]=id;row.amounts[id]=amounts[i]end
    row.expiry=expiry;row.nextTick=nextTick
end,Amount=function(row,id)return assert(row.amounts[id])end}
local function actor(id)
    local row={Id=id,TemplateId=3,Team=id==1 and 1 or 2,TraitCount=0,HP=50,MaxHP=100,Guard=0,
        Effects=collection(),Growth={TalentCount=0,SkillCount=0,GetAttribute=function()return 30 end,GetRank=function()return 1 end}}
    function row:Heal(amount)local actual=math.min(self.MaxHP-self.HP,amount);self.HP=self.HP+actual;return actual end
    function row:Damage(amount)local actual=math.min(self.HP,amount);self.HP=self.HP-actual;return actual end
    function row:SetGuard(amount)self.Guard=math.max(self.Guard,amount)end
    return row
end
local source,target=actor(1),actor(2)
local data={WearableCount=0,main=nil,Equipped=function(self,id)return id==1 and self.main or nil end,
    Offhand=function()return nil end,Worn=function()return nil end}
local stats=require('Game.Battle.CombatStats')(config,data);local rules=stats.equipment
local function resolve(weaponId,skillId,attached)
    data.main=Gear(1,weaponId,1)
    function data.main:GetRune(id)return attached and attached[sockets:Get(id).kind] or 0 end
    return rules:Skill(source,skillId,stats)
end
local hosts={grip={40,10},pommel={44,12},bowlimb={46,2},bowstring={618,1618},muzzle={604,1604},stock={604,1604}}
local function count(values,wanted)local total=0;for _,id in ipairs(values)do if id==wanted then total=total+1 end end;return total end
local function close(a,b)return math.abs(a-b)<.000001 end
local counts={}
for id=730,741 do
    local rune=rules.runes:Get(id);local host=assert(hosts[rune.slotKind]);counts[rune.slotKind]=(counts[rune.slotKind]or 0)+1
    local baseline=resolve(host[1],host[2]);local base=rules.skills:Get(host[2]);local shared=table.concat(base.effectIds,',')
    local skill=resolve(host[1],host[2],{[rune.slotKind]=id})
    assert(close(skill.damageScale,baseline.damageScale*rune.damageMultiplier))
    assert(skill.hitChance==math.max(0,math.min(100,baseline.hitChance+rune.hitBonus)))
    assert(skill.range==math.max(1,baseline.range+rune.rangeBonus) and skill.cooldownTurns==math.max(0,baseline.cooldownTurns+rune.cooldownBonus))
    assert(skill.maxTargets==math.max(baseline.maxTargets,rune.maxTargets) and skill.splashRadius==math.max(baseline.splashRadius,rune.splashRadius))
    assert(skill.cost==baseline.cost and skill.shots==baseline.shots and skill.ammoPerShot==baseline.ammoPerShot)
    for _,effectId in ipairs(rune.onHitEffectIds)do assert(count(skill.effectIds,effectId)==count(base.effectIds,effectId)+1)end
    assert(table.concat(base.effectIds,',')==shared,'Shared skill definition was mutated')
    assert(#require('Game.Equipment.EquipmentPresentation').Attachment(rules,id)>30)
    local item=rules.items:Get(id);local asset=rules.assets:Get(item.assetId)
    assert(item.assetId==id and item.kind=='module' and item.iconMode=='model')
    assert(asset.modelPath=='Assets/DynamicAsset/SocketExpansion202610/Models/Socket_'..id..'.fbx')
    assert(asset.prefabPath=='Assets/DynamicAsset/SocketExpansion202610/Prefabs/Socket_'..id..'.prefab')
    assert(item.iconPath=='Assets/DynamicAsset/SocketExpansion202610/Icons/Item_'..id..'.png')
    local shop=config:GetTable('ShopEntryTable'):Get(id);assert(shop.itemId==id and shop.templateId==1 and shop.chance>0)
    local price=config:GetTable('WorldTradePriceTable'):Get(id)
    assert(price.itemId==id and price.price==shop.price,'Attachment needs its caravan buy/sell price: '..id)
end
for kind in pairs(hosts)do assert(counts[kind]==2)end
assert(config:GetTable('LootPoolTable'):Get(5).mode=='weighted')
for id=730,733 do local entry=config:GetTable('LootEntryTable'):Get(id);assert(entry.poolId==5 and entry.weight>0)end
print('PASS 12 attachments resolve physical modifiers, exact tradeoffs, trigger composition, paths, labels and acquisition without altering shared skills or action costs')

local baseline=resolve(2,7)
local combined=resolve(2,7,{rail=715,muzzle=739,stock=741})
assert(close(combined.damageScale,baseline.damageScale*.7*.8*.95) and combined.maxTargets==2 and combined.splashRadius==1)
assert(combined.cooldownTurns==0 and combined.ammoPerShot==baseline.ammoPerShot)
local cooldownBase=resolve(604,1604);local reduced=resolve(604,1604,{stock=741})
assert(cooldownBase.cooldownTurns==2 and reduced.cooldownTurns==1)
local basic=resolve(604,7,{stock=741});assert(basic.cooldownTurns==0)
print('PASS four-slot firearm composition multiplies damage but does not add target caps; recoil stock improves cooldown skills without underflowing basic shots')

local roll=0
local effects=require('Game.Battle.GameEffects').New(stats,config:GetTable('CombatEffectTable'),function()end,{roll=function()return roll end})
effects:Validate()
local guardEffect=rules.runes:Get(731).onHitEffectIds[1]
target.Guard=9
assert(effects:Apply(guardEffect,source,target) and source.Guard==2 and target.Guard==9,'Guard attachment must not borrow the victim guard value')
source.Guard=5;assert(effects:Apply(guardEffect,source,target) and source.Guard==5)
local healEffect=rules.runes:Get(733).onHitEffectIds[1];local hp=source.HP
assert(effects:Apply(healEffect,source,target) and source.HP==hp)
assert(effects:Apply(802,source,target));assert(effects:Apply(healEffect,source,target) and source.HP==hp+4 and target.Effects:Find(10002))
local wearEffect=rules.runes:Get(738).onHitEffectIds[1];hp=target.HP
assert(effects:Apply(wearEffect,source,target) and target.HP==hp-1 and worn[target.Id]==12)
local wetEffect=rules.runes:Get(737).onHitEffectIds[1]
assert(wetEffect==1362 and config:GetTable('CombatEffectTable'):Get(wetEffect).chance==40)
roll=40;assert(effects:Apply(wetEffect,source,target) and not target.Effects:Find(10005))
assert(effects:Apply(1307,source,target) and target.Effects:Find(10004))
roll=39;assert(effects:Apply(wetEffect,source,target) and target.Effects:Find(10005).Remaining==3 and not target.Effects:Find(10004))
print('PASS reusable guard, conditional non-consuming blood healing, real armor wear and exact 40% wet/extinguish behavior execute through GameEffects')
config:OnShutdown()
