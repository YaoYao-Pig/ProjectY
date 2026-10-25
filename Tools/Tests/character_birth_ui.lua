-- Isolated Edit Mode host: real Services, registry, characters and journal widgets.
-- Host supplies CaptureBirthUI(reference, name), then calls CloseBirthUIPreview()
-- before disposing its Services and PreviewScene. No player saves are touched.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
function CloseBirthUIPreview() registry:Shutdown();CloseBirthUIPreview=nil end
local messages={}
local ok,err=xpcall(function()
    assert(CaptureBirthUI,'The native birth UI capture callback is required')
    registry:Start()
    local ui,growth,adventure=registry:Get('UI'),registry:Get('Growth'),registry:Get('Adventure')
    local stats=growth.stats
    local config=registry:Get('Config')
    local professions=config:GetTable('ProfessionTable')
    local attributes=config:GetTable('GrowthAttributeTable')
    local language=require('Language')
    local data=Services.Adventure;data:Reset(923)
    local actors={}
    for i,row in ipairs({{template=1,profession=12},{template=3,profession=13}}) do
        local actor=data:AddPartyActor(i,row.template)
        growth:PrepareActor(actor,row.profession)
        adventure.characterAppearances:Party(actor,923);actors[i]=actor
    end
    adventure.equipment:Start();adventure.equipment:StartPartyLoadouts()
    for _,actor in ipairs(actors) do actor:SetMaxHP(stats:MaximumHP(actor));actor:Restore() end
    local farmer,noble=actors[1],actors[2]
    local adapter={LastError='',commands={}}
    function adapter:SetGrowthOpen(value) self.growthOpen=value end
    function adapter:SendCommand(command,actorId,id)
        assert(command=='growth_profession','Birth UI preview issued an unexpected command: '..command)
        local success,reason=growth:ChangeProfession(actorId,id)
        self.LastError=success and '' or reason
        self.commands[#self.commands+1]={actorId=actorId,profession=id,success=success}
    end
    local panel=ui:Open('CharacterGrowth',{demo=adapter})
    local function test(name,run) run();messages[#messages+1]='PASS '..name end
    local function birthSnapshot(actor)
        local rows={tostring(actor.InitialProfessionId)}
        for i=0,actor.InitialAttributeCount-1 do
            local name=actor:GetInitialAttributeNameAt(i)
            rows[#rows+1]=name..'='..actor:GetInitialAttribute(name)
        end
        return table.concat(rows,'|')
    end
    local function professionSnapshot(actor)
        local rows={}
        for i=0,actor.ProfessionAttributeSetCount-1 do
            local id=actor:GetProfessionAttributeProfessionAt(i);local values={}
            for j=0,actor:GetProfessionAttributeCount(id)-1 do
                local name=actor:GetProfessionAttributeNameAt(id,j)
                values[#values+1]=name..'='..actor:GetProfessionAttribute(id,name)
            end
            table.sort(values);rows[#rows+1]=id..':'..table.concat(values,',')
        end
        table.sort(rows);return table.concat(rows,'|')
    end
    local function resources(actor)
        local state=actor.Growth;local skills={}
        for i=0,state.SkillCount-1 do skills[#skills+1]=state:GetSkillAt(i) end
        return state.PendingCount..':'..state.TalentPoints..':'..state.AttributePoints..':'..table.concat(skills,',')
    end
    local initialFarmer,initialNoble=birthSnapshot(farmer),birthSnapshot(noble)
    local farmerResources,nobleResources=resources(farmer),resources(noble)
    local function checkNames()
        assert(panel.view.Role.text==professions:Get(panel.actor.Growth.CurrentProfessionId).name,'Role shows a stale template profession')
        for i,actor in ipairs(actors) do
            local name=stats:Template(actor).name
            local expected=string.format(language.GrowthCharacterProfessionName,name:match('^(.-)%s*·') or name,
                professions:Get(actor.Growth.CurrentProfessionId).name)
            assert(panel.view['Party'..i..'Text'].text==expected,'Party selector shows a stale template profession')
        end
    end
    local function checkHealth(actor)
        assert(actor.MaxHP==stats:MaximumHP(actor) and actor.HP==actor.MaxHP,'Profession change did not preserve a healthy actor at the calculated maximum HP')
        assert(panel.view.HeroHealth.text==string.format(language.UICharacterGrowthHeroHealthText,actor.HP,actor.MaxHP),'Journal HP does not match the real actor')
    end
    local function checkOverview(actor)
        assert(panel.actor==actor and panel.tab=='Overview')
        local shown={}
        for _,widget in ipairs(panel.pools.Attributes) do
            if widget.row then
                local attribute=attributes:Get(widget.row.id)
                assert(not shown[attribute.code] and widget.view.Root.gameObject.activeSelf)
                local expected=tostring(stats:Get(actor,attribute.code))
                assert(widget.row.body==expected and widget.view.Body.text==expected,'Overview total differs from CombatStats: '..attribute.code)
                shown[attribute.code]=true
            end
        end
        for _,attribute in ipairs(attributes:All()) do assert(shown[attribute.code],'Overview omitted an attribute: '..attribute.code) end
        checkNames();checkHealth(actor)
    end
    local function click(widget)
        assert(widget.view.Root.gameObject.activeSelf and widget.view.Button.interactable,'Expected an enabled visible profession node')
        widget.view.Button.onClick:Invoke()
    end
    local function professionNode(id)
        for _,widget in ipairs(panel.professionNodes) do if widget.row and widget.row.id==id then return widget end end
        error('Missing profession node: '..id)
    end
    local function checkRoot(id)
        assert(panel.professionPage=='courses' and panel.courseProfessionRoot.row.id==id)
        local image=panel.courseProfessionRoot.view.Icon
        assert(image.gameObject.activeSelf and image.enabled and image.sprite~=nil and image.preserveAspect,'Base profession icon is missing or distorted')
        assert(CS.UnityEditor.AssetDatabase.GetAssetPath(image.sprite)==professions:Get(id).iconPath,'Base profession root uses the wrong Sprite')
        local color=image.color;assert(color.r==1 and color.g==1 and color.b==1 and color.a==1)
        checkNames();checkHealth(panel.actor)
        return image.sprite:GetInstanceID()
    end
    local function checkGrid(expected)
        assert(panel.professionPage=='grid' and panel.selectedProfession==nil and not panel.view.Invest.interactable)
        local shown,count={},0
        for _,widget in ipairs(panel.professionNodes) do
            if widget.row then
                local id=widget.row.id;local profession=professions:Get(id)
                assert(widget.view.Root.gameObject.activeSelf and not profession.baseProfession and id~=12 and id~=13,
                    'A creation-only base profession leaked into the secondary-profession grid')
                assert(not panel.actor.Growth:HasProfession(id) and not shown[id],'Grid repeats or includes a joined profession')
                shown[id]=true;count=count+1
            else assert(not widget.view.Root.gameObject.activeSelf,'Cached profession node remained visible') end
        end
        for _,profession in ipairs(professions:All()) do
            local available=not profession.baseProfession and not panel.actor.Growth:HasProfession(profession.id)
            assert((shown[profession.id]==true)==available,'Grid availability differs from the profession rules')
        end
        assert(count==expected,'Unexpected number of secondary professions')
    end
    local function openGrid()
        click(panel.courseProfessionRoot);assert(panel.professionPage=='tree')
        click(professionNode(0));assert(panel.professionPage=='grid')
    end
    local function confirmWarrior(actor,code,before,bonus)
        local commands=#adapter.commands;local saved=professionSnapshot(actor)
        click(professionNode(1))
        assert(panel.selectedProfession==1 and panel.view.Invest.interactable and #adapter.commands==commands)
        assert(actor.Growth.CurrentProfessionId==actor.InitialProfessionId and stats:Get(actor,code)==before and professionSnapshot(actor)==saved,
            'Candidate selection changed the current profession or its attributes')
        panel.view.Invest.onClick:Invoke()
        assert(#adapter.commands==commands+1 and adapter.commands[#adapter.commands].success and adapter.commands[#adapter.commands].actorId==actor.Id)
        assert(actor.Growth.CurrentProfessionId==1 and actor.Growth.ProfessionCount==2 and actor.Growth:HasProfession(actor.InitialProfessionId))
        assert(stats:Get(actor,code)==before-bonus,'Inactive base profession still contributes its saved attribute bonus')
        assert(actor:GetProfessionAttribute(actor.InitialProfessionId,code)==bonus,'Switching discarded the saved base-profession bonus')
        checkRoot(1)
    end
    local farmerStrength=stats:Get(farmer,'strength');local farmerBonus=farmer:GetProfessionAttribute(12,'strength')
    local nobleSpeed=stats:Get(noble,'speed');local nobleBonus=noble:GetProfessionAttribute(13,'speed')
    local farmerSprite,nobleSprite
    test('farmer defaults and noble overrides render dynamic names and real total attributes',function()
        assert(config:GetTable('CharacterBirthRuleTable'):Get(1).defaultProfessionId==12)
        assert(professions.Count==13 and professions:Get(12).baseProfession and professions:Get(13).baseProfession)
        assert(farmer.InitialProfessionId==12 and farmer.Growth.CurrentProfessionId==12 and farmer.Growth.ProfessionCount==1)
        assert(noble.InitialProfessionId==13 and noble.Growth.CurrentProfessionId==13 and noble.Growth.ProfessionCount==1)
        assert(farmerBonus>0 and nobleBonus>0,'Seed 923 must visibly exercise both configured birth-profession bonuses')
        assert(farmer.HasInitialAttributes and noble.HasInitialAttributes and adapter.growthOpen and Services.UI.IsWorldPaused)
        checkOverview(farmer)
        CaptureBirthUI(panel.reference,'birth-farmer-overview')
    end)
    test('farmer has its own root icon and eleven addable professions without either base profession',function()
        panel.view.SkillsTab.onClick:Invoke();farmerSprite=checkRoot(12)
        assert(#panel.courseTree.nodes==0,'Farmer should not acquire placeholder professional courses')
        click(panel.courseProfessionRoot)
        assert(professionNode(12) and professionNode(0) and panel.professionPage=='tree')
        CaptureBirthUI(panel.reference,'birth-farmer-tree')
        click(professionNode(0));checkGrid(11)
        assert(#adapter.commands==0 and resources(farmer)==farmerResources and birthSnapshot(farmer)==initialFarmer)
    end)
    test('confirming warrior removes only the saved farmer bonus and updates overview totals',function()
        confirmWarrior(farmer,'strength',farmerStrength,farmerBonus)
        assert(resources(farmer)==farmerResources and birthSnapshot(farmer)==initialFarmer)
        panel.view.OverviewTab.onClick:Invoke();checkOverview(farmer)
        panel.view.SkillsTab.onClick:Invoke();openGrid();checkGrid(10)
        click(panel.professionHeaders[1]);assert(panel.professionPage=='tree')
    end)
    test('joined farmer remains selectable and reuses its original bonus when restored',function()
        local stored=professionSnapshot(farmer);local sets=farmer.ProfessionAttributeSetCount
        click(professionNode(12));checkRoot(12)
        assert(stats:Get(farmer,'strength')==farmerStrength and farmer:GetProfessionAttribute(12,'strength')==farmerBonus)
        assert(professionSnapshot(farmer)==stored and farmer.ProfessionAttributeSetCount==sets and birthSnapshot(farmer)==initialFarmer,
            'Switching back rerolled or replaced the stored character or profession attributes')
        assert(resources(farmer)==farmerResources and farmer.Growth.ProfessionCount==2)
        panel.view.OverviewTab.onClick:Invoke();checkOverview(farmer)
    end)
    test('noble uses a separate icon and only its current-profession speed bonus',function()
        panel.view.Party2.onClick:Invoke();checkOverview(noble)
        CaptureBirthUI(panel.reference,'birth-noble-overview')
        panel.view.SkillsTab.onClick:Invoke();nobleSprite=checkRoot(13)
        assert(nobleSprite~=farmerSprite and professions:Get(13).iconPath~=professions:Get(12).iconPath,'Farmer and noble must use distinct Sprite assets')
        click(panel.courseProfessionRoot)
        assert(professionNode(13) and professionNode(0));CaptureBirthUI(panel.reference,'birth-noble-tree')
        click(professionNode(0));checkGrid(11)
        confirmWarrior(noble,'speed',nobleSpeed,nobleBonus)
        assert(resources(noble)==nobleResources and birthSnapshot(noble)==initialNoble)
        panel.view.OverviewTab.onClick:Invoke();checkOverview(noble)
        panel.view.SkillsTab.onClick:Invoke();click(panel.courseProfessionRoot)
        local stored=professionSnapshot(noble);local sets=noble.ProfessionAttributeSetCount
        click(professionNode(13));checkRoot(13)
        assert(stats:Get(noble,'speed')==nobleSpeed and noble:GetProfessionAttribute(13,'speed')==nobleBonus)
        assert(professionSnapshot(noble)==stored and noble.ProfessionAttributeSetCount==sets and birthSnapshot(noble)==initialNoble)
        assert(resources(noble)==nobleResources and #adapter.commands==4)
    end)
    test('closing releases the model preview and cached reopening preserves both birth states',function()
        -- Inspect two known private resource fields; the test never searches UI objects or components.
        local view=panel.view.Character;local kind=view:GetType()
        local studio=assert(kind:GetField('studio',36));local texture=assert(kind:GetField('texture',36)) -- Instance | NonPublic
        assert(studio:GetValue(view)~=nil and texture:GetValue(view)~=nil,'Character model preview was not created')
        panel.view.Close.onClick:Invoke()
        assert(not adapter.growthOpen and not Services.UI.IsWorldPaused)
        assert(studio:GetValue(view)==nil and texture:GetValue(view)==nil,'Closing retained the preview studio or render texture')
        panel=ui:Open('CharacterGrowth',{demo=adapter,actorIndex=0})
        checkOverview(farmer)
        assert(panel.professionPage=='courses' and panel.selectedProfession==nil)
        assert(birthSnapshot(farmer)==initialFarmer and birthSnapshot(noble)==initialNoble)
        assert(resources(farmer)==farmerResources and resources(noble)==nobleResources and #adapter.commands==4)
        panel.view.Close.onClick:Invoke()
        assert(not adapter.growthOpen and not Services.UI.IsWorldPaused and studio:GetValue(view)==nil and texture:GetValue(view)==nil)
    end)
end,debug.traceback)
if not ok then CloseBirthUIPreview();error(err,0) end
return table.concat(messages,'\n')
