local LuaLanguage = require('Language')
-- One navigation stack per visible tooltip. View owns geometry, Lua owns configured text.
local Presenter={};Presenter.__index=Presenter
function Presenter.New(view,config)
    return setmetatable({view=assert(view),model=require('Game.Presentation.SkillTipModel').New(config),stack={}},Presenter)
end
function Presenter:Render(page)
    local bridge=CS.ProjectY.UI.SkillTooltipPresentation
    bridge.Begin(self.view,page.title,page.body)
    for _,tag in ipairs(page.tags) do bridge.AddTag(self.view,tag.name,tag.textColor,tag.backgroundColor) end
    for _,stat in ipairs(page.stats) do bridge.AddStat(self.view,stat.label,stat.value,stat.color) end
    for _,entry in ipairs(page.synergies) do bridge.AddSynergy(self.view,entry.name,entry.body,entry.known,entry.active) end
    bridge.SetNavigation(self.view,#self.stack>1,page.breadcrumb)
    bridge.Show(self.view,self.anchor)
end
function Presenter:Show(row,adventure,anchor)
    self.anchor=assert(anchor);self.stack={self.model:Build(row,adventure)};self:Render(self.stack[1])
end
function Presenter:ShowTerm(id,anchor)
    local term=self.model.catalog:Term(id)
    self.anchor=assert(anchor)
    self.stack={{title=term.title,body=term.body,tags={},stats={},synergies={},termId=id,
        breadcrumb=string.format(LuaLanguage.UISkillTipPresenterBreadcrumb,1)}}
    self:Render(self.stack[1])
end
function Presenter:Tick()
    local id=CS.ProjectY.UI.SkillTooltipPresentation.TakeLink(self.view)
    if id=='' then return end
    if id=='__back' then
        if #self.stack>1 then table.remove(self.stack);self:Render(self.stack[#self.stack]) end
        return
    end
    local termId=assert(id:match('^term:([%w_%-]+)$'),'Unsupported tooltip link: '..id)
    -- Repeated references go back to their existing page, so cycles cannot grow the stack.
    for i,page in ipairs(self.stack) do if page.termId==termId then
        for j=#self.stack,i+1,-1 do self.stack[j]=nil end
        self:Render(page);return
    end end
    local term=self.model.catalog:Term(termId)
    local page={title=term.title,body=term.body,tags={},stats={},synergies={},termId=termId,breadcrumb=string.format(LuaLanguage.UISkillTipPresenterBreadcrumb, (#self.stack))}
    self.stack[#self.stack+1]=page;self:Render(page)
end
function Presenter:KeepOpen(anchorHovered)
    return #self.stack>0 and CS.ProjectY.UI.SkillTooltipPresentation.KeepOpen(self.view,anchorHovered==true)
end
function Presenter:Hide()
    CS.ProjectY.UI.SkillTooltipPresentation.Hide(self.view);self.stack={};self.anchor=nil
end
return Presenter
