-- Real Main/Services and v18 persistence. Run only through the isolated temporary-save Edit Mode host.
local registry=require('Main');local adventure=registry:Get('Adventure')
local Save=require('Game.Adventure.CharacterSave');local Hex=require('Game.Map.HexGrid')
local results={}
local function test(name,body)body();results[#results+1]='PASS '..name end
local function close(a,b,message)assert(math.abs(a-b)<.000001,(message or 'Values differ')..': '..a..' ~= '..b)end
adventure:Start(20261016,3,10000);adventure.travel.data:SetPaused(true)
local parties,factions,lod
local function refresh()parties=adventure.parties;factions=adventure.factions;lod=parties.lod end
refresh()
local function normalized(path)return tostring(path):gsub('\\','/'):lower()end
local temporary=normalized(CS.System.IO.Path.GetFullPath(CS.System.IO.Path.GetTempPath()))
if temporary:sub(-1)~='/'then temporary=temporary..'/'end
local function temporarySavePath()
    local path=tostring(adventure.characterSaves.FilePath)
    assert(normalized(CS.System.IO.Path.GetFullPath(path)):sub(1,#temporary)==temporary,'LOD integration refuses a non-temporary player save')
    return path
end
temporarySavePath()
local function roundtrip()
    local path=temporarySavePath();local ok,reason=Save.Write(adventure);assert(ok,reason)
    local document=tostring(CS.System.IO.File.ReadAllText(path))
    assert(tonumber(document:match('"version"%s*:%s*(%d+)'))==18,'Integration must exercise a real v18 save')
    ok,reason=Save.Read(adventure);assert(ok,reason);refresh()
end
local function mobile(p)
    return p.Lod==3 and not p.Defeated and p.BattleSiteId==0 and (p.Role=='raider' or p.Role=='patrol' or p.Role=='caravan')
end
local function remoteCell(excluded)
    local positions={}
    for i=0,parties.data.Count-1 do local p=parties.data:GetAt(i)
        if not excluded[p.Id] then positions[#positions+1]={q=p.Travel.Q,r=p.Travel.R}end
    end
    local player=adventure.travel.data
    for _,cell in ipairs(adventure.map:GetCells())do
        if not cell.waterLevel and not cell.buildingId and Hex.Distance(cell.q,cell.r,player.AnchorQ,player.AnchorR)>lod.rule.mediumRadius+8 and
            lod:Connected(player.AnchorQ,player.AnchorR,cell.q,cell.r)then
            local safe=true
            for _,position in ipairs(positions)do if Hex.Distance(cell.q,cell.r,position.q,position.r)<=3 then safe=false;break end end
            if safe then
                for _,other in ipairs(parties.paths.neighbors[cell])do
                    if adventure.travel:Cost(cell,other) and Hex.Distance(other.q,other.r,player.AnchorQ,player.AnchorR)>lod.rule.mediumRadius+8 then
                        return cell,other
                    end
                end
            end
        end
    end
    error('Generated fixture needs a connected safe far cell with a traversable neighbor')
end
local function relocate(p,cell)
    assert(not p.Defeated and p.BattleSiteId==0)
    if p.AbstractTravel then p:CancelAbstractTravel()end
    p.Travel:Reset(adventure.data.Seed,cell.q,cell.r,1)
    p:SetMission('patrol',0,0,adventure.narrative.data.Minutes+10000)
end
local function health(p)local hp={};for i=0,p.MemberCount-1 do hp[i+1]=p:GetMemberAt(i).HP end;return hp end
local function sameHealth(p,hp)
    assert(p.MemberCount==#hp)
    for i=0,p.MemberCount-1 do assert(p:GetMemberAt(i).HP==hp[i+1],'LOD transition or reload changed a persistent wound')end
end
local function remainingAfterMaterialization(p,minute)
    local start=adventure.map:GetCell(p.Travel.Q,p.Travel.R);local goal=adventure.map:GetCell(p.AbstractQ,p.AbstractR)
    local route=assert(parties:Path(start,goal),'Fixture abstract route must remain reachable')
    local speed=parties.definitions:Get(p.DefinitionId).speed;local total=0
    for i=2,#route do total=total+adventure.travel:Cost(route[i-1],route[i])/speed end
    local fraction=math.min(1,math.max(0,(minute-p.AbstractStartedAt)/(p.AbstractArrivalAt-p.AbstractStartedAt)))
    return total*(1-fraction)
end
local travelerId,travelerHP
test('v18 abstract travel roundtrip retains its unprocessed simulation debt and wounds',function()
    local traveler
    for i=0,parties.data.Count-1 do local p=parties.data:GetAt(i);if mobile(p)then traveler=p;break end end
    assert(traveler,'World needs a far mobile party');travelerId=traveler.Id
    local start,goal=remoteCell({[travelerId]=true});relocate(traveler,start)
    local actor=traveler:GetMemberAt(0);actor:Damage(math.min(3,actor.HP-1));travelerHP=health(traveler)
    local minute=adventure.narrative.data.Minutes
    traveler:BeginAbstractTravel(goal.q,goal.r,minute,minute+240,lod.minimumStep/parties.definitions:Get(traveler.DefinitionId).speed)
    adventure.narrative:AdvanceMinutes(10);parties:SyncClock()
    assert(traveler.AbstractTravel and traveler.Lod==3 and traveler.SimulatedAt<adventure.narrative.data.Minutes,'Fixture must save outstanding far simulation debt')
    local saved={q=traveler.Travel.Q,r=traveler.Travel.R,lod=traveler.Lod,simulated=traveler.SimulatedAt,next=traveler.NextSimulationAt,
        started=traveler.AbstractStartedAt,arrival=traveler.AbstractArrivalAt,targetQ=traveler.AbstractQ,targetR=traveler.AbstractR}
    roundtrip();traveler=assert(parties.data:Find(travelerId))
    assert(traveler.AbstractTravel and traveler.Lod==saved.lod and traveler.Travel.Q==saved.q and traveler.Travel.R==saved.r)
    close(traveler.SimulatedAt,saved.simulated);close(traveler.NextSimulationAt,saved.next)
    close(traveler.AbstractStartedAt,saved.started);close(traveler.AbstractArrivalAt,saved.arrival)
    assert(traveler.AbstractQ==saved.targetQ and traveler.AbstractR==saved.targetR)
    sameHealth(traveler,travelerHP)
end)

test('far conflict resolves without an area, survives v18 reload and materializes its cargo once',function()
    local a,b
    for i=0,parties.data.Count-1 do local first=parties.data:GetAt(i)
        if mobile(first)and first.Id~=travelerId then
            for j=i+1,parties.data.Count-1 do local second=parties.data:GetAt(j)
                if mobile(second)and second.Id~=travelerId and first.FactionId~=second.FactionId and factions:Relation(first.FactionId,second.FactionId)=='hostile' then a,b=first,second;break end
            end
        end
        if a then break end
    end
    assert(a and b,'World needs two hostile far mobile factions')
    local location=remoteCell({[a.Id]=true,[b.Id]=true});relocate(a,location);relocate(b,location)
    local item=adventure.equipment.rules.items:Get(31)
    a:SetCargo('LOD integration cargo A',{31},{2},{item.kind},{item.width},{item.height})
    b:SetCargo('LOD integration cargo B',{31},{3},{item.kind},{item.width},{item.height})
    local ids={a.Id,b.Id};local before={health(a),health(b)}
    local minute=adventure.narrative.data.Minutes
    local conflict=factions.conflicts:Begin(a,b,minute,nil,true);local siteId=conflict.SiteId
    assert(not conflict.Materialized and not CS.ProjectY.Data.FactionPersistence.Find(adventure.data.Areas,siteId))
    local generator=adventure.areas.generator;local originalGenerate=generator.Generate;local generated=0
    generator.Generate=function(self,definition,seed,site,source)
        if site==siteId then generated=generated+1 end
        return originalGenerate(self,definition,seed,site,source)
    end
    local ok,reason=xpcall(function()
        adventure.narrative:AdvanceMinutes(math.max(lod.rule.farMinutes,factions.rules.settings.conflictMinimumMinutes));parties:SyncClock()
        assert(conflict.Phase=='resolved' and not conflict.Materialized,'Scheduled far conflict did not resolve as an abstract record')
        assert(generated==0 and not CS.ProjectY.Data.FactionPersistence.Find(adventure.data.Areas,siteId),'Remote combat eagerly generated a tactical battlefield')
        assert(conflict.PendingCargoCount==1,'The occupied winner hold must leave exactly one deferred loser hold')
        local pending=conflict:GetPendingCargoAt(0);local pendingName,pendingCount=pending.Name,pending:GetCountAt(0)
        local hp={health(a),health(b)};local defeated={a.Defeated,b.Defeated};local changed=false
        for n=1,2 do for i,value in ipairs(hp[n])do if value<before[n][i]then changed=true end end end
        assert(changed,'Far combat must update actual persistent actors')
        roundtrip();conflict=assert(factions.data:FindConflict(siteId));a=assert(parties.data:Find(ids[1]));b=assert(parties.data:Find(ids[2]))
        assert(conflict.Phase=='resolved' and not conflict.Materialized and conflict.PendingCargoCount==1)
        assert(not CS.ProjectY.Data.FactionPersistence.Find(adventure.data.Areas,siteId)and generated==0,'Reload materialized a distant ruin')
        assert(conflict:GetPendingCargoAt(0).Name==pendingName and conflict:GetPendingCargoAt(0):GetCountAt(0)==pendingCount)
        sameHealth(a,hp[1]);sameHealth(b,hp[2])
        local _,state=factions.conflicts:Prepare(conflict)
        assert(conflict.Materialized and generated==1 and conflict.PendingCargoCount==0 and state.LootCount==1)
        assert(state:GetLootAt(0).Name==pendingName and state:GetLootAt(0):GetCountAt(0)==pendingCount)
        for i=0,state.EncounterCount-1 do local group=state:GetEncounterAt(i)
            assert(CS.ProjectY.Data.FactionPersistence.Detached(group)and group.EnemyCount==0,'Resolved ruin respawned world party members')
            assert(CS.ProjectY.Data.FactionPersistence.PartyId(group)==ids[i+1])
        end
        local _,again=factions.conflicts:Prepare(conflict)
        assert(again==state and generated==1 and state.LootCount==1 and conflict.PendingCargoCount==0,'Repeated preparation duplicated cargo or geometry')
        assert(parties.data:DropDeferredCargo(conflict,state,1)==0,'Materialized cargo was not consumed exactly once')
        assert(a.Defeated==defeated[1]and b.Defeated==defeated[2]);sameHealth(a,hp[1]);sameHealth(b,hp[2])
    end,debug.traceback)
    generator.Generate=originalGenerate
    assert(ok,reason)
end)

test('pursuit and physical approach promote abstract travel without healing or double movement',function()
    local traveler=assert(parties.data:Find(travelerId));assert(traveler.AbstractTravel and traveler.Lod==3)
    local minute=adventure.narrative.data.Minutes;local expected=remainingAfterMaterialization(traveler,minute)
    local hp=health(traveler);local ok,reason=parties:Pursue(travelerId);assert(ok,reason)
    assert(traveler.Lod==1 and not traveler.AbstractTravel and traveler.Travel.Active,'Pursued party did not materialize a detailed route')
    close(traveler.Travel.RemainingMinutes,expected,'Pursuit advanced the abstract debt twice');sameHealth(traveler,hp)
    lod:Advance(minute);close(traveler.Travel.RemainingMinutes,expected,'Repeated promotion replayed elapsed movement')
    parties.data:Target(0);adventure.travel.data:Plan({},{},{},0);adventure.travel.data:SetPaused(true)

    local start,goal=remoteCell({[travelerId]=true});relocate(traveler,start)
    traveler:BeginAbstractTravel(goal.q,goal.r,minute,minute+120,lod.minimumStep/parties.definitions:Get(traveler.DefinitionId).speed)
    lod:Advance(minute);assert(traveler.Lod==3,'The approach fixture must first leave the detailed simulation radius')
    local vantage
    for _,cell in ipairs(adventure.map:GetCells())do
        local distance=Hex.Distance(cell.q,cell.r,start.q,start.r)
        if distance>=3 and distance<=lod.rule.nearRadius-2 and not cell.waterLevel and lod:Connected(start.q,start.r,cell.q,cell.r)then vantage=cell;break end
    end
    assert(vantage,'Need a reachable observation point outside contact range')
    ok,reason=adventure.travel:Plan(vantage,0);assert(ok,reason)
    local player=adventure.travel.data;player:SetPaused(false);player:AdvanceRoute(player.RemainingMinutes);player:Arrived();player:SetPaused(true)
    adventure.narrative:AdvanceMinutes(10);minute=adventure.narrative.data.Minutes;expected=remainingAfterMaterialization(traveler,minute)
    hp=health(traveler);parties:SyncClock()
    assert(traveler.Lod==1 and not traveler.AbstractTravel,'Approaching party corridor did not promote it')
    close(traveler.Travel.RemainingMinutes,expected,'Approach advanced the pending route twice');sameHealth(traveler,hp)
    lod:Advance(minute);close(traveler.Travel.RemainingMinutes,expected);sameHealth(traveler,hp)
end)
return table.concat(results,'\n')
