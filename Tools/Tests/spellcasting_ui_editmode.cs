// Targeted native resource/mesh validation. Run after apply_spellcasting_ui.cs; no Play or scene edits.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool originalDirty=originalScene.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();int cases=0;
try
{
    var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/UI/Prefabs/MainHud/HudHealthWidget.prefab");
    var root=UnityEngine.Object.Instantiate(prefab);UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();reference.ValidateBindings();
    var ring=(ProjectY.UI.CastingPointRing)reference.Get("CastingPoints");
    if(ring.GetComponent<CanvasRenderer>()==null)throw new System.Exception("Casting point Graphic needs a saved CanvasRenderer");
    var effects=reference.Get("EffectSlots").GetComponent<ProjectY.UI.ArcLayoutGroup>();
    var populate=typeof(ProjectY.UI.CastingPointRing).GetMethod("OnPopulateMesh",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance,null,new[]{typeof(UnityEngine.UI.VertexHelper)},null);
    var inner=typeof(ProjectY.UI.ArcLayoutGroup).GetField("innerSpacing",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance);
    foreach(int maximum in new[]{0,6,12,13,24,25,48})
    foreach(int available in new[]{0,maximum/2,maximum})
    {
        ProjectY.UI.SpellcastingPresentation.SetPoints(ring,available,maximum);
        if(ring.gameObject.activeSelf!=(maximum>0))throw new System.Exception("Non-caster visibility incorrect");
        using(var mesh=new UnityEngine.UI.VertexHelper())
        {
            populate.Invoke(ring,new object[]{mesh});
            if(mesh.currentVertCount!=maximum*8+available*4)throw new System.Exception("Incorrect available/spent point mesh");
            var vertex=new UnityEngine.UIVertex();
            for(int i=0;i<mesh.currentVertCount;i++)
            {
                mesh.PopulateUIVertex(ref vertex,i);
                if(float.IsNaN(vertex.position.x)||float.IsNaN(vertex.position.y))throw new System.Exception("Invalid point position");
            }
        }
        int rows=(maximum+11)/12;
        if((float)inner.GetValue(effects)!=UnityEngine.Mathf.Max(0,rows-2)*14)throw new System.Exception("Buff arc must follow wrapped casting rows");
        cases++;
    }
    if(ring.raycastTarget)throw new System.Exception("Resource points may not intercept world selection");
    ProjectY.UI.SpellcastingPresentation.SetPoints(ring,0,0);
    if((float)inner.GetValue(effects)!=0)throw new System.Exception("Reusing a non-caster must restore the status arc");
    var hudPrefab=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/UI/Prefabs/Battle/BattleHUDPanel.prefab");
    var hudRoot=UnityEngine.Object.Instantiate(hudPrefab);UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(hudRoot,scene);
    var hudReference=hudRoot.GetComponent<ProjectY.UI.LuaReference>();hudReference.ValidateBindings();
    var hud=(ProjectY.UI.BattleHUDView)hudReference.Get("HUD");hud.Prepare();
    foreach(string key in new[]{"CastingPanel","CastingStatus","CastingDetail","CastingLess","CastingMore","CastingLessText","CastingMoreText"})
        if(hudReference.Get(key)==null)throw new System.Exception("Missing casting binding: "+key);
    if(hud.EditorLayout.Casting!=(UnityEngine.RectTransform)hudReference.Get("CastingPanel"))throw new System.Exception("Casting layout ownership mismatch");
    var main=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab");
    var nested=main.GetComponent<ProjectY.UI.LuaReference>().GetReference("BattleContent");
    if(nested.Get("CastingPanel")==null)throw new System.Exception("Nested battle HUD did not inherit casting controls");
}
finally{UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene || originalScene.isDirty!=originalDirty)
    throw new System.Exception("Casting UI validation changed the user's scene");
return new{passed=true,pointMeshCases=cases,nativeBindings=true,sceneUnchanged=true,playMode=false};
