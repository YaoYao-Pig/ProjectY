// Compare authored and automatically fitted helmets using the same real character and camera.
var catalog=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Samples.PawnCustomizationCatalog>(ProjectY.Editor.PawnCustomizationAssets.CatalogPath);
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();UnityEngine.Texture2D sheet=null;
var capture=typeof(ProjectY.Editor.PawnCustomizationValidation).GetMethod("Capture",System.Reflection.BindingFlags.Static|System.Reflection.BindingFlags.NonPublic);
try
{
    var pawn=UnityEngine.Object.Instantiate(UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab"));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(pawn,scene);
    var view=pawn.GetComponentInChildren<ProjectY.Samples.PawnCustomizationView>(true);view.gameObject.SetActive(true);
    var animator=view.GetComponent<UnityEngine.Animator>();var settings=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Samples.PawnAnimationSet>(ProjectY.Editor.PawnAnimationAssets.SetPath);animator.runtimeAnimatorController=settings.Controller;animator.applyRootMotion=false;animator.enabled=false;
    var c=new UnityEngine.GameObject("FitCamera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(c,scene);var camera=c.AddComponent<UnityEngine.Camera>();camera.scene=scene;camera.orthographic=true;camera.orthographicSize=.33f;camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.16f,.19f,.20f);
    foreach(var angles in new[]{new UnityEngine.Vector3(30,-25,0),new UnityEngine.Vector3(25,150,0)}){var go=new UnityEngine.GameObject("FitLight");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(go,scene);var l=go.AddComponent<UnityEngine.Light>();l.type=UnityEngine.LightType.Directional;l.intensity=angles.y<0?1.2f:.7f;go.transform.rotation=UnityEngine.Quaternion.Euler(angles);}
    int width=500,height=560;sheet=new UnityEngine.Texture2D(width*2,height*2,UnityEngine.TextureFormat.RGB24,false);
    var ids=new[]{"head_human_female_sculpt_00","head_goblin_female_sculpt_00"};
    for(int row=0;row<2;row++)
    {
        var module=System.Array.Find(catalog.Rules.modules,m=>m.id==ids[row]);var value=catalog.Rules.Randomize(42,module.race,module.sex);value.head=module.id;value.body="body_female_1";value.hair="none";value.skin=0;view.Apply(value);animator.Rebind();animator.Play("Idle",0,.2f);animator.Update(0);
        var temp=new UnityEngine.Mesh();view.Modules[1].BakeMesh(temp);var center=view.Modules[1].transform.TransformPoint(temp.bounds.center);UnityEngine.Object.DestroyImmediate(temp);camera.transform.position=center+new UnityEngine.Vector3(.25f,.03f,.95f);camera.transform.LookAt(center);
        string path="Assets/DynamicAsset/PawnLowPoly/Models/Pawn_Helmet.fbx";var authored=catalog.Fit(path,value).Part.Mesh;var obj=view.CreateFit(path);var renderer=obj.GetComponent<UnityEngine.SkinnedMeshRenderer>();var fitted=renderer.sharedMesh;
        for(int column=0;column<2;column++)
        {
            renderer.sharedMesh=column==0?authored:fitted;
            var image=(UnityEngine.Texture2D)capture.Invoke(null,new object[]{camera,view,width,height});sheet.SetPixels(column*width,(1-row)*height,width,height,image.GetPixels());UnityEngine.Object.DestroyImmediate(image);
        }
        ProjectY.Samples.WeaponModelView.Remove(obj);
    }
    sheet.Apply();System.IO.File.WriteAllBytes("Art/HeadSculptExpansion202610/Previews/unity-autofit-before-after.png",sheet.EncodeToPNG());return "Left authored; right auto-fit. Human and goblin female heads.";
}
finally{if(sheet!=null)UnityEngine.Object.DestroyImmediate(sheet);UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
