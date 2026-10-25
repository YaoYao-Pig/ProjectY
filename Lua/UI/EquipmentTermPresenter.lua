-- Links in the equipment's scrollable body reuse the skill-card term navigation.
local Terms={};Terms.__index=Terms
function Terms.New(view,config)
    return setmetatable({source=assert(view.DescriptionLinks),
        presenter=require('UI.SkillTipPresenter').New(assert(view.EquipmentTermTip),config),text=nil},Terms)
end
function Terms:Reset()
    self.source:Clear();self.presenter:Hide();self.text=self.source.SourceText.text
end
function Terms:Tick()
    local text=self.source.SourceText.text
    if text~=self.text then self:Reset()end
    local target=self.source:TakeLink()
    if target~=''then
        local id=assert(target:match('^term:([%w_%-]+)$'),'Unsupported equipment term link: '..target)
        self.presenter:ShowTerm(id,self.source.Anchor)
    end
    self.presenter:Tick()
    if not self.presenter:KeepOpen(self.source:IsHovered())then self.presenter:Hide()end
end
return Terms
