using System;
using System.IO;
using UnityEngine;
using XLua;

namespace ProjectY.Data
{
    [LuaCallCSharp]
    public sealed class CharacterAppearanceService
    {
        private PawnCustomizationRules rules;
        public PawnCustomizationRules Rules
        {
            get
            {
                if (rules != null) return rules;
                var source = Resources.Load<TextAsset>("CharacterAppearanceCatalog");
                if (source == null) throw new FileNotFoundException("请同步模块化角色资源：缺少 CharacterAppearanceCatalog。");
                rules = JsonUtility.FromJson<PawnCustomizationRules>(source.text); return rules;
            }
        }
        public void Create(CombatActorData actor, int seed, string race, string sex)
        {
            if (actor.CustomizationJson != "") throw new InvalidOperationException("角色外观已经初始化，不能重新随机。");
            Apply(actor, JsonUtility.ToJson(Rules.Randomize(seed, race, sex)));
        }
        public void Apply(CombatActorData actor, string json)
        {
            if (string.IsNullOrEmpty(json) || json.Length > 8192) throw new ArgumentException("外观 JSON 无效。");
            var value = JsonUtility.FromJson<PawnCustomizationData>(json); Rules.Validate(value);
            actor.SetCustomization(JsonUtility.ToJson(value));
        }
        public string Race(CombatActorData actor)
        { var value = JsonUtility.FromJson<PawnCustomizationData>(actor.CustomizationJson); Rules.Validate(value); return value.race; }
        public bool HasRace(string race) => Array.Exists(Rules.races, row => row.id == race);
    }
}
