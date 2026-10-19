local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Rich=require('UI.RichText')
local Camp=Class('CampCtr',Base)
local sections={{'build','建设设施'},{'production','生产与领取'},{'storage','仓库存取'},{'wait','等待生产'}}
function Camp:Bind()
    self.model=self.context.systems:Get('Adventure').camp;self.rows={}
    self:Listen(self.view.Close,function() self.demo:SendCommand('camp_close',0,0) end)
end
function Camp:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetStoryOpen(true);self.section='build'
    self.view.Style:Prepare(self.demo.MainHudFont,960);self:Refresh();self.view.Scroll.verticalNormalizedPosition=1
end
function Camp:Refresh()
    if not self.model.data.IsOpen then return end
    local snapshot=self.model:Snapshot();local version=snapshot.version;local rows={}
    local minute=math.floor(snapshot.minutes%1440)
    self.view.Title.text='远征营地'
    self.view.Caption.text=string.format('第 %d 天 %02d:%02d  |  %d 金币  |  仓库 %d/%d  |  生产订单 %d',
        math.floor(snapshot.minutes/1440)+1,minute//60,minute%60,snapshot.coins,snapshot.stored,snapshot.capacity,snapshot.jobs)
    -- 页面分类属于显示状态；设施、物品和时间始终从 CampData / NarrativeData 读取。
    for _,section in ipairs(sections) do
        local id=section[1]
        rows[#rows+1]={title=(id==self.section and '● ' or '○ ')..section[2],body='',selected=id==self.section,action=function()
            self.section=id;self:Refresh();self.view.Scroll.verticalNormalizedPosition=1
        end}
    end
    for _,row in ipairs(snapshot.rows) do if row.section==self.section then
        local command,id,count=row.command,row.id,row.count
        rows[#rows+1]={title=Rich.Escape(row.title),body=Rich.Escape(row.body),available=row.available,
            action=command and function() self.demo:SendCommand(command,id,version,count) end or nil}
    end end
    for i,row in ipairs(rows) do
        if not self.rows[i] then self.rows[i]=self:CreateWidget('NarrativeEntry',self.view.Content) end
        self.rows[i]:SetData(row,self.demo.MainHudFont,row.action)
    end
    for i=#rows+1,#self.rows do self.rows[i]:SetData(nil) end
    self.view.Hint.text=self.demo.LastError~='' and self.demo.LastError or '材料优先使用仓库；金币、材料或空间不足时，交易不改变资源。'
    self.revision=version;self.equipmentRevision=self.model.adventure.equipment.data.Revision
    self.coins=snapshot.coins;self.minutes=math.floor(snapshot.minutes);self.demoRevision=self.demo.BattleHUDRevision
end
function Camp:Tick()
    if not self.model.data.IsOpen then return end
    local adventure=self.model.adventure
    if self.revision~=self.model.data.Revision or self.equipmentRevision~=adventure.equipment.data.Revision or
        self.coins~=adventure.player.Coins or self.minutes~=math.floor(adventure.narrative.data.Minutes) or self.demoRevision~=self.demo.BattleHUDRevision then self:Refresh() end
end
function Camp:OnHide()
    if self.model.data.IsOpen then self.model:Close() end
    if self.demo then self.demo:SetStoryOpen(false);self.demo=nil end
end
return Camp
