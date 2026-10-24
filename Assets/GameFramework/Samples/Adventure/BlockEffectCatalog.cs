using System;
using System.Collections.Generic;
using UnityEngine;
using XLua;

namespace ProjectY.Samples
{
    /// <summary>Detached configuration shared by battle effects and item displays.</summary>
    public sealed class BlockEffectCatalog
    {
        public sealed class Skill { public BlockEffectProfile Profile; public string Trajectory; }
        public readonly Dictionary<int, BlockEffectProfile> Profiles = new Dictionary<int, BlockEffectProfile>();
        public readonly Dictionary<int, Skill> Skills = new Dictionary<int, Skill>();
        public readonly Dictionary<int, BlockEffectProfile> Items = new Dictionary<int, BlockEffectProfile>();
        public static BlockEffectProfile ReadProfile(LuaTable row)
        {
            if (!ColorUtility.TryParseHtmlString(row.Get<string>("color"), out var color) ||
                !ColorUtility.TryParseHtmlString(row.Get<string>("accent"), out var accent))
                throw new InvalidOperationException("Visual effect has an invalid color: " + row.Get<int>("id"));
            return new BlockEffectProfile { Id=row.Get<int>("id"), Name=row.Get<string>("name"), Pattern=row.Get<string>("pattern"),
                Color=color, Accent=accent, Count=row.Get<int>("count"), Lifetime=row.Get<float>("lifetime"),
                Size=row.Get<float>("size"), Radius=row.Get<float>("radius"), Height=row.Get<float>("height"),
                Emission=row.Get<float>("emission"), Speed=row.Get<float>("speed"), Gravity=row.Get<float>("gravity") };
        }
        public static BlockEffectProfile ReadOptionalProfile(LuaTable row, string key)
        { using (var profile=row.Get<LuaTable>(key)) return profile==null ? null : ReadProfile(profile); }
        public static BlockEffectCatalog Read(LuaTable root)
        {
            var result=new BlockEffectCatalog();
            using (var rows=root.Get<LuaTable>("profiles")) for (int i=1;i<=rows.Length;i++)
                using (var row=rows.Get<int,LuaTable>(i)) { var profile=ReadProfile(row); result.Profiles.Add(profile.Id,profile); }
            using (var rows=root.Get<LuaTable>("skills")) for (int i=1;i<=rows.Length;i++)
                using (var row=rows.Get<int,LuaTable>(i)) result.Skills.Add(row.Get<int>("id"),new Skill {
                    Profile=result.Profiles[row.Get<int>("profileId")],Trajectory=row.Get<string>("trajectory") });
            using (var rows=root.Get<LuaTable>("items")) for (int i=1;i<=rows.Length;i++)
                using (var row=rows.Get<int,LuaTable>(i)) result.Items.Add(row.Get<int>("id"),result.Profiles[row.Get<int>("profileId")]);
            return result;
        }
        public static BlockEffectProfile Variant(BlockEffectProfile p,string pattern,int count,float lifetime)
            => new BlockEffectProfile {Id=p.Id,Name=p.Name,Pattern=pattern,Color=p.Color,Accent=p.Accent,
                Count=count,Lifetime=lifetime,Size=p.Size,Radius=p.Radius,Height=p.Height,Emission=p.Emission,Speed=p.Speed,Gravity=p.Gravity};
    }

    public sealed class WorldEffectEvent
    {
        public int Sequence,SkillId,ItemId,SourceId,TargetId,SourceQ,SourceR,TargetQ,TargetR,Shot;
        public int SourceLayer,TargetLayer;
        public string Outcome;
        public static WorldEffectEvent[] Read(LuaTable root)
        {
            using (var rows=root.Get<LuaTable>("visualEffects"))
            {
                // Initial/load snapshots contain no historical presentation events.
                if (rows==null) return Array.Empty<WorldEffectEvent>();
                var result=new WorldEffectEvent[rows.Length];
                for (int i=0;i<result.Length;i++) using (var row=rows.Get<int,LuaTable>(i+1))
                    result[i]=new WorldEffectEvent {Sequence=row.Get<int>("sequence"),SkillId=row.Get<int>("skillId"),ItemId=row.Get<int>("itemId"),
                        SourceId=row.Get<int>("sourceId"),TargetId=row.Get<int>("targetId"),SourceQ=row.Get<int>("sourceQ"),SourceR=row.Get<int>("sourceR"),
                        TargetQ=row.Get<int>("targetQ"),TargetR=row.Get<int>("targetR"),Shot=row.Get<int>("shot"),Outcome=row.Get<string>("outcome")};
                for(int i=0;i<result.Length;i++) using(var row=rows.Get<int,LuaTable>(i+1))
                {result[i].SourceLayer=row.Get<int>("sourceLayer");result[i].TargetLayer=row.Get<int>("targetLayer");}
                return result;
            }
        }
    }
}
