-- Isolated Edit Mode host: production registry, Data, prefab and button listeners.
-- The host supplies CaptureProfessionBrowser(reference, name), then calls
-- CloseProfessionBrowserPreview() before disposing its Services and PreviewScene.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
function CloseProfessionBrowserPreview() registry:Shutdown();CloseProfessionBrowserPreview=nil end
local messages={}
local ok,err=xpcall(function()
    assert(CaptureProfessionBrowser,'The native profession-browser capture callback is required')
    registry:Start()
    local ui,growth,adventure=registry:Get('UI'),registry:Get('Growth'),registry:Get('Adventure')
    local data=Services.Adventure;data:Reset(922)
    local actors={}
    for i,templateId in ipairs({1,3}) do
        local actor=data:AddPartyActor(i,templateId)
        adventure.characterAppearances:Party(actor,922);growth:Initialize(actor);actors[i]=actor
    end
    adventure.equipment:Start();adventure.equipment:StartPartyLoadouts()
    for _,actor in ipairs(actors) do actor:SetMaxHP(growth.stats:MaximumHP(actor));actor:Restore() end
    local actor=actors[1]
    local adapter={LastError='',commands={}}
    function adapter:SetGrowthOpen(value) self.growthOpen=value end
    function adapter:SendCommand(command,actorId,id)
        local success,reason
        if command=='growth_skill' then success,reason=growth:Learn(actorId,id)
        elseif command=='growth_profession' then success,reason=growth:ChangeProfession(actorId,id)
        else error('Unexpected profession-browser command: '..command) end
        self.LastError=success and '' or reason
        self.commands[#self.commands+1]={command=command,actorId=actorId,id=id,success=success}
    end
    local panel=ui:Open('CharacterGrowth',{demo=adapter,tab='Skills'})
    local professions=registry:Get('Config'):GetTable('ProfessionTable')
    local seenIcons,seenSprites={},{}
    local function test(name,run) run();messages[#messages+1]='PASS '..name end
    local function snapshot(target)
        local state=target.Growth;local values={}
        for _,key in ipairs({'Revision','CurrentProfessionId','ProfessionCount','PendingCount','SkillCount','TalentPoints','TalentCount','TreeCount'}) do
            values[#values+1]=tostring(state[key])
        end
        for i=0,state.ProfessionCount-1 do values[#values+1]=tostring(state:GetProfessionAt(i)) end
        for i=0,state.SkillCount-1 do values[#values+1]=tostring(state:GetSkillAt(i)) end
        for i=0,state.TalentCount-1 do
            local id=state:GetTalentAt(i);values[#values+1]=tostring(id);values[#values+1]=tostring(state:GetRank(id))
        end
        for i=0,state.TreeCount-1 do values[#values+1]=tostring(state:GetTreeAt(i)) end
        return table.concat(values,'|')
    end
    local function click(widget)
        assert(widget.view.Root.gameObject.activeSelf and widget.view.Button.interactable,'Expected a visible, enabled node')
        widget.view.Button.onClick:Invoke()
    end
    local function professionNode(id)
        for _,widget in ipairs(panel.professionNodes) do if widget.row and widget.row.id==id then return widget end end
        error('Missing profession node: '..id)
    end
    local function skillNode(id)
        for _,widget in ipairs(panel.courseNodes) do if widget.node and widget.node.id==id then return widget end end
        error('Missing course node: '..id)
    end
    local function activeProfessionRows()
        local rows={}
        for _,widget in ipairs(panel.professionNodes) do
            if widget.row then
                assert(widget.view.Root.gameObject.activeSelf,'Bound profession node must be visible')
                rows[#rows+1]=widget
            else assert(not widget.view.Root.gameObject.activeSelf,'Unused profession node leaked from the pool') end
        end
        return rows
    end
    local function hidden(pool,key)
        for _,widget in ipairs(pool) do
            assert(not widget.view.Root.gameObject.activeSelf,'Inactive graph pool leaked a visible node')
            if key then assert(not widget[key],'Inactive graph pool retained stale data: '..key) end
        end
    end
    local function hiddenBrowser()
        hidden(panel.professionNodes,'row');hidden(panel.professionEdges,'edge');hidden(panel.professionHeaders,'shown')
    end
    local function icon(widget)
        local row=widget.row;assert(row and row.id>0)
        local image=widget.view.Icon;local config=professions:Get(row.id)
        assert(config.iconPath~='' and row.iconPath==config.iconPath,'Profession node must use its configured artwork')
        assert(image.gameObject.activeSelf and image.enabled and image.sprite~=nil and image.preserveAspect,'Missing or distorted profession artwork: '..row.id)
        assert(CS.UnityEditor.AssetDatabase.GetAssetPath(image.sprite)==config.iconPath,'Wrong profession Sprite: '..row.id)
        local color=image.color
        assert(color.r==1 and color.g==1 and color.b==1 and color.a==1,'Profession artwork must retain its original colors')
        local instance=image.sprite:GetInstanceID()
        assert(not seenSprites[instance] or seenSprites[instance]==row.id,'Different professions must have distinct Sprite assets')
        seenSprites[instance]=row.id;seenIcons[row.id]=true
    end
    local function gridLayout()
        local widgets=activeProfessionRows();local rows={};local bounds={}
        for i,widget in ipairs(widgets) do
            local rect=widget.view.Root;local p=rect.anchoredPosition;local size=rect.rect
            local row=math.floor((i-1)/3)+1;rows[row]=rows[row] or {}
            rows[row][#rows[row]+1]={x=p.x,y=p.y}
            local box={left=p.x-size.width*rect.pivot.x,right=p.x+size.width*(1-rect.pivot.x),
                bottom=p.y-size.height*rect.pivot.y,top=p.y+size.height*(1-rect.pivot.y)}
            assert(box.left>=0 and box.right<=panel.view.Graph.sizeDelta.x,'Grid node extends outside the content width')
            assert(box.top<=0 and box.bottom>=-panel.view.Graph.sizeDelta.y,'Grid node extends outside the content height')
            for _,other in ipairs(bounds) do
                assert(box.right<=other.left or box.left>=other.right or box.top<=other.bottom or box.bottom>=other.top,
                    'Profession grid nodes overlap')
            end
            bounds[#bounds+1]=box;icon(widget)
        end
        for i,row in ipairs(rows) do
            assert(#row==math.min(3,#widgets-(i-1)*3),'Profession chooser must use three columns')
            for j=2,#row do assert(row[j].x>row[j-1].x and row[j].y==row[j-1].y,'Grid columns are not aligned') end
            if i>1 then assert(row[1].y<rows[i-1][1].y,'Grid rows must descend') end
        end
        assert(not panel.view.GraphScroll.horizontal,'Profession grid should not require horizontal scrolling')
        hidden(panel.professionEdges,'edge')
        return widgets
    end
    local function assertGridMembership(target)
        local shown={}
        for _,widget in ipairs(activeProfessionRows()) do
            assert(widget.row.id>0 and not target.Growth:HasProfession(widget.row.id),'Grid contains an already joined profession')
            assert(not shown[widget.row.id],'Grid repeats a profession');shown[widget.row.id]=true
        end
        for _,profession in ipairs(professions:All()) do
            assert((shown[profession.id]==true)==not target.Growth:HasProfession(profession.id),'Grid omitted an available profession')
        end
    end
    local function assertCourses(id)
        assert(panel.professionPage=='courses' and not panel.choosingProfession,'Expected the active profession course tree')
        assert(panel.courseProfessionRoot.row.id==id and panel.courseProfessionRoot.view.Root.gameObject.activeSelf)
        hiddenBrowser()
    end
    test('course root opens joined-profession branches without a gameplay command',function()
        assert(professions.Count==11,'The fixture must cover all eleven configured professions')
        assert(actor.Growth.CurrentProfessionId==1 and actor.Growth.ProfessionCount==1)
        assertCourses(1);icon(panel.courseProfessionRoot)
        local before=snapshot(actor);click(panel.courseProfessionRoot)
        assert(panel.professionPage=='tree' and panel.choosingProfession and #adapter.commands==0 and snapshot(actor)==before)
        assert(#activeProfessionRows()==2 and professionNode(1) and professionNode(0))
        assert(not professionNode(0).view.Icon.gameObject.activeSelf and professionNode(0).view.Plus.gameObject.activeSelf)
        assert(#panel.professionEdges>0 and panel.professionEdges[1].view.Root.gameObject.activeSelf,'Joined professions need visible branches')
        hidden(panel.courseNodes,'node');hidden(panel.courseHeaders,'shown');hidden(panel.courseEdges,'edge')
        assert(panel.courseProfessionRoot.row==nil and not panel.courseProfessionRoot.view.Root.gameObject.activeSelf)
        CaptureProfessionBrowser(panel.reference,'profession-browser-tree')
    end)
    test('add opens a non-overlapping three-column grid with eleven distinct profession icons',function()
        local before=snapshot(actor);click(professionNode(0))
        assert(panel.professionPage=='grid' and panel.selectedProfession==nil and not panel.view.Invest.interactable)
        assert(#gridLayout()==10);assertGridMembership(actor)
        assert(snapshot(actor)==before and #adapter.commands==0)
        local count=0;for _ in pairs(seenIcons) do count=count+1 end
        assert(count==11,'Course root plus unjoined grid must render all eleven profession icons')
        CaptureProfessionBrowser(panel.reference,'profession-browser-grid')
    end)
    test('candidate selection only previews details and back navigation cancels selection',function()
        local before=snapshot(actor)
        click(professionNode(3));assert(panel.selectedProfession==3 and panel.view.Invest.interactable)
        CaptureProfessionBrowser(panel.reference,'profession-browser-grid-selected')
        assert(panel.view.TalentName.text==professions:Get(3).name and panel.view.TalentDetail.text:find(professions:Get(3).description,1,true))
        click(professionNode(2));assert(panel.selectedProfession==2)
        assert(snapshot(actor)==before and #adapter.commands==0,'Candidate preview must not join or switch professions')
        click(panel.professionHeaders[1]);assert(panel.professionPage=='tree' and panel.selectedProfession==nil)
        click(panel.professionHeaders[1]);assertCourses(1)
        assert(snapshot(actor)==before and #adapter.commands==0)
    end)
    local learnedSkill,pendingAfterLearning
    test('existing skill selection and explicit learning remain available',function()
        learnedSkill=101;local pending=actor.Growth.PendingCount;local before=snapshot(actor)
        click(skillNode(learnedSkill))
        assert(panel.selectedCourse==learnedSkill and snapshot(actor)==before and #adapter.commands==0)
        assert(panel.view.Invest.interactable);panel.view.Invest.onClick:Invoke()
        assert(actor.Growth:HasSkill(learnedSkill) and actor.Growth.PendingCount==pending-1 and #adapter.commands==1)
        assert(adapter.commands[1].command=='growth_skill' and adapter.commands[1].success)
        pendingAfterLearning=actor.Growth.PendingCount
    end)
    test('explicit confirmation adds a second profession without spending opportunities or granting its initial skills',function()
        click(panel.courseProfessionRoot);click(professionNode(0));click(professionNode(3))
        local count=actor.Growth.SkillCount
        for _,id in ipairs(professions:Get(3).initialSkillIds) do assert(not actor.Growth:HasSkill(id),'Fixture already owns target initial skill') end
        assert(#adapter.commands==1 and actor.Growth.CurrentProfessionId==1)
        panel.view.Invest.onClick:Invoke()
        assert(#adapter.commands==2 and adapter.commands[2].command=='growth_profession' and adapter.commands[2].id==3 and adapter.commands[2].success)
        assert(actor.Growth.CurrentProfessionId==3 and actor.Growth.ProfessionCount==2 and actor.Growth:HasProfession(1) and actor.Growth:HasProfession(3))
        assert(actor.Growth.PendingCount==pendingAfterLearning and actor.Growth.SkillCount==count and actor.Growth:HasSkill(learnedSkill))
        for _,id in ipairs(professions:Get(3).initialSkillIds) do assert(not actor.Growth:HasSkill(id),'Joining must not grant initial skills') end
        for _,id in ipairs(professions:Get(3).treeIds) do assert(actor.Growth:HasTree(id),'Joining did not open the configured talent tree') end
        assertCourses(3)
        click(panel.courseProfessionRoot)
        assert(#activeProfessionRows()==3 and professionNode(1) and professionNode(3) and professionNode(0))
        CaptureProfessionBrowser(panel.reference,'profession-browser-joined')
        click(professionNode(0));assert(#gridLayout()==9);assertGridMembership(actor)
    end)
    test('joined-profession branches switch the current curriculum and preserve learned skills',function()
        click(panel.professionHeaders[1]);click(professionNode(1));assertCourses(1)
        assert(actor.Growth.CurrentProfessionId==1 and #adapter.commands==3 and actor.Growth.ProfessionCount==2)
        assert(actor.Growth:HasSkill(learnedSkill) and actor.Growth.PendingCount==pendingAfterLearning)
        click(panel.courseProfessionRoot);click(professionNode(1));assertCourses(1)
        assert(#adapter.commands==3,'Opening the current profession must not issue a redundant switch command')
    end)
    test('changing actors clears candidate selection and rebuilds the available grid',function()
        click(panel.courseProfessionRoot);click(professionNode(0));click(professionNode(2))
        local beforeFirst,beforeSecond=snapshot(actor),snapshot(actors[2])
        panel.view.Party2.onClick:Invoke()
        assert(panel.actor==actors[2] and panel.professionPage=='grid' and panel.selectedProfession==nil)
        assert(not panel.view.Invest.interactable and #gridLayout()==10);assertGridMembership(actors[2])
        assert(snapshot(actor)==beforeFirst and snapshot(actors[2])==beforeSecond and #adapter.commands==3)
        click(panel.professionHeaders[1]);assert(#activeProfessionRows()==2)
        assert(professionNode(3) and professionNode(0))
        click(panel.professionHeaders[1]);assertCourses(3)
    end)
    test('talent mode and cached reopen clear hidden browser pools and default back to courses',function()
        click(panel.courseProfessionRoot);click(professionNode(0));click(professionNode(1))
        panel.view.NextTree.onClick:Invoke();assert(panel.skillMode=='talent');hiddenBrowser()
        panel.view.PreviousTree.onClick:Invoke();assertCourses(3);hidden(panel.nodes,'node');hidden(panel.edges,'edge')
        click(panel.courseProfessionRoot);click(professionNode(0));click(professionNode(2))
        panel.view.Close.onClick:Invoke();assert(not adapter.growthOpen and not Services.UI.IsWorldPaused)
        panel=ui:Open('CharacterGrowth',{demo=adapter,tab='Skills',actorIndex=0})
        assert(panel.actor==actor and panel.selectedProfession==nil);assertCourses(1)
        assert(actor.Growth:HasSkill(learnedSkill) and actor.Growth.PendingCount==pendingAfterLearning and #adapter.commands==3)
        panel.view.Close.onClick:Invoke();assert(not adapter.growthOpen and not Services.UI.IsWorldPaused)
    end)
end,debug.traceback)
if not ok then CloseProfessionBrowserPreview();error(err,0) end
return table.concat(messages,'\n')
