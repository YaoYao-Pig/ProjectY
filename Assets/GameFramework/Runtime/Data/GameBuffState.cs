using System;
using System.Collections.Generic;

namespace ProjectY.Data
{
    /// <summary>Typed reflection bridge for reusable component snapshots and absolute game-minute timers.</summary>
    public static class GameBuffState
    {
        public static void Configure(GameEffectInstanceData instance,int[] ids,int[] amounts,double expiresAt,double nextTickAt)
        {
            if(instance==null || ids==null || amounts==null || ids.Length!=amounts.Length || ids.Length>64 ||
                expiresAt<0 || nextTickAt<0 || double.IsNaN(expiresAt) || double.IsNaN(nextTickAt) || double.IsInfinity(expiresAt) || double.IsInfinity(nextTickAt))
                throw new ArgumentException("Invalid buff component snapshot or timer.");
            var seen=new HashSet<int>();
            for(int i=0;i<ids.Length;i++)if(ids[i]<1 || !seen.Add(ids[i]) || Math.Abs((long)amounts[i])>1000000)throw new ArgumentException("Invalid buff snapshot component.");
            instance.SnapshotIds=(int[])ids.Clone();instance.SnapshotAmounts=(int[])amounts.Clone();instance.ExpiresAt=expiresAt;instance.NextTickAt=nextTickAt;
        }
        public static int Count(GameEffectInstanceData instance)=>instance.SnapshotIds.Length;
        public static int EffectAt(GameEffectInstanceData instance,int index)=>instance.SnapshotIds[index];
        public static int Amount(GameEffectInstanceData instance,int effectId)
        {
            int index=Array.IndexOf(instance.SnapshotIds,effectId);if(index<0)throw new ArgumentException("Buff snapshot component is missing.");
            return instance.SnapshotAmounts[index];
        }
        public static double ExpiresAt(GameEffectInstanceData instance)=>instance.ExpiresAt;
        public static double NextTickAt(GameEffectInstanceData instance)=>instance.NextTickAt;
        public static void AdvanceTick(GameEffectInstanceData instance,double period)
        {
            double next=instance.NextTickAt+period;
            if(period<=0 || double.IsNaN(next) || double.IsInfinity(next) || next<=instance.NextTickAt)throw new ArgumentOutOfRangeException(nameof(period));
            instance.NextTickAt=next;
        }
    }
}
