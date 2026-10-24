using System;

namespace ProjectY.Data
{
    public sealed partial class AdventureData
    {
        internal int ProfessionDuelActorId,ProfessionDuelThreshold;
        internal void BeginProfessionDuel(int actorId,int threshold)
        {
            RequirePhase("area");
            if(ProfessionDuelActorId!=0 || threshold<1 || threshold>=100 || !party.Exists(a=>a.Id==actorId && a.HP>0))
                throw new InvalidOperationException("Invalid profession duel contract.");
            Areas.Active.Stop();ProfessionDuelActorId=actorId;ProfessionDuelThreshold=threshold;
            AreaEncounterId=0;ResultText="";Phase="battle";
        }
        internal void FinishProfessionDuel(string result)
        {
            RequirePhase("battle");
            if(ProfessionDuelActorId==0 || Battle.Winner=="" || string.IsNullOrEmpty(result))
                throw new InvalidOperationException("Profession duel has not ended.");
            ProfessionDuelActorId=0;ProfessionDuelThreshold=0;
            Battle.Clear();AreaEncounterId=0;ResultText=result;Phase="area";
        }
    }
    public static class ProfessionDuelState
    {
        public static bool Active(AdventureData adventure) => adventure.ProfessionDuelActorId!=0 && adventure.Phase=="battle";
        public static int ActorId(AdventureData adventure) => adventure.ProfessionDuelActorId;
        public static void Begin(AdventureData adventure,int actorId,int threshold) => adventure.BeginProfessionDuel(actorId,threshold);
        public static int Limit(AdventureData adventure,CombatActorData target,int amount)
        {
            if(amount<0)throw new ArgumentOutOfRangeException(nameof(amount));
            if(!Active(adventure))return amount;
            var floor=(int)Math.Ceiling(target.MaxHP*adventure.ProfessionDuelThreshold/100.0);
            return Math.Min(amount,Math.Max(0,target.HP-floor));
        }
        public static string Result(AdventureData adventure)
        {
            if(!Active(adventure))return "";
            CombatActorData player=null,enemy=null;
            for(int i=0;i<adventure.Battle.UnitCount;i++)
            {
                var actor=adventure.Battle.GetUnitAt(i);
                if(actor.Id==adventure.ProfessionDuelActorId)player=actor;
                else if(actor.Team==2)enemy=actor;
            }
            if(player==null||enemy==null)return ""; // The validated roster is being deployed before BeginDeployment.
            int threshold=adventure.ProfessionDuelThreshold;
            if(player.HP<=(int)Math.Ceiling(player.MaxHP*threshold/100.0))return "defeat";
            if(enemy.HP<=(int)Math.Ceiling(enemy.MaxHP*threshold/100.0))return "victory";
            return "";
        }
        public static void Finish(AdventureData adventure,string result) => adventure.FinishProfessionDuel(result);
    }
}
