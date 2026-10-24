-- Actual HUD controller, LuaReference, widgets and native tooltip. Isolated Edit Mode host.
local fixture=assert(loadfile('Tools/Tests/battle_hud_fixture.lua'))()(Services)
local ok,err=xpcall(function()
    local hud,ui=fixture.hud,fixture.ui
    local first=hud.actions[1];assert(first.row and first.row.skill)
    first.view.Pointer:OnPointerEnter(nil);hud:Tick()
    assert(hud.view.SkillTip.Visible and #hud.skillTip.stack==1,'Actual widget hover did not open the new card')
    assert(not hud.view.Tooltip.gameObject.activeSelf,'Old concatenated tip overlapped the new card')
    local rootPage=hud.skillTip.stack[1]
    assert(rootPage.title==first.row.name and #rootPage.stats>=5)
    local term=hud.skillTip.model.catalog:Term('hit')
    hud.skillTip.stack[2]={title=term.title,body=term.body,tags={},stats={},synergies={},termId='hit',breadcrumb='术语释义'}
    hud.skillTip:Render(hud.skillTip.stack[2]);fixture.adapter.BattleHUDRevision=fixture.adapter.BattleHUDRevision+1;hud:Tick()
    assert(#hud.skillTip.stack==2,'Target hover revision discarded active terminology navigation')
    hud.view.Group.interactable=false;hud:Tick()
    assert(not hud.view.SkillTip.Visible and #hud.skillTip.stack==0,'Modal blocking retained a clickable tip')
    hud.view.Group.interactable=true;hud:Tick();assert(hud.view.SkillTip.Visible)
    ui:Close('BattleHUD');assert(not hud.view.SkillTip.Visible and #hud.skillTip.stack==0)
    hud=ui:Open('BattleHUD',{demo=fixture.adapter})
    assert(not hud.view.SkillTip.Visible and #hud.skillTip.stack==0,'Cached reopen retained tooltip state')
    assert(#fixture.battle.Changed.listeners==1,'Cached tooltip integration duplicated a battle subscription')
end,debug.traceback)
fixture.registry:Shutdown()
if not ok then error(err,0)end
return 'PASS actual HUD hover, LuaReference binding, structured card, modal blocking, hidden overlap and cached lifecycle'
