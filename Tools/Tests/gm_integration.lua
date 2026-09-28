-- 独立 Edit Mode 环境中的 GM 命令、真实养成状态和实际面板按钮。
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local messages={}
local function test(name,body) body();messages[#messages+1]='PASS '..name end
function CloseGMPreview() registry:Shutdown();CloseGMPreview=nil end
local ok,err=xpcall(function()
    registry:Start()
    local adventure=registry:Get('Adventure');adventure:Start(412)
    local gm,ui=registry:Get('GM'),registry:Get('UI')
    local first,second=adventure.data:GetPartyAt(0),adventure.data:GetPartyAt(1)
    test('slot validation and unknown commands never mutate party state',function()
        local revision=first.Growth.Revision
        for _,slot in ipairs({0,-1,5,1.5}) do assert(not gm:Execute('level_up',slot)) end
        assert(not gm:Execute('missing',1));assert(not gm:Execute('grant_skill',1,999999))
        assert(first.Growth.Revision==revision and first.Growth.Level==1 and second.Growth.Level==1)
    end)
    test('level-up targets the selected slot and preserves standard configured rewards and offers',function()
        local growth=second.Growth;local attributes,talents=growth.AttributePoints,growth.TalentPoints
        local row=gm.growth.rules.levels:Get(2)
        assert(gm:Execute('level_up',2))
        assert(growth.Level==2 and first.Growth.Level==1 and growth.Experience==0)
        assert(growth.AttributePoints==attributes+row.attributePoints and growth.TalentPoints==talents+row.talentPoints)
        assert(growth.PendingCount==1 and growth.OfferCount>0)
    end)
    test('direct grants do not consume a level or research opportunity and remove duplicate offers',function()
        local growth=second.Growth;local pending,level=growth.PendingCount,growth.Level
        local offered=growth:GetOfferAt(0)
        assert(gm:Execute('grant_skill',2,offered));assert(growth:HasSkill(offered))
        for i=0,growth.OfferCount-1 do assert(growth:GetOfferAt(i)~=offered) end
        assert(growth.PendingCount==pending and growth.Level==level)
        assert(gm:Execute('grant_skill',2,201) and growth:HasSkill(201) and not first.Growth:HasSkill(201))
        local revision=growth.Revision
        assert(not gm:Execute('grant_skill',2,201));assert(growth.Revision==revision)
        local rows=adventure.characterSkills:Rows(second.Id,'life');assert(#rows==1 and rows[1].id==201)
    end)
    test('max-level commands stop at the configured cap without granting extra points',function()
        while second.Growth.Level<gm.growth.rules.maxLevel do assert(gm:Execute('level_up',2)) end
        local revision=second.Growth.Revision;assert(not gm:Execute('level_up',2));assert(second.Growth.Revision==revision)
    end)
    local demo={BattleHUDRevision=0,SelectedCharacterId=first.Id,LastError='',commands=0}
    function demo:SetGMOpen(value) self.open=value end
    function demo:SendCommand(command,slot,id)
        local success,why=gm:Execute(command:sub(4),slot,id)
        self.LastError=success and '' or why;self.BattleHUDRevision=self.BattleHUDRevision+1;self.commands=self.commands+1
    end
    local panel=ui:Open('GM',{demo=demo,font=GMFont})
    test('GM panel buttons use the standalone system and closing releases its world pause',function()
        assert(demo.open and Services.UI.IsWorldPaused and panel.view.Slot.text=='1')
        panel.view.Slot.text='0';panel.view.LevelUp.onClick:Invoke();assert(demo.commands==0 and panel.view.Result.text~='')
        panel.view.Slot.text='1';panel.view.LevelUp.onClick:Invoke();assert(first.Growth.Level==2 and demo.commands==1)
        panel.view.SkillId.text='201';panel.view.GrantSkill.onClick:Invoke();assert(first.Growth:HasSkill(201) and demo.commands==2)
        panel.view.GrantSkill.onClick:Invoke();assert(panel.view.Result.text:find('已掌握'))
        panel.view.Close.onClick:Invoke();assert(not demo.open and not Services.UI.IsWorldPaused and not ui:IsOpen('GM'))
        panel=ui:Open('GM',{demo=demo,font=GMFont});assert(panel.view.Result.text=='' and demo.open)
        panel.view.Slot.text='2';panel.view.SkillId.text='201';panel:Refresh()
        panel.view.Result.text='检查通过：槽位升级、技能授予与边界校验均正常。'
    end)
end,debug.traceback)
if not ok then CloseGMPreview();error(err,0) end
return 'GM integration: '..#messages..' checks passed\n'..table.concat(messages,'\n')
