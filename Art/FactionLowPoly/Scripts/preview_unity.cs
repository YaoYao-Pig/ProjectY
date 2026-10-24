// One disposable PreviewScene, no gameplay, script Refresh, or changes to AdventureDemo.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var names=new[]{"Faction_OrcStockade","Faction_GoblinCamp","Faction_ElfGrove","WorldParty_Orcs","WorldParty_Caravan","Building_House"};
var labels=new[]{"ORC STOCKADE","GOBLIN CAMP","WOOD ELF GROVE","ORC PARTY / SCALE","CARAVAN / SCALE","HUMAN TOWN / SCALE"};
var font=UnityEditor.AssetDatabase.LoadAssetAtPath<Font>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc-Regular.otf");
try
{
    for(int i=0;i<names.Length;i++)
    {
        var position=new Vector3((i%3-1)*3f,0,i<3?2.9f:-.6f);
        string folder=i<3?"FactionLowPoly":(i<5?"WorldPartyLowPoly":"MapLowPoly");
        string path="Assets/DynamicAsset/"+folder+"/Models/"+names[i]+".fbx";
        var model=(GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path),scene);
        model.transform.position=position;model.transform.rotation=Quaternion.Euler(0,155,0);
        string tileName=i==2?"Hex_Forest":"Hex_Grass";
        var tile=(GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/MapLowPoly/Models/"+tileName+".fbx"),scene);
        tile.transform.position=position;tile.transform.localScale=new Vector3(1,.12f,1);
        var label=new GameObject(labels[i],typeof(TextMesh));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(label,scene);
        var text=label.GetComponent<TextMesh>();text.text=labels[i];text.font=font;text.fontSize=60;text.characterSize=.026f;text.anchor=TextAnchor.MiddleCenter;text.color=new Color(.92f,.88f,.75f);
        label.GetComponent<MeshRenderer>().sharedMaterial=font.material;label.transform.position=position+new Vector3(0,.025f,-1.25f);label.transform.rotation=Quaternion.Euler(44,0,0);
    }
    var lightObject=new GameObject("FactionPreviewSun",typeof(Light));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(lightObject,scene);
    var light=lightObject.GetComponent<Light>();light.type=LightType.Directional;light.intensity=1.3f;light.color=new Color(1,.96f,.88f);lightObject.transform.rotation=Quaternion.Euler(48,-35,0);
    var cameraObject=new GameObject("FactionPreviewCamera",typeof(Camera));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
    var camera=cameraObject.GetComponent<Camera>();camera.scene=scene;camera.enabled=false;camera.orthographic=true;camera.orthographicSize=4.25f;
    camera.backgroundColor=new Color(.10f,.14f,.15f);camera.clearFlags=CameraClearFlags.SolidColor;camera.nearClipPlane=.1f;camera.farClipPlane=100;
    var rotation=Quaternion.Euler(44,0,0);camera.transform.SetPositionAndRotation(new Vector3(0,.75f,1.2f)-rotation*Vector3.forward*30,rotation);
    var texture=new RenderTexture(1440,1000,24,RenderTextureFormat.ARGB32);texture.antiAliasing=4;texture.Create();
    var previous=RenderTexture.active;var image=new Texture2D(1440,1000,TextureFormat.RGB24,false);
    try
    {
        camera.targetTexture=texture;ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=texture;
        image.ReadPixels(new Rect(0,0,1440,1000),0,0);image.Apply();
        string path=System.IO.Path.GetFullPath("Art/FactionLowPoly/Previews/faction-sites-unity.png");System.IO.File.WriteAllBytes(path,image.EncodeToPNG());return path;
    }
    finally{camera.targetTexture=null;RenderTexture.active=previous;texture.Release();UnityEngine.Object.DestroyImmediate(texture);UnityEngine.Object.DestroyImmediate(image);}
}
finally{UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
