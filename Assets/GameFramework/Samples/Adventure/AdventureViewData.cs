using System;
using UnityEngine;
using XLua;

namespace ProjectY.Samples
{
    // 仅显示副本。每次命令后读取一次，所有 LuaTable 在当前调用中释放。
    public sealed class AdventureViewData
    {
        public sealed class Actor
        {
            public int Id, Team, HP, MaxHP, AP, Q, R, Guard;
            public string Name, Traits;
            public bool Moved, MainUsed;
            public PawnAppearanceData Appearance;
        }
        public sealed class Site { public int Id, AreaConfigId; public string Name, Reason; public Vector3 Position; public bool Available, Visited; }
        public sealed class Choice { public int Id; public string Label, Reason; public bool Available; }
        public sealed class Cell { public int Q, R; public bool Blocked; }
        public sealed class Skill { public int Id, Cost; public string Name, Description, Action; public int[] Targets; }
        public string Phase, Result, Error, EventTitle, EventText, Encounter;
        public int Coins, Round, ActiveId, Radius;
        public Actor[] Party, Units;
        public Site[] Sites;
        public Choice[] Choices;
        public Cell[] Cells, Reachable;
        public Skill[] Skills;
        public string[] Logs;
        public MapAreaViewData.State Area;

        private static T[] Rows<T>(LuaTable parent, string key, Func<LuaTable, T> read)
        {
            using (var rows = parent.Get<LuaTable>(key))
            {
                var result = new T[rows.Length];
                for (var i = 0; i < result.Length; i++)
                    using (var row = rows.Get<int, LuaTable>(i + 1)) result[i] = read(row);
                return result;
            }
        }
        private static T[] Values<T>(LuaTable parent, string key)
        {
            using (var values = parent.Get<LuaTable>(key))
            {
                var result = new T[values.Length];
                for (var i = 0; i < result.Length; i++) result[i] = values.Get<int, T>(i + 1);
                return result;
            }
        }
        private static Actor ReadActor(LuaTable row) => new Actor {
            Id = row.Get<int>("id"), Team = row.Get<int>("team"), Name = row.Get<string>("name"),
            Traits = row.Get<string>("traits"), HP = row.Get<int>("hp"), MaxHP = row.Get<int>("maxHP"),
            AP = row.Get<int>("ap"), Q = row.Get<int>("q"), R = row.Get<int>("r"), Guard = row.Get<int>("guard"),
            Moved = row.Get<bool>("moved"), MainUsed = row.Get<bool>("mainUsed") };
        private static Cell ReadCell(LuaTable row) => new Cell { Q = row.Get<int>("q"), R = row.Get<int>("r"), Blocked = row.Get<bool>("blocked") };
        private static Actor ReadPartyActor(LuaTable row)
        {
            var actor = ReadActor(row);
            using (var appearance = row.Get<LuaTable>("appearance")) actor.Appearance = PawnAppearanceData.Read(appearance);
            return actor;
        }
        public static AdventureViewData Read(LuaTable root) => new AdventureViewData {
            Area = MapAreaViewData.ReadState(root),
            Phase = root.Get<string>("phase"), Result = root.Get<string>("result"), Error = root.Get<string>("error"),
            EventTitle = root.Get<string>("eventTitle"), EventText = root.Get<string>("eventText"), Encounter = root.Get<string>("encounter"),
            Coins = root.Get<int>("coins"), Round = root.Get<int>("round"), ActiveId = root.Get<int>("activeId"), Radius = root.Get<int>("radius"),
            Party = Rows(root, "party", ReadPartyActor), Units = Rows(root, "units", ReadActor), Cells = Rows(root, "cells", ReadCell),
            Reachable = Rows(root, "reachable", ReadCell), Logs = Values<string>(root, "logs"),
            Sites = Rows(root, "sites", row => new Site { Id = row.Get<int>("id"), Name = row.Get<string>("name"),
                AreaConfigId = row.Get<int>("areaConfigId"), Reason = row.Get<string>("reason"),
                Position = new Vector3(row.Get<float>("x"), row.Get<float>("y"), row.Get<float>("z")),
                Available = row.Get<bool>("available"), Visited = row.Get<bool>("visited") }),
            Choices = Rows(root, "choices", row => new Choice { Id = row.Get<int>("id"), Label = row.Get<string>("label"),
                Reason = row.Get<string>("reason"), Available = row.Get<bool>("available") }),
            Skills = Rows(root, "skills", row => new Skill { Id = row.Get<int>("id"), Cost = row.Get<int>("cost"), Name = row.Get<string>("name"),
                Action = row.Get<string>("action"), Description = row.Get<string>("description"), Targets = Values<int>(row, "targets") })
        };
        public Actor Active => Array.Find(Units, actor => actor.Id == ActiveId);
    }
}
