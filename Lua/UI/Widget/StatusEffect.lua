local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Effect=Class('StatusEffect',Base)
function Effect:SetData(row,style,icon)
    self.row=row;self.effect=true;self.view.Root.gameObject:SetActive(row~=nil)
    if not row then return end
    self.view.Glyph.font,self.view.Count.font=style.Font,style.Font
    local finish=utf8.offset(row.name,2)
    self.view.Glyph.text=finish and row.name:sub(1,finish-1) or row.name
    self.view.Count.text=(row.stacks>1 and ('×'..row.stacks..' ') or '')..row.timerText
    local color=require('Config.Color').Normalize(row.color)
    self.view.Glyph.color=CS.UnityEngine.Color(tonumber(color:sub(2,3),16)/255,tonumber(color:sub(4,5),16)/255,tonumber(color:sub(6,7),16)/255,1)
    style:SetIcon(self.view.Icon,icon.id,icon.spritePath);self.view.Glyph.gameObject:SetActive(icon.spritePath=='')
end
function Effect:IsHovered() return self.view.Pointer.Hovered end
function Effect:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.row~=nil) end
return Effect
