-- Isolated UIHost + real C# Data, exported config and real Camp/Dialogue prefabs.
-- The adapter dispatches production models; this does not exercise AdventureRuntimeDemo's C# input gate.
local main=require('Main')
local adventure,story,ui=main:Get('Adventure'),main:Get('Narrative'),main:Get('UI')
local L=require('Language');local Rich=require('UI.RichText')
local data,bag=adventure.data,adventure.equipment.data
data:Reset(891);bag.Grid:Configure(adventure.equipment.recipe.bagWidth,adventure.equipment.recipe.bagHeight)
local actor=data:AddPartyActor(1,1);adventure.growth:PrepareActor(actor)
actor:SetMaxHP(adventure.battle.stats:MaximumHP(actor));actor:Restore()
adventure.player:AddCoins(500)
for _,id in ipairs({81,82,83})do assert(adventure.equipment:Grant(id,40))end
local recipe=adventure.forge.rules.settings
local weapon=bag:AddWeapon(recipe.weaponIds[1]);assert(bag:Equip(actor.Id,weapon.Id))
local weaponId,itemId,ownerId=weapon.Id,weapon.ItemId,weapon.OwnerActorId
local affixId=adventure.equipment.rules.affixes:Of(weapon).id
local condition=CS.ProjectY.Data.EquipmentConditionData.Of(weapon)
CS.ProjectY.Data.EquipmentCombatState.DamageWeapon(bag,weaponId,51)
assert(condition.Current==49 and condition.Maximum==95,'Fixture must start with permanent wear')
local legacy=CS.ProjectY.Data.EquipmentLegacyData.Of(weapon)
local camp=adventure.camp;local forge=adventure.forge
local demo={MainHudFont=assert(ForgeTestFont),LastError='',BattleHUDRevision=0,commands={}}
function demo:SetStoryOpen(value)self.storyOpen=value end
function demo:SetDialogueCamera()error('Equipment spirit attempted a town-NPC camera')end
function demo:EndDialogueCamera()self.cameraReleased=true end
function demo:SendCommand(command,a,b,c)
    local ok,reason
    if command=='camp_close' then ok,reason=camp:Close()
    elseif command=='camp_upgrade' then ok,reason=camp:Upgrade(a,b)
    elseif command=='forge_forge' then ok,reason=forge:Forge(a,b)
    elseif command=='forge_path' then ok,reason=forge:Advance(a,b,c)
    elseif command=='forge_awaken' then ok,reason=forge:Talk(a,b,true)
    elseif command=='forge_talk' then ok,reason=forge:Talk(a,b,false)
    elseif command=='dialogue_choose' then ok,reason=story.dialogue:Choose(a,b)
    elseif command=='dialogue_close' then ok,reason=story.dialogue:Close()
    else error('Unexpected forge fixture command: '..command)end
    self.LastError=ok and '' or assert(reason)
    self.BattleHUDRevision=self.BattleHUDRevision+1
    self.commands[command]=(self.commands[command] or 0)+1
    if not camp.data.IsOpen and ui:IsOpen('Camp')then ui:Close('Camp')end
    if story.data.DialogueOpen and not ui:IsOpen('Dialogue')then ui:Open('Dialogue',{demo=self})end
    if not story.data.DialogueOpen and ui:IsOpen('Dialogue')then ui:Close('Dialogue')end
end
local initialScale=CS.UnityEngine.Time.timeScale
assert(camp:Open());local panel=ui:Open('Camp',{demo=demo})
assert(Services.UI.IsWorldPaused and CS.UnityEngine.Time.timeScale==0 and demo.storyOpen)
local function rowWith(title)
    title=Rich.Escape(title)
    for _,widget in ipairs(panel.rows)do if widget.row and widget.row.title:find(title,1,true)then return widget end end
    error('Missing native Camp row: '..title)
end
local function click(widget)
    assert(widget.view.Root.gameObject.activeSelf and widget.view.Button.interactable,'Expected an active enabled native button')
    widget.view.Button.onClick:Invoke()
    assert(demo.LastError=='',demo.LastError)
    if ui:IsOpen('Camp')then panel:Tick()end
    if ui:IsOpen('Dialogue')then ui.panels.Dialogue.ctrl:Tick()end
end
click(rowWith(string.format(L.UICampText35,camp.rules.facilities:Get(recipe.facilityId).name,0)))
assert(camp.data:GetLevel(recipe.facilityId)==recipe.requiredLevel)
click(rowWith(L.ForgeSection));assert(panel.section=='forge')
local firstForge=rowWith(string.format(L.ForgeFirstAction,forge:Name(weapon)))
local staleForge=firstForge.action;local coins=adventure.player.Coins;local material=bag:CountItem(recipe.itemIds[1])
click(firstForge)
assert(legacy.Forged and condition.Current==condition.BaseMaximum and condition.Maximum==condition.BaseMaximum)
assert(weapon.Id==weaponId and weapon.ItemId==itemId and weapon.OwnerActorId==ownerId and bag:GetWeapon(weaponId)==weapon)
assert(adventure.equipment.rules.affixes:Of(weapon).id==affixId and bag.WeaponCount==1,'Forging must preserve the original instance and affix')
assert(adventure.player.Coins==coins-recipe.coins and bag:CountItem(recipe.itemIds[1])==material-recipe.itemCounts[1])
local afterCoins,afterMaterial=adventure.player.Coins,bag:CountItem(recipe.itemIds[1])
staleForge();assert(demo.LastError~='' and adventure.player.Coins==afterCoins and bag:CountItem(recipe.itemIds[1])==afterMaterial)
demo.LastError='';panel:Tick()
local path=forge.rules.paths:Get(1)
local pathButton=rowWith(string.format(L.ForgePathAction,path.name))
assert(not pathButton.view.Button.interactable,'A fresh weapon cannot advance without a deed')
local deedRule=forge.rules.deeds:Get(path.deedIds[1]);assert(deedRule.kind=='legendary_kill')
story.data:AdvanceMinutes(120)
assert(legacy:RecordDeed(deedRule.id,actor.Id,deedRule.targetIds[1],0,story.data.Minutes))
assert(not legacy:RecordDeed(deedRule.id,actor.Id,deedRule.targetIds[1],0,story.data.Minutes),'Duplicate deeds cannot grow a second history entry')
panel:Refresh()
local memory=forge:DeedText(legacy:GetDeedAt(0))
local identity=rowWith(string.format(L.ForgeWeaponIdentity,forge:Name(weapon),weaponId))
assert(identity.view.Body.DefaultText==memory,'Native camp detail must show the saved deed')
pathButton=rowWith(string.format(L.ForgePathAction,path.name));local stalePath=pathButton.action
click(pathButton);assert(legacy.PathId==path.id and bag:GetWeapon(weaponId)==weapon)
local revision=legacy.Revision;stalePath();assert(demo.LastError~='' and legacy.Revision==revision)
demo.LastError='';panel:Tick()
CS.UnityEngine.Canvas.ForceUpdateCanvases()
CS.UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(panel.view.Content)
panel.view.Scroll.verticalNormalizedPosition=0
ForgePreviewCapture('camp-advanced')
local awaken=rowWith(string.format(L.ForgeAwakenAction,forge:Name(weapon)));local oldCampRevision=camp.data.Revision
click(awaken)
assert(legacy.Awakened and adventure.spiritDialogue:Active() and CS.ProjectY.Data.EquipmentSpiritSession.WeaponId(story.data)==weaponId)
assert(not camp.data.IsOpen and not ui:IsOpen('Camp') and ui:IsOpen('Dialogue') and Services.UI.IsWorldPaused)
local dialogue=ui.panels.Dialogue.ctrl
assert(story.data.DialogueNpcId==0 and story.data.DialogueId==-1 and dialogue.view.Title.text==forge:Name(weapon))
assert(story.data:GetLineAt(0).Text==path.spiritOpening and dialogue.view.Caption.text==string.format(L.EquipmentSpiritCaption,path.name))
demo:SendCommand('forge_awaken',weaponId,oldCampRevision)
assert(demo.LastError~='' and legacy.Awakened and story.data.LineCount==1,'An old camp command cannot reopen or mutate the active spirit')
demo.LastError='';dialogue:Tick()
local function choice(id)
    local choices=story.dialogue:Choices()
    for i,row in ipairs(choices)do if row.id==id then return assert(dialogue.choices[i])end end
    error('Missing native spirit choice '..id)
end
click(choice(-1));assert(story.data:GetLineAt(story.data.LineCount-1).Text==path.personality)
click(choice(-2));assert(story.data:GetLineAt(story.data.LineCount-1).Text==memory)
click(choice(-3));assert(story.data:GetLineAt(story.data.LineCount-1).Text==path.wish)
CS.UnityEngine.Canvas.ForceUpdateCanvases()
CS.UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(dialogue.view.Choices)
dialogue.view.ChoiceScroll.verticalNormalizedPosition=0
ForgePreviewCapture('spirit-wish')
local accept=choice(-4);local oldAccept=accept.action
click(accept);assert(legacy.WishState==1 and story.data:GetLineAt(story.data.LineCount-1).Text==path.wishAccepted)
revision=legacy.Revision;oldAccept();assert(demo.LastError~='' and legacy.Revision==revision and legacy.WishState==1)
demo.LastError='';dialogue:Tick()
click(choice(-3));assert(story.data:GetLineAt(story.data.LineCount-1).Text==path.wishProgress)
ForgePreviewCapture('spirit-promise')
dialogue.view.Close.onClick:Invoke()
assert(demo.LastError=='' and not story.data.DialogueOpen and CS.ProjectY.Data.EquipmentSpiritSession.WeaponId(story.data)==0)
assert(not ui:IsOpen('Dialogue') and not Services.UI.IsWorldPaused and CS.UnityEngine.Time.timeScale==initialScale and not demo.storyOpen)
assert(demo.cameraReleased and story.data.LineCount==0)
-- Production close returns to exploration; opening the camp again must retain the same equipment state.
assert(camp:Open());assert(ui:Open('Camp',{demo=demo})==panel);click(rowWith(L.ForgeSection))
local talk=rowWith(string.format(L.ForgeTalkAction,forge:Name(weapon)))
assert(talk.view.Body.DefaultText==path.wishProgress and bag:GetWeapon(weaponId)==weapon and legacy.DeedCount==1)
click(talk);assert(ui.panels.Dialogue.ctrl==dialogue and story.data.LineCount==1 and legacy.WishState==1)
ui:Back();assert(not story.data.DialogueOpen and not Services.UI.IsWorldPaused and not demo.storyOpen)
assert(camp:Open());ui:Open('Camp',{demo=demo});panel.view.Close.onClick:Invoke()
assert(not camp.data.IsOpen and not Services.UI.IsWorldPaused and CS.UnityEngine.Time.timeScale==initialScale)
assert(demo.commands.forge_forge==2 and demo.commands.forge_path==2 and demo.commands.forge_awaken==2 and demo.commands.forge_talk==1)
return 'PASS native Camp/Dialogue buttons + real C# and xLua: worn instance forging, resource debit, deed and path gates, stale actions, awakening, memory/personality/wish, one acceptance, close/Back pause release and cached camp/dialogue reopening; isolated model command adapter'
