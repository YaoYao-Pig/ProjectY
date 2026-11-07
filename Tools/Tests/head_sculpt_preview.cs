// Actual Unity rendering of the five new painted heads; no Play or active-scene writes.
var catalog=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Samples.PawnCustomizationCatalog>(ProjectY.Editor.PawnCustomizationAssets.CatalogPath);
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var active=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=active.isDirty;
var capture=typeof(ProjectY.Editor.PawnCustomizationValidation).GetMethod("Capture",System.Reflection.BindingFlags.Static|System.Reflection.BindingFlags.NonPublic);
UnityEngine.Texture2D sheet=null;
try
{
    var pawn=UnityEngine.Object.Instantiate(UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab"));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(pawn,scene);
    var view=pawn.GetComponentInChildren<ProjectY.Samples.PawnCustomizationView>(true);view.gameObject.SetActive(true);
    var animator=view.GetComponent<UnityEngine.Animator>();var settings=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Samples.PawnAnimationSet>(ProjectY.Editor.PawnAnimationAssets.SetPath);
    animator.runtimeAnimatorController=settings.Controller;animator.applyRootMotion=false;animator.cullingMode=UnityEngine.AnimatorCullingMode.AlwaysAnimate;animator.enabled=false;
    var cameraObject=new UnityEngine.GameObject("HeadPortraitCamera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);var camera=cameraObject.AddComponent<UnityEngine.Camera>();camera.scene=scene;camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.16f,.19f,.20f);camera.orthographic=true;camera.orthographicSize=.30f;
    foreach(var angles in new[]{new UnityEngine.Vector3(30,-25,0),new UnityEngine.Vector3(25,150,0)}){var go=new UnityEngine.GameObject("HeadPortraitLight");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(go,scene);var light=go.AddComponent<UnityEngine.Light>();light.type=UnityEngine.LightType.Directional;light.intensity=angles.y<0?1.2f:.7f;go.transform.rotation=UnityEngine.Quaternion.Euler(angles);}
    string[] ids={"head_human_male_sculpt_03","head_human_male_sculpt_04","head_human_female_sculpt_00","head_human_female_sculpt_01","head_goblin_female_sculpt_00"};
    int width=440,height=560;sheet=new UnityEngine.Texture2D(width*5,height,UnityEngine.TextureFormat.RGB24,false);
    for(int i=0;i<ids.Length;i++)
    {
        var module=System.Array.Find(catalog.Rules.modules,m=>m.id==ids[i]);var value=catalog.Rules.Randomize(42,module.race,module.sex);value.head=module.id;value.body="body_"+module.sex+"_1";value.hair=module.race=="goblin"?"none":(module.sex=="female"?"hair_2":"hair_1");value.skin=0;value.hairColor=0;view.Apply(value);
        animator.Rebind();animator.Play("Idle",0,.2f);animator.Update(0);
        var temp=new UnityEngine.Mesh();view.Modules[1].BakeMesh(temp);var center=view.Modules[1].transform.TransformPoint(temp.bounds.center);UnityEngine.Object.DestroyImmediate(temp);
        camera.transform.position=center+new UnityEngine.Vector3(.22f,.025f,.9f);camera.transform.LookAt(center);
        var image=(UnityEngine.Texture2D)capture.Invoke(null,new object[]{camera,view,width,height});sheet.SetPixels(i*width,0,width,height,image.GetPixels());System.IO.File.WriteAllBytes("Art/HeadSculptExpansion202610/Previews/unity-"+ids[i]+".png",image.EncodeToPNG());UnityEngine.Object.DestroyImmediate(image);
    }
    sheet.Apply();System.IO.File.WriteAllBytes("Art/HeadSculptExpansion202610/Previews/unity-five-new-heads.png",sheet.EncodeToPNG());
    if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=active||active.isDirty!=dirty)throw new System.Exception("Preview modified the active scene");
    return "Rendered five actual Unity head variants.";
}
finally{if(sheet!=null)UnityEngine.Object.DestroyImmediate(sheet);UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
