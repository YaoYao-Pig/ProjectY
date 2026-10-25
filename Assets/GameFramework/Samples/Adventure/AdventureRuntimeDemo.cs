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
    public sealed partial class AdventureRuntimeDemo : MonoBehaviour
    {
        [SerializeField] private GameBootstrap bootstrap;
        [SerializeField] private Camera mapCamera;
        [SerializeField] private Shader previewShader;
        [SerializeField] private Light environmentSun;
        [SerializeField] private ExplorationGridRenderer.Settings explorationGrid = new ExplorationGridRenderer.Settings();
        [SerializeField] private MapRenderLod.Settings worldMapLod = new MapRenderLod.Settings();
        private MapEnvironmentController environment;
        private bool showEnvironment;
        [SerializeField] private MapRuntimeDemo.AssetBinding[] assetBindings;
        [SerializeField] private PawnView pawnPrefab;
        [SerializeField] private MeshRenderer townMissionMarkerPrefab;
        [SerializeField] private Material townMissionReadyMaterial;
        [SerializeField] private EquipmentAssetCatalog equipmentCatalog;
        [SerializeField] private MapRuntimeDemo.AssetBinding[] pawnBindings;
        private const string Bridge = "Game.Adventure.DemoBridge";
        private readonly Dictionary<int, MapRuntimeDemo.AssetBinding> assets = new Dictionary<int, MapRuntimeDemo.AssetBinding>();
        private MapPreviewRenderer mapRenderer;
        private MapPreviewData worldMap;
        [SerializeField] private WorldPartyView.Binding[] worldPartyBindings;
        private WorldPartyView worldPartyView;
        private Vector3 displayedTravel;
        private float nextTravelPoll;
        private bool followTravel;
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
            CancelGMKillSelection();
            bootstrap.CallModule("UI.AdventureUIBridge","gm",this);
        }
        private MainHudView mainHud;
        public Camera WorldCamera => mapCamera;
        private BattleFeedbackSystem Feedback => mainHud != null ? mainHud.BattleFeedback : null;
        public void SetMainHud(MainHudView value) {if(mainHud!=value){DisposeBattleCinematic();Feedback?.Clear();}mainHud=value;}
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
        public Transform HealthFootTarget(int actorId)
        {
            if(!HasArea)throw new InvalidOperationException("No 3D scene for foot HUD.");
            return Array.Exists(view.Party,actor=>actor.Id==actorId)?squadRenderer.Target(actorId):combatRenderer.Target(actorId);
        }
        public float HealthRingRadius(int actorId)
        {
            if(!HasArea)throw new InvalidOperationException("No 3D footprint for foot HUD.");
            var actor=Array.Find(view.Party,value=>value.Id==actorId)??Array.Find(view.Area.Enemies,value=>value.Id==actorId);
            if(actor==null)throw new ArgumentException("Missing foot HUD actor: "+actorId);
            float radius=areaLayout.Radius*.8f;
            if(actor.OccupiedCells.Length>1)
            {
                var center=Vector3.zero;
                foreach(var index in actor.OccupiedCells)center+=areaLayout.Cells[index].Position;
                center/=actor.OccupiedCells.Length;
                foreach(var index in actor.OccupiedCells)
                {
                    var delta=areaLayout.Cells[index].Position-center;delta.y=0;
                    radius=Mathf.Max(radius,delta.magnitude+areaLayout.Radius*.8f);
                }
            }
            return radius;
        }
        public Vector2 HealthFootScreenPosition(int actorId)
        {
            var head=HealthScreenPosition(actorId);
            return head-new Vector2(0,BoardSize()*1.05f+22);
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
        private ProjectY.Data.MapAreaStateData areaState;
        private readonly Dictionary<int, MapRuntimeDemo.AssetBinding> pawnAssets = new Dictionary<int, MapRuntimeDemo.AssetBinding>();
        private MapAreaViewData areaLayout;
        private bool revealArea, followParty = true;
        private float nextAreaPoll;
        private Vector3 worldFocus, displayedParty;
        private float worldZoom, worldYaw, worldPitch;
        private AdventureViewData view;
        private AdventureViewData pendingExitView;
        private bool AnimationBusy => HasArea && (squadRenderer.Busy || combatRenderer.Busy || pendingEffects.Count>0 || (visualEffects!=null && visualEffects.Busy) || (battleCinematic!=null && battleCinematic.Active));
        private float nextAI;
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
            if(selectedSkill==id){CancelBattleSkillSelection();return;}
            var skill = Array.Find(view.Skills, row => row.Id == id);
            if (skill == null || (skill.Targets.Length == 0 && skill.TargetCells.Length == 0 && skill.ContainerTargets.Length == 0)) return;
            ClearBattleTargets();selectedSkill = id; moveSelected = false; view.Error = ""; BattleHUDRevision++;
        }
        private void CancelBattleSkillSelection()
        {ClearBattleTargets();selectedSkill=0;moveSelected=view!=null && view.Reachable.Length>0;if(view!=null)view.Error="";BattleHUDRevision++;}
        public void SelectBattleMove()
        {
            if (view?.Phase != "battle" || view.Active.Team != 1 || view.Reachable.Length == 0) return;
            ClearBattleTargets();selectedSkill = 0; moveSelected = true; view.Error = ""; BattleHUDRevision++;
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
            if (bootstrap == null || mapCamera == null || previewShader == null || environmentSun == null || assetBindings == null || pawnPrefab == null || pawnBindings == null || townMissionMarkerPrefab == null || townMissionReadyMaterial == null)
                throw new InvalidOperationException("远征演示未绑定宿主、相机或地图资源。");
            foreach (var binding in assetBindings) assets.Add(binding.id, binding);
            foreach (var binding in pawnBindings) pawnAssets.Add(binding.id, binding);
            font = Font.CreateDynamicFontFromOSFont(new[] { "Microsoft YaHei", "Noto Sans CJK SC", "Arial" }, 16);
            hexTexture = ShapeTexture(false); circleTexture = ShapeTexture(true);
            mapRenderer = new MapPreviewRenderer(previewShader, transform);
            using (var root = (LuaTable)bootstrap.CallModule(Bridge, "presentation")[0])
                environment = new MapEnvironmentController(MapEnvironmentData.Read(root), environmentSun, mapCamera, transform);
            using (var root = (LuaTable)bootstrap.CallModule(Bridge, "visual_effect_catalog")[0]) effectCatalog=BlockEffectCatalog.Read(root);
            OpenCampaignMenu("home");
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
        { OpenCampaignMenu("home"); }
        private bool BuildExpedition(string command,int a=0,string selection=null)
        {
            Feedback?.Clear();
            campaignMenuError="";
            try
            {
                var values = bootstrap.CallModule(Bridge, command,a,selection);
                narrativeData=(ProjectY.Data.NarrativeData)bootstrap.CallModule("Game.Narrative.Bridge","data")[0];
                using (var mapRoot = (LuaTable)values[0])
                using (var stateRoot = (LuaTable)values[1])
                {
                    var error=stateRoot.Get<string>("error");
                    if(!string.IsNullOrEmpty(error))
                    {campaignMenuError=error;if(view!=null)view.Error=error;BattleHUDRevision++;return false;}
                    var next=AdventureViewData.Read(stateRoot);
                    var warning=stateRoot.Get<string>("warning");if(!string.IsNullOrEmpty(warning))next.Error=warning;
                    var map = MapPreviewData.Read(mapRoot);
                    if(HasArea)ClearAreaView();
                    worldPartyView?.Dispose();worldPartyView=null;
                    ClearWorldSites();
                    worldMap=map;
                    mapRenderer.Build(map, asset => {
                        if (!assets.TryGetValue(asset.Id, out var binding) || binding.path != asset.Path || binding.prefab == null)
                            throw new InvalidOperationException("地图资源绑定不一致：" + asset.Id);
                        return binding.prefab;
                    });
                    SetView(next);
                    displayedTravel=view.Travel.Position;followTravel=false;
                }
                fatalError = null; FitMap();cameraRig.Snap();return true;
            }
            catch (Exception exception)
            {
                campaignMenuError=exception.Message;
                if(view==null && !campaignMenuOpen)Report(exception);
                else if(view==null)Debug.LogException(exception,this);
                else {view.Error=exception.Message;BattleHUDRevision++;Debug.LogException(exception,this);}
                return false;
            }
        }
        // 也是此 demo 的最小自动化入口：与按钮使用相同命令，不绕过玩法检查。
        public void SendCommand(string command, int a = 0, int b = 0, int c = 0)
            => SendCommandInternal(command,a,b,c,null);
        private void SendCommandInternal(string command,int a,int b,int c,int[] targetIds)
        {
            if (campaignLoading != null) return;
            if (fatalError != null) return;
            if(command=="gm_begin_kill"){BeginGMKillSelection();return;}
            if(gmKillSelecting && command!="gm_kill_target" && command!="snapshot" && command!="hud_follow")CancelGMKillSelection();
            if(command=="campaign_menu" || command=="campaign_load_menu" || command=="campaign_continue" || command=="load_characters")
            {OpenCampaignMenu(command=="campaign_menu"?"home":"load");return;}
            if(command=="hud_missions"){bootstrap.CallModule("UI.AdventureUIBridge","missions",this);return;}
            if(command=="hud_skill_atlas"){bootstrap.CallModule("UI.AdventureUIBridge","skill_atlas",this);return;}
            if (command == "load_characters" || command == "start_story" || command=="campaign_start" || command=="campaign_continue")
            {
                if (view.Phase != "map" && view.Phase != "area") return;
                BuildExpedition(command,a); return;
            }
            // 对话会暂停世界，不能等待已暂停的角色动画才能选择或关闭。
            var dialogueCommand=command=="dialogue_choose" || command=="dialogue_interject" || command=="dialogue_close" || command=="shop_open" || command=="shop_buy" || command=="shop_close" || command.StartsWith("town_mission_",StringComparison.Ordinal);
            if (pendingExitView != null || (!dialogueCommand && !command.StartsWith("gm_",StringComparison.Ordinal) && HasArea && command != "snapshot" && command != "area_stop" &&
                (view.Phase == "battle" ? AnimationBusy : squadRenderer.ActionBusy || combatRenderer.ActionBusy))) return;
            if(command=="hud_follow")
            {
                if(view.Phase=="map") {followTravel=true;focus=displayedTravel;zoom=20*worldMap.Radius;pitch=52;return;}
                if(!HasArea) return;
                followParty=true;focus=displayedParty;zoom=10*areaLayout.Radius;pitch=50;return;
            }
            try
            {
                var values = bootstrap.CallModule(Bridge, command, a, targetIds==null?(object)b:targetIds, c);
                using (var root = (LuaTable)values[0])
                {
                    if (root.Get<bool>("unchanged")) return;
                    var next=AdventureViewData.Read(root);
                    if(command=="snapshot")next.RetainPollingFeedback(view);
                    // GM 传送可能跨城镇或跨越很长距离；重建显示宿主，不把瞬移解释为寻路动画。
                    if(root.Get<bool>("gmTeleport") && HasArea)ClearAreaView();
                    SetView(next);
                    if(root.Get<bool>("gmTeleport") && string.IsNullOrEmpty(next.Error))
                    {
                        var npc=Array.Find(areaLayout.Npcs,row=>row.NarrativeId==a);
                        if(npc==null)throw new InvalidOperationException("GM target NPC is absent from the displayed layout.");
                        followParty=false;
                        focus=(townNpcs.Position(npc.Id)+squadRenderer.Position(view.Area.Members[0].ActorId))*.5f;
                        zoom=Mathf.Max(4,areaLayout.Radius*3);pitch=50;yaw=-25;
                        cameraRig.Snap(); cameraDragButton = -1;
                    }
                }
                if(command=="character_skill")CancelCharacterSkill();
                if((command=="skill" || command=="skill_targets" || command=="skill_landing" || command=="skill_cell" || command=="skill_container" || command=="use_item") && string.IsNullOrEmpty(view.Error))
                    CancelBattleSkillSelection();
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
            bool wasBattle = view?.Phase == "battle";
            if(value.Phase!=view?.Phase)CancelGMKillSelection();
            if(value.Phase!=view?.Phase || !Array.Exists(value.Party,actor=>actor.Id==selectedCharacter))
            {selectedCharacterSkill=0;characterSkillTarget=null;}
            if(!Array.Exists(value.Party,actor=>actor.Id==selectedCharacter))selectedCharacter=0;
            if (!exitPresentationComplete && HasArea && view.Phase == "battle" && value.Area == null)
            {
                CaptureBattleCinematic(value.VisualEffects,0,true);
                QueueVisualEffects(value.VisualEffects,0);value.VisualEffects=Array.Empty<WorldEffectEvent>();
                Feedback?.Commit(0);
                squadRenderer.CaptureExit(value.Party);
                if (AnimationBusy) {pendingExitView=value;return;}
            }
            var enteringBattle = value.Area != null && value.Phase == "battle" && view?.Phase != "battle";
            var resumingExploration = value.Area != null && value.Phase == "area" && view?.Phase == "battle";
            bool enteringArea = value.Area != null && !HasArea;
            if (enteringArea)
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
                if (areaLayout.Npcs.Length > 0)
                {
                    townNpcs = new TownNpcRenderer(transform, pawnPrefab, areaLayout, ResolvePawnPart, townMissionMarkerPrefab, townMissionReadyMaterial);
                }
                focus = displayedParty = areaLayout.Cells[value.Area.CellIndex].Position;
                zoom = 10 * areaLayout.Radius; pitch = 50; yaw = -35;
                cameraDragButton = -1;
            }
            else if (value.Area == null && HasArea)
            {
                ClearAreaView();
            }
            SyncBattleTargets(view,value);
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
            CaptureBattleCinematic(value.VisualEffects,impactDelay,wasBattle);
            QueueVisualEffects(value.VisualEffects,impactDelay);
            if (enteringBattle) FocusBattle();
            if (enteringArea) cameraRig.Snap();
            if (resumingExploration) { followParty = true; focus = displayedParty = areaLayout.Cells[view.Area.CellIndex].Position; }
            if (view.ActiveId != lastActor)
            {
                lastActor = view.ActiveId; moveSelected = true; selectedSkill = 0;ClearBattleTargets();
                nextAI = Time.unscaledTime + .8f;
            }
            if (view.Phase == "battle" && view.Active.Moved) moveSelected = false;
            if(worldMap!=null)
            {
                if(worldPartyView==null)worldPartyView=new WorldPartyView(transform,worldPartyBindings,worldMap.Radius,previewShader,worldMapLod);
                mapRenderer.SetExploration(view.WorldFog);
                worldPartyView.Sync(view);
            }
            BattleHUDRevision++;
            bootstrap.CallModule("UI.AdventureUIBridge", "sync", this);
        }
        private void ClearAreaView()
        {
            DisposeBattleCinematic();
            DisposeVisualEffects();
            Feedback?.Clear();
            areaState = null;
            dialogueCamera?.Dispose();dialogueCamera=null;
            squadRenderer.Dispose();squadRenderer=null;
            explorationRenderer.Dispose();explorationRenderer=null;squadPosition=null;
            combatRenderer.Dispose();combatRenderer=null;
            lootRenderer.Dispose();lootRenderer=null;
            obstacleRenderer.Dispose();obstacleRenderer=null;
            constructionRenderer.Dispose();constructionRenderer=null;
            townNpcs?.Dispose();townNpcs=null;
            environment?.SetArea(null);
            areaRenderer.Dispose();areaRenderer=null;areaLayout=null;
            focus=worldFocus;zoom=worldZoom;yaw=worldYaw;pitch=worldPitch;
            cameraRig.Snap(); cameraDragButton = -1;
            view.Area=null;
        }
        private void FocusBattle()
        {
            var bounds = new Bounds(areaLayout.Cells[view.Units[0].CellIndex].Position, Vector3.zero);
            foreach (var actor in view.Units) if (actor.HP > 0) bounds.Encapsulate(areaLayout.Cells[actor.CellIndex].Position);
            focus = bounds.center; followParty = false;
            var viewport = CameraViewport;
            zoom = StrategyCameraRig.FitSize(bounds, yaw, pitch, viewport.width / viewport.height, 10 * areaLayout.Radius);
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
            followTravel=false;
            if (HasArea && view.Phase == "battle") { FocusBattle(); return; }
            var bounds = HasArea ? areaRenderer.Bounds : mapRenderer.Bounds; focus = bounds.center;
            if (HasArea) followParty = false;
            var viewport = CameraViewport;
            zoom = StrategyCameraRig.FitSize(bounds, yaw, pitch, viewport.width / viewport.height, 8);
        }
        private void Update()
        {
            cameraInputProcessed = false;
            battleCinematic?.RestoreTransforms();
            Feedback?.SetPlaybackRate(0);
            if (campaignLoading != null) { AdvanceCampaignLoading(); return; }
            if(environment!=null && narrativeData!=null){environment.Running=false;environment.Hour=(float)(narrativeData.Minutes/60%24);}
            environment?.Tick(Time.unscaledDeltaTime, view?.Area);
            environment?.SetTorch(HasArea && view.Torch!=null && view.Torch.Enabled,displayedParty);
            if (view == null || fatalError != null || campaignMenuOpen) return;
            if(Input.GetKeyDown(KeyCode.F8))OpenGM();
            if(gmOpen)return;
            if(gmKillSelecting && (Input.GetKeyDown(KeyCode.Escape) || Input.GetMouseButtonDown(1)))
            {CancelGMKillSelection();return;}
            if(Input.GetKeyDown(KeyCode.C)) OpenGrowth();
            if(growthOpen || storyOpen) {CancelGMKillSelection();return;}
            if(dialogueCamera!=null && dialogueCamera.Active)return;
            if(Input.GetKeyDown(KeyCode.I))
            {
                if(equipmentOpen) bootstrap.CallModule("UI.EquipmentUIBridge","close");else OpenEquipment();
            }
            if(equipmentOpen) {CancelGMKillSelection();return;}
            if(Input.GetKeyDown(KeyCode.T))SendCommand("torch_toggle");
            if(Input.GetKeyDown(KeyCode.F5))SendCommand("save_characters");
            float presentationDelta = battleCinematic != null ? battleCinematic.Advance(Time.deltaTime) : Time.deltaTime;
            Feedback?.SetPlaybackRate(battleCinematic != null ? battleCinematic.PlaybackRate : 1);
            Feedback?.Tick(presentationDelta);
            if(view.Phase=="map")
            {
                if(Time.unscaledTime>=nextTravelPoll) {SendCommand("snapshot");nextTravelPoll=Time.unscaledTime+.1f;}
                if(fatalError!=null || view.Phase!="map")return;
                displayedTravel=Vector3.Lerp(displayedTravel,view.Travel.Position,1-Mathf.Exp(-Time.unscaledDeltaTime*20));
                worldPartyView.Tick(displayedTravel,Time.unscaledDeltaTime);
                if(followTravel)focus=displayedTravel;
                if(Input.GetKeyDown(KeyCode.Space))SendCommand("travel_pause");
                if(Input.GetKeyDown(KeyCode.Alpha1))SendCommand("travel_speed",1);
                if(Input.GetKeyDown(KeyCode.Alpha2))SendCommand("travel_speed",2);
                if(Input.GetKeyDown(KeyCode.Alpha3))SendCommand("travel_speed",4);
            }
            if (HasArea)
            {
                // 城镇移动与居民占格变化当帧同步，避免在每个格子之间再等一次轮询。
                if (view.Phase == "area" && ((areaLayout.IsTown && areaState.Revision != view.Area.Revision) || Time.unscaledTime >= nextAreaPoll))
                { SendCommand("snapshot"); nextAreaPoll = Time.unscaledTime + .10f; }
                if (fatalError != null) return;
                squadRenderer.Tick(presentationDelta);
                // A defeated squad can have no living members while its final animation finishes.
                if (view.Area.Members.Length > 0) displayedParty = squadRenderer.Position(view.Area.Members[0].ActorId);
                else followParty = false;
                environment?.SetTorch(view.Torch!=null && view.Torch.Enabled,displayedParty);
                combatRenderer.Tick(presentationDelta);
                TickVisualEffects(presentationDelta);
                if (Input.GetKeyDown(KeyCode.Space) && (view.Phase == "battle" || pendingExitView != null))
                {ClearBattleCinematic();squadRenderer.Skip();combatRenderer.Skip();Feedback?.Skip();ClearVisualEffects();}
                if (pendingExitView != null && !AnimationBusy)
                {var completed=pendingExitView;pendingExitView=null;SetView(completed,true);return;}
                townNpcs?.Tick(Time.deltaTime);
                if (followParty) focus = displayedParty;
                if (view.Phase == "area" && Input.GetKeyDown(KeyCode.Space)) SendCommand("area_stop");
                if (view.Phase == "area" && Input.GetKeyDown(KeyCode.Escape) && selectedCharacterSkill!=0) CancelCharacterSkill();
                if(view.Phase=="area" && Input.GetKeyDown(KeyCode.E)) SendCommand("area_interact_nearest");
                if(view.Phase=="area" && Input.GetKeyDown(KeyCode.Escape) && view.Area.InteractionKind!=0) SendCommand("area_close");
            }
            if(gmKillSelecting){UpdateGMKillSelection();return;}
            if (view.Phase == "battle" && !AnimationBusy && pendingExitView == null && view.Active.Team != 1 && autoAI && Time.unscaledTime >= nextAI)
            {
                SendCommand("ai"); nextAI = Time.unscaledTime + .8f;
            }
            if (battleCinematic != null && battleCinematic.Active) return;
            if (view.Phase != "map" && !HasArea) return;
            UpdateCameraInput();
            if (Input.GetMouseButton(1) || Input.GetMouseButton(2)) { SetBattleTargetHover(0); return; }
            if (EventSystem.current != null && EventSystem.current.IsPointerOverGameObject()) {SetBattleTargetHover(0);return;}
            if (PointerOverInterface()) return;
            if(view.Phase=="map" && Input.GetMouseButtonDown(0))
            {
                int partyId=worldPartyView.Pick(mapCamera,Input.mousePosition);
                if(partyId!=0){SendCommand("world_pursue",partyId);return;}
                var site=WorldSiteAtPointer();
                if(site!=null)SendCommand("visit",site.Id);
                else {var index=WorldTravelView.Pick(worldMap,mapCamera.ScreenPointToRay(Input.mousePosition));if(index>=0)SendCommand("travel_move",index+1);}
                return;
            }
            if(HasArea && view.Phase=="battle")
            {
                var hoverRay=mapCamera.ScreenPointToRay(Input.mousePosition);
                var hoverIndex=areaRenderer.Pick(hoverRay);
                SetBattleTargetHover(PickAreaActor(hoverRay,hoverIndex));
                SetBattleCellHover(Array.Find(view.Cells,cell=>cell.CellIndex==hoverIndex));
            }
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
                    if(IsChoosingBattleLanding)
                    {
                        if(index>=0){var landing=areaLayout.Cells[index];ChooseBattleLanding(landing.Q,landing.R);}
                    }
                    else if(moveSelected) {if(index>=0)SendCommand("move_cell",index+1);}
                    else
                    {
                        var skill=Array.Find(view.Skills,row=>row.Id==selectedSkill);
                        if(skill!=null && skill.TargetCells.Length>0) {if(index>=0)SendCommand("skill_cell",selectedSkill,index+1);}
                        else if(selectedSkill>0)
                        {
                            var targetId=PickAreaActor(ray,index);
                            if(targetId!=0)ChooseBattleTarget(targetId);
                            else if(!IsSelectingBattleTargets) {var container=PickContainer(ray,index);if(container!=0)SendCommand("skill_container",selectedSkill,container);}
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
            if (!cameraInputProcessed) { cameraDragButton = -1; cameraRig.Stop(); }
            if (campaignLoading != null) {worldSites?.Hide();return;}
            if (view == null || mapRenderer == null) return;
            if(dialogueCamera!=null && dialogueCamera.Active)
            {
                worldSites?.Hide();
                dialogueCamera.Tick(squadRenderer.Position(dialogueActorId),townNpcs.Position(dialogueNpcId),dialogueShot,dialoguePanelFraction);
                townNpcs.LateTick(mapCamera);
                mapRenderer.SetVisible(false);areaRenderer.Draw(mapCamera);environment?.ApplyCameraFocus(displayedParty);return;
            }
            mapCamera.orthographic = true; mapCamera.nearClipPlane = .1f;
            var fraction = view.Phase == "battle" ? 0 : Mathf.Min(.7f, (mainHud!=null?mainHud.WorldLeftInset:0) / Screen.width);
            mapCamera.rect = new Rect(fraction, 0, 1 - fraction, 1);
            var bounds = HasArea ? areaRenderer.Bounds : mapRenderer.Bounds;
            cameraRig.Tick(Time.unscaledDeltaTime);
            var rotation = Quaternion.Euler(cameraRig.RenderPitch, cameraRig.RenderYaw, 0); var distance = bounds.size.magnitude + cameraRig.RenderZoom + 40;
            mapCamera.transform.SetPositionAndRotation(cameraRig.RenderFocus - rotation * Vector3.forward * distance, rotation);
            mapCamera.orthographicSize = cameraRig.RenderZoom; mapCamera.farClipPlane = distance * 2 + 100;
            battleCinematic?.ApplyCamera(mapCamera,cameraRig.RenderFocus,cameraRig.RenderYaw,cameraRig.RenderPitch);
            Feedback?.ApplyCamera(mapCamera);
            townNpcs?.LateTick(mapCamera);
            battleCinematic?.DrawMask(mapCamera);
            environment?.ApplyCameraFocus(cameraRig.RenderFocus);
            TickWorldSites();
            mapRenderer.SetVisible(!HasArea && view.Phase != "battle");
            if (HasArea)
            {
                areaRenderer.Draw(mapCamera);
                DrawExplorationGrid();
                combatRenderer.Draw(mapCamera, view, areaLayout, moveSelected, selectedSkill,selectedBattleTargets,IsChoosingBattleLanding?battleLandingCells:null);
            }
            else if (view.Phase != "battle")
            {
                worldPartyView?.Render(mapCamera);
                mapRenderer.Draw(mapCamera, true, true, true, true, worldMapLod);
            }
        }
        private bool AreaPointerBlocked()
        {
            return campaignMenuOpen || equipmentOpen || growthOpen || storyOpen || gmOpen || fatalError != null ||
                Input.GetMouseButton(1) || Input.GetMouseButton(2) || PointerOverInterface();
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
            if(campaignLoading!=null || equipmentOpen || growthOpen || storyOpen || campaignMenuOpen) return;
            EnsureStyles();
            if (view == null)
            {
                GUI.Label(new Rect(22,22,Screen.width-44,180),fatalError??ProjectY.UI.LuaLanguage.Get("CampaignPreparing"),textStyle);
                if(fatalError!=null)
                {
                    GUILayout.BeginArea(new Rect(22,210,Mathf.Min(540,Screen.width-44),260));
                    GUILayout.Label(ProjectY.UI.LuaLanguage.Get("CampaignRetrySize"),titleStyle);
                    if(Button(ProjectY.UI.LuaLanguage.Get("CampaignSizeSmall")))BuildExpedition("campaign_start",2500);
                    if(Button(ProjectY.UI.LuaLanguage.Get("CampaignSizeMedium")))BuildExpedition("campaign_start",10000);
                    if(Button(ProjectY.UI.LuaLanguage.Get("CampaignSizeLarge")))BuildExpedition("campaign_start",30000);
                    if(Button(ProjectY.UI.LuaLanguage.Get("CampaignSizeHuge")))BuildExpedition("campaign_start",100000);
                    GUILayout.EndArea();
                }
                return;
            }
            if(view.Phase=="battle"&&!HasArea) DrawBattle();
            else if(view.Phase=="map") {WorldTravelView.Draw(mapCamera,view.Travel,displayedTravel,textStyle);worldPartyView.DrawHover(mapCamera,textStyle);}
            if(HasArea) townNpcs?.DrawNames(mapCamera,smallStyle);
            if(HasArea && !AreaPointerBlocked())
            {
                var id=lootRenderer.Pick(mapCamera.ScreenPointToRay(Input.mousePosition));
                var loot=Array.Find(view.Area.Loots,row=>row.Id==id);
                if(loot!=null)
                {
                    var label=loot.Name+(loot.MaxDurability>0&&!loot.Destroyed?ProjectY.UI.LuaLanguage.Format("LootHoverDurability",loot.Durability,loot.MaxDurability):"");
                    label+=loot.CanSearch?ProjectY.UI.LuaLanguage.Get("LootHoverSearch"):!loot.Destroyed?ProjectY.UI.LuaLanguage.Get("LootHoverAttack"):"";
                    GUI.Label(new Rect(Input.mousePosition.x+16,Screen.height-Input.mousePosition.y+12,300,62),label,textStyle);
                }
            }
            if(showEnvironment) DrawEnvironmentWindow();
            DrawGMKillSelection();
        }
        internal bool TryInteractionPoint(int kind,int id,int cellIndex,out Vector3 point)
        {
            point=Vector3.zero;
            if(!HasArea || view.Phase!="area" || cellIndex<1 || cellIndex>areaLayout.Cells.Length || equipmentOpen || growthOpen || storyOpen || gmOpen)return false;
            point=areaLayout.Cells[cellIndex-1].Position+Vector3.up*1.4f;
            if(kind==2)
            {
                if(townNpcs==null || !Array.Exists(view.Area.Npcs,npc=>npc.Id==id && npc.Present))return false;
                point=townNpcs.Position(id)+Vector3.up*2.1f;
            }
            return true;
        }
        public void ToggleTownCamera()
        {
            if(!HasArea)return;
            followParty = true; focus = displayedParty;zoom = 10 * areaLayout.Radius; pitch = 50;
        }
        private void DrawEnvironmentControls()
        {
            GUILayout.Label(ProjectY.UI.LuaLanguage.Format("EnvironmentClock",Mathf.FloorToInt(environment.Hour).ToString("00"),Mathf.FloorToInt(environment.Hour % 1 * 60).ToString("00")), subtitleStyle);
            GUILayout.Label(ProjectY.UI.LuaLanguage.Get("EnvironmentClockHint"), subtitleStyle);
            GUILayout.BeginHorizontal();
            for (var i = 0; i < environment.Data.Weathers.Length; i++)
                if (GUILayout.Button((environment.WeatherIndex == i ? "● " : "") + environment.Data.Weathers[i].Name, buttonStyle)) environment.SelectWeather(i);
            GUILayout.EndHorizontal();
            if(view?.Torch!=null && Button(view.Torch.Label,view.Torch.Available))SendCommand("torch_toggle");
        }
        private void DrawEnvironmentWindow()
        {
            if (environment == null) return;
            if (!showEnvironment) return;
            var rect = new Rect(Screen.width - 308, 106, 290, 236); Fill(rect, Panel);
            GUILayout.BeginArea(new Rect(rect.x + 12, rect.y + 10, rect.width - 24, rect.height - 20)); DrawEnvironmentControls(); GUILayout.EndArea();
        }
        private AdventureViewData.Site WorldSiteAtPointer()
        {
            return WorldSitePointerEnabled ? worldSites?.Pick(mapCamera,Input.mousePosition) : null;
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
            AdventureViewData.Cell hoveredCell=null;
            foreach (var cell in view.Cells)
            {
                var position = CellCenter(cell.Q, cell.R, center, size);
                var rect = new Rect(position.x - size * .8660254f, position.y - size, size * 1.7320508f, size * 2);
                var reachable = view.Active.Team == 1 && (IsBattleLandingCell(cell.Q,cell.R)
                    || !IsChoosingBattleLanding && (moveSelected && Array.Exists(view.Reachable, next => next.Q == cell.Q && next.R == cell.R)
                    || chosen!=null && Array.IndexOf(chosen.TargetCells,cell.CellIndex+1)>=0));
                var color = cell.Blocked ? new Color(.12f, .15f, .17f) : reachable ? new Color(.19f, .39f, .34f) : new Color(.18f, .23f, .25f);
                if (!cell.Blocked && !reachable && view.Active.Team==1 && !IsChoosingBattleLanding && chosen!=null
                    && Array.IndexOf(chosen.RangeCells,cell.CellIndex+1)>=0) color=new Color(.27f,.38f,.57f);
                Fill(rect, new Color(.08f, .12f, .14f), hexTexture);
                var inner = new Rect(rect.x + 2, rect.y + 2, rect.width - 4, rect.height - 4); Fill(inner, color, hexTexture);
                if (cell.Blocked) GUI.Label(rect, "◆", tokenStyle);
                if(Array.Exists(view.Traps,trap=>trap.Q==cell.Q && trap.R==cell.R))GUI.Label(rect,"×",tokenStyle);
                var e = Event.current;
                var dx = Mathf.Abs(e.mousePosition.x - position.x) / (size * .8660254f);
                var dy = Mathf.Abs(e.mousePosition.y - position.y) / size;
                if(dx <= 1 && dy <= 1 - dx * .5f)
                {
                    hoveredCell=cell;
                    if (e.type == EventType.MouseDown && e.button == 0) clicked = cell;
                }
            }
            // 尸体先画，存活角色在其上方；尸体不阻挡路径。
            foreach (var actor in view.Units) if (actor.HP == 0) DrawActor(actor, center, size, chosen);
            foreach (var actor in view.Units) if (actor.HP > 0) DrawActor(actor, center, size, chosen);
            var hovered=hoveredCell==null?null:Array.Find(view.Units,actor=>actor.HP>0 && Array.IndexOf(actor.OccupiedCells,hoveredCell.CellIndex)>=0);
            SetBattleTargetHover(EventSystem.current!=null && EventSystem.current.IsPointerOverGameObject()?0:(hovered?.Id ?? 0));
            SetBattleCellHover(EventSystem.current!=null && EventSystem.current.IsPointerOverGameObject()?null:hoveredCell);
            if (clicked != null && (gmKillSelecting || view.Active.Team == 1) && (EventSystem.current == null || !EventSystem.current.IsPointerOverGameObject()))
            {
                Event.current.Use();
                if(gmKillSelecting){TryGMKillTarget(hovered==null?0:hovered.Id);return;}
                if(IsChoosingBattleLanding)ChooseBattleLanding(clicked.Q,clicked.R);
                else if (moveSelected) SendCommand("move", clicked.Q, clicked.R);
                else
                {
                    if(chosen!=null && chosen.TargetCells.Length>0) {SendCommand("skill_cell",selectedSkill,clicked.CellIndex+1);return;}
                    var target = Array.Find(view.Units, actor => actor.HP > 0 && Array.IndexOf(actor.OccupiedCells,clicked.CellIndex)>=0);
                    if (target != null && selectedSkill > 0) ChooseBattleTarget(target.Id);
                }
            }
        }
        private void DrawActor(AdventureViewData.Actor actor, Vector2 center, float size, AdventureViewData.Skill chosen)
        {
            var position = CellCenter(actor.Q, actor.R, center, size);
            var radius = size * .61f;
            var rect = new Rect(position.x - radius, position.y - radius, radius * 2, radius * 2);
            var target = chosen != null && Array.IndexOf(chosen.Targets, actor.Id) >= 0;
            var selected=selectedBattleTargets.IndexOf(actor.Id);
            if (actor.Id == view.ActiveId || target || selected>=0) Fill(new Rect(rect.x - 3, rect.y - 3, rect.width + 6, rect.height + 6), selected>=0?Teal:target ? Gold : Color.white, circleTexture);
            Fill(rect, actor.HP == 0 ? new Color(.23f, .26f, .27f) : actor.Team == 1 || actor.Team == 4 ? Teal * .7f
                : actor.Team == 2 ? Enemy * .8f : new Color(.96f,.78f,.22f), circleTexture);
            var separator = actor.Name.IndexOf(" · ", StringComparison.Ordinal);
            var label = actor.HP == 0 ? "×" : separator > 0 ? actor.Name.Substring(0, separator) : actor.Name.Substring(0, Mathf.Min(3, actor.Name.Length));
            GUI.Label(rect, label, tokenStyle);
            if(selected>=0)GUI.Label(new Rect(rect.xMax-12,rect.y-10,24,22),(selected+1).ToString(),tokenStyle);
        }
        private void OnDestroy()
        {
            DisposeBattleCinematic();
            ClearWorldSites();
            EndCampaignLoading();
            DisposeVisualEffects();
            worldPartyView?.Dispose();worldPartyView=null;
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
    }
}
