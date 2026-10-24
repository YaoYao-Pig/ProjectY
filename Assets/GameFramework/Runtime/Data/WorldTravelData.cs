using System;
using System.Collections.Generic;

namespace ProjectY.Data
{
    public sealed class WorldTravelStep
    {
        public int Q { get; }
        public int R { get; }
        public double Minutes { get; }
        internal WorldTravelStep(int q,int r,double minutes) { Q=q;R=r;Minutes=minutes; }
    }
    public sealed class WorldTravelStop
    {
        public int Id { get; }
        public int Q { get; }
        public int R { get; }
        public int EventId { get; }
        public int EncounterId { get; }
        internal WorldTravelStop(int id,int q,int r,int eventId,int encounterId)
        { Id=id;Q=q;R=r;EventId=eventId;EncounterId=encounterId; }
    }
    /// <summary>Expedition-owned position, route, time budget and deterministic encounter stream.</summary>
    public sealed partial class WorldTravelData
    {
        private readonly List<WorldTravelStep> route=new List<WorldTravelStep>();
        private readonly List<WorldTravelStop> stops=new List<WorldTravelStop>();
        private int index,firstStopId;
        private double elapsed,sinceCheck;
        private uint random;
        public static WorldTravelData For(AdventureData adventure) => adventure.Travel;
        public int Q { get; private set; }
        public int R { get; private set; }
        public bool Active => index<route.Count;
        public bool Paused { get; private set; }=true;
        public int Speed { get; private set; }=1;
        public int TargetSiteId { get; private set; }
        public int Revision { get; private set; }
        public string Message { get; private set; }="";
        public void Report(string message) { Message=message??throw new ArgumentNullException(nameof(message));Revision++; }
        public double Progress => Active?elapsed/route[index].Minutes:0;
        public int AnchorQ => Active && elapsed>0?route[index].Q:Q;
        public int AnchorR => Active && elapsed>0?route[index].R:R;
        public int StepCount => route.Count-index;
        public WorldTravelStep GetStepAt(int offset) => route[index+offset];
        public int StopCount => stops.Count;
        public WorldTravelStop GetStopAt(int offset) => stops[offset];
        public double RemainingMinutes { get { double total=-elapsed;for(int i=index;i<route.Count;i++)total+=route[i].Minutes;return total; } }
        public void Reset(uint seed,int q,int r,int nextSiteId)
        {
            if(nextSiteId<1)throw new ArgumentOutOfRangeException(nameof(nextSiteId));
            route.Clear();stops.Clear();index=0;elapsed=sinceCheck=0;Q=q;R=r;firstStopId=nextSiteId;
            random=seed^0x6d2b79f5u;if(random==0)random=1;
            TargetSiteId=0;Speed=1;Paused=false;Message="";Revision++;
        }
        public void Plan(int[] qs,int[] rs,double[] minutes,int targetSiteId)
        {
            if(qs==null || rs==null || minutes==null || qs.Length!=rs.Length || qs.Length!=minutes.Length || targetSiteId<0)
                throw new ArgumentException("Invalid world travel route.");
            var next=new List<WorldTravelStep>();
            int q=AnchorQ,r=AnchorR;
            if(Active && elapsed>0)next.Add(route[index]);
            for(int i=0;i<qs.Length;i++)
            {
                int dq=qs[i]-q,dr=rs[i]-r;
                if(Math.Max(Math.Abs(dq),Math.Max(Math.Abs(dr),Math.Abs(dq+dr)))!=1 || double.IsNaN(minutes[i]) || double.IsInfinity(minutes[i]) || minutes[i]<=0)
                    throw new ArgumentException("Travel steps must be adjacent and have a positive duration.");
                next.Add(new WorldTravelStep(qs[i],rs[i],minutes[i]));q=qs[i];r=rs[i];
            }
            if(!Active || elapsed==0)elapsed=0;
            route.Clear();route.AddRange(next);index=0;TargetSiteId=targetSiteId;Message="";Revision++;
        }
        public void SetPaused(bool value) { Paused=value;Revision++; }
        /// <summary>Follow a co-located carrier while retaining this traveler's clock, stops and random stream.</summary>
        public void Follow(WorldTravelData leader)
        {
            if(leader==null || ReferenceEquals(this,leader))throw new ArgumentException("Invalid travel leader.");
            Q=leader.Q;R=leader.R;route.Clear();
            for(int i=leader.index;i<leader.route.Count;i++)route.Add(leader.route[i]);
            index=0;elapsed=leader.elapsed;TargetSiteId=0;Revision++;
        }
        public void SetSpeed(int value)
        { if(value!=1 && value!=2 && value!=4)throw new ArgumentOutOfRangeException(nameof(value));Speed=value;Revision++; }
        public double Step(double budget)
        {
            if(double.IsNaN(budget) || double.IsInfinity(budget) || budget<0)throw new ArgumentOutOfRangeException(nameof(budget));
            if(!Active || Paused || budget==0)return 0;
            var step=route[index];double spent=Math.Min(budget,step.Minutes-elapsed);
            elapsed+=spent;sinceCheck+=spent;
            if(elapsed>=step.Minutes) { Q=step.Q;R=step.R;index++;elapsed=0; }
            Revision++;return spent;
        }
        public double AdvanceRoute(double budget)
        {
            if(double.IsNaN(budget) || double.IsInfinity(budget) || budget<0)throw new ArgumentOutOfRangeException(nameof(budget));
            if(!Active || Paused || budget==0)return 0;
            double remaining=budget;
            while(Active && remaining>0)
            {
                var step=route[index];double required=step.Minutes-elapsed;
                if(remaining<required){elapsed+=remaining;remaining=0;}
                else{remaining-=required;Q=step.Q;R=step.R;index++;elapsed=0;}
            }
            double spent=budget-remaining;sinceCheck+=spent;Revision++;return spent;
        }
        internal long PendingDistance(int playerQ,int playerR,double budget)
        {
            long dq=(long)Q-playerQ,dr=(long)R-playerR;
            long closest=Math.Max(Math.Abs(dq),Math.Max(Math.Abs(dr),Math.Abs(dq+dr)));
            if(!Active || Paused || budget<=0)return closest;
            double remaining=budget+elapsed;
            for(int i=index;i<route.Count && remaining>0;i++)
            {
                var step=route[i];dq=(long)step.Q-playerQ;dr=(long)step.R-playerR;
                closest=Math.Min(closest,Math.Max(Math.Abs(dq),Math.Max(Math.Abs(dr),Math.Abs(dq+dr))));
                if(closest==0)break;
                remaining-=step.Minutes;
            }
            return closest;
        }
        internal void CompleteAbstractRoute(int q,int r,double duration)
        {
            if(Active)throw new InvalidOperationException("Cannot complete an abstract journey over an active route.");
            route.Clear();index=0;elapsed=0;Q=q;R=r;TargetSiteId=0;sinceCheck+=duration;Revision++;
        }
        public bool CheckDue(double interval)
        {
            if(interval<=0 || double.IsNaN(interval) || double.IsInfinity(interval))throw new ArgumentOutOfRangeException(nameof(interval));
            if(sinceCheck<interval)return false;sinceCheck-=interval;return true;
        }
        public int Roll(int maximum)
        {
            if(maximum<1 || random==0)throw new InvalidOperationException("Travel random stream is not initialized.");
            random^=random<<13;random^=random>>17;random^=random<<5;
            return (int)(random%(uint)maximum)+1;
        }
        public WorldTravelStop AddStop(int eventId,int encounterId)
        {
            if(eventId<0 || encounterId<0 || (eventId==0)==(encounterId==0) || Progress!=0)
                throw new ArgumentException("Travel stop needs exactly one event or encounter at a completed step.");
            var stop=new WorldTravelStop(firstStopId+stops.Count,Q,R,eventId,encounterId);stops.Add(stop);
            sinceCheck=0;Paused=true;Revision++;return stop;
        }
        public WorldTravelStop AddWorldStop(int q,int r,int eventId,int encounterId)
        {
            if(firstStopId<1 || eventId<0 || encounterId<0 || (eventId==0)==(encounterId==0) || stops.Count>=10000)
                throw new ArgumentException("World stop needs exactly one event or encounter.");
            var stop=new WorldTravelStop(checked(firstStopId+stops.Count),q,r,eventId,encounterId);
            stops.Add(stop);Revision++;return stop;
        }
        public void Arrived()
        { if(Active)throw new InvalidOperationException("Travel route has not arrived.");TargetSiteId=0;route.Clear();index=0;elapsed=0;Revision++; }
        public static void BeginBattle(AdventureData adventure,int siteId) => adventure.BeginTravelBattle(siteId);
    }
    public sealed partial class AdventureData
    {
        internal WorldTravelData Travel { get; }=new WorldTravelData();
        internal void BeginTravelBattle(int siteId)
        {
            RequirePhase("map");if(siteId<1)throw new ArgumentOutOfRangeException(nameof(siteId));
            SiteId=siteId;EventId=ChoiceId=EventActorId=0;EventLocation="";EventReturnPhase="map";StoryTriggerKey="";ResultText="";Phase="resolving";
        }
    }
}
