using System;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>A small, bounded accent at an explicitly supplied equipment anchor.</summary>
    public sealed class EquipmentEffectDisplay : IDisposable
    {
        private readonly Transform owner;
        private BlockParticleEffects particles;
        private BlockEffectProfile profile;
        private float elapsed;
        private int seed;
        private readonly float interval, scale;
        private readonly int particleLimit;
        public EquipmentEffectDisplay(Transform owner, float interval=0, float scale=.3f, int particleLimit=5)
        {
            if(owner==null) throw new ArgumentNullException(nameof(owner));
            if(interval<0 || scale<=0 || particleLimit<1 || particleLimit>8) throw new ArgumentOutOfRangeException(nameof(interval));
            this.owner=owner;this.interval=interval;this.scale=scale;this.particleLimit=particleLimit;
        }
        public void Set(BlockEffectProfile value)
        {
            if (profile!=null && value!=null && profile.Id==value.Id) return;
            particles?.Clear();elapsed=0;seed=value==null?0:value.Id;
            profile=value==null?null:BlockEffectCatalog.Variant(value,value.Pattern,Mathf.Min(particleLimit,value.Count),Mathf.Min(.7f,value.Lifetime));
            if (profile!=null) {profile.Radius=Mathf.Min(.35f,profile.Radius);profile.Height=Mathf.Min(.4f,profile.Height);profile.Speed=Mathf.Min(.3f,profile.Speed);}
        }
        public void Tick(float deltaTime,Vector3 position)
        {
            if (profile==null || deltaTime<=0 || !owner.gameObject.activeInHierarchy) return;
            if (particles==null) particles=new BlockParticleEffects(owner,owner.gameObject.layer,true);
            particles.Tick(deltaTime);elapsed-=deltaTime;
            if (elapsed>0) return;
            // Slow pulses retain the silhouette and stay visible without portrait Bloom.
            particles.Play(profile,position,position,seed++,scale);
            elapsed=interval>0?interval:2.2f+(profile.Id%7)*.13f;
        }
        public void Clear() {particles?.Clear();elapsed=0;}
        public void Dispose() {particles?.Dispose();particles=null;profile=null;}
    }
}
