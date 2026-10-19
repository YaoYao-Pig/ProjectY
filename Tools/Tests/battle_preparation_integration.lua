-- Real C# state and exported rules in an independent Edit Mode LuaEnv; no scene or player save changes.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
local messages={};local function test(name,run)run();messages[#messages+1]='PASS '..name end
local ok,err=xpcall(function()
    registry:Start()
    local battle,equipment=registry:Get('Battle'),registry:Get('Equipment')
    local data=Services.Adventure;data:Reset(123)
    local party={}
    for i,id in ipairs({1,2})do
        local actor=data:AddPartyActor(i,id);actor.Growth:Initialize(123+i,0,0,0);actor.Growth:GrantSkill(400+i)
        actor:SetMaxHP(battle.stats:MaximumHP(actor));actor:Restore();party[i]=actor
    end
    equipment:Start()
    local inventory=data.Equipment
    assert(inventory:CountItem(91)>0 and inventory:CountItem(92)>0,'Demo must supply playable consumables')
    battle:Start(1,party,123)
    local worldRounds=0;battle.board.onRoundCompleted=function()worldRounds=worldRounds+1 end
    local first=battle:Active();local origin={q=first.Q,r=first.R}
    test('real action budget skips an unused move without charging movement AP or creating movement animation',function()
        local actor=CS.ProjectY.Data.CombatActorData(999,1)
        actor:Deploy(1,2,3);actor:SetMaxHP(40);actor:Restore();actor:BeginTurn(4)
        local sequence=actor.MovementSequence
        assert(not pcall(function()actor:SpendAction('main',5)end))
        assert(not pcall(function()actor:SpendAction('invalid',1)end))
        assert(actor.AP==4 and not actor.Moved and not actor.MainUsed)
        actor:SpendAction('secondary',1)
        assert(actor.Moved and not actor.MainUsed and actor.AP==3 and actor.Q==2 and actor.R==3 and actor.MovementSequence==sequence)
        assert(not pcall(function()actor:Move(3,3,1)end) and actor.AP==3)
        actor:SpendAction('main',2);assert(actor.MainUsed and actor.AP==1)
        actor:BeginTurn(4);assert(not actor.Moved and not actor.MainUsed)
        actor:SpendAction('main',2);assert(actor.Moved and actor.MainUsed and actor.AP==2 and actor.MovementSequence==sequence)
        actor:BeginDeploymentTurn(4);assert(not actor.Moved and not actor.MainUsed)
        actor:Move(3,3,1);actor:SpendAction('main',2)
        assert(actor.AP==1 and actor.Q==3 and actor.R==3 and actor.MovementSequence==sequence+1)
    end)
    test('real battle starts with one bounded deployment round and only player actors',function()
        assert(battle.data.Phase=='deployment'and battle.data.Round==0 and battle.data.TurnCount==2 and first.Id==2)
        for i=0,battle.data.TurnCount-1 do assert(battle:FindUnit(battle.data:GetTurnAt(i)).Team==1)end
        for _,actor in ipairs(battle:Units())do if actor.Team==2 then assert(actor.AP==0)end end
        assert(not battle:StepAI())
        local ap=first.AP;assert(not battle:TrySkill(2,101)and first.AP==ap)
        local Hex=require('Game.Map.HexGrid')
        for _,cell in ipairs(battle:Reachable())do assert(Hex.Distance(origin.q,origin.r,cell.q,cell.r)<=2)end
    end)
    test('full health and invalid items do not spend inventory or AP',function()
        local count,ap,revision=inventory:CountItem(91),first.AP,inventory.Revision
        assert(not battle:TryItem(91));assert(not battle:TryItem(1))
        assert(first.AP==ap and inventory:CountItem(91)==count and inventory.Revision==revision)
        assert(not first.Moved and #battle:Reachable()>0,'Rejected actions must preserve the unused movement')
        local success=pcall(function()inventory:ConsumeStack(91,count+1)end)
        assert(not success and inventory:CountItem(91)==count and inventory.Revision==revision)
    end)
    test('preparation skill and item transactions share AP and preserve inventory ownership',function()
        first:Damage(20);local hp=first.HP;local count=inventory:CountItem(91)
        local sequence=first.MovementSequence
        assert(battle:TrySkill(402,first.Id));assert(first.MainUsed and first.AP==2 and first.Effects:Find(402))
        assert(first.Moved and #battle:Reachable()==0 and not battle:TryMove(origin.q+1,origin.r))
        assert(first.Q==origin.q and first.R==origin.r and first.MovementSequence==sequence,'Acting in place must not animate a move')
        assert(not battle:TrySkill(402,first.Id));assert(not battle:TrySkill(701,first.Id))
        assert(battle:TryItem(91));assert(first.HP==hp+12 and first.AP==1 and inventory:CountItem(91)==count-1)
        assert(battle:TryItem(92));assert(first.AP==0 and first.Effects:Find(702))
        count=inventory:CountItem(91);assert(not battle:TryItem(91));assert(inventory:CountItem(91)==count)
        assert(not first.Growth:HasSkill(701)and not first.Growth:HasSkill(702))
    end)
    test('remaining allies can deploy while previous preparation remains and time stays frozen',function()
        assert(battle:EndTurn());assert(battle:Active().Id==1 and battle.data.Phase=='deployment')
        assert(first.Effects:Find(402).Remaining==1 and first.Effects:Find(702).Remaining==2 and worldRounds==0)
        local actor=battle:Active();local cell=battle:Reachable()[1];assert(cell)
        assert(battle:TryMove(cell.q,cell.r));assert(actor.Moved and actor.AP==3)
        assert(#battle:Reachable()==0 and not battle:TryMove(origin.q,origin.r))
        assert(battle:TrySkill(401,actor.Id));assert(actor.AP==1)
        assert(battle:EndTurn())
    end)
    test('formal round one refills budgets, preserves preparation until own turn end and excludes preparation skills',function()
        assert(battle.data.Phase=='combat'and battle.data.Round==1 and battle:Active().Id==first.Id and worldRounds==0)
        assert(first.AP==4 and not first.MainUsed and not first.Moved)
        assert(first.Effects:Find(402)and first.Effects:Find(702))
        assert(not battle:TrySkill(402,first.Id))
        assert(not first.Moved,'Unavailable preparation skills cannot skip formal combat movement')
        assert(battle:TryItem(91));assert(first.Moved and not first.MainUsed and first.AP==3 and #battle:Reachable()==0)
        assert(battle:EndTurn());assert(not first.Effects:Find(402)and first.Effects:Find(702).Remaining==1)
        while battle.data.Round==1 do assert(battle:EndTurn())end
        assert(worldRounds==1)
    end)
    test('depletion frees the grid cell and victory clears only battle effects',function()
        local count=inventory:CountItem(91);assert(count>0)
        inventory:ConsumeStack(91,count);assert(inventory:CountItem(91)==0 and inventory.Grid:Find('s91')==nil)
        for _,actor in ipairs(battle:Units())do if actor.Team==2 then actor:Damage(actor.HP)end end
        assert(battle:CheckWinner()and battle.data.Phase=='ended'and battle.data.Winner=='victory')
        for _,actor in ipairs(party)do assert(actor.Effects.Count==0)end
        assert(not battle:TryItem(92))
    end)
end,debug.traceback)
registry:Shutdown();if not ok then error(err,0)end
return table.concat(messages,'\n')
