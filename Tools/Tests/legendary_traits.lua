-- Real exported trait composition and effect execution; C# containers are isolated fixtures.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local b=f:read('*a');f:close();return b end}})
local function collection()
    local c={rows={},Count=0,next=1,Revision=0}
    function c:GetAt(i)return assert(self.rows[i+1])end
    function c:Find(id)for _,r in ipairs(self.rows)do if r.EffectId==id then return r end end end
    function c:ById(id)for _,r in ipairs(self.rows)do if r.Id==id then return r end end;error('Missing fixture instance')end
    function c:Add(id,source,name,amount,duration)
        local row={Id=self.next,EffectId=id,SourceId=source,SourceName=name,Amount=amount,Remaining=duration,Elapsed=0,Stacks=1}
        self.next=self.next+1;self.rows[#self.rows+1]=row;self.Count=#self.rows;self.Revision=self.Revision+1;return row
    end
    function c:Refresh(id,source,name,amount,duration,max,stack)local r=self:ById(id);r.SourceId=source;r.SourceName=name;r.Amount=amount;r.Remaining=duration;r.Elapsed=0;r.Stacks=stack and math.min(max,r.Stacks+1) or 1;self.Revision=self.Revision+1 end
    function c:Advance(id,period)local r=self:ById(id);r.Elapsed=period>0 and (r.Elapsed+1)%period or 0;if r.Remaining>0 then r.Remaining=r.Remaining-1 end;self.Revision=self.Revision+1 end
    function c:Remove(id)for i,r in ipairs(self.rows)do if r.Id==id then table.remove(self.rows,i);self.Count=#self.rows;self.Revision=self.Revision+1;return end end;error('Missing fixture removal')end
    return c
end
local state={}
function state.Configure(row,ids,amounts,expiry,nextTick)row.ids={table.unpack(ids)};row.amounts={table.unpack(amounts)};row.expiry=expiry;row.nextTick=nextTick end
function state.Amount(row,id)for i,value in ipairs(row.ids)do if value==id then return row.amounts[i]end end;error('Missing snapshot')end
function state.Count(row)return #row.ids end
function state.EffectAt(row,i)return row.ids[i+1]end
function state.ExpiresAt(row)return row.expiry end
function state.NextTickAt(row)return row.nextTick end
function state.AdvanceTick(row,period)row.nextTick=row.nextTick+period end
CS={ProjectY={Data={GameBuffState=state}}}
CS.ProjectY.Data.EquipmentCombatState={DamageArmor=function()return 0 end,RefreshMaximum=function()end}
local stats=require('Game.Battle.CombatStats')(config)
local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local function actor(id,template)
    local a={Id=id,TemplateId=template or 1,Team=1,TraitCount=0,traits={},Guard=0,Effects=collection(),Growth=EmptyGrowth()}
    function a:AddTrait(id)for _,old in ipairs(self.traits) do if old==id then return end end;self.traits[#self.traits+1]=id;self.TraitCount=#self.traits end
    function a:GetTraitAt(i)return self.traits[i+1]end
    function a:SetGuard(amount)self.Guard=math.max(self.Guard,amount)end
    for _,id in ipairs(config:GetTable('CombatUnitTable'):Get(a.TemplateId).traitIds)do a:AddTrait(id)end
    a.MaxHP=stats:MaximumHP(a);a.HP=20
    function a:Damage(amount)local loss=math.min(amount,self.HP);self.HP=self.HP-loss;return loss end
    function a:Heal(amount)if self.HP==0 then return 0 end;local gain=math.min(amount,self.MaxHP-self.HP);self.HP=self.HP+gain;return gain end
    function a:SetMaxHP(maximum)self.HP=self.HP==0 and 0 or math.max(1,math.min(maximum,self.HP+maximum-self.MaxHP));self.MaxHP=maximum end
    function a:BeginTurn(ap)self.AP=ap;self.MainUsed=false;self.Moved=false end
    return a
end
local effects=require('Game.Battle.GameEffects').New(stats,config:GetTable('CombatEffectTable'),function()end,{roll=function()return 0 end,minutes=function()return 0 end})
effects:Validate()
local function hit(source,target)
    local skill=stats.equipment:Skill(source,source.TemplateId==706 and 2 or source.TemplateId==705 and 1 or 205,stats)
    local plans={}
    for _,id in ipairs(skill.effectIds)do plans[#plans+1]=effects:Prepare(id,source,target,skill,1)end
    for _,plan in ipairs(plans)do assert(effects:ApplyPrepared(plan))end
    return skill
end
local source,target=actor(1,701),actor(2)
target.HP=target.MaxHP;hit(source,target);assert(target.Effects:Find(10002),'Bloodmoon hit must cause real bleeding')
source=actor(3,702);target=actor(4);target.HP=target.MaxHP
local speed=stats:Get(target,'speed');hit(source,target);assert(stats:Get(target,'speed')==speed-3,'Frost breath must alter real initiative')
source=actor(5,703);target=actor(6);target.HP=target.MaxHP;hit(source,target);assert(source.Guard==3 and target.Guard==0,'Stone guard belongs to the attacker')
source=actor(7,704);target=actor(8);target.HP=target.MaxHP;effects:Apply(805,source,target);hit(source,target)
assert(target.Effects:Find(10005) and not target.Effects:Find(10004),'Wet must still block legendary burning')
target=actor(9);target.HP=target.MaxHP;hit(source,target);assert(target.Effects:Find(10004))
source=actor(10,705);target=actor(11);target.HP=target.MaxHP;effects:Apply(808,source,target)
assert(target.Effects:Find(10008));hit(source,target);assert(not target.Effects:Find(10008),'Oathbreaker must dispel an actual buff')
source=actor(12,706);target=actor(13);target.HP=target.MaxHP;local before=source.HP;hit(source,target)
assert(source.HP==before+4,'Wayfarer must restore its own health')
local guard=stats.equipment:Skill(source,4,stats);assert(#guard.effectIds==1,'Traits must not proc from guard actions')
local ordinary=stats.equipment:Skill(actor(14),1,stats);assert(#ordinary.effectIds==1,'Ordinary units must retain original effects')
local equipment=require('Game.Equipment.EquipmentSystem')();equipment.rules=stats.equipment;equipment.initialLoadouts={ApplyEnemy=function()end}
equipment:InitializeEnemy(source);equipment:InitializeEnemy(source);assert(source.TraitCount==1,'Repeated initialization cannot stack innate traits')
print('PASS six distinct legendary mechanics, wet exclusion, source rewards, ordinary skills and duplicate initialization')
local Board=require('Game.Battle.BattleBoard');local Deploy=require('Game.Battle.BodyFootprints').Deploy
for id=701,706 do
    local encounter=config:GetTable('CombatEncounterTable'):Get(id);local board=Board.Create(7,981,.06)
    local positions=Deploy(board,encounter,stats.animals);local unit=actor(id,id)
    local shape=assert(stats.animals:Cells(unit,board,positions[1].q,positions[1].r))
    assert(#shape==(id<=702 and 2 or id<=704 and 4 or 1))
    assert(not stats.animals.byUnit[id],'Legendary creatures do not become tameable by accident')
end
print('PASS all six legendary bodies deploy with existing two/four/one-cell footprints')
config:OnShutdown()
