-- Edit Mode fixture: actual C# actors and UGUI, with a small presentation-only input adapter.
return function(services)
    local registry = require('Core.SystemRegistry')(services)
    registry:Register('Config',require('Config.ConfigSystem'))
    registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
    registry:Register('UI',require('UI.UISystem'),{'Config','Battle'})
    registry:Start()
    local battle, ui, data = registry:Get('Battle'), registry:Get('UI'), services.Adventure
    data:Reset(123)
    local party = {}
    for i,id in ipairs({1,2,3,6}) do
        local actor = data:AddPartyActor(i,id); actor:SetMaxHP(battle.stats:MaximumHP(actor)); actor:Restore()
        party[#party+1] = actor
    end
    data:BeginEvent(1,1); data:ResolveChoice(1); battle:Start(1,party,123); data:BeginBattle()
    local adapter = {SelectedBattleSkill=0,IsBattleMoveSelected=true,BattleAutoAI=true,BattleHUDRevision=0,LastError='',selections=0}
    function adapter:SelectBattleSkill(id) self.SelectedBattleSkill=id;self.IsBattleMoveSelected=false;self.BattleHUDRevision=self.BattleHUDRevision+1;self.selections=self.selections+1 end
    function adapter:SelectBattleMove() self.SelectedBattleSkill=0;self.IsBattleMoveSelected=true;self.BattleHUDRevision=self.BattleHUDRevision+1 end
    function adapter:SetBattleAutoAI(value) self.BattleAutoAI=value;self.BattleHUDRevision=self.BattleHUDRevision+1 end
    function adapter:FocusBattleActor(id) self.focused=id end
    function adapter:FitMap() self.focused=0 end
    function adapter:SendCommand(command)
        if command=='end_turn' then assert(battle:EndTurn())
        elseif command=='ai' then assert(battle:StepAI()) else error('Unexpected UI command: '..command) end
        self.BattleHUDRevision=self.BattleHUDRevision+1
    end
    local hud = ui:Open('BattleHUD',{demo=adapter})
    return {registry=registry,battle=battle,ui=ui,data=data,adapter=adapter,hud=hud}
end
