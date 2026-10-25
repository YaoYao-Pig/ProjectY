-- Use the existing Tools/GM/run_checks.cs with this Lua path in an isolated Edit Mode host.
local registry=require('Core.SystemRegistry')(Services);require('Game.Systems')(registry)
local Language=require('Language')
local messages={};local function test(name,run)run();messages[#messages+1]='PASS '..name end
function CloseGMPreview()registry:Shutdown();CloseGMPreview=nil end
local ok,err=xpcall(function()
    registry:Start()
    local adventure,gm,ui=registry:Get('Adventure'),registry:Get('GM'),registry:Get('UI')
    assert(not gm:Execute('no_random_encounters',1))
    adventure:Start(412)
    local travel=adventure.travel;local data=travel.data
    local demo={BattleHUDRevision=0,SelectedCharacterId=0,LastError=''}
    function demo:SetGMOpen(value)self.open=value end
    function demo:SendCommand(command,value)
        local success,why=gm:Execute(command:sub(4),value)
        self.LastError=success and '' or why;self.BattleHUDRevision=self.BattleHUDRevision+1
    end
    local panel=ui:Open('GM',{demo=demo,font=GMFont})
    test('saved toggle enables, disables and shows actual state across cached reopen',function()
        assert(not travel.randomEncountersDisabled and panel.view.NoRandomEncountersText.text==Language.GMNoRandomEncountersOff)
        panel.view.Slot.text='0';panel.view.SkillId.text='invalid'
        local revision=data.Revision;local q,r=data.Q,data.R
        panel.view.NoRandomEncounters.onClick:Invoke()
        assert(travel.randomEncountersDisabled and panel.view.NoRandomEncountersText.text==Language.GMNoRandomEncountersOn)
        assert(data.Revision==revision and data.Q==q and data.R==r and Services.UI.IsWorldPaused)
        panel.view.Close.onClick:Invoke();panel=ui:Open('GM',{demo=demo,font=GMFont})
        assert(panel.view.NoRandomEncountersText.text==Language.GMNoRandomEncountersOn)
        panel.view.NoRandomEncounters.onClick:Invoke()
        assert(not travel.randomEncountersDisabled and panel.view.NoRandomEncountersText.text==Language.GMNoRandomEncountersOff)
        assert(gm:Execute('no_random_encounters',1));panel:Tick()
        assert(panel.view.NoRandomEncountersText.text==Language.GMNoRandomEncountersOn)
    end)
    test('travel reset clears the session override and the panel notices the real state',function()
        travel:Reset(adventure.map,adventure.sites);panel:Tick()
        assert(not travel.randomEncountersDisabled and panel.view.NoRandomEncountersText.text==Language.GMNoRandomEncountersOff)
    end)
    test('real random battle creation is suppressed, then restored by switching the GM off',function()
        local row
        local kind=adventure.map:GetRegion(adventure.map:GetCell(data.Q,data.R).regionId).regionType
        for _,candidate in ipairs(travel.events:All())do
            local allowed=#candidate.regionTypes==0
            for _,region in ipairs(candidate.regionTypes)do if region==kind then allowed=true end end
            if candidate.encounterId>0 and candidate.weight>0 and allowed then row=candidate;break end
        end
        assert(row,'Fixture needs an eligible travel battle')
        local rule,events=travel.rule,travel.events
        travel.rule={eventChance=100};travel.events={All=function()return {row}end}
        assert(gm:Execute('no_random_encounters',1));local stops=data.StopCount;local sites=#adventure.sites
        assert(not travel:Check() and data.StopCount==stops and #adventure.sites==sites and adventure.data.Phase=='map')
        assert(gm:Execute('no_random_encounters',0));assert(travel:Check())
        assert(adventure.data.Phase=='battle' and data.StopCount==stops+1 and #adventure.sites==sites+1)
        travel.rule=rule;travel.events=events
        local encounter=adventure.data.Battle.EncounterId
        assert(gm:Execute('no_random_encounters',1) and adventure.data.Phase=='battle' and adventure.data.Battle.EncounterId==encounter)
        panel:Tick();panel.view.Result.text=Language.GMNoRandomEncountersEnabled
    end)
end,debug.traceback)
if not ok then CloseGMPreview();error(err,0)end
return 'GM encounter integration: '..#messages..' checks passed\n'..table.concat(messages,'\n')
