using System;

namespace ProjectY.Data
{
    public sealed partial class NarrativeData
    {
        internal CombatActorData SpeechAnimal;
        internal int SpeechParty;
        internal string SpeechContext;
        internal bool SpeechUnderstood;
        internal void ClearAnimalSpeech()
        { SpeechAnimal=null;SpeechParty=0;SpeechContext=null;SpeechUnderstood=false; }
        internal void BindAnimalSpeech(CombatActorData animal,int party,string context,bool understood)
        {
            if(!DialogueOpen || SpeechAnimal!=null || animal==null || animal.HP<=0 || animal.AnimalSpeciesId<=0 ||
                party<0 || context!="world" && context!="area" && context!="battle" && context!="companion" ||
                context=="world" && party==0)
                throw new InvalidOperationException("Invalid animal dialogue session.");
            SpeechAnimal=animal;SpeechParty=party;SpeechContext=context;SpeechUnderstood=understood;
            DialogueVersion++;Revision++;
        }
        internal void UnderstandAnimal(int actorId)
        {
            if(!DialogueOpen || SpeechAnimal==null || SpeechUnderstood || actorId<=0)
                throw new InvalidOperationException("Animal dialogue cannot be translated.");
            SpeechUnderstood=true;DialogueActorId=actorId;DialogueVersion++;Revision++;
        }
        internal void TouchAnimalSpeech()
        {
            if(!DialogueOpen || SpeechAnimal==null)throw new InvalidOperationException("No animal dialogue session.");
            DialogueVersion++;Revision++;
        }
    }

    // The existing narrative session owns these transient fields and clears them on every close/reset.
    public static partial class AnimalSpeechState
    {
        public static CombatActorData Target(NarrativeData data) => data.SpeechAnimal;
        public static int PartyId(NarrativeData data) => data.SpeechParty;
        public static string Context(NarrativeData data) => data.SpeechContext;
        public static bool Understood(NarrativeData data) => data.SpeechUnderstood;
        public static void Bind(NarrativeData data,CombatActorData animal,int party,string context,bool understood)
            => data.BindAnimalSpeech(animal,party,context,understood);
        public static void Understand(NarrativeData data,int actorId) => data.UnderstandAnimal(actorId);
        public static void Touch(NarrativeData data) => data.TouchAnimalSpeech();
    }
}
