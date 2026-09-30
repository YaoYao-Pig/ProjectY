-- 使用真实 Data、UGUI Prefab 和 Lua 控制器，在独立 PreviewScene 中验证；不进入 Play。
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local messages={}
local function test(name,run) run();messages[#messages+1]='PASS '..name end
local ui,adventure,growth,data,adapter
function CloseGrowthPreview() registry:Shutdown();PreviewGrowthPage=nil;CloseGrowthPreview=nil end
local ok,err=xpcall(function()
    registry:Start()
    ui,adventure,growth,data=registry:Get('UI'),registry:Get('Adventure'),registry:Get('Growth'),Services.Adventure
    data:Reset(920)
    for i,id in ipairs({1,2,3,6}) do local actor=data:AddPartyActor(i,id);growth:Initialize(actor);actor:SetMaxHP(growth.stats:MaximumHP(actor));actor:Restore() end
    adventure.sites={{id=1,eventId=6,name='灰烬门廊'},{id=2,eventId=5,name='古老路标'}}
    adapter={BattleHUDRevision=0,LastError='',commands=0}
    function adapter:SetGrowthOpen(value) self.growthOpen=value end
    function adapter:SetStoryOpen(value) self.storyOpen=value end
    function adapter:OpenGrowth() ui:Open('CharacterGrowth',{demo=self}) end
    function adapter:SendCommand(command,a,b)
        local success,reason
        if command=='growth_attribute' then success,reason=growth:InvestAttribute(a,b)
        elseif command=='growth_talent' then success,reason=growth:InvestTalent(a,b)
        elseif command=='growth_skill' then success,reason=growth:Learn(a,b)
        elseif command=='choose' then success,reason=adventure:Choose(a)
        elseif command=='return' then success,reason=adventure:ReturnToMap();ui:Close('StoryEvent')
        else error('Unexpected growth UI command: '..command) end
        self.LastError=success and '' or reason;self.BattleHUDRevision=self.BattleHUDRevision+1;self.commands=self.commands+1
    end
    local panel=ui:Open('CharacterGrowth',{demo=adapter})
    test('overview reads real attributes and trait tags; attribute button mutates once',function()
        assert(adapter.growthOpen and Services.UI.IsWorldPaused)
        assert(panel.view.Summary.text:find('属性点 2',1,true))
        assert(#panel.pools.Attributes==growth.rules.attributes.Count and #panel.pools.Traits==1)
        local seen={}
        for i,row in ipairs(growth.rules.attributes:All()) do
            local widget=panel.pools.Attributes[i]
            assert(widget.view.Icon.sprite~=nil,'Missing rendered glyph for '..row.code)
            seen[row.code]=true
        end
        assert(seen.animalAffinity and seen.charisma,'Animal affinity and charisma must be covered by the real UI check')
        local actor=data:GetPartyAt(0);local hp=actor.MaxHP
        panel.pools.Attributes[1].view.Button.onClick:Invoke()
        assert(actor.MaxHP==hp+4 and actor.Growth.AttributePoints==1 and adapter.commands==1)
    end)
    test('talent nodes and edges use config positions; selection and investment reach real rules',function()
        panel.view.SkillsTab.onClick:Invoke();assert(#panel.nodes==9 and #panel.edges==11)
        panel.nodes[1].view.Button.onClick:Invoke();assert(panel.view.Invest.interactable)
        panel.view.Invest.onClick:Invoke();assert(data:GetPartyAt(0).Growth:GetRank(1)==1)
        panel.view.NextTree.onClick:Invoke();assert(panel.view.TreeTitle.text:find('未解锁',1,true))
        panel.nodes[1].view.Button.onClick:Invoke();assert(not panel.view.Invest.interactable)
    end)
    test('active choices survive cached reopen and learn through the real button',function()
        local actor=data:GetPartyAt(0);growth:AddExperience(actor,40,'营火旁')
        local first=actor.Growth:GetOfferAt(0);ui:Close('CharacterGrowth');assert(not Services.UI.IsWorldPaused)
        panel=ui:Open('CharacterGrowth',{demo=adapter});panel.view.SkillsTab.onClick:Invoke()
        assert(actor.Growth:GetOfferAt(0)==first)
        local commands=adapter.commands;panel.pools.SkillRows[1].view.Button.onClick:Invoke()
        assert(actor.Growth:HasSkill(first) and adapter.commands==commands+1)
        panel.view.HistoryTab.onClick:Invoke();assert(#panel.pools.HistoryRows>0)
        panel.view.Close.onClick:Invoke();assert(not adapter.growthOpen and not Services.UI.IsWorldPaused)
    end)
    test('complex story prefab binds art and choices; resolution is recorded and modal pause returns',function()
        assert(adventure:Visit(1));local story=ui:Open('StoryEvent',{demo=adapter})
        assert(story.view.Illustration.sprite~=nil and #story.pools.Choices==3 and Services.UI.IsWorldPaused)
        story.pools.Choices[1].view.Button.onClick:Invoke();ui:Tick(0,0)
        assert(data.Phase=='result' and story.view.Continue.gameObject.activeSelf)
        assert(data:GetPartyAt(0).Growth:HasTree(2));assert(not story.pools.Choices[1].view.Root.gameObject.activeSelf)
        story.view.Continue.onClick:Invoke();assert(data.Phase=='map' and not adapter.storyOpen and not Services.UI.IsWorldPaused)
    end)
    test('simple event stays in map; in-game journal displays tagged results',function()
        assert(adventure:Visit(2));assert(data.Phase=='map')
        local journal=ui:Open('AdventureJournal',{demo=adapter});assert(not Services.UI.IsWorldPaused)
        assert(journal.pools.Logs[1].view.Title.text:find('【',1,true));ui:Close('AdventureJournal')
    end)
    function PreviewGrowthPage(name)
        ui:Close('CharacterGrowth');ui:Close('StoryEvent');ui:Close('AdventureJournal')
        if name=='event' then
            assert(adventure.events:Begin({id=3,eventId=6,name='灰烬门廊'}))
            ui:Open('StoryEvent',{demo=adapter})
        else
            panel=ui:Open('CharacterGrowth',{demo=adapter})
            if name=='skills' then panel.view.SkillsTab.onClick:Invoke()
            elseif name=='history' then panel.view.HistoryTab.onClick:Invoke() end
        end
    end
end,debug.traceback)
if not ok then CloseGrowthPreview();error(err,0) end
return table.concat(messages,'\n')
