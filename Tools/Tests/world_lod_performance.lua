-- Native real-data benchmark: run only in the existing isolated Edit Mode LuaEnv host.
-- Return a report for a NEW performance-lod record; never overwrite performance-before/after.
-- The 100 ms gate covers 60 game minutes of narrative + world simulation, not world creation/rendering.
local started=os.clock()
local registry=require('Main');local adventure=registry:Get('Adventure')
local registrySeconds=os.clock()-started
local metrics={path=0,think=0,near=0,medium=0,far=0,nearMinutes=0,mediumMinutes=0,farMinutes=0,
    areaInit=0,areaSimulation=0,areaNear=0,areaMedium=0,areaFar=0,conflictNear=0,conflictMedium=0,conflictFar=0,
    beganDetailed=0,beganAbstract=0,materializeTravel=0}
local originals={};local phase='initialize';local currentLevel=1
local function wrap(object,name,replace)
    local original=assert(object[name],name)
    originals[#originals+1]={object=object,name=name,value=original};object[name]=replace(original)
end
local function restore()for i=#originals,1,-1 do local row=originals[i];row.object[row.name]=row.value end end
local ok,result=xpcall(function()
    wrap(adventure.areas.generator,'Generate',function(original)return function(self,...)
        if phase=='initialize' then metrics.areaInit=metrics.areaInit+1
        elseif phase=='simulation' then
            metrics.areaSimulation=metrics.areaSimulation+1
            local key=currentLevel==3 and 'areaFar' or currentLevel==2 and 'areaMedium' or 'areaNear';metrics[key]=metrics[key]+1
        end
        return original(self,...)
    end end)
    local initStarted=os.clock();adventure:Start(20261016,3,10000);adventure.travel.data:SetPaused(true)
    local initializeSeconds=os.clock()-initStarted
    local parties,factions=adventure.parties,adventure.factions
    local initialLevels={0,0,0}
    for i=0,parties.data.Count-1 do local level=parties.data:GetAt(i).Lod;initialLevels[level]=initialLevels[level]+1 end
    wrap(parties,'Path',function(original)return function(self,...)metrics.path=metrics.path+1;return original(self,...)end end)
    wrap(factions,'Think',function(original)return function(self,...)metrics.think=metrics.think+1;return original(self,...)end end)
    wrap(parties,'TickParty',function(original)return function(self,party,minute,minutes)
        metrics.near=metrics.near+1;metrics.nearMinutes=metrics.nearMinutes+(minutes or 1)
        local previous=currentLevel;currentLevel=1;original(self,party,minute,minutes);currentLevel=previous
    end end)
    wrap(parties.lod,'CoarseStep',function(original)return function(self,party,elapsed,minute,level)
        local key=level==2 and 'medium' or 'far';metrics[key]=metrics[key]+1;metrics[key..'Minutes']=metrics[key..'Minutes']+elapsed
        local previous=currentLevel;currentLevel=level;original(self,party,elapsed,minute,level);currentLevel=previous
    end end)
    wrap(parties.lod,'MaterializeTravel',function(original)return function(self,...)
        metrics.materializeTravel=metrics.materializeTravel+1;return original(self,...)
    end end)
    wrap(factions.conflicts,'TickConflict',function(original)return function(self,conflict,minute,level)
        local key=level==3 and 'conflictFar' or level==2 and 'conflictMedium' or 'conflictNear';metrics[key]=metrics[key]+1
        local previous=currentLevel;currentLevel=level;original(self,conflict,minute,level);currentLevel=previous
    end end)
    wrap(factions.conflicts,'Begin',function(original)return function(self,a,b,minute,site,abstract)
        local key=abstract and 'beganAbstract' or 'beganDetailed';metrics[key]=metrics[key]+1
        return original(self,a,b,minute,site,abstract)
    end end)
    local frames={};phase='simulation';local simulationStarted=os.clock()
    for _=1,60 do
        local tick=os.clock();adventure.narrative:AdvanceMinutes(1);parties:SyncClock();frames[#frames+1]=os.clock()-tick
    end
    local simulationSeconds=os.clock()-simulationStarted;phase='report'
    table.sort(frames)
    local finalLevels={0,0,0};local hash=2166136261
    local function append(value)local s=tostring(value)..'|';for i=1,#s do hash=((hash ~ s:byte(i))*16777619)&0xffffffff end end
    for i=0,parties.data.Count-1 do local party=parties.data:GetAt(i);finalLevels[party.Lod]=finalLevels[party.Lod]+1
        for _,value in ipairs({party.Id,party.Travel.Q,party.Travel.R,string.format('%.9f',party.Travel.Progress),party.Lod,
            party.Mission,party.TargetPartyId,party.TargetSiteId,party.BattleSiteId,party.AbstractTravel,
            party.AbstractQ,party.AbstractR,string.format('%.9f',party.AbstractArrivalAt)})do append(value)end
        for j=0,party.MemberCount-1 do append(party:GetMemberAt(j).HP)end
    end
    append(factions.data.ConflictCount)
    for i=0,factions.data.ConflictCount-1 do local conflict=factions.data:GetConflictAt(i)
        append(conflict.SiteId);append(conflict.Phase);append(conflict.Materialized);append(conflict.PendingCargoCount)
    end
    local snapshotStarted=os.clock();adventure:Snapshot();local snapshotSeconds=os.clock()-snapshotStarted
    local bridge=require('Game.Adventure.DemoBridge');bridge('snapshot')
    local pausedStarted=os.clock();local unchanged=0
    for _=1,30 do if bridge('snapshot').unchanged then unchanged=unchanged+1 end end
    local pausedSeconds=os.clock()-pausedStarted
    local lines={
        'benchmark=world_lod seed=20261016 recipe=3 world_cells=10000 simulation_minutes=60 instrumentation=counter_only',
        string.format('registry_init_ms=%.3f world_init_ms=%.3f parties=%d sites=%d',registrySeconds*1000,initializeSeconds*1000,parties.data.Count,factions.data.SiteCount),
        string.format('simulation_ms=%.3f budget_ms=100 budget_status=%s tick_p50_ms=%.3f tick_p95_ms=%.3f tick_max_ms=%.3f',simulationSeconds*1000,simulationSeconds<=.1 and 'PASS' or 'FAIL',frames[30]*1000,frames[57]*1000,frames[60]*1000),
        string.format('initial_lod near=%d medium=%d far=%d final_lod near=%d medium=%d far=%d',initialLevels[1],initialLevels[2],initialLevels[3],finalLevels[1],finalLevels[2],finalLevels[3]),
        string.format('party_updates near=%d medium=%d far=%d party_minutes near=%.3f medium=%.3f far=%.3f',metrics.near,metrics.medium,metrics.far,metrics.nearMinutes,metrics.mediumMinutes,metrics.farMinutes),
        string.format('path_calls=%d think_calls=%d materialize_travel_calls=%d',metrics.path,metrics.think,metrics.materializeTravel),
        string.format('area_generate init=%d simulation=%d near=%d medium=%d far=%d',metrics.areaInit,metrics.areaSimulation,metrics.areaNear,metrics.areaMedium,metrics.areaFar),
        string.format('conflict_updates near=%d medium=%d far=%d begin_detailed=%d begin_abstract=%d',metrics.conflictNear,metrics.conflictMedium,metrics.conflictFar,metrics.beganDetailed,metrics.beganAbstract),
        string.format('snapshot_ms=%.3f paused_polls=30 unchanged=%d paused_ms=%.3f signature_lod=%08x',snapshotSeconds*1000,unchanged,pausedSeconds*1000,hash)}
    if metrics.areaFar>0 then lines[#lines+1]='FAIL far simulation generated a local battlefield' end
    if unchanged~=30 then lines[#lines+1]='FAIL unchanged paused polls generated new snapshots' end
    return table.concat(lines,'\n')
end,debug.traceback)
restore()
if not ok then error(result,0)end
return result
