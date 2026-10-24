-- Real data CPU benchmark, independent PreviewScene host; no rendering or user save.
local registry=require('Main');local adventure=registry:Get('Adventure')
adventure:Start(20261016,3,10000);adventure.travel.data:SetPaused(true)
local metrics={};local originals={}
local function measure(object,name,label)
    local original=object[name];local metric={calls=0,seconds=0,maximum=0};metrics[label]=metric
    originals[#originals+1]={object=object,name=name,value=original}
    object[name]=function(self,...)
        local started=os.clock();local result=table.pack(original(self,...));local elapsed=os.clock()-started
        metric.calls=metric.calls+1;metric.seconds=metric.seconds+elapsed;metric.maximum=math.max(metric.maximum,elapsed)
        return table.unpack(result,1,result.n)
    end
end
measure(adventure.parties,'Path','path')
measure(adventure.factions,'Think','think')
measure(adventure.factions,'PlayerPower','player_power')
measure(adventure.factions.conflicts,'Contacts','contacts')
measure(adventure,'Snapshot','snapshot')
local frames={};local started=os.clock()
for _=1,60 do
    local tick=os.clock();adventure.narrative:AdvanceMinutes(1);adventure.parties:SyncClock();frames[#frames+1]=os.clock()-tick
end
local simulation=os.clock()-started
for _=1,30 do adventure:Snapshot() end
for _,row in ipairs(originals) do row.object[row.name]=row.value end
local bridge=require('Game.Adventure.DemoBridge')
assert(not bridge('snapshot').unchanged,'First paused poll must publish a snapshot')
local pausedStarted=os.clock();local skipped=0
for _=1,30 do if bridge('snapshot').unchanged then skipped=skipped+1 end end
local pausedSeconds=os.clock()-pausedStarted
table.sort(frames)
local hash=2166136261
local function append(value)
    local s=tostring(value)..'|';for i=1,#s do hash=((hash ~ s:byte(i))*16777619)&0xffffffff end
end
for i=0,adventure.parties.data.Count-1 do local party=adventure.parties.data:GetAt(i)
    for _,value in ipairs({party.Id,party.Travel.Q,party.Travel.R,string.format('%.9f',party.Travel.Progress),party.Mission,party.TargetPartyId,party.TargetSiteId,party.BattleSiteId}) do append(value) end
    for j=0,party.MemberCount-1 do append(party:GetMemberAt(j).HP) end
end
append(adventure.factions.data.ConflictCount)
local lines={string.format('world=10000 parties=%d sites=%d simulation_minutes=60 signature=%08x',adventure.parties.data.Count,adventure.factions.data.SiteCount,hash),
    string.format('simulation_ms=%.3f tick_p50_ms=%.3f tick_p95_ms=%.3f tick_max_ms=%.3f',simulation*1000,frames[30]*1000,frames[57]*1000,frames[60]*1000),
    string.format('paused_polls=30 skipped=%d total_ms=%.3f',skipped,pausedSeconds*1000)}
for _,name in ipairs({'path','think','player_power','contacts','snapshot'}) do local row=metrics[name]
    lines[#lines+1]=string.format('%s calls=%d total_ms=%.3f max_ms=%.3f',name,row.calls,row.seconds*1000,row.maximum*1000)
end
return table.concat(lines,'\n')
