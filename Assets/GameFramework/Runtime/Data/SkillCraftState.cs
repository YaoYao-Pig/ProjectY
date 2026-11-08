using System;
using System.Collections.Generic;
using System.Linq;

namespace ProjectY.Data
{
    [Serializable] public sealed class CraftedSkillData
    {
        public int id, version = 1, bodyId, bodyProfessionId;
        public string name;
        public int[] modifierIds = Array.Empty<int>(), modifierProfessionIds = Array.Empty<int>();
        internal CraftedSkillData Copy() => new CraftedSkillData { id=id, version=version, bodyId=bodyId,
            bodyProfessionId=bodyProfessionId, name=name, modifierIds=(int[])modifierIds.Clone(), modifierProfessionIds=(int[])modifierProfessionIds.Clone() };
    }
    [Serializable] internal sealed class SkillCraftSave
    {
        public int version=1, nextId=1, remainderCursor;
        public IntEntry[] practice=Array.Empty<IntEntry>();
        public CraftedSkillData[] recipes=Array.Empty<CraftedSkillData>();
    }
    public sealed partial class CharacterGrowthData
    {
        internal readonly Dictionary<int,int> ProfessionPractice = new Dictionary<int,int>();
        internal readonly List<CraftedSkillData> CraftedSkills = new List<CraftedSkillData>();
        internal int NextCraftedId=1, PracticeCursor, CraftRevision;
    }
    /// <summary>Actor-scoped runtime handles are distinct from static configuration IDs.</summary>
    public static class SkillCraftState
    {
        public const int RuntimeIdBase=1000000000;
        public static int Revision(CombatActorData actor) => actor.Growth.CraftRevision;
        public static int Points(CombatActorData actor,int professionId) => actor.Growth.ProfessionPractice.TryGetValue(professionId,out int value)?value:0;
        public static int Count(CombatActorData actor) => actor.Growth.CraftedSkills.Count;
        public static CraftedSkillData At(CombatActorData actor,int index) => actor.Growth.CraftedSkills[index].Copy();
        public static CraftedSkillData Find(CombatActorData actor,int runtimeId) => actor.Growth.CraftedSkills.Find(x=>RuntimeIdBase+x.id==runtimeId)?.Copy();
        public static void Practice(CombatActorData actor,int[] professions,int amount,int maximum)
        {
            var growth=actor.Growth;
            if(!growth.Initialized || professions==null || professions.Length==0 || professions.Length>128 || amount<1 || maximum<1 || professions.Distinct().Count()!=professions.Length || professions.Any(id=>!growth.HasProfession(id)))
                throw new ArgumentException("Invalid profession practice transaction.");
            var ids=professions.OrderBy(x=>x).ToArray();int share=amount/ids.Length,remainder=amount%ids.Length;
            for(int i=0;i<ids.Length;i++)
            {
                int offset=(i-growth.PracticeCursor%ids.Length+ids.Length)%ids.Length;
                growth.ProfessionPractice[ids[i]]=(int)Math.Min(maximum,(long)Points(actor,ids[i])+share+(offset<remainder?1:0));
            }
            growth.PracticeCursor=(growth.PracticeCursor+remainder)%ids.Length;growth.CraftRevision++;
        }
        public static int Save(CombatActorData actor,int runtimeId,string name,int bodyId,int bodyProfessionId,int[] modifierIds,int[] modifierProfessionIds)
        {
            var growth=actor.Growth;
            if(!growth.Initialized || string.IsNullOrWhiteSpace(name) || name.Length>32 || name.Any(char.IsControl) || bodyId<1 || !growth.HasProfession(bodyProfessionId) || modifierIds==null || modifierProfessionIds==null || modifierIds.Length<1 || modifierIds.Length>2 || modifierIds.Length!=modifierProfessionIds.Length || modifierIds.Any(id=>id<1) || modifierIds.Distinct().Count()!=modifierIds.Length || modifierProfessionIds.Any(id=>!growth.HasProfession(id)))
                throw new ArgumentException("Invalid crafted skill.");
            var existing=runtimeId==0?null:growth.CraftedSkills.Find(x=>RuntimeIdBase+x.id==runtimeId);
            if(runtimeId!=0 && existing==null)throw new ArgumentException("Unknown crafted skill.");
            if(existing==null && (growth.CraftedSkills.Count>=128 || growth.NextCraftedId>=1000000))throw new InvalidOperationException("Crafted skill capacity reached.");
            var value=new CraftedSkillData {id=existing==null?growth.NextCraftedId:existing.id,name=name,bodyId=bodyId,bodyProfessionId=bodyProfessionId,
                modifierIds=(int[])modifierIds.Clone(),modifierProfessionIds=(int[])modifierProfessionIds.Clone()};
            if(existing==null){growth.NextCraftedId++;growth.CraftedSkills.Add(value);}
            else growth.CraftedSkills[growth.CraftedSkills.IndexOf(existing)]=value;
            growth.CraftRevision++;return RuntimeIdBase+value.id;
        }
        internal static SkillCraftSave Capture(CharacterGrowthData growth) => new SkillCraftSave {nextId=growth.NextCraftedId,remainderCursor=growth.PracticeCursor,
            practice=growth.ProfessionPractice.Select(p=>new IntEntry{id=p.Key,value=p.Value}).ToArray(),recipes=growth.CraftedSkills.Select(x=>x.Copy()).ToArray()};
        internal static void Restore(CharacterGrowthData growth,SkillCraftSave save)
        {
            SaveCheck.Require(save!=null && save.version==1 && save.nextId>=1 && save.nextId<=1000000 && save.remainderCursor>=0 && save.remainderCursor<128,"skillCraft.header");
            foreach(var p in SaveCheck.Rows(save.practice,128,"skillCraft.practice"))
            {
                SaveCheck.Require(p!=null && growth.HasProfession(p.id) && p.value>=0 && !growth.ProfessionPractice.ContainsKey(p.id),"skillCraft.practice.entry");
                growth.ProfessionPractice.Add(p.id,p.value);
            }
            var ids=new HashSet<int>();
            foreach(var r in SaveCheck.Rows(save.recipes,128,"skillCraft.recipes"))
            {
                SaveCheck.Require(r!=null && r.version==1 && r.id>0 && r.id<save.nextId && ids.Add(r.id) && r.bodyId>0 && growth.HasSkill(r.bodyId) && growth.HasProfession(r.bodyProfessionId) && !string.IsNullOrWhiteSpace(r.name) && r.name.Length<=32 && !r.name.Any(char.IsControl),"skillCraft.recipe");
                SaveCheck.PositiveIds(r.modifierIds,"skillCraft.modifiers");SaveCheck.Rows(r.modifierProfessionIds,2,"skillCraft.origins");
                SaveCheck.Require(r.modifierIds.Length>=1 && r.modifierIds.Length<=2 && r.modifierIds.Length==r.modifierProfessionIds.Length && r.modifierProfessionIds.All(growth.HasProfession),"skillCraft.origins");
                growth.CraftedSkills.Add(r.Copy());
            }
            growth.NextCraftedId=save.nextId;growth.PracticeCursor=save.remainderCursor;growth.CraftRevision++;
        }
    }
}
