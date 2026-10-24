-- Real event resolution, StoryEvent controller and UI synchronization; isolated Data/view adapters.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=f:read('*a');f:close();return bytes
end}})
local actor={Id=1,HP=100,HasTrait=function()return false end,SetMaxHP=function()end}
local visited={};local data={Phase='map',PartyCount=1,EventReturnPhase='map',Areas={ActiveSiteId=0},records=0}
function data:GetPartyAt()return actor end
function data:HasVisited(id)return visited[id]==true end
function data:BeginEvent(site,event)assert(self.Phase=='map');self.Phase='event';self.SiteId=site;self.EventId=event end
function data:SetEventContext(id,location)self.EventActorId=id;self.EventLocation=location end
function data:ResolveChoice(id)assert(self.Phase=='event');self.Phase='resolving';self.ChoiceId=id;visited[self.SiteId]=true end
function data:Complete(text)assert(self.Phase=='resolving');self.Phase='result';self.ResultText=text end
function data:ReturnToMap()assert(self.Phase=='result');self.Phase='map' end
function data:Record()self.records=self.records+1 end
local player={Coins=0}
function player:TrySpendCoins(amount)if self.Coins<amount then return false end;self.Coins=self.Coins-amount;return true end
function player:AddCoins(amount)self.Coins=self.Coins+amount end
local experience=0;local stats={Get=function()return 10 end,MaximumHP=function()return 100 end,Template=function()return {name='测试队员'}end}
stats.traits=config:GetTable('CombatTraitTable')
local events=require('Game.Adventure.EventSystem')()
events.data=data;events.player=player;events.stats=stats;events.events=config:GetTable('AdventureEventTable');events.choices=config:GetTable('AdventureChoiceTable')
events.growth={Actor=function()return actor end,AddExperience=function(_,_,amount)experience=experience+amount end}
events.chronicle=require('Game.Progression.Chronicle').New(config,data,stats)
local adventure=require('Game.Adventure.AdventureSystem')()
adventure.data=data;adventure.events=events;adventure.battle={stats=stats}
adventure.specialEvents={CanEnter=function()return true end,CanChoose=function()return true end,
    Choose=function()return false end,ShouldLeave=function()return false end}
events.specialEvents=adventure.specialEvents
adventure.factions={conflicts={EnterSite=function()return false end}}
adventure.parties={data={IsOpen=false}}
adventure.camp={data={IsOpen=false}};adventure.shop={data={IsOpen=false}}
adventure.areas={AreaId=function()return nil end}
adventure.sites={{id=1,eventId=5,name='石缝里的路标',travelStop=true},{id=2,eventId=6,name='余烬中的援手',travelStop=true}}
local fields={Style={Prepare=function()end,SetArt=function()end},Title={},Caption={},Description={},ContinueText={},Hint={},Illustration={},Choices={}}
local click
fields.Continue={gameObject={SetActive=function(_,value)fields.continueVisible=value end},
    onClick={AddListener=function(_,callback)click=callback end,RemoveListener=function()end}}
local demo={BattleHUDRevision=1,LastError=''}
function demo:SetStoryOpen(value)self.storyOpen=value end
local ui={opened={MainHud=true},opens=0,closes=0};local ctrl
local main={Get=function(_,name)
    if name=='UI' then return ui elseif name=='Adventure' then return adventure
    elseif name=='Narrative' then return {data={DialogueOpen=false}}
    elseif name=='Equipment' then return {worldLoot={session={Active=false,Pending=false}}} end
    error('Unexpected UI dependency: '..name)
end}
package.loaded.Main=main
local bridge=assert(loadfile('Lua/UI/AdventureUIBridge.lua'))()
function ui:IsOpen(name)return self.opened[name]==true end
function ui:Open(name,args)
    assert(name=='StoryEvent');self.opened[name]=true;self.opens=self.opens+1
    if not ctrl then
        ctrl=require('UI.Panel.StoryEventCtr')({systems=main,log=function(error)assert(false,error)end},{Get=function(_,key)return assert(fields[key],key)end})
        function ctrl:CreateWidget()
            return {SetData=function(widget,row,_,action)widget.row=row;widget.action=action end}
        end
        ctrl:Bind()
    end
    ctrl:OnShow(args)
end
function ui:Close(name)assert(name=='StoryEvent');self.opened[name]=false;self.closes=self.closes+1;ctrl:OnHide()end
function demo:SendCommand(command)
    assert(command=='return');assert(adventure:ReturnToMap());self.BattleHUDRevision=self.BattleHUDRevision+1;bridge('sync',self)
end

assert(adventure:EnterSite(1))
assert(data.Phase=='result','Simple event result must survive until the next presentation poll')
assert(player.Coins==6 and experience==25 and data.records==1)
bridge('sync',demo)
assert(ui:IsOpen('StoryEvent') and demo.storyOpen and fields.continueVisible)
assert(fields.Title.text=='石缝里的路标' and fields.Description.text:find('25 经验与 6 金币',1,true))
assert(fields.ContinueText.text=='返回旅途' and #ctrl.pools.Choices==0)
bridge('sync',demo);bridge('sync',demo)
assert(ui.opens==1 and player.Coins==6 and experience==25,'Repeated UI polls must not repeat event resolution/rewards')
click()
assert(data.Phase=='map' and not ui:IsOpen('StoryEvent') and not demo.storyOpen and ui.closes==1)
assert(not adventure:EnterSite(1) and player.Coins==6,'Completed one-time event must not reward twice')
print('PASS simple travel event keeps a visible result until confirmation, rewards once and closes cleanly')

assert(adventure:EnterSite(2) and data.Phase=='event')
bridge('sync',demo)
assert(ui:IsOpen('StoryEvent') and not fields.continueVisible and #ctrl.pools.Choices==3)
assert(ctrl.pools.Choices[1].row.title=='握住同伴的手' and ctrl.pools.Choices[3].row.title=='离开此地')
assert(adventure:Choose(3) and data.Phase=='result')
demo.BattleHUDRevision=demo.BattleHUDRevision+1;ctrl:Tick();bridge('sync',demo)
assert(fields.continueVisible and ui.opens==2 and ctrl.pools.Choices[1].row==nil)
click();assert(data.Phase=='map' and ui.closes==2)
print('PASS choice event still opens options, refreshes to result and returns through the same panel')
-- New puzzle choices keep their outcome secret without hiding a failed cost requirement.
events.equipment={CanGrant=function()return true end,rules={items=config:GetTable('EquipmentItemTable')}}
events.effectDefinitions=config:GetTable('CombatEffectTable')
adventure.sites[3]={id=3,eventId=212,name='三枚影子的机关',travelStop=true}
assert(adventure:EnterSite(3));bridge('sync',demo)
assert(#ctrl.pools.Choices==4 and ctrl.pools.Choices[1].row.body=='' and ctrl.pools.Choices[2].row.body=='','Puzzle rewards must not reveal the correct solution')
assert(not ctrl.pools.Choices[3].row.available and ctrl.pools.Choices[3].row.body:find('金币不足'),'Hidden rewards must not hide the reason a choice is unavailable')
assert(adventure:Choose(2124));demo.BattleHUDRevision=demo.BattleHUDRevision+1;ctrl:Tick();click()
assert(data.Phase=='map' and not ui:IsOpen('StoryEvent'),'Expanded four-choice event must retain its free exit')
print('PASS four-choice puzzle hides spoilers, retains cost feedback and exits through the existing result UI')
config:OnShutdown()
