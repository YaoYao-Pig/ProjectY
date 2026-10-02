using System;
using System.Collections.Generic;
using XLua;

namespace ProjectY.Data
{
    /// <summary>Owned by the original loot record; reflection bridge avoids editing generated xLua wrappers.</summary>
    [LuaCallCSharp]
    public sealed class ContainerState
    {
        private readonly int cellIndex;
        private int[] cells;
        public int Durability { get; private set; }
        public int MaxDurability { get; private set; }
        public bool Destroyed => MaxDurability > 0 && Durability == 0;
        public bool RequiresBreaking { get; private set; }
        public bool Unlocked { get; private set; } = true;
        public int UnlockEncounterId { get; private set; }
        public int Rotation { get; private set; }
        public int CellCount => cells == null ? 1 : cells.Length;
        public bool CanSearch => Unlocked && (!RequiresBreaking || Destroyed);
        public bool Configured => cells != null;
        public int GetCellAt(int index) => cells == null ? (index == 0 ? cellIndex : throw new ArgumentOutOfRangeException(nameof(index))) : cells[index];
        internal ContainerState(int cell) {cellIndex=cell;}
        internal void Configure(int durability,bool requiresBreaking,int encounter,int rotation,int[] footprint)
        {
            if(Configured || durability<0 || requiresBreaking && durability==0 || encounter<0 || rotation<0 || rotation>5 || footprint==null || footprint.Length==0 || footprint[0]!=cellIndex)
                throw new ArgumentException("Invalid physical container.");
            var unique=new HashSet<int>();foreach(var cell in footprint)if(cell<1 || !unique.Add(cell))throw new ArgumentException("Invalid container footprint.");
            cells=(int[])footprint.Clone();Durability=MaxDurability=durability;RequiresBreaking=requiresBreaking;
            UnlockEncounterId=encounter;Unlocked=encounter==0;Rotation=rotation;
        }
        internal bool Unlock() {if(Unlocked)return false;Unlocked=true;return true;}
        internal int Damage(int amount)
        {
            if(amount<0 || MaxDurability==0 || Destroyed || !Unlocked)throw new InvalidOperationException("Container cannot receive damage.");
            int actual=Math.Min(amount,Durability);Durability-=actual;return actual;
        }
        public static ContainerState Of(MapAreaLootData row) => row.Physical;
        public static int Revision(MapAreaStateData area) => area.ContainerRevision;
        public static void Initialize(MapAreaStateData area,int id,int durability,bool requiresBreaking,int encounter,int rotation,int[] footprint)
            => area.ConfigureContainer(id,durability,requiresBreaking,encounter,rotation,footprint);
        public static void Unlock(MapAreaStateData area,int id) => area.UnlockContainer(id);
        public static int Hit(MapAreaStateData area,int id,int amount) => area.DamageContainer(id,amount);
        public static void AdvanceCooldowns(CombatActorData actor) => actor.AdvanceSkillCooldowns();
    }
}
