package.path='Lua/?.lua;Lua/?/init.lua;'..package.path
local Audio=require('Game.Presentation.AudioEvents')
local Visual=require('Game.Presentation.VisualEffects')
local battle={}
local function hit(source,target,shot,critical)
    return {kind='damage',sourceId=source,targetId=target,amount=5,attackHit=true,
        impact={shot=shot,critical=critical==true}}
end
local first=hit(1,2,1)
Audio.Record(battle,first)
Audio.Record(battle,first) -- Multiple damage effects from the same actual hit.
Audio.Record(battle,hit(1,2,3,true)) -- Missed shot 2 retains the timing gap.
Audio.Record(battle,hit(1,3,1)) -- A separate actual target is retained.
local rows=Audio.Drain(battle)
assert(#rows==3 and rows[1].shot==1 and rows[2].shot==3 and rows[2].critical)
assert(#Audio.Drain(battle)==0,'Polling must not replay drained audio')
Audio.Record(battle,first)
assert(#Audio.Drain(battle)==1,'The next command may hit the same target again')
for _,kind in ipairs({'heal','miss','effect_added','check','battle_started','battle_ended'}) do
    local event=hit(1,2,1);event.kind=kind;Audio.Record(battle,event)
end
local periodic=hit(1,2,1);periodic.periodic=true;Audio.Record(battle,periodic)
local zero=hit(1,2,1);zero.amount=0;Audio.Record(battle,zero)
local environment=hit(1,2,1);environment.attackHit=false;Audio.Record(battle,environment)
Audio.Record(battle,hit(1,1,1))
assert(#Audio.Drain(battle)==0,'Non-direct, self, missed and zero damage must remain silent')
Audio.Record(battle,first);Visual.Clear(battle)
assert(#Audio.Drain(battle)==0,'Restart/load/teardown must clear sound history')
for shot=1,140 do Audio.Record(battle,hit(1,2,shot)) end
rows=Audio.Drain(battle)
assert(#rows==128 and rows[1].shot==13 and rows[128].shot==140,'Bound the transient queue')
local invalid=hit(1,2,1);invalid.impact=nil
assert(not pcall(Audio.Record,battle,invalid),'Missing required metadata must fail')
print('PASS audio events: direct-hit filtering, deduplication, burst gaps, drain, reset, capacity, metadata')
