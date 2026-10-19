if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.Exception("Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var names=new[]{"Flag","Caravan","Bandits","Goblins","Orcs","Direwolves","Stonebeast","House"};
var labels=new[]{"PLAYER","CARAVAN","BANDITS","GOBLINS","ORCS","DIREWOLF","STONE BEAST","TOWN / SCALE"};
var font=UnityEditor.AssetDatabase.LoadAssetAtPath<Font>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc-Regular.otf");
try
{
    for(int i=0;i<names.Length;i++)
    {
        var position=new Vector3((i%4-1.5f)*2.8f,0,(i/4)*3.4f);
        string path=i==7?"Assets/DynamicAsset/MapLowPoly/Models/Building_House.fbx":"Assets/DynamicAsset/WorldPartyLowPoly/Models/WorldParty_"+names[i]+".fbx";
        var model=(GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path),scene);
        model.transform.position=position;model.transform.rotation=Quaternion.Euler(0,180,0);
        var tile=(GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/MapLowPoly/Models/Hex_Grass.fbx"),scene);
        tile.transform.position=position;tile.transform.localScale=new Vector3(1,.12f,1);
        var label=new GameObject(labels[i],typeof(TextMesh));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(label,scene);
        var text=label.GetComponent<TextMesh>();text.text=labels[i];text.font=font;text.fontSize=60;text.characterSize=.032f;text.anchor=TextAnchor.MiddleCenter;text.color=new Color(.92f,.88f,.75f);
        label.GetComponent<MeshRenderer>().sharedMaterial=font.material;label.transform.position=position+new Vector3(0,.05f,-1.2f);label.transform.rotation=Quaternion.Euler(47,0,0);
    }
    var lightObject=new GameObject("Sun",typeof(Light));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(lightObject,scene);
    var light=lightObject.GetComponent<Light>();light.type=LightType.Directional;light.intensity=1.25f;light.color=new Color(1,.96f,.88f);lightObject.transform.rotation=Quaternion.Euler(48,-35,0);
    var cameraObject=new GameObject("Camera",typeof(Camera));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
    var camera=cameraObject.GetComponent<Camera>();camera.scene=scene;camera.enabled=false;camera.orthographic=true;camera.orthographicSize=4.7f;
    camera.backgroundColor=new Color(.10f,.14f,.15f);camera.clearFlags=CameraClearFlags.SolidColor;camera.nearClipPlane=.1f;camera.farClipPlane=100;
    var rotation=Quaternion.Euler(47,0,0);camera.transform.SetPositionAndRotation(new Vector3(0,.6f,1.5f)-rotation*Vector3.forward*30,rotation);
    var texture=new RenderTexture(1440,900,24,RenderTextureFormat.ARGB32);texture.antiAliasing=4;texture.Create();
    var previous=RenderTexture.active;var image=new Texture2D(1440,900,TextureFormat.RGB24,false);
    try
    {
        camera.targetTexture=texture;ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=texture;
        image.ReadPixels(new Rect(0,0,1440,900),0,0);image.Apply();
        string path=System.IO.Path.GetFullPath("Art/WorldPartyLowPoly/Previews/world-parties-unity.png");System.IO.File.WriteAllBytes(path,image.EncodeToPNG());return path;
    }
    finally{camera.targetTexture=null;RenderTexture.active=previous;texture.Release();UnityEngine.Object.DestroyImmediate(texture);UnityEngine.Object.DestroyImmediate(image);}
}
finally{UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
