using System;
using XLua;

namespace ProjectY.Data
{
    /// <summary>Authoritative mutable state. Lua systems forward commands and notifications.</summary>
    [LuaCallCSharp]
    public sealed class PlayerData
    {
        public int Coins { get; private set; }
        public int Level { get; private set; } = 1;
        private event Action Changed;

        public void AddChangedListener(Action listener) => Changed += listener;
        public void RemoveChangedListener(Action listener) => Changed -= listener;

        public void AddCoins(int amount)
        {
            if (amount < 0) throw new ArgumentOutOfRangeException(nameof(amount));
            Coins = checked(Coins + amount);
            Changed?.Invoke();
        }

        public bool TrySpendCoins(int amount)
        {
            if (amount < 0) throw new ArgumentOutOfRangeException(nameof(amount));
            if (Coins < amount) return false;
            Coins -= amount;
            Changed?.Invoke();
            return true;
        }

        public void AdvanceLevel()
        {
            Level = checked(Level + 1);
            Changed?.Invoke();
        }

        public void ClearListeners() => Changed = null;
    }
}
