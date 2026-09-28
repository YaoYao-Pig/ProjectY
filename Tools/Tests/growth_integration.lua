local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Register('Growth',require('Game.Progression.GrowthSystem'),{'Battle'})
registry:Register('PlayerModel',require('Game.PlayerModelSystem'),{'Config'})
registry:Register('AdventureEvents',require('Game.Adventure.EventSystem'),{'Battle','Growth','Equipment','PlayerModel'})
local messages={}
local function test(name,run) run();messages[#messages+1]='PASS '..name end
local ok,err=xpcall(function()
    registry:Start()
    local data=Services.Adventure;data:Reset(217)
    local growth,battle,events=registry:Get('Growth'),registry:Get('Battle'),registry:Get('AdventureEvents')
    for i=1,3 do local a=data:AddPartyActor(i,i);growth:Initialize(a);a:SetMaxHP(battle.stats:MaximumHP(a));a:Restore() end
    local actor=data:GetPartyAt(0)
    test('initial points and passive investments change real combat stats and preserve wounds',function()
        actor:Damage(5);local before=actor.MaxHP
        assert(growth:InvestTalent(1,1));assert(actor.MaxHP==before+4 and actor.MaxHP-actor.HP==5)
        assert(not growth:InvestTalent(1,9))
        assert(growth:InvestAttribute(1,1));assert(actor.MaxHP==before+8 and actor.MaxHP-actor.HP==5)
        local points=actor.Growth.TalentPoints;assert(not growth:InvestTalent(1,999));assert(actor.Growth.TalentPoints==points)
    end)
    test('multiple levels queue persistent offers and one choice consumes exactly one opportunity',function()
        growth:AddExperience(actor,180,'练习场')
        assert(actor.Growth.Level==4 and actor.Growth.PendingCount==2 and actor.Growth.OfferCount>=2)
        local ids={};for i=0,actor.Growth.OfferCount-1 do ids[i+1]=actor.Growth:GetOfferAt(i) end
        growth:PrepareOffers(actor);for i,id in ipairs(ids) do assert(actor.Growth:GetOfferAt(i-1)==id) end
        assert(not growth:Learn(1,999));assert(growth:Learn(1,ids[1]));assert(actor.Growth.PendingCount==1)
        assert(not growth:Learn(1,ids[1]));assert(actor.Growth:HasSkill(ids[1]))
        local found=false;for _,id in ipairs(battle:SkillIds(actor)) do if id==ids[1] then found=true end end;assert(found)
    end)
    test('event context gates options; result applies traits, potential and tree once',function()
        assert(events:Begin({id=9,eventId=6,name='灰烬门廊'}));assert(data.EventActorId==1)
        assert(not growth:InvestTalent(1,2))
        assert(events:CanChoose(8));local points=actor.Growth.TalentPoints
        assert(events:Choose(7));assert(not events:Choose(7))
        assert(not actor:HasTrait(3) and actor:HasTrait(4) and actor:HasTrait(5))
        assert(actor.Growth:HasTree(2) and actor.Growth.LockedPotential==0 and actor.Growth.TalentPoints>=points+2)
        data:Complete('结果');data:ReturnToMap()
        assert(growth:InvestTalent(1,101));assert(growth:InvestTalent(1,102));assert(not growth:InvestTalent(1,104))
        assert(growth:InvestTalent(1,103));assert(growth:InvestTalent(1,104))
    end)
    test('simple discovery auto-resolves to map and never awards twice',function()
        local adventure=require('Game.Adventure.AdventureSystem')();adventure.data=data;adventure.events=events;adventure.growth=growth;adventure.battle=battle
        adventure.sites={{id=1,eventId=5,name='古老路标'}}
        local coins=Services.Player.Coins;assert(adventure:Visit(1));assert(data.Phase=='map' and Services.Player.Coins==coins+6)
        assert(not adventure:Visit(1));assert(Services.Player.Coins==coins+6)
    end)
    test('history records actual participants and freezes its text after later trait changes',function()
        local all=growth.chronicle:Rows(1);assert(#all>4)
        local body=all[1].body;actor:RemoveTrait(5);assert(growth.chronicle:Rows(1)[1].body==body)
        local found=false;for _,row in ipairs(growth.chronicle:Rows(2)) do if row.title=='余烬中的援手' then found=true end end;assert(found)
        for _,row in ipairs(growth.chronicle:Rows()) do assert(not row.body:find('{actor}',1,true)) end
    end)
    test('queued learning opportunities finish one by one after a multi-level reward',function()
        local a=data:GetPartyAt(2);growth:AddExperience(a,10000,'测试')
        local safety=0
        while a.Growth.OfferCount>0 do safety=safety+1;assert(safety<=5);assert(growth:Learn(a.Id,a.Growth:GetOfferAt(0))) end
        assert(a.Growth.PendingCount==0 and a.Growth.Level==growth.rules.maxLevel)
    end)
end,debug.traceback)
registry:Shutdown();if not ok then error(err,0) end
return table.concat(messages,'\n')
