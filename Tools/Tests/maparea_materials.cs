// Unity MCP execute_code body: compiled MapArea renderer and exported theme/assets; Edit Mode only.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
var scene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
var dirty = scene.isDirty;
System.Action<bool,string> check = (ok,message) => { if (!ok) throw new System.Exception(message); };
var shader = UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
var state = new ProjectY.Samples.MapAreaViewData.State {
    Revision = 1, Known = new[] { 0 }, Visible = new[] { 0 }, Members = new ProjectY.Samples.MapAreaViewData.Member[0]
};
int named = 0, optional = 0, rejected = 0;
using (var lua = new XLua.LuaEnv())
{
    var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load);
    using (var assets = (XLua.LuaTable)lua.DoString(@"
        local registry = require('Core.SystemRegistry')({ReadConfig=function(_,name)
            local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
            local bytes=file:read('*a');file:close();return bytes
        end,LogError=error})
        registry:Register('Config',require('Config.ConfigSystem'));registry:Start()
        local config=registry:Get('Config');local assets,seen={},{}
        for _,name in ipairs({'MapAreaThemeTable','MapAreaTownThemeTable','MapAreaForestThemeTable',
            'MapAreaBattlefieldThemeTable','MapAreaShipwreckThemeTable','MapAreaMineThemeTable'}) do
            for _,theme in ipairs(config:GetTable(name):All()) do
                if not seen[theme.assetId] then
                    local row=config:GetTable('MapAssetTable'):Get(theme.assetId)
                    assets[#assets+1]={id=row.id,path=row.prefabPath,tint=row.tintMaterial};seen[row.id]=true
                end
            end
        end
        registry:Shutdown();return assets", "@maparea_materials")[0])
    for (int i = 1; i <= assets.Length; i++) using (var row = assets.Get<int,XLua.LuaTable>(i))
    {
        var map = new ProjectY.Samples.MapAreaViewData {
            AssetId = row.Get<int>("id"), AssetPath = row.Get<string>("path"), TintMaterial = row.Get<string>("tint"),
            Radius = 1.5f, AreaType = 4, PropAssets = new ProjectY.Samples.MapAreaViewData.Asset[0],
            Cells = new[] { new ProjectY.Samples.MapAreaViewData.Cell {
                Kind = "floor", Corners = new float[6], Color = Color.gray, SurfaceId = 1
            } }
        };
        map.Surfaces.Add(1, new ProjectY.Samples.MapAreaViewData.Surface { Color = Color.gray, DetailColor = Color.gray });
        var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(map.AssetPath);
        check(prefab != null, "Missing configured model: " + map.AssetPath);
        System.Func<ProjectY.Samples.MapAreaViewData.Asset,GameObject> resolve = asset => { throw new System.Exception("Unexpected prop"); };
        using (var renderer = new ProjectY.Samples.MapAreaRenderer(shader, prefab, map, resolve)) renderer.UpdateVisibility(state, false);
        if (string.IsNullOrEmpty(map.TintMaterial)) optional++; else named++;

        // A supplied but incorrect name must still fail with actionable asset/name context.
        map.TintMaterial = "__missing_maparea_material__";
        bool failed = false;
        try { using (var renderer = new ProjectY.Samples.MapAreaRenderer(shader, prefab, map, resolve)) { } }
        catch (System.InvalidOperationException exception) {
            failed = exception.Message.Contains(map.AssetPath) && exception.Message.Contains(map.TintMaterial)
                && exception.Message.Contains(prefab.GetComponent<MeshRenderer>().sharedMaterials[0].name);
        }
        check(failed, "Invalid named tint was accepted or lost diagnostics: " + map.AssetId); rejected++;

        // Empty tint must not hide null materials or a mismatched material-slot count.
        map.TintMaterial = "";
        var probe = new GameObject("MapArea material validation", typeof(MeshFilter), typeof(MeshRenderer));
        probe.hideFlags = HideFlags.HideAndDontSave;
        try {
            var mesh = prefab.GetComponent<MeshFilter>().sharedMesh;
            probe.GetComponent<MeshFilter>().sharedMesh = mesh;
            foreach (var slots in new[] { mesh.subMeshCount, mesh.subMeshCount + 1 }) {
                var materials = new Material[slots];
                if (slots != mesh.subMeshCount) for (int slot = 0; slot < slots; slot++) materials[slot] = prefab.GetComponent<MeshRenderer>().sharedMaterials[0];
                probe.GetComponent<MeshRenderer>().sharedMaterials = materials; failed = false;
                try { using (var renderer = new ProjectY.Samples.MapAreaRenderer(shader, probe, map, resolve)) { } }
                catch (System.InvalidOperationException exception) { failed = exception.Message.Contains("材质槽") && exception.Message.Contains(map.AssetPath); }
                check(failed, "Broken material slots accepted: " + map.AssetId); rejected++;
            }
        }
        finally { UnityEngine.Object.DestroyImmediate(probe); }
    }
}
check(named == 3 && optional == 5, "Expected three legacy columns and all five new ecology columns");
check(UnityEngine.SceneManagement.SceneManager.GetActiveScene() == scene && scene.isDirty == dirty, "Validation changed the active scene");
return new { named, optional, rejected, playMode = false };
