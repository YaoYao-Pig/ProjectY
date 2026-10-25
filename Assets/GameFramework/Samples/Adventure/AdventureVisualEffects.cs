using System;
using System.Collections.Generic;
using UnityEngine;
using XLua;

namespace ProjectY.Samples
{
    public sealed partial class AdventureRuntimeDemo
    {
        private sealed class PendingEffect
        { public BlockEffectProfile Profile; public Vector3 Origin,Target; public int Seed; public float Delay,Scale; }
        private BlockParticleEffects visualEffects;
        private BlockEffectCatalog effectCatalog;
        private readonly List<PendingEffect> pendingEffects=new List<PendingEffect>(128);
        private readonly Dictionary<Vector3Int,MapAreaViewData.Cell> effectCells=new Dictionary<Vector3Int,MapAreaViewData.Cell>();
        private void CreateVisualEffects()
        {
            if(effectCatalog==null) using (var root=(LuaTable)bootstrap.CallModule(Bridge,"visual_effect_catalog")[0]) effectCatalog=BlockEffectCatalog.Read(root);
            visualEffects=new BlockParticleEffects(transform);
            effectCells.Clear();
            foreach (var cell in areaLayout.Cells) effectCells.Add(new Vector3Int(cell.Q,cell.R,cell.Layer),cell);
        }
        private Vector3 EffectPosition(int q,int r,int layer,int actorId)
        {
            if(layer==int.MinValue)
            {
                layer=areaLayout.Cells[view.Area.CellIndex].Layer;
                var member=Array.Find(view.Area.Members,value=>value.ActorId==actorId);
                if(member!=null) layer=areaLayout.Cells[member.CellIndex].Layer;
                else
                {
                    var actor=Array.Find(view.Area.Enemies,value=>value.Id==actorId)??Array.Find(view.Area.Defeated,value=>value.Id==actorId);
                    if(actor!=null) layer=areaLayout.Cells[actor.CellIndex].Layer;
                }
            }
            if (!effectCells.TryGetValue(new Vector3Int(q,r,layer),out var cell)) throw new InvalidOperationException("Visual effect is outside the displayed area.");
            return cell.Position+Vector3.up*.65f;
        }
        private void QueueVisualEffects(WorldEffectEvent[] events,float impactDelay)
        {
            if (!HasArea || events.Length==0) return;
            if (visualEffects==null) CreateVisualEffects();
            foreach (var item in events)
            {
                var origin=EffectPosition(item.SourceQ,item.SourceR,item.SourceLayer,item.SourceId);
                var target=EffectPosition(item.TargetQ,item.TargetR,item.TargetLayer,item.TargetId);
                var profile=item.SkillId!=0 ? effectCatalog.Skills[item.SkillId].Profile : effectCatalog.Items[item.ItemId];
                var delay=impactDelay+Mathf.Max(0,item.Shot-1)*(Feedback!=null?Feedback.BurstHitInterval:.2f);
                if (item.Outcome=="pickup")
                { var swap=origin;origin=target;target=swap;delay=0; }
                bool miss=item.Outcome=="miss";
                if (miss) target+=new Vector3(.65f,0,.4f);
                if (item.SkillId!=0 && effectCatalog.Skills[item.SkillId].Trajectory!="sight" && (target-origin).sqrMagnitude>.1f)
                {
                    var trail=BlockEffectCatalog.Variant(profile,effectCatalog.Skills[item.SkillId].Trajectory=="lobbed"?"arc":"beam",Mathf.Min(24,profile.Count),.24f);
                    AddVisualEffect(trail,origin,target,item.Sequence,Mathf.Max(0,delay-.16f),.6f);
                }
                if (!miss) AddVisualEffect(profile,origin,target,item.Sequence,delay,item.Outcome=="pickup"?.55f:1f);
                else AddVisualEffect(BlockEffectCatalog.Variant(profile,"shards",Mathf.Min(6,profile.Count),.25f),target,target,item.Sequence,delay,.35f);
            }
        }
        private void AddVisualEffect(BlockEffectProfile profile,Vector3 origin,Vector3 target,int seed,float delay,float scale)
        {
            if (pendingEffects.Count==128) pendingEffects.RemoveAt(0);
            pendingEffects.Add(new PendingEffect {Profile=profile,Origin=origin,Target=target,Seed=seed,Delay=delay,Scale=scale});
        }
        private void TickVisualEffects(float deltaTime)
        {
            if (visualEffects==null || deltaTime<=0) return;
            visualEffects.Tick(deltaTime);
            for (int i=0;i<pendingEffects.Count;)
            {
                var item=pendingEffects[i];item.Delay-=deltaTime;
                if (item.Delay>0) {i++;continue;}
                visualEffects.Play(item.Profile,item.Origin,item.Target,item.Seed,item.Scale);
                pendingEffects.RemoveAt(i);
            }
        }
        private void ClearVisualEffects()
        { pendingEffects.Clear();visualEffects?.Clear();ClearBattleAudio(); }
        private void DisposeVisualEffects()
        { ClearVisualEffects();visualEffects?.Dispose();visualEffects=null;effectCatalog=null;effectCells.Clear(); }
    }
}
