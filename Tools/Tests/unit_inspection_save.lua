-- Inspection configuration validation only; no Unity, disk saves or gameplay mutation.
package.path='Lua/?.lua;'..package.path
local preparedCalls=0
CS={ProjectY={Data={UnitInspections={Prepared=function(prepared)
    preparedCalls=preparedCalls+1;return prepared.inspections
end}}}}
local Save=require('Game.Adventure.CharacterSave')
local definitions={GrowthAttributeTable={{code='scouting'},{code='strength'}},CombatTraitTable={{id=1},{id=101}},CombatSkillTable={{id=11},{id=12}}}
local config={GetTable=function(_,name)return {All=function()return assert(definitions[name])end}end}
local function candidate(rows)
    local inspections={Count=#rows,rows=rows}
    function inspections:GetAt(index)return self.rows[index+1]end
    for _,row in ipairs(rows)do
        row.FieldCount=#row.fields
        function row:GetFieldAt(index)return self.fields[index+1]end
    end
    return {inspections=inspections}
end
local empty=candidate({})
Save.ValidateInspections({GetTable=function()error('Empty legacy knowledge must not require field lookup')end},empty)
assert(preparedCalls==1 and empty.inspections.Count==0)
print('PASS empty legacy and fresh-world discoveries are accepted without inventing fields')

local record={ObserverId=999999,fields={'health','actionPoints','guard','casting','attribute:scouting','attribute:strength','trait:1','trait:101'}}
local saved=candidate({record,{ObserverId=12345,fields={}}})
Save.ValidateInspections(config,saved)
assert(saved.inspections.Count==2 and record.FieldCount==8 and record.fields[8]=='trait:101')
print('PASS current field identities and failed checks survive with historical departed observers')

Save.ValidateInspections(config,candidate({{ObserverId=0,fields={'health','skill:11'}}}))
for _,field in ipairs({'attribute:deleted','trait:404','healthPoints','skill:404'})do
    local bad=candidate({{ObserverId=1,fields={field}}})
    local ok=pcall(Save.ValidateInspections,config,bad)
    assert(not ok,'Unknown configuration identity accepted: '..field)
    assert(bad.inspections:GetAt(0):GetFieldAt(0)==field and bad.inspections.Count==1,'Validation mutated candidate knowledge')
end
Save.ValidateInspections(config,saved)
assert(saved.inspections.Count==2 and record.FieldCount==8)
print('PASS removed attributes, missing traits and unknown field groups reject without mutating knowledge')
