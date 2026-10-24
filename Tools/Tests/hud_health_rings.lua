-- Executed by GroundHealthValidation in a PreviewScene with real saved UI bindings.
local Health=require('UI.Widget.HudHealth')
local widget=Health({log=print},RingReference)
widget.effects={}
local demo={WorldCamera=RingCamera}
function demo:HealthTarget()return RingHead end
function demo:HealthFootTarget()return RingFoot end
function demo:HealthRingRadius()return .8 end
function demo:HealthScreenPosition()return CS.UnityEngine.Vector2(400,400) end
function demo:HealthFootScreenPosition()return CS.UnityEngine.Vector2(400,300) end
local row={id=1,healthId=1,name='测试角色',team=1,hp=20,maxHP=20,ap=2,maxAP=4,effects={}}
widget:SetData(row,RingStyle,demo,nil,RingFeedback)
RingStyle:UpdateFollowers()
assert(widget.view.Health.fillAmount==1 and widget.view.AP.fillAmount==.5)
assert(not widget.view.Name.gameObject.activeSelf,'No persistent nameplate above the actor')
assert(widget.view.Follower.ProjectedVisible and widget.view.DamageFollower.ProjectedVisible)
assert(widget.view.WorldCanvas.renderMode==CS.UnityEngine.RenderMode.WorldSpace)
widget:OnHide()
assert(not widget.view.Follower.ProjectedVisible and not widget.view.DamageFollower.ProjectedVisible)
widget:OnShow();RingStyle:UpdateFollowers()
assert(widget.view.Follower.ProjectedVisible and widget.view.DamageFollower.ProjectedVisible)
row.screen=true;row.ap=0;widget:SetData(row,RingStyle,demo,nil,RingFeedback);widget:Tick();RingStyle:UpdateFollowers()
assert(widget.view.WorldCanvas.renderMode==CS.UnityEngine.RenderMode.ScreenSpaceOverlay)
assert(widget.view.AP.fillAmount==0 and widget.view.APText.text=='0/4 AP')
row.screen=false;row.healthId=2;row.hp=10;widget:SetData(row,RingStyle,demo,nil,RingFeedback)
assert(widget.view.WorldCanvas.renderMode==CS.UnityEngine.RenderMode.WorldSpace)
assert(widget.view.HealthAnimation.ForegroundFraction==.5,'Changing mount/health owner resets both rings')
widget:Retire();widget:SetData(nil)
assert(not widget.view.Follower.ProjectedVisible and not widget.view.DamageFollower.ProjectedVisible)
return 'PASS: actual HudHealth Lua binding, HP/AP fractions, head/foot tracking, hide/reopen, 2D mode, mount owner reset and retirement'
