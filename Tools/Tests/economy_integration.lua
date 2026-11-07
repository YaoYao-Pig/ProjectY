local registry=require('Main');local a=registry:Get('Adventure');local story=registry:Get('Narrative');local ui=registry:Get('UI')
a:Start(20261029,1,4000);a.player:AddCoins(5000)
local model=a.economy;assert(model.data.TownCount>0 and model:Summary().food==model.rule.starterFood)
local _,food,wages=model:Needs();assert(wages[1]==0 and food[1]>0)
local before=model:Summary();local coins=a.player.Coins
story:AdvanceMinutes(1440-story.data.Minutes)
assert(model:Summary().food==before.food-before.dailyFood and a.player.Coins==coins-before.dailyWages)
local used=model:Summary().food;story:TickBuffs();assert(model:Summary().food==used,'Repeated clock callback charged twice')
for i=1,76 do story:AdvanceMinutes(360) end
local site=model.data:GetTownAt(0).SiteId;assert(a:EnterSite(site))
local layout,state=a.areas:ActiveLayout(),a.data.Areas.Active
local bank;for _,f in ipairs(layout.facilities) do if f.kind=='bank' then bank=f end end;assert(bank)
assert(not model:OpenBank(bank.id),'Bank opened from town entrance')
local ids={};for i=0,a.data.PartyCount-1 do ids[#ids+1]=a.data:GetPartyAt(i).Id end
local function approach(index)
    local cells=require('Game.MapArea.SquadMovement').Deploy(layout,index,#ids,function(cell)return not state:IsNpcOccupied(cell.index) end)
    state:Stop();state:DeployMembers(ids,cells)
end
approach(bank.entryIndex);assert(a:AreaCommand('area_interact',1,bank.id));assert(model.data.ActiveBankSite==site)
assert(not a:AreaCommand('area_leave'),'Left town with an open bank')
local demo={MainHudFont=BankFont,LastError='',BattleHUDRevision=0}
function demo:SetStoryOpen(value)self.storyOpen=value end
function demo:SendCommand(command,id,version,count)
    local ok,reason=model:Command(command,id,version,count);self.LastError=ok and '' or reason;self.BattleHUDRevision=self.BattleHUDRevision+1
    if model.data.ActiveBankSite==0 then ui:Close('Bank') end
end
ui:Open('Bank',{demo=demo});local ctrl=ui.panels.Bank.ctrl
assert(Services.UI.IsWorldPaused and ctrl.view.Chart.Count>1 and ctrl.view.InvestSmall.interactable)
local time=story.data.Minutes;story:Tick(3);assert(story.data.Minutes==time,'Bank did not pause time')
local principalCoins=a.player.Coins;ctrl.view.InvestSmall.onClick:Invoke();ctrl:Tick()
assert(demo.LastError=='' and a.player.Coins==principalCoins-100 and model.data:FindTown(site).Principal==100)
assert(not ctrl.view.InvestSmall.interactable and ctrl.view.Risk.text:find('30%%'))
ctrl.view.Range.onClick:Invoke();assert(ctrl.range==60);ctrl.view.Range.onClick:Invoke();assert(ctrl.range==15 and ctrl.view.Chart.Count<=15)
ctrl.view.Range.onClick:Invoke();assert(ctrl.range==30)
CaptureBank(ctrl.view.Root)
ui:Back();assert(model.data.ActiveBankSite==0 and not Services.UI.IsWorldPaused)
if BankPreviewOnly then registry:Shutdown();return 'PASS real bank panel render, candle hover, range controls and risk text' end

local npc;for _,value in ipairs(layout.npcs) do if a.shop.rules:Resolve(layout,value) then npc=value;break end end;assert(npc)
local npcCell=state:GetNpcAt(npc.id-1).CellIndex;local spot
for _,cell in ipairs(layout:Neighbors(layout.cells[npcCell])) do if not state:IsNpcOccupied(cell.index) then spot=cell.index;break end end
approach(assert(spot));assert(a.shop:Open(npc.id))
local snapshot=a.shop:Snapshot();local buy
for _,row in ipairs(snapshot.rows) do if row.command=='economy_buy' and row.id==9100 and row.quantity==10 then buy=row;break end end;assert(buy)
local inventory=a.equipment.data:CountItem(9100);assert(model:Command(buy.command,buy.id,buy.version,buy.quantity));assert(a.equipment.data:CountItem(9100)==inventory+10)
assert(not model:Command(buy.command,buy.id,buy.version,buy.quantity),'Repeated UI trade succeeded')
a.shop:Close()
local save=require('Game.Adventure.CharacterSave');assert(save.Write(a))
local candidate=a.characterSaves:Prepare(a.equipment.data);save.Validate(a,candidate)
local saved=CS.ProjectY.Data.TownEconomyData.Prepared(candidate);assert(saved:FindTown(site).Principal==100 and saved.LastTick==model.data.LastTick)
local prepared,world=save.Prepare(a);local nav=model.data:FindTown(site).NetValue;save.Commit(a,prepared,world)
assert(model.data:FindTown(site).NetValue==nav and model.data:FindTown(site).Principal==100 and model.data.ActiveBankSite==0)
registry:Shutdown()
return 'PASS actual world/roster/day rollover, bank proximity/pause/buttons/chart, merchant food purchase, stale trade and complete v36 save/load'
