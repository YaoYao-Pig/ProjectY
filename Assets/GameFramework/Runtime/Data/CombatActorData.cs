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
        public int HP { get => TotalBodyHealth(false); private set => SetBodyHealth(value); }
        public int MaxHP { get => TotalBodyHealth(true); private set => ResizeBody(value); }
        public int AP { get; private set; }
        public int Q { get; private set; }
        public int R { get; private set; }
        public int Guard { get; private set; }
        // Normal movement ends when its distance budget is exhausted or an action is committed.
        public bool Moved { get; private set; }
        private int movementSpent;
        internal int MovementSpent => movementSpent;
        public bool MainUsed { get; private set; }
        public int TraitCount => traits.Count;
        public bool DropResolved { get; private set; }
        public void ResolveDrop()
        {
            if(HP!=0 || Team<2 || AnimalOwnerId!=0 || DropResolved)throw new InvalidOperationException("Enemy drop cannot be resolved.");
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
            MaxHP = value;
        }
        public void Deploy(int team, int q, int r)
        {
            if (team < 0 || team > 64) throw new ArgumentOutOfRangeException(nameof(team));
            Team = team; Q = q; R = r; AP = 0; Guard = 0; Moved = false; MainUsed = false;movementSpent=0;
            cooldowns.Clear(); ActionTemplateId = 0; presentationActions.Clear();
            ProfessionMarks.Clear();
        }
        public void BeginTurn(int points)
        {
            BeginDeploymentTurn(points);
            AdvanceSkillCooldowns();
        }
        public void BeginDeploymentTurn(int points)
        {
            if (HP == 0 || points < 1) throw new InvalidOperationException("Invalid actor turn.");
            AP = points; Moved = false; MainUsed = false; Guard = 0;movementSpent=0;
        }
        internal void AdvanceSkillCooldowns()
        {foreach(var id in new List<int>(cooldowns.Keys))SetCooldown(id,Math.Max(0,cooldowns[id]-1));}
        public void Move(int q, int r, int cost)
        {
            if (HP == 0 || Moved || cost < 0 || AP < cost) throw new InvalidOperationException("Invalid move budget.");
            Q = q; R = r; AP -= cost; Moved = true;
            MovementStyle="walk";MovementSequence++;
        }
        internal void MoveSegment(int q,int r,int moveAP,int pathCost,int moveRange)
        {
            int cost=movementSpent==0?moveAP:0;
            if(HP==0 || Moved || moveAP<0 || pathCost<1 || moveRange<1 || pathCost>moveRange-movementSpent || AP<cost || (q==Q && r==R))
                throw new InvalidOperationException("Invalid movement segment.");
            Q=q;R=r;AP-=cost;movementSpent+=pathCost;Moved=movementSpent==moveRange;
            MovementStyle="walk";MovementSequence++;
        }
        public void SpendAction(string kind, int cost)
        {
            if (kind != "main" && kind != "secondary") throw new ArgumentException("Unknown action kind.", nameof(kind));
            if (HP == 0 || cost < 0 || AP < cost || (kind == "main" && MainUsed))
                throw new InvalidOperationException("Invalid action budget.");
            AP -= cost;
            // Acting commits the turn to actions; skip any unused normal move without charging its AP or animating a step.
            Moved = true;
            if (kind == "main") MainUsed = true;
        }
        internal int ApplyExertion(int amount)
        {
            if(amount<0||HP==0)throw new ArgumentOutOfRangeException(nameof(amount));
            return DamageBody(Math.Min(amount,HP-1),-1,0,false);
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
            return DamageBody(amount,-1,0,false);
        }
        public int Heal(int amount)
        {
            if (amount < 0) throw new ArgumentOutOfRangeException(nameof(amount));
            if (HP == 0) return 0; // 普通治疗不复活；营地 Restore 明确允许恢复倒地角色。
            return HealBody(amount);
        }
        public void SetGuard(int amount)
        {
            if (amount < 0) throw new ArgumentOutOfRangeException(nameof(amount));
            Guard = Math.Max(Guard, amount);
        }
        public void Replenish()
        {
            if (HP != 0 || Team < 2 || AnimalOwnerId != 0)
                throw new InvalidOperationException("Only defeated independent defenders can be replenished.");
            DropResolved = false; cooldowns.Clear(); Restore();
        }
        public void Restore() { HP = MaxHP; Guard = 0; }
    }
}
