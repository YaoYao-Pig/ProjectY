// Unity MCP execute_code body. Isolated native preview; no Play or active scene changes.
if (EditorApplication.isPlayingOrWillChangePlaymode || EditorApplication.isCompiling) throw new System.Exception("Idle Edit Mode required");
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var savedScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); var savedDirty = savedScene.isDirty;
var services = new ProjectY.FrameworkServices(null);
var previous = RenderTexture.active;
var rt = new RenderTexture(1280, 720, 24); rt.Create();
var meshes = new System.Collections.Generic.List<Mesh>();
var copies = new System.Collections.Generic.List<GameObject>();
ProjectY.Samples.BattleCinematic cinematic = null;
ProjectY.UI.SceneFocusMask mask = null;
try
{
    using (var lua = new XLua.LuaEnv())
    {
        var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load); lua.Global.Set("Services", services);
        try
        {
            ProjectY.Samples.AdventureViewData.Actor state;
            var values = lua.DoString(System.IO.File.ReadAllText("Tools/Tests/spear_preview.lua"));
            using (var row = (XLua.LuaTable)values[0]) state = ProjectY.Samples.AdventureViewData.ReadActor(row);
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab");
            var participants = new System.Collections.Generic.List<ProjectY.Samples.PawnView>();
            var locations = new[] {new Vector3(-1.6f,0,0),new Vector3(1.6f,0,0),new Vector3(0,0,2)};
            for (int i=0;i<3;i++)
            {
                var pawn = UnityEngine.Object.Instantiate(prefab).GetComponent<ProjectY.Samples.PawnView>();
                UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(pawn.gameObject,scene);
                pawn.transform.position=locations[i];pawn.transform.rotation=Quaternion.Euler(0,i==0?90:270,0);
                pawn.ApplyAppearance(state.Appearance, p=>AssetDatabase.LoadAssetAtPath<GameObject>(p.Path));
                pawn.Capture(new ProjectY.Samples.AdventureViewData.Actor {Id=i+1,HP=state.HP,ActionSequence=0,
                    Actions=new ProjectY.Data.CombatActorData.PresentationAction[0]},locations[1],0);
                if(i==0) pawn.Capture(new ProjectY.Samples.AdventureViewData.Actor {Id=1,HP=state.HP,ActionSequence=1,
                    Actions=new[]{new ProjectY.Data.CombatActorData.PresentationAction {Sequence=1,TemplateId=9,Shots=1}}},locations[1],0);
                participants.Add(pawn);
            }
            var cameraObject=new GameObject("Cinematic preview camera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
            var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;
            camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
            camera.orthographic=true;camera.aspect=1280f/720;camera.nearClipPlane=.1f;camera.farClipPlane=80;camera.targetTexture=rt;
            camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.16f,.20f,.19f);
            ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
            var lightObject=new GameObject("Cinematic preview light");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(lightObject,scene);
            var light=lightObject.AddComponent<Light>();light.type=LightType.Directional;light.intensity=1.4f;light.transform.rotation=Quaternion.Euler(45,-30,0);
            var floor=GameObject.CreatePrimitive(PrimitiveType.Cube);UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(floor,scene);
            floor.transform.position=new Vector3(0,-.2f,0);floor.transform.localScale=new Vector3(14,.2f,10);
            var canvasObject=new GameObject("Cinematic mask canvas",typeof(RectTransform),typeof(Canvas));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(canvasObject,scene);
            var canvas=canvasObject.GetComponent<Canvas>();canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;
            var settings=new ProjectY.Samples.BattleCinematicSettings();
            mask=ProjectY.UI.SceneFocusMask.Create((RectTransform)canvasObject.transform);
            cinematic=new ProjectY.Samples.BattleCinematic(settings,mask);
            var chosen=new[]{participants[0],participants[1]};cinematic.Begin(chosen,.7f);
            var focus=Vector3.up*.7f;var rotation=Quaternion.Euler(52,-25,0);
            float simulated=0;
            for(int frame=0;frame<25;frame++)
            {
                cinematic.RestoreTransforms();float dt=cinematic.Advance(1f/60);simulated+=dt;
                foreach(var pawn in participants)pawn.TickPresentation(dt);
                camera.orthographicSize=6;camera.transform.SetPositionAndRotation(focus-rotation*Vector3.forward*25,rotation);
                cinematic.ApplyCamera(camera,focus,-25,52);
            }
            if(simulated>=.3f || !cinematic.Active)throw new System.Exception("Cinematic did not slow presentation");
            if(Mathf.Abs(participants[0].transform.position.y-.2f)>.002f || Mathf.Abs(participants[1].transform.position.y-.2f)>.002f || participants[2].transform.position.y!=0)
                throw new System.Exception("Lift affected wrong units or accumulated");
            var weight=cinematic.Weight;cinematic.Advance(0);if(cinematic.Weight!=weight)throw new System.Exception("Paused cinematic advanced");
            foreach(var pawn in participants)foreach(var skin in pawn.GetComponentsInChildren<SkinnedMeshRenderer>())
            {
                var mesh=new Mesh();skin.BakeMesh(mesh);meshes.Add(mesh);var copy=new GameObject("Baked preview pose");copy.transform.SetParent(skin.transform,false);
                copy.AddComponent<MeshFilter>().sharedMesh=mesh;var renderer=copy.AddComponent<MeshRenderer>();renderer.sharedMaterials=skin.sharedMaterials;
                for(int m=0;m<skin.sharedMaterials.Length;m++){var block=new MaterialPropertyBlock();skin.GetPropertyBlock(block,m);renderer.SetPropertyBlock(block,m);}copies.Add(copy);
            }
            // Real scene mask receives current skinned geometry; the output below includes its RawImage overlay.
            cinematic.DrawMask(camera);Canvas.ForceUpdateCanvases();
            var maskTexture=(RenderTexture)mask.Image.texture;RenderTexture.active=maskTexture;
            var maskPixels=new Texture2D(maskTexture.width,maskTexture.height,TextureFormat.RGBA32,false);
            maskPixels.ReadPixels(new Rect(0,0,maskTexture.width,maskTexture.height),0,0);maskPixels.Apply();
            var samples=new System.Collections.Generic.List<object>();
            foreach(var pawn in participants)
            {
                var point=camera.WorldToViewportPoint(pawn.transform.position+Vector3.up*.15f);
                int x=Mathf.Clamp((int)(point.x*maskTexture.width),0,maskTexture.width-1);
                int y=Mathf.Clamp((int)(point.y*maskTexture.height),0,maskTexture.height-1);
                samples.Add(new{point=point.ToString(),normal=maskPixels.GetPixel(x,y).r,flipped=maskPixels.GetPixel(x,maskTexture.height-1-y).r});
            }
            System.IO.File.WriteAllBytes("Docs/Previews/SpearBattleCinematicMask.png",maskPixels.EncodeToPNG());UnityEngine.Object.DestroyImmediate(maskPixels);
            // Mask was drawn from the live skins. The color snapshot uses exactly one baked copy per skin.
            foreach(var pawn in participants)foreach(var skin in pawn.GetComponentsInChildren<SkinnedMeshRenderer>())skin.enabled=false;
            mask.Image.gameObject.SetActive(false);Canvas.ForceUpdateCanvases();ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=rt;
            var before=new Texture2D(1280,720,TextureFormat.RGB24,false);before.ReadPixels(new Rect(0,0,1280,720),0,0);before.Apply();
            mask.Image.gameObject.SetActive(true);Canvas.ForceUpdateCanvases();
            ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=rt;
            var image=new Texture2D(1280,720,TextureFormat.RGB24,false);
            image.ReadPixels(new Rect(0,0,1280,720),0,0);image.Apply();
            bool aligned=true;var colorDeltas=new System.Collections.Generic.List<float>();
            for(int i=0;i<participants.Count;i++)
            {
                var point=camera.WorldToViewportPoint(participants[i].transform.position+Vector3.up*.15f);
                int x=Mathf.Clamp((int)(point.x*1280),0,1279),y=Mathf.Clamp((int)(point.y*720),0,719);
                var a=before.GetPixel(x,y);var b=image.GetPixel(x,y);float change=Mathf.Abs(a.r-b.r)+Mathf.Abs(a.g-b.g)+Mathf.Abs(a.b-b.b);colorDeltas.Add(change);
                aligned&=i<2 ? change<.04f : change>.05f;
            }
            UnityEngine.Object.DestroyImmediate(before);
            System.IO.Directory.CreateDirectory("Docs/Previews");System.IO.File.WriteAllBytes("Docs/Previews/SpearBattleCinematic.png",image.EncodeToPNG());UnityEngine.Object.DestroyImmediate(image);
            if(!aligned)throw new System.Exception("Composited mask does not preserve selected units and dim the third: "+string.Join(",",colorDeltas));
            cinematic.Clear();
            for(int i=0;i<3;i++)if(Vector3.Distance(participants[i].transform.position,locations[i])>.0001f)throw new System.Exception("Skip left a lifted actor");
            if(mask.Image.gameObject.activeSelf || cinematic.Active)throw new System.Exception("Skip left an active mask");
            cinematic.Begin(participants,.1f);
            for(int i=0;i<180 && cinematic.Active;i++)cinematic.Advance(1f/60);
            if(cinematic.Active)throw new System.Exception("Cinematic did not finish automatically");
            cinematic.Begin(chosen,.5f);cinematic.Advance(.2f);UnityEngine.Object.DestroyImmediate(participants[1].gameObject);
            cinematic.ApplyCamera(camera,focus,-25,52);cinematic.Clear();
            return new {passed=true,colorDeltas=colorDeltas,samples=samples,simulatedSeconds=simulated,preview="Docs/Previews/SpearBattleCinematic.png",checks="real spear snapshot/animation, slow clock, composited mask preserves both targets/dims third, no lift accumulation, pause, skip, finish, destroyed target"};
        }
        finally { lua.DoString("if CloseSpearPreview then CloseSpearPreview() end");lua.Global.Set<string,object>("Services",null); }
    }
}
finally
{
    if(cinematic!=null)cinematic.Dispose();else if(mask!=null)mask.Dispose();
    RenderTexture.active=previous;rt.Release();UnityEngine.Object.DestroyImmediate(rt);
    foreach(var mesh in meshes)UnityEngine.Object.DestroyImmediate(mesh);
    services.Player.ClearListeners();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if(savedScene.isDirty!=savedDirty)throw new System.Exception("Preview changed the active scene dirty state");
}
