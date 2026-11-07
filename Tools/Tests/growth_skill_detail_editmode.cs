// Execute after the coordinated compile and GrowthSkillDetailAssets.Sync. No Play or scene saves.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool originalDirty=originalScene.isDirty;
var originalTime=Time.timeScale;var originalRandom=UnityEngine.Random.state;var originalTarget=RenderTexture.active;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("Course detail isolated check");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var cameraObject=new GameObject("Course detail camera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;
camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
camera.orthographic=true;camera.orthographicSize=360;camera.nearClipPlane=.1f;camera.farClipPlane=100;camera.cullingMask=1<<31;
camera.transform.position=new Vector3(0,0,-10);camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.04f,.06f,.05f);
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var target=new RenderTexture(1280,720,24);target.Create();camera.targetTexture=target;
var output="Docs/Previews/GrowthSkillDetail";System.IO.Directory.CreateDirectory(output);
int nativeCases=0;
System.Action<bool,string> check=(value,message)=>{if(!value)throw new System.Exception(message);};
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host,System.IO.Path.Combine(System.IO.Path.GetTempPath(),"growth-detail-unused-"+System.Guid.NewGuid()+".json"));
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
        System.Action<ProjectY.UI.GrowthSkillDetailView,string,bool> inspect=(view,phase,canLearn)=>
        {
            Canvas.ForceUpdateCanvases();var layout=view.EditorLayout;
            if(phase=="long")
            {
                ProjectY.UI.GrowthSkillDetailPresentation.Begin(view,layout.Body.text,layout.Heading.text,"","",true);
                for(int i=0;i<12;i++)ProjectY.UI.GrowthSkillDetailPresentation.AddCondition(view,"Long requirement "+i+" — a separate line wrapping safely inside the scrollable card",i%2==0);
                ProjectY.UI.GrowthSkillDetailPresentation.End(view);Canvas.ForceUpdateCanvases();
                check(layout.Scroll.content.rect.height>layout.Scroll.viewport.rect.height&&layout.Scroll.verticalScrollbar.gameObject.activeSelf,"Long requirements need scrollable content");
                layout.Scroll.content.anchoredPosition=new Vector2(0,40);
                ProjectY.UI.GrowthSkillDetailPresentation.Begin(view,layout.Body.text,layout.Heading.text,"","",false);
                for(int i=0;i<12;i++)ProjectY.UI.GrowthSkillDetailPresentation.AddCondition(view,"Requirement "+i,i%2==0);
                ProjectY.UI.GrowthSkillDetailPresentation.End(view);
                check(Mathf.Abs(layout.Scroll.content.anchoredPosition.y-40)<.1f,"Ordinary refresh should preserve scrolling");
                ProjectY.UI.GrowthSkillDetailPresentation.Begin(view,"",layout.Heading.text,"","",true);
                ProjectY.UI.GrowthSkillDetailPresentation.AddCondition(view,"Complete",true);ProjectY.UI.GrowthSkillDetailPresentation.End(view);
                check(view.EditorConditionCount==1&&layout.Scroll.content.anchoredPosition.y==0,"Selection change must reset scroll and hide pooled rows");
                nativeCases++;return;
            }
            check(view.EditorTagCount>=2&&view.EditorTag(0).Caption.text==ProjectY.UI.LuaLanguage.Get("UICharacterGrowthKind"),"Active skill kind must be a real colored tag");
            check(view.EditorTag(0).Background.color.a>0&&view.EditorTag(0).Rect.rect.height>15,"Skill tag needs visible background and layout");
            check(layout.Body.text.Contains("<color=#A45C22>")&&layout.Body.text.Contains("<b>3</b>"),"Description number must be colored and bold");
            int met=0,unmet=0;
            for(int i=0;i<view.EditorConditionCount;i++)
            {
                var row=view.EditorCondition(i);bool crossed=row.Caption.text.StartsWith("<s>");
                check(row.Mask.gameObject.activeSelf==crossed,"Checkbox and strikethrough disagree");
                check(row.Caption.color==row.Background.color,"Checkbox border and condition text must share the semantic color");
                check(crossed?row.Caption.color.g>row.Caption.color.r:row.Caption.color.r>row.Caption.color.g,"Wrong condition color");
                row.Caption.ForceMeshUpdate(true,true);
                check(row.Caption.preferredHeight<=row.Caption.rectTransform.rect.height+2,"Condition text is clipped");
                if(crossed){met++;bool styled=false;for(int n=0;n<row.Caption.textInfo.characterCount;n++)if((row.Caption.textInfo.characterInfo[n].style&TMPro.FontStyles.Strikethrough)!=0)styled=true;check(styled,"TMP did not generate strikethrough styling");}
                else unmet++;
            }
            check(phase=="locked"?unmet>0&&met>0:unmet==0&&met>0,"Live requirement state is incorrect");
            check(canLearn==(phase=="ready"),"Learning button must follow the actual rules");nativeCases++;
        };
        System.Action<ProjectY.UI.LuaReference,string> capture=(reference,name)=>
        {
            foreach(var child in root.GetComponentsInChildren<Transform>(true))child.gameObject.layer=31;
            foreach(var canvas in root.GetComponentsInChildren<Canvas>(true))if(canvas.transform.parent==root.transform&&canvas.renderMode!=RenderMode.WorldSpace)
            {canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}
            Canvas.ForceUpdateCanvases();foreach(var style in root.GetComponentsInChildren<ProjectY.UI.StoryGrowthView>())style.Prepare();Canvas.ForceUpdateCanvases();
            ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;
            var pixels=new Texture2D(1280,720,TextureFormat.RGB24,false);
            try{pixels.ReadPixels(new Rect(0,0,1280,720),0,0);pixels.Apply();System.IO.File.WriteAllBytes(output+"/"+name+".png",pixels.EncodeToPNG());}
            finally{UnityEngine.Object.DestroyImmediate(pixels);RenderTexture.active=originalTarget;}
        };
        lua.Global.Set("CheckGrowthSkillDetail",inspect);lua.Global.Set("CaptureGrowthSkillDetail",capture);
        try
        {
            var report=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/growth_skill_detail_integration.lua"),"@Tools/Tests/growth_skill_detail_integration.lua")[0];
            return new{passed=true,nativeCases,report,previews=output,playMode=false};
        }
        finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
    }
}
finally
{
    host.Shutdown();camera.targetTexture=null;RenderTexture.active=originalTarget;target.Release();UnityEngine.Object.DestroyImmediate(target);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Time.timeScale=originalTime;UnityEngine.Random.state=originalRandom;
    if(originalScene.isDirty!=originalDirty)throw new System.Exception("Course detail validation changed the active scene");
}
