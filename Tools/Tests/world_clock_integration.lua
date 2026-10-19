-- Idle Editor fixture with real C# state and game rules; no player save or Play mode.
local registry=require('Main');local adventure=registry:Get('Adventure');local Hex=require('Game.Map.HexGrid')
adventure:Start(20261016,3,10000)
local travel,parties=adventure.travel,adventure.parties;local data=travel.data
local messages={}
local function test(name,body)body();messages[#messages+1]='PASS '..name end
local function equal(a,b,message)assert(math.abs(a-b)<.000001,message..': '..tostring(a)..' / '..tostring(b))end
-- Keep one real town-to-town caravan so unrelated random enemies cannot interrupt clock measurements.
local source
for i=0,parties.data.Count-1 do local row=parties.data:GetAt(i)
    if row.DefinitionId==1 and row.Travel.RemainingMinutes>60 then source=row;break end
end
assert(source,'Clock fixture needs a connected caravan route')
local q,r,home,destination=source.Travel.Q,source.Travel.R,source.HomeSiteId,source.DestinationSiteId
parties.data:Clear();local caravan=parties.data:Add(1,q,r,home,431);caravan:SetDestination(destination);parties:Restock(caravan)
local site=adventure.sites[destination];assert(parties:Plan(caravan,adventure.map:GetCell(site.q,site.r)));parties.data:Complete(adventure.narrative.data.Minutes)
test('idle time and caravan movement advance at the three configured rates without random travel checks',function()
    assert(not data.Active and not data.Paused,'New expedition clock must start while the player is idle')
    local q,r=data.Q,data.R
    for _,speed in ipairs({1,2,4}) do
        assert(travel:Command('travel_speed',speed))
        local before=adventure.narrative.data.Minutes;local remaining=caravan.Travel.RemainingMinutes
        adventure:Tick(.125)
        equal(adventure.narrative.data.Minutes-before,travel.rule.minutesPerSecond*.125*speed,'Wrong idle clock rate')
        assert(caravan.Travel.RemainingMinutes<remaining and data.Q==q and data.R==r and not data.Active)
    end
    assert(not data:CheckDue(1),'Idle time must not accumulate random walking encounters')
    local before=adventure.narrative.data.Minutes;adventure.narrative:Tick(1)
    equal(adventure.narrative.data.Minutes,before,'Narrative auto-cycle double-counted world-map time')
end)
local function neighbor(q,r)
    local origin=adventure.map:GetCell(q,r)
    for direction=1,6 do local nq,nr=Hex.Neighbor(q,r,direction);local cell=adventure.map:FindCell(nq,nr)
        if cell and travel:Cost(origin,cell) then return cell end
    end
    error('Fixture has no walkable neighbor')
end
test('pause freezes everyone; changing speed and planning a route preserve pause',function()
    assert(travel:Command('travel_pause') and data.Paused)
    local before=adventure.narrative.data.Minutes;local remaining=caravan.Travel.RemainingMinutes
    assert(travel:Command('travel_speed',2) and data.Paused)
    assert(travel:Plan(neighbor(data.Q,data.R),0) and data.Active and data.Paused)
    adventure:Tick(1)
    equal(adventure.narrative.data.Minutes,before,'Paused world clock advanced')
    equal(caravan.Travel.RemainingMinutes,remaining,'Paused caravan advanced')
    equal(data.Progress,0,'Planning a route resumed paused movement')
end)
test('arrival stops only the squad and consumes the remaining frame as idle world time',function()
    assert(travel:Command('travel_pause') and not data.Paused)
    local last=data:GetStepAt(data.StepCount-1);local targetQ,targetR=last.Q,last.R
    local duration=data.RemainingMinutes+3;local before=adventure.narrative.data.Minutes
    adventure:Tick(duration/(travel.rule.minutesPerSecond*data.Speed))
    equal(adventure.narrative.data.Minutes-before,duration,'Arrival dropped the rest of the world-time budget')
    assert(not data.Active and not data.Paused and data.Q==targetQ and data.R==targetR)
    before=adventure.narrative.data.Minutes;adventure:Tick(.125)
    equal(adventure.narrative.data.Minutes-before,travel.rule.minutesPerSecond*.125*data.Speed,'Idle clock stopped after arrival')
end)
test('idle HUD exposes world pause and labels the 1/2/3 shortcuts',function()
    local hud=require('Game.Adventure.MainHudModel').Build(adventure);local pause,speeds
    speeds={}
    for _,row in ipairs(hud.rows) do
        if row.command=='travel_pause' then pause=row end
        if row.command=='travel_speed' then speeds[#speeds+1]=row end
    end
    assert(pause and pause.available and pause.title:find('时间') and hud.subtitle:find('1 / 2 / 3'))
    assert(#speeds==3)
    for i,expected in ipairs({1,2,4}) do assert(speeds[i].a==expected and speeds[i].body:find('数字键 '..i)) end
end)
test('modal UI and camp retain their pause lease without changing the selected clock state',function()
    local ui=registry:Get('UI');assert(adventure.camp:Open())
    local demo={MainHudFont=ShopFont,LastError='',BattleHUDRevision=0,SetStoryOpen=function(self,value)self.storyOpen=value end}
    ui:Open('Camp',{demo=demo});assert(Services.UI.IsWorldPaused)
    local before=adventure.narrative.data.Minutes;local remaining=caravan.Travel.RemainingMinutes
    adventure:Tick(1);equal(adventure.narrative.data.Minutes,before,'Modal UI did not pause the world clock')
    equal(caravan.Travel.RemainingMinutes,remaining,'Modal UI did not pause parties')
    ui:Back();assert(not Services.UI.IsWorldPaused and not adventure.camp.data.IsOpen and not data.Paused)
    adventure:Tick(.125);assert(adventure.narrative.data.Minutes>before)
end)
test('a hostile pursues and contacts a stationary player without requiring a move command',function()
    parties.data:Clear();local player=adventure.map:GetCell(data.Q,data.R);local spawn
    for direction=1,6 do local q,r=Hex.Neighbor(player.q,player.r,direction);local middle=adventure.map:FindCell(q,r)
        if middle and travel:Cost(player,middle) then
            for nextDirection=1,6 do local nq,nr=Hex.Neighbor(q,r,nextDirection);local cell=adventure.map:FindCell(nq,nr)
                if cell and Hex.Distance(player.q,player.r,nq,nr)==2 and travel:Cost(middle,cell) then spawn=cell;break end
            end
        end
        if spawn then break end
    end
    assert(spawn,'Fixture needs a two-step approach')
    local enemy=parties.data:Add(2,spawn.q,spawn.r,0,431);parties.data:Complete(adventure.narrative.data.Minutes)
    assert(travel:Command('travel_speed',1));local chasing=false
    for _=1,150 do
        adventure:Tick(.1);chasing=chasing or enemy.Chasing
        if adventure.data.Phase=='battle' then break end
    end
    assert(chasing and adventure.data.Phase=='battle' and enemy.BattleSiteId>0,'Idle player was not caught')
    assert(data.Q==player.q and data.R==player.r and not data.Active and data.Paused)
end)
return table.concat(messages,'\n')
