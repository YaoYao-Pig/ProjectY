using System;

namespace ProjectY.Data
{
    [Serializable] internal sealed class BodyInjurySave
    {
        public int damage, kind, health, maximum;
        public bool permanent;
        public int recoveryAmount;
        public double recoveryAt;
    }

    public sealed partial class CombatActorData
    {
        internal readonly BodyInjurySave[] BodyInjuries = CreateHealthyBody(1);
        internal int BodyRevision;
        private static readonly int[] BodyWeights = {10,30,15,15,15,15};
        internal static int[] BodyMaximums(int total)
        {
            var values=new int[6];int assigned=0;
            for(int i=0;i<6;i++){values[i]=(int)((long)total*BodyWeights[i]/100);assigned+=values[i];}
            // Assign remaining integer HP by largest fractional remainder, with stable index ties.
            var used=new bool[6];
            while(assigned<total)
            {
                int best=-1;
                for(int i=0;i<6;i++)if(!used[i] && (best<0 || (long)total*BodyWeights[i]%100>(long)total*BodyWeights[best]%100))best=i;
                values[best]++;used[best]=true;assigned++;
            }
            return values;
        }
        internal static BodyInjurySave[] CreateHealthyBody(int maximum=0)
        {
            var result = new BodyInjurySave[6];
            var sizes=BodyMaximums(maximum);
            for (int i = 0; i < result.Length; i++) result[i] = new BodyInjurySave {maximum=sizes[i],health=sizes[i]};
            return result;
        }
        internal int TotalBodyHealth(bool maximum)
        {int value=0;foreach(var row in BodyInjuries)value+=maximum?row.maximum:row.health;return value;}
        internal void ResizeBody(int maximum)
        {
            if(maximum<1 || maximum>1000000)throw new ArgumentOutOfRangeException(nameof(maximum));
            if(maximum==MaxHP)return;
            bool dead=HP==0;var sizes=BodyMaximums(maximum);
            for(int i=0;i<6;i++)
            {
                var row=BodyInjuries[i];row.health=dead || row.permanent?0:Math.Max(0,Math.Min(sizes[i],row.health+sizes[i]-row.maximum));
                row.maximum=sizes[i];
            }
            if(!dead && HP==0)HealBody(1);
            BodyRevision++;
        }
        internal void SetBodyHealth(int value)
        {
            if(value<0 || value>MaxHP)throw new ArgumentOutOfRangeException(nameof(value));
            int difference=value-HP;
            if(difference>0)HealBody(difference);else if(difference<0)DamageBody(-difference,-1,0,false);
        }
        internal int HealBody(int amount)
        {
            int missing=0;foreach(var row in BodyInjuries)if(!row.permanent)missing+=row.maximum-row.health;
            int actual=Math.Min(missing,amount),remaining=actual;
            if(actual==0)return 0;
            foreach(var row in BodyInjuries)if(!row.permanent)
            {int share=(int)((long)actual*(row.maximum-row.health)/missing);row.health+=share;remaining-=share;}
            foreach(var row in BodyInjuries)if(remaining>0 && !row.permanent && row.health<row.maximum){row.health++;remaining--;}
            BodyRevision++;return actual;
        }
        internal int DamageBody(int amount,int part,int kind,bool disableEmpty)
        {
            if(amount<0 || part < -1 || part>=6)throw new ArgumentOutOfRangeException(nameof(amount));
            if(amount==0 || HP==0)return 0;
            int before=HP,remaining=amount;
            if(part>=0)
            {
                var row=BodyInjuries[part];
                if(disableEmpty && row.maximum>0 && row.health==0 && !row.permanent)
                {row.permanent=true;row.damage=100;row.kind=kind;row.recoveryAmount=0;row.recoveryAt=0;}
                int taken=Math.Min(row.health,remaining);row.health-=taken;remaining-=taken;
            }
            int available=HP;remaining=Math.Min(remaining,available);int spill=remaining;
            if(available>0 && remaining>0)
            {
                foreach(var row in BodyInjuries){int share=(int)((long)spill*row.health/available);row.health-=share;remaining-=share;}
                foreach(var row in BodyInjuries)if(remaining>0 && row.health>0){row.health--;remaining--;}
            }
            BodyRevision++;return before-HP;
        }
        // Upgrade the old independent trauma/HP records while retaining permanent injuries and recovery schedules.
        internal static void MigrateBody(BodyInjurySave[] rows,int maximum,ref int health)
        {
            SaveCheck.Require(rows!=null && rows.Length==6 && maximum>0 && health>=0 && health<=maximum,ProjectY.UI.LuaLanguage.Get("BodySaveLegacy"));
            var sizes=BodyMaximums(maximum);int capacity=0;
            for(int i=0;i<6;i++){SaveCheck.Require(rows[i]!=null && rows[i].permanent==(rows[i].damage==100),ProjectY.UI.LuaLanguage.Get("BodySaveLegacyPart"));rows[i].maximum=sizes[i];rows[i].health=0;if(!rows[i].permanent)capacity+=sizes[i];}
            health=Math.Min(health,capacity);int remaining=health;
            if(capacity>0)
            {
                foreach(var row in rows)if(!row.permanent){row.health=(int)((long)health*row.maximum/capacity);remaining-=row.health;}
                foreach(var row in rows)if(remaining>0 && !row.permanent && row.health<row.maximum){row.health++;remaining--;}
            }
        }
        internal BodyInjurySave[] CaptureBody()
        {
            var result = new BodyInjurySave[6];
            for (int i = 0; i < result.Length; i++)
            {
                var part = BodyInjuries[i];
                result[i] = new BodyInjurySave { damage = part.damage, kind = part.kind, permanent = part.permanent, health=part.health, maximum=part.maximum,
                    recoveryAmount = part.recoveryAmount, recoveryAt = part.recoveryAt };
            }
            return result;
        }
        internal void RestoreBody(BodyInjurySave[] rows)
        {
            SaveCheck.Require(rows != null && rows.Length == 6, ProjectY.UI.LuaLanguage.Get("BodySaveMissing"));
            foreach (var row in rows)
                SaveCheck.Require(row != null && row.damage >= 0 && row.damage <= 100 &&
                    (row.damage == 0 ? row.kind == 0 : row.kind > 0) && row.maximum>=0 && row.health>=0 && row.health<=row.maximum &&
                    (!row.permanent || row.health==0 && row.damage==100) &&
                    row.recoveryAmount >= 0 && row.recoveryAmount <= row.damage && !double.IsNaN(row.recoveryAt) && !double.IsInfinity(row.recoveryAt) &&
                    (row.recoveryAmount == 0 ? row.recoveryAt == 0 : !row.permanent && row.recoveryAt > 0), ProjectY.UI.LuaLanguage.Get("BodySaveState"));
            int total=0,maximum=0;var expected=BodyMaximums(MaxHP);
            for(int i=0;i<6;i++){total+=rows[i].health;maximum+=rows[i].maximum;SaveCheck.Require(rows[i].maximum==expected[i],ProjectY.UI.LuaLanguage.Get("BodySaveCapacity"));}
            SaveCheck.Require(total==HP && maximum==MaxHP,ProjectY.UI.LuaLanguage.Get("BodySaveTotals"));
            for (int i = 0; i < rows.Length; i++)
                BodyInjuries[i] = new BodyInjurySave { damage = rows[i].damage, kind = rows[i].kind, permanent = rows[i].permanent, health=rows[i].health, maximum=rows[i].maximum,
                    recoveryAmount = rows[i].recoveryAmount, recoveryAt = rows[i].recoveryAt };
            BodyRevision++;
        }
    }

    /// <summary>Actor-owned injuries. The static bridge also works without regenerated actor wrappers.</summary>
    public static class BodyHealth
    {
        private static BodyInjurySave Part(CombatActorData actor, int part)
        {
            if (actor == null) throw new ArgumentNullException(nameof(actor));
            if (part < 0 || part >= 6) throw new ArgumentOutOfRangeException(nameof(part));
            return actor.BodyInjuries[part];
        }
        public static int Revision(CombatActorData actor) => actor.BodyRevision;
        public static int HP(CombatActorData actor,int part) => Part(actor,part).health;
        public static int MaximumHP(CombatActorData actor,int part) => Part(actor,part).maximum;
        public static int RecoverableHP(CombatActorData actor)
        {int value=0;foreach(var row in actor.BodyInjuries)if(!row.permanent)value+=row.maximum;return value;}
        public static int Hit(CombatActorData actor,int part,int amount,int kind)
        {
            Part(actor,part);
            if(actor.MountedAnimal!=null || kind<1)throw new ArgumentException("Part damage needs an unmounted target and a valid trauma kind");
            return actor.DamageBody(amount,part,kind,true);
        }
        public static int Damage(CombatActorData actor, int part) => Part(actor, part).damage;
        public static int Kind(CombatActorData actor, int part) => Part(actor, part).kind;
        public static bool Permanent(CombatActorData actor, int part) => Part(actor, part).permanent;
        public static int RecoveryAmount(CombatActorData actor, int part) => Part(actor, part).recoveryAmount;
        public static double RecoveryAt(CombatActorData actor, int part) => Part(actor, part).recoveryAt;
        public static void ScheduleRecovery(CombatActorData actor, int part, int amount, double absoluteMinutes)
        {
            var row = Part(actor, part);
            if (row.permanent || amount < 1 || amount > row.damage || row.recoveryAmount != 0 ||
                double.IsNaN(absoluteMinutes) || double.IsInfinity(absoluteMinutes) || absoluteMinutes <= 0)
                throw new ArgumentException("Invalid scheduled injury recovery.");
            row.recoveryAmount = amount; row.recoveryAt = absoluteMinutes; actor.BodyRevision++;
        }
        public static int AdvanceRecovery(CombatActorData actor, double now)
        {
            if (actor == null) throw new ArgumentNullException(nameof(actor));
            if (double.IsNaN(now) || double.IsInfinity(now) || now < 0) throw new ArgumentOutOfRangeException(nameof(now));
            int recovered = 0;
            foreach (var row in actor.BodyInjuries)
            {
                if (row.recoveryAmount == 0 || row.recoveryAt > now) continue;
                recovered += row.recoveryAmount;
                row.damage -= row.recoveryAmount;
                row.recoveryAmount = 0; row.recoveryAt = 0;
                if (row.damage == 0) row.kind = 0;
            }
            if (recovered > 0) actor.BodyRevision++;
            return recovered;
        }
        public static bool Injure(CombatActorData actor, int part, int kind, int amount)
        {
            var row = Part(actor, part);
            if (kind <= 0 || amount < 1 || amount > 100) throw new ArgumentOutOfRangeException(nameof(amount));
            if (row.permanent) return false;
            row.damage = Math.Min(100, row.damage + amount);
            row.kind = kind;
            actor.BodyRevision++;
            return true;
        }
        public static bool Treat(CombatActorData actor, EquipmentData equipment, int part, int itemId, int count, int recovery)
        {
            var row = Part(actor, part);
            if (equipment == null || itemId < 1 || count < 1 || recovery < 1 || recovery > 100)
                throw new ArgumentException("Invalid injury treatment.");
            if (row.damage == 0 || row.permanent || equipment.CountItem(itemId) < count) return false;
            // Validate the entire operation before consuming from the shared inventory.
            equipment.ConsumeStack(itemId, count);
            int recovered = Math.Min(row.damage, recovery);
            row.damage -= recovered;
            // Treatment consumes scheduled damage first, so its later timer cannot erase a subsequent wound.
            row.recoveryAmount = Math.Max(0, row.recoveryAmount - recovered);
            if (row.recoveryAmount == 0) row.recoveryAt = 0;
            if (row.damage == 0) row.kind = 0;
            actor.BodyRevision++;
            return true;
        }
    }
}
