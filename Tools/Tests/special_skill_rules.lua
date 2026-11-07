-- Isolated acquisition-rule checks; no Editor, live state, or generated-config dependency.
package.path='Lua/?.lua;'..package.path
local Rules=require('Game.Progression.SpecialSkillRules')
local L=require('Language')
local function row(id)
    return {id=id,teachable=true,reteachable=false,relationMinimum=50,attributeNames={'strength'},attributeValues={8},
        observationAttribute='intellect',observationMinimum=10,observationBaseChance=.1,observationPerPoint=.05,observationMaxChance=.4}
end
local function fixture()
    local rows={SpecialSkillTable={row(101),row(102),row(103)},
        SpecialSkillHolderTable={{id=1,unitTemplateId=1,npcId=0,skillIds={102,101}},
            {id=2,unitTemplateId=0,npcId=3,skillIds={103,101}}},
        CombatSkillTable={{id=101,skillKind='active',contexts={'battle'}},{id=102,skillKind='active',contexts={'life','battle'}},
            {id=103,skillKind='active',contexts={'battle'}}},
        CombatUnitTable={{id=1,skillIds={103}},{id=2,skillIds={}}},NpcTable={{id=3,actorTemplateId=1}},
        GrowthAttributeTable={{id=1,code='strength',name='Strength'},{id=2,code='intellect',name='Intellect'}},ProfessionSkillTable={}}
    local config={}
    function config:GetTable(name)
        local values=assert(rows[name],name)
        return {All=function()return values end,Get=function(_,id)
            for _,value in ipairs(values)do if value.id==id then return value end end
            error('Missing '..name..' id '..id)
        end}
    end
    return config,rows
end
local function actor(id,template,learned)
    learned=learned or {}
    return {Id=id,TemplateId=template,AnimalSpeciesId=1,values={strength=8,intellect=10},Growth={SkillCount=#learned,
        GetSkillAt=function(_,i)return learned[i+1]end,HasSkill=function(_,id)
            for _,value in ipairs(learned)do if value==id then return true end end
            return false
        end}}
end
local stats={Get=function(_,target,name,excludeEquipment)
    assert(excludeEquipment==true,'Acquisition cannot count equipment attributes')
    return assert(target.values[name])
end}
local config,rows=fixture()
local rules=Rules.New(config)
do
    local original=actor(10003,1)
    local ids=rules:InitialSkills(original)
    assert(#ids==3 and ids[1]==101 and ids[2]==102 and ids[3]==103,'Initial skills must be sorted and deduplicated')
    for _,id in ipairs(ids)do assert(rules:IsOriginal(original,id) and rules:Owns(original,id))end
    local learned=actor(7,2,{101})
    assert(#rules:InitialSkills(learned)==0 and not rules:IsOriginal(learned,101) and rules:Owns(learned,101))
    assert(not rules:Owns(learned,102) and not rules:IsOriginal(learned,999))
    local mismatch=actor(10003,2)
    assert(#rules:InitialSkills(mismatch)==0 and not rules:IsOriginal(mismatch,103),'NPC identity cannot override a different actor template')
    -- Distinguish a template's innate skill from an NPC-only holder grant.
    rows.CombatUnitTable[1].skillIds={};rows.SpecialSkillHolderTable[1].skillIds={102}
    rules=Rules.New(config)
    assert(#rules:InitialSkills(actor(20,1))==1 and not rules:IsOriginal(actor(20,1),103))
    assert(rules:IsOriginal(original,103))
end
print('PASS: initial template/NPC ownership, learned ownership, deduplication and stable order')
do
    local student=actor(7,2)
    local ok,reason=rules:Requirements(student,101,stats)
    assert(ok and reason==L.SpecialSkillRequirementsMet)
    student.values.strength=7
    ok,reason=rules:Requirements(student,101,stats)
    assert(not ok and reason==string.format(L.SpecialSkillAttributeRequired,'Strength',8))
    assert(rules:ObservationChance(student,101,stats)==0)
    student.values.strength=8;student.values.intellect=9
    assert(rules:ObservationChance(student,101,stats)==0)
    student.values.intellect=10;assert(rules:ObservationChance(student,101,stats)==.1)
    student.values.intellect=12;assert(math.abs(rules:ObservationChance(student,101,stats)-.2)<1e-9)
    student.values.intellect=30;assert(rules:ObservationChance(student,101,stats)==.4)
    local text=rules:Description(101,stats)
    assert(text:find(L.SpecialSkillOriginalOnly,1,true) and text:find(L.SpecialSkillObserveBasis,1,true))
    rows.SpecialSkillTable[1].reteachable=true
    assert(rules:Description(101,stats):find(L.SpecialSkillReteachable,1,true))
    rows.SpecialSkillTable[1].teachable=false
    assert(rules:Description(101,stats):find(L.SpecialSkillCannotTeach,1,true))
end
print('PASS: shared thresholds, equipment exclusion, observation boundaries and localized descriptions')
do
    local equipment=setmetatable({specialSkills=rules,skills=config:GetTable('CombatSkillTable'),
        Weapon=function()end,Offhand=function()end,Usable=function()return false end},
        {__index=require('Game.Equipment.EquipmentRules')})
    local target=actor(10003,1,{101})
    local ids=equipment:SkillIds(target,{skillIds={102}})
    assert(#ids==3 and ids[1]==102 and ids[2]==101 and ids[3]==103,'Skills must merge with innate and learned identities without duplicates')
    -- Fallback bare-handed actions are already inserted by equipment; special classification cannot duplicate them.
    equipment.data={};target.AnimalSpeciesId=0
    equipment.specialSkills={InitialSkills=function()return {503,504}end}
    ids=equipment:SkillIds(target,{skillIds={}})
    local counts={};for _,id in ipairs(ids)do counts[id]=(counts[id]or 0)+1 end
    assert(counts[503]==1 and counts[504]==1)
end
print('PASS: equipment aggregation retains granted skills and avoids duplicate actions')
local malformed={
    function(r)r.SpecialSkillTable[2].id=101 end,
    function(r)r.CombatSkillTable[1].skillKind='item'end,
    function(r)r.CombatSkillTable[1].skillKind='preparation'end,
    function(r)r.CombatSkillTable[1].contexts={'life'}end,
    function(r)r.ProfessionSkillTable={{id=1,skillId=101}}end,
    function(r)r.SpecialSkillTable[1].teachable=1 end,
    function(r)r.SpecialSkillTable[1].relationMinimum=1.5 end,
    function(r)r.SpecialSkillTable[1].attributeValues={}end,
    function(r)r.SpecialSkillTable[1].attributeNames={'unknown'}end,
    function(r)r.SpecialSkillTable[1].attributeNames={'strength','strength'};r.SpecialSkillTable[1].attributeValues={1,2}end,
    function(r)r.SpecialSkillTable[1].attributeValues={-1}end,
    function(r)r.SpecialSkillTable[1].observationAttribute='unknown'end,
    function(r)r.SpecialSkillTable[1].observationMinimum=-1 end,
    function(r)r.SpecialSkillTable[1].observationBaseChance=1.1 end,
    function(r)r.SpecialSkillTable[1].observationPerPoint=-.1 end,
    function(r)r.SpecialSkillTable[1].observationPerPoint=math.huge end,
    function(r)r.SpecialSkillTable[1].observationMaxChance=.01 end,
    function(r)r.SpecialSkillTable[1].observationMaxChance=0/0 end,
    function(r)r.SpecialSkillHolderTable[1].npcId=3 end,
    function(r)r.SpecialSkillHolderTable[1].unitTemplateId=0 end,
    function(r)r.SpecialSkillHolderTable[1].unitTemplateId=999 end,
    function(r)r.SpecialSkillHolderTable[2].npcId=999 end,
    function(r)r.SpecialSkillHolderTable[2].npcId=90000 end,
    function(r)r.SpecialSkillHolderTable[2].id=1 end,
    function(r)r.SpecialSkillHolderTable[2].unitTemplateId=1;r.SpecialSkillHolderTable[2].npcId=0 end,
    function(r)r.SpecialSkillHolderTable[1].skillIds={101,101}end,
    function(r)r.SpecialSkillHolderTable[1].skillIds={999}end,
}
for i,change in ipairs(malformed)do
    local bad,badRows=fixture();change(badRows)
    assert(not pcall(Rules.New,bad),'Malformed config was accepted: '..i)
end
print('PASS: '..#malformed..' invalid acquisition configurations rejected')
