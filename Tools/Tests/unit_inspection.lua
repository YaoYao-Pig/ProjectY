-- Isolated inspection rules and real battle action-budget checks; no Editor or save files.
package.path='Lua/?.lua;'..package.path
local L=require('Language')
local attributes={
    {id=1,code='vitality',name='Vitality'}, {id=2,code='endurance',name='Endurance'},
    {id=3,code='intellect',name='Intellect'}, {id=4,code='strength',name='Strength'},
    {id=5,code='speed',name='Speed'}, {id=6,code='defense',name='Defense'},
    {id=7,code='scouting',name='Scouting'},
}
local traits={[1]={id=1,name='Brave',description='Courage bonus'},[2]={id=2,name='Sharp',description='Scouting bonus'}}
local skills={[11]={id=11,name='Strike',description='Strike description',skillKind='attack'},
    [12]={id=12,name='Fire',description='Fire description',skillKind='attack'}}
local config={GetTable=function(_,name)
    if name=='CombatSkillTable'then return {Get=function(_,id)return assert(skills[id])end}end
    assert(name=='GrowthAttributeTable');return {All=function()return attributes end}
end}
local function actor(id,team)
    local result={Id=id,Team=team,HP=30,MaxHP=40,AP=3,Guard=2,scouting=10,TraitCount=2,traits={2,1},Moved=false,MainUsed=false}
    function result:GetTraitAt(i)return self.traits[i+1]end
    function result:SpendAction(kind,cost)
        assert(kind=='secondary' and cost==1 and self.AP>=cost)
        self.AP=self.AP-cost;self.Moved=true
    end
    return result
end
local function state()
    local result={records={},rolls={10,10},draws=0}
    function result:Find(key)return self.records[key]end
    function result:Roll(sides)
        assert(sides==20);self.draws=self.draws+1
        return assert(self.rolls[self.draws],'Unexpected extra inspection roll')
    end
    function result:Store(key,id,a,b,margin,fields)
        local old=self.records[key]
        local record={Key=key,ObserverId=id,ObserverRoll=a,TargetRoll=b,Margin=margin,Observed=id>0,fields={},ordered={}}
        local function add(field)
            if record.fields[field]then return end
            record.fields[field]=true;record.ordered[#record.ordered+1]=field
        end
        if old then for _,field in ipairs(old.ordered)do add(field)end end
        for _,field in ipairs(fields)do add(field)end
        record.FieldCount=#record.ordered
        function record:GetFieldAt(index)return self.ordered[index+1]end
        function record:HasField(field)return self.fields[field]==true end
        self.records[key]=record
    end
    function result:Record(key,id,a,b,margin,fields)
        assert((not self.records[key] or not self.records[key].Observed) and math.tointeger(margin),'Inspection attempt must be unique')
        self:Store(key,id,a,b,margin,fields)
    end
    function result:Reveal(key,fields)
        local old=self.records[key]
        self:Store(key,old and old.ObserverId or 0,old and old.ObserverRoll or 0,old and old.TargetRoll or 0,old and old.Margin or 0,fields)
    end
    return result
end
CS={ProjectY={Data={UnitInspections={Get=function(data)return data.inspections end},
    DeathDoorState={Alive=function(unit)return not unit.dead and (unit.HP>0 or unit.deathDoor)end},
    SpellcastingState={Current=function()return 2 end,Maximum=function()return 5 end}}}}
package.loaded['Game.Adventure.UnitInspectionTargets']={New=function(adventure)return adventure.targetIndex end}
local Inspection=require('Game.Adventure.UnitInspection')
local RealBattle=require('Game.Battle.BattleSystem')
local function fixture(phase)
    local a,b,target=actor(1,1),actor(2,1),actor(101,2)
    local adventure={config=config,data={PartyCount=2,Phase=phase or 'area',inspections=state()},minutes=0}
    adventure.narrative={AdvanceMinutes=function(_,minutes)adventure.minutes=adventure.minutes+minutes end}
    function adventure.data:GetPartyAt(i)return ({a,b})[i+1]end
    local stats={traits={Get=function(_,id)return assert(traits[id])end},
        Template=function(_,unit)return {name='Unit '..unit.Id,actionPoints=3}end,
        Get=function(_,unit,field)return field=='scouting' and unit.scouting or field=='speed' and 7 or 4 end,
        buffs={Skipping=function(_,unit)return unit.stunned and {name='stunned'}or nil end},
        equipment={CheckSkillEquipment=function(_,_,skill)assert(skill.catalystKind=='none');return true end,
            CheckAmmo=function(_,_,skill)assert(skill.ammoPerShot==0);return true end}}
    local battle=RealBattle();adventure.battle=battle
    function battle:SkillIds()return {11,12}end
    battle.data={Phase='combat',Winner='',ActiveId=1};battle.stats=stats
    function battle:Active()return self.data.ActiveId==1 and a or self.data.ActiveId==2 and b or target end
    battle.morale={Fleeing=function(_,unit)return unit.fleeing==true end}
    battle.professions={Budget=function()return true end};battle.spellcasting={Budget=function()return true end}
    battle.Changed={Emit=function(_,event)adventure.lastEvent=event end}
    local row={key='unit:101',name='Target',actor=target,owned=false,kind='actor'}
    local index={row=row,visible=true}
    function index:Rows()return self.visible and {self.row}or {}end
    function index:Name(unit)return 'Unit '..unit.Id end
    function index:Find(key)return self.visible and key==self.row.key and self.row or nil end
    function index:Identity(unit)
        if unit==a or unit==b then return 'party:'..unit.Id,true end
        if unit==target then return row.key,row.owned end
    end
    adventure.targetIndex=index
    local inspection=Inspection.New(adventure);stats.inspection=inspection
    return inspection,adventure,a,b,target,row
end
local count=0
local function test(name,run)run();count=count+1;print('PASS '..name)end
test('encounters reveal only battle resources for free and preserve the scouting attempt',function()
    local inspection,adventure,_,_,target=fixture()
    local view=assert(inspection:Build('unit:101',1))
    assert(view.canObserve and view.revealedCount==4 and view.totalCount==13)
    for _,row in ipairs(view.attributes)do
        if row.field:match('^attribute:')then assert(not row.known and row.name==L.InspectionUnknown and row.value==L.InspectionUnknown)
        else assert(row.known and row.value~=L.InspectionUnknown)end
    end
    for _,row in ipairs(view.traits)do assert(not row.known and row.title==L.InspectionUnknown and row.body==L.InspectionUnknown)end
    inspection:Build('unit:101',1);inspection:Targets();inspection:Observers()
    assert(inspection:Known(target,'health') and adventure.data.inspections.draws==0 and adventure.minutes==0)
    assert(not adventure.data.inspections:Find('unit:101').Observed)
    for _,skill in ipairs(view.skills)do assert(not skill.known and skill.title==L.InspectionUnknown and skill.body==L.InspectionUnknown)end
end)
test('ties and losses consume once, persist across module recreation, share across party',function()
    local inspection,adventure,a,b=fixture()
    local ok=inspection:Observe('unit:101',a.Id);assert(ok)
    local view=inspection:Build('unit:101',b.Id)
    assert(view.revealedCount==4 and not view.canObserve and adventure.minutes==5)
    assert(not Inspection.New(adventure):Observe('unit:101',b.Id))
    assert(adventure.minutes==5 and adventure.data.inspections.draws==2)
    assert(not view.result:find('10.+10'),'Result must not expose both opposing rolls')
end)
test('reveal tiers use stable interleaved field identities at every boundary',function()
    for _,case in ipairs({{-10,0},{0,0},{1,1},{4,1},{5,2},{9,2},{10,3},{14,3},{15,4},{19,4},{20,5},{25,5}})do
        local inspection,adventure,a,_,target=fixture()
        a.scouting=30+case[1];target.scouting=30
        assert(inspection:Observe('unit:101',1))
        local view=inspection:Build('unit:101',1)
        assert(view.revealedCount==4+math.ceil((view.totalCount-4)*case[2]/5),'Incorrect reveal tier at margin '..case[1])
        assert(inspection:Known(target,'health'))
        if case[2]>0 then
            assert(inspection:Known(target,'trait:1') and inspection:Known(target,'attribute:scouting'))
        end
        assert(adventure.data.inspections.draws==2 and adventure.minutes==5)
    end
end)
test('higher scouting never reveals less for fixed dice, fractional bonuses floor separately',function()
    local previous=-1
    for scouting=0,50 do
        local inspection,_,a=fixture();a.scouting=scouting
        assert(inspection:Observe('unit:101',1))
        local known=inspection:Build('unit:101',1).revealedCount
        assert(known>=previous);previous=known
    end
    local inspection,adventure,a,_,target=fixture();a.scouting=10.1;target.scouting=9.9
    assert(inspection:Observe('unit:101',1));assert(adventure.data.inspections:Find('unit:101').Margin==1)
end)
test('failed validation does not consume random draws, time or AP',function()
    local inspection,adventure,a,b=fixture()
    assert(not inspection:Observe('missing',1))
    assert(not inspection:Observe('unit:101',999))
    a.HP=0;assert(not inspection:Observe('unit:101',1));assert(#inspection:Observers()==1)
    a.HP=30;adventure.data.Phase='event';assert(not inspection:Observe('unit:101',1))
    adventure.data.Phase='battle';adventure.battle.data.ActiveId=b.Id
    assert(not inspection:Observe('unit:101',a.Id));assert(#inspection:Observers()==1 and inspection:Observers()[1].id==b.Id)
    adventure.battle.data.ActiveId=101;assert(#inspection:Observers()==0)
    adventure.battle.data.ActiveId=a.Id;a.AP=0;assert(not inspection:Observe('unit:101',a.Id))
    a.AP=3;a.fleeing=true;assert(not inspection:Observe('unit:101',a.Id))
    a.fleeing=false;a.stunned=true;assert(not inspection:Observe('unit:101',a.Id))
    a.stunned=false;adventure.battle.data.Winner='player';assert(not inspection:Observe('unit:101',a.Id))
    assert(adventure.data.inspections.draws==0 and adventure.minutes==0 and a.AP==3 and not a.Moved)
end)
test('combat and preparation spend one secondary AP through the real budget without time cost',function()
    for _,phase in ipairs({'combat','deployment'})do
        local inspection,adventure,a=fixture('battle');adventure.battle.data.Phase=phase;a.MainUsed=true
        assert(inspection:Observe('unit:101',1))
        assert(a.AP==2 and a.Moved and a.MainUsed and adventure.minutes==0)
        assert(adventure.lastEvent.kind=='unit_observed' and adventure.lastEvent.sourceId==1)
        assert(not inspection:Observe('unit:101',1) and a.AP==2 and adventure.data.inspections.draws==2)
    end
end)
test('death-door survivors may observe while permanently dead party members may not',function()
    local inspection,adventure,a=fixture();a.HP=0;a.deathDoor=true
    assert(#inspection:Observers()==2 and inspection:Build('unit:101',1).canObserve)
    a.dead=true;assert(#inspection:Observers()==1 and not inspection:Observe('unit:101',1))
    assert(adventure.minutes==0 and adventure.data.inspections.draws==0)
end)
test('known values remain live; recruitment reveals everything without reroll or spending',function()
    local inspection,adventure,a,_,target,row=fixture();a.scouting=30
    assert(inspection:Observe(row.key,1))
    target.HP=8
    local view=inspection:Build(row.key,1)
    assert(view.attributes[1].value==string.format(L.InspectionFraction,8,40))
    row.owned=true
    view=inspection:Build(row.key,1)
    assert(view.owned and view.revealedCount==view.totalCount and not view.canObserve)
    assert(inspection:Known(target,'attribute:defense') and not inspection:Observe(row.key,1))
    assert(adventure.data.inspections.draws==2 and adventure.minutes==5)
    inspection,adventure,a,_,target,row=fixture();row.owned=true
    assert(inspection:Build(row.key,1).revealedCount==13 and not inspection:Observe(row.key,1))
    assert(adventure.data.inspections.draws==0 and adventure.minutes==0)
end)
test('stale targets cannot be observed, but retained knowledge does not depend on current visibility',function()
    local inspection,adventure,a,_,target=fixture();a.scouting=30
    assert(inspection:Observe('unit:101',1));adventure.targetIndex.visible=false
    assert(not inspection:Build('unit:101',1));assert(not inspection:Observe('unit:101',1))
    assert(inspection:Known(target,'health') and adventure.data.inspections.draws==2 and adventure.minutes==5)
end)
test('visible encounters persist across recreation without disclosing unseen units',function()
    local inspection,adventure,_,_,target=fixture()
    adventure.targetIndex.visible=false;inspection:EncounterVisible()
    assert(not inspection:Known(target,'health') and not adventure.data.inspections:Find('unit:101'))
    adventure.targetIndex.visible=true;inspection:EncounterVisible()
    adventure.targetIndex.visible=false
    assert(Inspection.New(adventure):Known(target,'actionPoints'))
    assert(adventure.data.inspections.draws==0 and adventure.minutes==0)
end)
test('only successful witnessed skill use reveals that skill and keeps the scouting attempt',function()
    local inspection,adventure,_,_,target=fixture('battle')
    local battle=adventure.battle
    local function use(ok)return function()return ok,'test result'end end
    assert(not battle:ObserveSkillUse(target,11,use(false)))
    assert(not inspection:Known(target,'skill:11'))
    adventure.targetIndex.visible=false
    assert(battle:ObserveSkillUse(target,11,use(true)))
    assert(not inspection:Known(target,'skill:11'))
    adventure.targetIndex.visible=true
    assert(battle:ObserveSkillUse(target,11,function()
        adventure.targetIndex.visible=false;return true
    end))
    assert(inspection:Known(target,'skill:11') and not inspection:Known(target,'skill:12'))
    assert(adventure.data.inspections.draws==0 and adventure.minutes==0)
    adventure.targetIndex.visible=true
    local view=inspection:Build('unit:101',1)
    assert(view.canObserve and view.skills[1].title=='Strike' and view.skills[2].title==L.InspectionUnknown)
    assert(inspection:Observe('unit:101',1))
    assert(Inspection.New(adventure):Known(target,'skill:11') and not inspection:Known(target,'skill:12'))
    assert(battle:ObserveSkillUse(target,12,use(true)))
    assert(inspection:Known(target,'skill:12') and not inspection:Build('unit:101',1).canObserve)
    assert(adventure.data.inspections.draws==2)
    adventure.targetIndex.row.key='unit:102'
    assert(not inspection:Known(target,'skill:11'),'Different instances must not inherit observed skills')
end)
print('Unit inspection: '..count..' checks passed')
