-- Real exported equipment/skill prose and shared term presenter; no gameplay data is mutated.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local value=file:read('*a');file:close();return value
end}})
local Model=require('Game.Presentation.EquipmentDescriptionModel')
local model=Model.New(config)
local count=0
for _,legendary in ipairs(config:GetTable('LegendaryEquipmentTable'):All())do
    local row=config:GetTable('EquipmentDescriptionTable'):Get(legendary.id)
    local body=model:Equipment(legendary.id)
    assert(body:find(row.passiveName,1,true)and body:find('<b>',1,true),'Missing named effect hierarchy')
    assert(body:find('<link="term:',1,true)and body:find('<u>',1,true),'Equipment terms are not linked')
    for _,id in ipairs(row.skillIds)do assert(body:find(config:GetTable('CombatSkillTable'):Get(id).name,1,true),'Equipment skill omitted')end
    count=count+1
end
assert(count==15)
print('PASS all 15 equipment entries have named effects, explicit terms and complete granted skill descriptions')
local lance=model:Equipment(9015)
assert(lance:find('term:momentum',1,true)and lance:find('term:main_action',1,true),'Lance terminology missing')
local actual={};for key,value in pairs(config:GetTable('CombatSkillTable'):Get(2215))do actual[key]=value end
actual.cost=2;actual.damageScale=1.17;actual.hitChance=83;actual.cooldownTurns=4;actual.maxTargets=3;actual.shots=2
local resolved=model:Skill(actual)
assert(resolved:find('2 AP',1,true)and resolved:find('1.17',1,true)and resolved:find('83%',1,true)and resolved:find('4 回合',1,true),'Resolved skill parameters were replaced with base values')
assert(resolved:find(string.format(require('Language').UISkillTipText6,3),1,true)and resolved:find(string.format(require('Language').UISkillTipText4,2),1,true),'Resolved target/shot counts omitted')
assert(model:Equipment(40)~=''and model:Equipment(57)=='','Ordinary weapon or unconfigured shield fallback changed')
assert(not pcall(function()model.catalog:Rich('<link="term:does_not_exist">broken</link>')end),'Unknown term silently accepted')
print('PASS live weapon skill parameters, ordinary-equipment fallback and invalid-term rejection')

local visible,page,queued=false,nil,''
CS={ProjectY={UI={SkillTooltipPresentation={
    Begin=function(_,title,body)page={title=title,body=body}end,
    AddTag=function()end,AddStat=function()end,AddSynergy=function()end,
    SetNavigation=function(_,back)page.back=back end,
    Show=function()visible=true end,Hide=function()visible=false end,
    TakeLink=function()local value=queued;queued='';return value end,
    KeepOpen=function(_,hovered)return visible and hovered end,
}}}}
local input={SourceText={text='equipment-A'},Anchor={},next='',hover=true}
function input:Clear()self.next=''end
function input:TakeLink()local value=self.next;self.next='';return value end
function input:IsHovered()return self.hover end
local terms=require('UI.EquipmentTermPresenter').New({DescriptionLinks=input,EquipmentTermTip={}},config)
terms:Reset();input.next='term:momentum';terms:Tick()
assert(visible and page.title==model.catalog:Term('momentum').title and not page.back)
queued='term:main_action';terms:Tick();assert(#terms.presenter.stack==2 and page.back)
queued='__back';terms:Tick();assert(#terms.presenter.stack==1)
queued='term:momentum';terms:Tick();assert(#terms.presenter.stack==1,'Repeated term grew navigation indefinitely')
input.SourceText.text='equipment-B';terms:Tick();assert(not visible and #terms.presenter.stack==0,'Selection change retained stale terminology')
input.next='term:momentum';terms:Tick();input.hover=false;terms:Tick();assert(not visible,'Leaving source/card retained tooltip')
print('PASS equipment term open, nested navigation, back, cycle, selection reset and immediate exit')
