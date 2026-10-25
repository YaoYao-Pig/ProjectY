using System;

namespace ProjectY.Data
{
    /// <summary>Reflection bridge for the animal's one-use, party-shared taming modifier.</summary>
    public static partial class AnimalSpeechState
    {
        public static bool Pending(CombatActorData animal) => Actor(animal).AnimalSpeechPending;
        public static int Modifier(CombatActorData animal) => Actor(animal).AnimalSpeechModifier;
        public static void Resolve(CombatActorData animal,int modifier)
        {
            Actor(animal);
            if(animal.AnimalSpeciesId==0 || animal.AnimalOwnerId!=0 || animal.Team==1 || animal.HP<=0 || animal.AnimalSpeechPending)
                throw new InvalidOperationException("Only an unresolved living wild animal can receive a speech result.");
            if(modifier < -100 || modifier > 100)throw new ArgumentOutOfRangeException(nameof(modifier));
            animal.AnimalSpeechPending=true;animal.AnimalSpeechModifier=modifier;
        }
        public static int Consume(CombatActorData animal)
        {
            Actor(animal);
            if(animal.AnimalSpeciesId==0)throw new InvalidOperationException("Only animals can consume a speech result.");
            int modifier=animal.AnimalSpeechModifier;
            animal.AnimalSpeechPending=false;animal.AnimalSpeechModifier=0;
            return modifier;
        }
        public static bool RetireParty(WorldPartiesData parties,WorldPartyData party)
        {
            if(parties==null || party==null || !ReferenceEquals(parties.Find(party.Id),party))
                throw new ArgumentException("The animal party must belong to these world parties.");
            bool ownsAnimal=false;
            for(int i=0;i<party.MemberCount;i++)if(party.GetMemberAt(i).AnimalOwnerId>0){ownsAnimal=true;break;}
            if(!ownsAnimal)throw new InvalidOperationException("Retiring an animal party requires a completed taming transition.");
            party.SetDefeated(party.LivingCount==0);
            if(!party.Defeated)return false;
            party.CancelAbstractTravel();party.Travel.StopForRetiredParty();party.SetChasing(false);party.SetDestination(0);
            party.SetMission("idle",0,0,parties.Clock);
            if(parties.TargetId==party.Id)parties.Target(0);
            return true;
        }
        internal static void ValidateSaved(int species,bool pending,int modifier)
        {
            SaveCheck.Require(modifier>=-100 && modifier<=100 && (pending?species>0:modifier==0),
                ProjectY.UI.LuaLanguage.Get("AnimalSpeechSaveState"));
        }
        private static CombatActorData Actor(CombatActorData animal) => animal ?? throw new ArgumentNullException(nameof(animal));
    }

    public sealed partial class WorldTravelData
    {
        internal void StopForRetiredParty()
        {route.Clear();index=0;elapsed=0;TargetSiteId=0;Paused=true;Revision++;}
    }
}
