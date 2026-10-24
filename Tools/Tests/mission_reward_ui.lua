-- Real config, C# Data, nearby resident interaction, production Lua UI and reward operations.
local registry=require('Main');local adventure=registry:Get('Adventure');local story=registry:Get('Narrative');local ui=registry:Get('UI')
adventure:Start(nil,2,2500)
local siteId=assert(story.npcs.locations[1]);assert(adventure:EnterSite(siteId));story:Refresh()
local layout=adventure.areas:ActiveLayout();local state=adventure.data.Areas.Active;local town=story.townMissions
local definition
for _,row in ipairs(town.definitions:All()) do if row.kind=='delivery' then definition=row;break end end
local npc
for _,row in ipairs(layout.npcs) do if not row.narrativeId and not row.facilityId then npc=row;break end end
local mission=town.data:Add(definition.id,siteId,npc.stableId,math.floor(story.data.Minutes/1440),definition.itemId,definition.minCount)
local index=state:GetNpcAt(npc.id-1).CellIndex;local anchor
for _,cell in ipairs(layout:Neighbors(layout.cells[index])) do if not state:IsNpcOccupied(cell.index) then anchor=cell.index;break end end
local ids={};for i=0,adventure.data.PartyCount-1 do ids[#ids+1]=adventure.data:GetPartyAt(i).Id end
state:Stop();state:DeployMembers(ids,require('Game.MapArea.SquadMovement').Deploy(layout,assert(anchor),#ids,function(cell)return not state:IsNpcOccupied(cell.index)end))
assert(adventure:AreaCommand('area_interact',2,npc.id))
local demo={MainHudFont=MissionTestFont,LastError='',BattleHUDRevision=0,SetStoryOpen=function()end}
function demo:SendCommand(command,id)
    local ok,reason
    if command=='town_mission_accept' then ok,reason=town:Accept(id)
    elseif command=='town_mission_claim' then ok,reason=town:Claim(id)
    else error(command) end
    self.LastError=ok and '' or reason;self.BattleHUDRevision=self.BattleHUDRevision+1;story:Refresh()
end
local receipts={};local settlement
local unsubscribe=story.RewardSettled:Subscribe(function(receipt)
    receipts[#receipts+1]=receipt
    if settlement and settlement.visible then settlement:Enqueue(receipt)
    else settlement=ui:Open('MissionSettlement',{receipt=receipt,font=MissionTestFont}) end
end)
local journal=ui:Open('MissionJournal',{demo=demo,townSiteId=siteId,townNpcId=npc.stableId})
journal.selected=-mission.Id;journal:Refresh()
assert(journal.view.Objective.DefaultText:find('任务目标',1,true) and #journal.rewardRows==2)
assert(journal.rewardRows[2].view.Glyph.DefaultText=='EXP+')
assert(journal.rewardRows[2].view.Note.DefaultText=='每位队员')
MissionPreviewCapture('journal')
local function clickAction()
    assert(journal.view.PrimaryAction.interactable);journal.view.PrimaryAction.onClick:Invoke();journal:Tick()
end
clickAction();assert(mission.State=='active')
assert(adventure.equipment:Grant(mission.TargetId,mission.RequiredCount));story:Refresh();journal:Tick();assert(mission.State=='ready')
local before=adventure.player.Coins
clickAction();assert(mission.State=='completed' and adventure.player.Coins>before and #receipts==1)
assert(settlement.visible and Services.UI.IsWorldPaused and settlement.pool[2].view.Glyph.DefaultText=='EXP+')
MissionPreviewCapture('settlement')
local coins=adventure.player.Coins;assert(not town:Claim(mission.Id));assert(#receipts==1 and adventure.player.Coins==coins)
settlement:Enqueue(receipts[1]);assert(settlement.view.ConfirmText.DefaultText:find('1',1,true))
settlement.view.Confirm.onClick:Invoke();assert(settlement.visible and #settlement.queue==0)
settlement.view.Confirm.onClick:Invoke();assert(not ui:IsOpen('MissionSettlement') and adventure.player.Coins==coins)
assert(Services.UI.IsWorldPaused,'Underlying journal still owns a pause lease')
ui:Close('MissionJournal');assert(not Services.UI.IsWorldPaused and state.InteractionKind==0)
journal=ui:Open('MissionJournal',{demo=demo});assert(journal.selected and not journal.view.Objective.gameObject.activeSelf)
ui:Close('MissionJournal');assert(not Services.UI.IsWorldPaused)
-- Cached reopening replaces rows and keeps the inventory icon and EXP glyph mutually exclusive.
local item=story.rules.config:GetTable('EquipmentItemTable'):Get(92)
settlement=ui:Open('MissionSettlement',{font=MissionTestFont,receipt={title='物品奖励验证',kind='mission',rows={{kind='item',name=item.name,amount=2,itemId=item.id,iconPath=item.iconPath}}}})
assert(settlement.pool[1].view.Icon.enabled and not settlement.pool[1].view.Glyph.gameObject.activeSelf)
assert(not settlement.pool[2].view.Root.gameObject.activeSelf)
settlement.view.Confirm.onClick:Invoke();assert(not Services.UI.IsWorldPaused)
unsubscribe()
return 'PASS real town acceptance/hand-in, coins and EXP settlement, reward icons, duplicate claim, queued confirmation, cached reopen and pause/interaction cleanup'
