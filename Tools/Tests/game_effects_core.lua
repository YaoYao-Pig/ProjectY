package.path='Lua/?.lua;'..package.path
local function collection()
    local c={Count=0,Revision=0,rows={},next=1}
    function c:GetAt(i)return assert(self.rows[i+1]) end
    function c:Find(effectId)for _,row in ipairs(self.rows)do if row.EffectId==effectId then return row end end end
    function c:Add(id,source,name,amount,duration)
        local r={Id=self.next,EffectId=id,SourceId=source,SourceName=name,Amount=amount,Remaining=duration,Elapsed=0,Stacks=1}
        self.next=self.next+1;self.rows[#self.rows+1]=r;self.Count=#self.rows;return r
    end
    function c:Require(id)for _,r in ipairs(self.rows)do if r.Id==id then return r end end;error('missing effect')end
    function c:Refresh(id,source,name,amount,duration,max,stack)
        local r=self:Require(id);r.SourceId=source;r.SourceName=name;r.Amount=amount;r.Remaining=duration;r.Elapsed=0;r.Stacks=stack and math.min(max,r.Stacks+1) or 1
    end
    function c:Advance(id,period)local r=self:Require(id);r.Elapsed=period>0 and (r.Elapsed+1)%period or 0;if r.Remaining>0 then r.Remaining=r.Remaining-1 end end
    function c:Remove(id)for i,r in ipairs(self.rows)do if r.Id==id then table.remove(self.rows,i);self.Count=#self.rows;return end end;error('missing removal')end
    return c
end
local function actor(id)
    local a={Id=id,TemplateId=id,HP=50,MaxHP=50,Effects=collection()}
    function a:Damage(amount)local used=math.min(self.HP,amount);self.HP=self.HP-used;return used end
    function a:Heal(amount)if self.HP==0 then return 0 end;local used=math.min(self.MaxHP-self.HP,amount);self.HP=self.HP+used;return used end
    function a:SetMaxHP(max)self.HP=self.HP==0 and 0 or math.max(1,math.min(max,self.HP+max-self.MaxHP));self.MaxHP=max end
    return a
end
local definitions={rows={}}
function definitions:Get(id)return assert(self.rows[id])end
function definitions:All()local r={};for _,row in pairs(self.rows)do r[#r+1]=row end;return r end
local function define(id,kind,amount,changes)
    local r={id=id,name='Effect '..id,description='Test effect',kind=kind,amount={Evaluate=function()return amount end},duration='duration',durationTurns=3,periodTurns=1,tickPhase='turn_start',stacking='refresh',maxStacks=1,removeOnBattleEnd=false,removeOnDeath=true,attribute='',iconId=1}
    for k,v in pairs(changes or {})do r[k]=v end;definitions.rows[id]=r;return r
end
define(1,'damage',3);define(2,'heal',4,{tickPhase='turn_end'});define(3,'damage',2,{stacking='independent'})
define(4,'damage',2,{stacking='stack',maxStacks=2});define(5,'damage',1,{duration='infinite',durationTurns=0,periodTurns=2,removeOnBattleEnd=true})
define(6,'modifier',2,{periodTurns=0,attribute='vitality'});define(7,'damage',5,{duration='instant'})
local events={};local stats={attributes={[1]={vitality=10}},growth={attributeByCode={}}}
function stats:Template(a)return{name='Actor '..a.Id}end
function stats:EffectVariables()return{}end
function stats:MaximumHP(a,pending)
    local amount=0;for i=0,a.Effects.Count-1 do local e=a.Effects:GetAt(i);local d=definitions:Get(e.EffectId)
        if d.kind=='modifier' and (not pending or e.Id~=pending.oldId)then amount=amount+e.Amount*e.Stacks end
    end
    if pending then amount=amount+pending.amount*pending.stacks end
    return 50+amount
end
local effects=require('Game.Battle.GameEffects').New(stats,definitions,function(kind)events[#events+1]=kind end);effects:Validate()
local source,target=actor(1),actor(2)
assert(effects:Apply(7,source,target));assert(target.HP==45 and target.Effects.Count==0)
effects:Apply(1,source,target);effects:Tick(target,'turn_end');assert(target.HP==45)
effects:Tick(target,'turn_start');assert(target.HP==42 and target.Effects:GetAt(0).Remaining==2)
effects:Apply(1,source,target);assert(target.Effects.Count==1 and target.Effects:GetAt(0).Remaining==3)
effects:Apply(2,source,target);effects:Tick(target,'turn_end');assert(target.HP==46)
effects:Tick(target,'turn_start');effects:Tick(target,'turn_start');effects:Tick(target,'turn_start');assert(target.Effects:Find(1)==nil and target.HP==37)
effects:Apply(3,source,target);effects:Apply(3,source,target);assert(target.Effects.Count==3)
effects:Apply(4,source,target);effects:Apply(4,source,target);effects:Apply(4,source,target);assert(target.Effects:Find(4).Stacks==2)
effects:Apply(5,source,target);effects:Clear(target,'battle_end');assert(not target.Effects:Find(5) and target.Effects:Find(4))
effects:Apply(6,source,target);assert(target.MaxHP==52);effects:Remove(target,target.Effects:Find(6).Id);assert(target.MaxHP==50)
local dot=actor(3);effects:Apply(5,source,dot);effects:Tick(dot,'turn_start');assert(dot.HP==50);effects:Tick(dot,'turn_start');assert(dot.HP==49 and dot.Effects:GetAt(0).Remaining==-1)
dot.HP=1;effects:Apply(1,source,dot);effects:Tick(dot,'turn_start');assert(dot.HP==0 and dot.Effects.Count==0,'Death cleanup must tolerate simultaneous instance removal')
assert(events[#events]=='effect_removed')
local mount,rider=actor(4),actor(5);mount.HP=1;rider.MountedAnimal=mount
function rider:Damage(amount)local value=self.MountedAnimal:Damage(amount);self.MountedAnimal=nil;return value end
effects:Apply(1,source,mount);effects:Apply(7,source,rider)
assert(mount.HP==0 and mount.Effects.Count==0 and rider.HP==50,'Intercepted damage must clean up effects on a defeated mount')
print('PASS GameEffect instant/periodic, start/end phases, refresh/independent/capped stacks, infinity/interval, cleanup and modifiers')
for _,path in ipairs({'Lua/UI/Panel/MainHudCtr.lua','Lua/UI/Panel/DialogueCtr.lua','Lua/UI/Panel/MissionJournalCtr.lua','Lua/UI/Widget/BattleHUDContent.lua','Lua/UI/Widget/NarrativeEntry.lua','Lua/UI/Widget/StatusEffect.lua','Lua/UI/Widget/TabButton.lua','Lua/Game/Battle/BattleSystem.lua','Lua/Game/MapArea/MapAreaSystem.lua'})do assert(loadfile(path))end
assert(require('UI.RichText').Escape('<s>A & B</s>'):find('<noparse>',1,true))
print('PASS modified Lua syntax and literal rich-text escaping')
