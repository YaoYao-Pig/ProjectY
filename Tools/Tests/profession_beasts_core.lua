-- Production command, budget, trajectory and opportunity modules; only the C# data boundary is isolated.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local Hex=require('Game.Map.HexGrid')
local Battle=require('Game.Battle.BattleSystem')
local Beasts=require('Game.Battle.ProfessionBeasts')
local function copy(row)local result={};for k,v in pairs(row)do result[k]=v end;return result end

local bridge={}
function bridge.Bound(owner)return owner.bound end
function bridge.Partner(owner)return owner.independentMode and owner.bound or nil end
function bridge.Independent(actor)return actor.independent==true end
function bridge.Layer(actor)return actor.layer or 0 end
function bridge.SetMode(owner,independent,q,r,layer)
    local pet=assert(owner.bound);assert(owner.HP>0 and pet.HP>0 and pet.AnimalOwnerId==owner.Id)
    owner.independentMode=independent;owner.MountedAnimal=not independent and pet or nil;pet.independent=independent;pet.Q=q;pet.R=r;pet.Team=owner.Team;pet.layer=layer or 0
end
function bridge.Follow(pet,q,r,layer)assert(pet.independent and pet.HP>0);pet.Q=q;pet.R=r;pet.layer=layer or 0 end
function bridge.ReleaseDefeated(owner)if bridge.Partner(owner)and owner.bound.HP<=0 then owner.bound=nil;owner.independentMode=false end end
function bridge.Touch(area)area.touches=(area.touches or 0)+1 end
function bridge.ResetBattle(owner)owner.moveRound=-1;owner.attackRound=-1;owner.rescueRound=-1;owner.scent=0 end
function bridge.CanMove(owner,round)return owner.moveRound~=round end
function bridge.CanAttack(owner,round)return owner.attackRound~=round and owner.rescueRound~=round end
function bridge.Moved(owner,round)assert(bridge.CanMove(owner,round));owner.moveRound=round end
function bridge.Attacked(owner,round)assert(bridge.CanAttack(owner,round));owner.attackRound=round end
function bridge.Rescued(owner,round)owner.rescueRound=round end
function bridge.Scent(owner)return owner.scent or 0 end
function bridge.SetScent(owner,id)owner.scent=id end
CS={ProjectY={Data={AnimalCompanionState=bridge,ProfessionDuelState={Active=function(a)return a.duel==true end},
    ProfessionCombatState={Move=function(actor,q,r)assert(actor.HP>0);actor.Q=q;actor.R=r end,
    AddUnit=function(data,actor,team,q,r)actor.Team=team;actor.Q=q;actor.R=r;data.units[#data.units+1]=actor;data.UnitCount=#data.units end}}}}

local function actor(id,team,q,r)
    local a={Id=id,TemplateId=id,Team=team,Q=q,R=r,HP=30,MaxHP=30,AP=9,MainUsed=false,AnimalOwnerId=0,AnimalSpeciesId=0,
        cooldowns={},marks={},injuries={leg=7},Effects={Count=0},passive=0,records=0}
    a.Growth={GetRank=function(_,id)assert(id==1855);return a.passive end}
    function a:GetCooldown(id)return self.cooldowns[id]or 0 end
    function a:SetCooldown(id,turns)self.cooldowns[id]=turns end
    function a:SpendAction(kind,cost)assert(self.HP>0 and self.AP>=cost and not(kind=='main'and self.MainUsed));self.AP=self.AP-cost;if kind=='main'then self.MainUsed=true end end
    function a:RecordAction(...)self.records=self.records+1 end
    function a:BeginTurn(points)self.AP=points;self.MainUsed=false end
    function a:Damage(amount)
        if self.MountedAnimal then return self.MountedAnimal:Damage(amount)end
        local actual=math.min(self.HP,amount);self.HP=self.HP-actual;return actual
    end
    return a
end
local function fixture()
    local owner,pet,enemy,ally=actor(1,1,0,0),actor(31,1,1,0),actor(90,2,2,0),actor(2,1,1,1)
    pet.AnimalOwnerId=owner.Id;pet.AnimalSpeciesId=1;pet.independent=true
    owner.bound=pet;owner.independentMode=true;bridge.ResetBattle(owner)
    local board={cells={},byKey={},byLayer={},externalOccupied={}}
    for r=-3,3 do for q=-3,4 do local cell={index=#board.cells+1,q=q,r=r,layer=0,blocked=false};board.cells[#board.cells+1]=cell;board.byKey[Hex.Key(q,r)]=cell end end
    function board:Find(q,r,layer)if layer and layer~=0 then return self.byLayer[Hex.Key(q,r)..':'..layer]end;return self.byKey[Hex.Key(q,r)]end
    function board:Neighbors(cell)local result={};for d=1,6 do local q,r=Hex.Neighbor(cell.q,cell.r,d);local nextCell=self:Find(q,r,cell.layer);if nextCell and not nextCell.blocked then result[#result+1]=nextCell end end;return result end
    local data={Phase='combat',Round=1,Winner='',ActiveId=owner.Id,units={owner,pet,enemy,ally},UnitCount=4}
    function data:GetUnitAt(i)return self.units[i+1]end
    local animals={bySkill={[205]={speciesId=1}},byUnit={[31]=true},species={Get=function()return {rideable=true}end}}
    function animals:Cells(unit,grid,q,r,layer)
        q=q or unit.Q;r=r or unit.R;local first=grid:Find(q,r,layer);if not first then return end
        local result={first};if unit.large then local extra=grid:Find(q+1,r,layer);if not extra then return end;result[#result+1]=extra end;return result
    end
    function animals:Occupy(unit,grid,occupied)for _,cell in ipairs(assert(self:Cells(unit,grid)))do occupied[Hex.Key(cell.q,cell.r)]=unit end end
    function animals:CanPlace(unit,grid,q,r,occupied,allowed,layer)
        local cells=self:Cells(unit,grid,q,r,layer);if not cells then return false end
        for _,cell in ipairs(cells)do if cell.blocked or occupied and occupied[Hex.Key(cell.q,cell.r)]or allowed and not allowed(cell)then return false end end
        return true
    end
    function animals:Distance(a,b,grid)local distance=math.huge;for _,x in ipairs(assert(self:Cells(a,grid)))do for _,y in ipairs(assert(self:Cells(b,grid)))do distance=math.min(distance,Hex.Distance(x.q,x.r,y.q,y.r))end end;return distance end
    local battle=setmetatable({board=board,data=data,skills=config:GetTable('CombatSkillTable'),effects=config:GetTable('CombatEffectTable'),events={},attacks=0,bleeds=0,commits=0,
        stats={animals=animals,buffs={Skipping=function(_,unit)return unit.skip and {name='stun'}or nil end},
            equipment={CheckSkillEquipment=function()return true end,CheckAmmo=function()return true end,Consume=function()end},
            Template=function(_,unit)return {name='Actor'..unit.Id}end},
        professions={Budget=function()return true end,OnMoved=function(unit)end},context={services={Adventure={}}}}, {__index=Battle})
    battle.professions.Commit=function()battle.commits=battle.commits+1 end
    function battle:Units()return self.data.units end
    function battle:FindUnit(id)for _,unit in ipairs(self.data.units)do if unit.Id==id then return unit end end end
    function battle:Active()return owner end
    function battle:IsHostile(a,b)return a.Team~=b.Team end
    function battle:IsAllied(a,b)return a.Team==b.Team end
    function battle:SkillIds(unit)return unit==owner and {1851,1852,1853,1854}or unit==enemy and self.reaction and {1}or {}end
    function battle:Skill(unit,id)
        local result=copy(self.skills:Get(id));if id==1 then result.opportunityAttack=true;result.range=1;result.minRange=0;result.trajectory='sight';result.target='enemy' end
        return result
    end
    function battle:CheckWinner()return self.data.Winner~=''end
    function battle:Emit(kind,...)self.events[#self.events+1]=kind end
    battle.gameEffects={Prepare=function(_,id,source,target,skill)return {id=id,source=source,target=target,skill=skill}end,
        Apply=function(_,id,source,target)assert(id==802);battle.bleeds=battle.bleeds+1;return true end,
        TickActor=function()end,Clear=function()end}
    function battle:ApplyEffectProgram(source,skill,program)
        local target=program[1].target
        if source==enemy then
            if self.reaction=='kill'then target.HP=0 elseif self.reaction=='stun'then target.skip=true elseif self.reaction=='end'then self.data.Winner='defeat'end
        else
            self.attacks=self.attacks+1;self.lastProgram=program
            if self.hit~=false then target:Damage(2);self.beasts:OnHit(source,target,skill)end
        end
    end
    battle.beasts=Beasts.New(config,battle)
    local active={MemberCount=2,EncounterCount=0,NpcCount=0,GetMemberIdAt=function(_,i)return i==0 and owner.Id or ally.Id end,
        GetMemberCellAt=function(_,i)local unit=i==0 and owner or ally;return board:Find(unit.Q,unit.R,unit.layer).index end,Stop=function(self)self.stopped=true end}
    local adventure={config=config,data={Phase='area',PartyCount=2,GetPartyAt=function(_,i)return i==0 and owner or ally end,Areas={Active=active}},areas={ActiveLayout=function()return board end}}
    return {battle=battle,owner=owner,pet=pet,enemy=enemy,ally=ally,board=board,adventure=adventure}
end
local function resetTurn(e,round)e.battle.data.Round=round or e.battle.data.Round;e.owner.AP=9;e.owner.MainUsed=false;e.owner.cooldowns={}end
local function test(name,run)local ok,err=pcall(run);assert(ok,name..': '..tostring(err));print('PASS '..name)end

test('owner AP, main action, cooldown and one attack command per round',function()
    local e=fixture();e.owner.passive=1
    e.owner.AP=1;assert(not e.battle:TrySkill(1853,e.enemy.Id));assert(e.battle.attacks==0 and e.battle.commits==0)
    resetTurn(e);assert(e.battle:TrySkill(1853,e.enemy.Id));assert(e.owner.AP==7 and e.owner.MainUsed and e.pet.AP==9 and e.battle.attacks==1)
    assert(e.owner:GetCooldown(1853)==2 and e.battle.lastProgram[1].id==20209)
    resetTurn(e);assert(not e.battle:TrySkill(1853,e.enemy.Id)and e.owner.AP==9,'Round gate survives refreshed AP/cooldown')
    resetTurn(e,2);assert(e.battle:TrySkill(1853,e.enemy.Id)and e.battle.attacks==2)
    assert(#e.battle.skills:Get(205).effectIds==1,'Pet skill base definition must not be mutated')
end)
test('scent survives a miss, triggers on the bound animal only and consumes exactly once',function()
    local e=fixture();e.battle.data.Phase='deployment';assert(e.battle:TrySkill(1851,e.enemy.Id));assert(bridge.Scent(e.owner)==e.enemy.Id)
    e.battle.data.Phase='combat';resetTurn(e);assert(not e.battle:TrySkill(1851,e.enemy.Id),'Scent is preparation-only')
    e.battle.beasts:OnHit(e.ally,e.enemy,e.battle:Skill(e.ally,1));assert(e.battle.bleeds==0)
    resetTurn(e,2);e.battle.hit=false;assert(e.battle:TrySkill(1853,e.enemy.Id));assert(e.battle.bleeds==0 and bridge.Scent(e.owner)==e.enemy.Id)
    resetTurn(e,3);e.battle.hit=true;assert(e.battle:TrySkill(1853,e.enemy.Id));assert(e.battle.bleeds==1 and bridge.Scent(e.owner)==0)
    e.battle.beasts:OnHit(e.pet,e.enemy,e.battle:Skill(e.pet,205));assert(e.battle.bleeds==1)
end)
test('dead, absent, stunned and out-of-command-range pets never spend or attack',function()
    for _,mode in ipairs({'dead','absent','stun','distant'})do local e=fixture()
        if mode=='dead'then e.pet.HP=0 elseif mode=='absent'then table.remove(e.battle.data.units,2)
        elseif mode=='stun'then e.pet.skip=true else e.pet.Q=4;e.pet.R=-3 end
        assert(not e.battle:TrySkill(1853,e.enemy.Id));assert(e.owner.AP==9 and e.battle.attacks==0 and e.battle.commits==0,mode)
    end
end)
test('legal pet movement costs owner AP once; occupied, disallowed and distant cells are free failures',function()
    local e=fixture();local oldQ,oldR=e.pet.Q,e.pet.R
    assert(not e.battle:TrySkillAt(1852,e.enemy.Q,e.enemy.R));assert(e.owner.AP==9)
    e.board.allowed=function(cell)return not(cell.q==1 and cell.r==-1)end
    assert(not e.battle:TrySkillAt(1852,1,-1));assert(e.owner.AP==9)
    assert(not e.battle:TrySkillAt(1852,4,0));assert(e.owner.AP==9 and e.pet.Q==oldQ and e.pet.R==oldR)
    e.board.allowed=nil;assert(e.battle:TrySkillAt(1852,1,-1));assert(e.owner.AP==8 and not e.owner.MainUsed and e.pet.Q==1 and e.pet.R==-1)
    resetTurn(e);assert(not e.battle:TrySkillAt(1852,0,-1));assert(e.owner.AP==9,'One move per round independent of cooldown')
end)
test('real opportunity resolution interrupts movement on pet death, stun or battle end',function()
    for _,mode in ipairs({'kill','stun','end'})do local e=fixture();e.battle.reaction=mode
        assert(e.battle:TrySkillAt(1852,1,-1));assert(e.owner.AP==8 and e.pet.Q==1 and e.pet.R==0,mode)
        assert(e.owner.moveRound==1 and e.battle.events[1]=='opportunity_attack',mode)
        if mode=='kill'then assert(e.pet.HP==0 and bridge.Partner(e.owner)==nil)end
    end
end)
test('rescue requires an explicit legal landing before payment and suppresses same-round attack',function()
    local e=fixture();local skill=e.battle:Skill(e.owner,1854);local cells=e.battle.beasts:LandingCells(e.owner,skill,e.ally)
    assert(#cells>0);assert(not e.battle:TrySkill(1854,e.ally.Id));assert(e.owner.AP==9 and e.battle.commits==0)
    assert(not e.battle:TrySkill(1854,e.ally.Id,nil,{q=4,r=3}));assert(e.owner.AP==9 and e.battle.commits==0)
    local chosen=cells[1];e.board.externalOccupied[Hex.Key(chosen.q,chosen.r)]=true
    assert(not e.battle:TrySkill(1854,e.ally.Id,nil,chosen));assert(e.owner.AP==9)
    e.board.externalOccupied={};assert(e.battle:TrySkill(1854,e.ally.Id,nil,chosen));assert(e.owner.AP==6 and e.ally.Q==chosen.q and e.ally.R==chosen.r)
    resetTurn(e);assert(not e.battle:TrySkill(1853,e.enemy.Id)and e.owner.AP==9)
    local f=fixture();f.ally.large=true;assert(not f.battle:TrySkill(1854,f.ally.Id)and f.owner.AP==9)
end)
test('life mode switch reuses the same animal, preserves state and rejects invalid footprint space',function()
    local e=fixture();local handlers={};e.battle.beasts:RegisterLife({Register=function(_,key,row)handlers[key]=row end},e.adventure)
    local handler=assert(handlers[config:GetTable('CombatSkillTable'):Get(1867).skillGroup]);local original=e.pet
    e.pet.HP=19;e.pet.AnimalBond=17;local wound=e.pet.injuries;local effects=e.pet.Effects
    assert(handler.Use(e.owner));assert(e.owner.MountedAnimal==original and bridge.Partner(e.owner)==nil and not bridge.Independent(original))
    assert(original.HP==19 and original.AnimalBond==17 and original.injuries==wound and original.Effects==effects)
    assert(handler.Use(e.owner));assert(e.owner.MountedAnimal==nil and bridge.Partner(e.owner)==original and bridge.Independent(original))
    assert(original.HP==19 and original.injuries==wound and original.Effects==effects)
    local petHP=original.HP;e.owner:Damage(4);assert(e.owner.HP==26 and original.HP==petHP,'Independent pets do not absorb owner damage')
    assert(handler.Use(e.owner));e.owner:Damage(3);assert(e.owner.HP==26 and original.HP==petHP-3,'Mounted mode still routes damage')
    for _,cell in ipairs(e.board:Neighbors(e.board:Find(e.owner.Q,e.owner.R)))do cell.blocked=true end
    assert(not handler.Use(e.owner));assert(e.owner.MountedAnimal==original and not bridge.Independent(original),'No-space switch must preserve mode')
end)
test('deployment excludes duel, dead companions and occupied footprints',function()
    local e=fixture();e.battle.data.units={e.owner,e.enemy,e.ally};e.battle.data.UnitCount=3
    e.battle.context.services.Adventure.duel=true;e.battle.beasts:Deploy();assert(e.battle.data.UnitCount==3)
    e.battle.context.services.Adventure.duel=false;e.pet.HP=0;e.battle.beasts:Deploy();assert(e.battle.data.UnitCount==3)
    e.pet.HP=19;e.battle.beasts:Deploy();assert(e.battle.data.UnitCount==4 and e.battle:FindUnit(e.pet.Id)==e.pet)
    assert(Hex.Distance(e.owner.Q,e.owner.R,e.pet.Q,e.pet.R)>0)
    assert(not(e.pet.Q==e.enemy.Q and e.pet.R==e.enemy.R)and not(e.pet.Q==e.ally.Q and e.pet.R==e.ally.R))
end)
test('upper-floor companions occupy only their actual layer and follow or switch on the owner floor',function()
    local e=fixture();local originals={table.unpack(e.board.cells)}
    for _,ground in ipairs(originals)do local upper=copy(ground);upper.index=#e.board.cells+1;upper.layer=1
        e.board.cells[#e.board.cells+1]=upper;e.board.byLayer[Hex.Key(upper.q,upper.r)..':1']=upper
    end
    e.owner.layer=1;e.pet.layer=1;e.ally.Q=0;e.ally.R=0
    local excluded={[e.owner.Id]=true,[e.ally.Id]=true}
    local ground=e.battle.beasts:AreaOccupied(e.adventure,excluded,0)
    local upper=e.battle.beasts:AreaOccupied(e.adventure,excluded,1)
    assert(not ground[Hex.Key(e.pet.Q,e.pet.R)]and upper[Hex.Key(e.pet.Q,e.pet.R)],'Upper pet must not occupy the lower cell')
    local handlers={};e.battle.beasts:RegisterLife({Register=function(_,key,value)handlers[key]=value end},e.adventure)
    local handler=assert(handlers[config:GetTable('CombatSkillTable'):Get(1867).skillGroup])
    assert(handler.Use(e.owner));assert(e.owner.MountedAnimal==e.pet and bridge.Layer(e.pet)==1,'Mounting stays upstairs despite a lower-floor actor below')
    assert(handler.Use(e.owner));assert(bridge.Partner(e.owner)==e.pet and bridge.Layer(e.pet)==1)
    e.pet.layer=0;e.pet.Q=3;e.pet.R=2;e.battle.beasts:FollowArea(e.adventure)
    assert(bridge.Layer(e.pet)==1 and Hex.Distance(e.owner.Q,e.owner.R,e.pet.Q,e.pet.R)==1,'Following returns to a legal cell on the owner floor')
end)
print('PASS nine profession companion scenarios using production Lua dispatch and isolated actor-state adapters; native C# persistence remains a separate check')
