// Unity MCP execute_code method body. Run only after the requested project compilation.
// Independent PreviewScene, real configured FBX/materials and native HUD/fog; no Play or scene/save writes.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();var originalDirty=originalScene.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();var previousTarget=RenderTexture.active;
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.Public|System.Reflection.BindingFlags.NonPublic;
System.Action<bool,string> check=(ok,message)=>{if(!ok)throw new System.Exception(message);};
System.Func<object,string,object> field=(owner,name)=>{
    var member=owner.GetType().GetField(name,flags);check(member!=null,"Missing inspection field: "+name);return member.GetValue(owner);
};
System.Func<object,string,object[],object> call=(owner,name,args)=>{
    var method=owner.GetType().GetMethod(name,flags);check(method!=null,"Missing test API: "+name);
    try{return method.Invoke(owner,args);}catch(System.Reflection.TargetInvocationException error){throw error.InnerException??error;}
};
ProjectY.Samples.MapPreviewRenderer renderer=null;System.IDisposable siteView=null;
Camera camera=null;RenderTexture target=null;Texture2D pixels=null;
var errors=new System.Collections.Generic.List<string>();
Application.LogCallback log=(message,trace,type)=>{if(type==LogType.Error||type==LogType.Exception)errors.Add(message);};
Application.logMessageReceived+=log;
try
{
    var host=new GameObject("Giant tree site picking checks");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,scene);
    var cameraObject=new GameObject("Check camera",typeof(Camera));cameraObject.transform.SetParent(host.transform,false);
    camera=cameraObject.GetComponent<Camera>();camera.enabled=false;camera.scene=scene;
    camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic=true;camera.orthographicSize=30;camera.aspect=1.6f;camera.nearClipPlane=.1f;camera.farClipPlane=400;
    camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.12f,.17f,.21f);
    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    var lightObject=new GameObject("Check sun",typeof(Light));lightObject.transform.SetParent(host.transform,false);
    var sun=lightObject.GetComponent<Light>();sun.type=LightType.Directional;sun.intensity=1.6f;sun.color=new Color(1,.95f,.88f);
    sun.transform.rotation=Quaternion.Euler(45,-35,0);
    target=new RenderTexture(1440,900,24,RenderTextureFormat.ARGB32,RenderTextureReadWrite.sRGB);target.Create();camera.targetTexture=target;

    var assetRows=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Map/MapAssetTable.json"))["rows"].ToDictionary(row=>(int)row["id"]);
    var biomeRows=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Map/MapBiomeTable.json"))["rows"].ToDictionary(row=>(int)row["id"]);
    System.Func<int,ProjectY.Samples.MapPreviewData.Asset> asset=id=>{
        var row=assetRows[id];return new ProjectY.Samples.MapPreviewData.Asset{Id=id,Path=(string)row["prefabPath"],
            TintMaterial=(string)row["tintMaterial"],ReferenceHeight=(float)row["referenceHeight"]};
    };
    var map=new ProjectY.Samples.MapPreviewData{Radius=1,RegionCount=2,GenerationVersion=8,Seed=426,
        Towns=System.Array.Empty<ProjectY.Samples.MapPreviewData.Town>(),Buildings=System.Array.Empty<ProjectY.Samples.MapPreviewData.Building>(),
        Roads=System.Array.Empty<ProjectY.Samples.MapPreviewData.Road>(),Waterfalls=System.Array.Empty<ProjectY.Samples.MapPreviewData.Waterfall>(),
        Groundcover=System.Array.Empty<ProjectY.Samples.MapPreviewData.Cover>(),Clouds=System.Array.Empty<ProjectY.Samples.MapPreviewData.Cloud>()};
    map.Assets=new[]{1106,1109,(int)biomeRows[1]["terrainAssetId"],(int)biomeRows[5]["terrainAssetId"]}.Distinct().Select(asset).ToArray();
    map.Surfaces=biomeRows.Values.Select(row=>{
        Color color;check(ColorUtility.TryParseHtmlString((string)row["groundColor"],out color),"Invalid configured biome color");
        return new ProjectY.Samples.MapPreviewData.Surface{Id=(int)row["id"],Color=color,GroundTexture=(string)row["groundTexture"],
            TextureWorldSize=(float)row["textureWorldSize"],TextureStrength=(float)row["textureStrength"],
            WindStrength=(float)row["windStrength"],CliffTintStrength=(float?)row["cliffTintStrength"]??0};
    }).ToArray();
    var surfaces=map.Surfaces.ToDictionary(value=>value.Id);
    var cells=new System.Collections.Generic.List<ProjectY.Samples.MapPreviewData.Cell>();
    var indices=new System.Collections.Generic.Dictionary<Vector2Int,int>();
    // The outer ordinary ground makes model-versus-ground hit distances finite. Only radius 9 is the wonder.
    for(int q=-20;q<=20;q++)for(int r=Mathf.Max(-20,-q-20);r<=Mathf.Min(20,-q+20);r++)
    {
        int distance=(Mathf.Abs(q)+Mathf.Abs(r)+Mathf.Abs(q+r))/2;int biome=q<0?1:5;
        indices.Add(new Vector2Int(q,r),cells.Count);
        cells.Add(new ProjectY.Samples.MapPreviewData.Cell{Q=q,R=r,RegionId=q<0?1:2,WonderId=distance<=9?1:0,
            Position=new Vector3(Mathf.Sqrt(3)*(q+r*.5f),0,r*1.5f),Color=surfaces[biome].Color,
            TerrainAssetId=(int)biomeRows[biome]["terrainAssetId"],SurfaceA=biome,SurfaceB=biome});
    }
    map.Cells=cells.ToArray();var cellIdentity=map.Cells;
    var directions=new[]{new Vector2Int(1,0),new Vector2Int(1,-1),new Vector2Int(0,-1),new Vector2Int(-1,0),new Vector2Int(-1,1),new Vector2Int(0,1)};
    foreach(var cell in map.Cells)
    {
        var neighbors=new System.Collections.Generic.List<int>();
        foreach(var direction in directions)if(indices.TryGetValue(new Vector2Int(cell.Q,cell.R)+direction,out var index))neighbors.Add(index);
        cell.Neighbors=neighbors.ToArray();
    }
    int center=indices[new Vector2Int(0,0)],entrance=indices[new Vector2Int(0,10)];
    int farRoot=indices[new Vector2Int(-9,0)],otherRoot=indices[new Vector2Int(9,0)],outside=indices[new Vector2Int(18,0)];
    check(map.Cells.Count(cell=>cell.WonderId==1)==271 && map.Cells[farRoot].RegionId!=map.Cells[otherRoot].RegionId,"Fixture must cross two regions with 271 root cells");
    check(map.Cells[entrance].WonderId==0 && map.Cells[outside].RegionId==map.Cells[center].RegionId,"Fixture requires an external entrance and same-region ordinary ground");
    map.Decorations=new[]{new ProjectY.Samples.MapPreviewData.Decoration{Cell=center,AssetId=1106,Wonder=true,Scale=1,Yaw=0,Height=0}};
    var wonderName=(string)Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Map/MapWonderTable.json"))["rows"][0]["name"];
    var treeSite=new ProjectY.Samples.AdventureViewData.Site{Id=77,AreaConfigId=72,WorldWonderId=1,WorldRegionId=2,Q=0,R=10,
        Name=wonderName,Position=map.Cells[entrance].Position,Available=true};
    var ordinarySite=new ProjectY.Samples.AdventureViewData.Site{Id=88,Q=18,R=0,Name="范围外测试点",Position=map.Cells[outside].Position,Available=true};

    // Native HUD and UIFollower bindings match the world-sites test, including the current MapHud toggle.
    var canvasObject=new GameObject("Check HUD",typeof(RectTransform),typeof(Canvas),typeof(ProjectY.UI.MainHudView));canvasObject.transform.SetParent(host.transform,false);
    var canvas=canvasObject.GetComponent<Canvas>();canvas.renderMode=RenderMode.ScreenSpaceOverlay;
    var rootReference=canvasObject.AddComponent<ProjectY.UI.LuaReference>();
    var toggleObject=new GameObject("SiteTags",typeof(RectTransform),typeof(UnityEngine.UI.Toggle));toggleObject.transform.SetParent(canvasObject.transform,false);
    var siteTags=toggleObject.GetComponent<UnityEngine.UI.Toggle>();siteTags.isOn=false;
    var mapHudObject=new GameObject("MapHud",typeof(RectTransform),typeof(ProjectY.UI.LuaReference));mapHudObject.transform.SetParent(canvasObject.transform,false);
    var mapToggleObject=new GameObject("MapSiteTags",typeof(RectTransform),typeof(UnityEngine.UI.Toggle));mapToggleObject.transform.SetParent(mapHudObject.transform,false);
    var mapTags=mapToggleObject.GetComponent<UnityEngine.UI.Toggle>();mapTags.isOn=false;
    var mapHud=mapHudObject.GetComponent<ProjectY.UI.LuaReference>();mapHud.SetEditorBindings(new ProjectY.UI.LuaReference.Entry("SiteTags",mapTags));
    rootReference.SetEditorBindings(new ProjectY.UI.LuaReference.Entry("SiteTags",siteTags),new ProjectY.UI.LuaReference.Entry("MapHud",mapHud));
    var hud=canvasObject.GetComponent<ProjectY.UI.MainHudView>();hud.enabled=false;
    hud.SetEditorBindings(new ProjectY.UI.MainHudView.Layout{Root=(RectTransform)canvas.transform,Canvas=canvas,Labels=System.Array.Empty<UnityEngine.UI.Text>()});
    var viewType=typeof(ProjectY.Samples.AdventureRuntimeDemo).Assembly.GetType("ProjectY.Samples.WorldSiteView",true);
    var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
    renderer=new ProjectY.Samples.MapPreviewRenderer(shader,host.transform);
    System.Action sync=()=>call(siteView,"Sync",new object[]{new[]{treeSite,ordinarySite}});
    System.Action rebuild=()=>{
        siteView?.Dispose();siteView=null;
        renderer.Build(map,entry=>UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(entry.Path));
        siteView=(System.IDisposable)System.Activator.CreateInstance(viewType,flags,null,new object[]{hud,map,renderer},null);
        sync();Canvas.ForceUpdateCanvases();
    };
    System.Func<Ray,System.Tuple<bool,int,float>> wonderPick=ray=>{
        var args=new object[]{ray,-1,float.PositiveInfinity};var hit=(bool)call(renderer,"PickWonder",args);
        return System.Tuple.Create(hit,(int)args[1],(float)args[2]);
    };
    System.Func<Ray,System.Tuple<int,float>> groundPick=ray=>{
        var args=new object[]{ray,float.PositiveInfinity};var hit=(int)call(field(siteView,"layout"),"Pick",args);
        return System.Tuple.Create(hit,(float)args[1]);
    };
    System.Func<Vector3,Ray> aim=point=>{
        camera.orthographicSize=30;camera.transform.position=point+new Vector3(0,95,-60);camera.transform.LookAt(point);
        return camera.ScreenPointToRay((Vector2)camera.WorldToScreenPoint(point));
    };
    System.Func<Vector3,Ray> aimDown=point=>{
        camera.orthographicSize=24;camera.transform.SetPositionAndRotation(point+Vector3.up*100,Quaternion.LookRotation(Vector3.down,Vector3.forward));
        return camera.ScreenPointToRay((Vector2)camera.WorldToScreenPoint(point));
    };
    System.Func<ProjectY.Samples.AdventureViewData.Site> pickAtCenter=()=>
        (ProjectY.Samples.AdventureViewData.Site)call(siteView,"Pick",new object[]{camera,camera.pixelRect.center});
    System.Action<ProjectY.Samples.AdventureViewData.Site,string> sameTree=(picked,label)=>
        check(picked!=null&&picked.Id==77&&picked.WorldWonderId==1&&picked.AreaConfigId==72&&picked.Q==0&&picked.R==10,label+" must retain the one fixed root entrance");
    var reports=new System.Collections.Generic.List<object>();Vector3 previewHit=Vector3.up*8;int restoreBlocker=-1;
    foreach(int assetId in new[]{1106,1109})
    {
        if(restoreBlocker>=0){map.Cells[restoreBlocker].Position=new Vector3(map.Cells[restoreBlocker].Position.x,0,map.Cells[restoreBlocker].Position.z);restoreBlocker=-1;}
        map.Decorations[0].AssetId=assetId;rebuild();
        check(object.ReferenceEquals(map.Cells,cellIdentity)&&treeSite.Id==77&&treeSite.AreaConfigId==72&&treeSite.Q==0&&treeSite.R==10,"Model swap regenerated or moved the site");
        var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>((string)assetRows[assetId]["prefabPath"]);
        var mesh=prefab.GetComponent<MeshFilter>().sharedMesh;check(mesh.isReadable,"Tree mesh must be readable before this check: "+assetId);
        var bounds=mesh.bounds;var tags=(System.Collections.IDictionary)field(siteView,"tags");
        var footprint=(int[])field(tags[77],"Cells");var mapping=(System.Collections.IDictionary)field(siteView,"sitesByCell");
        check(footprint.Length==272&&footprint.Distinct().Count()==272&&footprint.Contains(farRoot)&&footprint.Contains(otherRoot)&&footprint.Contains(entrance)&&!footprint.Contains(outside),"Wonder footprint must be 271 roots plus entrance, never the whole region");
        foreach(int index in footprint)check(object.ReferenceEquals(mapping[index],tags[77]),"Root/entrance cell points at another tag");
        check(object.ReferenceEquals(mapping[outside],tags[88]),"Ordinary same-region site was swallowed by the wonder");
        aimDown(map.Cells[farRoot].Position);check(groundPick(camera.ScreenPointToRay(camera.pixelRect.center)).Item1==farRoot,"Far-root ground fixture missed its column");sameTree(pickAtCenter(),"Far root click");
        aimDown(map.Cells[entrance].Position);sameTree(pickAtCenter(),"Fixed entrance click");
        aimDown(map.Cells[outside].Position);check(pickAtCenter()?.Id==88,"Same-region ordinary site must remain separate");

        Vector3 trunkTarget=Vector3.zero,crownTarget=Vector3.zero;Ray trunkRay=default(Ray);float trunkDistance=0,crownDistance=0;
        for(int part=0;part<2;part++)
        {
            bool found=false;
            for(int y=0;y<8&&!found;y++)for(int x=0;x<13&&!found;x++)
            {
                float fraction=part==0 ? .07f+y*.025f : .56f+y*.043f;
                float lateral=x==0?0:((x+1)/2)*(x%2==1?1:-1)*bounds.size.x*.055f;
                var point=new Vector3(bounds.center.x+lateral,bounds.min.y+bounds.size.y*fraction,bounds.center.z);
                var ray=aim(point);var hit=wonderPick(ray);if(!hit.Item1)continue;
                var ground=groundPick(ray);
                check(hit.Item2==center&&ground.Item1>=0&&hit.Item3<ground.Item2,"Actual tree geometry must precede the ground behind it");
                sameTree(pickAtCenter(),part==0?"Trunk mesh click":"Crown mesh click");
                if(part==0){trunkTarget=point;trunkRay=ray;trunkDistance=hit.Item3;previewHit=ray.GetPoint(hit.Item3);}
                else{crownTarget=point;crownDistance=hit.Item3;}
                found=true;
            }
            check(found,part==0?"No real trunk triangle hit":"No real crown triangle hit");
        }
        // Find an interior miss bracketed by real silhouette hits on both sides of a branch-level scanline.
        // This cannot pass by choosing an empty corner outside the model's AABB.
        bool gapFound=false;Ray gapRay=default(Ray);int gapSamples=0;
        foreach(var direction in new[]{Vector3.forward,Vector3.right,new Vector3(1,0,1).normalized})
        {
            if(gapFound)break;var sideways=new Vector3(direction.z,0,-direction.x);
            float halfWidth=Mathf.Abs(sideways.x)*bounds.extents.x+Mathf.Abs(sideways.z)*bounds.extents.z;
            for(int y=0;y<37&&!gapFound;y++)
            {
                var hits=new bool[49];var inBounds=new bool[49];var rays=new Ray[49];
                for(int x=0;x<49;x++)
                {
                    var point=bounds.center+sideways*Mathf.Lerp(-halfWidth*.82f,halfWidth*.82f,x/48f);
                    point.y=bounds.min.y+bounds.size.y*(.25f+.55f*y/36f);
                    rays[x]=new Ray(point-direction*(bounds.extents.magnitude+20),direction);
                    inBounds[x]=bounds.IntersectRay(rays[x]);hits[x]=wonderPick(rays[x]).Item1;gapSamples++;
                }
                bool left=false;
                for(int x=0;x<49&&!gapFound;x++)
                {
                    if(hits[x]){left=true;continue;}
                    if(!left||!inBounds[x])continue;
                    for(int right=x+1;right<49;right++)if(hits[right]){gapRay=rays[x];gapFound=true;break;}
                }
            }
        }
        check(gapFound&&bounds.IntersectRay(gapRay)&&!wonderPick(gapRay).Item1,"Branch gap was swallowed by AABB picking");

        aim(trunkTarget);call(siteView,"Tick",new object[]{camera,true,camera.pixelRect.center,.2f});hud.UpdateFollowers();
        check((int)field(siteView,"hovered")==77&&((RectTransform)field(tags[77],"Rect")).gameObject.activeSelf,"Tree hover did not activate its native tag");
        var focused=(System.Collections.Generic.HashSet<int>)field(renderer,"focusedCells");
        check(focused.Count==272&&focused.Contains(farRoot)&&focused.Contains(entrance)&&!focused.Contains(outside),"Hover focus lost the complete wonder footprint");
        var focusInstances=(System.Collections.IList)field(renderer,"focusedInstances");int liftedWonderParts=0;
        foreach(var entry in focusInstances)
        {
            var batch=field(entry,"Batch");if(field(batch,"Kind").ToString()!="Wonder")continue;
            int index=(int)field(entry,"Index");var original=(Matrix4x4)field(entry,"Matrix");var current=((Matrix4x4[])field(batch,"Matrices"))[index];
            check(Mathf.Abs(current.m13-original.m13-.24f)<.0001f,"Wonder hover lift must be applied exactly once");liftedWonderParts++;
        }
        check(liftedWonderParts>0,"Wonder was omitted from native hover instances");
        var liftedHit=wonderPick(new Ray(trunkRay.origin+Vector3.up*.24f,trunkRay.direction));
        check(liftedHit.Item1&&Mathf.Abs(liftedHit.Item3-trunkDistance)<.002f,"BVH picking did not follow the hovered instance transform");
        aimDown(map.Cells[outside].Position);call(siteView,"Tick",new object[]{camera,true,camera.pixelRect.center,.2f});
        check((int)field(siteView,"hovered")==88&&((System.Collections.Generic.HashSet<int>)field(renderer,"focusedCells")).Count==1,"Moving hover off the tree retained its footprint");
        check(wonderPick(trunkRay).Item1&&Mathf.Abs(wonderPick(trunkRay).Item3-trunkDistance)<.002f,"Leaving tree hover did not restore its transform");
        call(siteView,"Hide",System.Array.Empty<object>());

        var fog=new ProjectY.Data.WorldMapExplorationData();fog.Reset(map.Cells.Length);renderer.SetExploration(fog);sync();
        aim(trunkTarget);check(!wonderPick(trunkRay).Item1&&pickAtCenter()==null,"Completely undiscovered wonder must not be pickable");
        fog.Reveal(new[]{farRoot+1});renderer.SetExploration(fog);sync();
        check(fog.KnownCount==1&&!fog.IsKnown(center+1)&&!fog.IsKnown(entrance+1)&&!fog.IsKnown(outside+1),"Revealing one root uncovered unrelated ground");
        aim(trunkTarget);sameTree(pickAtCenter(),"One-root discovery trunk click");
        aim(crownTarget);sameTree(pickAtCenter(),"One-root discovery crown click");
        check((bool)call(renderer,"IsWorldWonderKnown",new object[]{1})&&!(bool)call(renderer,"IsWorldCellKnown",new object[]{center}),"Wonder visibility was incorrectly tied to its unknown center");
        aimDown(map.Cells[outside].Position);check(pickAtCenter()==null,"An unknown ordinary ground site became selectable");
        check(fog.KnownCount==1&&fog.VisibleCount==1,"Wonder interaction changed exploration state");

        // Existing flat-top terrain, in front of the tested trunk ray, must win the nearest-hit comparison.
        float frontZ=-18;float along=(frontZ-trunkRay.origin.z)/trunkRay.direction.z;var occlusionPoint=trunkRay.GetPoint(along);
        int blockerQ=Mathf.RoundToInt(occlusionPoint.x/Mathf.Sqrt(3)+6);restoreBlocker=indices[new Vector2Int(blockerQ,-12)];
        check(map.Cells[restoreBlocker].WonderId==0&&map.Cells[restoreBlocker].SurfaceCorners==null,"Occluder must be ordinary legacy column terrain");
        var oldPosition=map.Cells[restoreBlocker].Position;map.Cells[restoreBlocker].Position=new Vector3(oldPosition.x,occlusionPoint.y+5,oldPosition.z);
        rebuild();aim(trunkTarget);var modelBehind=wonderPick(trunkRay);var foreground=groundPick(trunkRay);
        check(modelBehind.Item1&&foreground.Item1==restoreBlocker&&foreground.Item2<modelBehind.Item3,"Foreground terrain did not intersect before the model");
        check(pickAtCenter()==null,"Tree behind foreground terrain stole the click");
        reports.Add(new{assetId,footprint=272,regions=2,trunkDistance,crownDistance,gapSamples,
            gapHeight=gapRay.origin.y,oneRootKnown=1,foregroundHeight=map.Cells[restoreBlocker].Position.y,siteId=77,areaId=72,entrance=new[]{0,10}});
    }

    // One final screenshot: the alternate actual model is selected with only one root cell discovered.
    var blockedPosition=map.Cells[restoreBlocker].Position;map.Cells[restoreBlocker].Position=new Vector3(blockedPosition.x,0,blockedPosition.z);rebuild();
    var finalFog=new ProjectY.Data.WorldMapExplorationData();finalFog.Reset(map.Cells.Length);finalFog.Reveal(new[]{farRoot+1});renderer.SetExploration(finalFog);sync();
    camera.orthographicSize=30;camera.transform.position=new Vector3(38,36,-75);camera.transform.LookAt(new Vector3(0,18,0));
    var previewPointer=(Vector2)camera.WorldToScreenPoint(previewHit);
    call(siteView,"Tick",new object[]{camera,true,previewPointer,.2f});hud.UpdateFollowers();
    check((int)field(siteView,"hovered")==77&&finalFog.KnownCount==1,"Final preview lost one-root discovery or hover");
    renderer.Draw(camera,true,true,true,true);ProjectY.Rendering.UrpCameraRendering.Render(camera);
    RenderTexture.active=target;pixels=new Texture2D(1440,900,TextureFormat.RGB24,false);pixels.ReadPixels(new Rect(0,0,1440,900),0,0);pixels.Apply();
    int pink=0,changed=0;var colors=pixels.GetPixels32();var background=colors[0];
    foreach(var color in colors){if(color.r>230&&color.b>230&&color.g<30)pink++;if(Mathf.Abs(color.r-background.r)+Mathf.Abs(color.g-background.g)+Mathf.Abs(color.b-background.b)>24)changed++;}
    check(pink==0&&changed>5000,"Giant-tree click preview is empty or has missing materials");
    check(errors.Count==0,"Preview logged errors: "+string.Join("; ",errors));
    var folder="Docs/Previews/TerrainWonders";System.IO.Directory.CreateDirectory(folder);
    var output=folder+"/giant-tree-site-click.png";System.IO.File.WriteAllBytes(output,pixels.EncodeToPNG());
    return new{status="PASS",models=reports,output,worldRegenerated=false,playMode=false};
}
finally
{
    siteView?.Dispose();renderer?.Dispose();if(camera!=null)camera.targetTexture=null;RenderTexture.active=previousTarget;
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Application.logMessageReceived-=log;
    if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene||originalScene.isDirty!=originalDirty)
        throw new System.Exception("Giant-tree site check modified the active scene");
}
