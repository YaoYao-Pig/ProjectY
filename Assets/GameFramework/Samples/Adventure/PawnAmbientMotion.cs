using System;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Per-character presentation RNG. Never consumes Unity or combat random state.</summary>
    public sealed class PawnAmbientMotion
    {
        private readonly PawnAnimationSet settings;
        private readonly System.Random random;
        private PawnAnimationSet.Hold hold;
        private PawnAnimationSet.AmbientVariant[] idlePool;
        private bool selected, moving;
        private float untilChange;
        public PawnAnimationSet.AmbientVariant Current { get; private set; }
        public float Phase { get; private set; }
        public float Rate { get; private set; }

        public PawnAmbientMotion(PawnAnimationSet settings,int identity)
        {
            this.settings=settings;
            random=new System.Random(unchecked(settings.VariationSeed ^ identity*73856093));
            Validate(settings.IdleVariants);Validate(settings.MoveVariants);
            CheckRange(settings.IdleChangeSeconds);CheckRange(settings.MoveChangeSeconds);
            CheckRange(settings.IdlePlaybackRange);CheckRange(settings.MovePlaybackRange);
        }
        private static void CheckRange(Vector2 range)
        {if(range.x<=0 || range.y<range.x)throw new InvalidOperationException("Invalid ambient animation range.");}
        private static void Validate(PawnAnimationSet.AmbientVariant[] variants)
        {
            if(variants==null || variants.Length==0)throw new InvalidOperationException("Pawn ambient animation pool is missing. Sync animation resources.");
            foreach(var v in variants)if(string.IsNullOrEmpty(v.State)||v.ReferenceClip==null||v.Weight<=0)
                throw new InvalidOperationException("Invalid pawn ambient animation variant.");
        }
        public bool Update(float deltaTime,PawnAnimationSet.Hold value,bool isMoving)
        {
            bool changedHold=hold!=value;
            if(changedHold)
            {
                hold=value;
                if(hold.IdleVariants==null || hold.IdleVariants.Length==0)throw new InvalidOperationException("Hold has no allowed idle variants: "+hold.PoseId);
                idlePool=new PawnAnimationSet.AmbientVariant[hold.IdleVariants.Length];
                for(int i=0;i<idlePool.Length;i++)idlePool[i]=Array.Find(settings.IdleVariants,v=>v.State==hold.IdleVariants[i])
                    ?? throw new InvalidOperationException("Unknown idle variant: "+hold.IdleVariants[i]);
            }
            untilChange-=Mathf.Max(0,deltaTime);
            if(selected && !changedHold && moving==isMoving && untilChange>0)return false;
            var pool=isMoving?settings.MoveVariants:idlePool;
            float total=0;foreach(var variant in pool)if(pool.Length==1||variant!=Current)total+=variant.Weight;
            float roll=(float)random.NextDouble()*total;
            PawnAnimationSet.AmbientVariant next=null;
            foreach(var variant in pool)
            {
                if(pool.Length>1&&variant==Current)continue;
                next=variant;roll-=variant.Weight;if(roll<=0)break;
            }
            if(next==null)throw new InvalidOperationException("Ambient pool has no distinct weighted choice.");
            Current=next;Phase=(float)random.NextDouble();Rate=Between(isMoving?settings.MovePlaybackRange:settings.IdlePlaybackRange);
            untilChange=Between(isMoving?settings.MoveChangeSeconds:settings.IdleChangeSeconds);
            moving=isMoving;selected=true;return true;
        }
        private float Between(Vector2 range) => Mathf.Lerp(range.x,range.y,(float)random.NextDouble());
    }
}
