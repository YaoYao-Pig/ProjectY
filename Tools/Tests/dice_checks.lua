package.path='Lua/?.lua;'..package.path
local Checks=require('Game.Presentation.DiceChecks')
local function value(row)
    local dice=row.dice
    local whole=dice[1].value+dice[2].value
    if #dice==4 then return whole+dice[3].value/10+dice[4].value/100 end
    return whole
end
for roll=1,100 do
    local check=Checks.Percent('开锁',roll,37,roll<=37,'inclusive',1)
    assert(value(check)==roll%100 and check.passed==(roll<=37))
end
for roll=0,99 do
    local check=Checks.Percent('触发',roll,37,roll<37,'exclusive',1)
    assert(value(check)==roll and check.passed==(roll<37))
end
for _,roll in ipairs({0,.01,24.99,25,25.01,99.99}) do
    local check=Checks.Percent('驯服',roll,25,roll<25,'exclusive',100)
    assert(#check.dice==4 and math.abs(value(check)-roll)<.000001)
end
assert(Checks.Percent('清障',100,35,false,'inclusive').reading=='100')
assert(Checks.Percent('效果',0,35,true,'exclusive').reading=='0')
assert(Checks.Percent('驯服',25.01,25,false,'exclusive',100).reading=='25.01')
assert(not pcall(Checks.Percent,'错误精度',24.99,25,true,'exclusive',1))
assert(not pcall(Checks.Percent,'越界',100,25,false,'exclusive',1))
assert(not Checks.FromBattleEvent({kind='damage'}))
assert(not Checks.FromBattleEvent({kind='check',impact={chance=100,passed=true}}))
local high=Checks.FromBattleEvent({kind='check',impact={checkName='Burn',roll=89,chance=60,passed=true,threshold=40,rollComparison='greater',rollConvention='inclusive'}})
assert(high.passed and high.reading=='89' and high.detail:find('40',1,true) and high.detail:find('60%',1,true))
local row=Checks.FromBattleEvent({kind='check',impact={checkName='祝福触发',roll=72,chance=50,passed=false}})
assert(value(row)==72 and not row.passed)
-- Drive the real controller's button callbacks: queued checks must not be overwritten or revealed early.
CS={UnityEngine={Time={realtimeSinceStartup=12.5}}}
local Dice=require('UI.Panel.DiceRollCtr')
local presented,buttons,closed={}, {},0
local renderer={Settled=false}
function renderer:Prepare()self.Settled=false;self.current={}end
function renderer:AddDie(kind,result,label)self.current[#self.current+1]={kind,result,label}end
function renderer:Throw()presented[#presented+1]=self.current end
function renderer:Reveal()self.Settled=true end
function renderer:Advance()end
function renderer:Release()self.Settled=false end
local reveal={gameObject={SetActive=function()end}}
local ctrl=setmetatable({view={Dice=renderer,Title={},Detail={},Result={fontSize=30},Continue={},Reveal=reveal}}, {__index=Dice})
function ctrl:Listen(button,fn)buttons[button]=fn end
function ctrl:Close()closed=closed+1;self:OnHide()end
ctrl:Bind();ctrl:OnShow({check=row})
assert(ctrl.view.Result.text=='' and not ctrl.view.Continue.interactable and #presented==1)
ctrl:Enqueue(Checks.Percent('第二次',37,50,true,'inclusive'))
buttons[ctrl.view.Continue]()
assert(#presented==1 and closed==0,'Early continue must not skip the active check')
buttons[ctrl.view.Reveal]()
assert(ctrl.view.Continue.interactable and ctrl.view.Result.text:find('72',1,true))
buttons[ctrl.view.Continue]()
assert(#presented==2 and ctrl.view.Title.text=='第二次' and ctrl.view.Result.text=='')
buttons[ctrl.view.Reveal]();buttons[ctrl.view.Continue]()
assert(closed==1 and ctrl.queue==nil and not renderer.Settled)
local ok,freeRoll=require('Game.GM.DiceCommands').New(7):Roll({D6=2,D20=1});assert(ok)
ctrl:OnShow({check=freeRoll});assert(ctrl.view.Result.text=='' and ctrl.view.Result.fontSize==20)
ctrl:Enqueue(Checks.Percent('回到检定',20,50,true,'inclusive'))
buttons[ctrl.view.Reveal]();assert(ctrl.view.Result.text==freeRoll.reading)
buttons[ctrl.view.Continue]();assert(ctrl.view.Result.fontSize==30 and ctrl.view.Result.text=='')
buttons[ctrl.view.Reveal]();assert(ctrl.view.Result.text:find(require('Language').DiceSuccess,1,true))
buttons[ctrl.view.Continue]();assert(closed==2)
-- Two percentile rolls are one settled check, shown sequentially within the six-die renderer limit.
local draws=0
local result=require('Game.CheckRoll').Resolve(2500,100,function()
    draws=draws+1;return draws==1 and 9999 or 2499
end,{'animal_speech'})
local advantage=Checks.Resolved('驯服',result)
assert(#advantage.rounds==2 and #advantage.rounds[1].dice==4 and #advantage.rounds[2].dice==4)
assert(advantage.rounds[1].reading=='0.01' and advantage.rounds[2].reading=='75.01')
assert(advantage.reading:find('<b>75.01</b>',1,true) and advantage.passed)
assert(advantage.detail:find('动物沟通',1,true) and advantage.detail:find('43.75',1,true))
assert(Checks.FromBattleEvent({kind='check',impact={checkName='驯服',check=result}}).reading==advantage.reading)
local before=#presented
ctrl:OnShow({check=advantage});ctrl:Enqueue(row)
buttons[ctrl.view.Continue]();assert(#presented==before+1,'Unsettled first roll must not advance')
buttons[ctrl.view.Reveal]();buttons[ctrl.view.Reveal]()
assert(ctrl.view.Result.text:find('0.01',1,true) and not ctrl.view.Result.text:find(require('Language').DiceSuccess,1,true))
buttons[ctrl.view.Continue]();assert(#presented==before+2 and ctrl.roundIndex==2 and ctrl.view.Result.text=='')
buttons[ctrl.view.Continue]();assert(#presented==before+2,'Unsettled second roll must not advance')
buttons[ctrl.view.Reveal]()
assert(ctrl.view.Result.text:find('<b>75.01</b>',1,true) and ctrl.view.Result.text:find(require('Language').DiceSuccess,1,true))
buttons[ctrl.view.Continue]();assert(#presented==before+3 and ctrl.check==row and ctrl.view.Result.fontSize==30)
buttons[ctrl.view.Reveal]();buttons[ctrl.view.Continue]();assert(closed==3 and draws==2)
ctrl:OnShow({check=advantage});buttons[ctrl.view.Reveal]();buttons[ctrl.view.Continue]();buttons[ctrl.view.Reveal]()
assert(draws==2 and ctrl.view.Result.text:find('<b>75.01</b>',1,true),'Cached replay must only show the settled outcome')
buttons[ctrl.view.Continue]();assert(closed==4)
for _,path in ipairs({'Lua/UI/Panel/DiceRollCtr.lua','Lua/UI/Panel/MainHudCtr.lua','Lua/Game/Adventure/EventSystem.lua',
    'Lua/Game/MapArea/ObstacleInteractions.lua','Lua/Game/MapArea/MapAreaSystem.lua'})do assert(loadfile(path))end
print('PASS percentile boundaries, advantage rounds/selection, six-die limit, reveal/queue/replay lifecycle and Lua syntax')
