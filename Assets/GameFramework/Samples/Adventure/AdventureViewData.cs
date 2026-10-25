using System;
using UnityEngine;
using XLua;

namespace ProjectY.Samples
{
    // 仅显示副本。每次命令后读取一次，所有 LuaTable 在当前调用中释放。
    public sealed class AdventureViewData
    {
        public ProjectY.Data.WorldMapExplorationData WorldFog;
        public sealed class Actor
        {
            public int Id, Team, HP, MaxHP, AP, Q, R, Guard, CellIndex;
            public string Name, Traits;
            public bool Moved, MainUsed,FixedFootprint;
            public PawnAppearanceData Appearance;
            public int ActionSequence;
            public ProjectY.Data.CombatActorData.PresentationAction[] Actions;
            public int[] OccupiedCells;
            public int MovementSequence;
            public string MovementStyle;
        }
        public sealed class Site { public int Id, AreaConfigId, Q, R, WorldTownId; public string Name, Reason, Kind; public Vector3 Position; public bool Available, Visited; }
        public sealed class Choice { public int Id; public string Label, Reason; public bool Available; }
        public sealed class Cell { public int Q, R, CellIndex; public bool Blocked; }
        public sealed class TargetPreview
        {
            public int Id, BlockerCount;
            public float HitChance, InterceptChance;
            public bool FriendlyRisk;
            public string Description;
        }
        public sealed class Skill
        {
            public int Id, Cost, MaxTargets;
            public string Name, Description, Action;
            public bool ManualTargets, Guided, NeedsLanding;
            public int[] Targets, TargetCells, ContainerTargets;
            public int[] RangeCells = Array.Empty<int>();
            public TargetPreview[] TargetPreviews;
            public LandingOption[] LandingOptions=Array.Empty<LandingOption>();
        }
        public sealed class LandingOption { public int TargetId; public Cell[] Cells; }
        public sealed class Trap { public int Q, R, SourceId; public string Name; }
        public string Phase, BattlePhase, Result, Error, EventTitle, EventText, Encounter;
        public int Coins, Round, ActiveId, Radius;
        public Actor[] Party, Units;
        public Site[] Sites;
        public Choice[] Choices;
        public Cell[] Cells, Reachable;
        public Skill[] Skills;
        public Trap[] Traps=Array.Empty<Trap>();
        public string[] Logs;
        public WorldEffectEvent[] VisualEffects=Array.Empty<WorldEffectEvent>();
        public MapAreaViewData.State Area;
        public sealed class TravelState
        {
            public Vector3 Position;
            public Vector3[] Route;
            public bool Active,Paused;
            public int Speed;
        }
        public TravelState Travel;
        public sealed class WorldParty { public int Id;public string Name,Kind,Status,ModelPath;public Vector3 Position; }
        public sealed class WorldPartyState { public string PlayerModelPath;public WorldParty[] Rows; }
        public WorldPartyState WorldParties;
        private static WorldPartyState ReadWorldParties(LuaTable root)
        {
            using(var row=root.Get<LuaTable>("worldParties"))
            {
                if(row==null)throw new InvalidOperationException("Adventure snapshot lacks world parties.");
                return new WorldPartyState {PlayerModelPath=row.Get<string>("playerModelPath"),Rows=Rows(row,"rows",party=>new WorldParty {
                    Id=party.Get<int>("id"),Name=party.Get<string>("name"),Kind=party.Get<string>("kind"),Status=party.Get<string>("status"),ModelPath=party.Get<string>("modelPath"),
                    Position=new Vector3(party.Get<float>("x"),party.Get<float>("y"),party.Get<float>("z"))})};
            }
        }
        public sealed class TorchState
        {
            public bool Available, Enabled;
            public int Count;
            public string Label;
        }
        public TorchState Torch;
        private static TorchState ReadTorch(LuaTable root)
        {
            using (var row = root.Get<LuaTable>("torch"))
            {
                if (row == null) throw new InvalidOperationException("Adventure snapshot lacks torch state.");
                return new TorchState { Available = row.Get<bool>("available"), Enabled = row.Get<bool>("enabled"),
                    Count = row.Get<int>("count"), Label = row.Get<string>("label") };
            }
        }
        private static TravelState ReadTravel(LuaTable root)
        {
            using(var row=root.Get<LuaTable>("travel"))
            {
                if(row==null)throw new InvalidOperationException("Adventure snapshot lacks world travel.");
                return new TravelState {Position=new Vector3(row.Get<float>("x"),row.Get<float>("y"),row.Get<float>("z")),
                    Active=row.Get<bool>("active"),Paused=row.Get<bool>("paused"),Speed=row.Get<int>("speed"),
                    Route=Rows(row,"route",point=>new Vector3(point.Get<float>("x"),point.Get<float>("y"),point.Get<float>("z")))};
            }
        }

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
        public static Actor ReadActor(LuaTable row)
        {
            var actor = new Actor {
            Id = row.Get<int>("id"), Team = row.Get<int>("team"), Name = row.Get<string>("name"),
            Traits = row.Get<string>("traits"), HP = row.Get<int>("hp"), MaxHP = row.Get<int>("maxHP"),
            AP = row.Get<int>("ap"), Q = row.Get<int>("q"), R = row.Get<int>("r"), Guard = row.Get<int>("guard"),
            FixedFootprint=row.Get<bool>("fixedFootprint"), Moved = row.Get<bool>("moved"), MainUsed = row.Get<bool>("mainUsed"), CellIndex = row.Get<int>("cellIndex") - 1 };
            using (var appearance = row.Get<LuaTable>("appearance")) actor.Appearance = PawnAppearanceData.Read(appearance);
            var source = row.Get<ProjectY.Data.CombatActorData>("presentationActor");
            if (source == null) throw new InvalidOperationException("Actor snapshot lacks its presentation source.");
            actor.ActionSequence = source.ActionSequence;
            actor.Actions = source.CopyPresentationActions();
            actor.MovementSequence=source.MovementSequence;actor.MovementStyle=source.MovementStyle;
            actor.OccupiedCells=Values<int>(row,"occupiedCells");
            for(int i=0;i<actor.OccupiedCells.Length;i++)actor.OccupiedCells[i]--;
            return actor;
        }
        private static Cell ReadCell(LuaTable row) => new Cell { Q = row.Get<int>("q"), R = row.Get<int>("r"), Blocked = row.Get<bool>("blocked"), CellIndex = row.Get<int>("cellIndex") - 1 };
        public static AdventureViewData Read(LuaTable root) => new AdventureViewData {
            WorldFog=root.Get<ProjectY.Data.WorldMapExplorationData>("worldFog"),
            VisualEffects=WorldEffectEvent.Read(root),
            Travel=ReadTravel(root), WorldParties=ReadWorldParties(root), Torch=ReadTorch(root),
            Area = MapAreaViewData.ReadState(root),
            Phase = root.Get<string>("phase"), BattlePhase = root.Get<string>("battlePhase"), Result = root.Get<string>("result"), Error = root.Get<string>("error"),
            EventTitle = root.Get<string>("eventTitle"), EventText = root.Get<string>("eventText"), Encounter = root.Get<string>("encounter"),
            Coins = root.Get<int>("coins"), Round = root.Get<int>("round"), ActiveId = root.Get<int>("activeId"), Radius = root.Get<int>("radius"),
            Party = Rows(root, "party", ReadActor), Units = Rows(root, "units", ReadActor), Cells = Rows(root, "cells", ReadCell),
            Reachable = Rows(root, "reachable", ReadCell), Logs = Values<string>(root, "logs"),
            Traps=Rows(root,"traps",row=>new Trap { Q=row.Get<int>("q"),R=row.Get<int>("r"),SourceId=row.Get<int>("sourceId"),Name=row.Get<string>("name") }),
            Sites = Rows(root, "sites", row => new Site { Id = row.Get<int>("id"), Name = row.Get<string>("name"),
                Q = row.Get<int>("q"), R = row.Get<int>("r"), WorldTownId = row.Get<int>("worldTownId"),
                AreaConfigId = row.Get<int>("areaConfigId"), Reason = row.Get<string>("reason"), Kind = row.Get<string>("kind"),
                Position = new Vector3(row.Get<float>("x"), row.Get<float>("y"), row.Get<float>("z")),
                Available = row.Get<bool>("available"), Visited = row.Get<bool>("visited") }),
            Choices = Rows(root, "choices", row => new Choice { Id = row.Get<int>("id"), Label = row.Get<string>("label"),
                Reason = row.Get<string>("reason"), Available = row.Get<bool>("available") }),
            Skills = Rows(root, "skills", row => new Skill { Id = row.Get<int>("id"), Cost = row.Get<int>("cost"), Name = row.Get<string>("name"),
                Action = row.Get<string>("action"), Description = row.Get<string>("description"), Targets = Values<int>(row, "targets"),
                TargetCells = Values<int>(row,"targetCells"),ContainerTargets=Values<int>(row,"containerTargets"),RangeCells=Values<int>(row,"rangeCells"),
                ManualTargets=row.Get<bool>("manualTargets"),MaxTargets=row.Get<int>("maxTargets"),Guided=row.Get<bool>("guided"),
                NeedsLanding=row.Get<bool>("needsLanding"),
                LandingOptions=Rows(row,"landingOptions",option=>new LandingOption { TargetId=option.Get<int>("targetId"),Cells=Rows(option,"cells",ReadCell) }),
                TargetPreviews=Rows(row,"targetPreviews",preview=>new TargetPreview {
                    Id=preview.Get<int>("id"),HitChance=preview.Get<float>("hitChance"),InterceptChance=preview.Get<float>("interceptChance"),
                    BlockerCount=preview.Get<int>("blockerCount"),FriendlyRisk=preview.Get<bool>("friendlyRisk"),Description=preview.Get<string>("description") }) })
        };
        public Actor Active => Array.Find(Units, actor => actor.Id == ActiveId);
        public void RetainPollingFeedback(AdventureViewData previous)
        {
            if(previous!=null && Phase==previous.Phase)Error=previous.Error;
        }
    }
}
