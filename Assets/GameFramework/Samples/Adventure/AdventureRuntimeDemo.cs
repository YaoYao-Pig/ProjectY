using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
using XLua;
using ProjectY.UI;

namespace ProjectY.Samples
{
    /// <summary>演示输入与显示。所有玩法命令交给现有 Lua 运行时，不持有规则或权威状态。</summary>
    [LuaCallCSharp]
    public sealed class AdventureRuntimeDemo : MonoBehaviour
    {
        [SerializeField] private GameBootstrap bootstrap;
        [SerializeField] private Camera mapCamera;
        [SerializeField] private Shader previewShader;
        [SerializeField] private Light environmentSun;
        [SerializeField] private ExplorationGridRenderer.Settings explorationGrid = new ExplorationGridRenderer.Settings();
        private MapEnvironmentController environment;
        private bool showEnvironment;
        [SerializeField] private MapRuntimeDemo.AssetBinding[] assetBindings;
        [SerializeField] private PawnView pawnPrefab;
        [SerializeField] private EquipmentAssetCatalog equipmentCatalog;
        [SerializeField] private MapRuntimeDemo.AssetBinding[] pawnBindings;
        private const string Bridge = "Game.Adventure.DemoBridge";
        private readonly Dictionary<int, MapRuntimeDemo.AssetBinding> assets = new Dictionary<int, MapRuntimeDemo.AssetBinding>();
        private MapPreviewRenderer mapRenderer;
        private MapAreaRenderer areaRenderer;
        private SquadPawnRenderer squadRenderer;
        private ExplorationGridRenderer explorationRenderer;
        private Func<int, Vector3> squadPosition;
        private AreaCombatRenderer combatRenderer;
        private AreaLootRenderer lootRenderer;
        private AreaObstacleRenderer obstacleRenderer;
        private ConstructionRenderer constructionRenderer;
        private bool equipmentOpen;
        private bool growthOpen, storyOpen, gmOpen;
        public Font MainHudFont => mainHud.Font;
        public void SetGMOpen(bool value) {gmOpen=value;}
        public void OpenGM()
        {
            if(equipmentOpen || growthOpen || storyOpen || view==null || pendingExitView!=null)return;
            bootstrap.CallModule("UI.AdventureUIBridge","gm",this);
        }
        private MainHudView mainHud;
        public Camera WorldCamera => mapCamera;
        private BattleFeedbackSystem Feedback => mainHud != null ? mainHud.BattleFeedback : null;
        public void SetMainHud(MainHudView value) {if(mainHud!=value)Feedback?.Clear();mainHud=value;}
        public void ToggleEnvironment() {showEnvironment=!showEnvironment;}
        public int[] RenderedHealthActorIds()
        {
            var ids=new List<int>();
            if(view==null)return ids.ToArray();
            if(HasArea)
            {
                foreach(var member in view.Area.Members)ids.Add(member.ActorId);
                foreach(var actor in view.Area.Enemies)if(actor.HP>0)ids.Add(actor.Id);
            }
            else if(view.Phase=="battle")foreach(var actor in view.Units)if(actor.HP>0)ids.Add(actor.Id);
            return ids.ToArray();
        }
        public Transform HealthTarget(int actorId)
        {
            if(!HasArea) throw new InvalidOperationException("No 3D scene for health follower.");
            return Array.Exists(view.Party,actor=>actor.Id==actorId)?squadRenderer.HealthTarget(actorId):combatRenderer.HealthTarget(actorId);
        }
        public Vector2 HealthScreenPosition(int actorId)
        {
            if(view==null||view.Phase!="battle"||HasArea) throw new InvalidOperationException("Screen target is only used by the legacy 2D board.");
            var actor=Array.Find(view.Units,value=>value.Id==actorId);
            if(actor==null) throw new ArgumentException("Missing board actor: "+actorId);
            var size=BoardSize();var center=BoardCenter();var point=CellCenter(actor.Q,actor.R,center,size);
            return new Vector2(point.x,Screen.height-point.y+size*.8f+22);
        }
        public void SetGrowthOpen(bool value) { growthOpen=value; }
        public void SetStoryOpen(bool value) { storyOpen=value; }
        public void OpenGrowth()
        {
            if(equipmentOpen || (view?.Phase!="map" && view?.Phase!="area")) return;
            bootstrap.CallModule("UI.AdventureUIBridge","growth",this);
        }
        public void SetEquipmentOpen(bool value) { equipmentOpen=value; }
        public void OpenEquipment()
        {
            if(growthOpen || storyOpen || (view?.Phase!="map"&&view?.Phase!="area")) return;
            bootstrap.CallModule("UI.EquipmentUIBridge","open",this);
        }
        private TownNpcRenderer townNpcs;
        private TownWalkCamera townCamera;
        private DialogueCamera dialogueCamera;
        private ProjectY.Data.NarrativeData narrativeData;
        private int dialogueActorId, dialogueNpcId;
        private string dialogueShot;
        private float dialoguePanelFraction;
        public void SetDialogueCamera(int actorId,int npcId,string shot,float distance,float height,float cameraPitch,float fov,float blend,float closeup,float panelFraction)
        {
            if(!HasArea || townNpcs==null)throw new InvalidOperationException("Dialogue requires a rendered town and NPC.");
            if(dialogueCamera==null || !dialogueCamera.Active)dialogueCamera=new DialogueCamera(mapCamera,transform,distance,height,cameraPitch,fov,blend,closeup,areaRenderer.CameraObstacles,areaRenderer.TerrainDistance);
            dialogueActorId=actorId;dialogueNpcId=npcId;dialogueShot=shot;dialoguePanelFraction=panelFraction;
        }
        public void EndDialogueCamera(){dialogueCamera?.Return();}
        private bool thirdPerson, wasWalking;
        private ProjectY.Data.MapAreaStateData areaState;
        private readonly Dictionary<int, MapRuntimeDemo.AssetBinding> pawnAssets = new Dictionary<int, MapRuntimeDemo.AssetBinding>();
        private MapAreaViewData areaLayout;
        private bool revealArea, followParty = true;
        private float nextAreaPoll;
        private Vector3 worldFocus, displayedParty;
        private float worldZoom, worldYaw, worldPitch;
        private AdventureViewData view;
        private AdventureViewData pendingExitView;
        private bool AnimationBusy => HasArea && (squadRenderer.Busy || combatRenderer.Busy);
        private Vector3 focus;
        private float zoom, yaw = -25, pitch = 52, nextAI;
        private int selectedSkill, lastActor;
        private int selectedCharacter, selectedCharacterSkill;
        public int SelectedCharacterId => selectedCharacter;
        public int SelectedCharacterSkill => selectedCharacterSkill;
        public void SelectCharacter(int id)
        {
            if(view==null || (view.Phase!="map" && view.Phase!="area") || !Array.Exists(view.Party,actor=>actor.Id==id))return;
            selectedCharacter=id;selectedCharacterSkill=0;BattleHUDRevision++;
        }
        public void SelectCharacterSkill(int actorId,int skillId,string target)
        {
            if(view==null || view.Phase!="area")return;
            SelectCharacter(actorId);
            if(target=="self") {SendCommand("character_skill",actorId,skillId,actorId);return;}
            if(target!="unit" && target!="cell" && target!="container")throw new ArgumentException("Unknown character skill target.",nameof(target));
            selectedCharacterSkill=skillId;characterSkillTarget=target;view.Error="";BattleHUDRevision++;
        }
        private string characterSkillTarget;
        public void CancelCharacterSkill() {selectedCharacterSkill=0;characterSkillTarget=null;BattleHUDRevision++;}
        private int selectedAreaCell=-1;
        private bool moveSelected = true, autoAI = true;
        private string fatalError;
        private Font font;
        private Texture2D hexTexture, circleTexture;
        private GUIStyle textStyle, titleStyle, subtitleStyle, buttonStyle, tokenStyle, smallStyle, toggleStyle;
        private static readonly Color Background = new Color(.045f, .07f, .085f);
        private static readonly Color Panel = new Color(.075f, .105f, .12f);
        private static readonly Color Teal = new Color(.31f, .83f, .71f);
        private static readonly Color Gold = new Color(.97f, .76f, .43f);
        private static readonly Color Enemy = new Color(.86f, .40f, .35f);
        public string Phase => view?.Phase;
        public string LastError => fatalError ?? view?.Error;
        public int SelectedBattleSkill => selectedSkill;
        public bool IsBattleMoveSelected => moveSelected;
        public bool BattleAutoAI => autoAI;
        public int BattleHUDRevision { get; private set; }
        private bool HasArea => view?.Area != null;

        public void SelectBattleSkill(int id)
        {
            if (view?.Phase != "battle" || view.Active.Team != 1) return;
            var skill = Array.Find(view.Skills, row => row.Id == id);
            if (skill == null || (skill.Targets.Length == 0 && skill.TargetCells.Length == 0)) return;
            selectedSkill = id; moveSelected = false; view.Error = ""; BattleHUDRevision++;
        }
        public void SelectBattleMove()
        {
            if (view?.Phase != "battle" || view.Active.Team != 1 || view.Reachable.Length == 0) return;
            selectedSkill = 0; moveSelected = true; view.Error = ""; BattleHUDRevision++;
        }
        public void SetBattleAutoAI(bool value) { autoAI = value; BattleHUDRevision++; }
        public void FocusBattleActor(int id)
        {
            if (view?.Phase != "battle") return;
            var actor = Array.Find(view.Units, row => row.Id == id && row.HP > 0);
            if (actor != null && HasArea) { focus = areaLayout.Cells[actor.CellIndex].Position; followParty = false; }
        }

        private void Start()
        {
            if (bootstrap == null || mapCamera == null || previewShader == null || environmentSun == null || assetBindings == null || pawnPrefab == null || pawnBindings == null)
                throw new InvalidOperationException("远征演示未绑定宿主、相机或地图资源。");
            foreach (var binding in assetBindings) assets.Add(binding.id, binding);
            foreach (var binding in pawnBindings) pawnAssets.Add(binding.id, binding);
            font = Font.CreateDynamicFontFromOSFont(new[] { "Microsoft YaHei", "Noto Sans CJK SC", "Arial" }, 16);
            hexTexture = ShapeTexture(false); circleTexture = ShapeTexture(true);
            mapRenderer = new MapPreviewRenderer(previewShader, transform);
            StartExpedition();
            if (fatalError == null)
                using (var root = (LuaTable)bootstrap.CallModule(Bridge, "presentation")[0])
                    environment = new MapEnvironmentController(MapEnvironmentData.Read(root), environmentSun, mapCamera, transform);
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
        { BuildExpedition("start"); }
        private void BuildExpedition(string command)
        {
            Feedback?.Clear();
            try
            {
                var values = bootstrap.CallModule(Bridge, command);
                narrativeData=(ProjectY.Data.NarrativeData)bootstrap.CallModule("Game.Narrative.Bridge","data")[0];
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
        public void SendCommand(string command, int a = 0, int b = 0, int c = 0)
        {
            if (fatalError != null) return;
            if(command=="hud_missions"){bootstrap.CallModule("UI.AdventureUIBridge","missions",this);return;}
            if(command=="hud_skill_atlas"){bootstrap.CallModule("UI.AdventureUIBridge","skill_atlas",this);return;}
            if (command == "load_characters" || command == "start_story")
            {
                if (view.Phase != "map" && view.Phase != "area") return;
                BuildExpedition(command); return;
            }
            // 对话会暂停世界，不能等待已暂停的角色动画才能选择或关闭。
            var dialogueCommand=command=="dialogue_choose" || command=="dialogue_close" || command=="shop_open" || command=="shop_buy" || command=="shop_close";
            if (pendingExitView != null || (!dialogueCommand && !command.StartsWith("gm_",StringComparison.Ordinal) && HasArea && command != "snapshot" && command != "area_stop" &&
                (view.Phase == "battle" ? AnimationBusy : squadRenderer.ActionBusy || combatRenderer.ActionBusy))) return;
            if(command=="hud_follow")
            {
                if(!HasArea) return;
                followParty=true;focus=displayedParty;zoom=10*areaLayout.Radius;pitch=50;return;
            }
            try
            {
                var values = bootstrap.CallModule(Bridge, command, a, b, c);
                using (var root = (LuaTable)values[0])
                {
                    var next=AdventureViewData.Read(root);
                    if(command=="snapshot")next.RetainPollingFeedback(view);
                    // GM 传送可能跨城镇或跨越很长距离；重建显示宿主，不把瞬移解释为寻路动画。
                    if(root.Get<bool>("gmTeleport") && HasArea)ClearAreaView();
                    SetView(next);
                    if(root.Get<bool>("gmTeleport") && string.IsNullOrEmpty(next.Error))
                    {
                        var npc=Array.Find(areaLayout.Npcs,row=>row.NarrativeId==a);
                        if(npc==null)throw new InvalidOperationException("GM target NPC is absent from the displayed layout.");
                        thirdPerson=false;followParty=false;
                        focus=(townNpcs.Position(npc.Id)+squadRenderer.Position(view.Area.Members[0].ActorId))*.5f;
                        zoom=Mathf.Max(4,areaLayout.Radius*3);pitch=50;yaw=-25;
                    }
                }
                if(command=="character_skill")CancelCharacterSkill();
                if(view.Phase=="area" && string.IsNullOrEmpty(view.Error))
                {
                    if(!storyOpen && (command=="area_loot" || command=="area_interact")) squadRenderer.Interact(view.Area.Members[0].ActorId,command=="area_interact");
                    if(command=="area_move_cell") selectedAreaCell=a-1;
                    else if(command=="area_stop" || command=="area_walk") selectedAreaCell=-1;
                }
            }
            catch (Exception exception) { Report(exception); }
        }
        private void SetView(AdventureViewData value, bool exitPresentationComplete = false)
        {
            if(value.Phase!=view?.Phase || !Array.Exists(value.Party,actor=>actor.Id==selectedCharacter))
            {selectedCharacterSkill=0;characterSkillTarget=null;}
            if(!Array.Exists(value.Party,actor=>actor.Id==selectedCharacter))selectedCharacter=0;
            if (!exitPresentationComplete && HasArea && view.Phase == "battle" && value.Area == null)
            {
                Feedback?.Commit(0);
                squadRenderer.CaptureExit(value.Party);
                if (AnimationBusy) {pendingExitView=value;return;}
            }
            var enteringBattle = value.Area != null && value.Phase == "battle" && view?.Phase != "battle";
            var resumingExploration = value.Area != null && value.Phase == "area" && view?.Phase == "battle";
            if (value.Area != null && !HasArea)
            {
                selectedAreaCell=-1;
                worldFocus = focus; worldZoom = zoom; worldYaw = yaw; worldPitch = pitch;
                var values = bootstrap.CallModule(Bridge, "area_layout");
                using (var root = (LuaTable)values[0]) areaLayout = MapAreaViewData.Read(root);
                areaState = (ProjectY.Data.MapAreaStateData)bootstrap.CallModule(Bridge, "area_state")[0];
                environment?.SetArea(areaLayout);
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
                squadPosition = squadRenderer.Position;
                explorationRenderer = new ExplorationGridRenderer(areaLayout, explorationGrid, areaRenderer.IsCellShown);
                combatRenderer = new AreaCombatRenderer(transform, pawnPrefab, previewShader, ResolvePawnPart);
                lootRenderer = new AreaLootRenderer(transform,equipmentCatalog,areaRenderer.IsCellShown);
                obstacleRenderer = new AreaObstacleRenderer(transform,equipmentCatalog);
                constructionRenderer=new ConstructionRenderer(transform);
                if (areaLayout.IsTown)
                {
                    townNpcs = new TownNpcRenderer(transform, pawnPrefab, areaLayout, ResolvePawnPart);
                    townCamera = new TownWalkCamera(areaLayout, value.Area, areaRenderer.CameraObstacles, areaRenderer.TerrainDistance);
                    thirdPerson = true; wasWalking = false;
                }
                focus = displayedParty = areaLayout.Cells[value.Area.CellIndex].Position;
                zoom = 10 * areaLayout.Radius; pitch = 50; yaw = -35;
            }
            else if (value.Area == null && HasArea)
            {
                ClearAreaView();
            }
            view = value;
            if(view.Phase!="area") selectedAreaCell=-1;
            float impactDelay=0;
            if (HasArea)
            {
                areaLayout.ApplyConstruction(view.Area);
                areaRenderer.UpdateVisibility(view.Area, revealArea);
                squadRenderer.SetState(view.Area, view.Party, areaLayout, view.Phase == "battle");
                explorationRenderer.SetState(view.Area, view.Phase == "area");
                combatRenderer.SetState(view.Area, areaLayout);
                impactDelay=Mathf.Max(squadRenderer.ImpactDelay(),combatRenderer.ImpactDelay());
                squadRenderer.Capture(impactDelay);combatRenderer.Capture(impactDelay);
                townNpcs?.SetState(view.Area, areaLayout);
                lootRenderer.Apply(view.Area,areaLayout);
                obstacleRenderer.Apply(view.Area,areaLayout);
                constructionRenderer.Apply(view.Area,areaLayout);
            }
            Feedback?.Commit(impactDelay);
            if (enteringBattle) FocusBattle();
            if (resumingExploration) { followParty = true; focus = displayedParty = areaLayout.Cells[view.Area.CellIndex].Position; }
            if (view.ActiveId != lastActor)
            {
                lastActor = view.ActiveId; moveSelected = true; selectedSkill = 0;
                nextAI = Time.unscaledTime + .8f;
            }
            BattleHUDRevision++;
            bootstrap.CallModule("UI.AdventureUIBridge", "sync", this);
        }
        private void ClearAreaView()
        {
            Feedback?.Clear();
            areaState = null;
            dialogueCamera?.Dispose();dialogueCamera=null;
            squadRenderer.Dispose();squadRenderer=null;
            explorationRenderer.Dispose();explorationRenderer=null;squadPosition=null;
            combatRenderer.Dispose();combatRenderer=null;
            lootRenderer.Dispose();lootRenderer=null;
            obstacleRenderer.Dispose();obstacleRenderer=null;
            constructionRenderer.Dispose();constructionRenderer=null;
            townNpcs?.Dispose();townNpcs=null;townCamera=null;thirdPerson=false;wasWalking=false;
            environment?.SetArea(null);
            areaRenderer.Dispose();areaRenderer=null;areaLayout=null;
            focus=worldFocus;zoom=worldZoom;yaw=worldYaw;pitch=worldPitch;
            view.Area=null;
        }
        private void FocusBattle()
        {
            var bounds = new Bounds(areaLayout.Cells[view.Units[0].CellIndex].Position, Vector3.zero);
            foreach (var actor in view.Units) if (actor.HP > 0) bounds.Encapsulate(areaLayout.Cells[actor.CellIndex].Position);
            focus = bounds.center; followParty = false;
            zoom = Mathf.Max(10 * areaLayout.Radius, bounds.extents.magnitude + 4 * areaLayout.Radius);
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
            BattleHUDRevision++;
            Debug.LogException(exception, this);
        }
        public void FitMap()
        {
            if (HasArea && view.Phase == "battle") { FocusBattle(); return; }
            var bounds = HasArea ? areaRenderer.Bounds : mapRenderer.Bounds; focus = bounds.center;
            if (HasArea) followParty = false;
            var inverse = Quaternion.Inverse(Quaternion.Euler(pitch, yaw, 0)); var extent = Vector2.zero;
            for (var x = -1; x <= 1; x += 2) for (var y = -1; y <= 1; y += 2) for (var z = -1; z <= 1; z += 2)
            {
                var corner = inverse * Vector3.Scale(bounds.extents, new Vector3(x, y, z));
                extent.x = Mathf.Max(extent.x, Mathf.Abs(corner.x)); extent.y = Mathf.Max(extent.y, Mathf.Abs(corner.y));
            }
            zoom = Mathf.Max(8, Mathf.Max(extent.y, extent.x / Mathf.Max(.2f, (Screen.width - (mainHud!=null?mainHud.WorldLeftInset:0)) / Screen.height)) * 1.18f);
        }
        private void Update()
        {
            if(environment!=null && narrativeData!=null){environment.Running=false;environment.Hour=(float)(narrativeData.Minutes/60%24);}
            environment?.Tick(Time.unscaledDeltaTime, view?.Area);
            if (view == null || fatalError != null) return;
            if(Input.GetKeyDown(KeyCode.F8))OpenGM();
            if(gmOpen)return;
            if(Input.GetKeyDown(KeyCode.C)) OpenGrowth();
            if(growthOpen || storyOpen) return;
            if(dialogueCamera!=null && dialogueCamera.Active)return;
            if(Input.GetKeyDown(KeyCode.I))
            {
                if(equipmentOpen) bootstrap.CallModule("UI.EquipmentUIBridge","close");else OpenEquipment();
            }
            if(equipmentOpen) return;
            Feedback?.Tick(Time.deltaTime);
            if (HasArea)
            {
                // 城镇移动与居民占格变化当帧同步，避免在每个格子之间再等一次轮询。
                if (view.Phase == "area" && ((areaLayout.IsTown && areaState.Revision != view.Area.Revision) || Time.unscaledTime >= nextAreaPoll))
                { SendCommand("snapshot"); nextAreaPoll = Time.unscaledTime + .10f; }
                if (fatalError != null) return;
                displayedParty = Vector3.Lerp(displayedParty, areaLayout.Cells[view.Area.CellIndex].Position, 1 - Mathf.Exp(-Time.unscaledDeltaTime * 18));
                squadRenderer.Tick(Time.deltaTime);
                combatRenderer.Tick(Time.deltaTime);
                if (Input.GetKeyDown(KeyCode.Space) && (view.Phase == "battle" || pendingExitView != null))
                {squadRenderer.Skip();combatRenderer.Skip();Feedback?.Skip();}
                if (pendingExitView != null && !AnimationBusy)
                {var completed=pendingExitView;pendingExitView=null;SetView(completed,true);return;}
                townNpcs?.Tick(Time.deltaTime);
                if (followParty) focus = displayedParty;
                if (view.Phase == "area" && Input.GetKeyDown(KeyCode.Space)) SendCommand("area_stop");
                if (view.Phase == "area" && Input.GetKeyDown(KeyCode.Escape) && selectedCharacterSkill!=0) CancelCharacterSkill();
                if(view.Phase=="area"&&!areaLayout.IsTown&&Input.GetKeyDown(KeyCode.E))
                {
                    var obstacle=NearestObstacle();
                    if(obstacle!=null)SendCommand("area_obstacle",obstacle.Id);
                    else {var loot=NearestLoot();if(loot!=null) SendCommand("area_loot",loot.Id);}
                }
                if (townCamera != null)
                {
                    if (Input.GetKeyDown(KeyCode.V)) ToggleTownCamera();
                    if (Input.GetKeyDown(KeyCode.Escape) && view.Area.InteractionKind != 0) SendCommand("area_close");
                    if (Input.GetKeyDown(KeyCode.E) && view.Area.InteractionKind == 0)
                    {
                        NearestInteraction(out var kind, out var id, out _);
                        if (kind != 0) SendCommand("area_interact", kind, id);
                        else {var loot=NearestLoot();if(loot!=null)SendCommand("area_loot",loot.Id);}
                    }
                    if (thirdPerson)
                    {
                        var pointer = new Vector2(Input.mousePosition.x, Screen.height - Input.mousePosition.y);
                        if (AreaPointerBlocked()) return;
                        townCamera.Orbit();
                        if(selectedCharacterSkill!=0 && characterSkillTarget=="container" && Input.GetMouseButtonDown(0))
                        {
                            var ray=mapCamera.ScreenPointToRay(Input.mousePosition);var id=PickContainer(ray,areaRenderer.Pick(ray));
                            if(id!=0)SendCommand("character_skill",selectedCharacter,selectedCharacterSkill,id);
                            return;
                        }
                        if (view.Area.InteractionKind != 0 || Input.GetKey(KeyCode.Space)) { townCamera.ResetSteering(); wasWalking = false; return; }
                        var direction = townCamera.Direction(areaLayout, view.Area, Time.deltaTime);
                        if (wasWalking && !townCamera.Walking) SendCommand("area_stop");
                        wasWalking = townCamera.Walking;
                        // 当前格的平滑移动结束即可衔接下一格，不另设按键冷却或提前堆积路线。
                        if (direction != 0 && !squadRenderer.Busy) SendCommand("area_walk", direction);
                        return;
                    }
                }
            }
            if (view.Phase == "battle" && !AnimationBusy && pendingExitView == null && view.Active.Team == 2 && autoAI && Time.unscaledTime >= nextAI)
            {
                SendCommand("ai"); nextAI = Time.unscaledTime + .8f;
            }
            if (EventSystem.current != null && EventSystem.current.IsPointerOverGameObject()) return;
            if ((view.Phase != "map" && !HasArea) || (view.Phase != "battle" && Input.mousePosition.x <= (mainHud!=null?mainHud.WorldLeftInset:0))) return;
            if (Input.GetKeyDown(KeyCode.F)) FitMap();
            zoom = Mathf.Clamp(zoom * Mathf.Exp(-Input.mouseScrollDelta.y * .12f), 3, 2000);
            if (Input.GetMouseButton(1)) { yaw += Input.GetAxis("Mouse X") * 3; pitch = Mathf.Clamp(pitch - Input.GetAxis("Mouse Y") * 2, 20, 85); }
            var step = new Vector3(Input.GetAxisRaw("Horizontal"), 0, Input.GetAxisRaw("Vertical")) * zoom * Time.unscaledDeltaTime;
            if (Input.GetMouseButton(2)) step += new Vector3(-Input.GetAxis("Mouse X"), 0, -Input.GetAxis("Mouse Y")) * zoom * .035f;
            focus += Quaternion.Euler(0, yaw, 0) * step;
            if (step.sqrMagnitude > 0 && HasArea) followParty = false;
            if (HasArea && Input.GetMouseButtonDown(0))
            {
                var ray=mapCamera.ScreenPointToRay(Input.mousePosition);
                var index = areaRenderer.Pick(ray);
                if (view.Phase == "area")
                {
                    if(AreaPointerBlocked())return;
                    if(selectedCharacterSkill!=0 && characterSkillTarget=="container")
                    {
                        var container=PickContainer(ray,index);
                        if(container!=0)SendCommand("character_skill",selectedCharacter,selectedCharacterSkill,container);
                        else {view.Error="请选择要攻击的容器";BattleHUDRevision++;}
                    }
                    else if(selectedCharacterSkill!=0 && characterSkillTarget=="unit")
                    {
                        var targetId=PickAreaActor(ray,index);
                        if(targetId!=0)SendCommand("character_skill",selectedCharacter,selectedCharacterSkill,targetId);
                        else {view.Error="请选择目标模型或它占据的格子";BattleHUDRevision++;}
                    }
                    else if(index>=0)
                    {
                        if(selectedCharacterSkill==0)SendCommand("area_move_cell",index+1);
                        else SendCommand("character_skill",selectedCharacter,selectedCharacterSkill,index+1);
                    }
                }
                else if(view.Phase=="battle" && view.Active.Team==1)
                {
                    if(moveSelected) {if(index>=0)SendCommand("move_cell",index+1);}
                    else
                    {
                        var skill=Array.Find(view.Skills,row=>row.Id==selectedSkill);
                        if(skill!=null && skill.TargetCells.Length>0) {if(index>=0)SendCommand("skill_cell",selectedSkill,index+1);}
                        else if(selectedSkill>0)
                        {
                            var targetId=PickAreaActor(ray,index);
                            if(targetId!=0)SendCommand("skill",selectedSkill,targetId);
                            else {var container=PickContainer(ray,index);if(container!=0)SendCommand("skill_container",selectedSkill,container);}
                        }
                    }
                }
            }
        }
        private int PickContainer(Ray ray,int groundCell)
        {
            int id=lootRenderer.Pick(ray);if(id!=0)return id;
            if(groundCell>=0)foreach(var loot in view.Area.Loots)
                if(Array.IndexOf(loot.Cells,groundCell)>=0 && areaRenderer.IsCellShown(loot.CellIndex))return loot.Id;
            return 0;
        }
        private int PickAreaActor(Ray ray,int groundCell)
        {
            var enemy=combatRenderer.PickActor(ray,out var enemyDistance);
            var party=squadRenderer.PickActor(ray,out var partyDistance);
            if(enemy!=0 || party!=0)return enemyDistance<=partyDistance?enemy:party;
            if(groundCell<0)return 0;
            var target=Array.Find(view.Area.Enemies,actor=>Array.IndexOf(actor.OccupiedCells,groundCell)>=0);
            if(target!=null)return target.Id;
            var member=Array.Find(view.Area.Members,row=>row.CellIndex==groundCell);
            return member==null?0:member.ActorId;
        }
        private void LateUpdate()
        {
            if (view == null || mapRenderer == null) return;
            if(dialogueCamera!=null && dialogueCamera.Active)
            {
                dialogueCamera.Tick(squadRenderer.Position(dialogueActorId),townNpcs.Position(dialogueNpcId),dialogueShot,dialoguePanelFraction);
                mapRenderer.SetVisible(false);areaRenderer.Draw(mapCamera);environment?.ApplyCameraFocus(displayedParty);return;
            }
            if (thirdPerson)
            {
                townCamera.Apply(mapCamera, squadRenderer.Position(view.Area.Members[0].ActorId));
                environment?.ApplyCameraFocus(displayedParty);
                mapRenderer.SetVisible(false); areaRenderer.Draw(mapCamera);
                DrawExplorationGrid(); return;
            }
            mapCamera.orthographic = true; mapCamera.nearClipPlane = .1f;
            var fraction = view.Phase == "battle" ? 0 : Mathf.Min(.7f, (mainHud!=null?mainHud.WorldLeftInset:0) / Screen.width);
            mapCamera.rect = new Rect(fraction, 0, 1 - fraction, 1);
            var bounds = HasArea ? areaRenderer.Bounds : mapRenderer.Bounds;
            var rotation = Quaternion.Euler(pitch, yaw, 0); var distance = bounds.size.magnitude + zoom + 40;
            mapCamera.transform.SetPositionAndRotation(focus - rotation * Vector3.forward * distance, rotation);
            mapCamera.orthographicSize = zoom; mapCamera.farClipPlane = distance * 2 + 100;
            Feedback?.ApplyCamera(mapCamera);
            environment?.ApplyCameraFocus(focus);
            mapRenderer.SetVisible(!HasArea && view.Phase != "battle");
            if (HasArea)
            {
                areaRenderer.Draw(mapCamera);
                DrawExplorationGrid();
                combatRenderer.Draw(mapCamera, view, areaLayout, moveSelected, selectedSkill);
            }
            else if (view.Phase != "battle") mapRenderer.Draw(mapCamera, true, true, true, true);
        }
        private bool AreaPointerBlocked()
        {
            if(equipmentOpen || growthOpen || storyOpen || fatalError!=null || (EventSystem.current!=null && EventSystem.current.IsPointerOverGameObject())) return true;
            var point=new Vector2(Input.mousePosition.x,Screen.height-Input.mousePosition.y);
            if(!new Rect(0,0,Screen.width,Screen.height).Contains(point)) return true;
            if(showEnvironment && new Rect(Screen.width-308,106,290,196).Contains(point)) return true;
            return false;
        }
        private void DrawExplorationGrid()
        {
            int hover=-1;
            if(view.Phase=="area" && !AreaPointerBlocked()) hover=areaRenderer.Pick(mapCamera.ScreenPointToRay(Input.mousePosition));
            explorationRenderer.SetInteraction(hover,selectedAreaCell);
            explorationRenderer.Draw(mapCamera,view.Area,squadPosition);
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
            if(equipmentOpen || growthOpen || storyOpen) return;
            EnsureStyles();
            if (view == null) { GUI.Label(new Rect(22, 22, Screen.width - 44, 200), fatalError ?? "正在准备远征…", textStyle); return; }
            if(view.Phase=="battle"&&!HasArea) DrawBattle();
            else if(view.Phase=="map") DrawSites();
            if(HasArea && !AreaPointerBlocked())
            {
                var id=lootRenderer.Pick(mapCamera.ScreenPointToRay(Input.mousePosition));
                var loot=Array.Find(view.Area.Loots,row=>row.Id==id);
                if(loot!=null)
                {
                    var label=loot.Name+(loot.MaxDurability>0&&!loot.Destroyed?" · 耐久 "+loot.Durability+"/"+loot.MaxDurability:"");
                    label+=loot.CanSearch?"\n靠近后 E 搜刮 / 存放":!loot.Destroyed?"\n选择攻击技能后点击容器":"";
                    GUI.Label(new Rect(Input.mousePosition.x+16,Screen.height-Input.mousePosition.y+12,300,62),label,textStyle);
                }
            }
            if(showEnvironment) DrawEnvironmentWindow();
        }
        public void ToggleTownCamera()
        {
            SendCommand("area_stop"); townCamera.ResetSteering(); wasWalking = false; thirdPerson = !thirdPerson;
            followParty = true; focus = displayedParty;
            if (!thirdPerson) { zoom = 10 * areaLayout.Radius; pitch = 50; }
        }
        // 提示使用显示快照，命令仍在 Lua 重新检查距离，不能通过 UI 绕过靠近要求。
        private void NearestInteraction(out int kind, out int id, out string label)
        {
            kind = 0; id = 0; label = ""; var best = int.MaxValue;
            foreach (var facility in areaLayout.Facilities)
            {
                var range = areaLayout.StreetDistance(view.Area.CellIndex, facility.EntryIndex, facility.InteractionRadius);
                if (range <= facility.InteractionRadius && range < best) { best = range; kind = 1; id = facility.Id; label = facility.Name; }
            }
            foreach (var npc in view.Area.Npcs)
            {
                if(!npc.Present)continue;
                var range = areaLayout.StreetDistance(view.Area.CellIndex, npc.CellIndex, 1);
                var identity=Array.Find(areaLayout.Npcs,value=>value.Id==npc.Id);
                if (range <= 1 && (range < best || (range==best && identity.NarrativeId>0)))
                { best = range; kind = 2; id = npc.Id; label = Array.Find(areaLayout.Npcs, value => value.Id == npc.Id).Name; }
            }
        }
        private void DrawEnvironmentControls()
        {
            GUILayout.Label("画面 · " + Mathf.FloorToInt(environment.Hour).ToString("00") + ":" + Mathf.FloorToInt(environment.Hour % 1 * 60).ToString("00"), subtitleStyle);
            GUILayout.Label("游戏时钟与 NPC 日程同步 · 参数由配置控制", subtitleStyle);
            GUILayout.BeginHorizontal();
            for (var i = 0; i < environment.Data.Weathers.Length; i++)
                if (GUILayout.Button((environment.WeatherIndex == i ? "● " : "") + environment.Data.Weathers[i].Name, buttonStyle)) environment.SelectWeather(i);
            GUILayout.EndHorizontal();
        }
        private void DrawEnvironmentWindow()
        {
            if (environment == null) return;
            if (!showEnvironment) return;
            var rect = new Rect(Screen.width - 308, 106, 290, 196); Fill(rect, Panel);
            GUILayout.BeginArea(new Rect(rect.x + 12, rect.y + 10, rect.width - 24, rect.height - 20)); DrawEnvironmentControls(); GUILayout.EndArea();
        }
        private void DrawSites()
        {
            foreach (var site in view.Sites)
            {
                var point = mapCamera.WorldToScreenPoint(site.Position + Vector3.up * .6f);
                if (point.z < 0 || point.x < (mainHud!=null?mainHud.WorldLeftInset:0) + 15 || point.x > Screen.width - 15) continue;
                var rect = new Rect(point.x - 17, Screen.height - point.y - 17, 34, 34);
                Fill(new Rect(rect.x - 3, rect.y - 3, 40, 40), Background, circleTexture);
                Fill(rect, site.Available ? Gold : new Color(.4f, .46f, .46f), circleTexture);
                GUI.Label(rect, site.Id.ToString(), tokenStyle);
                if (site.Available && GUI.Button(rect, GUIContent.none, GUIStyle.none) && (EventSystem.current==null||!EventSystem.current.IsPointerOverGameObject())) { SendCommand("visit", site.Id); break; }
            }
        }
        private Vector2 CellCenter(int q, int r, Vector2 center, float size) => center + new Vector2(1.7320508f * (q + r * .5f), 1.5f * r) * size;
        private float BoardSize() => Mathf.Max(8,Mathf.Min((Screen.width-70)/((view.Radius*2+1)*1.7320508f),(Screen.height-210)/(view.Radius*3+2)));
        private Vector2 BoardCenter() => new Vector2(Screen.width*.5f,95+(Screen.height-210)*.5f) + (Feedback != null ? new Vector2(Feedback.ScreenOffset.x,-Feedback.ScreenOffset.y) : Vector2.zero);
        private void DrawBattle()
        {
            var area = new Rect(0, 0, Screen.width, Screen.height); Fill(area, Background);
            var size = BoardSize();var center = BoardCenter();
            var chosen = Array.Find(view.Skills, skill => skill.Id == selectedSkill);
            AdventureViewData.Cell clicked = null;
            foreach (var cell in view.Cells)
            {
                var position = CellCenter(cell.Q, cell.R, center, size);
                var rect = new Rect(position.x - size * .8660254f, position.y - size, size * 1.7320508f, size * 2);
                var reachable = view.Active.Team == 1 && (moveSelected && Array.Exists(view.Reachable, next => next.Q == cell.Q && next.R == cell.R)
                    || chosen!=null && Array.IndexOf(chosen.TargetCells,cell.CellIndex+1)>=0);
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
            if (clicked != null && view.Active.Team == 1 && (EventSystem.current == null || !EventSystem.current.IsPointerOverGameObject()))
            {
                Event.current.Use();
                if (moveSelected) SendCommand("move", clicked.Q, clicked.R);
                else
                {
                    if(chosen!=null && chosen.TargetCells.Length>0) {SendCommand("skill_cell",selectedSkill,clicked.CellIndex+1);return;}
                    var target = Array.Find(view.Units, actor => actor.HP > 0 && Array.IndexOf(actor.OccupiedCells,clicked.CellIndex)>=0);
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
        }
        private void OnDestroy()
        {
            dialogueCamera?.Dispose();dialogueCamera=null;
            environment?.Dispose(); environment = null;
            lootRenderer?.Dispose();lootRenderer=null;
            obstacleRenderer?.Dispose();obstacleRenderer=null;
            constructionRenderer?.Dispose();constructionRenderer=null;
            townNpcs?.Dispose(); townNpcs = null;
            squadRenderer?.Dispose(); squadRenderer = null;
            explorationRenderer?.Dispose(); explorationRenderer = null; squadPosition = null;
            combatRenderer?.Dispose(); combatRenderer = null;
            areaRenderer?.Dispose(); areaRenderer = null;
            mapRenderer?.Dispose(); mapRenderer = null;
            foreach(var owned in new UnityEngine.Object[]{font,hexTexture,circleTexture})
                if(owned!=null){if(Application.isPlaying)Destroy(owned);else DestroyImmediate(owned);}
        }
        private bool IsNearLoot(MapAreaViewData.Loot loot)
        {
            return loot.Near;
        }
        private MapAreaViewData.Loot NearestLoot()
        {
            foreach(var loot in view.Area.Loots) if(!loot.Looted&&loot.CanSearch&&IsNearLoot(loot)) return loot;
            foreach(var loot in view.Area.Loots) if(loot.CanSearch&&IsNearLoot(loot)) return loot;
            return null;
        }
        private MapAreaViewData.Obstacle NearestObstacle()
        {
            foreach(var obstacle in view.Area.Obstacles)foreach(var index in obstacle.Cells)foreach(var member in view.Area.Members)
                if(areaLayout.StreetDistance(member.CellIndex,index,1)<=1)return obstacle;
            return null;
        }
    }
}
