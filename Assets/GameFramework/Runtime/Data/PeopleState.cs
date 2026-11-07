using System;
using System.Collections.Generic;
using System.Linq;

namespace ProjectY.Data
{
    [Serializable] internal sealed class PeopleSave
    { public int format, nextActorId; public PersonSave[] records; }
    [Serializable] internal sealed class PersonSave
    {
        public string key, originKind, bondKey;
        public int actorId, siteId, residentId, profileId, nameId, trust, stage, branch1, branch2, victories, rescues, learned;
        public bool known, joined, owned;
        public double joinedMinute;
        public ActorSave actor;
        public string[] receipts;
    }

    /// <summary>One persistent identity pointing at the actual resident, world member, or recruited actor.</summary>
    public sealed class PersonData
    {
        internal readonly PeopleData Owner;
        internal readonly HashSet<string> Receipts = new HashSet<string>(StringComparer.Ordinal);
        public string Key { get; }
        public CombatActorData Actor { get; }
        public string OriginKind { get; }
        public int SiteId { get; }
        public int ResidentId { get; }
        public int ProfileId { get; }
        public int NameId { get; }
        public string BondKey { get; private set; }
        public bool Known { get; private set; }
        public int Trust { get; private set; }
        public bool Joined { get; internal set; }
        public double JoinedMinute { get; internal set; }
        public int Stage { get; internal set; }
        public int GrowthStage => Stage;
        public int Branch1 { get; internal set; }
        public int Branch2 { get; internal set; }
        public int BattleWins { get; private set; }
        public int Rescues { get; private set; }
        public int LearnedSkills { get; private set; }
        internal PersonData(PeopleData owner, string key, CombatActorData actor, string origin, int site, int resident, int profile, int name, string bond)
        { Owner=owner;Key=key;Actor=actor;OriginKind=origin;SiteId=site;ResidentId=resident;ProfileId=profile;NameId=name;BondKey=bond; }
        public bool Meet()
        { if(Known)return false;Known=true;Owner.Changed();return true; }
        public void AddTrust(int amount)
        { Trust=(int)Math.Max(-100L,Math.Min(100L,(long)Trust+amount));Owner.Changed(); }
        public void SetBond(string key)
        {
            if(key==null || key==Key || key!="" && !PeopleData.ValidKey(key))throw new ArgumentException(nameof(key));
            BondKey=key;Owner.Changed();
        }
        public int Progress(string kind)
        {
            switch(kind){case "victories":return BattleWins;case "rescues":return Rescues;case "learned":return LearnedSkills;default:throw new ArgumentException(nameof(kind));}
        }
        public void AddProgress(string kind,int amount)
        {
            if(!Joined || amount<1)throw new InvalidOperationException(ProjectY.UI.LuaLanguage.Get("PeopleGrowthInvalid"));
            int value=checked(Progress(kind)+amount);
            switch(kind){case "victories":BattleWins=value;break;case "rescues":Rescues=value;break;case "learned":LearnedSkills=value;break;}
            Owner.Changed();
        }
        public int GetGrowthChoice(int stage)
        { if(stage<1 || stage>2)throw new ArgumentOutOfRangeException(nameof(stage));return stage==1?Branch1:Branch2; }
        internal PersonSave Capture(bool owned) => new PersonSave
        {
            key=Key,actorId=Actor.Id,originKind=OriginKind,siteId=SiteId,residentId=ResidentId,profileId=ProfileId,nameId=NameId,bondKey=BondKey,
            known=Known,trust=Trust,joined=Joined,joinedMinute=JoinedMinute,stage=Stage,branch1=Branch1,branch2=Branch2,
            victories=BattleWins,rescues=Rescues,learned=LearnedSkills,owned=owned,actor=owned?CaptureResident():null,
            receipts=Receipts.OrderBy(value=>value,StringComparer.Ordinal).ToArray()
        };
        private ActorSave CaptureResident()
        {
            var saved=Actor.CaptureSave();
            // Unrecruited residents have no death-door grace period. Zero HP must stay dead when restored.
            if(Actor.HP==0 && !DeathDoorState.Enabled(Actor))saved.deathDoor=new DeathDoorSave{format=1,dead=true,used=true};
            return saved;
        }
        internal void Restore(PersonSave saved)
        {
            Known=saved.known;Trust=saved.trust;Joined=saved.joined;JoinedMinute=saved.joinedMinute;Stage=saved.stage;
            Branch1=saved.branch1;Branch2=saved.branch2;BattleWins=saved.victories;Rescues=saved.rescues;LearnedSkills=saved.learned;
            Receipts.UnionWith(saved.receipts);
        }
    }

    public sealed class PeopleData
    {
        internal const int FirstActorId=600000000, LastActorId=999999999, MaximumRecords=10000;
        private int nextActorId=FirstActorId;
        private readonly List<PersonData> records=new List<PersonData>();
        private readonly Dictionary<string,PersonData> byKey=new Dictionary<string,PersonData>(StringComparer.Ordinal);
        private readonly Dictionary<int,PersonData> byActor=new Dictionary<int,PersonData>();
        public int Count=>records.Count;
        public int Revision { get; private set; }
        public PersonData GetAt(int index)=>records[index];
        public PersonData Find(string key)
        { if(!ValidKey(key))throw new ArgumentException(nameof(key));return byKey.TryGetValue(key,out var value)?value:null; }
        public PersonData FindActor(int actorId)=>byActor.TryGetValue(actorId,out var value)?value:null;
        internal void Changed()=>Revision++;
        internal void MarkJoined(CombatActorData actor,double minute)
        {
            var record=FindActor(actor.Id);if(record==null)return;
            if(!ReferenceEquals(record.Actor,actor))throw new InvalidOperationException(ProjectY.UI.LuaLanguage.Get("PeopleSaveInvalid"));
            if(record.Joined)return;
            record.Joined=true;record.JoinedMinute=minute;record.Meet();Changed();
        }
        internal static bool ValidKey(string key)
        {
            if(string.IsNullOrEmpty(key) || key.Length>128)return false;
            var parts=key.Split(':');int id,site;
            if(parts.Length==2 && (parts[0]=="actor" || parts[0]=="npc"))return int.TryParse(parts[1],out id) && id>0 && parts[1]==id.ToString(System.Globalization.CultureInfo.InvariantCulture);
            return parts.Length==3 && parts[0]=="resident" && int.TryParse(parts[1],out site) && site>0 && int.TryParse(parts[2],out id) && id>0 &&
                parts[1]==site.ToString(System.Globalization.CultureInfo.InvariantCulture) && parts[2]==id.ToString(System.Globalization.CultureInfo.InvariantCulture);
        }
        public PersonData CreateResident(int siteId,int residentId,int templateId,int profileId,int nameId,string bondKey)
        {
            if(siteId<=0 || residentId<=0 || templateId<=0 || nextActorId>=LastActorId)throw new ArgumentOutOfRangeException(nameof(residentId));
            string key="resident:"+siteId.ToString(System.Globalization.CultureInfo.InvariantCulture)+":"+residentId.ToString(System.Globalization.CultureInfo.InvariantCulture);
            if(byKey.TryGetValue(key,out var existing))
            {
                if(existing.Actor.TemplateId!=templateId || existing.ProfileId!=profileId || existing.NameId!=nameId)
                    throw new InvalidOperationException(ProjectY.UI.LuaLanguage.Get("PeopleSaveInvalid"));
                return existing;
            }
            var actor=new CombatActorData(nextActorId,templateId);actor.Deploy(0,0,0);
            var result=Add(key,actor,"resident",siteId,residentId,profileId,nameId,bondKey);
            nextActorId++;return result;
        }
        internal PersonData Add(string key,CombatActorData actor,string origin,int site,int resident,int profile,int name,string bond)
        {
            if(!ValidKey(key) || actor==null || records.Count>=MaximumRecords || byKey.ContainsKey(key) || byActor.ContainsKey(actor.Id) ||
                (origin!="resident" && origin!="area" && origin!="world" && origin!="party") || site<0 || resident<0 || profile<1 || name<0 ||
                bond==null || bond==key || bond!="" && !ValidKey(bond))throw new ArgumentException(ProjectY.UI.LuaLanguage.Get("PeopleSaveInvalid"));
            if((origin=="resident")!=key.StartsWith("resident:",StringComparison.Ordinal) ||
                origin=="resident" && (site<=0 || resident<=0 || key!="resident:"+site+":"+resident || actor.Id<FirstActorId || actor.Id>=LastActorId) ||
                key.StartsWith("actor:",StringComparison.Ordinal) && key!="actor:"+actor.Id)
                throw new ArgumentException(ProjectY.UI.LuaLanguage.Get("PeopleSaveInvalid"));
            var row=new PersonData(this,key,actor,origin,site,resident,profile,name,bond);
            records.Add(row);byKey.Add(key,row);byActor.Add(actor.Id,row);Changed();return row;
        }
        internal void Clear()
        {records.Clear();byKey.Clear();byActor.Clear();nextActorId=FirstActorId;Changed();}
        internal void TakePrepared(PeopleData prepared)
        {
            Clear();nextActorId=prepared.nextActorId;
            foreach(var original in prepared.records)
            {
                var row=Add(original.Key,original.Actor,original.OriginKind,original.SiteId,original.ResidentId,original.ProfileId,original.NameId,original.BondKey);
                row.Restore(original.Capture(false));
            }
        }
        internal PeopleSave Capture(AdventureData data,HashSet<int> equipmentOwners)
        {
            var all=PeopleState.WorldActors(data);
            var rows=new List<PersonSave>();
            foreach(var row in records)
            {
                bool owned=row.OriginKind=="resident" && !row.Joined;
                Check(row.Actor.Growth.Initialized);
                Check(row.Joined==ReferenceEquals(PartyRoster.Find(data,row.Actor.Id),row.Actor));
                if(owned)Check(!all.ContainsKey(row.Actor.Id));
                else Check(all.TryGetValue(row.Actor.Id,out var original) && ReferenceEquals(original,row.Actor));
                equipmentOwners.Add(row.Actor.Id);rows.Add(row.Capture(owned));
            }
            return new PeopleSave{format=1,nextActorId=nextActorId,records=rows.ToArray()};
        }
        internal static PeopleData Prepare(PeopleSave saved,PreparedCharacterSave prepared,CharacterAppearanceService appearances,HashSet<int> owners)
        {
            Check(saved!=null && saved.format==1 && saved.nextActorId>=FirstActorId && saved.nextActorId<=LastActorId);
            var result=new PeopleData{nextActorId=saved.nextActorId};
            var all=PeopleState.PreparedActors(prepared);
            double now=prepared.Narrative==null?0:prepared.Narrative.Minutes;
            foreach(var row in SaveCheck.Rows(saved.records,MaximumRecords,ProjectY.UI.LuaLanguage.Get("PeopleSaveInvalid")))
            {
                Check(row!=null && row.actorId>0 && ValidKey(row.key) && row.profileId>0 && row.nameId>=0 && row.siteId>=0 && row.residentId>=0 &&
                    row.trust>=-100 && row.trust<=100 && WorldFactionsData.ValidTime(row.joinedMinute) && row.joinedMinute<=now &&
                    row.stage>=0 && row.stage<=2 && row.branch1>=0 && row.branch2>=0 && (row.stage>=1)==(row.branch1>0) && (row.stage==2)==(row.branch2>0) &&
                    row.victories>=0 && row.rescues>=0 && row.learned>=0 && (row.joined || row.joinedMinute==0 && row.stage==0 && row.victories==0 && row.rescues==0 && row.learned==0) &&
                    (!row.joined || row.known) && row.bondKey!=null);
                Check(row.originKind!="resident" || row.siteId>0 && row.residentId>0 && row.key=="resident:"+row.siteId+":"+row.residentId && row.actorId>=FirstActorId && row.actorId<saved.nextActorId);
                Check(row.owned==(row.originKind=="resident" && !row.joined));
                CombatActorData actor;
                if(row.owned)
                {
                    Check(row.actor!=null && row.actor.id==row.actorId && owners.Add(row.actorId) && !all.ContainsKey(row.actorId) && !row.actor.hasMount);
                    actor=CombatActorData.FromSave(row.actor,appearances);actor.DeathDoorEnabled=false;actor.Deploy(0,0,0);
                }
                else
                {
                    Check(row.actor==null || row.actor.id==0);
                    Check(all.TryGetValue(row.actorId,out actor));
                }
                Check(actor.Growth.Initialized && row.joined==prepared.Actors.Any(value=>ReferenceEquals(value,actor)));
                if(!row.joined && !row.owned)Check(PeopleState.PreparedSourceMatches(prepared,row.originKind,row.siteId,actor));
                var receiptSet=new HashSet<string>(StringComparer.Ordinal);
                foreach(string receipt in SaveCheck.Rows(row.receipts,10000,ProjectY.UI.LuaLanguage.Get("PeopleSaveInvalid")))
                    Check(row.joined && ValidReceipt(receipt) && receiptSet.Add(receipt));
                var person=result.Add(row.key,actor,row.originKind,row.siteId,row.residentId,row.profileId,row.nameId,row.bondKey);person.Restore(row);
            }
            foreach(var person in result.records)
                if(person.BondKey!="")Check(result.byKey.TryGetValue(person.BondKey,out var bond) && person.SiteId>0 && bond.SiteId==person.SiteId && bond.Key!=person.Key);
            return result;
        }
        internal static bool ValidReceipt(string value)=>!string.IsNullOrEmpty(value) && value.Length<=200 &&
            (value.StartsWith("battle:",StringComparison.Ordinal) && value.Length>7 || value.StartsWith("rescue:",StringComparison.Ordinal) && value.Length>7 || value.StartsWith("learn:",StringComparison.Ordinal) && value.Length>6);
        internal static void Check(bool valid)=>SaveCheck.Require(valid,ProjectY.UI.LuaLanguage.Get("PeopleSaveInvalid"));
    }

    /// <summary>Reflection bridge. Rules and localization stay in Lua; identity and ownership stay in Data.</summary>
    public static class PeopleState
    {
        public static PeopleData Get(AdventureData data)=>(data??throw new ArgumentNullException(nameof(data))).People;
        public static PeopleData Prepared(PreparedCharacterSave prepared)
        {
            if(prepared==null || prepared.Consumed || prepared.People==null)throw new InvalidOperationException(ProjectY.UI.LuaLanguage.Get("PeopleSaveInvalid"));
            return prepared.People;
        }
        public static PersonData Bind(AdventureData data,string key,CombatActorData actor,string originKind,int siteId,int residentId,int profileId,int nameId,string bondKey)
        {
            var existing=Get(data).Find(key);
            if(existing!=null)
            { if(!ReferenceEquals(existing.Actor,actor))throw new InvalidOperationException(ProjectY.UI.LuaLanguage.Get("PeopleSaveInvalid"));return existing; }
            if(actor==null || actor.AnimalSpeciesId!=0 || !SourceMatches(data,originKind,siteId,actor))
                throw new InvalidOperationException(ProjectY.UI.LuaLanguage.Get("PeopleSaveInvalid"));
            var result=data.People.Add(key,actor,originKind,siteId,residentId,profileId,nameId,bondKey);
            if(originKind=="party"){result.Joined=true;result.JoinedMinute=data.Narrative.Minutes;result.Meet();}
            return result;
        }
        public static bool CanRecruit(AdventureData data,string key)
        { return RecruitReason(data,key)==""; }
        public static string RecruitReason(AdventureData data,string key)
        {
            var row=Get(data).Find(key);
            if(row==null || row.Joined || data.Phase!="map" && data.Phase!="area" || PartyRoster.Count(data)>=PartyRoster.ActiveLimit+PartyRoster.ReserveLimit)
                return "PeopleRecruitInvalid";
            var actor=row.Actor;
            if(actor.HP<=0 || DeathDoorState.Dead(actor) || actor.AnimalSpeciesId!=0 || actor.AnimalOwnerId!=0 || actor.BoundAnimal!=null ||
                !actor.Growth.Initialized || PartyRoster.Find(data,actor.Id)!=null)return "PeopleRecruitInvalid";
            if(row.OriginKind=="resident")return WorldActors(data).ContainsKey(actor.Id)?"PeopleRecruitInvalid":"";
            if(row.OriginKind=="world")
            {
                var party=WorldOwner(data.WorldParties,actor);
                return party==null || party.BattleSiteId!=0 || party.Defeated || party.LivingCount<=1 || !data.Equipment.CombatInitialized(actor.Id)?"PeopleRecruitInvalid":"";
            }
            if(row.OriginKind=="area")
            {
                var group=data.Areas.PersonEncounter(actor);
                return group==null || group.PartyId!=0 || group.Detached || group.EnemyCount<=1 || !data.Equipment.CombatInitialized(actor.Id)?"PeopleRecruitInvalid":"";
            }
            return "PeopleRecruitInvalid";
        }
        public static void ValidateRecruit(AdventureData data,string key)
        {string reason=RecruitReason(data,key);if(reason!="")throw new InvalidOperationException(ProjectY.UI.LuaLanguage.Get(reason));}
        public static CombatActorData Recruit(AdventureData data,string key)
        {
            ValidateRecruit(data,key);var row=data.People.Find(key);var actor=row.Actor;
            if(row.OriginKind=="world")WorldOwner(data.WorldParties,actor).ReleasePerson(actor);
            else if(row.OriginKind=="area")
            {var group=data.Areas.PersonEncounter(actor);var area=data.Areas.RecruitEncounterOwner(group);group.ReleaseRecruit(actor);area.MarkRecruitTransferred();}
            data.Equipment.TransferCombatOwner(actor.Id);actor.Deploy(1,actor.Q,actor.R);data.AddPreparedRecruit(actor);
            return actor;
        }
        public static bool RecordGrowthEvent(AdventureData data,int actorId,string kind,string eventId)
        {
            if((kind!="battle" && kind!="rescue" && kind!="learn") || string.IsNullOrEmpty(eventId) || eventId.Length>180)
                throw new ArgumentException(ProjectY.UI.LuaLanguage.Get("PeopleGrowthInvalid"));
            var row=Get(data).FindActor(actorId);if(row==null || !row.Joined)return false;
            if(!ReferenceEquals(PartyRoster.Find(data,actorId),row.Actor))throw new InvalidOperationException(ProjectY.UI.LuaLanguage.Get("PeopleGrowthInvalid"));
            string receipt=kind+":"+eventId;if(row.Receipts.Contains(receipt))return false;
            string counter=kind=="battle"?"victories":kind=="rescue"?"rescues":"learned";
            if(row.Receipts.Count>=10000 || row.Progress(counter)==int.MaxValue)throw new InvalidOperationException(ProjectY.UI.LuaLanguage.Get("PeopleGrowthInvalid"));
            row.AddProgress(counter,1);row.Receipts.Add(receipt);return true;
        }
        public static bool ChooseGrowth(AdventureData data,int actorId,int expectedStage,int choiceId)
        {
            if(expectedStage<0 || expectedStage>1 || choiceId<1)throw new ArgumentException(ProjectY.UI.LuaLanguage.Get("PeopleGrowthInvalid"));
            var row=Get(data).FindActor(actorId);
            if(row==null || !row.Joined || row.Stage!=expectedStage || !ReferenceEquals(PartyRoster.Find(data,actorId),row.Actor) || !DeathDoorState.Alive(row.Actor))return false;
            if(expectedStage==0)row.Branch1=choiceId;else row.Branch2=choiceId;row.Stage++;data.People.Changed();return true;
        }
        private static bool SourceMatches(AdventureData data,string origin,int site,CombatActorData actor)
        {
            if(origin=="party")return ReferenceEquals(PartyRoster.Find(data,actor.Id),actor);
            if(origin=="world")return WorldOwner(data.WorldParties,actor)!=null;
            var group=data.Areas.PersonEncounter(actor);
            return origin=="area" && group!=null && group.PartyId==0 && data.Areas.RecruitEncounterOwner(group).SiteId==site;
        }
        internal static bool PreparedSourceMatches(PreparedCharacterSave prepared,string origin,int site,CombatActorData actor)
        {
            if(origin=="world")return prepared.PreparedWorldParties!=null && WorldOwner(prepared.PreparedWorldParties,actor)!=null;
            return origin=="area" && prepared.PreparedAreas!=null && prepared.PreparedAreas.Any(area=>area.SiteId==site && Enumerable.Range(0,area.EncounterCount)
                .Any(index=>area.GetEncounterAt(index).PartyId==0 && area.GetEncounterAt(index).ContainsRecruit(actor)));
        }
        private static WorldPartyData WorldOwner(WorldPartiesData world,CombatActorData actor)
        { for(int i=0;i<world.Count;i++){var party=world.GetAt(i);for(int j=0;j<party.MemberCount;j++)if(ReferenceEquals(party.GetMemberAt(j),actor))return party;}return null; }
        internal static Dictionary<int,CombatActorData> WorldActors(AdventureData data)
        {
            var result=new Dictionary<int,CombatActorData>();for(int i=0;i<PartyRoster.Count(data);i++)Remember(result,PartyRoster.At(data,i));
            AddWorld(result,data.WorldParties);foreach(var actor in data.Areas.PersonActors())Remember(result,actor);return result;
        }
        internal static Dictionary<int,CombatActorData> PreparedActors(PreparedCharacterSave data)
        {
            var result=new Dictionary<int,CombatActorData>();foreach(var actor in data.Actors)Remember(result,actor);
            if(data.PreparedWorldParties!=null)AddWorld(result,data.PreparedWorldParties);
            if(data.PreparedAreas!=null)foreach(var area in data.PreparedAreas)for(int i=0;i<area.EncounterCount;i++)
                for(int j=0;j<area.GetEncounterAt(i).EnemyCount;j++)Remember(result,area.GetEncounterAt(i).GetEnemyAt(j));
            return result;
        }
        private static void AddWorld(Dictionary<int,CombatActorData> result,WorldPartiesData world)
        {for(int i=0;i<world.Count;i++){var party=world.GetAt(i);for(int j=0;j<party.MemberCount;j++)Remember(result,party.GetMemberAt(j));}}
        private static void Remember(Dictionary<int,CombatActorData> result,CombatActorData actor)
        {if(result.TryGetValue(actor.Id,out var previous))PeopleData.Check(ReferenceEquals(previous,actor));else result.Add(actor.Id,actor);}
    }
    public sealed partial class AdventureData { internal PeopleData People { get; } = new PeopleData(); }
    public sealed partial class MapAreaData
    {
        internal IEnumerable<CombatActorData> PersonActors()
        {foreach(var area in areas.Values)for(int i=0;i<area.EncounterCount;i++){var group=area.GetEncounterAt(i);for(int j=0;j<group.EnemyCount;j++)yield return group.GetEnemyAt(j);}}
        internal MapAreaEncounterData PersonEncounter(CombatActorData actor)
        {foreach(var area in areas.Values)for(int i=0;i<area.EncounterCount;i++)if(area.GetEncounterAt(i).ContainsRecruit(actor))return area.GetEncounterAt(i);return null;}
    }
}
