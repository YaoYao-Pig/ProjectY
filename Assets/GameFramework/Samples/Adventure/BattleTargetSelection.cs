using System;
using System.Collections.Generic;
using ProjectY.UI;

namespace ProjectY.Samples
{
    /// <summary>Reflection-only UI bridge; selections are disposable presentation state.</summary>
    public static class BattleTargetSelection
    {
        public static bool Active(AdventureRuntimeDemo demo) => demo.IsSelectingBattleTargets;
        public static bool NeedsLanding(AdventureRuntimeDemo demo) => demo.IsSelectingBattleLandingSkill;
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
        private AdventureViewData.Trap hoveredBattleTrap;
        private int landingTargetId;
        private AdventureViewData.Cell landingSourceCell;
        private AdventureViewData.Cell[] battleLandingCells=Array.Empty<AdventureViewData.Cell>();
        private AdventureViewData.Skill ChosenBattleSkill => view?.Phase=="battle"?Array.Find(view.Skills,row=>row.Id==selectedSkill):null;
        internal bool IsSelectingBattleLandingSkill => ChosenBattleSkill?.NeedsLanding==true || ChosenBattleSkill?.NeedsCellLanding==true;
        private bool IsChoosingBattleLanding => IsSelectingBattleLandingSkill && (landingTargetId!=0 || landingSourceCell!=null);
        internal bool IsSelectingBattleTargets => ChosenBattleSkill?.ManualTargets==true || IsSelectingBattleLandingSkill;
        internal int SelectedBattleTargetCount => selectedBattleTargets.Count;
        internal int BattleTargetLimit => ChosenBattleSkill?.MaxTargets ?? 0;
        private void ClearBattleTargets() {selectedBattleTargets.Clear();hoveredBattleTarget=0;hoveredBattleTrap=null;landingTargetId=0;landingSourceCell=null;battleLandingCells=Array.Empty<AdventureViewData.Cell>();}
        internal void CancelBattleTargets() => CancelBattleSkillSelection();
        internal void ConfirmBattleTargets()
        {
            if(!IsSelectingBattleTargets || IsSelectingBattleLandingSkill || selectedBattleTargets.Count==0)return;
            SendCommandInternal("skill_targets",selectedSkill,0,0,selectedBattleTargets.ToArray());
        }
        internal void ChooseBattleTarget(int id)
        {
            var skill=ChosenBattleSkill;
            if(skill==null || view.Active.Team!=1 || pendingExitView!=null || AnimationBusy)return;
            if(skill.NeedsLanding)
            {
                if(Array.IndexOf(skill.Targets,id)<0){view.Error=LuaLanguage.Get("BattleSelectionInvalidTarget");BattleHUDRevision++;return;}
                var option=Array.Find(skill.LandingOptions,row=>row.TargetId==id);
                if(option==null)throw new InvalidOperationException("Missing landing options for a valid skill target.");
                if(option.Cells.Length==0){view.Error=LuaLanguage.Get("BattleSelectionNoLanding");BattleHUDRevision++;return;}
                landingTargetId=id;battleLandingCells=option.Cells;
                selectedBattleTargets.Clear();selectedBattleTargets.Add(id);
                hoveredBattleTarget=id;view.Error="";BattleHUDRevision++;return;
            }
            if(!skill.ManualTargets){SendCommand("skill",selectedSkill,id);return;}
            int existing=selectedBattleTargets.IndexOf(id);
            if(existing>=0)selectedBattleTargets.RemoveAt(existing);
            else
            {
                if(Array.IndexOf(skill.Targets,id)<0){view.Error=LuaLanguage.Get("BattleSelectionInvalidTarget");BattleHUDRevision++;return;}
                if(selectedBattleTargets.Count>=skill.MaxTargets){view.Error=LuaLanguage.Get("BattleSelectionFull");BattleHUDRevision++;return;}
                selectedBattleTargets.Add(id);
            }
            hoveredBattleTarget=id;view.Error="";BattleHUDRevision++;
        }
        private bool IsBattleLandingCell(int q,int r) => IsChoosingBattleLanding && Array.Exists(battleLandingCells,cell=>cell.Q==q && cell.R==r);
        private void ChooseBattleCell(int cellIndex)
        {
            var skill=ChosenBattleSkill;
            if(skill==null || view.Active.Team!=1 || pendingExitView!=null || AnimationBusy)return;
            if(!skill.NeedsCellLanding){SendCommand("skill_cell",selectedSkill,cellIndex+1);return;}
            var option=Array.Find(skill.CellLandingOptions,row=>row.Source.CellIndex==cellIndex);
            if(option==null || option.Cells.Length==0){view.Error=LuaLanguage.Get("BattleSelectionNoLanding");BattleHUDRevision++;return;}
            landingSourceCell=option.Source;landingTargetId=0;battleLandingCells=option.Cells;
            selectedBattleTargets.Clear();view.Error="";BattleHUDRevision++;
        }
        private void ChooseBattleLanding(int q,int r)
        {
            if(!IsChoosingBattleLanding || view.Active.Team!=1 || pendingExitView!=null || AnimationBusy)return;
            if(!IsBattleLandingCell(q,r)){view.Error=LuaLanguage.Get("BattleSelectionInvalidLanding");BattleHUDRevision++;return;}
            if(landingSourceCell!=null)
                SendCommandInternal("skill_at_landing",selectedSkill,0,0,new[]{landingSourceCell.Q,landingSourceCell.R,q,r});
            else SendCommandInternal("skill_landing",selectedSkill,0,0,new[]{landingTargetId,q,r});
        }
        private void SyncBattleTargets(AdventureViewData previous,AdventureViewData next)
        {
            if(previous==null || next.Phase!="battle" || previous.Phase!=next.Phase || previous.ActiveId!=next.ActiveId || previous.Round!=next.Round || previous.BattlePhase!=next.BattlePhase)
            {ClearBattleTargets();selectedSkill=0;moveSelected=next.Reachable.Length>0;return;}
            var skill=Array.Find(next.Skills,row=>row.Id==selectedSkill);
            if(skill==null){ClearBattleTargets();selectedSkill=0;return;}
            if(skill.NeedsCellLanding && landingSourceCell!=null)
            {
                var option=Array.Find(skill.CellLandingOptions,row=>row.Source.CellIndex==landingSourceCell.CellIndex);
                if(option==null || option.Cells.Length==0)ClearBattleTargets();
                else {landingSourceCell=option.Source;battleLandingCells=option.Cells;}
            }
            else if(skill.NeedsLanding && landingTargetId!=0)
            {
                var option=Array.Find(skill.LandingOptions,row=>row.TargetId==landingTargetId);
                if(Array.IndexOf(skill.Targets,landingTargetId)<0 || option==null || option.Cells.Length==0)ClearBattleTargets();
                else battleLandingCells=option.Cells;
            }
            else if(!skill.ManualTargets)selectedBattleTargets.Clear();
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
        private void SetBattleCellHover(AdventureViewData.Cell cell)
        {
            var trap=cell==null?null:Array.Find(view.Traps,row=>row.Q==cell.Q && row.R==cell.R);
            if(trap==hoveredBattleTrap)return;
            hoveredBattleTrap=trap;BattleHUDRevision++;
        }
        private AdventureViewData.TargetPreview TargetPreview(int id)
        {
            var skill=ChosenBattleSkill;
            return skill==null?null:Array.Find(skill.TargetPreviews,row=>row.Id==id);
        }
        private string TargetName(int id) => Array.Find(view.Units,row=>row.Id==id)?.Name ?? "";
        private static string RiskText(AdventureViewData.TargetPreview preview)
        {
            var text=LuaLanguage.Format("BattleSelectionHit",preview.HitChance);
            if(preview.InterceptChance>0)text=LuaLanguage.Format("BattleSelectionIntercept",text,preview.InterceptChance);
            if(preview.FriendlyRisk)text=LuaLanguage.Format("BattleSelectionFriendlyRisk",text);
            return text;
        }
        internal string BattleTargetHint()
        {
            var skill=ChosenBattleSkill;if(skill==null)return "";
            if(skill.NeedsCellLanding)return LuaLanguage.Get(IsChoosingBattleLanding?"BattleSelectionConstructionLandingHint":"BattleSelectionConstructionHint");
            if(skill.NeedsLanding)return IsChoosingBattleLanding
                ?LuaLanguage.Format("BattleSelectionLandingHint",TargetName(landingTargetId))
                :LuaLanguage.Get("BattleSelectionLandingTargetHint");
            int id=hoveredBattleTarget!=0?hoveredBattleTarget:selectedBattleTargets.Count>0?selectedBattleTargets[selectedBattleTargets.Count-1]:0;
            var preview=TargetPreview(id);
            if(preview!=null)return skill.ManualTargets?LuaLanguage.Format("BattleSelectionCountRisk",selectedBattleTargets.Count,skill.MaxTargets,RiskText(preview)):RiskText(preview);
            return skill.ManualTargets?LuaLanguage.Format("BattleSelectionTargetHint",selectedBattleTargets.Count,skill.MaxTargets):"";
        }
        internal string BattleTargetPreviewTitle() => hoveredBattleTrap!=null?hoveredBattleTrap.Name:TargetPreview(hoveredBattleTarget)==null?"":TargetName(hoveredBattleTarget);
        internal string BattleTargetPreviewBody()
        {
            if(hoveredBattleTrap!=null)return LuaLanguage.Get("BattleSelectionTrapHelp");
            var preview=TargetPreview(hoveredBattleTarget);if(preview==null)return "";
            var text=RiskText(preview);
            if(preview.BlockerCount>0)text=LuaLanguage.Format("BattleSelectionBlockers",text,preview.BlockerCount);
            if(!string.IsNullOrEmpty(preview.Description))text+="\n"+preview.Description;
            if(IsSelectingBattleLandingSkill)text+="\n"+BattleTargetHint();
            else if(IsSelectingBattleTargets)text=LuaLanguage.Format("BattleSelectionMultipleHelp",text,BattleTargetLimit);
            return text;
        }
    }
}
