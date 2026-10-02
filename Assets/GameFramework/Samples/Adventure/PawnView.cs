using ProjectY.Data;
using System;
using System.Collections.Generic;
using UnityEngine;
using XLua;

namespace ProjectY.Samples
{
    /// <summary>棋子外观的显示快照；装备状态由业务数据提供，视图不决定装备内容。</summary>
    public sealed class PawnAppearanceData
    {
        public sealed class Part { public int Id; public string Slot, Path; }
        public int TemplateId;
        public Part[] Parts;
        public EquipmentVisualData Equipment;
        public PawnCustomizationData Customization;
        public sealed class RidingData { public Part Body; public Vector3 Seat; }
        public RidingData Riding;
        public static PawnAppearanceData Read(LuaTable root)
        {
            using (var parts = root.Get<LuaTable>("parts"))
            {
                var result = new PawnAppearanceData { TemplateId = root.Get<int>("templateId"), Parts = new Part[parts.Length] };
                // Optional for existing templates and town NPCs; a supplied descriptor is validated by the shared catalog.
                var customization = root.Get<string>("customizationJson");
                if (!string.IsNullOrEmpty(customization)) result.Customization = JsonUtility.FromJson<PawnCustomizationData>(customization);
                using(var equipment=root.Get<LuaTable>("equipment")) if(equipment!=null) result.Equipment=EquipmentVisualData.Read(equipment);
                using(var riding=root.Get<LuaTable>("riding")) if(riding!=null)
                using(var body=riding.Get<LuaTable>("body")) using(var seat=riding.Get<LuaTable>("seat"))
                    result.Riding=new RidingData {Body=new Part {Id=body.Get<int>("id"),Slot="body",Path=body.Get<string>("path")},
                        Seat=new Vector3(seat.Get<int,float>(1),seat.Get<int,float>(2),seat.Get<int,float>(3))};
                for (var i = 0; i < result.Parts.Length; i++) using (var row = parts.Get<int, LuaTable>(i + 1))
                    result.Parts[i] = new Part { Id = row.Get<int>("id"), Slot = row.Get<string>("slot"), Path = row.Get<string>("path") };
                return result;
            }
        }
    }

    /// <summary>固定尺度的桌面战棋棋子。挂点由 Prefab 显式绑定，部件替换不搜索层级。</summary>
    public sealed class PawnView : MonoBehaviour
    {
        [Serializable] public sealed class Mount { public string slot; public Transform anchor; }
        [SerializeField] private Mount[] mounts;
        [SerializeField] private PawnEquipmentView equipmentView;
        [SerializeField] private PawnAnimationView animationView;
        [SerializeField] private PawnCustomizationView customizationView;
        private bool animated;
        private int presentationActorId;
        private GameObject riddenAnimal;
        private int riddenPartId;
        private readonly Dictionary<string, Vector3> staticPositions = new Dictionary<string, Vector3>();
        private readonly Dictionary<string, Transform> anchors = new Dictionary<string, Transform>();
        private readonly Dictionary<string, GameObject> objects = new Dictionary<string, GameObject>();
        private readonly Dictionary<string, int> partIds = new Dictionary<string, int>();
        private readonly List<Renderer> pickRenderers = new List<Renderer>();
        public bool Raycast(Ray ray,out float distance)
        {
            distance=float.PositiveInfinity;
            foreach(var renderer in pickRenderers)
                if(renderer!=null && renderer.enabled && renderer.gameObject.activeInHierarchy &&
                    renderer.bounds.IntersectRay(ray,out var hit) && hit<distance)distance=hit;
            return !float.IsPositiveInfinity(distance);
        }
        public Vector3 EquipmentSlotPosition(string slot) => equipmentView.SlotWorldPosition(slot);
        public Transform HealthTarget => anchors["head"];
        public bool PresentationBusy => animated && animationView.Busy;
        public bool DeathFinished => !animated || animationView.DeathFinished;
        public float BattleMoveSpeed => animated ? animationView.Settings.BattleMoveSpeed * animationView.Settings.PresentationSpeed : 5;
        public float ImpactTime(AdventureViewData.Actor actor, int previousSequence)
        {
            if (!animated) return 0;
            float elapsed = 0;
            foreach (var motion in actor.Actions) if (motion.Sequence > previousSequence)
            {
                var action = animationView.Settings.GetAction(motion.TemplateId);
                if (!string.IsNullOrEmpty(action.State)) return (elapsed + action.Duration * action.Impact) / animationView.Settings.PresentationSpeed;
                elapsed += action.Duration;
            }
            return 0;
        }
        public void Capture(AdventureViewData.Actor actor, Vector3 target, float impactDelay)
        {
            presentationActorId=actor.Id;
            if (animated) {animationView.SetIdentity(actor.Id);animationView.Capture(actor, target, impactDelay * animationView.Settings.PresentationSpeed);}
        }
        public void TickPresentation(float deltaTime, float speed = 0)
        { if (animated) animationView.Tick(deltaTime, speed, transform); }
        public void SkipPresentation() { if (animated) animationView.Skip(); }
        public void PlayInteraction(bool talking) {if(animated) animationView.Interact(talking);}

        public void ApplyAppearance(PawnAppearanceData appearance, Func<PawnAppearanceData.Part, GameObject> resolve)
        {
            if (anchors.Count == 0)
            {
                if (mounts == null || mounts.Length == 0) throw new InvalidOperationException("棋子 Prefab 未绑定挂点。");
                foreach (var mount in mounts)
                {
                    if (mount.anchor == null || string.IsNullOrEmpty(mount.slot)) throw new InvalidOperationException("棋子挂点无效。");
                    anchors.Add(mount.slot, mount.anchor);
                    staticPositions.Add(mount.slot, mount.anchor.localPosition);
                }
            }
            // 先验证整套外观，避免查到缺失资源时只替换了一半装备。
            var requested = new Dictionary<string, PawnAppearanceData.Part>();
            var prefabs = new Dictionary<string, GameObject>();
            foreach (var part in appearance.Parts)
            {
                if (!anchors.ContainsKey(part.Slot)) throw new InvalidOperationException("棋子没有挂点：" + part.Slot);
                requested.Add(part.Slot, part);
                var prefab = resolve(part);
                if (prefab == null) throw new InvalidOperationException("棋子资源缺失：" + part.Id);
                prefabs.Add(part.Slot, prefab);
            }
            if (!requested.ContainsKey("body") || !requested.ContainsKey("base")) throw new InvalidOperationException("棋子缺少身体或底座。");
            bool useAnimation = animationView != null && animationView.Settings.Supports(requested["body"].Id);
            bool refreshPicking=pickRenderers.Count==0 || animated!=useAnimation;
            if(useAnimation)animationView.SetIdentity(presentationActorId==0?appearance.TemplateId:presentationActorId);
            if (animationView != null && (animated != useAnimation || !animationView.gameObject.activeSelf))
            {
                animated = useAnimation;
                animationView.gameObject.SetActive(animated);
                foreach (var mount in mounts)
                {
                    if (mount.slot == "body" || mount.slot == "base") continue;
                    mount.anchor.SetParent(animated ? animationView.Anchor(mount.slot) : transform, false);
                    mount.anchor.localPosition = animated ? Vector3.zero : staticPositions[mount.slot];
                    mount.anchor.localRotation = Quaternion.identity;
                }
            }
            // Old templates and town NPCs use authored defaults from the same modular catalog.
            if (animationView != null) animationView.gameObject.SetActive(useAnimation);
            animated = useAnimation;
            var customization = appearance.Customization;
            if (animated && customization == null)
            {
                if (customizationView == null) throw new InvalidOperationException("Animated pawn has no customization binding.");
                customization = customizationView.Catalog.DefaultAppearance(requested["body"].Id);
            }
            if (customization != null && (!animated || customizationView == null))
                throw new InvalidOperationException("当前棋子未绑定模块化 Humanoid 外观。");
            int previousCustomization = customizationView == null ? 0 : customizationView.Revision;
            if (customizationView != null)
            {
                int coverage = 0; bool hideHair = false;
                if (animated && customization != null)
                {
                    foreach (var part in appearance.Parts) if (PawnCustomizationCatalog.NeedsFit(part.Slot))
                    { var fit = customizationView.Catalog.Fit(part.Path, customization); coverage |= fit.Coverage; hideHair |= fit.HideHair; }
                    if (appearance.Equipment != null) foreach (var worn in appearance.Equipment.Wearables) if (PawnCustomizationCatalog.NeedsFit(worn.Mount))
                    { var fit = customizationView.Catalog.Fit(worn.Model.Path, customization); coverage |= fit.Coverage; hideHair |= fit.HideHair; }
                }
                customizationView.Apply(animated ? customization : null, coverage, hideHair);
            }
            bool customizationChanged = customizationView != null && previousCustomization != customizationView.Revision;
            refreshPicking|=customizationChanged;
            foreach (var mount in mounts)
            {
                var exists = requested.TryGetValue(mount.slot, out var part) && !(animated && mount.slot == "body");
                if (exists && partIds.TryGetValue(mount.slot, out var previous) && previous == part.Id && !customizationChanged) continue;
                if (objects.TryGetValue(mount.slot, out var old))
                {
                    refreshPicking=true;
                    old.SetActive(false);
                    if (Application.isPlaying) Destroy(old); else DestroyImmediate(old);
                    objects.Remove(mount.slot); partIds.Remove(mount.slot);
                }
                if (!exists) continue; // 空插槽表示未装备，而不是缺少必需数据。
                bool fitted = animated && customization != null && PawnCustomizationCatalog.NeedsFit(mount.slot);
                var next = fitted ? customizationView.CreateFit(part.Path) : Instantiate(prefabs[mount.slot], anchors[mount.slot], false);
                next.transform.localPosition = Vector3.zero;
                next.transform.localRotation = Quaternion.identity;
                next.transform.localScale = Vector3.one;
                objects.Add(mount.slot, next); partIds.Add(mount.slot, part.Id);
                refreshPicking=true;
            }
            if(animated && appearance.Equipment==null) animationView.SetHold(null);
            if(equipmentView!=null) {equipmentView.SetAnimation(animated ? animationView : null); equipmentView.SetCustomization(animated && customization != null ? customizationView : null); equipmentView.Apply(appearance.Equipment);}
            else if(appearance.Equipment!=null) throw new InvalidOperationException("棋子未绑定装备显示组件。");
            var ride=appearance.Riding;
            int nextPart=ride==null?0:ride.Body.Id;
            if(riddenPartId!=nextPart)
            {
                refreshPicking=true;
                if(riddenAnimal!=null) {riddenAnimal.SetActive(false);if(Application.isPlaying)Destroy(riddenAnimal);else DestroyImmediate(riddenAnimal);}
                riddenAnimal=ride==null?null:Instantiate(resolve(ride.Body),transform,false);
                riddenPartId=nextPart;
            }
            if(animated) animationView.SetRiding(ride!=null,ride==null?Vector3.zero:ride.Seat);
            if(refreshPicking)
            {
                pickRenderers.Clear();
                foreach(var model in objects.Values)pickRenderers.AddRange(model.GetComponentsInChildren<Renderer>());
                if(animated)pickRenderers.AddRange(animationView.GetComponentsInChildren<Renderer>());
                if(riddenAnimal!=null)pickRenderers.AddRange(riddenAnimal.GetComponentsInChildren<Renderer>());
            }
        }
#if UNITY_EDITOR
        public void BindAnimation(PawnAnimationView value) { animationView = value; }
        public void BindCustomization(PawnCustomizationView value) { customizationView = value; }
#endif
    }
}
