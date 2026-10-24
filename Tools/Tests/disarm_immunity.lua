-- Real growth/equipment/battle rules and exported configuration; native state is isolated.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=f:read('*a');f:close();return bytes
end}})
local Gear=assert(loadfile('Tools/Tests/equipment_read_fixture.lua'))()
local Layout=require('Game.MapArea.MapAreaLayout')
local Board=require('Game.Battle.BattleBoard')
local checks=0
local function test(name,run)run();checks=checks+1;print('PASS '..name)end
local function growth(ranks,attributes)
    local ids={};for id,rank in pairs(ranks)do if rank>0 then ids[#ids+1]=id end end;table.sort(ids)
    return {Level=1,TalentPoints=1,TalentCount=#ids,SkillCount=0,
        GetAttribute=function(_,name)return attributes and attributes[name] or 0 end,GetTalentAt=function(_,i)return ids[i+1]end,
        GetRank=function(_,id)return ranks[id] or 0 end,HasTree=function(_,id)return id==1 end}
end
local function fixture(immune,roll,height,sourceSpeedBonus,targetSpeedBonus)
    local env={rollCalls=0,disarms=0,wearCalls=0,events={},logs={}}
    local sourceWeapon,targetWeapon=Gear(1,40,1),Gear(2,40,2)
    local inventory={WearableCount=0}
    function inventory:Equipped(id)
        if sourceWeapon.OwnerActorId==id then return sourceWeapon end
        if targetWeapon.OwnerActorId==id then return targetWeapon end
    end
    function inventory:Offhand()end
    function inventory:Worn()end
    function inventory:GetWeapon(id)return assert(id==1 and sourceWeapon or id==2 and targetWeapon)end
    CS.ProjectY.Data.EquipmentCombatState={DamageWeapon=function(data,id,amount)
        local item=data:GetWeapon(id);env.wearCalls=env.wearCalls+1;item.condition.Current=item.condition.Current-amount;return amount
    end}
    local battle=require('Game.Battle.BattleSystem')();env.battle=battle
    battle.stats=require('Game.Battle.CombatStats')(config,inventory)
    battle.skills=config:GetTable('CombatSkillTable')
    local function actor(id,team,q,r,ranks,speedBonus)
        local a={Id=id,Team=team,TemplateId=1,Q=q,R=r,HP=46,MaxHP=46,AP=8,MainUsed=false,Moved=false,AnimalOwnerId=0,
            TraitCount=0,Effects={Count=0},Growth=growth(ranks,{speed=speedBonus or 0}),cooldowns={},actions=0,spends=0}
        function a:GetCooldown(id)return self.cooldowns[id] or 0 end
        function a:SetCooldown(id,turns)self.cooldowns[id]=turns end
        function a:SpendAction(action,cost)
            self.spends=self.spends+1;self.AP=self.AP-cost;self.Moved=true;if action=='main'then self.MainUsed=true end
        end
        function a:RecordAction()self.actions=self.actions+1 end
        return a
    end
    env.source=actor(1,1,3,3,{},sourceSpeedBonus)
    env.target=actor(2,2,4,3,immune and {[10]=1} or {},targetSpeedBonus)
    env.sourceWeapon,env.targetWeapon=sourceWeapon,targetWeapon
    local units={env.source,env.target}
    local area=Layout.New({id=999,name='disarm',areaType=1,width=9,height=9,hexRadius=1,visionRadius=8,moveStepSeconds=.1},1,{}, {wallHeight=3})
    for _,cell in ipairs(area.cells)do cell.height=0;cell.blocked=false;cell.blocksSight=false;cell.kind='floor'end
    area:Find(3,3).height=height or 0
    env.area=area;battle.board=Board.FromArea(area,4,4,6)
    battle.data={Phase='combat',Winner='',ActiveId=1,UnitCount=2,
        GetUnitAt=function(_,i)return units[i+1]end,
        RollPercent=function()env.rollCalls=env.rollCalls+1;return roll end,
        AddLog=function(_,text)env.logs[#env.logs+1]=text end}
    battle.Changed={Emit=function(_,event)env.events[#env.events+1]=event end}
    battle.checks=function(...)battle:ChanceLog(...)end
    local areas={marker='isolated map area'}
    local equipment={worldLoot={Disarm=function(_,map,target,weapon)
        assert(map==areas and target==env.target and weapon==targetWeapon and weapon.OwnerActorId==target.Id)
        env.disarms=env.disarms+1;weapon.OwnerActorId=0;weapon.Hand=''
    end}}
    battle.context={systems={Get=function(_,name)
        if name=='Equipment'then return equipment elseif name=='MapArea'then return areas end
        error('Unexpected dependency: '..name)
    end}}
    assert(battle:Skill(env.source,501).hitChance==30,'Fixture requires the real unmodified 30-percent disarm skill')
    return env
end

test('exported pure-immunity passive is learnable, rank-bound and has an explicit existing glyph',function()
    local rules=require('Game.Progression.GrowthRules').New(config)
    local node=rules.nodes:Get(10);local passive=rules.passives:Get(node.passiveId)
    assert(node.passiveId==14 and node.maxRank==1 and node.pointCost==1 and node.treeId==1)
    assert(passive.name=='紧握武器' and passive.iconAttribute=='strength' and #passive.attributeNames==0 and #passive.attributeValues==0)
    local a={Growth=growth({[1]=1,[4]=1})}
    assert(rules:CanInvest(a,10) and not rules:Immunity(a,'disarm'))
    a.Growth=growth({[1]=1,[4]=1,[10]=1})
    assert(rules:Immunity(a,'disarm')==passive and not rules:Immunity(a,'poison') and not rules:CanInvest(a,10))
    assert(rules:Bonus(a,'strength')==0 and rules:Bonus(a,'sword')==2)
    a.Growth=growth({[1]=1});assert(not rules:CanInvest(a,10))
end)

test('immune target rejects both preview and real attempt without spending resources or RNG',function()
    local env=fixture(true,0);local battle=env.battle
    local ok,reason,blocked=battle:CanUseSkill(501,env.target.Id)
    assert(not ok and reason:find('紧握武器',1,true) and blocked.target==env.target)
    assert(#env.events==0 and #env.logs==0,'Read-only eligibility must not emit an attempted-action log')
    assert(not battle:TrySkill(501,env.target.Id))
    assert(env.source.AP==8 and not env.source.MainUsed and not env.source.Moved and env.source:GetCooldown(501)==0)
    assert(env.source.spends==0 and env.source.actions==0 and env.rollCalls==0 and env.wearCalls==0 and env.disarms==0)
    assert(env.targetWeapon.OwnerActorId==env.target.Id and env.targetWeapon.Hand=='weapon' and env.sourceWeapon.condition.Current==100)
    assert(#env.events==1 and env.events[1].kind=='immune' and env.events[1].impact.reason:find('紧握武器',1,true))
    assert(#env.logs==1 and env.logs[1]:find('紧握武器',1,true) and env.logs[1]:find('未消耗行动点',1,true))
end)

test('equal-speed flat-ground disarm uses 30-percent boundaries and records the actual roll',function()
    for _,roll in ipairs({0,29,30,99})do
        local env=fixture(false,roll);local skill=env.battle:Skill(env.source,501)
        assert(env.battle:CanUseSkill(501,env.target.Id) and env.rollCalls==0)
        assert(env.battle:ShotPreview(env.source,env.target,skill).hitChance==30 and env.rollCalls==0)
        assert(env.battle:TrySkill(501,env.target.Id))
        local success=roll<30
        assert(env.disarms==(success and 1 or 0) and env.targetWeapon.OwnerActorId==(success and 0 or env.target.Id))
        assert(env.source.AP==8-skill.cost and env.source.MainUsed and env.source.Moved and env.source:GetCooldown(501)==skill.cooldownTurns)
        assert(env.source.spends==1 and env.source.actions==1 and env.rollCalls==1 and env.wearCalls==1)
        assert(env.events[1].kind=='check' and env.events[1].impact.chance==30 and env.events[1].impact.roll==roll and env.events[1].impact.passed==success)
        assert(env.events[2].kind==(success and 'disarmed' or 'miss') and #env.events==2)
        assert(env.logs[1]:find('掷值',1,true) and env.logs[1]:find(tostring(roll)..'/100',1,true))
    end
end)

test('final actor speed difference changes both preview and resolution by two points per speed',function()
    for _,sample in ipairs({{10,0,49,50,true},{10,0,50,50,false},{0,10,9,10,true},{0,10,10,10,false},{7,7,29,30,true}})do
        local env=fixture(false,sample[3],0,sample[1],sample[2]);local battle=env.battle
        local preview=battle:ShotPreview(env.source,env.target,battle:Skill(env.source,501))
        assert(preview.hitChance==sample[4] and preview.description:find(string.format('%.1f%%',sample[4]),1,true))
        assert(env.rollCalls==0 and #env.events==0 and env.source.spends==0 and env.wearCalls==0)
        assert(battle:TrySkill(501,env.target.Id))
        local check=env.events[1].impact
        assert(check.chance==preview.hitChance and check.roll==sample[3] and check.passed==sample[5])
        assert(env.disarms==(sample[5] and 1 or 0) and env.rollCalls==1)
    end
end)

test('disarm clamps zero and certain success after combining speed and height',function()
    for _,sample in ipairs({{0,15,0,0,0,false},{0,16,0,0,0,false},{35,0,0,99,100,true},{36,0,0,99,100,true},
        {0,16,1,2,3,true},{0,16,1,3,3,false},{34,0,1,99,100,true}})do
        local env=fixture(false,sample[4],sample[3],sample[1],sample[2]);local battle=env.battle
        local preview=battle:ShotPreview(env.source,env.target,battle:Skill(env.source,501))
        assert(preview.hitChance==sample[5] and env.rollCalls==0)
        assert(battle:TrySkill(501,env.target.Id))
        assert(env.events[1].impact.chance==preview.hitChance and env.events[1].impact.passed==sample[6])
        assert(env.disarms==(sample[6] and 1 or 0) and env.rollCalls==1)
    end
end)

test('existing high-ground accuracy remains part of disarm effective chance',function()
    for _,sample in ipairs({{1,34,35,true},{1,35,35,false},{2,39,40,true},{2,40,40,false}})do
        local env=fixture(false,sample[2],sample[1]);assert(env.battle:TrySkill(501,env.target.Id))
        assert(env.events[1].kind=='check' and env.events[1].impact.chance==sample[3] and env.events[1].impact.roll==sample[2])
        assert(env.events[1].impact.passed==sample[4] and env.disarms==(sample[4] and 1 or 0))
    end
end)

test('speed comparison does not alter other skills',function()
    local env=fixture(false,0,0,35,0);local battle=env.battle;local skill=battle:Skill(env.source,502)
    assert(battle:ShotPreview(env.source,env.target,skill).hitChance==skill.hitChance and env.rollCalls==0)
end)

config:OnShutdown()
print('Disarm immunity: '..checks..' checks passed')
