-- Production widget state projection without Editor; native Button tint events have a separate Edit Mode check.
package.path='Lua/?.lua;'..package.path
CS={UnityEngine={Color=function(r,g,b,a)return {r=r,g=g,b=b,a=a or 1}end}}
local Color=CS.UnityEngine.Color
local Action=require('UI.Widget.BattleAction')
local assignments=0
local buttonState={interactable=true,colors={normalColor=Color(.105,.116,.106),highlightedColor=Color(.23,.25,.19),
    pressedColor=Color(.075,.085,.065),selectedColor=Color(.105,.116,.106),disabledColor=Color(.07,.077,.07),fadeDuration=.12,colorMultiplier=1}}
local button=setmetatable({}, {__index=function(_,key)
    if key~='colors' then return buttonState[key] end
    local copy={};for k,v in pairs(buttonState.colors)do copy[k]=v end;return copy -- Unity returns ColorBlock by value.
end,__newindex=function(_,key,value)if key=='colors'then assignments=assignments+1 end;buttonState[key]=value end})
local selected={activeSelf=false};function selected:SetActive(value)self.activeSelf=value end
local view={Button=button,Selected={gameObject=selected},Pointer={Hovered=false},
    Title={color=Color(.87,.85,.76)},Cost={color=Color(.57,.60,.55)},Shortcut={},Icon={}}
local activated=0
local widget=setmetatable({view=view,Listen=function(self,_,callback)self.click=callback end},Action)
widget:Bind();widget:Initialize({Font='fixture',SetIcon=function(_,icon,id,path)icon.enabled=path~='';icon.sprite=id end},function()activated=activated+1 end)
local row={id=12,name='重击',cost=2,available=true};local icon={id=5,spritePath='fixture'}
widget:SetData(row,1,false,icon)
assert(button.interactable and not selected.activeSelf and view.Icon.enabled and view.Shortcut.text=='1')
assert(button.colors.highlightedColor.r>button.colors.normalColor.r*1.5,'Hover must visibly brighten the native button tint')
local writes=assignments;view.Pointer.Hovered=true
widget:SetData({id=12,name='重击',cost=2,available=true},1,false,icon)
assert(widget:IsHovered() and assignments==writes,'Routine refresh must preserve hover and the native transition')
widget.click();assert(activated==1)
widget:SetData(row,1,true,icon)
assert(selected.activeSelf and button.colors.normalColor.r>widget.baseColors.normalColor.r*2 and view.Title.color==widget.palette.selectedTitle)
view.Pointer.Hovered=false;widget:SetData(row,1,true,icon)
assert(selected.activeSelf and not widget:IsHovered(),'Mouse exit must retain model selection')
row.available=false;widget:SetData(row,1,true,icon);widget.click()
assert(not button.interactable and activated==1 and view.Icon.color.a<1 and view.Title.color==widget.palette.disabledText)
view.Pointer.Hovered=true;assert(widget:IsHovered(),'Disabled skill must still expose its unavailable tooltip')
widget:OnHide();assert(not selected.activeSelf and not button.interactable and widget.row==nil)
view.Pointer.Hovered=false -- UIPointerState.OnDisable owns this native lifecycle reset.
row.available=true;widget:SetData(row,1,true,icon)
assert(selected.activeSelf and button.interactable and view.Icon.color.a==1,'Cache reuse must rebuild the current selection and availability')
widget:SetData(row,1,false,icon)
assert(not selected.activeSelf and button.colors.normalColor==widget.baseColors.normalColor,'Keyboard move selection must clear the skill style')
widget:SetData(nil,nil,false,nil);widget.click()
assert(not selected.activeSelf and not button.interactable and not view.Icon.enabled and view.Title.text=='' and activated==1)
print('PASS action feedback: visible hover palette, refresh preservation, model/keyboard selection, disabled click guard, hide/reuse and empty slots')
