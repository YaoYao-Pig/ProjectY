using System;
using System.Collections.Generic;

namespace ProjectY.Samples
{
    /// <summary>Reflection-only UI bridge; selections are disposable presentation state.</summary>
    public static class BattleTargetSelection
    {
        public static bool Active(AdventureRuntimeDemo demo) => demo.IsSelectingBattleTargets;
        public static int Count(AdventureRuntimeDemo demo) => demo.SelectedBattleTargetCount;
        public static int Limit(AdventureRuntimeDemo demo) => demo.BattleTargetLimit;
        public static string Hint(AdventureRuntimeDemo demo) => demo.BattleTargetHint();
        public static string PreviewTitle(AdventureRuntimeDemo demo) => demo.BattleTargetPreviewTitle();
        public static string PreviewBody(AdventureRuntimeDemo demo) => demo.BattleTargetPreviewBody();
        public static void Toggle(AdventureRuntimeDemo demo,int id) => demo.ChooseBattleTarget(id);
        public static void Confirm(AdventureRuntimeDemo demo) => demo.ConfirmBattleTargets();
        public static void Cancel(AdventureRuntimeDemo demo) => demo.CancelBattleTargets();
    }

    public sealed partial class AdventureRuntimeDemo
    {
        private readonly List<int> selectedBattleTargets=new List<int>();
        private int hoveredBattleTarget;
        private AdventureViewData.Skill ChosenBattleSkill => view?.Phase=="battle"?Array.Find(view.Skills,row=>row.Id==selectedSkill):null;
        internal bool IsSelectingBattleTargets => ChosenBattleSkill?.ManualTargets==true;
        internal int SelectedBattleTargetCount => selectedBattleTargets.Count;
        internal int BattleTargetLimit => ChosenBattleSkill?.MaxTargets ?? 0;
        private void ClearBattleTargets() {selectedBattleTargets.Clear();hoveredBattleTarget=0;}
        internal void CancelBattleTargets() => CancelBattleSkillSelection();
        internal void ConfirmBattleTargets()
        {
            if(!IsSelectingBattleTargets || selectedBattleTargets.Count==0)return;
            SendCommandInternal("skill_targets",selectedSkill,0,0,selectedBattleTargets.ToArray());
        }
        internal void ChooseBattleTarget(int id)
        {
            var skill=ChosenBattleSkill;
            if(skill==null || view.Active.Team!=1 || pendingExitView!=null || AnimationBusy)return;
            if(!skill.ManualTargets){SendCommand("skill",selectedSkill,id);return;}
            int existing=selectedBattleTargets.IndexOf(id);
            if(existing>=0)selectedBattleTargets.RemoveAt(existing);
            else
            {
                if(Array.IndexOf(skill.Targets,id)<0){view.Error="请选择射程内的合法敌人";BattleHUDRevision++;return;}
                if(selectedBattleTargets.Count>=skill.MaxTargets){view.Error="已选满目标；再次点击已选目标可取消";BattleHUDRevision++;return;}
                selectedBattleTargets.Add(id);
            }
            hoveredBattleTarget=id;view.Error="";BattleHUDRevision++;
        }
        private void SyncBattleTargets(AdventureViewData previous,AdventureViewData next)
        {
            if(previous==null || next.Phase!="battle" || previous.Phase!=next.Phase || previous.ActiveId!=next.ActiveId || previous.Round!=next.Round || previous.BattlePhase!=next.BattlePhase)
            {ClearBattleTargets();selectedSkill=0;moveSelected=next.Reachable.Length>0;return;}
            var skill=Array.Find(next.Skills,row=>row.Id==selectedSkill);
            if(skill==null){ClearBattleTargets();selectedSkill=0;return;}
            if(!skill.ManualTargets)selectedBattleTargets.Clear();
            else
            {
                selectedBattleTargets.RemoveAll(id=>Array.IndexOf(skill.Targets,id)<0);
                if(selectedBattleTargets.Count>skill.MaxTargets)selectedBattleTargets.RemoveRange(skill.MaxTargets,selectedBattleTargets.Count-skill.MaxTargets);
            }
            if(!Array.Exists(next.Units,row=>row.Id==hoveredBattleTarget && row.HP>0))hoveredBattleTarget=0;
        }
        private void SetBattleTargetHover(int id)
        {
            if(ChosenBattleSkill==null)id=0;
            if(hoveredBattleTarget==id)return;
            hoveredBattleTarget=id;BattleHUDRevision++;
        }
        private AdventureViewData.TargetPreview TargetPreview(int id)
        {
            var skill=ChosenBattleSkill;
            return skill==null?null:Array.Find(skill.TargetPreviews,row=>row.Id==id);
        }
        private string TargetName(int id) => Array.Find(view.Units,row=>row.Id==id)?.Name ?? "";
        private static string RiskText(AdventureViewData.TargetPreview preview)
        {
            var text=$"命中 {preview.HitChance:0.#}%";
            if(preview.InterceptChance>0)text+=$" · 误击 {preview.InterceptChance:0.#}%";
            if(preview.FriendlyRisk)text+=" · 有友军风险";
            return text;
        }
        internal string BattleTargetHint()
        {
            var skill=ChosenBattleSkill;if(skill==null)return "";
            int id=hoveredBattleTarget!=0?hoveredBattleTarget:selectedBattleTargets.Count>0?selectedBattleTargets[selectedBattleTargets.Count-1]:0;
            var preview=TargetPreview(id);
            string prefix=skill.ManualTargets?$"已选 {selectedBattleTargets.Count}/{skill.MaxTargets} · ":"";
            if(preview!=null)return prefix+RiskText(preview);
            return skill.ManualTargets?prefix+"点击敌人切换 · Enter 确认 · Esc 取消":"";
        }
        internal string BattleTargetPreviewTitle() => TargetPreview(hoveredBattleTarget)==null?"":TargetName(hoveredBattleTarget);
        internal string BattleTargetPreviewBody()
        {
            var preview=TargetPreview(hoveredBattleTarget);if(preview==null)return "";
            var text=RiskText(preview);
            if(preview.BlockerCount>0)text+=$"\n弹道经过 {preview.BlockerCount} 处遮挡";
            if(!string.IsNullOrEmpty(preview.Description))text+="\n"+preview.Description;
            if(IsSelectingBattleTargets)text+="\n点击切换选择；可选 1 至 "+BattleTargetLimit+" 个不同敌人。Enter 确认，Esc 取消。";
            return text;
        }
    }
}
