local LuaLanguage = require('Language')
local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Dice=Class('DiceRollCtr',Base)
function Dice:Bind()
    self.resultFontSize=self.view.Result.fontSize
    self:Listen(self.view.Reveal,function() self.view.Dice:Reveal();self:Result() end)
    self:Listen(self.view.Continue,function()
        if not self.view.Dice.Settled then return end
        if self.check.rounds and self.roundIndex<#self.check.rounds then
            self.roundIndex=self.roundIndex+1;self:StartRound();return
        end
        if #self.queue>0 then self:Start(table.remove(self.queue,1)) else self:Close() end
    end)
end
function Dice:OnShow(args)
    self.queue={};self.sequence=0
    self:Start(assert(args.check,'DiceRoll needs a settled check'))
end
function Dice:Enqueue(check) self.queue[#self.queue+1]=check end
function Dice:Start(check)
    self.check=check;self.roundIndex=1;self:StartRound()
end
function Dice:StartRound()
    local check=self.check.rounds and self.check.rounds[self.roundIndex] or self.check
    self.shown=false;self.sequence=self.sequence+1
    self.view.Title.text=check.title
    self.view.Detail.text=check.detail
    self.view.Result.fontSize=(check.kind=='roll' or self.check.rounds) and math.min(self.resultFontSize,20) or self.resultFontSize
    self.view.Result.text='';self.view.Continue.interactable=false
    self.view.Reveal.gameObject:SetActive(true)
    self.view.Dice:Prepare()
    for _,die in ipairs(check.dice) do self.view.Dice:AddDie(die.kind,die.value,die.label or die.kind) end
    -- Presentation-only variation; it cannot change outcomes or consume the game RNG.
    self.view.Dice:Throw(math.floor(CS.UnityEngine.Time.realtimeSinceStartup*1000)%2147483000+self.sequence)
end
function Dice:Result()
    if self.shown or not self.view.Dice.Settled then return end
    self.shown=true
    if self.check.rounds and self.roundIndex<#self.check.rounds then
        self.view.Result.text=string.format(LuaLanguage.DiceAdvantageRoundResult,self.roundIndex,self.check.rounds[self.roundIndex].reading)
    elseif self.check.kind=='roll' then
        self.view.Result.text=self.check.reading
    else
        assert(type(self.check.passed)=='boolean','A settled check needs a boolean outcome')
        self.view.Result.text='<color='..(self.check.passed and '#79E6C3' or '#ED897C')..'>'..
            self.check.reading..'  ·  '..(self.check.passed and LuaLanguage.DiceSuccess or LuaLanguage.DiceFailure)..'</color>'
    end
    self.view.Continue.interactable=true;self.view.Reveal.gameObject:SetActive(false)
end
function Dice:Tick(_,unscaledDt) self.view.Dice:Advance(unscaledDt);self:Result() end
function Dice:OnHide() self.view.Dice:Release();self.queue=nil;self.check=nil end
return Dice
