using System;
using System.Collections.Generic;
using XLua;

namespace ProjectY.Data
{
    /// <summary>角色的唯一可变状态；基础属性与技能定义由 Lua 配表查询。</summary>
    [LuaCallCSharp]
    public sealed partial class CombatActorData
    {
        // Bounded display history preserves attack + guard in the same AI command.
        // Snapshots copy it in C#; no Lua view retains this mutable actor.
        public struct PresentationAction { public int Sequence, TemplateId, Shots, TargetQ, TargetR; }
        private readonly List<PresentationAction> presentationActions = new List<PresentationAction>(8);
        public PresentationAction[] CopyPresentationActions() => presentationActions.ToArray();
        private readonly List<int> traits = new List<int>();
        private readonly Dictionary<int, int> cooldowns = new Dictionary<int, int>();
        public int ActionSequence { get; private set; }
        public int ActionTemplateId { get; private set; }
        public int ActionShots { get; private set; }
        public int ActionTargetQ { get; private set; }
        public int ActionTargetR { get; private set; }
        public int Id { get; }
        public int TemplateId { get; }
        public int Team { get; private set; } = 1;
        public int HP { get; private set; } = 1;
        public int MaxHP { get; private set; } = 1;
        public int AP { get; private set; }
        public int Q { get; private set; }
        public int R { get; private set; }
        public int Guard { get; private set; }
        public bool Moved { get; private set; }
        public bool MainUsed { get; private set; }
        public int TraitCount => traits.Count;
        public bool DropResolved { get; private set; }
        public void ResolveDrop()
        {
            if(HP!=0 || Team!=2 || AnimalOwnerId!=0 || DropResolved)throw new InvalidOperationException("Enemy drop cannot be resolved.");
            DropResolved=true;
        }
        public CharacterGrowthData Growth { get; } = new CharacterGrowthData();

        public CombatActorData(int id, int templateId)
        {
            if (id <= 0 || templateId <= 0) throw new ArgumentOutOfRangeException(nameof(id));
            Id = id; TemplateId = templateId;
        }
        public int GetTraitAt(int index) => traits[index];
        public bool HasTrait(int id) => traits.Contains(id);
        public bool RemoveTrait(int id) => traits.Remove(id);
        public int GetCooldown(int skillId) => cooldowns.TryGetValue(skillId, out var value) ? value : 0;
        public void SetCooldown(int skillId, int turns)
        {
            if (skillId < 1 || turns < 0) throw new ArgumentOutOfRangeException(nameof(turns));
            if (turns == 0) cooldowns.Remove(skillId); else cooldowns[skillId] = turns;
        }
        public void RecordAction(int templateId, int shots, int q, int r)
        {
            if (templateId < 0 || shots < 1) throw new ArgumentOutOfRangeException(nameof(shots));
            ActionTemplateId = templateId; ActionShots = shots; ActionTargetQ = q; ActionTargetR = r; ActionSequence++;
            if (presentationActions.Count == 8) presentationActions.RemoveAt(0);
            presentationActions.Add(new PresentationAction {Sequence=ActionSequence, TemplateId=templateId, Shots=shots, TargetQ=q, TargetR=r});
        }
        public void AddTrait(int id)
        {
            if (id <= 0) throw new ArgumentOutOfRangeException(nameof(id));
            if (!traits.Contains(id)) traits.Add(id);
        }
        public void SetMaxHP(int value)
        {
            if (value < 1 || value > 1000000) throw new ArgumentOutOfRangeException(nameof(value));
            // 改变上限时保留已受伤害；倒地角色须通过明确的休整恢复。
            HP = HP == 0 ? 0 : Math.Max(1, Math.Min(value, HP + value - MaxHP));
            MaxHP = value;
        }
        public void Deploy(int team, int q, int r)
        {
            if (team != 0 && team != 1 && team != 2) throw new ArgumentOutOfRangeException(nameof(team));
            Team = team; Q = q; R = r; AP = 0; Guard = 0; Moved = false; MainUsed = false;
            cooldowns.Clear(); ActionTemplateId = 0; presentationActions.Clear();
        }
        public void BeginTurn(int points)
        {
            if (HP == 0 || points < 1) throw new InvalidOperationException("Invalid actor turn.");
            AP = points; Moved = false; MainUsed = false; Guard = 0;
            foreach (var id in new List<int>(cooldowns.Keys)) SetCooldown(id, Math.Max(0, cooldowns[id] - 1));
        }
        public void Move(int q, int r, int cost)
        {
            if (HP == 0 || Moved || cost < 0 || AP < cost) throw new InvalidOperationException("Invalid move budget.");
            Q = q; R = r; AP -= cost; Moved = true;
            MovementStyle="walk";MovementSequence++;
        }
        public void SpendAction(string kind, int cost)
        {
            if (kind != "main" && kind != "secondary") throw new ArgumentException("Unknown action kind.", nameof(kind));
            if (HP == 0 || cost < 0 || AP < cost || (kind == "main" && MainUsed))
                throw new InvalidOperationException("Invalid action budget.");
            AP -= cost;
            if (kind == "main") MainUsed = true;
        }
        public int Damage(int amount)
        {
            if (amount < 0) throw new ArgumentOutOfRangeException(nameof(amount));
            if (MountedAnimal != null)
            {
                var absorbed = MountedAnimal.Damage(amount);
                if (MountedAnimal.HP == 0) MountedAnimal = null;
                return absorbed; // 坐骑承担整次伤害；死亡时丢弃本次溢出伤害。
            }
            var applied = Math.Min(HP, amount); HP -= applied; return applied;
        }
        public int Heal(int amount)
        {
            if (amount < 0) throw new ArgumentOutOfRangeException(nameof(amount));
            if (HP == 0) return 0; // 普通治疗不复活；营地 Restore 明确允许恢复倒地角色。
            var applied = Math.Min(MaxHP - HP, amount); HP += applied; return applied;
        }
        public void SetGuard(int amount)
        {
            if (amount < 0) throw new ArgumentOutOfRangeException(nameof(amount));
            Guard = Math.Max(Guard, amount);
        }
        public void Restore() { HP = MaxHP; Guard = 0; }
    }
}
