-- Isolated Edit Mode: actual actors, loot, turn ownership, settlement and saved GM button.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local Language=require('Language')
local messages={};local function test(name,run)run();messages[#messages+1]='PASS '..name end
function CloseGMPreview()registry:Shutdown();CloseGMPreview=nil end
local ok,err=xpcall(function()
    registry:Start()
    local adventure=registry:Get('Adventure');local gm=registry:Get('GM');local ui=registry:Get('UI')
    test('unstarted and world-map commands reject before mutation',function()
        assert(not gm:Execute('kill_target',1))
        adventure:Start(412)
        local actor=adventure.data:GetPartyAt(0);local hp=actor.HP
        assert(not gm:Execute('kill_target',actor.Id) and actor.HP==hp)
    end)
    local site
    for _,candidate in ipairs(adventure.sites) do if candidate.areaConfigId==1 then site=candidate;break end end
    assert(site and adventure.areas:Enter(site,adventure.data.Seed))
    local state=adventure.data.Areas.Active;local group=state:GetEncounterAt(0)
    local target,other=group:GetEnemyAt(0),group:GetEnemyAt(1)
    local party=adventure.data:GetPartyAt(0);local battle=adventure.battle
    test('invalid IDs and party members never take damage',function()
        local before=target.HP;local hp=party.HP
        for _,id in ipairs({0,-1,1.5,99999999,party.Id}) do assert(not gm:Execute('kill_target',id)) end
        assert(target.HP==before and party.HP==hp)
    end)
    test('exploration kill affects only one actor, bypasses guard and resolves loot once',function()
        local before=other.HP;local ap=party.AP;local events={}
        local subscription=battle.Changed:Subscribe(function(event)events[#events+1]=event end)
        target:SetGuard(100000)
        assert(gm:Execute('kill_target',target.Id))
        assert(target.HP==0 and target.DropResolved and other.HP==before and party.AP==ap)
        assert(#events>=2 and events[1].kind=='damage' and events[1].targetId==target.Id and events[1].hpAfter==0)
        local count=state.LootCount;local log=battle.data.LogCount
        assert(not gm:Execute('kill_target',target.Id) and state.LootCount==count and battle.data.LogCount==log)
        subscription()
    end)
    test('combat rejects friendly units and killing the active enemy advances the turn',function()
        local layout=adventure.areas:ActiveLayout()
        local deployment=assert(gm.npcs:Deployment(layout,state,assert(layout:Find(other.Q,other.R)).index))
        state:DeployMembers(deployment.ids,deployment.cells)
        adventure.areas:StartBattle(battle,group)
        assert(adventure.data.Phase=='battle')
        assert(not gm:Execute('kill_target',party.Id))
        local active
        for _=1,16 do
            if battle:Active().Team==2 then active=battle:Active();break end
            assert(battle:EndTurn())
        end
        assert(active,'Fixture needs an enemy turn')
        assert(gm:Execute('kill_target',active.Id))
        assert(active.HP==0 and adventure.data.Phase=='battle' and battle.data.ActiveId~=active.Id)
    end)
    test('last enemy uses ordinary victory settlement and never pays twice',function()
        local coins=adventure.player.Coins;local encounter=battle.encounters:Get(group.EncounterId)
        local last
        for i=0,group.EnemyCount-1 do local actor=group:GetEnemyAt(i)
            if actor.HP>0 then last=actor;assert(gm:Execute('kill_target',actor.Id)) end
        end
        assert(last and group.Defeated and adventure.data.Phase=='area')
        assert(adventure.player.Coins==coins+encounter.rewardCoins)
        local count=state.LootCount;coins=adventure.player.Coins
        assert(not gm:Execute('kill_target',last.Id) and state.LootCount==count and adventure.player.Coins==coins)
        adventure:CloseLoot()
    end)
    test('wild animals are valid targets and owned animals are protected',function()
        assert(adventure.areas:Leave())
        local forest
        for _,candidate in ipairs(adventure.sites)do
            local definition=candidate.areaConfigId and adventure.areas.generator.definitions:Get(candidate.areaConfigId)
            if definition and definition.areaType==adventure.areas.forestType then forest=candidate;break end
        end
        assert(forest and adventure.areas:Enter(forest,adventure.data.Seed))
        local state=adventure.data.Areas.Active;local animals={}
        for i=0,state.EncounterCount-1 do local group=state:GetEncounterAt(i)
            for j=0,group.EnemyCount-1 do local actor=group:GetEnemyAt(j)
                if actor.AnimalSpeciesId>0 and actor.Team==0 then animals[#animals+1]=actor end
            end
        end
        assert(#animals>=2,'Fixture needs wild animals')
        assert(gm:Execute('kill_target',animals[1].Id) and animals[1].HP==0)
        party:TameAndRide(animals[2],0)
        local hp=animals[2].HP
        assert(not gm:Execute('kill_target',animals[2].Id) and animals[2].HP==hp and party.MountedAnimal==animals[2])
    end)
    local demo={BattleHUDRevision=0,SelectedCharacterId=party.Id,LastError=''}
    function demo:SetGMOpen(value)self.open=value end
    function demo:SendCommand(command)
        assert(command=='gm_begin_kill');self.selecting=true;self.LastError='';self.BattleHUDRevision=self.BattleHUDRevision+1
    end
    test('saved kill button enters selection and releases the GM panel pause without needing slot input',function()
        local panel=ui:Open('GM',{demo=demo,font=GMFont})
        panel.view.Slot.text='0';panel.view.SkillId.text='invalid'
        assert(panel.view.KillTargetText.text==Language.UIGMKillTargetText)
        panel.view.KillTarget.onClick:Invoke()
        assert(demo.selecting and not demo.open and not ui:IsOpen('GM') and not Services.UI.IsWorldPaused)
        panel=ui:Open('GM',{demo=demo,font=GMFont})
        panel.view.Result.text=Language.GMKillPickHint
    end)
end,debug.traceback)
if not ok then CloseGMPreview();error(err,0) end
return 'GM kill integration: '..#messages..' checks passed\n'..table.concat(messages,'\n')
