local LuaLanguage = require('Language')
local Class=require('Core.Class')
local Panel=require('UI.UIPanelCtrl')
local Text=require('Game.Equipment.EquipmentPresentation')
local Workbench=Class('EquipmentWorkbenchCtr',Panel)
local SocketCapacity=4
function Workbench:Bind()
    self.system=self.context.systems:Get('Equipment');self.rules=self.system.rules
    self.terms=require('UI.EquipmentTermPresenter').New(self.view,self.system.config)
    self.stats=self.context.systems:Get('Battle').stats
    self.view.Workbench:Prepare();self.inventory={};self.options={};self.tags={}
    self:Listen(self.view.CategoryPrevious,function() self:ChangeCategory(-1) end)
    self:Listen(self.view.CategoryNext,function() self:ChangeCategory(1) end)
    for i=1,4 do local index=i
        self:Listen(self.view['Actor'..i],function()
            self.actorId=self.system.adventure:GetPartyAt(index-1).Id;self:Refresh()
        end)
    end
    for i=1,SocketCapacity do local index=i
        self:Listen(self.view['Socket'..i],function()
            self.socketId=self.rules.weapons:Get(self.system.data:GetWeapon(self.weaponId).ItemId).socketIds[index]
            self.fillMagazineId=nil;self.fillAmmoItemId=nil;self.message=LuaLanguage.UIEquipmentWorkbenchMessage;self:Refresh()
        end)
    end
    self:Listen(self.view.Close,function() self.context.systems:Get('UI'):Close(self.panelName) end)
    self:Listen(self.view.Equip,function() self:Command('equip',0) end)
    self:Listen(self.view.Unequip,function() self:Command('unequip',0) end)
    self:Listen(self.view.Remove,function() self:Command('attach',0) end)
    self:Listen(self.view.Fill,function()
        if self.fillMagazineId then self:Command('fill',self.fillMagazineId,self.fillAmmoItemId) end
    end)
end
function Workbench:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetEquipmentOpen(true)
    self.actorId=self.system.adventure:GetPartyAt(0).Id
    self.weaponId=0
    for i=0,self.system.data.WeaponCount-1 do local weapon=self.system.data:GetWeaponAt(i);if self.system:IsCarriedWeapon(weapon) then self.weaponId=weapon.Id;break end end
    assert(self.weaponId~=0,'Open the workbench only while carrying a weapon')
    self.socketId=0;self.categoryIndex=0;self.fillMagazineId=nil;self.fillAmmoItemId=nil;self.message=LuaLanguage.UIEquipmentWorkbenchMessage
    self.view.Workbench:Prepare();self:Refresh();self.terms:Reset()
end
function Workbench:ChangeCategory(step)
    self.fillMagazineId=nil;self.fillAmmoItemId=nil
    local categories=self.rules.categories:All()
    self.categoryIndex=(self.categoryIndex+step)%(#categories+1)
    local categoryId=self.categoryIndex>0 and categories[self.categoryIndex].id or 0
    if categoryId~=0 then
        for i=0,self.system.data.WeaponCount-1 do local weapon=self.system.data:GetWeaponAt(i)
            if self.system:IsCarriedWeapon(weapon) and self.rules.weapons:Get(weapon.ItemId).categoryId==categoryId then self.weaponId=weapon.Id;self.socketId=0;break end
        end
    end
    self:Refresh()
end
function Workbench:SelectMagazine(magazine)
    self.fillMagazineId=magazine.Id;self.fillAmmoItemId=magazine.AmmoItemId
    self.message=LuaLanguage.WorkbenchAmmoInstructions;self:Refresh()
end
function Workbench:Command(command,value,ammoItemId)
    local ok,reason=self.system:Command(command,self.actorId,self.weaponId,self.socketId,value,ammoItemId)
    self.message=ok and LuaLanguage.UIEquipmentWorkbenchMessage2 or reason
    if ok then
        self.demo:SendCommand('snapshot')
        if command=='attach' and value~=0 and self.rules.sockets:Get(self.socketId).kind=='magazine' then
            self:SelectMagazine(self.system.data:GetMagazine(value));return
        end
    end
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
    assert(#definition.socketIds<=SocketCapacity,'Weapon sockets exceed the authored workbench capacity')
    local actor=self.system:Actor(self.actorId);local equipped=data:Equipped(self.actorId)
    local item=self.rules.items:Get(weapon.ItemId)
    local socketFound=false
    for _,id in ipairs(definition.socketIds) do if id==self.socketId then socketFound=true end end
    if not socketFound then self.socketId=definition.socketIds[1] or 0 end
    for i=1,4 do
        local active=i<=self.system.adventure.PartyCount
        self.view['Actor'..i].gameObject:SetActive(active)
        if active then local member=self.system.adventure:GetPartyAt(i-1)
            self.view['ActorText'..i].text=(member.Id==self.actorId and '● ' or '')..self.stats:Template(member).name
        end
    end
    self.view.Title.text=Text.Name(self.rules,weapon)
    local legendary=self.rules.affixes:Legendary(weapon)
    self.view.DetailsRarityFrame:Configure(legendary~=nil,legendary and legendary.color or '',true)
    local tags=self.rules:WeaponTags(weapon.ItemId)
    for i=1,math.max(#self.tags,#tags) do
        if not self.tags[i] then
            self.tags[i]=self:CreateWidget('EquipmentTag',self.view.TagSlots)
            self.tags[i]:Initialize(self.view.Workbench)
        end
        self.tags[i]:SetData(tags[i])
    end
    self.view.TagSlots.gameObject:SetActive(#tags>0)
    self.view.Subtitle.text=self.rules.categories:Get(definition.categoryId).name..' · Lv.'..definition.level..'\n'..(weapon.OwnerActorId==0 and LuaLanguage.UIEquipmentWorkbenchSubtitleText2 or (string.format(LuaLanguage.UIEquipmentWorkbenchSubtitleText, (self.stats:Template(self.system:Actor(weapon.OwnerActorId)).name))))
    self.view.EquipText.text=string.format(LuaLanguage.UIEquipmentWorkbenchEquipTextText, (self.stats:Template(actor).name))
    self.view.Equip.interactable=(not equipped or equipped.Id~=weapon.Id)
        and self.system:HandAllowed(self.actorId,weapon,'weapon') and self.rules:CanEquip(actor,weapon.ItemId,self.stats)
    self.view.Unequip.interactable=equipped~=nil
    self.view.Status.text=self.message
    self.view.Workbench:ShowWeapon(self.rules:WeaponVisual(weapon))
    for i=1,SocketCapacity do
        local id=definition.socketIds[i]
        self.view['Socket'..i].gameObject:SetActive(id~=nil)
        self.view['Socket'..i].interactable=id~=nil
        self.view['SocketText'..i].text=id and ((id==self.socketId and '● ' or '◇ ')..self.rules.sockets:Get(id).name) or ''
    end
    local function row(itemId,title,detail)
        return {itemId=itemId,title=title,detail=detail,iconPath=self.rules.items:Get(itemId).iconPath}
    end
    local category=self.categoryIndex>0 and self.rules.categories:All()[self.categoryIndex] or nil
    self.view.CategoryText.text=category and category.name or LuaLanguage.UIEquipmentWorkbenchCategoryTextText
    local inventory={}
    for i=0,data.WeaponCount-1 do local w=data:GetWeaponAt(i);local d=self.rules.weapons:Get(w.ItemId)
        if self.system:IsCarriedWeapon(w) and (not category or category.id==d.categoryId) then
            local r=row(w.ItemId,Text.Name(self.rules,w),self.rules.categories:Get(d.categoryId).name..' · Lv.'..d.level..(w.OwnerActorId==0 and LuaLanguage.UIEquipmentWorkbenchR11 or LuaLanguage.UIEquipmentWorkbenchR10))
            r.weaponId=w.Id;r.category=d.categoryId;r.level=d.level;r.selected=w.Id==self.weaponId;inventory[#inventory+1]=r
        end
    end
    table.sort(inventory,function(a,b)
        if a.category~=b.category then return a.category<b.category end
        if a.level~=b.level then return a.level<b.level end
        return a.weaponId<b.weaponId
    end)
    for i=0,data.MagazineCount-1 do local mag=data:GetMagazineAt(i)
        if self.system:IsCarriedMagazine(mag) then
            local r=row(mag.ItemId,string.format(LuaLanguage.WorkbenchMagazineName,self.rules.items:Get(mag.ItemId).name,mag.Id),
                string.format(LuaLanguage.WorkbenchMagazineSelect,Text.MagazineSummary(self.rules,mag),data:MagazineWeapon(mag.Id)==0 and LuaLanguage.UIEquipmentWorkbenchR8 or LuaLanguage.UIEquipmentWorkbenchR7))
            r.magazineId=mag.Id;r.selected=mag.Id==self.fillMagazineId;inventory[#inventory+1]=r
        end
    end
    local stacked={}
    for i=0,data.StackCount-1 do local stack=data:GetStackAt(i)
        if not stacked[stack.ItemId] then
            stacked[stack.ItemId]=true
            local count=data:CountItem(stack.ItemId)
            if count>0 then
                local stackItem=self.rules.items:Get(stack.ItemId)
                local detail=stackItem.kind=='ammo' and Text.AmmoStats(self.rules,stack.ItemId) or LuaLanguage.UIEquipmentWorkbenchR6
                local r=row(stack.ItemId,stackItem.name..' ×'..count,detail)
                r.enabled=false;inventory[#inventory+1]=r
            end
        end
    end
    self:Rows(self.inventory,self.view.InventorySlots,inventory,function(r)
        if r.weaponId then self.weaponId=r.weaponId;self.socketId=0;self.fillMagazineId=nil;self.fillAmmoItemId=nil;self.message=LuaLanguage.UIEquipmentWorkbenchMessage;self:Refresh()
        elseif r.magazineId then self:SelectMagazine(self.system.data:GetMagazine(r.magazineId)) end
    end)
    local requirement=self.rules:ItemRequirements(actor,weapon.ItemId,self.stats,true);local requirements={}
    for _,entry in ipairs(requirement.entries) do requirements[#requirements+1]=Text.Paint(entry.name..' '..entry.current..' / '..entry.required,entry.current>=entry.required and Text.colors.positive or Text.colors.negative,12) end
    self.view.Requirements.text=Text.Heading(LuaLanguage.UIEquipmentWorkbenchRequirementsText5)..'\n'..(#requirements>0 and table.concat(requirements,'  ') or Text.Note(LuaLanguage.UIEquipmentWorkbenchRequirementsText4))..'\n'..
        Text.Paint(requirement.met and LuaLanguage.UIEquipmentWorkbenchRequirementsText3 or LuaLanguage.UIEquipmentWorkbenchRequirementsText2,requirement.met and Text.colors.positive or Text.colors.negative,12)
    local effective=self.rules:Requirements(actor,weapon,self.stats)
    if weapon.OwnerActorId==actor.Id and not effective.met then
        self.view.Requirements.text=self.view.Requirements.text..'\n'..Text.Paint(string.format(LuaLanguage.UIEquipmentWorkbenchRequirementsText,math.floor((1-effective.damageScale)*100+.5),effective.hitLoss),Text.colors.negative,11)
    end
    local slot=self.socketId~=0 and self.rules.sockets:Get(self.socketId) or nil;local options={};local current=0
    local filling=self.fillMagazineId and data:GetMagazine(self.fillMagazineId) or nil
    self.view.SocketTitle.text=slot and string.format(LuaLanguage.UIEquipmentWorkbenchSocketTitleText2, (slot.name)) or LuaLanguage.UIEquipmentWorkbenchSocketTitleText
    if filling then
        self.view.SocketTitle.text=string.format(LuaLanguage.WorkbenchAmmoTitle,filling.Id)
        for _,ammo in ipairs(self.rules.ammunition:ForMagazine(filling.ItemId)) do
            local r=row(ammo.id,ammo.name,string.format(LuaLanguage.WorkbenchAmmoStock,Text.AmmoStats(self.rules,ammo.id),data:CountItem(ammo.id)))
            r.ammoItemId=ammo.id;r.selected=ammo.id==self.fillAmmoItemId;options[#options+1]=r
        end
    elseif slot and slot.kind=='magazine' then
        current=weapon.MagazineId
        for i=0,data.MagazineCount-1 do local mag=data:GetMagazineAt(i)
            if self.system:IsCarriedMagazine(mag) and mag.ItemId==definition.magazineItemId and (data:MagazineWeapon(mag.Id)==0 or mag.Id==current) then
                local r=row(mag.ItemId,string.format(LuaLanguage.WorkbenchMagazineName,self.rules.items:Get(mag.ItemId).name,mag.Id),
                    Text.MagazineSummary(self.rules,mag)..'\n'..(mag.Id==current and LuaLanguage.UIEquipmentWorkbenchR2 or LuaLanguage.UIEquipmentWorkbenchR3))
                r.value=mag.Id;r.selected=current==mag.Id;options[#options+1]=r
            end
        end
    elseif slot then
        current=weapon:GetRune(slot.id)
        for _,rune in ipairs(self.rules.runes:All()) do if rune.slotKind==slot.kind then
            local r=row(rune.id,self.rules.items:Get(rune.id).name,data:CountItem(rune.id)>0 and LuaLanguage.UIEquipmentWorkbenchR3 or (current==rune.id and LuaLanguage.UIEquipmentWorkbenchR2 or LuaLanguage.UIEquipmentWorkbenchR))
            r.enabled=data:CountItem(rune.id)>0 or current==rune.id;r.value=rune.id;r.selected=current==rune.id;options[#options+1]=r
        end end
    end
    self:Rows(self.options,self.view.OptionSlots,options,function(r)
        if r.ammoItemId then self.fillAmmoItemId=r.ammoItemId;self.message=LuaLanguage.WorkbenchAmmoInstructions;self:Refresh()
        else self:Command('attach',r.value) end
    end)
    self.view.Remove.interactable=not filling and current~=0
    local loaded=self.rules:Loaded(weapon)
    self.view.Fill.gameObject:SetActive(filling~=nil or definition.kind=='gun')
    self.view.Fill.interactable=filling~=nil and (filling.Rounds<filling.Capacity or filling.AmmoItemId~=self.fillAmmoItemId)
        and data:CountItem(self.fillAmmoItemId)>0
    -- Resolve the selected inventory weapon without mutating the actor's real loadout.
    local previewRules=self.rules:PreviewWeapon(weapon)
    local descriptions=require('Game.Presentation.EquipmentDescriptionModel').For(self.system.config)
    local granted={};for _,id in ipairs(descriptions:GrantedSkills(weapon.ItemId))do granted[id]=true end
    local function resolve(id)
        local skill=previewRules:Skill(actor,id,self.stats)
        if skill.catalystKind~='none'then
            local allowed,reason=previewRules:CheckSkillEquipment(actor,skill,self.stats)
            if not allowed then skill.equipmentDescriptionReason=reason end
        end
        return skill
    end
    local lines={Text.Abilities(self.rules,weapon,resolve),Text.Attributes(self.rules,weapon),Text.Affix(self.rules,weapon),Text.Condition(self.rules,weapon)}
    if slot and slot.kind~='magazine' and current~=0 then
        lines[#lines+1]=Text.Heading(LuaLanguage.UIEquipmentWorkbenchLinesLines14)..'\n'..Text.Paint(self.rules.runes:Get(current).description,Text.colors.label,13)
    end
    if loaded then lines[#lines+1]=Text.Heading(LuaLanguage.UIEquipmentWorkbenchLinesLines13)..'\n'..Text.Magazine(self.rules,loaded) end
    if filling then
        lines[#lines+1]=Text.Note(string.format(LuaLanguage.WorkbenchAmmoTarget,self.rules.items:Get(filling.ItemId).name,filling.Id,Text.MagazineSummary(self.rules,filling)))..'\n'..
            Text.Paint(string.format(LuaLanguage.WorkbenchAmmoSelected,self.rules.ammunition:Get(self.fillAmmoItemId).name,data:CountItem(self.fillAmmoItemId)),Text.colors.accent,12)..'\n'..
            Text.Ammunition(self.rules,self.fillAmmoItemId)
    end
    local otherHeading=false
    for _,id in ipairs(previewRules:SkillIds(actor,self.stats:Template(actor))) do
        if not granted[id]then
            if not otherHeading then lines[#lines+1]=Text.Heading(LuaLanguage.EquipmentOtherSkills);otherHeading=true end
            lines[#lines+1]=Text.Skill(self.rules,resolve(id))
        end
    end
    self.view.Stats.text=table.concat(lines,'\n\n')
end
function Workbench:OnHide() self.terms:Reset();self.view.Workbench:ReleasePreview();self.demo:SetEquipmentOpen(false);self.demo=nil end
function Workbench:Tick() require('UI.EquipmentRarity').Tick();self.terms:Tick() end
return Workbench
