local Class=require('Core.Class')
local Panel=require('UI.UIPanelCtrl')
local Workbench=Class('EquipmentWorkbenchCtr',Panel)
function Workbench:Bind()
    self.system=self.context.systems:Get('Equipment');self.rules=self.system.rules
    self.stats=self.context.systems:Get('Battle').stats
    self.view.Workbench:Prepare();self.inventory={};self.options={}
    for i=1,4 do local index=i
        self:Listen(self.view['Actor'..i],function()
            self.actorId=self.system.adventure:GetPartyAt(index-1).Id;self:Refresh()
        end)
    end
    for i=1,3 do local index=i
        self:Listen(self.view['Socket'..i],function()
            self.socketId=self.rules.weapons:Get(self.system.data:GetWeapon(self.weaponId).ItemId).socketIds[index];self:Refresh()
        end)
    end
    self:Listen(self.view.Close,function() self.context.systems:Get('UI'):Close(self.panelName) end)
    self:Listen(self.view.Equip,function() self:Command('equip',0) end)
    self:Listen(self.view.Unequip,function() self:Command('unequip',0) end)
    self:Listen(self.view.Remove,function() self:Command('attach',0) end)
    self:Listen(self.view.Fill,function()
        local loaded=self.rules:Loaded(self.system.data:GetWeapon(self.weaponId))
        if loaded then self:Command('fill',loaded.Id) end
    end)
end
function Workbench:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetEquipmentOpen(true)
    self.actorId=self.system.adventure:GetPartyAt(0).Id
    self.weaponId=self.system.data:GetWeaponAt(0).Id;self.socketId=0;self.message='点击挂点选择组件；拖动旋转，滚轮缩放。'
    self.view.Workbench:Prepare();self:Refresh()
end
function Workbench:Command(command,value)
    local ok,reason=self.system:Command(command,self.actorId,self.weaponId,self.socketId,value)
    self.message=ok and '已应用，装备与战斗参数已同步。' or reason
    if ok then self.demo:SendCommand('snapshot') end
    self:Refresh()
end
function Workbench:Rows(pool,parent,rows,callback)
    for i=1,math.max(#pool,#rows) do
        if not pool[i] then
            pool[i]=self:CreateWidget('EquipmentRow',parent);pool[i]:Initialize(self.view.Workbench,callback)
        end
        pool[i]:SetData(rows[i])
    end
end
function Workbench:Refresh()
    local data=self.system.data;local weapon=data:GetWeapon(self.weaponId);local definition=self.rules.weapons:Get(weapon.ItemId)
    local actor=self.system:Actor(self.actorId);local equipped=data:Equipped(self.actorId)
    local item=self.rules.items:Get(weapon.ItemId)
    local socketFound=false
    for _,id in ipairs(definition.socketIds) do if id==self.socketId then socketFound=true end end
    if not socketFound then self.socketId=definition.socketIds[1] end
    for i=1,4 do
        local active=i<=self.system.adventure.PartyCount
        self.view['Actor'..i].gameObject:SetActive(active)
        if active then local member=self.system.adventure:GetPartyAt(i-1)
            self.view['ActorText'..i].text=(member.Id==self.actorId and '● ' or '')..self.stats:Template(member).name
        end
    end
    self.view.Title.text=item.name
    self.view.Subtitle.text=weapon.OwnerActorId==0 and '共享背包 · 未装备' or ('持有者：'..self.stats:Template(self.system:Actor(weapon.OwnerActorId)).name)
    self.view.EquipText.text='装备给 '..self.stats:Template(actor).name
    self.view.Equip.interactable=not equipped or equipped.Id~=weapon.Id
    self.view.Unequip.interactable=equipped~=nil
    self.view.Status.text=self.message
    self.view.Workbench:ShowWeapon(self.rules:WeaponVisual(weapon))
    for i,id in ipairs(definition.socketIds) do
        local slot=self.rules.sockets:Get(id)
        self.view['SocketText'..i].text=(id==self.socketId and '● ' or '◇ ')..slot.name
    end
    local function row(itemId,title,detail)
        return {itemId=itemId,title=title,detail=detail,iconPath=self.rules.items:Get(itemId).iconPath}
    end
    local inventory={}
    for i=0,data.WeaponCount-1 do local w=data:GetWeaponAt(i);local r=row(w.ItemId,self.rules.items:Get(w.ItemId).name,w.OwnerActorId==0 and '武器 · 在背包中' or '武器 · 已装备')
        r.weaponId=w.Id;r.selected=w.Id==self.weaponId;inventory[#inventory+1]=r
    end
    for i=0,data.MagazineCount-1 do local mag=data:GetMagazineAt(i);local r=row(mag.ItemId,'弹匣 #'..mag.Id,mag.Rounds..'/'..mag.Capacity..' 发 · '..(data:MagazineWeapon(mag.Id)==0 and '备用 · 点击装填' or '已装入武器'))
        r.magazineId=mag.Id;inventory[#inventory+1]=r
    end
    for i=0,data.StackCount-1 do local stack=data:GetStackAt(i);local r=row(stack.ItemId,self.rules.items:Get(stack.ItemId).name..' ×'..stack.Count,'共享库存')
        r.enabled=false;inventory[#inventory+1]=r
    end
    self:Rows(self.inventory,self.view.InventorySlots,inventory,function(r)
        if r.weaponId then self.weaponId=r.weaponId;self.socketId=0;self:Refresh()
        elseif r.magazineId then self:Command('fill',r.magazineId) end
    end)
    local slot=self.rules.sockets:Get(self.socketId);local options={};local current=0
    self.view.SocketTitle.text=slot.name..' · 可安装组件'
    if slot.kind=='magazine' then
        current=weapon.MagazineId
        for i=0,data.MagazineCount-1 do local mag=data:GetMagazineAt(i)
            if mag.ItemId==definition.magazineItemId and (data:MagazineWeapon(mag.Id)==0 or mag.Id==current) then
                local r=row(mag.ItemId,'弹匣 #'..mag.Id,mag.Rounds..'/'..mag.Capacity..' 发');r.value=mag.Id;r.selected=current==mag.Id;options[#options+1]=r
            end
        end
    else
        current=weapon:GetRune(slot.id)
        for _,rune in ipairs(self.rules.runes:All()) do if rune.slotKind==slot.kind then
            local r=row(rune.id,self.rules.items:Get(rune.id).name,data:CountItem(rune.id)>0 and '点击安装' or (current==rune.id and '已安装' or '尚未获得 · 前往地牢搜刮'))
            r.enabled=data:CountItem(rune.id)>0 or current==rune.id;r.value=rune.id;r.selected=current==rune.id;options[#options+1]=r
        end end
    end
    self:Rows(self.options,self.view.OptionSlots,options,function(r) self:Command('attach',r.value) end)
    self.view.Remove.interactable=current~=0
    local loaded=self.rules:Loaded(weapon)
    self.view.Fill.gameObject:SetActive(definition.kind=='gun')
    self.view.Fill.interactable=loaded~=nil and loaded.Rounds<loaded.Capacity and data:CountItem(loaded.AmmoItemId)>0
    local lines={}
    if slot.kind~='magazine' then
        for _,rune in ipairs(self.rules.runes:All()) do if rune.slotKind==slot.kind then lines[#lines+1]=rune.description end end
    end
    if loaded then lines[#lines+1]='弹匣 '..loaded.Rounds..' / '..loaded.Capacity..' · 散装弹药 '..data:CountItem(loaded.AmmoItemId) end
    -- Preview a selected inventory weapon without mutating actor ownership.
    local previewRules=setmetatable({Weapon=function() return weapon end},{__index=self.rules})
    for _,id in ipairs(previewRules:SkillIds(actor,self.stats:Template(actor))) do
        local skill=previewRules:Skill(actor,id)
        local effects={};local damage=false
        for _,effectId in ipairs(skill.effectIds) do
            if self.rules.effects:Get(effectId).kind=='damage' then damage=true end
        end
        if damage then effects[#effects+1]=string.format('命中 %d%% · 伤害 ×%.2f',skill.hitChance,skill.damageScale) end
        effects[#effects+1]=string.format('射程 %d · 目标 %d · CD %d',skill.range,skill.maxTargets,skill.cooldownTurns)
        if skill.ammoPerShot>0 then effects[#effects+1]='每次耗弹 '..skill.shots*skill.ammoPerShot end
        lines[#lines+1]=skill.name..' · '..skill.cost..' AP\n'..table.concat(effects,'\n')
    end
    self.view.Stats.text=table.concat(lines,'\n\n')
end
function Workbench:OnHide() self.view.Workbench:ReleasePreview();self.demo:SetEquipmentOpen(false);self.demo=nil end
return Workbench
