local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local List=require('UI.UIScrollList')
local L=require('Language')
local Skin=require('UI.ArtSkin')
local Catalog=require('Game.Presentation.SkillTipCatalog')
local Panel=Class('SkillCraftCtr',Base)
local groups={primary='body',combat='element',life='status',special='saved',negative='new'}
function Panel:Bind()
    self.adventure=self.context.systems:Get('Adventure');self.model=self.adventure.battle.stats.skillCraft
    self.skin=Skin.Read(self.view.Skin)
    self:Listen(self.view.Close,function()self:Close()end)
    self:Listen(self.view.Craft,function()self:Save()end)
    for key,group in pairs(groups)do self:Listen(self.view['Group_'..key],function()
        if group=='new' then self:New()else self.group=group;self:RefreshRows()end
    end)end
    self.list=self:AddWidget(List,self.view.EffectList)
    self.list:Configure({templates={effect=self.view.EffectTemplate},spacing=6,getTemplate=function()return 'effect'end,
        onCreate=function(cell)
            self:Listen(cell.view.Plus,function()self:Select(self.rows[assert(cell.index)],true)end)
            self:Listen(cell.view.Minus,function()self:Select(self.rows[assert(cell.index)],false)end)
        end,onBind=function(cell,index)self:BindRow(cell,self.rows[index])end})
    local changed=function()if self.visible then self.recipe.name=self.view.Name.text;self.error=nil;self:RefreshQuote()end end
    self.view.Name.onValueChanged:AddListener(changed);self.lifetime:Add(function()self.view.Name.onValueChanged:RemoveListener(changed)end)
end
function Panel:OnShow(args)
    self.demo=assert(args.demo);self.actor=assert(CS.ProjectY.Data.PartyRoster.Find(self.adventure.data,args.actorId))
    self.view.Owner.text=string.format(L.SkillCraftOwner,require('Game.Presentation.CharacterIdentity').Read(self.adventure.battle.stats,self.actor).name)
    self.view.Name.characterLimit=32;self:New();self:FitPage()
end
function Panel:New()
    self.recipe={id=0,name='',modifierIds={},modifierProfessionIds={}};self.group='body';self.error=nil
    self.view.Name.text='';self:RefreshRows()
end
function Panel:RefreshRows()
    self.rows={}
    for key,group in pairs(groups)do
        Skin.ApplyButton(self.skin,self.view['Group_'..key],self.view['Group_'..key..'Text'],{normal='button_light',dark=true,selected=self.group==group})
    end
    Skin.ApplyButton(self.skin,self.view.Close,self.view.CloseText,{normal='button_light',dark=true})
    if self.group=='saved' then
        local state=CS.ProjectY.Data.SkillCraftState
        for i=0,state.Count(self.actor)-1 do
            local saved=state.At(self.actor,i);local recipe=self.model:Recipe(self.actor,1000000000+saved.id)
            local skill,reason=self.model:Compile(self.actor,recipe)
            self.rows[#self.rows+1]={id=recipe.id,kind='saved',name=Catalog.Escape(recipe.name),description=skill and skill.description or reason,allowed=true}
        end
    else
        local definitions=self.group=='body' and self.model.bodies or self.model.modifiers
        for _,part in ipairs(definitions:All())do if self.group=='body' or part.kind==self.group then
            local skillId=self.group=='body' and part.id or part.skillId;local skill=self.model.skills:Get(skillId)
            for _,course in ipairs(self.model.professions.bySkill[skillId])do
                local allowed=self.model:Eligible(self.actor,skillId,course.professionId)
                self.rows[#self.rows+1]={id=part.id,kind=self.group,professionId=course.professionId,allowed=allowed,
                    name=self.group=='body' and skill.name or part.name,description=self.group=='body' and skill.description or part.description,
                    source=string.format(L.SkillCraftMaterialSource,skill.name,self.model:ProgressText(self.actor,course.professionId))}
            end
        end end
        if self.group=='status' then for i,id in ipairs(self.recipe.modifierIds)do
            if not self.model.modifiers:Find(id)then self.rows[#self.rows+1]={id=id,kind='status',professionId=self.recipe.modifierProfessionIds[i],
                allowed=true,name=L.SkillCraftUnknown,description=L.SkillCraftModifierLocked}end
        end end
    end
    self.list:SetItemCount(#self.rows);self:RefreshQuote()
end
function Panel:Selected(row)
    if row.kind=='body' then return self.recipe.bodyId==row.id and self.recipe.bodyProfessionId==row.professionId end
    if row.kind=='saved' then return self.recipe.id==row.id end
    for i,id in ipairs(self.recipe.modifierIds)do if id==row.id then return self.recipe.modifierProfessionIds[i]==row.professionId end end
    return false
end
function Panel:BindRow(cell,row)
    local view=cell.view;local selected=self:Selected(row)
    view.Title.text=row.name;view.Description.text=row.description
    view.Price.text=row.source or L.SkillCraftSavedHint;view.Rank.text=selected and L.SkillCraftSelected or not row.allowed and L.SkillCraftLocked or ''
    view.PlusText.text=row.kind=='saved' and L.SkillCraftEdit or L.SkillCraftSelect;view.MinusText.text=L.SkillCraftRemove
    view.Plus.interactable=row.allowed and not selected;view.Minus.interactable=selected and row.kind~='saved'
    Skin.ApplyButton(self.skin,view.Plus,view.PlusText,{normal='button_light',dark=true,emphasis=selected})
    Skin.ApplyButton(self.skin,view.Minus,view.MinusText,{normal='button_light',dark=true})
end
function Panel:Select(row,add)
    if not row.allowed then return end
    self.error=nil
    if row.kind=='saved' then self.recipe=self.model:Recipe(self.actor,row.id);self.view.Name.text=self.recipe.name
    elseif row.kind=='body' then
        self.recipe.bodyId=add and row.id or nil;self.recipe.bodyProfessionId=add and row.professionId or nil
        if add and self.recipe.name=='' then self.view.Name.text=string.format(L.SkillCraftDefaultName,row.name)end
    else
        local index;for i,id in ipairs(self.recipe.modifierIds)do if id==row.id then index=i;break end end
        if add then
            if not index and #self.recipe.modifierIds>=self.model.policy.maxModifiers then self.error=L.SkillCraftSlots
            else index=index or #self.recipe.modifierIds+1;self.recipe.modifierIds[index]=row.id;self.recipe.modifierProfessionIds[index]=row.professionId end
        elseif index then table.remove(self.recipe.modifierIds,index);table.remove(self.recipe.modifierProfessionIds,index)end
    end
    self.list:SetItemCount(#self.rows);self:RefreshQuote()
end
function Panel:RefreshQuote()
    local model=self.model;local recipe=self.recipe
    local skill,reason
    if recipe.bodyId then skill,reason=model:Compile(self.actor,recipe)else reason=L.SkillCraftChooseBody end
    local phase=self.adventure.data.Phase;local allowed=phase=='map' or phase=='area'
    local names={};for _,id in ipairs(recipe.modifierIds)do local part=model.modifiers:Find(id);names[#names+1]=part and part.name or L.SkillCraftUnknown end
    self.view.Balance.text=string.format(L.SkillCraftSlotCount,#recipe.modifierIds,model.policy.maxModifiers)
    local body=recipe.bodyId and model.skills:Find(recipe.bodyId)
    self.view.PositiveCost.text=string.format(L.SkillCraftBodySummary,body and body.name or L.SkillCraftUnselected)
    self.view.DiscountCost.text=string.format(L.SkillCraftModifierSummary,#names>0 and table.concat(names,L.SkillCraftSeparator)or L.SkillCraftUnselected)
    if skill then
        self.adventure.battle.spellcasting:Resolve(self.actor,skill)
        self.view.Preview.text=string.format(L.SkillCraftPreview,skill.description,skill.cost,skill.castingCost or 0,skill.cooldownTurns,skill.range,skill.maxTargets,skill.damageScale)
        local ok,equipmentReason=self.adventure.battle.stats.equipment:CheckSkillEquipment(self.actor,skill,self.adventure.battle.stats)
        if not ok then self.view.Preview.text=string.format(L.SkillCraftEquipmentPreview,self.view.Preview.text,equipmentReason)end
    else self.view.Preview.text=reason end
    self.view.TotalCost.text=L.SkillCraftFree;self.view.CraftText.text=recipe.id>0 and L.SkillCraftUpdate or L.SkillCraftCreate
    self.view.Craft.interactable=skill~=nil and allowed and recipe.name~=''
    self.view.Hint.text=self.error or (not allowed and L.SkillCraftExploreOnly or reason or L.SkillCraftReady)
    self.view.PreviewContent.sizeDelta=CS.UnityEngine.Vector2(self.view.PreviewContent.sizeDelta.x,math.max(self.view.PreviewScroll.viewport.rect.height,self.view.Preview.preferredHeight+12))
    self.phase=phase;self.revision=CS.ProjectY.Data.SkillCraftState.Revision(self.actor)
    Skin.ApplyButton(self.skin,self.view.Craft,self.view.CraftText,{emphasis=true})
end
function Panel:Save()
    local ok,reason,id=self.model:Save(self.actor,self.adventure.data.Phase,self.recipe)
    self.error=reason;if ok then self.recipe.id=id;self.demo:SendCommand('snapshot')end
    self:RefreshRows()
end
function Panel:FitPage()
    local rect=self.view.Root.rect;local scale=math.max(.1,math.min(1,(rect.width-24)/1100,(rect.height-24)/660))
    self.view.Page.localScale=CS.UnityEngine.Vector3(scale,scale,scale)
end
function Panel:Tick()
    self:FitPage()
    if self.phase~=self.adventure.data.Phase or self.revision~=CS.ProjectY.Data.SkillCraftState.Revision(self.actor)then self:RefreshRows()end
end
function Panel:OnHide()self.actor=nil;self.demo=nil;self.recipe=nil;self.rows={}end
return Panel
