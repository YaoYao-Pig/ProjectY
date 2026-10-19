-- Actual configured BattleAction widgets and cached BattleHUD in the existing independent Edit Mode fixture.
local fixture=assert(loadfile('Tools/Tests/battle_hud_fixture.lua'))()(Services)
local result
local ok,err=xpcall(function()
    local hud,ui,adapter=fixture.hud,fixture.ui,fixture.adapter
    local action=hud.actions[1];local reference=action.reference;local button=action.view.Button
    assert(action.row and action.row.available,'The initial preparation skill must be available')
    -- This independent Edit Mode clone must receive the same OnDisable callback that runs naturally in Play.
    action.view.Pointer.runInEditMode=true
    local pointer=CS.UnityEngine.EventSystems.PointerEventData(CS.UnityEngine.EventSystems.EventSystem.current)
    local function snap()
        local colors=button.colors;colors.fadeDuration=0;button.colors=colors
    end
    local function tint()return button.targetGraphic.canvasRenderer:GetColor()end
    local function same(a,b)return math.abs(a.r-b.r)<.001 and math.abs(a.g-b.g)<.001 and math.abs(a.b-b.b)<.001 end
    snap();local idle=tint()
    action.view.Pointer:OnPointerEnter(pointer);button:OnPointerEnter(pointer)
    local hover=tint();assert(action:IsHovered() and hover.r>idle.r*1.5,'Native pointer enter must visibly brighten the card')
    hud.dirty=true;ui:Tick(0,0)
    assert(action:IsHovered() and same(tint(),hover) and button.colors.fadeDuration==0,'HUD refresh reset native hover')
    adapter:SelectBattleSkill(action.row.id);ui:Tick(0,0)
    assert(action.view.Selected.gameObject.activeSelf and button.colors.normalColor.r>idle.r*2,'Shortcut selection must show the selected treatment')
    snap();action.view.Pointer:OnPointerExit(pointer);button:OnPointerExit(pointer)
    local selected=tint()
    assert(not action:IsHovered() and action.view.Selected.gameObject.activeSelf and same(selected,button.colors.normalColor),'Pointer exit must keep the selected skill visible')
    local row={};for key,value in pairs(action.row)do row[key]=value end;row.available=false;row.reason='测试不可用'
    action:SetData(row,1,true,hud.icons:Get(row.iconId));snap()
    action.view.Pointer:OnPointerEnter(pointer);button:OnPointerEnter(pointer)
    local disabled=tint();local selections=adapter.selections;button.onClick:Invoke()
    assert(not button.interactable and same(disabled,button.colors.disabledColor) and action:IsHovered() and adapter.selections==selections,'Disabled visual/tooltip/click guard differs')
    ui:Close('BattleHUD')
    local hiddenPointer=action:IsHovered()
    local hiddenSelection=action.view.Selected.gameObject.activeSelf
    local hiddenListeners=#fixture.battle.Changed.listeners
    assert(not hiddenPointer and not hiddenSelection and hiddenListeners==0,
        string.format('Hide state: pointer=%s selected=%s subscriptions=%d',tostring(hiddenPointer),tostring(hiddenSelection),hiddenListeners))
    local reopened=ui:Open('BattleHUD',{demo=adapter})
    assert(reopened==hud and reopened.actions[1].reference==reference,'The check must reuse the cached widget')
    assert(not action:IsHovered() and action.row.available and action.view.Selected.gameObject.activeSelf and #fixture.battle.Changed.listeners==1,'Cached reopen did not restore current model selection')
    adapter:SelectBattleMove();ui:Tick(0,0);assert(not action.view.Selected.gameObject.activeSelf,'Keyboard move projection failed to clear selection')
    selections=adapter.selections;button.onClick:Invoke();assert(adapter.selections==selections+1,'Cache reopen duplicated click listeners')
    result={idle={idle.r,idle.g,idle.b},hover={hover.r,hover.g,hover.b},selected={selected.r,selected.g,selected.b},disabled={disabled.r,disabled.g,disabled.b},
        hoverPreserved=true,keyboardSelection=true,pointerExit=true,disabledTooltip=true,cacheReuse=true,clickListeners=true}
end,debug.traceback)
fixture.registry:Shutdown()
if not ok then error(err,0)end
return result
