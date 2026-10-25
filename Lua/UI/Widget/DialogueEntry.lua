local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Skin=require('UI.ArtSkin')
local Entry=Class('DialogueEntry',Base)
local Color=CS.UnityEngine.Color
function Entry:Bind()
    self.skin=Skin.Read(self.view.Skin)
    self.speakerFont=assert(self.view.Title.font,'Dialogue speaker font is not bound')
    self.view.Title.enableWordWrapping=true
    self.view.Body.enableWordWrapping=true
    self.view.Layout.childControlWidth=true
    self.view.Layout.childControlHeight=true
    self.view.Layout.childForceExpandWidth=true
    self.view.Layout.childForceExpandHeight=false
    self.view.Layout.spacing=8
    self.view.Sizing.preferredHeight=-1
    self.view.Sizing.flexibleHeight=0
    local colors=self.skin.colors
    self.accents={npc=colors.accent_ink,player=colors.ink,narrator=colors.muted,
        companion=Color.Lerp(colors.ink,colors.accent_ink,.35),choice=colors.ink,invite=colors.accent_ink}
    self.voices={colors.accent_ink,colors.ink,Color.Lerp(colors.ink,colors.accent_ink,.35),Color.Lerp(colors.ink,colors.accent_ink,.7)}
    self:Listen(self.view.Button,function() if self.action then self.action() end end)
end
function Entry:SetData(row,font,action)
    self.row,self.action=row,action
    self.view.Root.gameObject:SetActive(row~=nil)
    if not row then return end
    self.view.Style:Prepare(font,0)
    local interactive=action~=nil
    self.view.Title.font=interactive and self.view.Body.font or self.speakerFont
    local locked=interactive and row.available==false
    local accent=row.actorId and row.actorId>0 and self.voices[(row.actorId-1)%#self.voices+1] or self.accents[row.kind]
    self.view.Title.DefaultText=(locked and '     ' or '')..row.title
    self.view.Body.DefaultText=row.body
    self.view.Title.gameObject:SetActive(row.title~='')
    self.view.Body.gameObject:SetActive(row.body~='')
    self.view.Title.fontSize=interactive and 17 or 18
    self.view.Body.fontSize=interactive and 13 or 18
    self.view.Title.color=locked and self.skin.colors.disabled_ink or accent
    self.view.Body.color=locked and self.skin.colors.disabled_ink or self.skin.colors.ink
    self.view.Body.lineSpacing=interactive and 2 or 9
    self.view.Accent.color=accent
    self.view.Accent.gameObject:SetActive(not interactive)
    self.view.Locked.gameObject:SetActive(locked)
    self.view.Button.interactable=interactive and not locked
    local companion=row.kind=='companion'
    local surface=interactive and 'button_light' or (companion and 'panel_dark' or 'panel_light')
    Skin.ApplyButton(self.skin,self.view.Button,nil,{normal=surface,disabled=surface,dark=companion})
    if not interactive then
        self.view.Button.transition=CS.UnityEngine.UI.Selectable.Transition.None
        self.view.Background:CrossFadeColor(Color.white,0,true,true)
        if companion then self.view.Title.color=self.skin.colors.on_accent;self.view.Body.color=self.skin.colors.on_dark end
    end
    -- Reserve the paper's decorative edge; the layout uses wrapped text preferred heights.
    self.view.Layout.padding=CS.UnityEngine.RectOffset(interactive and 28 or (companion and 54 or 40),interactive and 28 or 36,interactive and 20 or 34,interactive and 20 or 36)
    self.view.Sizing.minHeight=interactive and 64 or 116
end
function Entry:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.row~=nil) end
return Entry
