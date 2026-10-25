-- Real widgets in an isolated Edit Mode host; no player data or saved scene changes.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
function CloseProfessionTreePreview() registry:Shutdown();CloseProfessionTreePreview=nil end
local messages={}
local ok,err=xpcall(function()
    registry:Start()
    local ui,growth,adventure=registry:Get('UI'),registry:Get('Growth'),registry:Get('Adventure')
    local data=Services.Adventure;data:Reset(920)
    local actor=data:AddPartyActor(1,3);adventure.characterAppearances:Party(actor,920);growth:PrepareActor(actor,3)
    adventure.equipment:Start();adventure.equipment:StartPartyLoadouts()
    actor:SetMaxHP(growth.stats:MaximumHP(actor));actor:Restore();growth:AddExperience(actor,140,'UI tree check')
    local adapter={LastError='',commands=0}
    function adapter:SetGrowthOpen(value) self.growthOpen=value end
    function adapter:SendCommand(command,a,b)
        local success,reason
        if command=='growth_skill' then success,reason=growth:Learn(a,b)
        elseif command=='growth_profession' then success,reason=growth:ChangeProfession(a,b)
        else error('Unexpected command '..command) end
        self.LastError=success and '' or reason;self.commands=self.commands+1
    end
    local panel=ui:Open('CharacterGrowth',{demo=adapter,tab='Skills'})
    local function check(name,fn) fn();messages[#messages+1]='PASS '..name end
    local function node(id)
        for _,widget in ipairs(panel.courseNodes) do if widget.node and widget.node.id==id then return widget end end
        error('Missing skill node '..id)
    end
    local icons=registry:Get('Config'):GetTable('BattleIconTable')
    local imageCount,glyphCount=0,0
    local function checkIcons()
        for _,widget in ipairs(panel.courseNodes) do if widget.node then
            local image=widget.view.Icon
            local skill=growth.rules.skills:Get(widget.node.id)
            local path=icons:Get(skill.iconId).spritePath
            assert(image.sprite~=nil and image.enabled and image.preserveAspect,'Missing or distorted skill icon: '..skill.id)
            if path~='' then
                assert(CS.UnityEditor.AssetDatabase.GetAssetPath(image.sprite)==path,'Wrong skill Sprite: '..skill.id)
                local color=image.color
                assert(color.r==1 and color.g==1 and color.b==1 and color.a==1,'Skill artwork must keep its original colors: '..skill.id)
                imageCount=imageCount+1
            else
                local actual=image.sprite
                panel.view.Style:SetGlyph(image,widget.node.glyphCode)
                assert(image.sprite==actual,'Skill without artwork must use its configured glyph: '..skill.id)
                glyphCount=glyphCount+1
            end
            assert(widget.view.Root.gameObject.activeSelf)
        end end
    end
    check('mage courses render configured skill artwork and bound mode labels',function()
        assert(panel.actor.TemplateId==3 and actor.Growth.CurrentProfessionId==3)
        assert(#panel.courseTree.nodes==7 and #panel.courseTree.headers==3)
        checkIcons();assert(imageCount==7,'All seven mage skills should use published artwork')
        assert(panel.view.PreviousTreeText.rectTransform.rect.width==110 and panel.view.NextTreeText.rectTransform.rect.width==110)
        assert(panel.view.GraphScroll.gameObject.activeSelf)
    end)
    check('real skill button previews and explicit learning spends exactly once',function()
        local pending=actor.Growth.PendingCount
        node(103).view.Button.onClick:Invoke()
        assert(panel.selectedCourse==103 and adapter.commands==0 and actor.Growth.PendingCount==pending)
        assert(panel.view.Invest.interactable);panel.view.Invest.onClick:Invoke()
        assert(actor.Growth:HasSkill(103) and actor.Growth.PendingCount==pending-1 and adapter.commands==1)
        assert(node(103).view.Rank.text==require('Language').UISkillAtlasText8)
        checkIcons()
    end)
    check('mode and cached reopen keep inactive graph pools hidden',function()
        panel.view.NextTree.onClick:Invoke()
        for _,widget in ipairs(panel.courseNodes) do assert(not widget.view.Root.gameObject.activeSelf) end
        ui:Close('CharacterGrowth')
        panel=ui:Open('CharacterGrowth',{demo=adapter,tab='Skills',skillMode='talent'})
        for _,widget in ipairs(panel.courseNodes) do assert(not widget.view.Root.gameObject.activeSelf) end
        panel.view.PreviousTree.onClick:Invoke()
        for _,widget in ipairs(panel.nodes) do assert(not widget.view.Root.gameObject.activeSelf) end
        ui:Close('CharacterGrowth')
        panel=ui:Open('CharacterGrowth',{demo=adapter,tab='Skills'})
        for _,widget in ipairs(panel.nodes) do assert(not widget.view.Root.gameObject.activeSelf) end
        checkIcons()
    end)
    check('profession root opens the chooser and every addable profession renders',function()
        panel.courseProfessionRoot.view.Button.onClick:Invoke()
        assert(panel.professionPage=='tree' and panel.choosingProfession and panel.view.GraphScroll.gameObject.activeSelf)
        local rendered=0
        for _,profession in ipairs(growth.rules.professions.professions:All()) do if not profession.baseProfession then
            panel.choosingProfession=false;panel:Command('growth_profession',profession.id)
            assert(actor.Growth.CurrentProfessionId==profession.id)
            checkIcons();rendered=rendered+1
        end end
        assert(rendered==11 and imageCount>7,'All eleven addable professions must exercise configured artwork')
    end)
    messages[#messages+1]='PASS profession icon projections: '..imageCount..' artwork, '..glyphCount..' glyph fallback'
    panel:Command('growth_profession',3);panel.selectedCourse=103;panel:Refresh();panel:ResetGraph()
    CaptureProfessionTree(panel.reference,'profession-tree-mage')
    panel:Command('growth_profession',4);panel.selectedCourse=302;panel:Refresh();panel:ResetGraph()
    CaptureProfessionTree(panel.reference,'profession-tree-crafter')
    panel:Command('growth_profession',6);panel.selectedCourse=1804;panel:Refresh();panel:ResetGraph()
    CaptureProfessionTree(panel.reference,'profession-tree-chain')
    panel.view.NextTree.onClick:Invoke()
    CaptureProfessionTree(panel.reference,'profession-tree-passive')
    ui:Close('CharacterGrowth');assert(not Services.UI.IsWorldPaused and not adapter.growthOpen)
end,debug.traceback)
if not ok then CloseProfessionTreePreview();error(err,0) end
return table.concat(messages,'\n')
