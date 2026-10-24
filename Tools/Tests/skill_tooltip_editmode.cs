// Unity MCP execute_code body. Real saved prefab and TMP links, isolated PreviewScene, no Play.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();var originalDirty=originalScene.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var previous=RenderTexture.active;var target=new RenderTexture(1280,720,24,RenderTextureFormat.ARGB32);target.Create();
var cameraObject=new GameObject("Skill tooltip preview camera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;camera.orthographic=true;camera.orthographicSize=360;
camera.aspect=1280f/720;camera.nearClipPlane=.1f;camera.farClipPlane=2000;camera.transform.position=new Vector3(0,0,-1000);
camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.035f,.055f,.065f);camera.targetTexture=target;
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
object result;
try
{
    var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/Battle/BattleHUDPanel.prefab");
    var root=UnityEngine.Object.Instantiate(prefab);UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
    var canvas=root.GetComponent<Canvas>();canvas.renderMode=RenderMode.WorldSpace;canvas.worldCamera=camera;
    root.GetComponent<UnityEngine.UI.CanvasScaler>().enabled=false;
    var rect=(RectTransform)root.transform;rect.sizeDelta=new Vector2(1280,720);rect.localPosition=Vector3.zero;rect.localScale=Vector3.one;
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();reference.ValidateBindings();
    var hud=root.GetComponent<ProjectY.UI.BattleHUDView>();hud.Prepare();hud.PreviewLayout(1280);
    var tip=(ProjectY.UI.SkillTooltipView)reference.Get("SkillTip");
    foreach(Transform child in hud.EditorLayout.SafeArea)if(child!=tip.transform)child.gameObject.SetActive(false);
    var anchor=(RectTransform)new GameObject("Preview skill anchor",typeof(RectTransform)).transform;
    anchor.SetParent(hud.EditorLayout.SafeArea,false);anchor.anchorMin=anchor.anchorMax=anchor.pivot=new Vector2(.5f,.5f);
    anchor.anchoredPosition=new Vector2(-300,-230);anchor.sizeDelta=new Vector2(120,72);
    System.Action<string> capture=name=>{
        Canvas.ForceUpdateCanvases();ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;
        var pixels=new Texture2D(target.width,target.height,TextureFormat.RGBA32,false);
        try{pixels.ReadPixels(new Rect(0,0,target.width,target.height),0,0);pixels.Apply();System.IO.Directory.CreateDirectory("Docs/Previews/SkillTooltip");
            System.IO.File.WriteAllBytes("Docs/Previews/SkillTooltip/"+name+".png",pixels.EncodeToPNG());}
        finally{UnityEngine.Object.DestroyImmediate(pixels);RenderTexture.active=previous;}
    };
    System.Func<TMPro.TMP_Text,string> clickFirst=text=>{
        text.ForceMeshUpdate();var info=text.textInfo;if(info.linkCount<1)throw new System.Exception("TMP did not parse a term link");
        var link=info.linkInfo[0];var ch=info.characterInfo[link.linkTextfirstCharacterIndex];
        var center=text.transform.TransformPoint((ch.bottomLeft+ch.topRight)*.5f);
        if(!tip.ClickAt(camera.WorldToScreenPoint(center),camera))throw new System.Exception("Visible TMP link hit-test failed");
        return link.GetLinkID();
    };
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(null,System.IO.Path.Combine(System.IO.Path.GetTempPath(),"skill-tip-unused-"+System.Guid.NewGuid().ToString("N")+".json"));
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        lua.Global.Set("Services",services);lua.Global.Set("TipView",tip);lua.Global.Set("TipAnchor",anchor);
        try
        {
            lua.DoString(@"local config=require('Config.ConfigSystem')();config:OnInit({services=Services})
                TipPresenter=require('UI.SkillTipPresenter').New(TipView,config)
                local base=config:GetTable('CombatSkillTable'):Get(6);TipSkill={};for k,v in pairs(base)do TipSkill[k]=v end
                TipSkill.appliedRuneIds={11};TipSkill.damageScale=.7;TipSkill.maxTargets=3;TipSkill.splashRadius=2
                CS.ProjectY.Data.SkillSynergyDiscovery.Discover(Services.Adventure,11)
                TipRow={skill=TipSkill,cooldown=0,name=TipSkill.name,available=true}
                TipPresenter:Show(TipRow,Services.Adventure,TipAnchor)");
            Canvas.ForceUpdateCanvases();tip.RebuildLayout();var layout=tip.EditorLayout;
            if(tip.EditorTagCount<2 || tip.EditorStatCount<7 || tip.EditorSynergyCount<2)throw new System.Exception("Structured tooltip data missing");
            if(layout.Scroll.content.rect.height<=layout.Scroll.viewport.rect.height)throw new System.Exception("Long synergy descriptions are not scrollable");
            var known=tip.EditorSynergy(0);var unknown=tip.EditorSynergy(1);
            if(known.Mask.gameObject.activeSelf || !unknown.Mask.gameObject.activeSelf || unknown.Caption.text!="" || unknown.Body.text!="")
                throw new System.Exception("Discovery mask or secret-text isolation failed");
            capture("skill-card");
            var firstLink=clickFirst(layout.Body);lua.DoString("TipPresenter:Tick();assert(#TipPresenter.stack==2)");
            Canvas.ForceUpdateCanvases();tip.RebuildLayout();
            clickFirst(layout.Body);lua.DoString("TipPresenter:Tick();assert(#TipPresenter.stack==3)");
            capture("nested-term");
            layout.Back.onClick.Invoke();lua.DoString("TipPresenter:Tick();assert(#TipPresenter.stack==2)");
            layout.Back.onClick.Invoke();lua.DoString("TipPresenter:Tick();assert(#TipPresenter.stack==1)");
            Canvas.ForceUpdateCanvases();layout.Scroll.content.anchoredPosition=new Vector2(0,-layout.SynergyTitle.rectTransform.anchoredPosition.y-8);capture("synergies");
            rect.sizeDelta=new Vector2(480,420);hud.PreviewLayout(480);Canvas.ForceUpdateCanvases();tip.Show(anchor);
            var corners=new Vector3[4];layout.Root.GetWorldCorners(corners);
            foreach(var point in corners){var local=layout.Bounds.InverseTransformPoint(point);if(!layout.Bounds.rect.Contains(new Vector2(local.x,local.y)))throw new System.Exception("Tooltip exceeded small-screen safe area");}
            lua.DoString("TipPresenter:Hide();assert(#TipPresenter.stack==0);TipPresenter:Show(TipRow,Services.Adventure,TipAnchor)");
            if(layout.Back.gameObject.activeSelf)throw new System.Exception("Cached reopen retained navigation");
            result=new{passed=true,realTMPHitTests=true,nestedNavigation=true,maskedSynergies=tip.EditorSynergyCount-1,
                scrollable=true,smallScreen=true,playMode=false,preview="Docs/Previews/SkillTooltip/skill-card.png"};
        }
        finally {lua.DoString("if TipPresenter then TipPresenter:Hide() end;TipPresenter=nil;TipSkill=nil;TipRow=nil");lua.Global.Set<string,object>("Services",null);lua.Global.Set<string,object>("TipView",null);lua.Global.Set<string,object>("TipAnchor",null);services.Player.ClearListeners();}
    }
}
finally {camera.targetTexture=null;RenderTexture.active=previous;target.Release();UnityEngine.Object.DestroyImmediate(target);UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene || originalScene.isDirty!=originalDirty)throw new System.Exception("Tooltip validation changed the user's scene");
return result;
