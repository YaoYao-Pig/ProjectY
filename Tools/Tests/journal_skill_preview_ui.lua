-- Isolated Edit Mode host: production registry, Data, panel and skill-node buttons.
-- The host supplies CheckSkillPreview(view, skillId, phase). Its native checks own
-- frame advancement, particle/animation assertions and gameplay/Unity RNG snapshots.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local messages={}
local originalRandom,originalRandomSeed=math.random,math.randomseed
local ok,err=xpcall(function()
    registry:Start()
    assert(CheckSkillPreview,'The native skill-preview checker is required')
    local ui,growth,adventure=registry:Get('UI'),registry:Get('Growth'),registry:Get('Adventure')
    local battle=registry:Get('Battle')
    local data=Services.Adventure;data:Reset(921)
    local actors={}
    for i,templateId in ipairs({1,3}) do
        local actor=data:AddPartyActor(i,templateId)
        adventure.characterAppearances:Party(actor,921);growth:PrepareActor(actor,templateId)
        actors[i]=actor
    end
    adventure.equipment:Start();adventure.equipment:StartPartyLoadouts()
    for _,actor in ipairs(actors) do
        actor:SetMaxHP(growth.stats:MaximumHP(actor));actor:Restore();actor:BeginTurn(7)
    end
    battle.data:SetRandomSeed(921)
    local adapter={LastError='',commands=0}
    function adapter:SetGrowthOpen(value) self.growthOpen=value end
    function adapter:SendCommand(command)
        self.commands=self.commands+1;error('Skill selection issued gameplay command: '..command)
    end
    local inventory=adventure.equipment.data
    local function snapshot()
        local values={}
        local function add(value) values[#values+1]=tostring(value) end
        add(data.JournalCount);add(data.PartyBonds.Revision);add(inventory.Revision)
        add(battle.data.LogCount);add(battle.data.Phase)
        for _,actor in ipairs(actors) do
            for _,key in ipairs({'HP','MaxHP','AP','Q','R','Guard','Moved','MainUsed','ActionSequence','ActionTemplateId','ActionShots'}) do add(actor[key]) end
            add(actor.Effects.Count)
            local state=actor.Growth
            for _,key in ipairs({'Revision','Level','Experience','AttributePoints','TalentPoints','LockedPotential','PendingCount','PendingLevel','CurrentProfessionId','SkillCount','TalentCount','OfferCount'}) do add(state[key]) end
            for i=0,state.SkillCount-1 do add(state:GetSkillAt(i)) end
            for i=0,state.TalentCount-1 do local id=state:GetTalentAt(i);add(id);add(state:GetRank(id)) end
            for i=0,state.OfferCount-1 do add(state:GetOfferAt(i)) end
            for _,skill in ipairs(growth.rules.skills:All()) do add(actor:GetCooldown(skill.id)) end
        end
        add(inventory.MagazineCount)
        for i=0,inventory.MagazineCount-1 do
            local magazine=inventory:GetMagazineAt(i)
            add(magazine.Id);add(magazine.AmmoItemId);add(magazine.Rounds)
        end
        add(inventory.WeaponCount)
        for i=0,inventory.WeaponCount-1 do
            local weapon=inventory:GetWeaponAt(i)
            add(weapon.Id);add(weapon.OwnerActorId);add(weapon.Hand);add(weapon.MagazineId)
            local condition=adventure.equipment.rules:Condition(weapon)
            add(condition.Current);add(condition.Maximum)
        end
        add(inventory.StackCount)
        for i=0,inventory.StackCount-1 do local stack=inventory:GetStackAt(i);add(stack.ItemId);add(stack.Count) end
        return table.concat(values,'|')
    end
    local before=snapshot()
    math.random=function() error('Skill preview consumed Lua gameplay randomness') end
    math.randomseed=function() error('Skill preview reseeded Lua gameplay randomness') end
    local panel=ui:Open('CharacterGrowth',{demo=adapter,tab='Skills'})
    local function unchanged()
        assert(adapter.commands==0,'Selection must not invoke a gameplay command')
        assert(snapshot()==before,'Skill preview changed AP, health, growth, effects, cooldowns, equipment or ammunition')
    end
    local function native(id,phase)
        unchanged();CheckSkillPreview(panel.view.Character,id,phase);unchanged()
    end
    local function check(name,run)
        run();unchanged();messages[#messages+1]='PASS '..name
    end
    local function click(id)
        for _,widget in ipairs(panel.courseNodes) do
            if widget.node and widget.node.id==id then
                assert(widget.view.Root.gameObject.activeSelf,'Requested node is hidden: '..id)
                widget.view.Button.onClick:Invoke()
                assert(panel.selectedCourse==id,'Node failed to select its skill: '..id)
                native(id,'started');return
            end
        end
        error('Missing real profession skill node '..id)
    end
    check('opening the journal does not auto-play its default selection',function()
        assert(panel.actor==actors[1] and actors[1].Growth.CurrentProfessionId==1)
        native(0,'stopped')
    end)
    check('unlearned injury strike plays and repeat selection restarts it',function()
        assert(not actors[1].Growth:HasSkill(1630),'Fixture must exercise an unlearned skill')
        click(1630);native(1630,'advance')
        click(1630);native(1630,'finished')
    end)
    check('refresh, page and talent changes stop the old preview',function()
        click(1630);panel:Refresh();native(0,'stopped')
        click(1630);panel.view.OverviewTab.onClick:Invoke();native(0,'stopped')
        panel.view.SkillsTab.onClick:Invoke();native(0,'stopped')
        click(1630);panel.view.NextTree.onClick:Invoke();native(0,'stopped')
        panel.view.PreviousTree.onClick:Invoke();native(0,'stopped')
    end)
    check('switching the real party selector clears the previous actor action',function()
        click(1630);native(1630,'advance')
        panel.view.Party2.onClick:Invoke()
        assert(panel.actor==actors[2] and actors[2].Growth.CurrentProfessionId==3)
        native(0,'stopped')
    end)
    check('mage nodes replace the action and use distinct configured effect profiles',function()
        assert(not actors[2].Growth:HasSkill(103) and not actors[2].Growth:HasSkill(104))
        click(103);native(103,'advance')
        click(104);native(104,'advance');native(104,'finished')
    end)
    check('preparation with explicit action zero still previews its effect',function()
        assert(battle:Skill(actors[2],403).actionTemplate==0)
        click(403);native(403,'advance');native(403,'finished')
    end)
    check('multi-shot projection plays all shots without spending ammunition',function()
        assert(battle:Skill(actors[2],8).shots==3)
        -- This equipment skill is outside the mage course tree; exercise the same selector.
        panel:SelectCourse(8);native(8,'started');native(8,'advance');native(8,'finished')
    end)
    check('profession chooser, close and cached reopen release or stop playback',function()
        click(103);panel.courseProfessionRoot.view.Button.onClick:Invoke()
        assert(panel.choosingProfession);native(0,'stopped')
        ui:Close('CharacterGrowth');native(0,'released')
        assert(not adapter.growthOpen and not Services.UI.IsWorldPaused)
        panel=ui:Open('CharacterGrowth',{demo=adapter,tab='Skills',actorIndex=1,selectedCourse=103})
        assert(panel.actor==actors[2] and panel.selectedCourse==103);native(0,'stopped')
        click(104);native(104,'advance')
        ui:Close('CharacterGrowth');native(0,'released')
        assert(not adapter.growthOpen and not Services.UI.IsWorldPaused)
    end)
    check('capture uses the actual injury-strike node and isolated preview clock',function()
        panel=ui:Open('CharacterGrowth',{demo=adapter,tab='Skills',actorIndex=0})
        native(0,'stopped');click(1630);native(1630,'capture')
        ui:Close('CharacterGrowth');native(0,'released')
    end)
    messages[#messages+1]='PASS all preview steps preserve both actors, learning opportunities, learned skills, ammo, action sequence and gameplay RNG'
end,debug.traceback)
math.random,math.randomseed=originalRandom,originalRandomSeed
registry:Shutdown()
if not ok then error(err,0) end
return table.concat(messages,'\n')
