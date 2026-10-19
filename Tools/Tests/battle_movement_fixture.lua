-- Scalar C# movement bridge substitute for existing offline battle fixtures.
-- Native movement bookkeeping is independently checked against Assembly-CSharp.dll.
CS=CS or {};CS.ProjectY=CS.ProjectY or {};CS.ProjectY.Data=CS.ProjectY.Data or {}
CS.ProjectY.Data.BattleMovement={
    Spent=function(actor)return actor.movementSpent or 0 end,
    Remaining=function(actor,range)return (actor.HP==0 or actor.Moved) and 0 or math.max(0,range-(actor.movementSpent or 0))end,
    Move=function(actor,q,r,moveAP,pathCost,range)
        local spent=actor.movementSpent or 0;local cost=spent==0 and moveAP or 0
        assert(actor.HP>0 and not actor.Moved and pathCost>0 and spent+pathCost<=range and actor.AP>=cost)
        actor.Q=q;actor.R=r;actor.AP=actor.AP-cost;actor.movementSpent=spent+pathCost;actor.Moved=actor.movementSpent==range
    end,
}
