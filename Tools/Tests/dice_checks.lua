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
local ctrl=setmetatable({view={Dice=renderer,Title={},Detail={},Result={},Continue={},Reveal=reveal}}, {__index=Dice})
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
for _,path in ipairs({'Lua/UI/Panel/DiceRollCtr.lua','Lua/UI/Panel/MainHudCtr.lua','Lua/Game/Adventure/EventSystem.lua',
    'Lua/Game/MapArea/ObstacleInteractions.lua','Lua/Game/MapArea/MapAreaSystem.lua'})do assert(loadfile(path))end
print('PASS percentile boundaries, 00/100 convention, hundredth precision, guaranteed-effect filtering, reveal/queue/close lifecycle and Lua syntax')
