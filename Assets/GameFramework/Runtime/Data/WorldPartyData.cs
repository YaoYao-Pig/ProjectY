using System;
using System.Collections.Generic;
using System.Linq;

namespace ProjectY.Data
{
    public sealed class WorldPartySimulationStep
    {
        public WorldPartyData Party { get; }
        public double FromMinute { get; }
        public double ToMinute { get; }
        public double Elapsed => ToMinute-FromMinute;
        public int Lod { get; }
        public int PreviousLod { get; }
        internal WorldPartySimulationStep(WorldPartyData party,double from,double to,int previous)
        { Party=party;FromMinute=from;ToMinute=to;Lod=party.Lod;PreviousLod=previous; }
    }
    public sealed class WorldPartySimulationBatch
    {
        private readonly List<WorldPartySimulationStep> steps=new List<WorldPartySimulationStep>();
        internal static readonly WorldPartySimulationBatch Empty=new WorldPartySimulationBatch();
        public int Count=>steps.Count;
        public WorldPartySimulationStep GetAt(int index)=>steps[index];
        internal void Add(WorldPartySimulationStep step)=>steps.Add(step);
    }
    /// <summary>One visible world party. Routes and cargo have a single persistent owner.</summary>
    public sealed class WorldPartyData
    {
        internal WorldPartiesData Owner;
        private readonly List<CombatActorData> members = new List<CombatActorData>();
        private readonly List<double> memberStrengths = new List<double>();
        private int calibratedMembers;
        public int Id { get; internal set; }
        public int DefinitionId { get; internal set; }
        public int HomeSiteId { get; internal set; }
        public int DestinationSiteId { get; private set; }
        public int BattleSiteId { get; internal set; }
        public bool Defeated { get; internal set; }
        public bool Chasing { get; private set; }
        public double SafeUntil { get; internal set; }
        public int FactionId { get; private set; }
        public int HomeQ { get; private set; }
        public int HomeR { get; private set; }
        public string Role { get; private set; } = "";
        public string Mission { get; private set; } = "idle";
        public int TargetPartyId { get; private set; }
        public int TargetSiteId { get; private set; }
        public double DecisionAt { get; private set; }
        public int Lod { get; internal set; } = 1;
        public double SimulatedAt { get; internal set; }
        public double NextSimulationAt { get; internal set; }
        public bool AbstractTravel { get; private set; }
        public int AbstractQ { get; private set; }
        public int AbstractR { get; private set; }
        public double AbstractStartedAt { get; private set; }
        public double AbstractArrivalAt { get; private set; }
        public double AbstractMinStepMinutes { get; private set; }
        public void BeginAbstractTravel(int q,int r,double now,double arrivalAt,double minStep)
        {
            WorldFactionsData.CheckTime(now);WorldFactionsData.CheckTime(arrivalAt);WorldFactionsData.CheckTime(minStep);
            if(Defeated || BattleSiteId!=0 || Travel.Active || AbstractTravel || now<SimulatedAt || arrivalAt<=now || minStep<=0 || q==Travel.Q && r==Travel.R)
                throw new InvalidOperationException("Invalid abstract world journey.");
            AbstractTravel=true;AbstractQ=q;AbstractR=r;AbstractStartedAt=now;AbstractArrivalAt=arrivalAt;AbstractMinStepMinutes=minStep;
            NextSimulationAt=Math.Min(NextSimulationAt,arrivalAt);Owner?.Changed();
        }
        public bool CompleteAbstractTravel(double now)
        {
            WorldFactionsData.CheckTime(now);
            if(!AbstractTravel || now<AbstractArrivalAt)return false;
            if(Travel.Active || BattleSiteId!=0)throw new InvalidOperationException("Abstract journey overlaps an active route or battlefield.");
            Travel.CompleteAbstractRoute(AbstractQ,AbstractR,AbstractArrivalAt-AbstractStartedAt);CancelAbstractTravel();return true;
        }
        public void CancelAbstractTravel()
        {
            AbstractTravel=false;AbstractQ=AbstractR=0;AbstractStartedAt=AbstractArrivalAt=AbstractMinStepMinutes=0;Owner?.Changed();
        }
        public int MemberCount => members.Count;
        public int LivingCount => members.Count(a => a.HP > 0 && a.AnimalOwnerId == 0);
        public bool StrengthReady => members.Count>0 && calibratedMembers==members.Count;
        public double StrategicPower
        {
            get
            {
                if(!StrengthReady)throw new InvalidOperationException("World party strength has not been calibrated.");
                double value=0;
                for(int i=0;i<members.Count;i++)if(members[i].AnimalOwnerId==0)value+=memberStrengths[i]*((double)members[i].HP/members[i].MaxHP);
                return value;
            }
        }
        public void SetMemberStrength(int index,double value)
        {
            if(index<0 || index>=members.Count || double.IsNaN(value) || double.IsInfinity(value) || value<=0 || value>double.MaxValue/64)
                throw new ArgumentOutOfRangeException(nameof(value));
            if(memberStrengths[index]==0)calibratedMembers++;
            memberStrengths[index]=value;Owner?.Changed();
        }
        public CombatActorData GetMemberAt(int index) => members[index];
        public CombatActorData AddMember(int templateId)
        {
            if (templateId < 1 || members.Count >= 64 || Owner == null || BattleSiteId != 0)
                throw new InvalidOperationException("Invalid world party roster member.");
            var actor = new CombatActorData(Owner.AllocateActorId(), templateId);
            actor.Deploy(2, 0, 0); members.Add(actor);memberStrengths.Add(0);Owner.Changed(); return actor;
        }
        public void ConfigureFaction(int faction, int homeQ, int homeR, string role)
        {
            if (faction < 1 || !ValidRole(role)) throw new ArgumentException("Invalid world party faction.");
            FactionId = faction; HomeQ = homeQ; HomeR = homeR; Role = role; Owner?.Changed();
        }
        internal static bool ValidRole(string role) => role == "caravan" || role == "raider" || role == "patrol" || role == "wildlife" || role == "garrison";
        public void SetHomeSite(int site) { if (site < 0) throw new ArgumentOutOfRangeException(nameof(site)); HomeSiteId = site; Owner?.Changed(); }
        public void SetMission(string mission, int targetParty, int targetSite, double decisionAt)
        {
            WorldFactionsData.CheckTime(decisionAt);
            if (string.IsNullOrEmpty(mission) || mission.Length > 64 || targetParty < 0 || targetSite < 0 || targetParty == Id)
                throw new ArgumentException("Invalid world party mission.");
            Mission = mission; TargetPartyId = targetParty; TargetSiteId = targetSite; DecisionAt = decisionAt; Owner?.Changed();
        }
        public void SetDefeated(bool defeated)
        {
            if (members.Count > 0 && defeated != (LivingCount == 0)) throw new InvalidOperationException("Defeated state differs from party survivors.");
            Defeated = defeated; Owner?.Changed();
        }
        public WorldTravelData Travel { get; internal set; } = new WorldTravelData();
        public MapAreaLootData Cargo { get; internal set; }
        public int CargoCount => Cargo?.SearchItems.Length ?? 0;
        public LootItemData GetCargoAt(int index) => Cargo.SearchItems[index];
        public void SetDestination(int site) { if(site<0)throw new ArgumentOutOfRangeException(nameof(site));DestinationSiteId=site; }
        public void SetChasing(bool value) => Chasing=value;
        public void SetCargo(string name,int[] items,int[] counts,string[] kinds,int[] widths,int[] heights)
        {
            if(Defeated || BattleSiteId!=0)throw new InvalidOperationException("Cannot restock a defeated or engaged caravan.");
            Cargo=new MapAreaLootData(1,1,102,name,items,counts);
            Cargo.PrepareSearch(kinds,widths,heights);
            foreach(var item in Cargo.SearchItems){item.Revealed=true;item.Progress=1;}
        }
        internal WorldPartySave Capture() => new WorldPartySave {id=Id,definition=DefinitionId,home=HomeSiteId,destination=DestinationSiteId,
            battle=BattleSiteId,defeated=Defeated,chasing=Chasing,safeUntil=SafeUntil,travel=Travel.Capture(),hasCargo=Cargo!=null,cargo=Cargo?.Capture(),
            faction=FactionId,homeQ=HomeQ,homeR=HomeR,role=Role,mission=Mission,targetParty=TargetPartyId,targetSite=TargetSiteId,decisionAt=DecisionAt,
            members=members.Select(a=>a.CaptureEnemy()).ToArray(),lod=Lod,simulatedAt=SimulatedAt,nextSimulationAt=NextSimulationAt,memberStrengths=memberStrengths.ToArray(),
            abstractTravel=AbstractTravel,abstractQ=AbstractQ,abstractR=AbstractR,abstractStartedAt=AbstractStartedAt,abstractArrivalAt=AbstractArrivalAt,abstractMinStepMinutes=AbstractMinStepMinutes};
        internal void PrepareAbstractTravel(WorldPartySave row,double clock)
        {
            if(!row.abstractTravel)
            {
                SaveCheck.Require(row.abstractQ==0 && row.abstractR==0 && row.abstractStartedAt==0 && row.abstractArrivalAt==0 && row.abstractMinStepMinutes==0,"未启用的抽象行程");return;
            }
            SaveCheck.Require(!Defeated && BattleSiteId==0 && !Travel.Active && WorldFactionsData.ValidTime(row.abstractStartedAt) &&
                row.abstractStartedAt<=SimulatedAt && row.abstractStartedAt<=clock && WorldFactionsData.ValidTime(row.abstractArrivalAt) &&
                row.abstractArrivalAt>row.abstractStartedAt && WorldFactionsData.ValidTime(row.abstractMinStepMinutes) && row.abstractMinStepMinutes>0 &&
                NextSimulationAt<=row.abstractArrivalAt && (row.abstractQ!=Travel.Q || row.abstractR!=Travel.R),"抽象世界行程");
            AbstractTravel=true;AbstractQ=row.abstractQ;AbstractR=row.abstractR;AbstractStartedAt=row.abstractStartedAt;
            AbstractArrivalAt=row.abstractArrivalAt;AbstractMinStepMinutes=row.abstractMinStepMinutes;
        }
        internal void AddPreparedMember(CombatActorData actor) {members.Add(actor);memberStrengths.Add(0);}
    }

    public sealed class WorldPartiesData
    {
        private readonly List<WorldPartyData> parties=new List<WorldPartyData>();
        private int nextActorId = 1000000000;
        public WorldFactionsData Factions { get; } = new WorldFactionsData();
        public bool LegacyFactions { get; private set; }
        public bool ScheduleInitialized { get; private set; }
        public static WorldPartiesData For(AdventureData adventure)=>adventure.WorldParties;
        public static WorldPartiesData Prepared(PreparedCharacterSave save)=>save.PreparedWorldParties;
        public bool Initialized { get; private set; }
        public int Count=>parties.Count;
        public int Revision { get; private set; }
        public int TargetId { get; private set; }
        public int ContactId { get; private set; }
        public bool Trading { get; private set; }
        public bool IsOpen=>ContactId!=0;
        public double Clock { get; private set; }
        public double Remainder { get; private set; }
        public WorldPartyData GetAt(int index)=>parties[index];
        public WorldPartyData Find(int id)=>parties.Find(p=>p.Id==id);
        public WorldPartyData[] NearbyMobile(int partyId,int radius,double minute)
        {
            CheckTime(minute);if(radius<0)throw new ArgumentOutOfRangeException(nameof(radius));
            var source=Find(partyId);if(source==null)throw new ArgumentException("Unknown world party.");
            if(source.Defeated || source.BattleSiteId!=0 || source.Role=="garrison" || source.Mission=="occupy" || source.SafeUntil>minute)
                return Array.Empty<WorldPartyData>();
            List<WorldPartyData> nearby=null;
            foreach(var candidate in parties)
            {
                if(candidate.Id==partyId || candidate.FactionId==source.FactionId || candidate.Defeated || candidate.BattleSiteId!=0 ||
                    candidate.Role=="garrison" || candidate.Mission=="occupy" || candidate.SafeUntil>minute)continue;
                long dq=(long)candidate.Travel.Q-source.Travel.Q,dr=(long)candidate.Travel.R-source.Travel.R;
                if(Math.Max(Math.Abs(dq),Math.Max(Math.Abs(dr),Math.Abs(dq+dr)))>radius)continue;
                if(nearby==null)nearby=new List<WorldPartyData>();nearby.Add(candidate);
            }
            return nearby==null?Array.Empty<WorldPartyData>():nearby.ToArray();
        }
        public void Clear(){parties.Clear();Factions.Clear();nextActorId=1000000000;LegacyFactions=false;Initialized=ScheduleInitialized=false;Clock=Remainder=0;TargetId=ContactId=0;Trading=false;Revision++;}
        internal int AllocateActorId() { int id=nextActorId;nextActorId=checked(nextActorId+1);return id; }
        internal void Changed() => Revision++;
        public void CompleteFactionMigration()
        {
            if(!Factions.Initialized || parties.Any(p=>p.MemberCount==0 || p.FactionId<1 || !WorldPartyData.ValidRole(p.Role) || p.Defeated!=(p.LivingCount==0)))
                throw new InvalidOperationException("Faction rosters are not initialized.");
            LegacyFactions=false;Revision++;
        }
        public WorldPartyData Add(int definition,int q,int r,int home,uint seed)
        {
            if(definition<1 || home<0 || parties.Count>=4096)throw new InvalidOperationException("Invalid world party initialization.");
            var party=new WorldPartyData{Owner=this,Id=parties.Count+1,DefinitionId=definition,HomeSiteId=home,SimulatedAt=Clock,NextSimulationAt=Clock};
            party.Travel.Reset(seed,q,r,1);parties.Add(party);Revision++;return party;
        }
        public void Complete(double minutes)
        {
            CheckTime(minutes);Clock=minutes;Initialized=true;
            if(!ScheduleInitialized)foreach(var party in parties){party.SimulatedAt=minutes;party.NextSimulationAt=minutes;}
            Revision++;
        }
        private static void CheckTime(double value){if(double.IsNaN(value)||double.IsInfinity(value)||value<0)throw new ArgumentOutOfRangeException(nameof(value));}
        private static int ClassifyLod(int previous,double distance,int near,int middle,int hysteresis,bool initial)
        {
            if(initial)return distance<=near?1:distance<=middle?2:3;
            if(previous==1)return distance<=(long)near+hysteresis?1:distance<=(long)middle+hysteresis?2:3;
            if(distance<=near)return 1;
            if(previous==2)return distance<=(long)middle+hysteresis?2:3;
            return distance<=middle?2:3;
        }
        private static long IntervalDistance(long value,long first,long second)
        {
            long minimum=Math.Min(first,second),maximum=Math.Max(first,second);
            return value<minimum?minimum-value:value>maximum?value-maximum:0;
        }
        private static long AbstractCorridorDistance(WorldPartyData party,int q,int r)
        {
            // The q/r/s bounding box encloses the hex segment; its lower bound never grows with journey age.
            long firstQ=party.Travel.Q,firstR=party.Travel.R,lastQ=party.AbstractQ,lastR=party.AbstractR;
            return Math.Max(IntervalDistance(q,firstQ,lastQ),Math.Max(IntervalDistance(r,firstR,lastR),
                IntervalDistance((long)q+r,firstQ+firstR,lastQ+lastR)));
        }
        private static bool CompletedMobile(WorldPartyData party)=>!party.Defeated && party.BattleSiteId==0 && party.Role!="garrison" &&
            party.Mission!="occupy" && !party.AbstractTravel && party.Travel.Progress==0;
        public WorldPartySimulationBatch Due(double now,int playerQ,int playerR,int nearRadius,int midRadius,int hysteresis,double mediumInterval,double farInterval)
        {
            CheckTime(now);CheckTime(mediumInterval);CheckTime(farInterval);
            if(!Initialized || now<Clock-Remainder || nearRadius<0 || midRadius<=nearRadius || hysteresis<0 ||
                mediumInterval<1 || farInterval<mediumInterval || double.IsInfinity(now+farInterval))
                throw new ArgumentException("Invalid world simulation schedule.");
            WorldPartySimulationBatch batch=null;bool changed=false;
            var previousLods=new int[parties.Count];var initialSchedules=new bool[parties.Count];
            List<WorldPartyData> primaryNear=null;
            for(int i=0;i<parties.Count;i++)
            {
                var party=parties[i];
                if(now<party.SimulatedAt)continue; // A just-restored fractional timestamp may lie beyond this completed minute.
                int previous=party.Lod;
                bool initial=!ScheduleInitialized || party.NextSimulationAt==party.SimulatedAt;
                previousLods[i]=previous;initialSchedules[i]=initial;
                var conflict=party.BattleSiteId==0?null:Factions.FindConflict(party.BattleSiteId);
                bool forced=party.Id==TargetId || party.Id==ContactId || party.Mission=="escort" || party.Mission=="escort_wait" || conflict!=null && conflict.PlayerEngaged;
                double distance=party.Travel.PendingDistance(playerQ,playerR,now-party.SimulatedAt);
                if(party.AbstractTravel)
                {
                    forced|=AbstractCorridorDistance(party,playerQ,playerR)<=(long)nearRadius+hysteresis;
                    long dq=(long)party.AbstractQ-playerQ,dr=(long)party.AbstractR-playerR;
                    distance=Math.Min(distance,Math.Max(Math.Abs(dq),Math.Max(Math.Abs(dr),Math.Abs(dq+dr))));
                    double progress=Math.Max(0,Math.Min(1,(now-party.AbstractStartedAt)/(party.AbstractArrivalAt-party.AbstractStartedAt)));
                    double estimatedQ=party.Travel.Q+((double)party.AbstractQ-party.Travel.Q)*progress-playerQ;
                    double estimatedR=party.Travel.R+((double)party.AbstractR-party.Travel.R)*progress-playerR;
                    distance=Math.Min(distance,Math.Max(Math.Abs(estimatedQ),Math.Max(Math.Abs(estimatedR),Math.Abs(estimatedQ+estimatedR))));
                }
                int lod=forced?1:ClassifyLod(previous,distance,nearRadius,midRadius,hysteresis,initial);
                double interval=lod==1?1:lod==2?mediumInterval:farInterval;
                if(party.Defeated)
                {
                    party.Lod=lod;party.SimulatedAt=now;party.NextSimulationAt=now+interval;continue;
                }
                if(lod!=previous)
                {
                    party.Lod=lod;party.NextSimulationAt=party.SimulatedAt+interval;changed=true;
                }
                if(party.AbstractTravel)party.NextSimulationAt=Math.Min(party.NextSimulationAt,party.AbstractArrivalAt);
                if(lod==1 && CompletedMobile(party))
                {if(primaryNear==null)primaryNear=new List<WorldPartyData>();primaryNear.Add(party);}
            }
            // Promote just the neighbors of the original near set; a chain must not pull the whole world into full simulation.
            if(primaryNear!=null)foreach(var party in parties)
            {
                if(party.Lod==1 || now<party.SimulatedAt || !CompletedMobile(party))continue;
                foreach(var source in primaryNear)
                {
                    long dq=(long)party.Travel.Q-source.Travel.Q,dr=(long)party.Travel.R-source.Travel.R;
                    if(Math.Max(Math.Abs(dq),Math.Max(Math.Abs(dr),Math.Abs(dq+dr)))>1)continue;
                    party.Lod=1;party.NextSimulationAt=party.SimulatedAt+1;changed=true;break;
                }
            }
            for(int i=0;i<parties.Count;i++)
            {
                var party=parties[i];if(party.Defeated || now<party.SimulatedAt)continue;
                int previous=previousLods[i],lod=party.Lod;bool initial=initialSchedules[i];
                double interval=lod==1?1:lod==2?mediumInterval:farInterval;
                // Initial classification does not replay history. Promotions settle every pending minute once.
                if(!initial && lod>=previous && now<party.NextSimulationAt)continue;
                if(batch==null)batch=new WorldPartySimulationBatch();
                batch.Add(new WorldPartySimulationStep(party,party.SimulatedAt,now,previous));
                party.SimulatedAt=now;party.NextSimulationAt=party.AbstractTravel && party.AbstractArrivalAt>now?Math.Min(now+interval,party.AbstractArrivalAt):now+interval;changed=true;
            }
            if(now>Clock){Clock=now;Remainder=0;}
            ScheduleInitialized=true;if(changed)Revision++;
            return batch??WorldPartySimulationBatch.Empty;
        }
        // Whole game-minute simulation boundaries are independent of render frame size and travel speed.
        public int ElapsedTicks(double now)
        {
            CheckTime(now);if(now<Clock)throw new InvalidOperationException("World clock moved backwards.");
            double elapsed=Remainder+now-Clock;int ticks=checked((int)Math.Floor(elapsed+1e-8));
            Remainder=Math.Max(0,elapsed-ticks);Clock=now;
            if(!ScheduleInitialized)foreach(var party in parties){party.SimulatedAt=now;party.NextSimulationAt=now;}
            return ticks;
        }
        public void Target(int id){if(id!=0 && (Find(id)==null || Find(id).Defeated))throw new ArgumentException("Unknown world party.");TargetId=id;Revision++;}
        public void Open(int id)
        {
            var party=Find(id);if(IsOpen || party==null || party.Defeated)throw new InvalidOperationException("Invalid world party contact.");
            ContactId=id;TargetId=0;Trading=false;Revision++;
        }
        public void Trade(){if(!IsOpen || Find(ContactId).Cargo==null)throw new InvalidOperationException("This party has no cargo.");Trading=true;Revision++;}
        public void Close(){ContactId=0;Trading=false;Revision++;}
        public void BeginBattle(int id,int site)
        {
            EngageParty(id,site);Close();TargetId=0;
        }
        public void EngageParty(int id,int site)
        {
            var party=Find(id);if(party==null || party.Defeated || party.AbstractTravel || site<1 || party.BattleSiteId!=0 && party.BattleSiteId!=site)throw new InvalidOperationException("Invalid world party battle.");
            party.BattleSiteId=site;party.SetChasing(false);party.Travel.SetPaused(true);Revision++;
        }
        public void ReleaseParty(int id,bool defeated,double safeUntil)
        {
            CheckTime(safeUntil);var party=Find(id);if(party==null)throw new ArgumentException("Unknown world party.");
            party.SetDefeated(defeated);party.BattleSiteId=0;party.SafeUntil=safeUntil;party.SetChasing(false);party.Travel.SetPaused(defeated);Revision++;
        }
        public void Settle(int site,bool victory,double safeUntil)
        {
            CheckTime(safeUntil);var party=parties.Find(p=>p.BattleSiteId==site && !p.Defeated);
            if(party==null)return;party.SetDefeated(party.MemberCount>0?party.LivingCount==0:victory);party.SafeUntil=safeUntil;Revision++;
        }
        private string Session(int revision)
        {return !Trading?"请先与商队交易":revision!=Revision?"交易列表已变化，请重新选择":"";}
        public string Buy(int index,int revision,int price,EquipmentData equipment,PlayerData player,int ammo,int capacity,int rounds)
        {
            string reason=Session(revision);if(reason!="")return reason;
            var party=Find(ContactId);
            if(index<0 || index>=party.CargoCount || price<0)return "无效商品";
            var item=party.GetCargoAt(index);if(item.Count==0)return "商品已经售罄";
            if(player.Coins<price)return "金币不足";
            if(item.IsStack && equipment.CountItem(item.ItemId)==int.MaxValue)return "物品数量已达上限";
            var place=equipment.Grid.SpaceFor(item.ItemId,item.IsStack);if(place==null)return "背包空间不足，请先整理背包";
            // One physical item / one unit of a stack. Stored equipment retains its exact identity.
            int previous=item.Count;item.Count=1;
            bool received;
            try{received=equipment.ReceiveLoot(item,place.X,place.Y,place.Rotated,ammo,capacity,rounds);}
            finally{item.Count=previous;}
            if(!received)return "背包空间不足";
            item.Count--;if(item.Count==0){item.ReleaseStored();party.Cargo.SearchGrid.Remove(item.Key);}
            Revision++;if(!player.TrySpendCoins(price))throw new InvalidOperationException("Validated caravan payment failed.");return "";
        }
        public string Sell(int inventoryIndex,int revision,int inventoryRevision,int unitPrice,EquipmentData equipment,PlayerData player)
        {
            string reason=Session(revision);if(reason!="")return reason;
            if(inventoryRevision!=equipment.Revision)return "背包已变化，请重新选择";
            if(inventoryIndex<0 || inventoryIndex>=equipment.Grid.Count || unitPrice<0)return "无效出售物品";
            var place=equipment.Grid.GetAt(inventoryIndex);var cargo=Find(ContactId).Cargo;
            var item=equipment.PreviewLootDeposit(cargo,place.Key);
            if(item==null)return "物品已不在背包中";
            long price=(long)unitPrice*item.Count;if(price+player.Coins>int.MaxValue)return "金币数量已达上限";
            cargo.SearchGrid.CopyShape(equipment.Grid,item.ItemId);
            if(!cargo.SearchGrid.Exchange(Array.Empty<string>(),new[]{item.Key},new[]{item.ItemId},false))return "商队货舱已满";
            equipment.CommitLootDeposit(place.Key,item);
            if(!cargo.SearchGrid.Exchange(Array.Empty<string>(),new[]{item.Key},new[]{item.ItemId},true))throw new InvalidOperationException("Validated cargo placement failed.");
            cargo.AddSearchItem(item);Revision++;player.AddCoins((int)price);return "";
        }
        public int DropCargo(int site,MapAreaStateData area,int cell)
        {
            var party=parties.Find(p=>p.BattleSiteId==site && !p.Defeated);
            return party==null?0:DropPartyCargo(party.Id,area,cell);
        }
        public bool CaptureCargo(int winnerId,int loserId)
        {
            var winner=Find(winnerId);var loser=Find(loserId);
            if(winner==null || loser==null || winnerId==loserId || winner.Defeated || winner.MemberCount>0 && winner.LivingCount==0)
                throw new ArgumentException("Invalid cargo capture parties.");
            if(winner.Cargo!=null || loser.Cargo==null || !loser.Cargo.SearchItems.Any(item=>item.Count>0))return false;
            MapAreaLootData replacement=null;
            if(loser.Role=="caravan" && loser.LivingCount>0)
            {
                replacement=EmptyCargo(loser.Cargo.Name);
            }
            // Move the physical hold, including equipment identities. Never clone its contents.
            winner.Cargo=loser.Cargo;loser.Cargo=replacement;Revision++;return true;
        }
        private static MapAreaLootData EmptyCargo(string name)
        {
            var cargo=new MapAreaLootData(1,1,102,name,Array.Empty<int>(),Array.Empty<int>());
            cargo.PrepareSearch(Array.Empty<string>(),Array.Empty<int>(),Array.Empty<int>());return cargo;
        }
        public bool DeferCargo(int partyId,WorldFactionConflictData conflict)
        {
            var party=Find(partyId);
            if(party==null || conflict==null || !ReferenceEquals(Factions.FindConflict(conflict.SiteId),conflict) ||
                partyId!=conflict.PartyA && partyId!=conflict.PartyB)
                throw new ArgumentException("Cargo party does not belong to this conflict.");
            var cargo=party.Cargo;
            if(cargo==null || !cargo.SearchItems.Any(item=>item.Count>0))return false;
            var replacement=party.Role=="caravan" && party.LivingCount>0?EmptyCargo(cargo.Name):null;
            conflict.DeferCargo(cargo);party.Cargo=replacement;Revision++;return true;
        }
        public int DropDeferredCargo(WorldFactionConflictData conflict,MapAreaStateData area,int cell)
        {
            if(conflict==null || !ReferenceEquals(Factions.FindConflict(conflict.SiteId),conflict) || !conflict.Materialized || area==null || area.SiteId!=conflict.SiteId)
                throw new ArgumentException("Deferred cargo needs its materialized battlefield.");
            int count=0;
            while(conflict.PendingCargoCount>0)
            {
                TransferCargo(conflict.GetPendingCargoAt(0),area,cell);
                conflict.RemovePendingCargo();count++;Revision++;
            }
            return count;
        }
        public int DropPartyCargo(int partyId,MapAreaStateData area,int cell)
        {
            var party=Find(partyId);
            if(party==null)throw new ArgumentException("Unknown world party.");
            if(party?.Cargo==null)return 0;
            var source=party.Cargo;
            if(!source.SearchItems.Any(item=>item.Count>0))
            {if(party.Role!="caravan" || party.LivingCount==0)party.Cargo=null;return 0;}
            TransferCargo(source,area,cell);
            party.Cargo=party.Role=="caravan" && party.LivingCount>0?EmptyCargo(source.Name):null;Revision++;return 1;
        }
        private static void TransferCargo(MapAreaLootData source,MapAreaStateData area,int cell)
        {
            area.AddLoot(cell,102,source.Name,Array.Empty<int>(),Array.Empty<int>(),true);
            var target=area.GetLootAt(area.LootCount-1);target.PrepareSearch(Array.Empty<string>(),Array.Empty<int>(),Array.Empty<int>());
            // Transfer the complete physical cargo, including items sold by the player, exactly once.
            source.SearchGrid.CopyDefinitionsTo(target.SearchGrid);
            target.SearchGrid.Configure(6,source.SearchGrid.Height);
            foreach(var old in source.SearchItems.Where(item=>item.Count>0))
            {
                var next=new LootItemData(target,target.SearchItems.Length,target.SourceIndexFor(old.ItemId),old.ItemId,old.Count,old.Kind)
                {StoredWeapon=old.StoredWeapon,StoredWearable=old.StoredWearable,StoredMagazine=old.StoredMagazine,LoadedMagazine=old.LoadedMagazine};
                if(!target.SearchGrid.Exchange(Array.Empty<string>(),new[]{next.Key},new[]{next.ItemId},true))throw new InvalidOperationException("Cargo no longer fits its original capacity.");
                target.AddSearchItem(next);
            }
        }
        internal WorldPartiesSave Capture()=>new WorldPartiesSave{initialized=Initialized,clock=Clock,remainder=Remainder,parties=parties.Select(p=>p.Capture()).ToArray(),
            rosterVersion=LegacyFactions?0:1,nextActorId=nextActorId,factions=Factions.Capture(),scheduleVersion=1,scheduleInitialized=ScheduleInitialized,strengthVersion=1};
        internal static WorldPartiesData Prepare(WorldPartiesSave save,EquipmentData equipment,HashSet<int> itemIds,CharacterAppearanceService appearances,HashSet<int> owners)
        {
            var result=new WorldPartiesData();if(save==null)return result; // Explicit pre-v12 migration.
            SaveCheck.Require(save.initialized && save.clock>=0 && !double.IsNaN(save.clock) && !double.IsInfinity(save.clock) && save.remainder>=0 && save.remainder<1 &&
                (save.rosterVersion==0 || save.rosterVersion==1) && (save.scheduleVersion==0 || save.scheduleVersion==1) &&
                (save.strengthVersion==0 || save.strengthVersion==1),"大地图队伍时钟");
            result.Initialized=true;result.Clock=save.clock;result.Remainder=save.remainder;
            result.ScheduleInitialized=save.scheduleVersion==1 && save.scheduleInitialized;
            result.LegacyFactions=save.rosterVersion==0;
            if(!result.LegacyFactions){SaveCheck.Require(save.nextActorId>=1000000000,"大地图角色序号");result.nextActorId=save.nextActorId;}
            foreach(var row in SaveCheck.Rows(save.parties,4096,"大地图队伍"))
            {
                SaveCheck.Require(row!=null && row.id==result.Count+1 && row.definition>0 && row.home>=0 && row.destination>=0 && row.battle>=0 && row.safeUntil>=0 && !double.IsNaN(row.safeUntil) && !double.IsInfinity(row.safeUntil),"大地图队伍身份");
                var party=new WorldPartyData{Owner=result,Id=row.id,DefinitionId=row.definition,HomeSiteId=row.home,BattleSiteId=row.battle,Defeated=row.defeated,SafeUntil=row.safeUntil,Travel=WorldTravelData.Prepare(row.travel)};
                if(save.scheduleVersion==0){party.SimulatedAt=save.clock;party.NextSimulationAt=save.clock;}
                else
                {
                    SaveCheck.Require(row.lod>=1 && row.lod<=3 && WorldFactionsData.ValidTime(row.simulatedAt) && row.simulatedAt<=save.clock &&
                        WorldFactionsData.ValidTime(row.nextSimulationAt) && row.nextSimulationAt>=row.simulatedAt &&
                        (save.scheduleInitialized || row.simulatedAt==save.clock && row.nextSimulationAt==save.clock),"大地图队伍分层调度");
                    party.Lod=row.lod;party.SimulatedAt=row.simulatedAt;party.NextSimulationAt=row.nextSimulationAt;
                    party.PrepareAbstractTravel(row,save.clock);
                }
                party.SetDestination(row.destination);party.SetChasing(row.chasing);party.Travel.SetPaused(row.battle>0);
                if(!result.LegacyFactions)
                {
                    SaveCheck.Require(row.faction>0 && WorldPartyData.ValidRole(row.role) && !string.IsNullOrEmpty(row.mission) && row.mission.Length<=64 &&
                        row.targetParty>=0 && row.targetParty!=row.id && row.targetSite>=0 && WorldFactionsData.ValidTime(row.decisionAt),"大地图队伍战略");
                    party.ConfigureFaction(row.faction,row.homeQ,row.homeR,row.role);party.SetMission(row.mission,row.targetParty,row.targetSite,row.decisionAt);
                    foreach(var member in SaveCheck.Rows(row.members,64,"大地图队伍编制"))
                    {
                        // A legacy battle keeps its existing actor identity; newly created members use the high ID range.
                        SaveCheck.Require(member!=null && member.id>0 && member.id<save.nextActorId &&
                            (member.team>=2 && member.owner==0 || member.team==1 && member.species>0 && member.owner>0),"大地图角色身份");
                        party.AddPreparedMember(CombatActorData.PrepareEnemy(member,appearances,owners));
                    }
                    SaveCheck.Require(party.MemberCount>0 && party.Defeated==(party.LivingCount==0),"大地图队伍存活状态");
                    if(save.strengthVersion==1)
                    {
                        SaveCheck.Rows(row.memberStrengths,64,"大地图队伍实力权重");
                        SaveCheck.Require(row.memberStrengths.Length==party.MemberCount,"大地图队伍实力编制");
                        for(int i=0;i<row.memberStrengths.Length;i++)
                        {
                            double strength=row.memberStrengths[i];
                            SaveCheck.Require(WorldFactionsData.ValidTime(strength) && strength<=double.MaxValue/64,"大地图队伍实力权重");
                            if(strength>0)party.SetMemberStrength(i,strength);
                        }
                    }
                }
                if(row.hasCargo){SaveCheck.Require(!row.defeated,"已击败商队仍有货物");party.Cargo=MapAreaLootData.Prepare(row.cargo,1,1,equipment,itemIds);SaveCheck.Require(party.Cargo.SearchItems!=null,"商队货物未初始化");}
                result.parties.Add(party);
            }
            if(!result.LegacyFactions)
            {
                foreach(var party in result.parties)SaveCheck.Require(party.TargetPartyId==0 || result.Find(party.TargetPartyId)!=null,"大地图目标队伍");
                result.Factions.TakePrepared(WorldFactionsData.Prepare(save.factions,result,equipment,itemIds));
            }
            return result;
        }
        internal void ValidateWorldReferences(int firstStop,int lastSite,HashSet<int> areaSites)
        {
            foreach(var party in parties)
            {
                SaveCheck.Require(party.HomeSiteId<=lastSite && party.DestinationSiteId<=lastSite && party.TargetSiteId<=lastSite &&
                    (party.BattleSiteId==0 || party.BattleSiteId>=firstStop && party.BattleSiteId<=lastSite &&
                        (areaSites.Contains(party.BattleSiteId) || Factions.FindConflict(party.BattleSiteId)?.Materialized==false)),"大地图队伍地点引用");
            }
            if(LegacyFactions || !Initialized)return;
            for(int i=0;i<Factions.SiteCount;i++)
            {
                var site=Factions.GetSiteAt(i);
                SaveCheck.Require(site.SiteId<=lastSite && (!site.IsTown || site.SiteId<firstStop),"势力据点与地图不一致");
            }
            for(int i=0;i<Factions.ConflictCount;i++)
            {
                var conflict=Factions.GetConflictAt(i);int site=conflict.SiteId;
                SaveCheck.Require(site>=firstStop && site<=lastSite && (!conflict.Materialized || areaSites.Contains(site)),"势力战场缺少探索记录");
            }
        }
        internal void TakePrepared(WorldPartiesData source){Clear();parties.AddRange(source.parties);foreach(var party in parties)party.Owner=this;Factions.TakePrepared(source.Factions);nextActorId=source.nextActorId;LegacyFactions=source.LegacyFactions;Initialized=source.Initialized;ScheduleInitialized=source.ScheduleInitialized;Clock=source.Clock;Remainder=source.Remainder;Revision++;}
    }
    [Serializable] internal sealed class WorldPartiesSave {public bool initialized,scheduleInitialized;public double clock,remainder;public WorldPartySave[] parties;public int rosterVersion,nextActorId,scheduleVersion,strengthVersion;public WorldFactionsSave factions;}
    [Serializable] internal sealed class WorldPartySave {public int id,definition,home,destination,battle;public bool defeated,chasing,hasCargo;public double safeUntil;public TravelSave travel;public ContainerSave cargo;
        public int faction,homeQ,homeR,targetParty,targetSite,lod,abstractQ,abstractR;public string role,mission;
        public double decisionAt,simulatedAt,nextSimulationAt,abstractStartedAt,abstractArrivalAt,abstractMinStepMinutes;public bool abstractTravel;
        public EnemySave[] members;public double[] memberStrengths;}
    public sealed partial class AdventureData {internal WorldPartiesData WorldParties {get;}=new WorldPartiesData();}
    public sealed partial class InventoryGridData {internal InventoryPlacementData SpaceFor(int item,bool stack)
        {
            if(stack){var existing=placements.Find(p=>p.ItemId==item && (p.Key[0]=='s' || p.Key[0]=='p'));if(existing!=null)return existing;}
            return AutoPlace(placements,"__incoming",item,null);
        }}
}
