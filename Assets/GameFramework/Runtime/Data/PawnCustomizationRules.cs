using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Data
{
    [Serializable]
    public sealed class PawnCustomizationData
    {
        public int version = 1, seed, skin, hairColor, clothColor;
        public string race, sex, body, head, hair;
        public PawnCustomizationData Copy() => (PawnCustomizationData)MemberwiseClone();
    }

    [Serializable]
    public sealed class PawnCustomizationRules
    {
        [Serializable] public sealed class Module { public string id, slot, race, sex, label; }
        [Serializable] public sealed class Race { public string id, label; public string[] colors; }
        public int version;
        public Module[] modules;
        public Race[] races;
        public string[] hairColors, clothColors;

        public Module[] Options(string slot, string race, string sex)
        {
            var result = new List<Module>();
            foreach (var module in modules)
                if (module.slot == slot && (string.IsNullOrEmpty(module.sex) || module.sex == sex) &&
                    (string.IsNullOrEmpty(module.race) || module.race == "all" || Array.IndexOf(module.race.Split(','), race) >= 0)) result.Add(module);
            return result.ToArray();
        }
        public void Validate(PawnCustomizationData value)
        {
            if (value == null || value.version != version || value.seed < 0) throw new ArgumentException("外观版本或种子无效。");
            var race = Array.Find(races, r => r.id == value.race);
            if (race == null || (value.sex != "male" && value.sex != "female")) throw new ArgumentException("未知种族或性别。");
            Check("body", value.body, value); Check("head", value.head, value); Check("hair", value.hair, value);
            if (value.skin < 0 || value.skin >= race.colors.Length || value.hairColor < 0 || value.hairColor >= hairColors.Length ||
                value.clothColor < 0 || value.clothColor >= clothColors.Length) throw new ArgumentException("外观颜色索引超出目录。");
        }
        private void Check(string slot, string id, PawnCustomizationData value)
        {
            if (Array.Find(Options(slot, value.race, value.sex), m => m.id == id) == null)
                throw new ArgumentException("不兼容的外观模块：" + slot + " / " + id);
        }
        // Explicit uint arithmetic has the same result in the web tool. No global Random state.
        private static uint Next(ref uint state)
        { state ^= state << 13; state ^= state >> 17; state ^= state << 5; return state; }
        public PawnCustomizationData Randomize(int seed, string race = null, string sex = null)
        {
            if (seed < 0) throw new ArgumentOutOfRangeException(nameof(seed));
            uint state = seed == 0 ? 0x6d2b79f5u : (uint)seed;
            var value = new PawnCustomizationData { version = version, seed = seed,
                race = race ?? races[(int)(Next(ref state) % (uint)races.Length)].id,
                sex = sex ?? (Next(ref state) % 2 == 0 ? "male" : "female") };
            var raceInfo = Array.Find(races, r => r.id == value.race);
            if (raceInfo == null || (value.sex != "male" && value.sex != "female")) throw new ArgumentException("随机范围无效。");
            var bodies = Options("body", value.race, value.sex); var heads = Options("head", value.race, value.sex); var hairs = Options("hair", value.race, value.sex);
            if (bodies.Length == 0 || heads.Length == 0 || hairs.Length == 0) throw new InvalidOperationException("随机范围没有可用模块。");
            value.body = bodies[(int)(Next(ref state) % (uint)bodies.Length)].id;
            value.head = heads[(int)(Next(ref state) % (uint)heads.Length)].id;
            value.hair = hairs[(int)(Next(ref state) % (uint)hairs.Length)].id;
            value.skin = (int)(Next(ref state) % (uint)raceInfo.colors.Length);
            value.hairColor = (int)(Next(ref state) % (uint)hairColors.Length);
            value.clothColor = (int)(Next(ref state) % (uint)clothColors.Length);
            Validate(value); return value;
        }
        public Color Tint(string role, PawnCustomizationData value, Color original)
        {
            string hex;
            switch (role)
            {
                case "Skin": hex = Array.Find(races, r => r.id == value.race).colors[value.skin]; break;
                case "Hair": hex = hairColors[value.hairColor]; break;
                case "Cloth": hex = clothColors[value.clothColor]; break;
                default: return original;
            }
            if (!ColorUtility.TryParseHtmlString(hex, out var color)) throw new InvalidOperationException("Invalid palette: " + hex);
            return color;
        }
    }

}
