local LuaLanguage = require('Language')
local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Panel=Class('GMCtr',Base)
function Panel:Bind()
    self.gm=self.context.systems:Get('GM')
    self.npcRows={}
    self:Listen(self.view.Close,function()self:Close()end)
    self:Listen(self.view.LevelUp,function()self:Execute('level_up')end)
    self:Listen(self.view.GrantSkill,function()self:Execute('grant_skill')end)
    self:Listen(self.view.RevealWorld,function()self:RevealWorld()end)
end
function Panel:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetGMOpen(true)
    local font=assert(args.font)
    self.font=font
    for _,key in ipairs({'Title','Description','SlotLabel','SkillLabel','Target','SkillName','Result','LevelUpText','GrantSkillText','CloseText','SlotText','SkillText','NpcTitle','NpcSearchText','NpcHint','NpcCount','RevealWorldText','RevealWorldHint'}) do self.view[key].font=font end
    local slot=1
    for i=0,self.gm.data.PartyCount-1 do if self.gm.data:GetPartyAt(i).Id==self.demo.SelectedCharacterId then slot=i+1;break end end
    self.view.Slot.text=tostring(slot);self.view.Result.text='';self:Refresh();self:RefreshNpcs()
end
function Panel:Refresh()
    local actor,reason=self.gm:Slot(tonumber(self.view.Slot.text))
    self.view.Target.text=actor and (string.format(LuaLanguage.UIGMTargetText, (self.gm.growth.stats:Template(actor).name), (actor.Growth.Level))) or reason
    local skill=self.gm:Skill(tonumber(self.view.SkillId.text))
    self.view.SkillName.text=skill and skill.name or LuaLanguage.UIGMSkillNameText
    self.slotText,self.skillText=self.view.Slot.text,self.view.SkillId.text
end
function Panel:Execute(command)
    local slot=tonumber(self.view.Slot.text);local actor,reason=self.gm:Slot(slot)
    if not actor then self.view.Result.text=reason;return end
    local id=tonumber(self.view.SkillId.text)
    if command=='grant_skill' and not self.gm:Skill(id) then self.view.Result.text=LuaLanguage.UIGMResultText4;return end
    local previous=self.demo.BattleHUDRevision
    self.demo:SendCommand('gm_'..command,slot,id or 0)
    if previous==self.demo.BattleHUDRevision then self.view.Result.text=LuaLanguage.UIGMResultText3;return end
    local errorText=self.demo.LastError
    self.view.Result.text=errorText and errorText~='' and errorText or (command=='level_up' and (string.format(LuaLanguage.UIGMResultText2, (actor.Growth.Level))) or (string.format(LuaLanguage.UIGMResultText, (self.gm:Skill(id).name))))
    self:Refresh()
end
function Panel:Tick()
    if self.slotText~=self.view.Slot.text or self.skillText~=self.view.SkillId.text then self:Refresh() end
    if self.npcQuery~=self.view.NpcSearch.text then self:RefreshNpcs() end
end
function Panel:RefreshNpcs()
    self.npcQuery=self.view.NpcSearch.text
    local rows=self.gm.npcs:Search(self.npcQuery)
    self.view.NpcCount.text=#rows==0 and LuaLanguage.UIGMNpcCountText2 or (string.format(LuaLanguage.UIGMNpcCountText, (#rows)))
    for i,row in ipairs(rows) do
        if not self.npcRows[i] then self.npcRows[i]=self:CreateWidget('NarrativeEntry',self.view.NpcRows) end
        local id=row.id
        self.npcRows[i]:SetData({title=row.name..'  #'..id,body=row.body,available=row.available},self.font,function() self:GoToNpc(id) end)
    end
    for i=#rows+1,#self.npcRows do self.npcRows[i]:SetData(nil) end
end
function Panel:GoToNpc(id)
    local previous=self.demo.BattleHUDRevision
    self.demo:SendCommand('gm_goto_npc',id,0)
    if self.demo.BattleHUDRevision==previous then self.view.Result.text=LuaLanguage.UIGMResultText3;return end
    local errorText=self.demo.LastError
    self.view.Result.text=errorText and errorText~='' and errorText or (string.format(LuaLanguage.UIGMResultText5, (self.gm.npcs.story.rules.npcs:Get(id).name)))
    self:RefreshNpcs()
end
function Panel:RevealWorld()
    local previous=self.demo.BattleHUDRevision
    self.demo:SendCommand('gm_reveal_world',0,0)
    if self.demo.BattleHUDRevision==previous then self.view.Result.text=LuaLanguage.UIGMResultText3;return end
    local errorText=self.demo.LastError
    self.view.Result.text=errorText and errorText~='' and errorText or LuaLanguage.GMRevealWorldSuccess
end
function Panel:OnHide() if self.demo then self.demo:SetGMOpen(false);self.demo=nil end end
return Panel
