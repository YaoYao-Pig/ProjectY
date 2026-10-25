// Targeted native model preview; use in the existing Editor, without Play or scene saves.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.Exception("Edit Mode required");
var original=UnityEngine.SceneManagement.SceneManager.GetActiveScene();var dirty=original.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();var previous=RenderTexture.active;
Camera camera=null;RenderTexture target=null;Texture2D pixels=null;Mesh floorMesh=null;Material floorMaterial=null;
var reports=new System.Collections.Generic.List<object>();
try {
    var host=new GameObject("Giant tree variant comparison");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,scene);
    var cameraObject=new GameObject("Review camera",typeof(Camera));cameraObject.transform.SetParent(host.transform,false);
    camera=cameraObject.GetComponent<Camera>();camera.enabled=false;camera.scene=scene;
    camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic=true;camera.orthographicSize=29;camera.aspect=1.6f;camera.nearClipPlane=.1f;camera.farClipPlane=500;
    camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.16f,.20f,.24f);
    camera.transform.position=new Vector3(0,31,-105);camera.transform.LookAt(new Vector3(0,21,0));
    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    var sunObject=new GameObject("Review sun",typeof(Light));sunObject.transform.SetParent(host.transform,false);
    var sun=sunObject.GetComponent<Light>();sun.type=LightType.Directional;sun.intensity=1.5f;sun.color=new Color(1,.95f,.86f);sun.transform.rotation=Quaternion.Euler(40,-35,0);
    foreach(var entry in new[]{new{Id=1106,Name="WorldTree_Colossal",X=-22f},new{Id=1109,Name="WorldTree_FantasyBough",X=17f}}) {
        var path="Assets/DynamicAsset/MapLowPoly/Models/"+entry.Name+".fbx";
        var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path);
        if(prefab==null)throw new System.Exception("Missing tree model: "+path);
        var instance=UnityEngine.Object.Instantiate(prefab,host.transform);instance.transform.localPosition=new Vector3(entry.X,0,0);
        var filter=prefab.GetComponent<MeshFilter>();var renderer=prefab.GetComponent<MeshRenderer>();
        if(filter==null||renderer==null||prefab.transform.localRotation!=Quaternion.identity||prefab.transform.localScale!=Vector3.one)
            throw new System.Exception("Tree violates root mesh contract: "+entry.Id);
        foreach(var mat in renderer.sharedMaterials)if(mat==null||mat.shader==null||mat.shader.name!="Universal Render Pipeline/Lit")throw new System.Exception("Invalid tree material");
        var mesh=filter.sharedMesh;int outside=0;float maxRadius=0;
        foreach(var v in mesh.vertices) {
            float q=Mathf.Sqrt(3)/3*v.x-v.z/3,r=2f/3*v.z,s=-q-r;
            int iq=Mathf.FloorToInt(q+.5f),ir=Mathf.FloorToInt(r+.5f),iz=Mathf.FloorToInt(s+.5f);
            float dq=Mathf.Abs(iq-q),dr=Mathf.Abs(ir-r),ds=Mathf.Abs(iz-s);
            if(dq>dr&&dq>ds)iq=-ir-iz;else if(dr>ds)ir=-iq-iz;
            int distance=(Mathf.Abs(iq)+Mathf.Abs(ir)+Mathf.Abs(iq+ir))/2;
            if(distance>9)outside++;maxRadius=Mathf.Max(maxRadius,new Vector2(v.x,v.z).magnitude);
        }
        // The original model is explicitly retained as authored. Enforce the new asset's full footprint;
        // report existing canopy overhang separately instead of silently modifying the retained variant.
        if(entry.Id==1109&&outside>0)throw new System.Exception("New tree extends outside reserved 271-cell footprint: "+outside);
        reports.Add(new{id=entry.Id,path,vertices=mesh.vertexCount,triangles=mesh.triangles.Length/3,
            size=new[]{mesh.bounds.size.x,mesh.bounds.size.y,mesh.bounds.size.z},maxRadius,outside});
        foreach(var reference in new[]{"Building_House","Tree_Broadleaf"}) {
            var source=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/MapLowPoly/Models/"+reference+".fbx");
            if(source==null)throw new System.Exception("Missing scale reference: "+reference);
            var item=UnityEngine.Object.Instantiate(source,host.transform);item.transform.localPosition=new Vector3(entry.X+(reference=="Building_House"?-4:4),0,-7);
        }
    }
    var floor=new GameObject("Review ground",typeof(MeshFilter),typeof(MeshRenderer));floor.transform.SetParent(host.transform,false);
    floorMesh=new Mesh();floorMesh.vertices=new[]{new Vector3(-50,-.05f,-20),new Vector3(50,-.05f,-20),new Vector3(50,-.05f,25),new Vector3(-50,-.05f,25)};
    floorMesh.triangles=new[]{0,2,1,0,3,2};floorMesh.RecalculateNormals();floorMesh.RecalculateBounds();floor.GetComponent<MeshFilter>().sharedMesh=floorMesh;
    floorMaterial=new Material(UnityEditor.AssetDatabase.LoadAssetAtPath<Material>("Assets/DynamicAsset/MapLowPoly/Materials/M_MapLP_Grass.mat"));
    floorMaterial.color=new Color(.29f,.34f,.26f);floor.GetComponent<MeshRenderer>().sharedMaterial=floorMaterial;
    target=new RenderTexture(1600,1000,24,RenderTextureFormat.ARGB32,RenderTextureReadWrite.sRGB);target.Create();camera.targetTexture=target;
    ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;pixels=new Texture2D(1600,1000,TextureFormat.RGB24,false);
    pixels.ReadPixels(new Rect(0,0,1600,1000),0,0);pixels.Apply();int pink=0;
    foreach(var c in pixels.GetPixels32())if(c.r>230&&c.b>230&&c.g<30)pink++;
    if(pink>0)throw new System.Exception("Missing material in tree variant preview");
    var output="Docs/Previews/TerrainWonders/giant-tree-variants-unity.png";System.IO.File.WriteAllBytes(output,pixels.EncodeToPNG());
    return new{reports,output,playMode=false};
} finally {
    if(camera!=null)camera.targetTexture=null;RenderTexture.active=previous;
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if(floorMesh!=null)UnityEngine.Object.DestroyImmediate(floorMesh);if(floorMaterial!=null)UnityEngine.Object.DestroyImmediate(floorMaterial);
    if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=original||original.isDirty!=dirty)throw new System.Exception("Variant preview modified active scene");
}
