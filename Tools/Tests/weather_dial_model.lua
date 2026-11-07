-- Real exported lighting configuration and production HUD/model code; mocks only at C#/view boundaries.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Model=require('Game.Adventure.WeatherDialModel')
local samples,positions=0,0
local lastX,lastZ,lastMinutes
local cloud,rain=.37,.22
local field={Sample=function(_,x,z,minutes)
    samples=samples+1;lastX,lastZ,lastMinutes=x,z,minutes
    return {Cloud=cloud,Rain=rain}
end}
local adventure={config=config,map={GetCellWorldPosition=function(_,q,r)
        positions=positions+1;return q*13,91,r*17
    end},weatherField=field,data={Phase='map',Areas={ActiveSiteId=0},JournalCount=0},
    travel={data={Q=2,R=-3}},sites={{x=57,z=-81},{x=-93,z=43}},narrative={data={Minutes=600.125,DialogueOpen=false}}}
local model=Model.New(adventure)
local day,dusk,night=model:Periods()
local profile=config:GetTable('MapEnvironmentTable'):Get(1)
local keys=config:GetTable('MapLightKeyTable')
assert(day==keys:Get(profile.dialDayKeyId).hour and dusk==keys:Get(profile.dialDuskKeyId).hour and night==keys:Get(profile.dialNightKeyId).hour)
assert(day==7 and dusk==17 and night==21,'Exported dial mapping does not match the chosen light keys')
local minutes,c,r=model:Read(0)
assert(minutes==600.125 and c==.37 and r==.22 and samples==1 and lastX==26 and lastZ==-51)
for i=1,4 do adventure.narrative.data.Minutes=600.125+i*.01;minutes=model:Read(.05) end
assert(samples==1 and positions==1 and minutes==600.165,'Every-frame clock updates must retain fractions without querying weather/position')
model:Read(.051);assert(samples==2 and lastMinutes==600.165,'Weather must refresh using current fractional game minutes when due')
for i=1,8 do model:Read(.25) end
assert(samples==2,'Paused, unmoved gameplay state must reuse its last weather sample')
adventure.travel.data.Q=-4;model:Read(.1);assert(samples==2)
model:Read(.15);assert(samples==3 and lastX==-52 and lastZ==-51,'Travel position changed without updating weather')
adventure.data.Phase='area';adventure.data.Areas.ActiveSiteId=1
model:Read(.25);assert(lastX==57 and lastZ==-81,'Local area used its local coordinates instead of its world site origin')
adventure.data.Phase='battle';adventure.data.Areas.ActiveSiteId=2
model:Read(.25);assert(lastX==-93 and lastZ==43,'Local battle did not use its active site')
adventure.data.Areas.ActiveSiteId=0;model:Read(.25)
assert(lastX==-52 and lastZ==-51,'Legacy battle without an area lost its retained travel anchor')
for _,phase in ipairs({'event','result','map'}) do adventure.data.Phase=phase;model:Read(.25);assert(lastX==-52 and lastZ==-51) end
adventure.data.Areas.ActiveSiteId=2
model:Read(.25);assert(lastX==-52 and lastZ==-51,'Map phase must follow travel even if an old area id is present')
adventure.data.Areas.ActiveSiteId=0
local before=samples;adventure.narrative.data.Minutes=1440.75;model:Read(5)
assert(samples==before+1,'Long frames must issue at most one query')
adventure.narrative.data.Minutes=1441;model:Read(.1);assert(samples==before+1,'Long-frame remainder caused a second query before .25 real seconds')
model:Read(.15);assert(samples==before+2)
local replacement={Sample=field.Sample};adventure.weatherField=replacement
model:Read(.25);assert(samples==before+3,'Replacing a world field must invalidate paused weather')
model:Reset();model:Read(0);assert(samples==before+4,'Showing a cached HUD must immediately obtain current weather')
assert(not pcall(model.Read,model,-.01),'Negative visual delta must not silently reverse the sampling clock')
adventure.data.Phase='area';adventure.data.Areas.ActiveSiteId=99
assert(not pcall(model.Read,model,.25),'Missing site must fail rather than inventing a world origin')
adventure.data.Phase='map';adventure.data.Areas.ActiveSiteId=0
local invalid=Model.New({config={GetTable=function(_,name)
    if name=='MapEnvironmentTable' then return {Get=function()return {dialDayKeyId=7,dialDuskKeyId=5,dialNightKeyId=3}end}end
    return keys
end}})
assert(not pcall(invalid.Periods,invalid),'Reversed configuration periods were accepted')

-- Invoke the real Clock/Tick methods with a minimal view, rather than mirroring controller logic.
local overview=0
CS={ProjectY={Samples={WorldMapOverviewBridge={Progress=function()return overview end}}}}
local HUD=require('UI.Panel.MainHudCtr')
local stateCalls,visualCalls=0,0
local displayedMinutes,visualDelta
local view={WeatherDial={SetState=function(_,total,coverage,intensity)
        stateCalls=stateCalls+1;displayedMinutes=total;assert(coverage==cloud and intensity==rain)
    end,TickVisual=function(_,dt)visualCalls=visualCalls+1;visualDelta=dt end},
    ClockTime={},ClockDay={},WeatherDialGroup={alpha=0},Group={alpha=1,interactable=true},MapTransition={SetProgress=function()end},
    SkillHint={},HealthTooltip={gameObject={SetActive=function()end}}}
local hud=setmetatable({adventure=adventure,weatherDial=model,view=view,skills={},health={},
    battleContent={view={Group={}}},demo={BattleHUDRevision=1,SelectedCharacterSkill=0},revision=1,journalCount=0},HUD)
adventure.narrative.data.Minutes=1440.75;model:Reset();hud:Clock(0)
assert(displayedMinutes==1440.75 and view.ClockTime.text=='00:00')
assert(view.ClockDay.text==string.format(require('Language').UIMainHudClockDayText,2),'Clock day no longer uses the existing localized template')
adventure.narrative.data.Minutes=1440.875;hud:Tick(.5,.03)
assert(displayedMinutes==1440.875 and visualDelta==.03 and visualCalls==1,'Clock visual used scaled time or rounded minutes')
assert(view.WeatherDialGroup.alpha==1,'Clock art remained hidden after its first visual tick')
local shown=stateCalls;local sampled=samples
overview=1;hud:Tick(.5,.3)
assert(stateCalls==shown and visualCalls==1 and samples==sampled,'Fully hidden overview clock still updated weather or animation')
overview=0;adventure.narrative.data.DialogueOpen=true;hud:Tick(.5,.3)
assert(stateCalls==shown and visualCalls==1 and samples==sampled,'Dialogue-hidden HUD still updated weather or animation')
adventure.narrative.data.DialogueOpen=false;hud:Tick(.5,.3)
assert(stateCalls==shown+1 and visualCalls==2 and displayedMinutes==1440.875,'Visible HUD did not resume its clock')
print('PASS weather dial: real light-key mapping, fractional clock, bounded authoritative queries, paused cache, local/battle/event anchors, world replacement, invalid context, localization and hidden-HUD gating')
