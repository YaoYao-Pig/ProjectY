using System;
using System.Collections.Generic;
using UnityEngine;
using XLua;

namespace ProjectY.Samples
{
    /// <summary>演示输入与显示。所有玩法命令交给现有 Lua 运行时，不持有规则或权威状态。</summary>
    public sealed class AdventureRuntimeDemo : MonoBehaviour
    {
        [SerializeField] private GameBootstrap bootstrap;
        [SerializeField] private Camera mapCamera;
        [SerializeField] private Shader previewShader;
        [SerializeField] private MapRuntimeDemo.AssetBinding[] assetBindings;
        [SerializeField] private PawnView pawnPrefab;
        [SerializeField] private MapRuntimeDemo.AssetBinding[] pawnBindings;
        private const string Bridge = "Game.Adventure.DemoBridge";
        private const float PanelWidth = 320;
        private readonly Dictionary<int, MapRuntimeDemo.AssetBinding> assets = new Dictionary<int, MapRuntimeDemo.AssetBinding>();
        private MapPreviewRenderer mapRenderer;
        private MapAreaRenderer areaRenderer;
        private SquadPawnRenderer squadRenderer;
        private TownNpcRenderer townNpcs;
        private TownWalkCamera townCamera;
        private bool thirdPerson, wasWalking;
        private float nextWalkCommand;
        private readonly Dictionary<int, MapRuntimeDemo.AssetBinding> pawnAssets = new Dictionary<int, MapRuntimeDemo.AssetBinding>();
        private MapAreaViewData areaLayout;
        private bool revealArea, followParty = true;
        private float nextAreaPoll;
        private Vector3 worldFocus, displayedParty;
        private float worldZoom, worldYaw, worldPitch;
        private AdventureViewData view;
        private Vector3 focus;
        private float zoom, yaw = -25, pitch = 52, nextAI;
        private int selectedSkill, lastActor;
        private bool moveSelected = true, autoAI = true;
        private string fatalError;
        private Font font;
        private Texture2D hexTexture, circleTexture;
        private GUIStyle textStyle, titleStyle, subtitleStyle, buttonStyle, tokenStyle, smallStyle, healthStyle, toggleStyle;
        private Vector2 sidebarScroll;
        private static readonly Color Background = new Color(.045f, .07f, .085f);
        private static readonly Color Panel = new Color(.075f, .105f, .12f);
        private static readonly Color Teal = new Color(.31f, .83f, .71f);
        private static readonly Color Gold = new Color(.97f, .76f, .43f);
        private static readonly Color Enemy = new Color(.86f, .40f, .35f);
        public string Phase => view?.Phase;
        public string LastError => fatalError ?? view?.Error;

        private void Start()
        {
            if (bootstrap == null || mapCamera == null || previewShader == null || assetBindings == null || pawnPrefab == null || pawnBindings == null)
                throw new InvalidOperationException("远征演示未绑定宿主、相机或地图资源。");
            foreach (var binding in assetBindings) assets.Add(binding.id, binding);
            foreach (var binding in pawnBindings) pawnAssets.Add(binding.id, binding);
            font = Font.CreateDynamicFontFromOSFont(new[] { "Microsoft YaHei", "Noto Sans CJK SC", "Arial" }, 16);
            hexTexture = ShapeTexture(false); circleTexture = ShapeTexture(true);
            mapRenderer = new MapPreviewRenderer(previewShader, transform);
            StartExpedition();
        }
        private static Texture2D ShapeTexture(bool circle)
        {
            const int size = 128;
            var texture = new Texture2D(size, size, TextureFormat.RGBA32, false) { filterMode = FilterMode.Bilinear, wrapMode = TextureWrapMode.Clamp };
            var pixels = new Color[size * size];
            for (var y = 0; y < size; y++) for (var x = 0; x < size; x++)
            {
                var u = Mathf.Abs((x + .5f) / size * 2 - 1); var v = Mathf.Abs((y + .5f) / size * 2 - 1);
                var inside = circle ? u * u + v * v <= .98f : v <= 1 - u * .5f;
                pixels[y * size + x] = inside ? Color.white : Color.clear;
            }
            texture.SetPixels(pixels); texture.Apply(false, true); return texture;
        }
        public void StartExpedition()
        {
            try
            {
                var values = bootstrap.CallModule(Bridge, "start");
                using (var mapRoot = (LuaTable)values[0])
                using (var stateRoot = (LuaTable)values[1])
                {
                    var map = MapPreviewData.Read(mapRoot);
                    mapRenderer.Build(map, asset => {
                        if (!assets.TryGetValue(asset.Id, out var binding) || binding.path != asset.Path || binding.prefab == null)
                            throw new InvalidOperationException("地图资源绑定不一致：" + asset.Id);
                        return binding.prefab;
                    });
                    SetView(AdventureViewData.Read(stateRoot));
                }
                fatalError = null; FitMap();
            }
            catch (Exception exception) { Report(exception); }
        }
        // 也是此 demo 的最小自动化入口：与按钮使用相同命令，不绕过玩法检查。
        public void SendCommand(string command, int a = 0, int b = 0)
        {
            if (fatalError != null) return;
            try
            {
                var values = bootstrap.CallModule(Bridge, command, a, b);
                using (var root = (LuaTable)values[0]) SetView(AdventureViewData.Read(root));
            }
            catch (Exception exception) { Report(exception); }
        }
        private void SetView(AdventureViewData value)
        {
            if (value.Phase == "area" && view?.Phase != "area")
            {
                worldFocus = focus; worldZoom = zoom; worldYaw = yaw; worldPitch = pitch;
                var values = bootstrap.CallModule(Bridge, "area_layout");
                using (var root = (LuaTable)values[0]) areaLayout = MapAreaViewData.Read(root);
                if (!assets.TryGetValue(areaLayout.AssetId, out var binding) || binding.path != areaLayout.AssetPath || binding.prefab == null)
                    throw new InvalidOperationException("MapArea 模型配置与场景绑定不一致，请同步地图资源引用。");
                areaRenderer = new MapAreaRenderer(previewShader, binding.prefab, areaLayout, asset => {
                    if (!assets.TryGetValue(asset.Id, out var prop) || prop.path != asset.Path || prop.prefab == null)
                        throw new InvalidOperationException("MapArea 陈设绑定缺失，请同步地图资源引用：" + asset.Id);
                    return prop.prefab;
                });
                revealArea = false; followParty = true;
                squadRenderer = new SquadPawnRenderer(transform, pawnPrefab, part => {
                    if (!pawnAssets.TryGetValue(part.Id, out var item) || item.path != part.Path || item.prefab == null)
                        throw new InvalidOperationException("棋子部件与配置不一致，请同步棋子资源引用：" + part.Id);
                    return item.prefab;
                });
                if (areaLayout.IsTown)
                {
                    townNpcs = new TownNpcRenderer(transform, pawnPrefab, areaLayout, ResolvePawnPart);
                    townCamera = new TownWalkCamera(areaLayout, value.Area, areaRenderer.CameraObstacles);
                    thirdPerson = true; wasWalking = false;
                }
                focus = displayedParty = areaLayout.Cells[value.Area.CellIndex].Position;
                zoom = 13 * areaLayout.Radius; pitch = 65; yaw = -25;
            }
            else if (value.Phase != "area" && view?.Phase == "area")
            {
                squadRenderer.Dispose(); squadRenderer = null;
                townNpcs?.Dispose(); townNpcs = null; townCamera = null; thirdPerson = false;
                areaRenderer.Dispose(); areaRenderer = null; areaLayout = null;
                focus = worldFocus; zoom = worldZoom; yaw = worldYaw; pitch = worldPitch;
            }
            view = value;
            if (view.Phase == "area")
            {
                areaRenderer.UpdateVisibility(view.Area, revealArea); squadRenderer.SetState(view.Area, view.Party, areaLayout);
                townNpcs?.SetState(view.Area, areaLayout);
            }
            if (view.ActiveId != lastActor)
            {
                lastActor = view.ActiveId; moveSelected = true; selectedSkill = 0;
                nextAI = Time.unscaledTime + .8f;
            }
        }
        private GameObject ResolvePawnPart(PawnAppearanceData.Part part)
        {
            if (!pawnAssets.TryGetValue(part.Id, out var item) || item.path != part.Path || item.prefab == null)
                throw new InvalidOperationException("棋子部件与配置不一致，请同步棋子资源引用：" + part.Id);
            return item.prefab;
        }
        private void Report(Exception exception)
        {
            fatalError = exception.Message;
            Debug.LogException(exception, this);
        }
        public void FitMap()
        {
            var bounds = view?.Phase == "area" ? areaRenderer.Bounds : mapRenderer.Bounds; focus = bounds.center;
            if (view?.Phase == "area") followParty = false;
            var inverse = Quaternion.Inverse(Quaternion.Euler(pitch, yaw, 0)); var extent = Vector2.zero;
            for (var x = -1; x <= 1; x += 2) for (var y = -1; y <= 1; y += 2) for (var z = -1; z <= 1; z += 2)
            {
                var corner = inverse * Vector3.Scale(bounds.extents, new Vector3(x, y, z));
                extent.x = Mathf.Max(extent.x, Mathf.Abs(corner.x)); extent.y = Mathf.Max(extent.y, Mathf.Abs(corner.y));
            }
            zoom = Mathf.Max(8, Mathf.Max(extent.y, extent.x / Mathf.Max(.2f, (Screen.width - PanelWidth) / Screen.height)) * 1.18f);
        }
        private void Update()
        {
            if (view == null || fatalError != null) return;
            if (view.Phase == "area")
            {
                if (Time.unscaledTime >= nextAreaPoll) { SendCommand("snapshot"); nextAreaPoll = Time.unscaledTime + .10f; }
                if (fatalError != null) return;
                displayedParty = Vector3.Lerp(displayedParty, areaLayout.Cells[view.Area.CellIndex].Position, 1 - Mathf.Exp(-Time.unscaledDeltaTime * 18));
                squadRenderer.Tick(Time.deltaTime);
                townNpcs?.Tick(Time.deltaTime);
                if (followParty) focus = displayedParty;
                if (Input.GetKeyDown(KeyCode.Space)) SendCommand("area_stop");
                if (townCamera != null)
                {
                    if (Input.GetKeyDown(KeyCode.V)) ToggleTownCamera();
                    if (Input.GetKeyDown(KeyCode.Escape) && view.Area.InteractionKind != 0) SendCommand("area_close");
                    if (Input.GetKeyDown(KeyCode.E) && view.Area.InteractionKind == 0)
                    {
                        NearestInteraction(out var kind, out var id, out _);
                        if (kind != 0) SendCommand("area_interact", kind, id);
                    }
                    if (thirdPerson)
                    {
                        townCamera.Orbit();
                        if (view.Area.InteractionKind != 0 || Input.GetKey(KeyCode.Space)) { townCamera.ResetSteering(); wasWalking = false; return; }
                        var direction = townCamera.Direction(areaLayout, view.Area, Time.deltaTime);
                        if (wasWalking && !townCamera.Walking) SendCommand("area_stop");
                        wasWalking = townCamera.Walking;
                        if (direction != 0 && Time.unscaledTime >= nextWalkCommand)
                        { SendCommand("area_walk", direction); nextWalkCommand = Time.unscaledTime + .10f; }
                        return;
                    }
                }
            }
            if (view.Phase == "battle" && view.Active.Team == 2 && autoAI && Time.unscaledTime >= nextAI)
            {
                SendCommand("ai"); nextAI = Time.unscaledTime + .8f;
            }
            if ((view.Phase != "map" && view.Phase != "area") || Input.mousePosition.x <= PanelWidth) return;
            if (Input.GetKeyDown(KeyCode.F)) FitMap();
            zoom = Mathf.Clamp(zoom * Mathf.Exp(-Input.mouseScrollDelta.y * .12f), 3, 2000);
            if (Input.GetMouseButton(1)) { yaw += Input.GetAxis("Mouse X") * 3; pitch = Mathf.Clamp(pitch - Input.GetAxis("Mouse Y") * 2, 20, 85); }
            var step = new Vector3(Input.GetAxisRaw("Horizontal"), 0, Input.GetAxisRaw("Vertical")) * zoom * Time.unscaledDeltaTime;
            if (Input.GetMouseButton(2)) step += new Vector3(-Input.GetAxis("Mouse X"), 0, -Input.GetAxis("Mouse Y")) * zoom * .035f;
            focus += Quaternion.Euler(0, yaw, 0) * step;
            if (step.sqrMagnitude > 0 && view.Phase == "area") followParty = false;
            if (view.Phase == "area" && Input.GetMouseButtonDown(0))
            {
                var index = areaRenderer.Pick(mapCamera.ScreenPointToRay(Input.mousePosition));
                if (index >= 0) SendCommand("area_move", areaLayout.Cells[index].Q, areaLayout.Cells[index].R);
            }
        }
        private void LateUpdate()
        {
            if (view == null || mapRenderer == null) return;
            if (thirdPerson)
            {
                townCamera.Apply(mapCamera, squadRenderer.Position(view.Area.Members[0].ActorId));
                mapRenderer.SetVisible(false); areaRenderer.Draw(mapCamera); return;
            }
            mapCamera.orthographic = true; mapCamera.nearClipPlane = .1f;
            var fraction = Mathf.Min(.7f, PanelWidth / Screen.width);
            mapCamera.rect = new Rect(fraction, 0, 1 - fraction, 1);
            var bounds = view.Phase == "area" ? areaRenderer.Bounds : mapRenderer.Bounds;
            var rotation = Quaternion.Euler(pitch, yaw, 0); var distance = bounds.size.magnitude + zoom + 40;
            mapCamera.transform.SetPositionAndRotation(focus - rotation * Vector3.forward * distance, rotation);
            mapCamera.orthographicSize = zoom; mapCamera.farClipPlane = distance * 2 + 100;
            mapRenderer.SetVisible(view.Phase != "area" && view.Phase != "battle");
            if (view.Phase == "area") areaRenderer.Draw(mapCamera);
            else if (view.Phase != "battle") mapRenderer.Draw(mapCamera, true, true, true, true);
        }
        private void EnsureStyles()
        {
            if (textStyle != null) return;
            textStyle = new GUIStyle(GUI.skin.label) { font = font, fontSize = 15, wordWrap = true };
            textStyle.normal.textColor = new Color(.88f, .91f, .9f);
            titleStyle = new GUIStyle(textStyle) { fontSize = 25, fontStyle = FontStyle.Bold };
            subtitleStyle = new GUIStyle(textStyle) { fontSize = 18, fontStyle = FontStyle.Bold };
            smallStyle = new GUIStyle(textStyle) { fontSize = 12 };
            smallStyle.normal.textColor = new Color(.63f, .72f, .74f);
            buttonStyle = new GUIStyle(GUI.skin.button) { font = font, fontSize = 15, wordWrap = true, padding = new RectOffset(12, 12, 9, 9) };
            tokenStyle = new GUIStyle(textStyle) { alignment = TextAnchor.MiddleCenter, fontStyle = FontStyle.Bold, fontSize = 14 };
            healthStyle = new GUIStyle(smallStyle) { alignment = TextAnchor.MiddleCenter };
            toggleStyle = new GUIStyle(GUI.skin.toggle) { font = font, fontSize = 14 };
        }
        private static void Fill(Rect rect, Color color, Texture texture = null)
        {
            var saved = GUI.color; GUI.color = color;
            GUI.DrawTexture(rect, texture == null ? Texture2D.whiteTexture : texture); GUI.color = saved;
        }
        private bool Button(string label, bool available = true)
        {
            var saved = GUI.enabled; GUI.enabled = saved && available;
            var clicked = GUILayout.Button(label, buttonStyle); GUI.enabled = saved; return clicked;
        }
        private void OnGUI()
        {
            EnsureStyles();
            if (view != null && thirdPerson) { DrawTownWalk(); return; }
            Fill(new Rect(0, 0, PanelWidth, Screen.height), Panel);
            if (view == null) { GUI.Label(new Rect(22, 22, Screen.width - 44, 200), fatalError ?? "正在准备远征…", textStyle); return; }
            DrawSidebar();
            if (view.Phase == "battle") DrawBattle();
            else if (view.Phase == "area") DrawArea();
            else if (view.Phase == "map") DrawSites();
            else DrawEvent();
            if (!string.IsNullOrEmpty(LastError))
            {
                var rect = new Rect(PanelWidth + 20, Screen.height - 65, Screen.width - PanelWidth - 40, 50);
                Fill(rect, new Color(.30f, .12f, .1f, .97f)); GUI.Label(new Rect(rect.x + 12, rect.y + 8, rect.width - 24, 38), LastError, textStyle);
            }
        }
        private void DrawSidebar()
        {
            GUILayout.BeginArea(new Rect(20, 20, PanelWidth - 40, Screen.height - 40));
            GUILayout.Label("边境远征", titleStyle);
            GUILayout.Label("探索 · 抉择 · 六边形战斗", smallStyle);
            GUILayout.Space(14); GUILayout.Label("队伍资金  /  " + view.Coins + " 金币", subtitleStyle);
            GUILayout.Space(10); sidebarScroll = GUILayout.BeginScrollView(sidebarScroll);
            if (view.Phase == "battle") DrawActions();
            else if (view.Phase == "area") DrawAreaActions();
            else if (view.Phase == "map")
            {
                GUILayout.Label("选择目的地", subtitleStyle);
                GUILayout.Label("进入地牢带队探索，进入城镇第三人称逛街。营地与野外事件保留原演示。", smallStyle);
                foreach (var site in view.Sites)
                {
                    if (Button((site.Visited ? "✓  " : "◇  ") + site.Id + "  " + site.Name, site.Available)) { SendCommand("visit", site.Id); break; }
                    if (!site.Available && !string.IsNullOrEmpty(site.Reason)) GUILayout.Label(site.Reason, smallStyle);
                }
                GUILayout.Space(10);
                if (Button("全图视角  [F]")) FitMap();
                GUILayout.Label("滚轮缩放 · 中键平移 · 右键旋转", smallStyle);
            }
            GUILayout.Space(16); GUILayout.Label("同行者", subtitleStyle);
            foreach (var actor in view.Party)
            {
                GUILayout.Space(9); GUILayout.Label(actor.Name, textStyle);
                GUILayout.Label((actor.HP == 0 ? "倒地  ·  " : "生命  ") + actor.HP + " / " + actor.MaxHP, smallStyle);
                if (!string.IsNullOrEmpty(actor.Traits)) GUILayout.Label(actor.Traits, smallStyle);
            }
            if (view.Phase == "map") { GUILayout.Space(18); if (Button("开始新远征")) StartExpedition(); }
            GUILayout.EndScrollView(); GUILayout.EndArea();
        }
        private void DrawActions()
        {
            var actor = view.Active; var player = actor.Team == 1;
            GUILayout.Label(actor.Name, subtitleStyle);
            GUILayout.Label("行动点 " + actor.AP + "   防御 " + actor.Guard, textStyle);
            GUILayout.Label((actor.Moved ? "移动已使用" : "可移动一次") + "  ·  " + (actor.MainUsed ? "主要行动已使用" : "可主要行动一次"), smallStyle);
            GUILayout.Space(10);
            if (Button((moveSelected ? "● " : "") + "移动", player && view.Reachable.Length > 0)) { moveSelected = true; selectedSkill = 0; }
            foreach (var skill in view.Skills)
            {
                if (Button((selectedSkill == skill.Id ? "● " : "") + skill.Name + "   " + skill.Cost + " AP", player && skill.Targets.Length > 0))
                { moveSelected = false; selectedSkill = skill.Id; }
                if (selectedSkill == skill.Id) GUILayout.Label(skill.Description, smallStyle);
            }
            if (Button("结束回合", player)) SendCommand("end_turn");
            GUILayout.Space(8);
            autoAI = GUILayout.Toggle(autoAI, " 自动推进敌方行动", toggleStyle);
            if (!autoAI && Button("推进敌方回合", !player)) SendCommand("ai");
            GUILayout.Space(10);
            GUILayout.Label(player ? (moveSelected ? "点击绿色地格移动。" : "点击高亮角色施放技能。") : "敌方正在行动…", smallStyle);
        }
        private void DrawAreaActions()
        {
            var area = view.Area;
            GUILayout.Label(area.Name, subtitleStyle);
            GUILayout.Label(area.Theme + " · 来自 Region #" + area.SourceRegionId, smallStyle);
            if (areaLayout.IsTown)
            {
                GUILayout.Label("预设街区组合 · " + areaLayout.Facilities.Length + " 处设施 · " + area.Npcs.Length + " 位居民", smallStyle);
                if (Button("第三人称逛街  [V]")) ToggleTownCamera();
                GUILayout.Label("左键带队移动，靠近设施门口或居民后按 E。", textStyle);
                foreach (var facility in areaLayout.Facilities)
                    if (Button("前往 · " + facility.Name))
                    { var cell = areaLayout.Cells[facility.EntryIndex]; SendCommand("area_move", cell.Q, cell.R); break; }
                DrawTownInteraction();
                if (Button("返回大地图")) SendCommand("area_leave");
                return;
            }
            GUILayout.Label(areaLayout.Cells.Length + " 格 / " + area.RoomCount + " 个房间 / " + area.PropCount + " 件陈设\n" + area.WalkableCount + " 格可走地面 / 已发现 " + area.Known.Length + " 格", smallStyle);
            var current = Array.Find(areaLayout.Rooms, room => room.Id == areaLayout.Cells[area.CellIndex].RoomId);
            GUILayout.Label(current == null ? "宽通道 · 净宽至少 " + areaLayout.CorridorWidth + " 格" : current.Name + " · 第 " + current.Tier + " 级生成", smallStyle);
            GUILayout.Label("一级连接石窟 / 二级精细随机 / 三级预设大房间", smallStyle);
            GUILayout.Space(8);
            GUILayout.Label("点击已发现地面，整队移动。每人各占一格，受阻自动跟随；空格停止。", textStyle);
            if (Button("定位小队并跟随")) { followParty = true; focus = displayedParty; zoom = 13 * areaLayout.Radius; }
            if (Button("停止移动  [Space]", area.Route.Length > 0)) SendCommand("area_stop");
            if (Button("完整布局视角  [F]")) FitMap();
            var nextReveal = GUILayout.Toggle(revealArea, " 显示完整结构（仅调试查看）", toggleStyle);
            if (nextReveal != revealArea) { revealArea = nextReveal; areaRenderer.UpdateVisibility(area, revealArea); }
            GUILayout.Label("调试显示不解锁未知路径。绿色为入口，金色为深处地标；本版未布置敌人。", smallStyle);
            GUILayout.Space(8);
            if (Button("返回大地图（测试入口）")) SendCommand("area_leave");
            GUILayout.Label("再次进入保留布局、位置和探索记录；开始新远征才重置。", smallStyle);
        }
        private void DrawArea()
        {
            GUI.Label(new Rect(PanelWidth + 24, 20, Screen.width - PanelWidth - 48, 35), view.Area.Theme + (areaLayout.IsTown ? "  /  城镇街区" : "  /  地牢探索"), subtitleStyle);
            if (revealArea)
                foreach (var room in areaLayout.Rooms)
                {
                    var point = mapCamera.WorldToScreenPoint(areaLayout.Cells[room.CenterIndex].Position);
                    if (point.z > 0 && point.x > PanelWidth + 70)
                        GUI.Label(new Rect(point.x - 65, Screen.height - point.y - 36, 150, 30), "L" + room.Tier + " " + room.Name, smallStyle);
                }
            foreach (var index in view.Area.Route)
            {
                var point = mapCamera.WorldToScreenPoint(areaLayout.Cells[index].Position + Vector3.up * .1f);
                if (point.z > 0 && point.x > PanelWidth) Fill(new Rect(point.x - 2, Screen.height - point.y - 2, 4, 4), Teal, circleTexture);
            }
            foreach (var member in view.Area.Members)
            {
                var marker = mapCamera.WorldToScreenPoint(squadRenderer.Position(member.ActorId) + Vector3.up * 2.55f);
                if (marker.z <= 0 || marker.x <= PanelWidth) continue;
                var actor = Array.Find(view.Party, item => item.Id == member.ActorId);
                GUI.Label(new Rect(marker.x - 65, Screen.height - marker.y - 14, 130, 25), actor.Name, healthStyle);
            }
        }
        private void ToggleTownCamera()
        {
            SendCommand("area_stop"); townCamera.ResetSteering(); wasWalking = false; thirdPerson = !thirdPerson;
            followParty = true; focus = displayedParty;
            if (!thirdPerson) { zoom = 13 * areaLayout.Radius; pitch = 65; }
        }
        // 提示使用显示快照，命令仍在 Lua 重新检查距离，不能通过 UI 绕过靠近要求。
        private void NearestInteraction(out int kind, out int id, out string label)
        {
            kind = 0; id = 0; label = ""; var best = int.MaxValue;
            var origin = areaLayout.Cells[view.Area.CellIndex];
            foreach (var facility in areaLayout.Facilities)
            {
                var target = areaLayout.Cells[facility.EntryIndex]; var dq = target.Q - origin.Q; var dr = target.R - origin.R;
                var range = (Mathf.Abs(dq) + Mathf.Abs(dr) + Mathf.Abs(dq + dr)) / 2;
                if (range <= facility.InteractionRadius && range < best) { best = range; kind = 1; id = facility.Id; label = facility.Name; }
            }
            foreach (var npc in view.Area.Npcs)
            {
                var target = areaLayout.Cells[npc.CellIndex]; var dq = target.Q - origin.Q; var dr = target.R - origin.R;
                var range = (Mathf.Abs(dq) + Mathf.Abs(dr) + Mathf.Abs(dq + dr)) / 2;
                if (range <= 1 && range < best)
                { best = range; kind = 2; id = npc.Id; label = Array.Find(areaLayout.Npcs, value => value.Id == npc.Id).Name; }
            }
        }
        private void DrawTownInteraction()
        {
            if (view.Area.InteractionKind == 0)
            {
                NearestInteraction(out var kind, out var id, out var label);
                if (kind != 0 && Button("[E]  查看 · " + label)) SendCommand("area_interact", kind, id);
                return;
            }
            string name, description;
            if (view.Area.InteractionKind == 1)
            {
                var site = Array.Find(areaLayout.Facilities, value => value.Id == view.Area.InteractionId);
                name = site.Name; description = site.Description;
            }
            else
            {
                var npc = Array.Find(areaLayout.Npcs, value => value.Id == view.Area.InteractionId);
                name = npc.Name; description = npc.Description;
            }
            GUILayout.Label(name, subtitleStyle); GUILayout.Label(description, textStyle);
            if (Button("继续逛街  [Esc]")) SendCommand("area_close");
        }
        private void DrawTownWalk()
        {
            var header = new Rect(18, 18, Mathf.Min(470, Screen.width - 36), 112);
            Fill(header, new Color(.075f, .105f, .12f, .90f));
            GUI.Label(new Rect(32, 29, header.width - 28, 32), view.Area.Theme + " · " + view.Area.Name, subtitleStyle);
            GUI.Label(new Rect(32, 65, header.width - 28, 52), "WASD 带队 · 右键拖动镜头 · 滚轮远近\nE 交互 · V 俯视/第三人称 · 空格停止", smallStyle);
            var leave = GUI.Button(new Rect(Screen.width - 154, 20, 135, 36), "返回大地图", buttonStyle);
            if (leave) { SendCommand("area_leave"); return; }
            // 只标注附近设施，避免远处名字遮挡街景。距离同时考虑相机前后。
            var leader = squadRenderer.Position(view.Area.Members[0].ActorId);
            foreach (var facility in areaLayout.Facilities)
            {
                var position = areaLayout.Cells[facility.EntryIndex].Position;
                if ((position - leader).sqrMagnitude > 28 * 28) continue;
                var point = mapCamera.WorldToScreenPoint(position + Vector3.up * 2.3f);
                if (point.z > .2f && point.x > 65 && point.x < Screen.width - 65)
                    GUI.Label(new Rect(point.x - 65, Screen.height - point.y - 24, 130, 25), facility.Name, healthStyle);
            }
            NearestInteraction(out var kind, out _, out _);
            if (kind != 0 || view.Area.InteractionKind != 0)
            {
                var width = Mathf.Min(520, Screen.width - 36); var height = view.Area.InteractionKind == 0 ? 65 : 170;
                var card = new Rect((Screen.width - width) / 2, Screen.height - height - 22, width, height);
                Fill(card, Panel); GUILayout.BeginArea(new Rect(card.x + 14, card.y + 12, card.width - 28, card.height - 20));
                DrawTownInteraction(); GUILayout.EndArea();
            }
            if (!string.IsNullOrEmpty(LastError))
                GUI.Label(new Rect(24, 140, Screen.width - 48, 52), LastError, textStyle);
        }
        private void DrawSites()
        {
            foreach (var site in view.Sites)
            {
                var point = mapCamera.WorldToScreenPoint(site.Position + Vector3.up * .6f);
                if (point.z < 0 || point.x < PanelWidth + 15 || point.x > Screen.width - 15) continue;
                var rect = new Rect(point.x - 17, Screen.height - point.y - 17, 34, 34);
                Fill(new Rect(rect.x - 3, rect.y - 3, 40, 40), Background, circleTexture);
                Fill(rect, site.Available ? Gold : new Color(.4f, .46f, .46f), circleTexture);
                GUI.Label(rect, site.Id.ToString(), tokenStyle);
                if (site.Available && GUI.Button(rect, GUIContent.none, GUIStyle.none)) { SendCommand("visit", site.Id); break; }
            }
            GUI.Label(new Rect(PanelWidth + 24, 22, Screen.width - PanelWidth - 48, 40), "大地图  /  选择一处地点开始探索", subtitleStyle);
        }
        private void DrawEvent()
        {
            var area = new Rect(PanelWidth, 0, Screen.width - PanelWidth, Screen.height);
            Fill(area, new Color(.02f, .035f, .045f, .76f));
            var width = Mathf.Min(590, area.width - 60);
            var card = new Rect(area.center.x - width / 2, Mathf.Max(30, Screen.height * .16f), width, Mathf.Min(470, Screen.height - 90));
            Fill(card, Panel); Fill(new Rect(card.x, card.y, card.width, 4), Gold);
            GUILayout.BeginArea(new Rect(card.x + 28, card.y + 27, card.width - 56, card.height - 54));
            GUILayout.Label(view.Phase == "event" ? "途中见闻" : "远征记录", smallStyle);
            GUILayout.Space(10); GUILayout.Label(view.Phase == "event" ? view.EventTitle : "本次行动结束", titleStyle);
            GUILayout.Space(18); GUILayout.Label(view.Phase == "event" ? view.EventText : view.Result, textStyle);
            GUILayout.Space(22);
            if (view.Phase == "event")
            {
                foreach (var choice in view.Choices)
                {
                    if (Button(choice.Label, choice.Available)) { SendCommand("choose", choice.Id); break; }
                    if (!choice.Available) GUILayout.Label(choice.Reason, smallStyle);
                    GUILayout.Space(5);
                }
            }
            else if (Button("返回大地图")) SendCommand("return");
            GUILayout.EndArea();
        }
        private Vector2 CellCenter(int q, int r, Vector2 center, float size) => center + new Vector2(1.7320508f * (q + r * .5f), 1.5f * r) * size;
        private void DrawBattle()
        {
            var area = new Rect(PanelWidth, 0, Screen.width - PanelWidth, Screen.height); Fill(area, Background);
            GUI.Label(new Rect(area.x + 28, 20, area.width - 56, 40), view.Encounter + "   /   第 " + view.Round + " 轮", titleStyle);
            GUI.Label(new Rect(area.x + 28, 61, area.width - 56, 26), "青色为队友 · 红色为敌人 · 深色地格不可通行", smallStyle);
            var size = Mathf.Max(8, Mathf.Min((area.width - 70) / ((view.Radius * 2 + 1) * 1.7320508f), (area.height - 210) / (view.Radius * 3 + 2)));
            var center = new Vector2(area.center.x, 95 + (area.height - 210) / 2);
            var chosen = Array.Find(view.Skills, skill => skill.Id == selectedSkill);
            AdventureViewData.Cell clicked = null;
            foreach (var cell in view.Cells)
            {
                var position = CellCenter(cell.Q, cell.R, center, size);
                var rect = new Rect(position.x - size * .8660254f, position.y - size, size * 1.7320508f, size * 2);
                var reachable = moveSelected && view.Active.Team == 1 && Array.Exists(view.Reachable, next => next.Q == cell.Q && next.R == cell.R);
                var color = cell.Blocked ? new Color(.12f, .15f, .17f) : reachable ? new Color(.19f, .39f, .34f) : new Color(.18f, .23f, .25f);
                Fill(rect, new Color(.08f, .12f, .14f), hexTexture);
                var inner = new Rect(rect.x + 2, rect.y + 2, rect.width - 4, rect.height - 4); Fill(inner, color, hexTexture);
                if (cell.Blocked) GUI.Label(rect, "◆", tokenStyle);
                var e = Event.current;
                var dx = Mathf.Abs(e.mousePosition.x - position.x) / (size * .8660254f);
                var dy = Mathf.Abs(e.mousePosition.y - position.y) / size;
                if (e.type == EventType.MouseDown && e.button == 0 && dx <= 1 && dy <= 1 - dx * .5f) clicked = cell;
            }
            // 尸体先画，存活角色在其上方；尸体不阻挡路径。
            foreach (var actor in view.Units) if (actor.HP == 0) DrawActor(actor, center, size, chosen);
            foreach (var actor in view.Units) if (actor.HP > 0) DrawActor(actor, center, size, chosen);
            var logRect = new Rect(area.x + 28, Screen.height - 110, area.width - 56, 98);
            for (var i = Mathf.Max(0, view.Logs.Length - 4); i < view.Logs.Length; i++)
                GUI.Label(new Rect(logRect.x, logRect.y + (i - Mathf.Max(0, view.Logs.Length - 4)) * 23, logRect.width, 23), view.Logs[i], smallStyle);
            if (clicked != null && view.Active.Team == 1)
            {
                Event.current.Use();
                if (moveSelected) SendCommand("move", clicked.Q, clicked.R);
                else
                {
                    var target = Array.Find(view.Units, actor => actor.HP > 0 && actor.Q == clicked.Q && actor.R == clicked.R);
                    if (target != null && selectedSkill > 0) SendCommand("skill", selectedSkill, target.Id);
                }
            }
        }
        private void DrawActor(AdventureViewData.Actor actor, Vector2 center, float size, AdventureViewData.Skill chosen)
        {
            var position = CellCenter(actor.Q, actor.R, center, size);
            var radius = size * .61f;
            var rect = new Rect(position.x - radius, position.y - radius, radius * 2, radius * 2);
            var target = chosen != null && Array.IndexOf(chosen.Targets, actor.Id) >= 0;
            if (actor.Id == view.ActiveId || target) Fill(new Rect(rect.x - 3, rect.y - 3, rect.width + 6, rect.height + 6), target ? Gold : Color.white, circleTexture);
            Fill(rect, actor.HP == 0 ? new Color(.23f, .26f, .27f) : actor.Team == 1 ? Teal * .7f : Enemy * .8f, circleTexture);
            var separator = actor.Name.IndexOf(" · ", StringComparison.Ordinal);
            var label = actor.HP == 0 ? "×" : separator > 0 ? actor.Name.Substring(0, separator) : actor.Name.Substring(0, Mathf.Min(3, actor.Name.Length));
            GUI.Label(rect, label, tokenStyle);
            if (actor.HP == 0) return;
            var bar = new Rect(position.x - size * .65f, position.y + size * .64f, size * 1.3f, 5);
            Fill(bar, new Color(.06f, .08f, .09f)); Fill(new Rect(bar.x, bar.y, bar.width * actor.HP / actor.MaxHP, bar.height), actor.Team == 1 ? Teal : Enemy);
            GUI.Label(new Rect(position.x - size, position.y + size * .72f, size * 2, 18), actor.HP + "/" + actor.MaxHP, healthStyle);
        }
        private void OnDestroy()
        {
            townNpcs?.Dispose(); townNpcs = null;
            squadRenderer?.Dispose(); squadRenderer = null;
            areaRenderer?.Dispose(); areaRenderer = null;
            mapRenderer?.Dispose(); mapRenderer = null;
            if (font != null) Destroy(font);
            if (hexTexture != null) Destroy(hexTexture);
            if (circleTexture != null) Destroy(circleTexture);
        }
    }
}
