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
        public static PawnAppearanceData Read(LuaTable root)
        {
            using (var parts = root.Get<LuaTable>("parts"))
            {
                var result = new PawnAppearanceData { TemplateId = root.Get<int>("templateId"), Parts = new Part[parts.Length] };
                using(var equipment=root.Get<LuaTable>("equipment")) if(equipment!=null) result.Equipment=EquipmentVisualData.Read(equipment);
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
        private readonly Dictionary<string, Transform> anchors = new Dictionary<string, Transform>();
        private readonly Dictionary<string, GameObject> objects = new Dictionary<string, GameObject>();
        private readonly Dictionary<string, int> partIds = new Dictionary<string, int>();
        public Vector3 EquipmentSlotPosition(string slot) => equipmentView.SlotWorldPosition(slot);

        public void ApplyAppearance(PawnAppearanceData appearance, Func<PawnAppearanceData.Part, GameObject> resolve)
        {
            if (anchors.Count == 0)
            {
                if (mounts == null || mounts.Length == 0) throw new InvalidOperationException("棋子 Prefab 未绑定挂点。");
                foreach (var mount in mounts)
                {
                    if (mount.anchor == null || string.IsNullOrEmpty(mount.slot)) throw new InvalidOperationException("棋子挂点无效。");
                    anchors.Add(mount.slot, mount.anchor);
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
            foreach (var mount in mounts)
            {
                var exists = requested.TryGetValue(mount.slot, out var part);
                if (exists && partIds.TryGetValue(mount.slot, out var previous) && previous == part.Id) continue;
                if (objects.TryGetValue(mount.slot, out var old))
                {
                    old.SetActive(false);
                    if (Application.isPlaying) Destroy(old); else DestroyImmediate(old);
                    objects.Remove(mount.slot); partIds.Remove(mount.slot);
                }
                if (!exists) continue; // 空插槽表示未装备，而不是缺少必需数据。
                var next = Instantiate(prefabs[mount.slot], anchors[mount.slot], false);
                next.transform.localPosition = Vector3.zero;
                next.transform.localRotation = Quaternion.identity;
                next.transform.localScale = Vector3.one;
                objects.Add(mount.slot, next); partIds.Add(mount.slot, part.Id);
            }
            if(equipmentView!=null) equipmentView.Apply(appearance.Equipment);
            else if(appearance.Equipment!=null) throw new InvalidOperationException("棋子未绑定装备显示组件。");
        }
    }
}
