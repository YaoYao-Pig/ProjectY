using System;
using System.Collections.Generic;
using System.IO;
using ProjectY.Samples;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace ProjectY.Editor
{
    /// <summary>按配表生成棋子装配样例、绑定挂点和场景实际资源引用。</summary>
    public static class PawnAssetMenu
    {
        private const string RigPath = "Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab";
        [Serializable] private sealed class PartRow { public int id; public string slot, prefabPath; }
        [Serializable] private sealed class PartTable { public PartRow[] rows; }
        [Serializable] private sealed class TemplateRow { public int id; public int[] partIds; }
        [Serializable] private sealed class TemplateTable { public TemplateRow[] rows; }
        private static string Read(string name) => File.ReadAllText(Path.Combine(Directory.GetParent(Application.dataPath).FullName, "Config/Tables/Adventure/" + name + ".json"));
        // 作者约定的装备局部原点；只用于制作 Rig，运行时读取序列化引用。
        private static readonly string[] Slots = { "body", "base", "mainHand", "offHand", "head", "chest", "back" };
        private static readonly Vector3[] Positions = { Vector3.zero, Vector3.zero, new Vector3(-.5f,.98f,.28f),
            new Vector3(.5f,.98f,.28f), new Vector3(0,1.59f,0), new Vector3(0,1.05f,0), new Vector3(0,1.13f,-.2f) };

        [MenuItem("Project Y/远征/同步棋子资源引用")]
        public static void Sync()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("请先退出 Play。");
            var scene = SceneManager.GetActiveScene();
            if (scene.path != AdventureDemoMenu.ScenePath) throw new InvalidOperationException("请先打开远征 Demo。");
            BuildPrefabs();
            AdventureRuntimeDemo target = null;
            foreach (var root in scene.GetRootGameObjects()) foreach (var demo in root.GetComponentsInChildren<AdventureRuntimeDemo>(true))
            { if (target != null) throw new InvalidOperationException("存在多个远征 Demo。"); target = demo; }
            if (target == null) throw new InvalidOperationException("场景缺少远征 Demo。");
            var fields = new SerializedObject(target); Bind(fields); fields.ApplyModifiedPropertiesWithoutUndo();
            EditorSceneManager.MarkSceneDirty(scene);
            if (!EditorSceneManager.SaveScene(scene)) throw new InvalidOperationException("保存棋子场景引用失败。");
        }
        internal static void Bind(SerializedObject fields)
        {
            var rigAsset = AssetDatabase.LoadAssetAtPath<GameObject>(RigPath);
            var rig = rigAsset == null ? null : rigAsset.GetComponent<PawnView>();
            if (rig == null) throw new InvalidOperationException("棋子 Rig 缺失，请先同步棋子资源引用。");
            fields.FindProperty("pawnPrefab").objectReferenceValue = rig;
            var rows = JsonUtility.FromJson<PartTable>(Read("PawnPartTable")).rows;
            var bindings = fields.FindProperty("pawnBindings"); bindings.arraySize = rows.Length;
            for (var i = 0; i < rows.Length; i++)
            {
                var row = rows[i]; var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(row.prefabPath);
                if (prefab == null) throw new InvalidOperationException("棋子部件缺失：" + row.prefabPath);
                var item = bindings.GetArrayElementAtIndex(i);
                item.FindPropertyRelative("id").intValue = row.id; item.FindPropertyRelative("path").stringValue = row.prefabPath;
                item.FindPropertyRelative("prefab").objectReferenceValue = prefab;
            }
        }
        public static void BuildPrefabs()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("请先退出 Play。");
            var preview = EditorSceneManager.NewPreviewScene();
            try
            {
                var rig = new GameObject("PawnRig").AddComponent<PawnView>(); SceneManager.MoveGameObjectToScene(rig.gameObject, preview);
                var fields = new SerializedObject(rig); var mounts = fields.FindProperty("mounts"); mounts.arraySize = Slots.Length;
                for (var i = 0; i < Slots.Length; i++)
                {
                    var anchor = new GameObject(Slots[i]).transform; anchor.SetParent(rig.transform, false); anchor.localPosition = Positions[i];
                    var row = mounts.GetArrayElementAtIndex(i); row.FindPropertyRelative("slot").stringValue = Slots[i]; row.FindPropertyRelative("anchor").objectReferenceValue = anchor;
                }
                fields.ApplyModifiedPropertiesWithoutUndo(); PrefabUtility.SaveAsPrefabAsset(rig.gameObject, RigPath);
                var parts = new Dictionary<int, PartRow>(); foreach (var row in JsonUtility.FromJson<PartTable>(Read("PawnPartTable")).rows) parts.Add(row.id, row);
                foreach (var template in JsonUtility.FromJson<TemplateTable>(Read("PawnTemplateTable")).rows)
                {
                    var obj = new GameObject("Pawn_Template_" + template.id); SceneManager.MoveGameObjectToScene(obj, preview);
                    foreach (var id in template.partIds)
                    {
                        var row = parts[id]; var slot = Array.IndexOf(Slots, row.slot);
                        if (slot < 0) throw new InvalidOperationException("未知棋子挂点：" + row.slot);
                        var anchor = new GameObject(row.slot).transform; anchor.SetParent(obj.transform, false); anchor.localPosition = Positions[slot];
                        var asset = AssetDatabase.LoadAssetAtPath<GameObject>(row.prefabPath);
                        if (asset == null) throw new InvalidOperationException("缺少棋子部件：" + row.prefabPath);
                        var part = (GameObject)PrefabUtility.InstantiatePrefab(asset, preview); part.transform.SetParent(anchor, false);
                    }
                    PrefabUtility.SaveAsPrefabAsset(obj, "Assets/DynamicAsset/PawnLowPoly/Templates/" + obj.name + ".prefab");
                }
                // NPC 模板独立于战斗单位表，仍使用相同的显式挂点装配。
                var townPath = Path.Combine(Directory.GetParent(Application.dataPath).FullName, "Config/Tables/MapArea/MapAreaTownNpcTable.json");
                if (!AssetDatabase.IsValidFolder("Assets/DynamicAsset/TownLowPoly/Templates")) AssetDatabase.CreateFolder("Assets/DynamicAsset/TownLowPoly", "Templates");
                foreach (var template in JsonUtility.FromJson<TemplateTable>(File.ReadAllText(townPath)).rows)
                {
                    var npc = UnityEngine.Object.Instantiate(rig); npc.name = "Town_NPC_" + template.id;
                    SceneManager.MoveGameObjectToScene(npc.gameObject, preview);
                    var appearance = new PawnAppearanceData { TemplateId = template.id, Parts = new PawnAppearanceData.Part[template.partIds.Length] };
                    for (var i = 0; i < template.partIds.Length; i++)
                    {
                        var part = parts[template.partIds[i]];
                        appearance.Parts[i] = new PawnAppearanceData.Part { Id = part.id, Slot = part.slot, Path = part.prefabPath };
                    }
                    npc.ApplyAppearance(appearance, part => AssetDatabase.LoadAssetAtPath<GameObject>(part.Path));
                    PrefabUtility.SaveAsPrefabAsset(npc.gameObject, "Assets/DynamicAsset/TownLowPoly/Templates/" + npc.name + ".prefab");
                }
            }
            finally { EditorSceneManager.ClosePreviewScene(preview); }
        }
    }
}
