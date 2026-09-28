using System;
using System.Collections.Generic;
using XLua;

namespace ProjectY.Data
{
    /// <summary>角色养成的权威状态。门槛、收益、随机池和天赋连线由 Lua 配表解释。</summary>
    [LuaCallCSharp]
    public sealed partial class CharacterGrowthData
    {
        private readonly Dictionary<string, int> attributes = new Dictionary<string, int>();
        private readonly Dictionary<int, int> talents = new Dictionary<int, int>();
        private readonly List<int> talentIds = new List<int>();
        private readonly List<int> trees = new List<int>();
        private readonly List<int> skills = new List<int>();
        private readonly Queue<int> pendingLevels = new Queue<int>();
        private readonly List<int> offers = new List<int>();
        private uint randomState = 1;
        public bool Initialized { get; private set; }
        public int Level { get; private set; } = 1;
        public int Experience { get; private set; }
        public int AttributePoints { get; private set; }
        public int TalentPoints { get; private set; }
        public int LockedPotential { get; private set; }
        public int Revision { get; private set; }
        public int TalentCount => talentIds.Count;
        public int TreeCount => trees.Count;
        public int SkillCount => skills.Count;
        public int OfferCount => offers.Count;
        public int PendingCount => pendingLevels.Count;
        public int PendingLevel => pendingLevels.Count == 0 ? 0 : pendingLevels.Peek();
        public int GetTalentAt(int index) => talentIds[index];
        public int GetTreeAt(int index) => trees[index];
        public int GetSkillAt(int index) => skills[index];
        public int GetOfferAt(int index) => offers[index];
        public bool HasTree(int id) => trees.Contains(id);
        public bool HasSkill(int id) => skills.Contains(id);
        public int GetRank(int id) => talents.TryGetValue(id, out var rank) ? rank : 0;
        public int GetAttribute(string name) => attributes.TryGetValue(name, out var value) ? value : 0;
        public void Initialize(uint seed, int attributePoints, int talentPoints, int potential)
        {
            if (Initialized || attributePoints < 0 || talentPoints < 0 || potential < 0) throw new InvalidOperationException("Invalid growth initialization.");
            randomState = seed == 0 ? 1u : seed; AttributePoints = attributePoints; TalentPoints = talentPoints;
            LockedPotential = potential; Initialized = true; Revision++;
        }
        public double NextRandom()
        {
            if (!Initialized) throw new InvalidOperationException("Growth is not initialized.");
            randomState ^= randomState << 13; randomState ^= randomState >> 17; randomState ^= randomState << 5;
            return randomState / 4294967296.0;
        }
        public void AddExperience(int amount)
        {
            if (!Initialized || amount < 0) throw new InvalidOperationException("Invalid experience reward.");
            Experience = checked(Experience + amount); Revision++;
        }
        public void AdvanceLevel(int cost, int attributePoints, int talentPoints, bool offersSkill)
        {
            if (!Initialized || cost < 1 || Experience < cost || attributePoints < 0 || talentPoints < 0) throw new InvalidOperationException("Invalid level advance.");
            Experience -= cost; Level++; AttributePoints = checked(AttributePoints + attributePoints);
            TalentPoints = checked(TalentPoints + talentPoints);
            if (offersSkill) pendingLevels.Enqueue(Level);
            Revision++;
        }
        public void InvestAttribute(string name, int cost, int amount)
        {
            if (string.IsNullOrEmpty(name) || cost < 1 || amount < 1 || AttributePoints < cost) throw new InvalidOperationException("Invalid attribute investment.");
            attributes[name] = checked(GetAttribute(name) + amount); AttributePoints -= cost; Revision++;
        }
        public void InvestTalent(int id, int cost)
        {
            if (id < 1 || cost < 1 || TalentPoints < cost) throw new InvalidOperationException("Invalid talent investment.");
            if (!talents.ContainsKey(id)) talentIds.Add(id);
            talents[id] = checked(GetRank(id) + 1); TalentPoints -= cost; Revision++;
        }
        public bool UnlockTree(int id)
        {
            if (id < 1) throw new ArgumentOutOfRangeException(nameof(id));
            if (trees.Contains(id)) return false;
            trees.Add(id); Revision++; return true;
        }
        public int UnlockPotential(int amount)
        {
            if (amount < 0) throw new ArgumentOutOfRangeException(nameof(amount));
            var applied = Math.Min(amount, LockedPotential);
            LockedPotential -= applied; TalentPoints = checked(TalentPoints + applied); Revision++; return applied;
        }
        public void AddOffer(int skillId)
        {
            if (PendingCount == 0 || skillId < 1 || HasSkill(skillId) || offers.Contains(skillId)) throw new InvalidOperationException("Invalid skill offer.");
            offers.Add(skillId); Revision++;
        }
        public void LearnOffer(int skillId)
        {
            if (PendingCount == 0 || !offers.Contains(skillId) || HasSkill(skillId)) throw new InvalidOperationException("Skill is not an available offer.");
            skills.Add(skillId); offers.Clear(); pendingLevels.Dequeue(); Revision++;
        }
        // 直接授予技能不消费等级研习机会；移除同 ID 候选以保持存档集合互斥。
        public bool GrantSkill(int skillId)
        {
            if(!Initialized || skillId<1)throw new InvalidOperationException("Invalid skill grant.");
            if(skills.Contains(skillId))return false;
            skills.Add(skillId);offers.Remove(skillId);Revision++;return true;
        }
        public void FinishEmptyOffer()
        {
            if (PendingCount == 0 || offers.Count != 0) throw new InvalidOperationException("Only an exhausted pool can finish without a skill.");
            pendingLevels.Dequeue(); Revision++;
        }
    }
}
