local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local Entry=Class('DialogueEntry',Base)
local Color=CS.UnityEngine.Color
local accents={npc=Color(.85,.65,.40,1),player=Color(.64,.73,.82,1),narrator=Color(.52,.59,.59,1),
    companion=Color(.49,.75,.70,1),choice=Color(.85,.75,.54,1),invite=Color(.49,.75,.70,1)}
local voices={Color(.49,.75,.70,1),Color(.74,.64,.82,1),Color(.63,.74,.87,1),Color(.87,.70,.49,1)}
function Entry:Bind()
    self:Listen(self.view.Button,function() if self.action then self.action() end end)
end
function Entry:SetData(row,font,action)
    self.row,self.action=row,action
    self.view.Root.gameObject:SetActive(row~=nil)
    if not row then return end
    self.view.Style:Prepare(font,0)
    local interactive=action~=nil
    local locked=interactive and row.available==false
    local accent=row.actorId and row.actorId>0 and voices[(row.actorId-1)%#voices+1] or accents[row.kind]
    self.view.Title.DefaultText=(locked and '     ' or '')..row.title
    self.view.Body.DefaultText=row.body
    self.view.Title.gameObject:SetActive(row.title~='')
    self.view.Body.gameObject:SetActive(row.body~='')
    self.view.Title.fontSize=interactive and 17 or 18
    self.view.Body.fontSize=interactive and 13 or 18
    self.view.Title.color=locked and Color(.49,.53,.54,1) or accent
    self.view.Body.color=locked and Color(.58,.59,.56,1) or Color(.86,.86,.80,1)
    self.view.Body.lineSpacing=interactive and 2 or 9
    self.view.Accent.color=accent
    self.view.Accent.gameObject:SetActive(not interactive)
    self.view.Locked.gameObject:SetActive(locked)
    self.view.Button.interactable=interactive and not locked
    self.view.Background.color=interactive and (row.kind=='invite' and Color(.085,.17,.17,.98) or Color(.13,.17,.19,.98))
        or row.kind=='companion' and Color(.045,.105,.12,.97) or Color(.035,.065,.085,.96)
    self.view.Layout.padding=CS.UnityEngine.RectOffset(interactive and 18 or 22,20,interactive and 12 or 18,interactive and 12 or 20)
end
function Entry:Show(args) Base.Show(self,args);self.view.Root.gameObject:SetActive(self.row~=nil) end
return Entry
