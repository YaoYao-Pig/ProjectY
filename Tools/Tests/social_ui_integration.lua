-- Real prefabs and controls in the standard isolated PreviewScene host; no Play Mode required.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local messages={};local function test(name,run) run();messages[#messages+1]='PASS '..name end
local ui,adventure,panel,adapter
function CloseSocialPreview() registry:Shutdown();PreviewSocialPage=nil;CloseSocialPreview=nil end
local ok,err=xpcall(function()
    registry:Start();ui=registry:Get('UI');adventure=registry:Get('Adventure')
    local data,growth=Services.Adventure,adventure.growth;data:Reset(781)
    for i,id in ipairs({1,2,3}) do
        local actor=data:AddPartyActor(i,id);adventure.characterAppearances:Party(actor,781);growth:PrepareActor(actor)
        actor:SetMaxHP(growth.stats:MaximumHP(actor));actor:Restore()
    end
    adventure.equipment:Start();adventure.equipment:StartPartyLoadouts();data.Narrative:AdvanceMinutes(1505)
    for i=0,data.PartyCount-1 do local actor=data:GetPartyAt(i);actor:SetMaxHP(growth.stats:MaximumHP(actor));actor:Restore();growth:RecordJoined(actor,'营地') end
    local first,second=data:GetPartyAt(0),data:GetPartyAt(1)
    first:Deploy(1,0,0);second:Deploy(1,1,0)
    for _=1,3 do
        data.PartyBonds:BeginBattle();data.PartyBonds:AddParticipant(first);data.PartyBonds:AddParticipant(second)
        assert(data.PartyBonds:TryRescue(first.Id,second.Id,25));data.PartyBonds:SettleBattle(true,10)
    end
    data.PartyBonds:AwardHonor(first.Id,1)
    growth.chronicle:RecordPair('relationship',first,second,'危急援手','在石桥下救助了生命濒危的同伴。','石桥遗址',25)
    growth.chronicle:RecordPair('honor',first,second,'荣誉 · 守望者','完成三次真实危急救援。','石桥遗址',0)
    adapter={LastError=''}
    function adapter:SetGrowthOpen(value) self.growthOpen=value end
    function adapter:SendCommand() error('Social projection is read-only') end
    panel=ui:Open('CharacterGrowth',{demo=adapter})
    test('existing trait-tag controls show relation stages and honor detail without new prefab bindings',function()
        assert(Services.UI.IsWorldPaused and adapter.growthOpen)
        local relationship,honor
        for _,widget in ipairs(panel.pools.Traits) do if widget.row then
            if widget.row.title:find('生死与共',1,true) then relationship=widget end
            if widget.row.title=='★ 荣誉 · 守望者' then honor=widget end
        end end
        assert(relationship and honor and relationship.view.Button.interactable and honor.view.Button.interactable)
        relationship.view.Button.onClick:Invoke();assert(panel.view.TraitDetail.text:find('关系 100 / 100',1,true))
        honor.view.Button.onClick:Invoke();assert(panel.view.TraitDetail.text:find('3 / 3',1,true))
        panel.view.HistoryTab.onClick:Invoke();local latest=panel.pools.HistoryRows[1].view.Title.text
        assert(latest:find('第2日 01:05',1,true) and latest:find('石桥遗址',1,true))
    end)
    test('individual histories exclude an uninvolved companion and cached reopen preserves relation display',function()
        panel.view.Party3.onClick:Invoke();assert(panel.view.HistorySummary.text:find('留下 1 段经历',1,true))
        ui:Close('CharacterGrowth');assert(not Services.UI.IsWorldPaused and not adapter.growthOpen)
        panel=ui:Open('CharacterGrowth',{demo=adapter});assert(panel.actor.Id==first.Id)
        local found=false;for _,widget in ipairs(panel.pools.Traits) do if widget.row and widget.row.title=='★ 荣誉 · 守望者' then found=true end end
        assert(found)
    end)
    function PreviewSocialPage(name)
        ui:Close('CharacterGrowth');panel=ui:Open('CharacterGrowth',{demo=adapter})
        if name=='history' then panel.view.HistoryTab.onClick:Invoke() end
    end
end,debug.traceback)
if not ok then CloseSocialPreview();error(err,0) end
return table.concat(messages,'\n')
