-- 独立 PreviewScene 内的真实 UI / Data；输入适配器只替代场景的显示与命令转发。
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local messages={}
local function test(name,fn) fn();messages[#messages+1]='PASS '..name end
local ui,adventure,hud,demo,areaSite,eventSite
local enemyTargets={}
function CloseHudPreview()
    registry:Shutdown();for _,target in pairs(enemyTargets) do CS.UnityEngine.Object.DestroyImmediate(target.gameObject) end
    PreviewMainHud=nil;HudPreviewActors=nil;CloseHudPreview=nil
end
local ok,err=xpcall(function()
    registry:Start();ui,adventure=registry:Get('UI'),registry:Get('Adventure');adventure:Start()
    for _,site in ipairs(adventure.sites) do
        if site.areaConfigId==1 and not areaSite then areaSite=site end
        if site.eventId==1 then eventSite=site end
    end
    demo={BattleHUDRevision=0,LastError='',WorldCamera=HudWorldCamera,BattleAutoAI=false,IsBattleMoveSelected=true,SelectedBattleSkill=0,commands=0}
    demo.SelectedCharacterId=0;demo.SelectedCharacterSkill=0
    function demo:SelectCharacter(id) self.SelectedCharacterId=id;self.SelectedCharacterSkill=0;self.BattleHUDRevision=self.BattleHUDRevision+1 end
    function demo:SelectCharacterSkill(actorId,skillId,target) self.SelectedCharacterId=actorId;self.SelectedCharacterSkill=skillId;self.BattleHUDRevision=self.BattleHUDRevision+1 end
    function demo:CancelCharacterSkill() self.SelectedCharacterSkill=0;self.BattleHUDRevision=self.BattleHUDRevision+1 end
    function demo:RenderedHealthActorIds()
        local ids={Length=0}
        local actors=adventure.data.Phase=='battle' and adventure.battle:Units() or {}
        for _,actor in ipairs(actors) do if actor.HP>0 then ids[ids.Length]=actor.Id;ids.Length=ids.Length+1 end end
        return ids
    end
    function demo:SetMainHud(view) self.mainHud=view end
    function demo:HealthTarget(id)
        local party=({HudTarget1,HudTarget2,HudTarget3,HudTarget4})[id]
        if party then return party end
        if not enemyTargets[id] then
            local root=CS.UnityEngine.GameObject('HudEnemyFixture_'..id)
            CS.UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,HudWorldCamera.gameObject.scene)
            root.transform.position=CS.UnityEngine.Vector3((id%3)*3,1,5);enemyTargets[id]=root.transform
        end
        return enemyTargets[id]
    end
    function demo:HealthScreenPosition(id) return CS.UnityEngine.Vector2(420+(id%4)*100,360) end
    function demo:OpenEquipment() self.opened='equipment' end
    function demo:OpenGrowth() self.opened='growth' end
    function demo:FitMap() self.focused=true end
    function demo:ToggleTownCamera() self.cameraToggle=true end
    function demo:ToggleEnvironment() self.environmentToggle=true end
    function demo:StartExpedition() adventure:Start();self.BattleHUDRevision=self.BattleHUDRevision+1 end
    function demo:SelectBattleSkill(id) self.SelectedBattleSkill=id;self.IsBattleMoveSelected=false;self.BattleHUDRevision=self.BattleHUDRevision+1 end
    function demo:SelectBattleMove() self.IsBattleMoveSelected=true;self.BattleHUDRevision=self.BattleHUDRevision+1 end
    function demo:SetBattleAutoAI(value) self.BattleAutoAI=value;self.BattleHUDRevision=self.BattleHUDRevision+1 end
    function demo:FocusBattleActor() end
    function demo:SendCommand(command,a,b,c)
        if command=='hud_follow' then self.focused=true;return end
        local success,why
        if command=='visit' then success,why=adventure:Visit(a)
        elseif command=='character_skill' then success,why=adventure.characterSkills:Use(a,b,c);self:CancelCharacterSkill()
        elseif command:sub(1,5)=='area_' then success,why=adventure:AreaCommand(command,a,b)
        else success,why=adventure:BattleCommand(command,a,b) end
        self.LastError=success and '' or why;self.commands=self.commands+1;self.BattleHUDRevision=self.BattleHUDRevision+1
    end
    hud=ui:Open('MainHud',{demo=demo})
    test('MainHud owns navigation, party, journal and real entry buttons without pausing',function()
        local visits=0;for _,widget in ipairs(hud.pools.NavigationRows) do if widget.row.command=='visit' then visits=visits+1 end end
        assert(not Services.UI.IsWorldPaused and #hud.party==4 and visits==#adventure.sites)
        assert(demo.mainHud~=nil and not hud.battleContent.visible)
        hud.view.Inventory.onClick:Invoke();assert(demo.opened=='equipment')
        hud.view.Growth.onClick:Invoke();assert(demo.opened=='growth')
        local row;for _,widget in ipairs(hud.pools.NavigationRows) do if widget.row.a==areaSite.id then row=widget;break end end
        assert(row and row.row.command=='visit')
        row.view.Button.onClick:Invoke();ui:Tick(0,0)
        assert(adventure.data.Phase=='area' and demo.commands==1 and #hud.model.health==0)
        assert(not hud.view.HealthLayer.gameObject.activeSelf)
    end)
    test('party selection filters owned life skills and the dual-context taming entry has a real button',function()
        local actor=adventure.data:GetPartyAt(0)
        actor.Growth:AddExperience(1);actor.Growth:AdvanceLevel(1,0,0,true);actor.Growth:AddOffer(201);actor.Growth:LearnOffer(201)
        hud.party[1].view.Button.onClick:Invoke();ui:Tick(0,0)
        assert(demo.SelectedCharacterId==actor.Id and hud.party[1].view.Selected.gameObject.activeSelf)
        assert(#hud.skillRows==1 and hud.skillRows[1].id==201 and hud.skills[1].view.Contexts.text=='生活 + 战斗')
        assert(hud.view.CharacterSkills.gameObject.activeInHierarchy and not hud.view.SkillEmpty.gameObject.activeSelf)
        assert(not hud.skills[1].view.Button.interactable,'Dungeon fixture has no neutral animal target')
        hud.party[2].view.Button.onClick:Invoke();ui:Tick(0,0)
        assert(#hud.skillRows==0 and hud.view.SkillEmpty.gameObject.activeSelf and not hud.skills[1].view.Root.gameObject.activeSelf)
        hud.party[1].view.Button.onClick:Invoke();ui:Tick(0,0)
    end)
    test('exploration keeps party HP cards but creates no overhead health',function()
        local actor=adventure.data:GetPartyAt(0);actor:Damage(5);demo.BattleHUDRevision=demo.BattleHUDRevision+1;ui:Tick(0,0)
        assert(hud.party[1].view.HealthText.text==actor.HP..' / '..actor.MaxHP)
        assert(#hud.health==0 and not hud.view.HealthLayer.gameObject.activeSelf)
        assert(adventure.events:BeginArea(6,'hud-visibility-test','测试门廊'))
        demo.BattleHUDRevision=demo.BattleHUDRevision+1;ui:Tick(0,0)
        assert(#hud.model.health==0 and not hud.view.HealthLayer.gameObject.activeSelf)
        assert(adventure:Choose(3));demo.BattleHUDRevision=demo.BattleHUDRevision+1;ui:Tick(0,0)
        assert(#hud.model.health==0 and not hud.view.HealthLayer.gameObject.activeSelf)
        assert(adventure:ReturnToMap())
    end)
    test('combat content is a MainHud child and reaches actual battle commands',function()
        assert(adventure.areas:Leave());assert(adventure:Visit(eventSite.id));assert(adventure:Choose(1))
        demo.BattleHUDRevision=demo.BattleHUDRevision+1;ui:Tick(0,0)
        assert(hud.battleContent.visible and not hud.view.Exploration.gameObject.activeSelf and not ui:IsOpen('BattleHUD'))
        assert(hud.battleContent.view.Root.gameObject.activeInHierarchy)
        assert(hud.battleContent.view.Root.localScale.x==1 and hud.battleContent.view.Root.localScale.y==1,'Embedded battle HUD must not retain a zero prefab scale')
        assert(hud.battleContent.view.Group.alpha==1)
        assert(hud.view.HealthLayer.gameObject.activeSelf and #hud.model.health>0)
        assert(hud.health[1].view.Root.rect.width==160 and hud.health[1].view.Root.rect.height==50)
        assert(not pcall(function() hud.battleContent.view.ActorName.text='' end),'Detached active-actor status panel must be removed')
        for _,head in ipairs(hud.health) do if head.row then
            local actor=assert(adventure.battle:FindUnit(head.row.id))
            assert(head.view.APText.text==actor.AP..' / '..adventure.battle.stats:Template(actor).actionPoints..' AP')
            assert(head.view.Health.color.r>head.view.Health.color.g and head.view.AP.color.b>head.view.AP.color.r)
        end end
        hud.view.Group.interactable=false;ui:Tick(0,0);assert(not hud.battleContent.view.Group.interactable)
        hud.view.Group.interactable=true;ui:Tick(0,0)
        local before=demo.commands;hud.battleContent.view.Move.onClick:Invoke();assert(demo.IsBattleMoveSelected)
        hud.battleContent.view.EndTurn.onClick:Invoke();assert(demo.commands==before+1)
        ui:Close('MainHud');hud=ui:Open('MainHud',{demo=demo})
        assert(hud.battleContent.visible and hud.battleContent.view.Root.gameObject.activeInHierarchy,'Reopening MainHud in battle must leave the embedded HUD active')
    end)
    test('overhead HP/AP and effects belong to each actor and refresh independently of the active turn',function()
        local battle=adventure.battle;local target
        for _,actor in ipairs(battle:Units()) do if actor.Team==2 and actor.Id~=battle.data.ActiveId then target=actor;break end end
        assert(target)
        local original=battle.effects
        local row={id=9001,name='灼烧',description='头顶状态验证',kind='damage',amount={Evaluate=function()return 1 end},duration='duration',durationTurns=2,periodTurns=1,tickPhase='turn_end',stacking='refresh',maxStacks=1,removeOnBattleEnd=true,removeOnDeath=true,attribute='',iconId=1}
        local definitions={Get=function(_,id)if id==9001 then return row end;return original:Get(id)end}
        battle.gameEffects.definitions=definitions;battle.stats.effects=definitions
        target:BeginTurn(battle.stats:Template(target).actionPoints)
        battle.gameEffects:Apply(9001,battle:Active(),target);ui:Tick(0,0)
        local head
        for _,widget in ipairs(hud.health) do if widget.row and widget.row.id==target.Id then head=widget;break end end
        assert(head and head.view.Root.rect.height==74 and head.effects[1].view.Count.text=='2')
        assert(head.view.APText.text==target.AP..' / '..battle.stats:Template(target).actionPoints..' AP')
        hud.view.HUD:UpdateFollowers();assert(head.view.Follower.ProjectedVisible)
        head.effects[1].view.Pointer:OnPointerEnter(nil);ui:Tick(0,0)
        assert(hud.view.HealthTooltip.gameObject.activeSelf and hud.view.HealthTipBody.text:find('头顶状态验证',1,true))
        assert(not head.view.Health.raycastTarget and not head.view.AP.raycastTarget)
        local hp=target.HP;target:SpendAction('secondary',1)
        battle.gameEffects:TickActor(target,'turn_end');ui:Tick(0,0)
        assert(target.HP==hp-1 and head.effects[1].view.Count.text=='1')
        assert(head.view.HealthText.text==target.HP..' / '..target.MaxHP and head.view.APText.text==target.AP..' / '..battle.stats:Template(target).actionPoints..' AP')
        battle.gameEffects:TickActor(target,'turn_end');ui:Tick(0,0)
        assert(head.view.Root.rect.height==50 and not head.effects[1].view.Root.gameObject.activeSelf and not hud.view.HealthTooltip.gameObject.activeSelf)
        battle.gameEffects.definitions=original;battle.stats.effects=original
    end)
    test('new expedition and cached reopen release combat subscriptions and followers',function()
        demo:StartExpedition();ui:Tick(0,0);assert(not hud.battleContent.visible)
        ui:Close('MainHud');assert(demo.mainHud==nil)
        hud=ui:Open('MainHud',{demo=demo});assert(not hud.battleContent.visible and #hud.party==4 and not Services.UI.IsWorldPaused)
        assert(adventure:Visit(areaSite.id));demo.BattleHUDRevision=demo.BattleHUDRevision+1;ui:Tick(0,0)
        local visible=0;for _,widget in ipairs(hud.health) do if widget.row then visible=visible+1;assert(widget.view.Root.gameObject.activeSelf) end end
        assert(visible==0 and not hud.view.HealthLayer.gameObject.activeSelf)
    end)
    test('forest life-skill button selects a target and dispatches production taming without starting combat',function()
        assert(adventure.areas:Leave())
        local forest;for _,site in ipairs(adventure.sites) do if site.areaConfigId==20 then forest=site;break end end
        assert(forest and adventure:Visit(forest.id))
        local areas=adventure.areas;local area,state=areas:ActiveLayout(),adventure.data.Areas.Active
        local target
        for i=0,state.EncounterCount-1 do local group=state:GetEncounterAt(i)
            for j=0,group.EnemyCount-1 do local animal=group:GetEnemyAt(j)
                if animal.AnimalSpeciesId>0 and not target then target=animal end
            end
        end
        assert(target);target:Deploy(0,target.Q,target.R)
        local actor=adventure.data:GetPartyAt(0)
        actor.Growth:AddExperience(1);actor.Growth:AdvanceLevel(1,0,0,true);actor.Growth:AddOffer(201);actor.Growth:LearnOffer(201)
        actor.Growth:InvestAttribute('animalAffinity',1,20);actor.Growth:InvestAttribute('charisma',1,20)
        local blocked=areas:EnemyOccupancy(area,state);local center=area:Find(target.Q,target.R)
        local origin;for _,cell in ipairs(area:Neighbors(center)) do if not blocked[cell.index] then origin=cell;break end end
        assert(origin)
        local ids={};for i=0,state.MemberCount-1 do ids[#ids+1]=state:GetMemberIdAt(i) end
        local positions=require('Game.MapArea.SquadMovement').Deploy(area,origin.index,#ids,function(cell)return not blocked[cell.index]end)
        state:DeployMembers(ids,positions);areas:RevealSquad(area,state)
        demo:SelectCharacter(actor.Id);ui:Tick(0,0)
        assert(#hud.skillRows==1 and hud.skills[1].view.Button.interactable)
        hud.skills[1].view.Button.onClick:Invoke();ui:Tick(0,0)
        assert(demo.SelectedCharacterSkill==201 and hud.view.CancelSkill.gameObject.activeSelf)
        hud.view.CancelSkill.onClick:Invoke();ui:Tick(0,0);assert(demo.SelectedCharacterSkill==0)
        for attempt=1,10 do
            hud.skills[1].view.Button.onClick:Invoke()
            demo:SendCommand('character_skill',actor.Id,demo.SelectedCharacterSkill,target.Id);ui:Tick(0,0)
            if actor.MountedAnimal then break end
            assert(target.TameRetryTurns>0 and not hud.skills[1].view.Button.interactable)
            for _=1,target.TameRetryTurns do state:CompleteWorldRound() end
            demo.BattleHUDRevision=demo.BattleHUDRevision+1;ui:Tick(0,0)
        end
        assert(actor.MountedAnimal==target and adventure.data.Phase=='area' and demo.SelectedCharacterSkill==0)
        assert(state:GetMemberCellAt(0)==center.index and target.AnimalOwnerId==actor.Id)
        assert(not hud.skills[1].view.Button.interactable,'A mounted actor cannot collect another mount')
        assert(adventure.characterSkills:Rows(adventure.data:GetPartyAt(1).Id,'life')[1]==nil)
        assert(areas:Leave());assert(adventure:Visit(forest.id));assert(actor.MountedAnimal==target)
        -- 预览使用有驯服技能的骑手；对象仍来自此隔离远征，不改用户存档。
    end)
    function HudPreviewActors() return adventure:Snapshot().party end
    function PreviewMainHud(mode)
        if mode=='battle' then
            if adventure.data.Phase=='area' then assert(adventure.areas:Leave()) end
            if adventure.data.Phase=='map' then assert(adventure:Visit(eventSite.id));assert(adventure:Choose(1)) end
        elseif mode=='map' then if adventure.data.Phase=='area' then assert(adventure.areas:Leave()) end
        elseif adventure.data.Phase=='map' then assert(adventure:Visit(areaSite.id)) end
        demo.BattleHUDRevision=demo.BattleHUDRevision+1;ui:Tick(0,0)
        if mode=='area' then hud.navigation=false;hud:Refresh() end
    end
end,debug.traceback)
if not ok then CloseHudPreview();error(err,0) end
return 'MainHud integration: '..#messages..' checks passed\n'..table.concat(messages,'\n')
