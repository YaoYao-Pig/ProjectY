using System;

namespace ProjectY.Data
{
    [Serializable] internal sealed class DeathDoorSave
    {
        public int format, survived;
        public bool entered, used, dead;
    }
    public sealed partial class CombatActorData
    {
        internal bool DeathDoorEnabled, DeathDoorEntered, DeathDoorUsed, PermanentlyDead;
        internal int DeathDoorSurvived, DeathDoorRevision;
        internal void EnterDeathDoor()
        {
            if(!DeathDoorEnabled || PermanentlyDead || HP!=0)return;
            DeathDoorEntered=true;DeathDoorUsed=true;DeathDoorRevision++;
        }
    }
    /// <summary>HP remains the true sum of body HP. Only recruited party members may live at zero.</summary>
    public static class DeathDoorState
    {
        public static bool Alive(CombatActorData actor) => !actor.PermanentlyDead && (actor.HP>0 || actor.DeathDoorEntered);
        public static bool Enabled(CombatActorData actor) => actor.DeathDoorEnabled;
        public static bool Entered(CombatActorData actor) => actor.DeathDoorEntered;
        public static bool Used(CombatActorData actor) => actor.DeathDoorUsed;
        public static bool Dead(CombatActorData actor) => actor.PermanentlyDead;
        public static int Survived(CombatActorData actor) => actor.DeathDoorSurvived;
        public static int Revision(CombatActorData actor) => actor.DeathDoorRevision;
        internal static void Enable(CombatActorData actor) => actor.DeathDoorEnabled=true;
        public static void BeginBattle(CombatActorData actor)
        {
            if(!actor.DeathDoorEnabled)return;
            actor.DeathDoorUsed=actor.DeathDoorEntered;actor.DeathDoorRevision++;
        }
        public static void Survive(CombatActorData actor)
        {
            if(!actor.DeathDoorEnabled || !actor.DeathDoorEntered || actor.HP!=0 || actor.PermanentlyDead)
                throw new InvalidOperationException("Death-door survival needs a living party actor at zero HP.");
            actor.DeathDoorSurvived=checked(actor.DeathDoorSurvived+1);actor.DeathDoorRevision++;
        }
        public static void Kill(CombatActorData actor)
        {
            if(!actor.DeathDoorEnabled || !actor.DeathDoorEntered || actor.HP!=0 || actor.PermanentlyDead)
                throw new InvalidOperationException("Death-door death needs a living party actor at zero HP.");
            actor.PermanentlyDead=true;actor.DeathDoorEntered=false;actor.DeathDoorRevision++;
        }
        internal static void Healed(CombatActorData actor)
        {if(actor.DeathDoorEntered && actor.HP>0){actor.DeathDoorEntered=false;actor.DeathDoorRevision++;}}
        internal static void Rested(CombatActorData actor)
        {
            if(actor.PermanentlyDead)return;
            actor.DeathDoorSurvived=0;actor.DeathDoorEntered=actor.DeathDoorEnabled && actor.HP==0;
            actor.DeathDoorUsed=actor.DeathDoorEntered;actor.DeathDoorRevision++;
        }
        internal static DeathDoorSave Capture(CombatActorData actor) => new DeathDoorSave
        {format=1,entered=actor.DeathDoorEntered,used=actor.DeathDoorUsed,dead=actor.PermanentlyDead,survived=actor.DeathDoorSurvived};
        internal static DeathDoorSave Legacy(int hp) => new DeathDoorSave{format=1,entered=hp==0,used=hp==0};
        internal static void Restore(CombatActorData actor,DeathDoorSave row)
        {
            SaveCheck.Require(row!=null && row.format==1 && row.survived>=0,ProjectY.UI.LuaLanguage.Get("DeathDoorSaveInvalid"));
            SaveCheck.Require(!(row.dead && row.entered) && (!row.entered || row.used) && (!row.dead || row.used)
                && (actor.HP==0 ? row.entered || row.dead : !row.entered && !row.dead),ProjectY.UI.LuaLanguage.Get("DeathDoorSaveInvalid"));
            actor.DeathDoorEnabled=true;actor.DeathDoorEntered=row.entered;actor.DeathDoorUsed=row.used;
            actor.PermanentlyDead=row.dead;actor.DeathDoorSurvived=row.survived;actor.DeathDoorRevision++;
        }
    }
}
