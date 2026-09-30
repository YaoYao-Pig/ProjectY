using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using ProjectY.Samples;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using Object = UnityEngine.Object;

namespace ProjectY.Editor
{
    /// <summary>Persistent local content pipeline. Executes explicit Web jobs in the open Edit Mode only.</summary>
    [InitializeOnLoad]
    public static class ContentCenterBridge
    {
        private const string Cache = "Tools/ContentCenter/.cache";
        private const string Generated = "Assets/DynamicAsset/ContentCenter/";
        [Serializable] private sealed class Dependency { public string path, sha256; }
        [Serializable] private sealed class Request { public string id, kind, sourcePath, createdAt; public Dependency[] configFiles; }
        [Serializable] private sealed class Result { public string id, status, message, completedAt; }
        [Serializable] private sealed class Status { public bool ready; public string message, updatedAt; }
        [Serializable] private sealed class Preview { public string sourcePath, exportedAt; public Dependency[] dependencies; public PawnCustomizationAssets.WebMesh[] meshes; }
        [Serializable] private sealed class AssetRow { public int id; public string modelPath, prefabPath; }
        [Serializable] private sealed class Assets { public AssetRow[] rows; }
        [Serializable] private sealed class ItemRow { public int id, assetId; public string kind; }
        [Serializable] private sealed class Items { public ItemRow[] rows; }
        [Serializable] private sealed class SocketRow { public int id, weaponItemId; public float[] position, rotation; }
        [Serializable] private sealed class Sockets { public SocketRow[] rows; }
        private static double nextTick;
        static ContentCenterBridge() { EditorApplication.update += Tick; }
        private static string Digest(byte[] data) { using (var sha = SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(data)).Replace("-", "").ToLowerInvariant(); }
        private static void Write(string file, object value)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(file));
            string temporary = file + ".tmp";
            File.WriteAllText(temporary, JsonUtility.ToJson(value), new System.Text.UTF8Encoding(false));
            if (File.Exists(file)) File.Replace(temporary, file, null); else File.Move(temporary, file);
        }
        private static void Tick()
        {
            if (EditorApplication.timeSinceStartup < nextTick) return;
            nextTick = EditorApplication.timeSinceStartup + 2;
            bool ready = !EditorApplication.isCompiling && !EditorApplication.isUpdating && !EditorApplication.isPlayingOrWillChangePlaymode;
            Write(Cache + "/editor.json", new Status { ready = ready, updatedAt = DateTime.UtcNow.ToString("o"), message = ready ? "Unity Edit Mode 已就绪" : "请等待 Unity 编译/导入完成，并退出 Play Mode" });
            if (!ready || !Directory.Exists(Cache + "/jobs")) return;
            foreach (string file in Directory.GetFiles(Cache + "/jobs", "*.request.json").OrderBy(File.GetCreationTimeUtc))
            {
                string output = file.Replace(".request.json", ".result.json");
                if (File.Exists(output)) continue;
                Request request = null;
                try
                {
                    request = JsonUtility.FromJson<Request>(File.ReadAllText(file));
                    if (!Guid.TryParse(request.id, out _) || Path.GetFileName(file) != request.id + ".request.json") throw new InvalidOperationException("Invalid content job identity");
                    if (DateTime.UtcNow - DateTime.Parse(request.createdAt).ToUniversalTime() > TimeSpan.FromMinutes(2)) throw new InvalidOperationException("任务已过期，请从 Web 明确重试。");
                    if (request.kind == "preview") ExportPreview(request.sourcePath);
                    else if (request.kind == "sync")
                    {
                        foreach (var dependency in request.configFiles)
                            if (!File.Exists(dependency.path) || Digest(File.ReadAllBytes(dependency.path)) != dependency.sha256) throw new InvalidOperationException("配置在资源同步前已变化，请重新保存并导出：" + dependency.path);
                        SyncContent();
                    }
                    else throw new InvalidOperationException("Unknown content operation");
                    Write(output, new Result { id = request.id, status = "completed", message = request.kind == "preview" ? "真实模型预览已导出" : "模型 Prefab、物品图标、资源目录与角色持握预览已同步", completedAt = DateTime.UtcNow.ToString("o") });
                }
                catch (Exception error)
                {
                    Write(output, new Result { id = request == null ? Path.GetFileName(file).Split('.')[0] : request.id, status = "failed", message = error.Message, completedAt = DateTime.UtcNow.ToString("o") });
                    Debug.LogException(error);
                }
                break;
            }
        }
        private static GameObject Model(string sourcePath)
        {
            string full = Path.GetFullPath(sourcePath), root = Path.GetFullPath(Application.dataPath) + Path.DirectorySeparatorChar;
            if (!sourcePath.StartsWith("Assets/", StringComparison.Ordinal) || !full.StartsWith(root, StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("Model must be inside Assets");
            return AssetDatabase.LoadAssetAtPath<GameObject>(sourcePath) ?? throw new InvalidOperationException("Unity 未导入此 3D 模型：" + sourcePath);
        }
        private static void ExportPreview(string sourcePath)
        {
            var prefab = Model(sourcePath); var scene = EditorSceneManager.NewPreviewScene();
            try
            {
                var instance = (GameObject)PrefabUtility.InstantiatePrefab(prefab, scene);
                var meshes = new List<PawnCustomizationAssets.WebMesh>();
                foreach (var renderer in instance.GetComponentsInChildren<Renderer>(true))
                {
                    Mesh mesh;
                    if (renderer is SkinnedMeshRenderer skin) { mesh = new Mesh(); skin.BakeMesh(mesh); }
                    else if (renderer is MeshRenderer) { var filter = renderer.GetComponent<MeshFilter>(); if (filter == null || filter.sharedMesh == null) continue; mesh = Object.Instantiate(filter.sharedMesh); }
                    else continue;
                    try
                    {
                        var matrix = instance.transform.worldToLocalMatrix * renderer.transform.localToWorldMatrix;
                        mesh.vertices = mesh.vertices.Select(matrix.MultiplyPoint3x4).ToArray();
                        mesh.normals = mesh.normals.Select(n => matrix.inverse.transpose.MultiplyVector(n).normalized).ToArray();
                        if (matrix.determinant < 0) for (int i = 0; i < mesh.subMeshCount; i++) { var indices = mesh.GetTriangles(i); for (int j = 0; j < indices.Length; j += 3) { int swap = indices[j + 1]; indices[j + 1] = indices[j + 2]; indices[j + 2] = swap; } mesh.SetTriangles(indices, i); }
                        var part = new PawnCustomizationCatalog.Part { Id = "preview_" + meshes.Count, Mesh = mesh, Materials = renderer.sharedMaterials, Roles = renderer.sharedMaterials.Select(m => "Equipment").ToArray() };
                        var exported = PawnCustomizationAssets.ExportMesh(part); exported.rigid = true; exported.path = sourcePath; meshes.Add(exported);
                    }
                    finally { Object.DestroyImmediate(mesh); }
                }
                if (meshes.Count == 0) throw new InvalidOperationException("资源没有可预览的网格");
                var paths = new HashSet<string>(AssetDatabase.GetDependencies(sourcePath, true).Where(File.Exists));
                foreach (var dependency in paths.ToArray()) if (File.Exists(dependency + ".meta")) paths.Add(dependency + ".meta");
                var data = new Preview { sourcePath = sourcePath, exportedAt = DateTime.UtcNow.ToString("o"), meshes = meshes.ToArray(), dependencies = paths.Select(p => new Dependency { path = p, sha256 = Digest(File.ReadAllBytes(p)) }).ToArray() };
                Write(Cache + "/previews/" + Digest(System.Text.Encoding.UTF8.GetBytes(sourcePath)) + ".json", data);
            }
            finally { EditorSceneManager.ClosePreviewScene(scene); }
        }
        [MenuItem("Project Y/内容中心/同步模型、图标与持握预览")]
        public static void SyncContent()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("内容同步需要 Edit Mode");
            var assets = JsonUtility.FromJson<Assets>(File.ReadAllText("Config/Tables/Equipment/EquipmentAssetTable.json")).rows;
            var items = JsonUtility.FromJson<Items>(File.ReadAllText("Config/Tables/Equipment/EquipmentItemTable.json")).rows;
            var sockets = JsonUtility.FromJson<Sockets>(File.ReadAllText("Config/Tables/Equipment/EquipmentSocketTable.json")).rows;
            foreach (var asset in assets)
            {
                if (!asset.prefabPath.StartsWith(Generated + "Prefabs/Asset_", StringComparison.Ordinal)) continue;
                if (asset.prefabPath != Generated + "Prefabs/Asset_" + asset.id + ".prefab") throw new InvalidOperationException("Invalid generated prefab path");
                var source = Model(asset.modelPath); var root = new GameObject("ContentAsset_" + asset.id);
                try
                {
                    var model = (GameObject)PrefabUtility.InstantiatePrefab(source); model.transform.SetParent(root.transform, false);
                    var weapon = Array.Find(items, i => i.assetId == asset.id && i.kind == "weapon");
                    if (weapon != null)
                    {
                        var mounts = new List<WeaponModelView.Mount>();
                        foreach (var socket in sockets.Where(s => s.weaponItemId == weapon.id))
                        {
                            if (socket.position.Length != 3 || socket.rotation.Length != 3) throw new InvalidOperationException("Socket must have Vector3 transforms");
                            var anchor = new GameObject("Socket_" + socket.id).transform; anchor.SetParent(root.transform, false);
                            anchor.localPosition = new Vector3(socket.position[0], socket.position[1], socket.position[2]); anchor.localEulerAngles = new Vector3(socket.rotation[0], socket.rotation[1], socket.rotation[2]);
                            mounts.Add(new WeaponModelView.Mount { Id = socket.id, Anchor = anchor });
                        }
                        root.AddComponent<WeaponModelView>().SetMounts(mounts.ToArray());
                    }
                    Directory.CreateDirectory(Path.GetDirectoryName(asset.prefabPath));
                    if (PrefabUtility.SaveAsPrefabAsset(root, asset.prefabPath) == null) throw new InvalidOperationException("Failed to save prefab " + asset.prefabPath);
                }
                finally { Object.DestroyImmediate(root); }
            }
            foreach (var file in Directory.GetFiles("Assets/GameFramework/Resources/_Gen/Config", "*.bytes")) AssetDatabase.ImportAsset(file.Replace('\\', '/'), ImportAssetOptions.ForceSynchronousImport);
            foreach (var weapon in items.Where(i => i.kind == "weapon"))
            {
                var asset = assets.Single(a => a.id == weapon.assetId);
                var root = PrefabUtility.LoadPrefabContents(asset.prefabPath);
                try
                {
                    var view = root.GetComponent<WeaponModelView>();
                    if (view == null) throw new InvalidOperationException("Weapon prefab requires WeaponModelView: " + asset.prefabPath);
                    var current = new SerializedObject(view).FindProperty("mounts");
                    var anchors = new Dictionary<int, Transform>();
                    for (int i = 0; i < current.arraySize; i++)
                    {
                        var element = current.GetArrayElementAtIndex(i);
                        anchors.Add(element.FindPropertyRelative("Id").intValue, (Transform)element.FindPropertyRelative("Anchor").objectReferenceValue);
                    }
                    var mounts = new List<WeaponModelView.Mount>();
                    foreach (var socket in sockets.Where(s => s.weaponItemId == weapon.id))
                    {
                        if (!anchors.TryGetValue(socket.id, out var anchor)) { anchor = new GameObject("Socket_" + socket.id).transform; anchor.SetParent(root.transform, false); }
                        if (anchor == null || socket.position.Length != 3 || socket.rotation.Length != 3) throw new InvalidOperationException("Invalid weapon socket: " + socket.id);
                        anchor.localPosition = new Vector3(socket.position[0], socket.position[1], socket.position[2]); anchor.localEulerAngles = new Vector3(socket.rotation[0], socket.rotation[1], socket.rotation[2]);
                        mounts.Add(new WeaponModelView.Mount { Id = socket.id, Anchor = anchor });
                    }
                    view.SetMounts(mounts.ToArray()); PrefabUtility.SaveAsPrefabAsset(root, asset.prefabPath);
                }
                finally { PrefabUtility.UnloadPrefabContents(root); }
            }
            EquipmentIconExporter.ExportAll();
            PawnCustomizationAssets.ExportWeb();
            AssetDatabase.SaveAssets();
        }
    }
}
