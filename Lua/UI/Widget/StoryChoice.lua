local Class = require('Core.Class')
local Base = require('UI.Widget.GrowthRow')
local Skin=require('UI.ArtSkin')
local Choice=Class('StoryChoice',Base)
function Choice:Bind()
    self.skin=Skin.Read(self.view.Skin)
    self.choiceFont=assert(self.view.Title.font,'Story choice narrative font is not bound')
    self.view.Layout.padding=CS.UnityEngine.RectOffset(32,32,24,32)
    self.view.Layout.spacing=6
    self.view.Layout.childControlWidth=true
    self.view.Layout.childControlHeight=true
    self.view.Layout.childForceExpandWidth=true
    self.view.Layout.childForceExpandHeight=false
    self.view.Sizing.minHeight=104
    self.view.Sizing.preferredHeight=-1
    self.view.Sizing.flexibleHeight=0
    self.view.Title.horizontalOverflow=CS.UnityEngine.HorizontalWrapMode.Wrap
    self.view.Body.horizontalOverflow=CS.UnityEngine.HorizontalWrapMode.Wrap
    self.view.Title.verticalOverflow=CS.UnityEngine.VerticalWrapMode.Overflow
    self.view.Body.verticalOverflow=CS.UnityEngine.VerticalWrapMode.Overflow
    Base.Bind(self)
end
function Choice:SetData(row,style,action)
    Base.SetData(self,row,style,action)
    if not row then return end
    self.view.Title.font=self.choiceFont
    self.view.Title.gameObject:SetActive(row.title~='')
    self.view.Body.gameObject:SetActive(row.body~='')
    Skin.ApplyButton(self.skin,self.view.Button,self.view.Title)
    self.view.Body.color=self.view.Button.interactable and self.skin.colors.muted or self.skin.colors.disabled_ink
end
return Choice
