-- 既有正式战斗回归先走完真实部署流程；部署自身由专项测试验收。
return function(battle)
    if battle.data.Phase=='idle' then battle:BeginDeployment() end
    for _=1,4 do
        if battle.data.Phase~='deployment' then break end
        assert(battle:EndTurn())
    end
    assert(battle.data.Phase=='combat' or battle.data.Winner~='','Deployment did not finish within party size')
end
