-- Production duel, exploration-service and real area-board queries; isolate only native mutable state.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local Hex=require('Game.Map.HexGrid')
local Layout=require('Game.MapArea.MapAreaLayout')
local Exploration=require('Game.Adventure.ProfessionExploration')
local Duels=require('Game.Adventure.ProfessionDuels')
local function actor(id,template)
    local result={Id=id,TemplateId=template,Team=1,Q=4,R=4,HP=100,MaxHP=100,injuries={leg=9},Effects={Count=0}}
    function result:Deploy(team,q,r)self.Team=team;self.Q=q;self.R=r end
    function result:SetMaxHP(value)self.MaxHP=value end
    function result:Restore()self.HP=self.MaxHP end
    return result
end
local bridge={Active=function(data)return data.duelActor~=nil and data.Phase=='battle'end,ActorId=function(data)return data.duelActor end,
    Begin=function(data,id,threshold)assert(data.Phase=='area'and not data.duelActor);data.duelActor=id;data.threshold=threshold;data.Phase='battle';data.Areas.Active:Stop()end,
    Finish=function(data,message)assert(data.Phase=='battle'and data.Battle.Winner~='');data.duelActor=nil;data.threshold=nil;data.Phase='area';data.result=message;data.Battle.Winner='';data.Battle.units={}end}
CS={ProjectY={Data={ProfessionDuelState=bridge,CombatActorData=actor,
    EquipmentCombatState={RemoveActor=function(data,id)assert(data.enemies[id]);data.enemies[id]=nil;data.removed[#data.removed+1]=id end}}}}
local function fixture()
    local owner,friend=actor(1,1),actor(2,2);friend.Q=3;friend.R=4
    local area=Layout.New({id=1,name='Test guild town',areaType=2,width=9,height=9,hexRadius=1,visionRadius=9,moveStepSeconds=.1},1,{}, {})
    for _,cell in ipairs(area.cells)do cell.blocked=false;cell.height=0;cell.blocksSight=false;cell.kind='floor'end
    local entry=area:Find(5,4);area.facilities={{kind='guild',name='Real guild',entryIndex=entry.index}}
    local ids={owner.Id,friend.Id};local cellIds={area:Find(owner.Q,owner.R).index,area:Find(friend.Q,friend.R).index}
    local known={};for _,cell in ipairs(area.cells)do known[cell.index]=true end
    local active={MemberCount=2,VisibleCount=#area.cells,stops=0,
        GetMemberIdAt=function(_,i)return ids[i+1]end,GetMemberCellAt=function(_,i)return cellIds[i+1]end,
        GetVisibleAt=function(_,i)return i+1 end,IsKnown=function(_,index)return known[index]==true end,
        Stop=function(self)self.stops=self.stops+1 end,
        DeployMembers=function(_,newIds,newCells)ids={table.unpack(newIds)};cellIds={table.unpack(newCells)}end}
    local facts={};local narrative={Minutes=1500,GetValue=function(_,key)return facts[key]or 0 end,SetValue=function(_,key,value)facts[key]=value end}
    local data={Phase='area',Seed=123,Areas={Active=active,ActiveSiteId=7},Narrative=narrative,PartyCount=2,
        GetPartyAt=function(_,i)return i==0 and owner or friend end,Battle={Winner='',units={}}}
    local equipment={enemies={},removed={}}
    local logs={};local adventure={config=config,data=data,equipment={data=equipment},
        areas={ActiveLayout=function()return area end,RevealSquad=function()logs.revealed=true end},
        factions={ServiceAllowed=function()return not logs.serviceClosed,'closed'end},
        player={Coins=100,TrySpendCoins=function(self,n)if self.Coins<n then return false end;self.Coins=self.Coins-n;return true end,AddCoins=function(self,n)self.Coins=self.Coins+n end},
        characterSkills={Actor=function(_,id)return id==owner.Id and owner or id==friend.Id and friend or nil end},
        partyStory={Reset=function()logs.partyReset=(logs.partyReset or 0)+1 end},
        growth={chronicle={Record=function(_,kind,subject,title,message,location)logs[#logs+1]={kind=kind,subject=subject,title=title,message=message,location=location}end}}}
    function adventure.equipment:InitializeEnemy(enemy)assert(not equipment.enemies[enemy.Id]);equipment.enemies[enemy.Id]=enemy end
    local battle={data=data.Battle,stats={MaximumHP=function()return 80 end},
        appearances={Group=function(_,pool,seed)assert(pool>0 and seed>=0);return {pool=pool}end,Assign=function(_,enemy,pool)enemy.appearance=pool end},
        beasts={AreaOccupied=function(_,_,exclude)
            local result={};if not exclude[friend.Id]then result[Hex.Key(friend.Q,friend.R)]=friend end
            for key,value in pairs(logs.occupied or {})do result[key]=value end;return result
        end}}
    function battle:StartArea(id,board,allies,enemies)
        assert(id==1801 and #allies==1 and allies[1].actor==owner and #enemies==1,'A duel must deploy exactly its challenger and one opponent')
        assert(bridge.Active(data),'Duel authority must be active before battle start')
        self.board=board;self.data.units={owner,enemies[1]};logs.started={allies=allies,enemies=enemies,board=board}
    end
    function battle:Units()return self.data.units end
    function battle.data:AddLog(message)logs.startMessage=message end
    adventure.battle=battle;adventure.professionExploration=Exploration.New(adventure)
    local handlers={};Duels.Register({Register=function(_,key,handler)handlers[key]=handler end},adventure)
    return {adventure=adventure,duel=adventure.professionDuels,owner=owner,friend=friend,area=area,active=active,known=known,facts=facts,
        data=data,logs=logs,equipment=equipment,handlers=handlers,cells=function()return cellIds end}
end
local function test(name,run)local ok,err=pcall(run);assert(ok,name..': '..tostring(err));print('PASS '..name)end
test('duel eligibility checks actual nearby guild, deposit, health, own target, phase and mounted state',function()
    local e=fixture();assert(e.duel:CanUse(e.owner,e.owner.Id))
    e.adventure.player.Coins=14;assert(not e.duel:Use(e.owner,e.owner.Id));assert(not e.logs.started and next(e.equipment.enemies)==nil)
    e.adventure.player.Coins=100;e.owner.MountedAnimal={};assert(not e.duel:CanUse(e.owner,e.owner.Id));e.owner.MountedAnimal=nil
    e.owner.HP=25;assert(not e.duel:CanUse(e.owner,e.owner.Id));e.owner.HP=100
    assert(not e.duel:CanUse(e.owner,e.friend.Id));e.data.Phase='map';assert(not e.duel:CanUse(e.owner,e.owner.Id));e.data.Phase='area'
    e.logs.serviceClosed=true;assert(not e.duel:CanUse(e.owner,e.owner.Id));e.logs.serviceClosed=false
    e.area.facilities[1].kind='tavern';assert(not e.duel:CanUse(e.owner,e.owner.Id));e.area.facilities[1].kind='guild'
    e.area.facilities[1].entryIndex=e.area:Find(0,0).index;assert(not e.duel:CanUse(e.owner,e.owner.Id))
    assert(e.adventure.player.Coins==100 and next(e.facts)==nil,'Rejected challenges never debit money or use the daily attempt')
end)
test('duel plan uses known connected original ground cells and excludes occupied or upstairs cells',function()
    local e=fixture();local upper=e.area:AddLayerCell(4,4,1,3)
    local plan=assert(e.duel:Plan(e.owner));assert(plan.board.area==e.area and plan.origin==e.area:Find(4,4))
    assert(plan.target==e.area.cells[plan.target.index]and plan.target.layer==0 and plan.target~=upper)
    assert(plan.target.index~=e.cells()[2]and Hex.Distance(4,4,plan.target.q,plan.target.r)>=2)
    for _,cell in ipairs(plan.board.cells)do assert(cell.layer==0)end
    for _,cell in ipairs(e.area.cells)do if Hex.Distance(4,4,cell.q,cell.r)>=2 then e.known[cell.index]=false end end
    assert(not e.duel:Plan(e.owner),'Unknown cells cannot supply the opponent landing')
    assert(not e.duel:Use(e.owner,e.owner.Id)and e.adventure.player.Coins==100 and not e.logs.started)
end)
test('victory refunds deposit and rewards once, preserves wounds and restores squad exploration positions',function()
    local e=fixture();local originalInjury=e.owner.injuries;local friendCell=e.cells()[2]
    assert(e.duel:Use(e.owner,e.owner.Id));assert(e.adventure.player.Coins==85 and e.data.Phase=='battle'and bridge.Active(e.data))
    assert(#e.logs.started.allies==1 and e.logs.started.allies[1].actor==e.owner)
    local enemy=e.logs.started.enemies[1];assert(enemy.HP==80 and enemy.Team==2 and e.equipment.enemies[enemy.Id]==enemy)
    assert(e.facts['flag:profession_duel_day_7']==2)
    e.owner.HP=62;e.owner.Q=4;e.owner.R=5;e.data.Battle.Winner='victory'
    assert(e.duel:Settle('victory'));assert(e.adventure.player.Coins==130 and e.data.Phase=='area'and not bridge.Active(e.data))
    assert(e.owner.HP==62 and e.owner.injuries==originalInjury,'Duel settlement must not heal real wounds')
    assert(e.cells()[1]==e.area:Find(4,5).index and e.cells()[2]==friendCell and e.adventure.battle.board==nil)
    assert(e.equipment.removed[1]==enemy.Id and next(e.equipment.enemies)==nil and e.logs.partyReset==1 and e.logs.revealed)
    assert(#e.logs==1 and e.logs[1].kind=='event'and e.logs[1].subject==e.owner)
    assert(not e.duel:Settle('victory')and e.adventure.player.Coins==130,'Already consumed settlement must not reward again')
end)
test('defeat consumes the guarantee, daily limit persists and another day unlocks the same guild',function()
    local e=fixture();assert(e.duel:Use(e.owner,e.owner.Id));e.owner.HP=25;e.data.Battle.Winner='defeat'
    assert(e.duel:Settle('defeat'));assert(e.adventure.player.Coins==85 and e.data.Phase=='area'and #e.equipment.removed==1)
    e.owner.HP=100;assert(not e.duel:Use(e.owner,e.owner.Id));assert(e.adventure.player.Coins==85)
    e.data.Narrative.Minutes=e.data.Narrative.Minutes+1440;assert(e.duel:CanUse(e.owner,e.owner.Id))
end)
test('registered life action exposes only the selected challenger and idle settlement is inert',function()
    local e=fixture();local group=config:GetTable('CombatSkillTable'):Get(1846).skillGroup;local handler=assert(e.handlers[group])
    local targets=handler.Targets(e.owner);assert(#targets==1 and targets[1]==e.owner.Id)
    assert(handler.CanUse(e.owner,e.owner.Id));assert(not e.duel:Settle('victory'))
    assert(e.adventure.player.Coins==100 and #e.equipment.removed==0 and #e.logs==0)
end)
print('PASS five duel lifecycle scenarios with real Lua plan/service/board logic and isolated native data; HP surrender threshold is verified by separate native checks')
