local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
function CloseCampPreview() registry:Shutdown();CloseCampPreview=nil end
registry:Start()
local a=registry:Get('Adventure');a:Start(412)
local Actions=require('Game.Narrative.NarrativeActions');local R=CS.ProjectY.Data.PartyRoster
local id
for _,row in ipairs(a.narrative.rules.actions:All()) do if row.kind=='recruit_npc' and row.targetId==1 then id=row.id;break end end
assert(id,'Recruit action fixture missing')
local plan,reason=Actions.Prepare(a.narrative,{id});assert(plan,reason)
assert(plan.recruits[1].reserve and a.data.PartyCount==4 and R.ReserveCount(a.data)==0)
Actions.Apply(a.narrative,plan)
assert(a.data.PartyCount==4 and R.ReserveCount(a.data)==1 and R.Find(a.data,10001))
assert(a.narrative.data:GetValue('recruited:1')==10001)
assert(a.equipment:Actor(10001)==R.Find(a.data,10001) and a.growth:Actor(10001)==R.Find(a.data,10001))
local saved=require('Game.Adventure.CharacterSave');assert(saved.Write(a));saved.Validate(a,a.characterSaves:Prepare(a.equipment.data))
return 'PASS real narrative recruitment: full active squad accepts reserve through prepare/apply, retains NPC fact and equipment, and validates the saved recruit.'
