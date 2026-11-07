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
        private BlockParticleEffects spellFieldEffects;
        private int spellFieldSignature;
        private float spellFieldPulse;
        private BlockEffectCatalog effectCatalog;
        private readonly List<PendingEffect> pendingEffects=new List<PendingEffect>(128);
        private readonly Dictionary<Vector3Int,MapAreaViewData.Cell> effectCells=new Dictionary<Vector3Int,MapAreaViewData.Cell>();
        private readonly List<Vector3> spellFieldAnchors=new List<Vector3>(64);
        private void CreateVisualEffects()
        {
            if(effectCatalog==null) using (var root=(LuaTable)bootstrap.CallModule(Bridge,"visual_effect_catalog")[0]) effectCatalog=BlockEffectCatalog.Read(root);
            visualEffects=new BlockParticleEffects(transform,illuminate:true);
            spellFieldEffects=new BlockParticleEffects(transform,illuminate:true);
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
                if(profile.Pattern=="meteor" || profile.Pattern=="rockfall")target-=Vector3.up*.55f;
                var delay=impactDelay+Mathf.Max(0,item.Shot-1)*(Feedback!=null?Feedback.BurstHitInterval:.2f);
                if (item.Outcome=="pickup")
                { var swap=origin;origin=target;target=swap;delay=0; }
                bool miss=item.Outcome=="miss";
                if (miss) target+=new Vector3(.65f,0,.4f);
                if (BlockParticleEffects.LeadTime(profile.Pattern)==0f && item.SkillId!=0 && effectCatalog.Skills[item.SkillId].Trajectory!="sight" && (target-origin).sqrMagnitude>.1f)
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
            float lead=BlockParticleEffects.LeadTime(profile.Pattern);
            // A zero-delay settled event still needs a visible launch and descent.
            // Short actor animations let the VFX impact follow after its complete flight.
            pendingEffects.Add(new PendingEffect {Profile=profile,Origin=origin,Target=target,Seed=seed,
                Delay=Mathf.Max(0f,delay-lead),Scale=scale});
        }
        private void TickVisualEffects(float deltaTime)
        {
            if (deltaTime<=0) return;
            if (visualEffects==null && HasArea && view.SpellFields.Length>0) CreateVisualEffects();
            if (visualEffects==null) return;
            visualEffects.Tick(deltaTime);
            TickSpellFields(deltaTime);
            for (int i=0;i<pendingEffects.Count;)
            {
                var item=pendingEffects[i];item.Delay-=deltaTime;
                if (item.Delay>0) {i++;continue;}
                float advance=Mathf.Max(0f,-item.Delay);
                float lead=BlockParticleEffects.LeadTime(item.Profile.Pattern);
                // A delayed frame must not consume the whole flight before its first render.
                if(lead>0f)advance=Mathf.Min(advance,lead*.1f);
                visualEffects.Play(item.Profile,item.Origin,item.Target,item.Seed,item.Scale,advance);
                pendingEffects.RemoveAt(i);
            }
        }
        private void ClearVisualEffects()
        { pendingEffects.Clear();visualEffects?.Clear();ClearBattleAudio(); }
        private void DisposeVisualEffects()
        { ClearVisualEffects();visualEffects?.Dispose();spellFieldEffects?.Dispose();visualEffects=null;spellFieldEffects=null;
            spellFieldSignature=0;spellFieldPulse=0f;effectCatalog=null;effectCells.Clear(); }

        private void TickSpellFields(float deltaTime)
        {
            int signature=17;
            foreach(var field in view.SpellFields)
                signature=unchecked(signature*397 ^ field.Id ^ field.Q*31 ^ field.R*71 ^ field.Layer*131 ^ field.Radius*173 ^ field.VisualEffectId);
            if(signature!=spellFieldSignature)
            {spellFieldEffects.Clear();spellFieldSignature=signature;spellFieldPulse=0f;}
            spellFieldEffects.Tick(deltaTime);
            if(!HasArea || view.SpellFields.Length==0) return;
            spellFieldPulse-=deltaTime;
            if(spellFieldPulse>0f) return;
            spellFieldPulse=.8f;
            foreach(var field in view.SpellFields)
            {
                var source=effectCatalog.Profiles[field.VisualEffectId];
                string pattern;
                switch(field.Kind)
                {
                    case "fire": pattern="embers";break;
                    case "mist": pattern="mist";break;
                    case "mud": pattern="mud";break;
                    default: throw new InvalidOperationException("Unknown spell field: "+field.Kind);
                }
                var profile=BlockEffectCatalog.Variant(source,pattern,64,1.15f);
                profile.Radius=.75f;profile.Height=field.Kind=="mist"?.55f:.35f;
                profile.Size=field.Kind=="mist"?.2f:field.Kind=="fire"?.16f:.15f;
                profile.Speed=field.Kind=="fire"?1f:.16f;profile.Gravity=0f;
                if(field.Kind=="mist")profile.Emission=1.2f;
                if(field.Kind=="mud")profile.Emission=1f;
                spellFieldAnchors.Clear();
                if(!effectCells.TryGetValue(new Vector3Int(field.Q,field.R,field.Layer),out var center))
                    throw new InvalidOperationException("Spell field center is outside the displayed area: "+field.Id);
                var position=center.Position+Vector3.up*.08f;
                foreach(var index in field.Cells)
                {
                    spellFieldAnchors.Add(areaLayout.Cells[index-1].Position+Vector3.up*.08f);
                }
                if(spellFieldAnchors.Count==0)continue;
                profile.Count=Mathf.Min(64,spellFieldAnchors.Count*(field.Kind=="mist"?7:6));
                spellFieldEffects.Play(profile,position,position,field.Id,anchors:spellFieldAnchors);
            }
        }
    }
}
