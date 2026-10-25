local Class = require('Core.Class')
local Base = require('UI.UIWidgetCtrl')
local SkillIcon=require('UI.SkillIcon')
local Node = Class('TalentNode',Base)
function Node:Bind()
    self.icons=self.context.systems:Get('Config'):GetTable('BattleIconTable')
    self:Listen(self.view.Button,function() if self.action then self.action(self.node.id) end end)
end
function Node:SetData(node,passive,actor,style,selected,available,action)
    self.node,self.action=node,action; self.view.Root.gameObject:SetActive(node~=nil)
    if not node then return end
    local rank=actor.Growth:GetRank(node.id)
    self.view.Title.font,self.view.Rank.font=style.Font,style.Font
    self.view.Title.text=passive.name;self.view.Rank.text=rank>0 and (rank..' / '..node.maxRank) or ''
    style:PlaceNode(self.view.Root,node.x,node.y)
    style:SetGlyph(self.view.Icon,passive.iconAttribute~='' and passive.iconAttribute or passive.attributeNames[1])
    style:Tint(self.view.Background,rank>0 and '394D40' or (available and 'F4ECD7' or 'D5CDBA'))
    style:Tint(self.view.Icon,rank>0 and 'E8D3A7' or (available and '51462F' or '999483'))
    style:Tint(self.view.Ring,selected and '9E682E' or (rank>0 and '94753C' or (available and 'A49571' or 'C0B7A2')))
    self.view.Ring.rectTransform.localScale=CS.UnityEngine.Vector3(selected and 1.12 or 1,selected and 1.12 or 1,1)
end
function Node:SetSkillData(node,skill,state,label,style,selected,action)
    self.node,self.action=node,action;self.view.Root.gameObject:SetActive(node~=nil)
    if not node then return end
    self.view.Title.font,self.view.Rank.font=style.Font,style.Font
    self.view.Title.text=skill.name;self.view.Rank.text=label
    local rank=self.view.Rank.rectTransform
    rank.anchorMin,rank.anchorMax=CS.UnityEngine.Vector2(0,1),CS.UnityEngine.Vector2(0,1)
    rank.pivot=CS.UnityEngine.Vector2(0,1);rank.anchoredPosition=CS.UnityEngine.Vector2(-5,-79);rank.sizeDelta=CS.UnityEngine.Vector2(110,18)
    style:PlaceNode(self.view.Root,node.x,node.y)
    local hasIcon=SkillIcon.Set(self.view.Icon,style,skill,self.icons,node.glyphCode,state=='owned' and 'E8D3A7' or (state=='eligible' and '51462F' or '999483'))
    local iconRect=self.view.Icon.rectTransform
    iconRect.anchoredPosition=CS.UnityEngine.Vector2(hasIcon and 30 or 34,hasIcon and -6 or -10)
    iconRect.sizeDelta=CS.UnityEngine.Vector2(hasIcon and 40 or 32,hasIcon and 40 or 32)
    style:Tint(self.view.Background,state=='owned' and '394D40' or (state=='eligible' and 'F4ECD7' or 'D5CDBA'))
    style:Tint(self.view.Ring,selected and '9E682E' or (state=='owned' and '94753C' or (state=='eligible' and 'A49571' or 'C0B7A2')))
    self.view.Ring.rectTransform.localScale=CS.UnityEngine.Vector3(selected and 1.12 or 1,selected and 1.12 or 1,1)
end
function Node:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.node~=nil) end
return Node
