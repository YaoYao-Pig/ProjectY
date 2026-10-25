using UnityEngine;
using UnityEngine.EventSystems;
using ProjectY.UI;

namespace ProjectY.Samples
{
    public sealed partial class AdventureRuntimeDemo
    {
        private bool gmKillSelecting;

        private void BeginGMKillSelection()
        {
            if(view==null || (view.Phase!="battle" && (view.Phase!="area" || !HasArea)))
            {
                if(view!=null){view.Error=LuaLanguage.Get("GMKillRequiresScene");BattleHUDRevision++;}
                return;
            }
            CancelCharacterSkill();CancelBattleSkillSelection();
            gmKillSelecting=true;view.Error="";BattleHUDRevision++;
        }

        private void CancelGMKillSelection()
        {
            if(!gmKillSelecting)return;
            gmKillSelecting=false;BattleHUDRevision++;
        }

        private void UpdateGMKillSelection()
        {
            if(view.Phase!="battle" && (view.Phase!="area" || !HasArea))
            {CancelGMKillSelection();return;}
            if(!HasArea)return; // The legacy battle board dispatches its click from DrawBattle.
            UpdateCameraInput();
            if(AnimationBusy || pendingExitView!=null || Input.GetMouseButton(2) ||
                (EventSystem.current!=null && EventSystem.current.IsPointerOverGameObject()) || PointerOverInterface())return;
            if(!Input.GetMouseButtonDown(0))return;
            var ray=mapCamera.ScreenPointToRay(Input.mousePosition);
            TryGMKillTarget(PickAreaActor(ray,areaRenderer.Pick(ray)));
        }

        private void TryGMKillTarget(int actorId)
        {
            if(!gmKillSelecting || AnimationBusy || pendingExitView!=null)return;
            if(actorId==0){view.Error=LuaLanguage.Get("GMKillInvalidTarget");BattleHUDRevision++;return;}
            var revision=BattleHUDRevision;
            SendCommand("gm_kill_target",actorId);
            if(BattleHUDRevision!=revision && string.IsNullOrEmpty(LastError))CancelGMKillSelection();
        }

        private void DrawGMKillSelection()
        {
            if(!gmKillSelecting || gmOpen)return;
            var width=Mathf.Min(620,Screen.width-40);
            var rect=new Rect((Screen.width-width)*.5f,Screen.height-100,width,40);
            Fill(rect,Panel);
            GUI.Label(new Rect(rect.x+12,rect.y+8,rect.width-24,24),LuaLanguage.Get("GMKillPickHint"),textStyle);
        }
    }
}
