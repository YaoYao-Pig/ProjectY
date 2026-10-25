-- Five production panels in a disposable Edit Mode host. No gameplay commands are submitted.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local messages={}
function CloseUIRefreshPreview()
    registry:Shutdown()
    CloseUIRefreshPreview=nil
end
local ok,err=xpcall(function()
    registry:Start()
    local ui,adventure,story=registry:Get('UI'),registry:Get('Adventure'),registry:Get('Narrative')
    local data=Services.Adventure
    -- Existing narrative demo recipe supplies real party, equipment, missions and NPC placements.
    -- A warrior leader gives the skills page a populated course tree without buying any skill.
    adventure:Start(nil,story.rules.settings.demoRecipeId,nil,nil,1)
    local adapter={MainHudFont=UIRefreshFont,LastError='',BattleHUDRevision=0,commands=0,cameraCalls=0}
    function adapter:SetEquipmentOpen(value) self.equipmentOpen=value end
    function adapter:SetGrowthOpen(value) self.growthOpen=value end
    function adapter:SetStoryOpen(value) self.storyOpen=value end
    function adapter:SetDialogueCamera(...) self.cameraCalls=self.cameraCalls+1 end
    function adapter:EndDialogueCamera() self.cameraEnded=true end
    function adapter:SendCommand(command)
        self.commands=self.commands+1
        error('UI artwork preview must not submit a gameplay command: '..command)
    end
    local function resources()
        local values={Services.Player.Coins,data.Equipment.Revision}
        for i=0,data.PartyCount-1 do
            local actor=data:GetPartyAt(i)
            values[#values+1]=actor.HP;values[#values+1]=actor.Growth.Revision
            values[#values+1]=actor.Growth.AttributePoints;values[#values+1]=actor.Growth.TalentPoints
            values[#values+1]=actor.Growth.PendingCount
        end
        return table.concat(values,':')
    end
    local function capture(name)
        assert(Services.UI.IsWorldPaused,'Expected original panel pause policy: '..name)
        local before=resources()
        CaptureUIRefresh(name)
        assert(resources()==before,'Rendering changed gameplay resources: '..name)
        assert(adapter.commands==0,'Preview submitted a gameplay command')
        messages[#messages+1]='PASS '..name..': real panel rendered; resources unchanged'
    end
    local inventory=ui:Open('Inventory',{demo=adapter})
    assert(inventory.view.Character~=nil and #inventory.rows>0)
    for _,row in ipairs(inventory.rows) do if row.kind=='weapon' then inventory.selected=row.key;inventory:Refresh();break end end
    capture('inventory');ui:Close('Inventory')

    local skills=ui:Open('CharacterGrowth',{demo=adapter,tab='Skills'})
    assert(skills.skin and skills.skin.sprites.button_light and #skills.courseNodes>0)
    capture('skills');ui:Close('CharacterGrowth')

    local mission=ui:Open('MissionJournal',{demo=adapter})
    assert(mission.skin and #mission.missionRows>0 and #mission.tabs>0)
    for _,reward in ipairs(mission.rewardRows) do
        if reward.row and reward.row.kind~='item' then
            assert(reward.view.Icon.enabled and not reward.view.Glyph.gameObject.activeSelf,'Reward glyph was not replaced by artwork')
            assert(reward.view.Icon.sprite==mission.rewardArt[reward.row.kind],'Reward artwork does not match its kind')
        end
    end
    messages[#messages+1]='PASS reward artwork: configured icons replace non-item glyphs; existing item icons and reward values remain separate'
    capture('mission')
    -- Presentation stress cases use copied rows only; no narrative or economy state is changed.
    local longTitle=mission.missionRows[1].view.Title.DefaultText
    mission.missionRows[1].view.Title.DefaultText=longTitle..' / '..longTitle..' / '..longTitle
    local rewardWidget=mission.rewardRows[1];local longReward={}
    for key,value in pairs(rewardWidget.row) do longReward[key]=value end
    longReward.name=longReward.name..' / '..longReward.name..' / '..longReward.name..' / '..longReward.name
    rewardWidget:SetData(longReward,UIRefreshFont)
    local height=require('UI.ArtSkin').ApplyReward(mission.skin,mission.rewardArt,rewardWidget.view,longReward,mission.view.RewardsLayout.cellSize.x)
    mission.view.RewardsLayout.cellSize=CS.UnityEngine.Vector2(mission.view.RewardsLayout.cellSize.x,height)
    capture('mission-wrap');ui:Close('MissionJournal')

    local entered,enterReason=adventure:EnterSite(assert(story.npcs.locations[1],'Demo NPC location missing'))
    assert(entered,enterReason)
    local localId
    for _,npc in ipairs(adventure.areas:ActiveLayout().npcs) do if npc.narrativeId==1 then localId=npc.id;break end end
    assert(localId,'Demo NPC missing from the real town layout')
    data.Areas.Active:SetInteraction(2,localId)
    local opened,openReason=story.dialogue:Open(1,localId);assert(opened,openReason)
    local dialogue=ui:Open('Dialogue',{demo=adapter})
    assert(adapter.cameraCalls>0 and #dialogue.pool>0 and #dialogue.choices>0)
    for _,entry in ipairs(dialogue.pool) do if entry.row then assert(entry.skin and entry.skin.colors.ink) end end
    for _,entry in ipairs(dialogue.choices) do if entry.row then assert(entry.skin and entry.skin.sprites.button_light) end end
    dialogue:Tick()
    capture('dialogue')
    local choice=dialogue.choices[1];local longChoice={}
    for key,value in pairs(choice.row) do longChoice[key]=value end
    longChoice.title=longChoice.title..' / '..longChoice.title..' / '..longChoice.title..' / '..longChoice.title
    longChoice.body=dialogue.pool[1].row.body
    choice:SetData(longChoice,UIRefreshFont,choice.action)
    capture('dialogue-wrap');ui:Close('Dialogue')
    messages[#messages+1]='LIMITATION dialogue: neutral native camera viewport on the left; world actors/Cinemachine rendering are not part of this UI capture'
    local left,leaveReason=adventure.areas:Leave();assert(left,leaveReason)

    local eventSite
    for _,site in ipairs(adventure.sites) do if site.eventId==6 then eventSite=site;break end end
    assert(eventSite,'Demo recipe must contain the configured complex event 6')
    local begun,beginReason=adventure.events:Begin(eventSite);assert(begun,beginReason)
    local event=ui:Open('StoryEvent',{demo=adapter})
    assert(event.view.Illustration.sprite~=nil and #event.pools.Choices>0)
    for _,entry in ipairs(event.pools.Choices) do if entry.row then assert(entry.skin and entry.skin.sprites.button_light) end end
    capture('event')
    local choice=event.pools.Choices[1];local longChoice={}
    for key,value in pairs(choice.row) do longChoice[key]=value end
    longChoice.title=longChoice.title..' / '..longChoice.title..' / '..longChoice.title
    longChoice.body=longChoice.body..' / '..longChoice.body..' / '..longChoice.body
    choice:SetData(longChoice,event.view.Style,choice.action)
    capture('event-wrap');ui:Close('StoryEvent')
    assert(not Services.UI.IsWorldPaused,'Preview panels retained a pause lease')
    messages[#messages+1]='PASS Skin bindings are read by the production Lua controllers; button availability remains controller-driven'
end,debug.traceback)
if not ok then CloseUIRefreshPreview();error(err,0) end
return table.concat(messages,'\n')
