using System;
using System.Collections.Generic;
using System.Linq;

namespace ProjectY.Data
{
    [Serializable] internal sealed class PartyRestSave
    { public int actorId; public double health, trauma; }
    [Serializable] internal sealed class PartyRosterSave
    { public int activeCount, protagonistId; public double recoveryMinute; public PartyRestSave[] rest; }

    /// <summary>Reflection bridge for the complete roster; PartyCount/GetPartyAt remain deployment-only.</summary>
    public static class PartyRoster
    {
        public const int ActiveLimit = 4, ReserveLimit = 6;
        public static int Count(AdventureData data) => data.PartyCount + data.ReserveActors.Count;
        public static int ReserveCount(AdventureData data) => data.ReserveActors.Count;
        public static CombatActorData At(AdventureData data, int index) => index < data.PartyCount ? data.GetPartyAt(index) : data.ReserveActors[index-data.PartyCount];
        public static CombatActorData Find(AdventureData data, int id)
        { for(int i=0;i<Count(data);i++)if(At(data,i).Id==id)return At(data,i);return null; }
        public static bool IsReserve(AdventureData data,int id) => data.ReserveActors.Exists(actor=>actor.Id==id);
        public static bool IsProtagonist(AdventureData data,int id) => data.ProtagonistId==id;
        public static int PreparedActiveCount(PreparedCharacterSave prepared) => prepared.Roster.activeCount;
        public static string CanMove(AdventureData data,int id,bool reserve)
        {
            if(data.Phase!="map" || !data.Camp.IsOpen)return "RosterCampOnly";
            if(Find(data,id)==null || IsReserve(data,id)==reserve)return "RosterInvalidMember";
            if(reserve && data.PartyCount<=1)return "RosterLastActive";
            if(reserve && ReserveCount(data)>=ReserveLimit)return "RosterReserveFull";
            if(!reserve && data.PartyCount>=ActiveLimit)return "RosterActiveFull";
            return "";
        }
        public static string Move(AdventureData data,int id,bool reserve,int revision)
        {
            if(data.Camp.Revision!=revision)return "UICampText5";
            string reason=CanMove(data,id,reserve);if(reason!="")return reason;
            // The model settles world time before changing membership.
            if(data.RosterRecoveryMinute!=data.Narrative.Minutes)throw new InvalidOperationException("Settle roster recovery before changing deployment.");
            data.MoveRosterActor(id,reserve);data.Camp.RosterChanged();CampLoadoutData.Reconcile(data);return "";
        }
        public static string Swap(AdventureData data,int activeId,int reserveId,int revision)
        {
            if(data.Camp.Revision!=revision)return "UICampText5";
            if(data.Phase!="map" || !data.Camp.IsOpen)return "RosterCampOnly";
            if(Find(data,activeId)==null || IsReserve(data,activeId) || !IsReserve(data,reserveId))return "RosterInvalidMember";
            if(data.RosterRecoveryMinute!=data.Narrative.Minutes)throw new InvalidOperationException("Settle roster recovery before changing deployment.");
            data.SwapRosterActors(activeId,reserveId);data.Camp.RosterChanged();CampLoadoutData.Reconcile(data);return "";
        }
        public static void AdvanceRecovery(AdventureData data,double now,double healthPerDay,int traumaPerDay,double scheduleSpeed)
        {
            if(double.IsNaN(now)||double.IsInfinity(now)||now<data.RosterRecoveryMinute || healthPerDay<0 || healthPerDay>1 || traumaPerDay<0 || scheduleSpeed<1)
                throw new ArgumentOutOfRangeException(nameof(now));
            double elapsed=now-data.RosterRecoveryMinute;data.RosterRecoveryMinute=now;if(elapsed==0)return;
            foreach(var actor in data.ReserveActors)
            {
                if(!DeathDoorState.Alive(actor))continue;
                var rest=data.RestFor(actor.Id);
                rest.health+=BodyHealth.RecoverableHP(actor)*elapsed/1440*healthPerDay;
                int heal=(int)Math.Min(int.MaxValue,Math.Floor(rest.health+1e-9));rest.health=Math.Max(0,rest.health-Math.Floor(rest.health+1e-9));
                actor.HealBody(heal);
                rest.trauma+=elapsed/1440*traumaPerDay;
                int treatment=(int)Math.Min(100,Math.Floor(rest.trauma+1e-9));rest.trauma=Math.Max(0,rest.trauma-Math.Floor(rest.trauma+1e-9));
                foreach(var part in actor.BodyInjuries)
                {
                    if(part.permanent)continue;
                    int removed=Math.Min(part.damage,treatment);part.damage-=removed;
                    part.recoveryAmount=Math.Max(0,part.recoveryAmount-removed);
                    if(part.damage==0)part.kind=0;
                    if(part.recoveryAmount==0)part.recoveryAt=0;
                    else part.recoveryAt=Math.Max(double.Epsilon,part.recoveryAt-elapsed*(scheduleSpeed-1));
                }
                BodyHealth.AdvanceRecovery(actor,now);actor.BodyRevision++;
            }
        }
        internal static PartyRosterSave Prepare(PartyRosterSave saved,CombatActorData[] actors,double now,bool legacy)
        {
            if(legacy)return new PartyRosterSave{activeCount=actors.Length,protagonistId=actors[0].Id,recoveryMinute=now,rest=Array.Empty<PartyRestSave>()};
            SaveCheck.Require(saved!=null && saved.activeCount>=1 && saved.activeCount<=ActiveLimit && saved.activeCount<=actors.Length &&
                actors.Length-saved.activeCount<=ReserveLimit && actors.Any(actor=>actor.Id==saved.protagonistId) &&
                !double.IsNaN(saved.recoveryMinute) && !double.IsInfinity(saved.recoveryMinute) && saved.recoveryMinute>=0 && saved.recoveryMinute<=now,ProjectY.UI.LuaLanguage.Get("RosterSaveInvalid"));
            var ids=new HashSet<int>();
            foreach(var row in SaveCheck.Rows(saved.rest,ActiveLimit+ReserveLimit,ProjectY.UI.LuaLanguage.Get("RosterSaveInvalid")))
                SaveCheck.Require(row!=null && ids.Add(row.actorId) && actors.Any(actor=>actor.Id==row.actorId) &&
                    !double.IsNaN(row.health) && row.health>=0 && row.health<1 && !double.IsNaN(row.trauma) && row.trauma>=0 && row.trauma<1,ProjectY.UI.LuaLanguage.Get("RosterSaveInvalid"));
            return saved;
        }
    }
    public sealed partial class AdventureData
    {
        internal readonly List<CombatActorData> ReserveActors=new List<CombatActorData>();
        private readonly List<PartyRestSave> rosterRest=new List<PartyRestSave>();
        internal int ProtagonistId;
        internal double RosterRecoveryMinute;
        internal PartyRestSave RestFor(int actorId)
        {
            var row=rosterRest.Find(value=>value.actorId==actorId);
            if(row==null){row=new PartyRestSave{actorId=actorId};rosterRest.Add(row);}return row;
        }
        internal void ClearRoster(){ReserveActors.Clear();rosterRest.Clear();ProtagonistId=0;RosterRecoveryMinute=0;}
        internal void MoveRosterActor(int id,bool reserve)
        {var source=reserve?party:ReserveActors;var target=reserve?ReserveActors:party;var actor=source.Find(row=>row.Id==id);source.Remove(actor);target.Add(actor);}
        internal void SwapRosterActors(int activeId,int reserveId)
        {int a=party.FindIndex(row=>row.Id==activeId),b=ReserveActors.FindIndex(row=>row.Id==reserveId);var actor=party[a];party[a]=ReserveActors[b];ReserveActors[b]=actor;}
        internal PartyRosterSave CaptureRoster() => new PartyRosterSave{activeCount=party.Count,protagonistId=ProtagonistId,recoveryMinute=RosterRecoveryMinute,
            rest=rosterRest.Select(row=>new PartyRestSave{actorId=row.actorId,health=row.health,trauma=row.trauma}).ToArray()};
        internal void RestoreRoster(CombatActorData[] actors,PartyRosterSave saved)
        {
            party.Clear();party.AddRange(actors.Take(saved.activeCount));ReserveActors.Clear();ReserveActors.AddRange(actors.Skip(saved.activeCount));
            ProtagonistId=saved.protagonistId;RosterRecoveryMinute=saved.recoveryMinute;rosterRest.Clear();rosterRest.AddRange(saved.rest);
        }
    }
    public sealed partial class CampData { internal void RosterChanged()=>Revision++; }
}
