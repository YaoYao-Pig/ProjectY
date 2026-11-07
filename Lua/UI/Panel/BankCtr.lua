local L=require('Language')
local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Panel=Class('BankCtr',Base)
function Panel:Bind()
    self.model=self.context.systems:Get('Adventure').economy;self.range=30
    self:Listen(self.view.Close,function()self.demo:SendCommand('bank_close')end)
    self:Listen(self.view.InvestSmall,function()self.demo:SendCommand('bank_invest',100,self.revision)end)
    self:Listen(self.view.InvestLarge,function()self.demo:SendCommand('bank_invest',500,self.revision)end)
    self:Listen(self.view.Claim,function()self.demo:SendCommand('bank_claim',0,self.revision)end)
    self:Listen(self.view.Range,function()self.range=self.range==15 and 30 or self.range==30 and 60 or 15;self:Refresh()end)
end
function Panel:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetStoryOpen(true)
    self.view.Style:Prepare(self.demo.MainHudFont,1120);self:Refresh()
end
function Panel:Refresh()
    local data=self.model.data;local a=self.model.adventure;local town=data:FindTown(data.ActiveBankSite)
    if not town then return end
    local rule=self.model.rule;local r=self.view
    r.Title.text=string.format(L.EconomyBankTitle,a.sites[town.SiteId].name)
    r.Caption.text=string.format(L.EconomyBankCaption,town.NetValue,a.player.Coins)
    r.Tags.text=self.model:Tags(town.SiteId)
    r.Risk.text=string.format(L.EconomyBankRisk,rule.termDays,rule.maximumLossPercent,rule.maximumGainPercent,rule.investmentLimit)
    r.InvestSmallLabel.text=string.format(L.EconomyInvest,100);r.InvestLargeLabel.text=string.format(L.EconomyInvest,500)
    r.CloseLabel.text=L.EconomyClose;r.ClaimLabel.text=L.EconomyClaim
    r.RangeLabel.text=string.format(L.EconomyChartRange,self.range)
    r.Legend.text=L.EconomyChartLegend
    local ok,reason=self.model:BankSession()
    r.InvestSmall.interactable=ok and town.Principal==0 and a.player.Coins>=100 and rule.investmentLimit>=100
    r.InvestLarge.interactable=ok and town.Principal==0 and a.player.Coins>=500 and rule.investmentLimit>=500
    r.Claim.interactable=ok and town.Principal>0 and town.Payout>=0
    if town.Principal==0 then r.Position.text=L.EconomyNoPosition
    elseif town.Payout>=0 then r.Position.text=string.format(L.EconomyMaturePosition,town.Principal,town.Payout,town.Payout-town.Principal)
    else
        local estimated=math.floor(town.Principal*math.max(1-rule.maximumLossPercent/100,math.min(1+rule.maximumGainPercent/100,town.NetValue/town.EntryValue)))
        r.Position.text=string.format(L.EconomyOpenPosition,town.Principal,town.EntryValue,estimated,estimated-town.Principal,
            math.floor(town.DueTick/4)+1,(town.DueTick%4)*6)
    end
    self.candles={};local days,opens,highs,lows,closes={},{},{},{},{}
    for i=math.max(0,town.CandleCount-self.range),town.CandleCount-1 do local c=town:GetCandleAt(i)
        self.candles[#self.candles+1]=c;days[#days+1]=c.Day;opens[#opens+1]=c.Open;highs[#highs+1]=c.High;lows[#lows+1]=c.Low;closes[#closes+1]=c.Close
    end
    r.Chart:SetCandles(days,opens,highs,lows,closes)
    r.AxisHigh.text=string.format(L.EconomyChartPrice,r.Chart.Maximum);r.AxisLow.text=string.format(L.EconomyChartPrice,r.Chart.Minimum)
    r.DateRange.text=string.format(L.EconomyChartDates,days[1],days[#days])
    r.Hint.text=self.demo.LastError~='' and self.demo.LastError or not ok and reason or L.EconomyChartHelp
    self.revision=data.Revision;self.coins=a.player.Coins;self.demoRevision=self.demo.BattleHUDRevision;self.hover=nil;self:Hover()
end
function Panel:Hover()
    local index=self.view.Chart.HoverIndex
    if self.hover==index then return end;self.hover=index
    local c=self.candles[index>=0 and index+1 or #self.candles]
    if c then self.view.OHLC.text=string.format(L.EconomyChartOHLC,c.Day,c.Open,c.High,c.Low,c.Close,(c.Close/c.Open-1)*100) end
end
function Panel:Tick()
    local data=self.model.data;if data.ActiveBankSite==0 then return end
    if self.revision~=data.Revision or self.coins~=self.model.adventure.player.Coins or self.demoRevision~=self.demo.BattleHUDRevision then self:Refresh() end
    self:Hover()
end
function Panel:OnHide()
    self.model:CloseBank();if self.demo then self.demo:SetStoryOpen(false);self.demo=nil end
end
return Panel
