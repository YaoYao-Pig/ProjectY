// Actual C# install transactions plus mounted prefab inspection, in an isolated Edit Mode scene.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var captures=new System.Collections.Generic.List<string>();
int weaponCount=0,installCases=0;
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        lua.Global.Set("Services",new ProjectY.FrameworkServices(null));
        using(var result=(XLua.LuaTable)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/weapon_socket_expansion_integration.lua"),"socket_expansion_native")[0])
        using(var snapshots=result.Get<XLua.LuaTable>("snapshots"))
        {
            installCases=result.Get<int>("installCases");
            var catalog=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Samples.EquipmentAssetCatalog>(ProjectY.Editor.EquipmentAssets.CatalogPath);
            var cameraObject=new UnityEngine.GameObject("AttachmentPreviewCamera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
            var camera=cameraObject.AddComponent<UnityEngine.Camera>();camera.enabled=false;camera.scene=scene;camera.orthographic=true;
            camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.07f,.09f,.10f);camera.cullingMask=1<<31;
            camera.allowHDR=false;camera.nearClipPlane=.01f;camera.farClipPlane=30;ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
            var lights=new[]{new UnityEngine.Vector3(30,-35,0),new UnityEngine.Vector3(15,135,0)};
            for(int i=0;i<lights.Length;i++)
            {
                var lightObject=new UnityEngine.GameObject("AttachmentPreviewLight"+i);UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(lightObject,scene);
                var light=lightObject.AddComponent<UnityEngine.Light>();light.type=UnityEngine.LightType.Directional;light.intensity=i==0?1.3f:.7f;light.cullingMask=1<<31;
                light.transform.rotation=UnityEngine.Quaternion.Euler(lights[i]);
            }
            var selected=new System.Collections.Generic.HashSet<int>(new[]{2,607,610,613,616,619,46,74});
            var request=new UnityEngine.Rendering.Universal.UniversalRenderPipeline.SingleCameraRequest();
            for(int index=1;index<=snapshots.Length;index++)using(var row=snapshots.Get<int,XLua.LuaTable>(index))using(var view=row.Get<XLua.LuaTable>("view"))
            {
                int id=row.Get<int>("itemId");var visual=ProjectY.Samples.EquipmentVisualData.Weapon.Read(view);
                var instance=(UnityEngine.GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(catalog.Resolve(visual.Model),scene);
                try
                {
                    var model=instance.GetComponent<ProjectY.Samples.WeaponModelView>();model.Apply(visual,catalog);
                    foreach(var socket in visual.Sockets)
                    {
                        var anchor=model.Socket(socket.Id);
                        if((anchor.localPosition-socket.Position).sqrMagnitude>.000001f)throw new System.Exception("Socket coordinate mismatch: "+socket.Id);
                        if(socket.Attachment==null || anchor.childCount!=1)throw new System.Exception("Attachment was not mounted: "+socket.Id);
                    }
                    foreach(var node in instance.GetComponentsInChildren<UnityEngine.Transform>(true))node.gameObject.layer=31;
                    var renderers=instance.GetComponentsInChildren<UnityEngine.Renderer>(true);var bounds=renderers[0].bounds;
                    foreach(var renderer in renderers){bounds.Encapsulate(renderer.bounds);foreach(var material in renderer.sharedMaterials)if(material==null)throw new System.Exception("Missing mounted material");}
                    weaponCount++;
                    if(selected.Contains(id))
                    {
                        camera.transform.position=bounds.center+new UnityEngine.Vector3(3,1.1f,4).normalized*6;camera.transform.LookAt(bounds.center);
                        camera.orthographicSize=UnityEngine.Mathf.Max(bounds.size.x,UnityEngine.Mathf.Max(bounds.size.y,bounds.size.z))*.63f;
                        var texture=new UnityEngine.RenderTexture(480,480,24,UnityEngine.RenderTextureFormat.ARGB32);texture.Create();
                        var png=new UnityEngine.Texture2D(480,480,UnityEngine.TextureFormat.RGB24,false);var previous=UnityEngine.RenderTexture.active;
                        try
                        {
                            camera.targetTexture=texture;ProjectY.Rendering.UrpCameraRendering.Render(camera,request);UnityEngine.RenderTexture.active=texture;
                            png.ReadPixels(new UnityEngine.Rect(0,0,480,480),0,0);png.Apply();
                            string path="Art/SocketExpansion202610/Previews/Weapon_"+id+".png";System.IO.File.WriteAllBytes(path,png.EncodeToPNG());captures.Add(path);
                        }
                        finally{UnityEngine.RenderTexture.active=previous;camera.targetTexture=null;texture.Release();UnityEngine.Object.DestroyImmediate(texture);UnityEngine.Object.DestroyImmediate(png);}
                    }
                }
                finally{UnityEngine.Object.DestroyImmediate(instance);}
            }
        }
    }
}
finally{UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
return new{weapons=weaponCount,installCases=installCases,captures=captures.ToArray(),playMode=false};
