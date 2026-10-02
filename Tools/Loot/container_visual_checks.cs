// Real renderer and authored assets, isolated preview scene; no active scene or prefab changes.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("ContainerVisualCheck");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var cameraObject=new GameObject("ContainerPreviewCamera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;camera.orthographic=true;camera.orthographicSize=5.3f;
camera.transform.position=new Vector3(9,13,-16);camera.transform.LookAt(new Vector3(0,.6f,0));camera.nearClipPlane=.01f;camera.farClipPlane=80;
camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.075f,.095f,.12f);ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var lightObject=new GameObject("ContainerPreviewSun");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(lightObject,scene);
var light=lightObject.AddComponent<Light>();light.type=LightType.Directional;light.intensity=2;light.transform.rotation=Quaternion.Euler(48,-35,0);
var target=new RenderTexture(1440,900,24,RenderTextureFormat.ARGB32);target.Create();camera.targetTexture=target;var previous=RenderTexture.active;
var catalog=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Samples.EquipmentAssetCatalog>(ProjectY.Editor.EquipmentAssets.CatalogPath);
ProjectY.Samples.AreaLootRenderer renderer=null;
try
{
    var layout=new ProjectY.Samples.MapAreaViewData();layout.Cells=new ProjectY.Samples.MapAreaViewData.Cell[8];
    var state=new ProjectY.Samples.MapAreaViewData.State();state.Loots=new ProjectY.Samples.MapAreaViewData.Loot[8];
    using(var lua=new XLua.LuaEnv())
    {
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);var services=new ProjectY.FrameworkServices(null);lua.Global.Set("Services",services);
        string script="local c=require('Config.ConfigSystem')();c:OnInit({services=Services});local assets=c:GetTable('EquipmentAssetTable');local result={};for _,id in ipairs({200,201,202,203,204,205,206,207}) do local row=c:GetTable('EquipmentLootTable'):Get(id);local item=c:GetTable('EquipmentItemTable'):Get(id==205 and 40 or 31);result[#result+1]={id=id,name=row.name,assetId=row.assetId,path=assets:Get(row.assetId).prefabPath,scale=row.modelScale,hp=row.maxDurability,display=row.displayContents,height=row.displayHeight,itemScale=row.displayItemScale,itemAsset=item.assetId,itemPath=assets:Get(item.assetId).prefabPath};end;return result";
        using(var rows=(XLua.LuaTable)lua.DoString(script)[0])for(int i=0;i<8;i++)using(var row=rows.Get<int,XLua.LuaTable>(i+1))
        {
            var position=new Vector3((i%4-1.5f)*3.8f,0,i<4?1.9f:-2.2f);layout.Cells[i]=new ProjectY.Samples.MapAreaViewData.Cell {Position=position};
            var loot=new ProjectY.Samples.MapAreaViewData.Loot {Id=i+1,CellIndex=i,Cells=new[]{i},Name=row.Get<string>("name"),Durability=row.Get<int>("hp"),MaxDurability=row.Get<int>("hp"),Scale=row.Get<float>("scale"),Scale3=Vector3.one*row.Get<float>("scale"),Height=0,Rotation=0,DisplayContents=row.Get<string>("display"),DisplayHeight=row.Get<float>("height"),DisplayItemScale=row.Get<float>("itemScale"),Asset=new ProjectY.Samples.EquipmentVisualData.Asset {Id=row.Get<int>("assetId"),Path=row.Get<string>("path")},Items=new ProjectY.Samples.MapAreaViewData.DisplayItem[0]};
            if(loot.DisplayContents!="none")loot.Items=new[]{new ProjectY.Samples.MapAreaViewData.DisplayItem {Index=0,Asset=new ProjectY.Samples.EquipmentVisualData.Asset {Id=row.Get<int>("itemAsset"),Path=row.Get<string>("itemPath")}}};
            state.Loots[i]=loot;
        }
    }
    renderer=new ProjectY.Samples.AreaLootRenderer(root.transform,catalog);renderer.Apply(state,layout);
    foreach(var item in root.GetComponentsInChildren<Renderer>())foreach(var material in item.sharedMaterials)
        if(material==null || material.shader.name=="Hidden/InternalErrorShader")throw new System.Exception("Invalid container material");
    if(renderer.Pick(new Ray(layout.Cells[0].Position+Vector3.up*5,Vector3.down))!=1)throw new System.Exception("Container mesh picking failed");
    System.Action<string> capture=name=>{
        ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;var image=new Texture2D(target.width,target.height,TextureFormat.RGBA32,false);
        try{image.ReadPixels(new Rect(0,0,target.width,target.height),0,0);image.Apply();System.IO.Directory.CreateDirectory("Docs/Previews/Loot");System.IO.File.WriteAllBytes("Docs/Previews/Loot/"+name+".png",image.EncodeToPNG());}
        finally{UnityEngine.Object.DestroyImmediate(image);RenderTexture.active=previous;}
    };
    capture("containers-full");
    int before=root.GetComponentsInChildren<Renderer>().Length;
    state.Loots[5].Items=new ProjectY.Samples.MapAreaViewData.DisplayItem[0];state.Loots[6].Items=new ProjectY.Samples.MapAreaViewData.DisplayItem[0];
    renderer.Apply(state,layout);
    if(root.GetComponentsInChildren<Renderer>().Length>=before)throw new System.Exception("Taken display items remain visible");
    capture("containers-empty");
    return "PASS eight configured container models, original materials, model picking, inventory display and removal; preview images saved under Docs/Previews/Loot/.";
}
finally
{
    if(renderer!=null)renderer.Dispose();camera.targetTexture=null;RenderTexture.active=previous;target.Release();UnityEngine.Object.DestroyImmediate(target);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
