local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local List=require('UI.UIScrollList')
local L=require('Language')
local Skin=require('UI.ArtSkin')
local Identity=require('Game.Presentation.CharacterIdentity')
local categories={'primary','combat','life','special','negative'}
local labels=require('Config.LanguageProxy').Map(L,{primary='TitleForgePrimary',combat='TitleForgeCombat',
    life='TitleForgeLife',special='TitleForgeSpecial',negative='TitleForgeNegative'})
local Panel=Class('TitleForgeCtr',Base)

function Panel:Bind()
    self.adventure=self.context.systems:Get('Adventure');self.model=self.adventure.titles
    self.skin=Skin.Read(self.view.Skin);self.rows={};self.ranks={};self.firstInCategory={}
    self:Listen(self.view.Close,function()self:Close()end)
    self:Listen(self.view.Craft,function()self:Craft()end)
    for _,category in ipairs(categories)do
        self:Listen(self.view['Group_'..category],function()self.list:ScrollTo(self.firstInCategory[category])end)
    end
    self.list=self:AddWidget(List,self.view.EffectList)
    self.list:Configure({templates={header=self.view.HeaderTemplate,effect=self.view.EffectTemplate},spacing=6,
        getTemplate=function(index)return self.rows[index].header and 'header' or 'effect'end,
        onCreate=function(cell)
            if cell.templateKey=='effect' then
                self:Listen(cell.view.Minus,function()self:Adjust(assert(cell.index),-1)end)
                self:Listen(cell.view.Plus,function()self:Adjust(assert(cell.index),1)end)
            end
        end,
        onBind=function(cell,index)self:BindRow(cell,self.rows[index])end})
    local changed=function()if self.visible then self.error=nil;self:RefreshQuote()end end
    self.view.Name.onValueChanged:AddListener(changed)
    self.lifetime:Add(function()self.view.Name.onValueChanged:RemoveListener(changed)end)
end

function Panel:OnShow(args)
    self:FitPage()
    self.demo=assert(args.demo);self.actorId=assert(args.actorId);self.onCrafted=args.onCrafted
    self.actor=assert(self.model:Actor(self.actorId),'Title forge actor must belong to the party')
    self.ranks={};self.error=nil;self.rows={};self.firstInCategory={}
    local effects=self.model:ForgeRows()
    for _,category in ipairs(categories)do
        self.firstInCategory[category]=#self.rows+1
        self.rows[#self.rows+1]={header=true,category=category}
        for _,row in ipairs(effects)do if row.category==category then self.rows[#self.rows+1]=row end end
        self.view['Group_'..category..'Text'].text=labels[category]
        Skin.ApplyButton(self.skin,self.view['Group_'..category],self.view['Group_'..category..'Text'],{normal='button_light',dark=true})
    end
    self.view.Owner.text=string.format(L.TitleForgeOwner,Identity.Read(self.adventure.battle.stats,self.actor).name)
    self.view.Permanent.text=string.format(L.TitleForgePermanent,self.model.rules.forge.policy.discountPercent)
    self.view.Name.text='';self.list:SetItemCount(#self.rows)
    self.view.PreviewScroll.verticalNormalizedPosition=1
    Skin.ApplyButton(self.skin,self.view.Close,self.view.CloseText,{normal='button_light',dark=true})
    self:RefreshQuote()
end

function Panel:BindRow(cell,row)
    if row.header then cell.view.Title.text=labels[row.category];return end
    local rank=self.ranks[row.id] or 0;local view=cell.view
    view.Title.text=row.name;view.Description.text=row.description
    view.Price.text=string.format(row.negative and L.TitleForgeDiscountPrice or L.TitleForgePrice,row.cost)
    view.Rank.text=string.format(L.TitleForgeRank,rank,row.maxRank)
    view.Minus.interactable=rank>0;view.Plus.interactable=rank<row.maxRank
    view.Title.color=row.negative and CS.UnityEngine.Color(.57,.19,.14,1)or self.skin.colors.ink
    Skin.ApplyButton(self.skin,view.Minus,view.MinusText,{normal='button_light',dark=true})
    Skin.ApplyButton(self.skin,view.Plus,view.PlusText,{normal='button_light',dark=true,emphasis=rank>0})
end

function Panel:Adjust(index,offset)
    local row=assert(self.rows[index]);local rank=(self.ranks[row.id] or 0)+offset
    if rank<0 or rank>row.maxRank then return end
    self.ranks[row.id]=rank>0 and rank or nil;self.error=nil
    self.list:RefreshItem(index);self:RefreshQuote()
end

function Panel:RefreshQuote()
    local data=self.adventure.data;local quote=self.model:Quote(self.view.Name.text,self.ranks)
    local balance=CS.ProjectY.Data.ReputationState.Balance(data)
    self.view.Balance.text=string.format(L.TitleForgeBalance,balance)
    self.view.PositiveCost.text=string.format(L.TitleForgePositiveCost,quote.positive)
    self.view.DiscountCost.text=string.format(L.TitleForgeDiscountCost,quote.discount)
    self.view.TotalCost.text=string.format(L.TitleForgeTotalCost,quote.cost)
    self.view.Preview.text=quote.description~='' and quote.description or L.TitleForgeEmptyPreview
    self.view.PreviewContent.sizeDelta=CS.UnityEngine.Vector2(self.view.PreviewContent.sizeDelta.x,
        math.max(self.view.PreviewScroll.viewport.rect.height,self.view.Preview.preferredHeight+12))
    local phaseAllowed=data.Phase=='map' or data.Phase=='area'
    self.view.Craft.interactable=quote.valid and balance>=quote.cost and phaseAllowed
    self.view.Hint.text=self.error or (not phaseAllowed and L.TitleExploreOnly or not quote.valid and quote.reason
        or balance<quote.cost and L.TitleForgeInsufficient or L.TitleForgeReady)
    Skin.ApplyButton(self.skin,self.view.Craft,self.view.CraftText,{emphasis=true})
    self.revision=CS.ProjectY.Data.ReputationState.Revision(data);self.phase=data.Phase
end

function Panel:Craft()
    local ok,reason,id=self.model:Craft(self.actorId,self.view.Name.text,self.ranks)
    if not ok then self.error=reason;self:RefreshQuote();return end
    self.demo:SendCommand('snapshot')
    local callback=self.onCrafted
    self:Close()
    if callback then callback(id)end
end

function Panel:Tick()
    self:FitPage()
    if self.revision~=CS.ProjectY.Data.ReputationState.Revision(self.adventure.data) or self.phase~=self.adventure.data.Phase then self:RefreshQuote()end
end
function Panel:FitPage()
    local rect=self.view.Root.rect
    if self.width==rect.width and self.height==rect.height then return end
    self.width,self.height=rect.width,rect.height
    local scale=math.max(.1,math.min(1,(rect.width-24)/1100,(rect.height-24)/660))
    self.view.Page.localScale=CS.UnityEngine.Vector3(scale,scale,scale)
end
function Panel:OnHide()self.demo=nil;self.actor=nil;self.onCrafted=nil;self.ranks={}end
return Panel
