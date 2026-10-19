-- Edit Mode fixture: actual C# actors and UGUI, with a small presentation-only input adapter.
return function(services)
    local registry = require('Core.SystemRegistry')(services)
    registry:Register('Config',require('Config.ConfigSystem'))
    registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
    registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
    registry:Register('UI',require('UI.UISystem'),{'Config','Battle'})
    local ok,result=xpcall(function()
    registry:Start()
    local battle, ui, data = registry:Get('Battle'), registry:Get('UI'), services.Adventure
    data:Reset(123)
    local party = {}
    for i,id in ipairs({1,2,3,6}) do
        local actor = data:AddPartyActor(i,id); actor:SetMaxHP(battle.stats:MaximumHP(actor)); actor:Restore()
        actor.Growth:Initialize(123+i,0,0,0);actor.Growth:GrantSkill(400+i)
        party[#party+1] = actor
    end
    data.Equipment.Grid:Configure(12,10);data.Equipment:AddStack(91,1);data.Equipment:AddStack(92,1)
    data:BeginEvent(1,1); data:ResolveChoice(1); battle:Start(1,party,123); data:BeginBattle()
    local adapter = {SelectedBattleSkill=0,IsBattleMoveSelected=true,BattleAutoAI=true,BattleHUDRevision=0,LastError='',selections=0}
    function adapter:SelectBattleSkill(id) self.SelectedBattleSkill=id;self.IsBattleMoveSelected=false;self.BattleHUDRevision=self.BattleHUDRevision+1;self.selections=self.selections+1 end
    function adapter:SelectBattleMove() self.SelectedBattleSkill=0;self.IsBattleMoveSelected=true;self.BattleHUDRevision=self.BattleHUDRevision+1 end
    function adapter:SetBattleAutoAI(value) self.BattleAutoAI=value;self.BattleHUDRevision=self.BattleHUDRevision+1 end
    function adapter:FocusBattleActor(id) self.focused=id end
    function adapter:FitMap() self.focused=0 end
    function adapter:SendCommand(command,a)
        if command=='end_turn' then assert(battle:EndTurn())
        elseif command=='use_item'then assert(battle:TryItem(a))
        elseif command=='ai' then assert(battle:StepAI()) else error('Unexpected UI command: '..command) end
        self.BattleHUDRevision=self.BattleHUDRevision+1
    end
    local hud = ui:Open('BattleHUD',{demo=adapter})
    return {registry=registry,battle=battle,ui=ui,data=data,adapter=adapter,hud=hud}
    end,debug.traceback)
    if not ok then registry:Shutdown();error(result,0)end
    return result
end
