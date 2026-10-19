-- 真实 Camp Prefab、LuaReference、分类点击与框架暂停；宿主提供 CampFont / 临时存档。
local main=require('Main');local adventure=main:Get('Adventure');local ui=main:Get('UI')
adventure:Start(412);adventure.player:AddCoins(1000)
for _,id in ipairs({81,82,83}) do assert(adventure.equipment:Grant(id,40)) end
local camp=adventure.camp;assert(camp:Open())
local demo={MainHudFont=assert(CampFont),LastError='',BattleHUDRevision=0,SetStoryOpen=function(self,value)self.storyOpen=value end}
function demo:SendCommand(command,a,b,c)
    local methods={camp_upgrade='Upgrade',camp_produce='Produce',camp_claim='Claim',camp_wait='Wait',camp_deposit='Deposit',camp_withdraw='Withdraw'}
    local ok,reason
    if command=='camp_close' then ok,reason=camp:Close();ui:Close('Camp')
    else ok,reason=camp[assert(methods[command],command)](camp,a,b,c) end
    self.LastError=ok and '' or reason;self.BattleHUDRevision=self.BattleHUDRevision+1
end
local scale=CS.UnityEngine.Time.timeScale;ui:Open('Camp',{demo=demo})
local ctrl=ui.panels.Camp.ctrl
assert(Services.UI.IsWorldPaused and CS.UnityEngine.Time.timeScale==0)
assert(ctrl.view.Title.text=='远征营地' and ctrl.view.Caption.text:find('仓库'))
local function clickTitle(fragment)
    for _,widget in ipairs(ctrl.rows) do if widget.row and widget.row.title:find(fragment,1,true) then
        assert(widget.view.Button.interactable,'Unavailable button: '..fragment);widget.view.Button.onClick:Invoke();ctrl:Tick();assert(demo.LastError=='',demo.LastError);return
    end end
    error('Missing camp button: '..fragment)
end
clickTitle('工作台');assert(camp.data:GetLevel(1)==1)
clickTitle('生产与领取');clickTitle('压制巡猎弹药');assert(camp.data.JobCount==1)
clickTitle('等待生产');clickTitle('等待 1 小时')
clickTitle('生产与领取');local ammo=adventure.equipment.data:CountItem(31);clickTitle('领取 · 压制巡猎弹药');assert(adventure.equipment.data:CountItem(31)==ammo+12)
clickTitle('仓库存取');clickTitle('存入 营造木料');assert(camp.data:Stored(81)==10)
clickTitle('取出 营造木料');assert(camp.data:Stored(81)==0)
ctrl.view.Close.onClick:Invoke();assert(not camp.data.IsOpen and not ui:IsOpen('Camp') and not Services.UI.IsWorldPaused and CS.UnityEngine.Time.timeScale==scale)
assert(camp:Open());ui:Open('Camp',{demo=demo});assert(ui.panels.Camp.ctrl==ctrl);ui:Back()
assert(not camp.data.IsOpen and not demo.storyOpen and not Services.UI.IsWorldPaused)
main:Shutdown();return 'PASS camp UI: real bindings, category navigation, upgrade, timed production, actual claim, storage transfers, close, cached reopen and Back release'
