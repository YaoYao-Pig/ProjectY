using System;
using System.Collections.Generic;
using System.IO;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;
using Object = UnityEngine.Object;

namespace ProjectY.Editor
{
    /// <summary>Creates the initial editable prefabs once. Subsequent syncs preserve authored layout.</summary>
    [InitializeOnLoad]
    public static class BattleHUDAssets
    {
        private static readonly Color Ink = new Color(.055f, .063f, .062f, .97f);
        private static readonly Color Tile = new Color(.105f, .116f, .106f);
        private static readonly Color Gold = new Color(.57f, .47f, .29f);
        private static readonly Color Bright = new Color(.89f, .78f, .52f);
        private static readonly Color Paper = new Color(.87f, .85f, .76f);
        private static readonly Color Muted = new Color(.57f, .60f, .55f);
        private static readonly Color Green = new Color(.36f, .61f, .49f);
        [Serializable] private sealed class IconTable { public IconRow[] rows; }
        [Serializable] private sealed class IconRow { public int id; public string spritePath; }

        static BattleHUDAssets()
        {
            LuaViewHints.Register(typeof(BattleHUDView), "CS.ProjectY.UI.BattleHUDView");
            LuaViewHints.Register(typeof(UIPointerState), "CS.ProjectY.UI.UIPointerState");
        }
        [MenuItem("Project Y/UI/创建战斗 HUD")]
        public static void Create()
        {
            RequireEditMode();
            CreateEntry("BattleAction", UIKind.Widget, BuildAction);
            CreateEntry("BattleParty", UIKind.Widget, root => BuildUnit(root, false));
            CreateEntry("BattleTurn", UIKind.Widget, root => BuildUnit(root, true));
            CreateEntry("BattleHUD", UIKind.Panel, BuildPanel);
            SyncIcons();
            Debug.Log("Battle HUD prefabs ready. Existing contents were preserved.");
        }
        private static void RequireEditMode()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("请先退出 Play。战斗 HUD 资源同步仅在 Edit Mode 执行。");
        }
        private static void CreateEntry(string name, UIKind kind, Action<GameObject> build)
        {
            var entry = PanelAssets.LoadOrCreate().Entries.Find(row => row.Name == name);
            if (entry == null) entry = PanelAssets.Save(new PanelDefinition {
                Name = name, Module = "Battle", Kind = kind, Layer = "Main", Modal = false,
                Cache = true, CloseOnBack = false, PauseWorldOnOpen = false
            }, null);
            PanelAssets.Generate(entry);
            var root = PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                if (root.transform.childCount == 0) build(root);
                root.GetComponent<LuaReference>().ValidateBindings();
                PrefabUtility.SaveAsPrefabAsset(root, entry.PrefabPath);
                LuaViewHints.Export(root.GetComponent<LuaReference>(), entry.ViewType);
            }
            finally { PrefabUtility.UnloadPrefabContents(root); }
        }
        [MenuItem("Project Y/UI/同步战斗图标引用")]
        public static void SyncIcons()
        {
            RequireEditMode();
            var rows = JsonUtility.FromJson<IconTable>(File.ReadAllText("Config/Tables/Adventure/BattleIconTable.json")).rows;
            var icons = new BattleHUDView.IconEntry[rows.Length];
            var ids = new HashSet<int>();
            for (var i = 0; i < rows.Length; i++)
            {
                var row = rows[i];
                if (row.id < 1 || !ids.Add(row.id) || row.spritePath == null) throw new InvalidOperationException("Invalid battle icon config.");
                var sprite = row.spritePath == "" ? null : AssetDatabase.LoadAssetAtPath<Sprite>(row.spritePath);
                if (row.spritePath != "" && sprite == null) throw new InvalidOperationException("Battle icon must reference a Sprite asset: " + row.spritePath);
                icons[i] = new BattleHUDView.IconEntry { Id = row.id, Path = row.spritePath, Sprite = sprite };
            }
            var entry = PanelAssets.LoadOrCreate().Get("BattleHUD");
            var root = PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                root.GetComponent<BattleHUDView>().SetEditorIcons(icons);
                PrefabUtility.SaveAsPrefabAsset(root, entry.PrefabPath);
            }
            finally { PrefabUtility.UnloadPrefabContents(root); }
            AssetDatabase.SaveAssets();
        }
        private static RectTransform Node(string name, Transform parent)
        {
            var root = new GameObject(name, typeof(RectTransform)); root.transform.SetParent(parent, false);
            return (RectTransform)root.transform;
        }
        private static void Stretch(RectTransform rect, float left = 0, float bottom = 0, float right = 0, float top = 0)
        {
            rect.anchorMin = Vector2.zero; rect.anchorMax = Vector2.one;
            rect.offsetMin = new Vector2(left, bottom); rect.offsetMax = new Vector2(-right, -top);
        }
        private static void Box(RectTransform rect, float x, float y, float width, float height, bool top = false)
        {
            rect.anchorMin = rect.anchorMax = new Vector2(0, top ? 1 : 0);
            rect.pivot = new Vector2(0, top ? 1 : 0); rect.anchoredPosition = new Vector2(x, top ? -y : y);
            rect.sizeDelta = new Vector2(width, height);
        }
        private static Image Paint(RectTransform rect, Color color, bool raycast = false)
        {
            var image = rect.gameObject.AddComponent<Image>(); image.color = color; image.raycastTarget = raycast; return image;
        }
        private static Image Plate(string name, Transform parent, Color color, bool raycast = false)
        {
            var rect = Node(name, parent); Stretch(rect); return Paint(rect, color, raycast);
        }
        private static RectTransform Frame(RectTransform root, Color color)
        {
            var border = Node("Frame", root); Stretch(border);
            var a = Plate("Top", border, color).rectTransform; a.anchorMin = new Vector2(0, 1); a.offsetMin = new Vector2(0, -1);
            var b = Plate("Bottom", border, color).rectTransform; b.anchorMax = new Vector2(1, 0); b.offsetMax = new Vector2(0, 1);
            var c = Plate("Left", border, color).rectTransform; c.anchorMax = new Vector2(0, 1); c.offsetMax = new Vector2(1, 0);
            var d = Plate("Right", border, color).rectTransform; d.anchorMin = new Vector2(1, 0); d.offsetMin = new Vector2(-1, 0);
            return border;
        }
        private static Text Label(string name, Transform parent, int size, Color color, TextAnchor alignment = TextAnchor.MiddleLeft)
        {
            var rect = Node(name, parent); Stretch(rect);
            var text = rect.gameObject.AddComponent<Text>(); text.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            text.fontSize = size; text.color = color; text.alignment = alignment; text.raycastTarget = false;
            text.horizontalOverflow = HorizontalWrapMode.Wrap; text.verticalOverflow = VerticalWrapMode.Truncate;
            text.supportRichText = false; return text;
        }
        private static Button Button(string name, Transform parent, out Text label)
        {
            var rect = Node(name, parent); var image = Paint(rect, Tile, true); Frame(rect, Gold);
            var button = rect.gameObject.AddComponent<Button>(); button.targetGraphic = image;
            var colors = button.colors; colors.highlightedColor = new Color(1.3f, 1.25f, 1.1f); colors.pressedColor = new Color(.7f, .8f, .7f);
            colors.disabledColor = new Color(.6f, .6f, .6f, .75f); button.colors = colors;
            button.navigation = new Navigation { mode = Navigation.Mode.None };
            label = Label("Label", rect, 13, Paper, TextAnchor.MiddleCenter); Stretch(label.rectTransform, 4, 1, 4, 1);
            return button;
        }
        private static GridLayoutGroup Grid(RectTransform root, int columns, Vector2 size)
        {
            var grid = root.gameObject.AddComponent<GridLayoutGroup>(); grid.constraint = GridLayoutGroup.Constraint.FixedColumnCount;
            grid.constraintCount = columns; grid.cellSize = size; grid.spacing = new Vector2(6, 8); return grid;
        }
        private static void Bind(GameObject root, params LuaReference.Entry[] entries)
        {
            var all = new List<LuaReference.Entry>(root.GetComponent<LuaReference>().GetEditorBindings()); all.AddRange(entries);
            root.GetComponent<LuaReference>().SetEditorBindings(all.ToArray());
        }
        private static LuaReference.Entry Ref(string key, Component value) => new LuaReference.Entry(key, value);
        private static void BuildAction(GameObject root)
        {
            var rect = (RectTransform)root.transform; rect.sizeDelta = new Vector2(74, 82);
            var back = Paint(rect, Tile, true); Frame(rect, Gold);
            var selected = Frame(rect, Bright); selected.name = "Selected";
            var button = root.AddComponent<Button>(); button.targetGraphic = back; button.navigation = new Navigation { mode = Navigation.Mode.None };
            var icon = Plate("Icon", rect, Color.white); Stretch(icon.rectTransform, 13, 28, 13, 18); icon.preserveAspect = true; icon.enabled = false;
            var title = Label("Title", rect, 12, Paper, TextAnchor.LowerCenter); Stretch(title.rectTransform, 2, 7, 2, 45);
            var cost = Label("Cost", rect, 10, Muted, TextAnchor.UpperRight); Stretch(cost.rectTransform, 3, 0, 5, 3);
            var shortcut = Label("Shortcut", rect, 10, Muted, TextAnchor.UpperLeft); Stretch(shortcut.rectTransform, 5, 0, 3, 3);
            Bind(root, Ref("Button", button), Ref("Icon", icon), Ref("Title", title), Ref("Cost", cost),
                Ref("Shortcut", shortcut), Ref("Selected", selected), Ref("Pointer", root.AddComponent<UIPointerState>()));
        }
        private static void BuildUnit(GameObject root, bool compact)
        {
            var rect = (RectTransform)root.transform; rect.sizeDelta = new Vector2(compact ? 78 : 180, compact ? 60 : 64);
            var back = Paint(rect, Ink, true); Frame(rect, Gold);
            var active = Frame(rect, Bright); active.name = "Active";
            var side = Plate("Side", rect, Green); Box(side.rectTransform, 0, 0, 3, compact ? 60 : 64);
            var name = Label("Name", rect, compact ? 11 : 14, Paper, compact ? TextAnchor.MiddleCenter : TextAnchor.MiddleLeft);
            name.resizeTextForBestFit = true; name.resizeTextMinSize = compact ? 9 : 11; name.resizeTextMaxSize = compact ? 11 : 14;
            Stretch(name.rectTransform, compact ? 4 : 12, compact ? 29 : 33, 6, 5);
            var detail = Label("Detail", rect, compact ? 10 : 11, Muted, compact ? TextAnchor.MiddleCenter : TextAnchor.MiddleLeft);
            Stretch(detail.rectTransform, compact ? 4 : 12, 12, 6, compact ? 29 : 33);
            var track = Node("Health", rect); Stretch(track, compact ? 6 : 12, 7, compact ? 6 : 12, compact ? 50 : 54); Paint(track, Tile);
            var hp = Plate("Fill", track, Green);
            var button = root.AddComponent<Button>(); button.targetGraphic = back; button.navigation = new Navigation { mode = Navigation.Mode.None };
            Bind(root, Ref("Name", name), Ref("Detail", detail), Ref("Health", hp), Ref("Active", active), Ref("Side", side),
                Ref("Group", root.GetComponent<CanvasGroup>()), Ref("Button", button));
        }
        private static void BuildPanel(GameObject root)
        {
            var rect = (RectTransform)root.transform;
            var safe = Node("SafeArea", rect); Stretch(safe);
            var header = Node("Encounter", safe); Paint(header, Ink, true); Frame(header, Gold);
            var encounter = Label("EncounterName", header, 15, Paper); Stretch(encounter.rectTransform, 12, 31, 8, 5);
            var round = Label("Round", header, 12, Bright); Stretch(round.rectTransform, 12, 7, 8, 35);
            var turns = Node("Initiative", safe); var turnGrid = Grid(turns, 8, new Vector2(78, 60));
            var party = Node("Party", safe); var partyGrid = party.gameObject.AddComponent<VerticalLayoutGroup>();
            partyGrid.spacing = 8; partyGrid.childControlHeight = false; partyGrid.childControlWidth = true;
            partyGrid.childForceExpandHeight = false; partyGrid.childForceExpandWidth = true;
            var topControls = Node("TopControls", safe); topControls.anchorMin = topControls.anchorMax = Vector2.one;
            topControls.pivot = Vector2.one; topControls.anchoredPosition = new Vector2(-16, -16); topControls.sizeDelta = new Vector2(174, 60);
            Text autoText, logText; var auto = Button("AutoAI", topControls, out autoText); Box((RectTransform)auto.transform, 0, 32, 174, 28);
            var logToggle = Button("LogToggle", topControls, out logText); Box((RectTransform)logToggle.transform, 0, 0, 174, 26);
            var deck = Node("ActionDeck", safe); Paint(deck, Ink, true); Frame(deck, Gold);
            var accent = Plate("CrownLine", deck, Bright).rectTransform; accent.anchorMin = new Vector2(.38f, 1); accent.anchorMax = new Vector2(.62f, 1); accent.offsetMin = new Vector2(0, -2); accent.offsetMax = Vector2.zero;
            var actor = Node("ActiveActor", deck);
            var actorName = Label("ActorName", actor, 20, Paper); Box(actorName.rectTransform, 0, 0, 190, 30, true);
            var hpText = Label("HealthText", actor, 12, Paper); Box(hpText.rectTransform, 0, 34, 190, 20, true);
            var healthTrack = Node("Health", actor); Box(healthTrack, 0, 57, 182, 5, true); Paint(healthTrack, Tile); var health = Plate("Fill", healthTrack, Green);
            var ap = Label("AP", actor, 15, Bright); Box(ap.rectTransform, 0, 70, 190, 23, true);
            var resources = Label("Resources", actor, 11, Muted); Box(resources.rectTransform, 0, 99, 190, 36, true);
            var skills = Node("Skills", deck); var skillTitle = Label("SectionLabel", skills, 12, Bright); Box(skillTitle.rectTransform, 0, 0, 160, 22, true);
            var skillSlots = Node("Slots", skills); Stretch(skillSlots, 0, 0, 0, 28); var skillGrid = Grid(skillSlots, 8, new Vector2(74, 82));
            var items = Node("Items", deck); var itemTitle = Label("SectionLabel", items, 12, Muted); Box(itemTitle.rectTransform, 0, 0, 110, 22, true);
            var itemSlots = Node("Slots", items); Stretch(itemSlots, 0, 0, 0, 28); var itemGrid = Grid(itemSlots, 4, new Vector2(40, 82));
            var hint = Node("Hint", deck); var hintText = Label("Text", hint, 11, Muted);
            var commands = Node("Commands", deck);
            Text endText, moveText, focusText; var endTurn = Button("EndTurn", commands, out endText); Box((RectTransform)endTurn.transform, 0, 0, 142, 46, true);
            endTurn.targetGraphic.color = new Color(.22f, .27f, .20f); endText.color = Bright;
            var move = Button("Move", commands, out moveText); Box((RectTransform)move.transform, 0, 54, 142, 32, true);
            var focus = Button("Focus", commands, out focusText); Box((RectTransform)focus.transform, 0, 94, 142, 28, true);
            Text prevText, nextText; var prev = Button("PreviousSkills", skills, out prevText); var next = Button("NextSkills", skills, out nextText);
            var prevRect = (RectTransform)prev.transform; prevRect.anchorMin = prevRect.anchorMax = Vector2.one; prevRect.pivot = Vector2.one; prevRect.anchoredPosition = new Vector2(-28, 0); prevRect.sizeDelta = new Vector2(24, 22);
            var nextRect = (RectTransform)next.transform; nextRect.anchorMin = nextRect.anchorMax = Vector2.one; nextRect.pivot = Vector2.one; nextRect.anchoredPosition = Vector2.zero; nextRect.sizeDelta = new Vector2(24, 22);
            prevText.text = "<"; nextText.text = ">";
            var log = Node("CombatLog", safe); Paint(log, new Color(Ink.r, Ink.g, Ink.b, .9f), true); Frame(log, Gold);
            var logs = Label("Lines", log, 12, Muted, TextAnchor.LowerLeft); Stretch(logs.rectTransform, 14, 10, 14, 10);
            var tooltip = Node("Tooltip", safe); Paint(tooltip, Ink); Frame(tooltip, Bright);
            var tipTitle = Label("Title", tooltip, 17, Bright); Box(tipTitle.rectTransform, 14, 10, 352, 28, true);
            var tipBody = Label("Body", tooltip, 12, Paper, TextAnchor.UpperLeft); Stretch(tipBody.rectTransform, 14, 14, 14, 46);
            var hud = root.AddComponent<BattleHUDView>();
            hud.SetEditorLayout(new BattleHUDView.Layout { Root = rect, SafeArea = safe, Header = header, Turns = turns, Party = party,
                Deck = deck, Actor = actor, Skills = skills, Items = items, Commands = commands, Hint = hint, Log = log, Tooltip = tooltip,
                SkillGrid = skillGrid, ItemGrid = itemGrid, TurnGrid = turnGrid, Labels = root.GetComponentsInChildren<Text>(true) });
            Bind(root, Ref("HUD", hud), Ref("Group", root.GetComponent<CanvasGroup>()), Ref("Encounter", encounter), Ref("Round", round),
                Ref("PartySlots", party), Ref("TurnSlots", turns), Ref("SkillSlots", skillSlots), Ref("ItemSlots", itemSlots),
                Ref("ActorName", actorName), Ref("HealthText", hpText), Ref("Health", health), Ref("AP", ap), Ref("Resources", resources),
                Ref("SkillTitle", skillTitle), Ref("ItemTitle", itemTitle), Ref("Hint", hintText), Ref("EndTurn", endTurn), Ref("EndTurnText", endText),
                Ref("Move", move), Ref("MoveText", moveText), Ref("Focus", focus), Ref("FocusText", focusText), Ref("Auto", auto), Ref("AutoText", autoText),
                Ref("LogToggle", logToggle), Ref("LogToggleText", logText), Ref("Previous", prev), Ref("Next", next), Ref("Log", log), Ref("Logs", logs),
                Ref("Tooltip", tooltip), Ref("TipTitle", tipTitle), Ref("TipBody", tipBody));
            hud.PreviewLayout(1280);
        }
    }
}
