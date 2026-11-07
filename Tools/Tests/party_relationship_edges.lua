-- Focused real C# state and production relationship model; no world initialization or unrelated features.
local config=require('Config.ConfigSystem')();config:OnInit({services=Services})
local data=CS.ProjectY.Data.AdventureData();data:Reset(781)
local actors={}
for i=1,3 do local actor=data:AddPartyActor(i,i);actor:SetMaxHP(100);actor:Restore();actor:Deploy(1,i,0);actors[i]=actor end
local stats={Template=function(_,actor)return {name='Actor '..actor.Id}end,MaximumHP=function()return 100 end}
local signal=require('Core.Signal')(function(message)error(message)end)
local battle={stats=stats,data={Phase='combat',Round=1},Changed=signal,Units=function()return actors end,Relation=function()return 'hostile'end}
local chronicle=require('Game.Progression.Chronicle').New(config,data,stats)
local model=require('Game.Progression.PartyStory').New({data=data,config=config,battle=battle,growth={chronicle=chronicle},sites={},camp={data={IsOpen=false}}})
local reports={}
local function test(name,fn)fn();reports[#reports+1]='PASS '..name end
model:Start()
local ok,result=xpcall(function()
    test('indirect legendary debt is excluded while real same-round damage counts once',function()
        signal:Emit({kind='battle_started'})
        local enemy={Id=99,Team=2}
        local function hit(source,debt)
            signal:Emit({kind='damage',sourceId=source.Id,targetId=99,target=enemy,amount=5,hpBefore=100,hpAfter=95,
                attackHit=true,periodic=false,impact={healthActorId=99,legendaryDebt=debt}})
        end
        hit(actors[1],false);hit(actors[2],true);assert(data.PartyBonds:Score(1,2)==0)
        hit(actors[2],false);assert(data.PartyBonds:Score(1,2)==3)
        hit(actors[2],false);assert(data.PartyBonds:Score(1,2)==3)
        model:Settle('victory','fixture')
    end)
    test('explicit memorial frees a surviving partner without erasing their shared story',function()
        for _=1,2 do
            signal:Emit({kind='battle_started'});data.PartyBonds:TryRescue(1,2,100);model:Settle('victory','fixture')
        end
        battle.data.Phase='idle'
        assert(model:Social(1,2,'romance'))
        actors[2]:Damage(100);CS.ProjectY.Data.DeathDoorState.Kill(actors[2])
        assert(model:StageName(1,2)==require('Language').RelationshipRememberedLove)
        assert(not model:CanSocial(2,1,'friendship'))
        data.Narrative:AdvanceMinutes(1440)
        local count=data.JournalCount;local score=data.PartyBonds:Score(1,2)
        assert(model:Social(1,2,'friendship'))
        assert(not CS.ProjectY.Data.PartyRelationshipState.HasRomance(data.PartyBonds,1))
        assert(data.PartyBonds:Score(1,2)==score and data.JournalCount==count+1)
        assert(data:GetJournalAt(data.JournalCount-1).Title==require('Language').RelationshipRemember)
    end)
    return table.concat(reports,'\n')
end,debug.traceback)
model:Dispose();if not ok then error(result,0)end
return result
