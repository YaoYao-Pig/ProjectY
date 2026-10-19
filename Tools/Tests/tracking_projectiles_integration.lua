-- Real C# actors/equipment and exported configuration; isolated Edit Mode LuaEnv only.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
local results={};local function test(name,run)run();results[#results+1]='PASS '..name end
local ok,err=xpcall(function()
    registry:Start()
    local battle,equipment=registry:Get('Battle'),registry:Get('Equipment')
    local data=Services.Adventure;data:Reset(20261018);equipment:Start()
    local source=data:AddPartyActor(1,3);local ally=data:AddPartyActor(2,1)
    local enemies={CS.ProjectY.Data.CombatActorData(101,4),CS.ProjectY.Data.CombatActorData(102,4),CS.ProjectY.Data.CombatActorData(103,4)}
    local units={source,ally,enemies[1],enemies[2],enemies[3]}
    for _,actor in ipairs(units)do actor.Growth:Initialize(actor.Id,0,0,0) end
    local inventory=equipment.data;local staff=inventory:AddWeapon(1);assert(inventory:Equip(source.Id,staff.Id))
    inventory:AddStack(721,1);inventory:AddStack(11,1)
    local Layout=require('Game.MapArea.MapAreaLayout');local Board=require('Game.Battle.BattleBoard')
    local area=Layout.New({id=999,name='Shot acceptance',areaType=1,width=12,height=12,hexRadius=1,visionRadius=9,moveStepSeconds=.1},1,{}, {wallHeight=3})
    for _,cell in ipairs(area.cells)do cell.height=0;cell.blocked=false;cell.blocksSight=false;cell.kind='floor' end
    battle.board=Board.FromArea(area,4,4,8)
    battle.data:Reset(1,20)
    local positions={{2,4},{4,4},{5,4},{2,7},{4,5}}
    for i,actor in ipairs(units)do
        actor:SetMaxHP(battle.stats:MaximumHP(actor));actor:Restore()
        battle.data:AddUnit(actor,i<=2 and 1 or 2,positions[i][1],positions[i][2])
    end
    battle.data:BeginDeployment();battle.data:BeginRound();battle.data:AddTurn(source.Id);battle.data:SelectTurn(0)
    local function turn()
        source:BeginTurn(8);source:SetCooldown(6,0)
        for _,actor in ipairs(units)do actor:Restore() end
    end
    local function seedFor(predicate)
        local probe=CS.ProjectY.Data.BattleData()
        for seed=1,10000 do
            probe:SetRandomSeed(seed)
            if predicate(probe:RollPercent(),probe:RollPercent())then battle.data:SetRandomSeed(seed);return end
        end
        error('No deterministic roll fixture')
    end
    test('real tracking cast costs one secondary AP and keeps the main attack available',function()
        turn();assert(not battle:CanUseSkill(1624,ally.Id))
        assert(battle:TrySkill(1624,source.Id))
        assert(source.AP==7 and not source.MainUsed and source.Effects:Find(10105).Remaining==3)
        assert(battle:CanUseSkill(6,enemies[1].Id) and battle:Skill(source,6).guided)
    end)
    test('installed transfer rune applies the same self spell to allies and enemies with recipient-owned timers',function()
        assert(inventory:SetRune(staff.Id,2,721));turn()
        local skill=battle:Skill(source,1624);assert(skill.target=='any' and skill.range==4 and skill.cost==1)
        assert(battle:TrySkill(1624,ally.Id));assert(battle:TrySkill(1624,enemies[1].Id))
        assert(ally.Effects:Find(10105).Remaining==3 and enemies[1].Effects:Find(10105).Remaining==3 and source.AP==6)
        battle.gameEffects:TickActor(ally,'turn_end')
        assert(ally.Effects:Find(10105).Remaining==2 and enemies[1].Effects:Find(10105).Remaining==3)
        assert(battle:Skill(source,9).target=='self','Reload must never transfer')
    end)
    test('manual scatter validates the entire list atomically and damages only chosen distinct targets',function()
        assert(inventory:SetRune(staff.Id,1,11));turn()
        local skill=battle:Skill(source,6);assert(skill.manualTargets and skill.maxTargets==3)
        local ap,first,second,third=source.AP,enemies[1].HP,enemies[2].HP,enemies[3].HP
        assert(not battle:TrySkillTargets(6,{}));assert(not battle:TrySkillTargets(6,{101,101}))
        assert(not battle:TrySkillTargets(6,{101,99999}));assert(not battle:TrySkillTargets(6,{101,102,103,101}))
        assert(source.AP==ap and enemies[1].HP==first and not source.Moved)
        seedFor(function(a,b)return a<skill.hitChance and b<skill.hitChance end)
        assert(battle:TrySkillTargets(6,{101,102}))
        assert(source.AP==ap-skill.cost and source.MainUsed and source.Moved)
        assert(enemies[1].HP<first and enemies[2].HP<second and enemies[3].HP==third)
        assert(source:GetCooldown(6)==skill.cooldownTurns)
    end)
    test('blocked shots remain available and a real friendly interceptor receives the whole projectile',function()
        assert(inventory:SetRune(staff.Id,1,0));battle.gameEffects:Clear(source,'battle_end');turn()
        local skill=battle:Skill(source,6);local preview=battle:ShotPreview(source,enemies[1],skill)
        assert(preview.blockerCount==1 and preview.friendlyRisk and preview.interceptChance==35)
        assert(math.abs(preview.hitChance-skill.hitChance*.65)<.001 and battle:CanUseSkill(6,101))
        local hp,friendHP,ap=enemies[1].HP,ally.HP,source.AP
        seedFor(function(first)return first<35 end)
        assert(battle:TrySkill(6,101))
        assert(enemies[1].HP==hp and ally.HP<friendHP and source.AP==ap-skill.cost)
    end)
    test('tracking removes cover rolls without granting automatic accuracy',function()
        turn();assert(battle.gameEffects:Apply(1361,source,source))
        local skill=battle:Skill(source,6);local preview=battle:ShotPreview(source,enemies[1],skill)
        assert(skill.guided and preview.blockerCount==0 and preview.interceptChance==0 and preview.hitChance==skill.hitChance)
        local hp,friendHP=enemies[1].HP,ally.HP
        assert(skill.hitChance<100,'Fixture needs an ordinary miss chance')
        seedFor(function(first)return first>=skill.hitChance end)
        assert(battle:TrySkill(6,101));assert(enemies[1].HP==hp and ally.HP==friendHP)
        turn();seedFor(function(first)return first<skill.hitChance end)
        assert(battle:TrySkill(6,101));assert(enemies[1].HP<hp and ally.HP==friendHP)
    end)
    test('tracking expires after exactly three recipient turn ends',function()
        local effect=source.Effects:Find(10105);assert(effect and effect.Remaining==3)
        for i=1,2 do battle.gameEffects:TickActor(source,'turn_end');assert(source.Effects:Find(10105).Remaining==3-i) end
        battle.gameEffects:TickActor(source,'turn_end')
        assert(not source.Effects:Find(10105) and not battle:Skill(source,6).guided)
    end)
end,debug.traceback)
registry:Shutdown();if not ok then error(err,0)end
return table.concat(results,'\n')
