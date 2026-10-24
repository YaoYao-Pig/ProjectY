local Class = require('Core.Class')
local Base = require('UI.UIPanelCtrl')
local Loading = Class('LoadingCtr', Base)

function Loading:OnShow(state)
    self.state = assert(state)
    for _, key in ipairs({'Title', 'Stage', 'Percent', 'TipCategory', 'Tip'}) do
        self.view[key].font = state.font
    end
    self.view.Title.text = state.title
    self.tipIndex = nil
    self:NextTip()
    self:RefreshProgress()
end

function Loading:NextTip()
    local tips = self.state.tips
    local index = self.state.random:Integer(1, #tips - (self.tipIndex and #tips > 1 and 1 or 0))
    if self.tipIndex and #tips > 1 and index >= self.tipIndex then index = index + 1 end
    self.tipIndex = index
    local tip = tips[index]
    self.view.TipCategory.text = tip.category
    self.view.Tip.text = tip.content
    self.remaining = tip.duration
end

function Loading:RefreshProgress()
    self.view.Progress.value = self.state.progress
    self.view.Percent.text = string.format('%d%%', math.floor(self.state.progress * 100 + .00001))
    self.view.Stage.text = self.state.stage
end

function Loading:Tick(_, unscaledDt)
    self:RefreshProgress()
    self.remaining = self.remaining - unscaledDt
    if self.remaining <= 0 then self:NextTip() end
end

function Loading:OnHide() self.state = nil; self.tipIndex = nil end
return Loading
