local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local LuaLanguage=require('Language')
local Rich=require('UI.RichText')
local Reward=Class('MissionReward',Base)
local colors={coins={.92,.74,.35},experience={.48,.77,1},item={.73,.83,.69},recruit={.70,.61,.96},relation={.95,.62,.67},reputation={.62,.85,.74}}
function Reward:SetData(row,font)
    self.row=row;self.view.Root.gameObject:SetActive(row~=nil)
    if not row then return end
    self.view.Style:Prepare(font,0)
    local rgb=assert(colors[row.kind],'Unknown mission reward kind')
    local color=CS.UnityEngine.Color(rgb[1],rgb[2],rgb[3],1)
    self.view.Accent.color=color;self.view.Glyph.color=color;self.view.Amount.color=color
    self.view.Icon.enabled=false
    local glyph=row.kind=='experience' and 'EXP+' or row.kind=='coins' and 'G' or row.kind=='recruit' and '+' or row.kind=='item' and LuaLanguage.MissionRewardItemGlyph or '+'
    local hasIcon=row.kind=='item' and self.view.ItemIcon:Show(row.itemId,row.iconPath)
    self.view.Glyph.gameObject:SetActive(not hasIcon);self.view.Glyph.DefaultText=glyph
    self.view.Name.DefaultText=Rich.Escape(row.name)
    self.view.Amount.DefaultText=row.amount and string.format('%+d',row.amount) or ''
    local notes={experience=LuaLanguage.MissionRewardEachMember,item=LuaLanguage.MissionRewardToInventory,coins=LuaLanguage.MissionRewardShared,
        recruit=LuaLanguage.MissionRewardRecruit,relation=LuaLanguage.MissionRewardRelation,reputation=LuaLanguage.MissionRewardReputation}
    self.view.Note.DefaultText=row.note or assert(notes[row.kind])
end
function Reward:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.row~=nil) end
return Reward
