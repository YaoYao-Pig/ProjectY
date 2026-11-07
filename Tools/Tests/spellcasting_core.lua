-- Real exported recipe/config/rules and projectile resolver; only C# state boundaries are simulated.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local state={}
CS={ProjectY={Data={SpellcastingState=state}}}
CS.ProjectY.Data.DeathDoorState={Alive=function(actor)return actor.HP>0 end}
local function resource(actor)actor.casting=actor.casting or {current=0,maximum=0,regen=0,boosts={}};return actor.casting end
function state.Configure(actor,maximum,regen)
    local row=resource(actor)
    if not row.initialized and maximum>0 then row.initialized=true;row.current=maximum end
    row.maximum=maximum;row.regen=regen;row.current=math.min(row.current,maximum)
end
function state.Current(actor)return resource(actor).current end
function state.Maximum(actor)return resource(actor).maximum end
function state.Regen(actor)return resource(actor).regen end
function state.Boost(actor,id)return resource(actor).boosts[id] or 0 end
function state.SetBoost(actor,id,value)resource(actor).boosts[id]=value end
local spendCount=0
function state.Spend(actor,amount)local row=resource(actor);assert(amount<=row.current);row.current=row.current-amount;spendCount=spendCount+1 end
function state.Recover(actor,amount)local row=resource(actor);local gain=math.min(amount,row.maximum-row.current);row.current=row.current+gain;return gain end
function state.FieldCount(data)return #data.fields end
function state.FieldAt(data,index)return data.fields[index+1]end
function state.Touch(field,id,round)field.touched=field.touched or {};if field.touched[id]==round then return false end;field.touched[id]=round;return true end
function state.AddField(data,id,source,q,r,radius,turns,kind,scale)
    data.fields[#data.fields+1]={Id=#data.fields+1,SkillId=id,SourceId=source,Q=q,R=r,Radius=radius,Remaining=turns,Kind=kind,DamageScale=scale}
end
local function actor(id,ids)
    local ranks={}
    return {Id=id,HP=20,AP=4,Q=0,R=0,ids=ids,ranks=ranks,Growth={GetRank=function(_,node)return ranks[node] or 0 end},
        SpendAction=function(self,action,cost)self.AP=self.AP-cost end,SetCooldown=function()end,RecordAction=function()end}
end
local gear={SkillIds=function(_,unit)local ids={};for _,id in ipairs(unit.ids)do ids[#ids+1]=id end;return ids end,
    Weapon=function(_,unit)return unit.weapon end,Offhand=function()end,Usable=function()return true end,
    data={WearableCount=0},Condition=function()return {Current=10}end,Consume=function()end}
local stats={equipment=gear,effects=config:GetTable('CombatEffectTable'),Template=function()return {}end,
    animals={Cells=function(_,unit,board,q,r)return unit.parts or {board:Find(q or unit.Q,r or unit.R)}end}}
local rules=require('Game.Battle.Spellcasting').New(config,stats)
local skills=config:GetTable('CombatSkillTable')
local function resolved(unit,id)
    local value={};for key,item in pairs(skills:Get(id))do value[key]=item end
    value.damageScale=1;value.minRange=value.minRange or 0;value.criticalChance=0
    return rules:Resolve(unit,value)
end
local function owns(ids,id)for _,value in ipairs(ids)do if value==id then return true end end;return false end
local mage=actor(1,{2301,2302,2303,104})
local all=rules:AddSkills(mage,rules:BaseIds(mage))
assert(owns(all,2304) and owns(all,2305) and owns(all,2306) and owns(all,2307),'Nested recipes must unlock to a fixed point')
assert(#rules:AddSkills(mage,all)==#all,'Recipe expansion must not duplicate entries')
local partial=actor(2,{2301});assert(not owns(rules:AddSkills(partial,rules:BaseIds(partial)),2304))
local current,maximum,regen=rules:Sync(mage);assert(current==6 and maximum==6 and regen==1)
mage.ranks[302]=1;mage.ranks[303]=1;mage.weapon={ItemId=601};rules:Sync(mage)
assert(state.Maximum(mage)==8 and state.Regen(mage)==3 and state.Current(mage)==6,'Capacity, talent and equipment regen must stack without filling gained capacity')
state.SetBoost(mage,2301,2);local fire=resolved(mage,2301)
assert(fire.castingCost==4 and fire.castingBoost==2 and fire.damageScale==1.5)
local before=state.Current(mage);rules:Commit(mage,fire)
assert(state.Current(mage)==before-4 and state.Boost(mage,2301)==0 and spendCount==1)
state.SetBoost(mage,2301,2);fire=resolved(mage,2301);before=state.Current(mage)
local ok=rules:Budget(mage,fire);assert(not ok and state.Current(mage)==before)
assert(not pcall(function()rules:Commit(mage,fire)end) and spendCount==1 and state.Current(mage)==before,'Rejected casts may not spend')
local injected=actor(3,{2304});rules:Sync(injected)
assert(not rules:Budget(injected,resolved(injected,2304)),'Owning only a composite ID must not bypass missing ingredients')
local warrior=actor(4,{1});rules:Sync(warrior);assert(state.Maximum(warrior)==0 and state.Current(warrior)==0)
print('PASS real recipes, nested unlock, bonus sources, no free refill, boost scaling, one commit and zero spend on rejection')

local board=require('Game.Battle.BattleBoard').Create(4,123,0)
local battle={data={fields={},Round=1},board=board,stats=stats}
rules:BindBoard(battle)
local origin,target=board:Find(-3,0),board:Find(3,0)
state.AddField(battle.data,2305,mage.Id,0,0,1,3,'mist',1)
assert(rules:BlocksSight(battle,origin,target))
assert(not require('Game.Battle.SkillTrajectory').CanReach(board,origin,target,'direct'))
assert(not require('Game.Battle.SkillTrajectory').CanReach(board,origin,target,'lobbed',nil,true),'Guided casts still require visibility through mist')
assert(not rules:BlocksSight(battle,board:Find(0,0),board:Find(1,0)),'Adjacent awareness remains usable')
battle.data.fields={};state.AddField(battle.data,2306,mage.Id,0,0,0,3,'mud',1)
local _,distance=board:Search(-1,0,{},3)
assert(distance[board:Find(0,0)]==2 and rules:MoveCost(battle,board:Find(2,0))==0,'Hazards must charge additional path cost only within their footprint')
assert(rules:MoveCost(battle,{q=0,r=0,layer=1})==0,'Ground fields may not affect upper floors')
battle.data.fields={};state.AddField(battle.data,2305,mage.Id,0,0,1,3,'mist',1)
assert(not rules:BlocksSight(battle,{q=-3,r=0,layer=1},{q=3,r=0,layer=1}),'Ground mist may not obscure upper floors')
print('PASS real mist projectile gating, adjacent visibility, hazard path cost and upper-floor isolation')

-- A committed area hit must finish every prepared target even if its caster dies first.
local source=actor(10,{2301,2302});source.HP=5;rules:Sync(source)
local enemy=actor(11,{1});enemy.Q=1;local friend=actor(12,{1});friend.R=1
local units={source,enemy,friend};local hits={}
battle.data.fields={};battle.Units=function()return units end;battle.Emit=function()end;battle.CheckWinner=function()end
battle.gameEffects={Prepare=function(_,id,caster,victim,skill)
    return {definition={id=id,kind='damage',duration='instant'},target=victim,source=caster,skill=skill}
end,ApplyPrepared=function(_,plan)plan.target.HP=0;hits[plan.target.Id]=true end}
local originalVisual=package.loaded['Game.Presentation.VisualEffects']
package.loaded['Game.Presentation.VisualEffects']={Skill=function()end}
local committed=0
battle.professions={Commit=function(_,unit,skill)committed=committed+1;rules:Commit(unit,skill)end,ConsumeEquipment=function()end,
    Redirect=function(_,_,_,victim)return victim end,BeforeHit=function()return {}end,AfterHit=function()end}
rules:UseAt(battle,source,resolved(source,2304),board:Find(0,0))
package.loaded['Game.Presentation.VisualEffects']=originalVisual
assert(committed==1 and state.Current(source)==1 and source.AP==4-skills:Get(2304).cost)
assert(hits[source.Id] and hits[enemy.Id] and hits[friend.Id],'Caster death must not cancel the remaining committed hostile or friendly area hits')
print('PASS committed area pays once, includes friendly fire and finishes after caster self-kill')

local ringSource=actor(13,{2301,2302});rules:Sync(ringSource)
local ringVictim=actor(14,{1});ringVictim.Q=1
local inner=actor(15,{1});local ringSkill=resolved(ringSource,2304);ringSkill.splashShape='ring'
local oldSkills=rules.skills
rules.skills={Get=function(_,id)return id==2304 and ringSkill or oldSkills:Get(id)end}
battle.data.fields={};hits={};battle.Units=function()return {ringSource,ringVictim,inner}end
package.loaded['Game.Presentation.VisualEffects']={Skill=function()end}
rules:UseAt(battle,ringSource,ringSkill,board:Find(0,0))
package.loaded['Game.Presentation.VisualEffects']=originalVisual
assert(hits[ringVictim.Id] and not hits[ringSource.Id] and not hits[inner.Id],'Ring area damage must leave its hollow center unaffected')
local field=battle.data.fields[1]
assert(not rules:FieldContains(field,0,0) and rules:FieldContains(field,1,0),'Persistent field geometry must match initial area damage')
assert(#rules:FieldRows(battle)[1].cells==6,'Persistent field visual cells must use the same ring')
rules.skills=oldSkills
print('PASS ring field initial damage, hollow center, persistent footprint and visual projection')
