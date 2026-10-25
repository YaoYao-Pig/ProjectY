// Execute via Unity MCP in an existing idle Editor. No scene changes or Play Mode.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("JournalSkillPreviewValidation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var oldTime=Time.timeScale;var oldRandom=UnityEngine.Random.state;
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
var viewType=typeof(ProjectY.UI.InventoryCharacterView);
var render=viewType.GetMethod("RenderPreview",flags,null,new[]{typeof(float)},null);
System.Func<ProjectY.UI.InventoryCharacterView,string,object> field=(view,name)=>viewType.GetField(name,flags).GetValue(view);
var output="Docs/Previews/SkillPreview";System.IO.Directory.CreateDirectory(output);
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host,System.IO.Path.Combine(System.IO.Path.GetTempPath(),"journal-skill-preview-"+System.Guid.NewGuid().ToString("N")+".json"));
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        var hitField=typeof(ProjectY.Data.BattleData).GetField("hitState",flags);
        var growthField=typeof(ProjectY.Data.CharacterGrowthData).GetField("randomState",flags);
        uint hitSeed=0;uint[] growthSeeds=null;UnityEngine.Random.State randomSeed=default(UnityEngine.Random.State);
        System.Action checkRandom=()=>{
            if(growthSeeds==null)
            {
                hitSeed=(uint)hitField.GetValue(services.Adventure.Battle);growthSeeds=new uint[services.Adventure.PartyCount];
                for(int i=0;i<growthSeeds.Length;i++)growthSeeds[i]=(uint)growthField.GetValue(services.Adventure.GetPartyAt(i).Growth);
                randomSeed=UnityEngine.Random.state;
            }
            if(!randomSeed.Equals(UnityEngine.Random.state)||(uint)hitField.GetValue(services.Adventure.Battle)!=hitSeed)
                throw new System.Exception("Skill preview consumed a shared random stream");
            for(int i=0;i<growthSeeds.Length;i++)if((uint)growthField.GetValue(services.Adventure.GetPartyAt(i).Growth)!=growthSeeds[i])
                throw new System.Exception("Skill preview consumed growth RNG");
        };
        System.Action<ProjectY.UI.InventoryCharacterView,int> capture=(view,index)=>{
            var texture=(RenderTexture)field(view,"texture");var previous=RenderTexture.active;
            var image=new Texture2D(texture.width,texture.height,TextureFormat.RGB24,false);
            try{RenderTexture.active=texture;image.ReadPixels(new Rect(0,0,texture.width,texture.height),0,0);image.Apply();System.IO.File.WriteAllBytes(output+"/wound-strike-"+index.ToString("00")+".png",image.EncodeToPNG());}
            finally{RenderTexture.active=previous;UnityEngine.Object.DestroyImmediate(image);}
        };
        System.Action<ProjectY.UI.InventoryCharacterView,int,string> check=(view,id,phase)=>{
            checkRandom();
            var pawn=(ProjectY.Samples.PawnView)field(view,"pawn");
            var effects=(ProjectY.Samples.BlockParticleEffects)field(view,"skillEffects");
            var profile=(ProjectY.Samples.BlockEffectProfile)field(view,"skillProfile");
            if(phase=="started")
            {
                if((int)field(view,"previewSkillId")!=id||profile==null||(float)field(view,"previewElapsed")!=0||effects.ActiveParticleCount!=0)
                    throw new System.Exception("Selection did not start a fresh preview: "+id);
                if(Time.timeScale!=0)throw new System.Exception("Journal should pause the world while previewing");
            }
            else if(phase=="advance")
            {
                var animation=(ProjectY.Samples.PawnAnimationView)typeof(ProjectY.Samples.PawnView).GetField("animationView",flags).GetValue(pawn);
                var animator=(Animator)typeof(ProjectY.Samples.PawnAnimationView).GetField("animator",flags).GetValue(animation);
                var hand=animator.GetBoneTransform(HumanBodyBones.RightHand);var before=hand.position;
                var left=animator.GetBoneTransform(HumanBodyBones.LeftHand);var leftBefore=left.position;
                float impact=(float)field(view,"previewImpact");int steps=Mathf.CeilToInt((impact+.08f)/.04f);
                for(int i=0;i<steps;i++)render.Invoke(view,new object[]{.04f});
                if(effects.ActiveParticleCount==0)throw new System.Exception("Skill profile produced no preview particles: "+id);
                if(impact>0&&Vector3.Distance(hand.position,before)<.002f&&Vector3.Distance(left.position,leftBefore)<.002f)
                    throw new System.Exception("Skill preview did not animate the character: "+id);
            }
            else if(phase=="finished")
            {
                for(int i=0;i<160&&field(view,"skillProfile")!=null;i++)render.Invoke(view,new object[]{.04f});
                if(field(view,"skillProfile")!=null||effects.ActiveParticleCount!=0||pawn.PresentationBusy)
                    throw new System.Exception("Skill preview failed to finish within 6.4 seconds");
            }
            else if(phase=="stopped")
            {
                if(field(view,"skillProfile")!=null||(effects!=null&&effects.ActiveParticleCount!=0)||(pawn!=null&&pawn.PresentationBusy))
                    throw new System.Exception("Previous skill preview survived navigation");
            }
            else if(phase=="released")
            {
                if(field(view,"studio")!=null||field(view,"skillEffects")!=null||field(view,"texture")!=null)
                    throw new System.Exception("Hidden journal retained preview resources");
            }
            else if(phase=="capture")
            {
                capture(view,0);
                for(int i=1;i<=16;i++)
                {
                    render.Invoke(view,new object[]{.08f});capture(view,i);checkRandom();
                    if(i==3)
                    {
                        var method=typeof(ProjectY.Editor.StoryGrowthValidation).GetMethod("Capture",System.Reflection.BindingFlags.Static|System.Reflection.BindingFlags.NonPublic);
                        // The legacy full-page capture creates a camera and lights; isolate that
                        // screenshot-only helper from the production preview RNG assertions.
                        var captureRandom=UnityEngine.Random.state;
                        try{method.Invoke(null,new object[]{root,scene,"skill-preview-wound-strike"});}
                        finally{UnityEngine.Random.state=captureRandom;}
                    }
                }
            }
            else throw new System.Exception("Unknown preview check phase: "+phase);
            checkRandom();
        };
        lua.Global.Set("Services",services);lua.Global.Set("CheckSkillPreview",check);
        try{return lua.DoString(System.IO.File.ReadAllText("Tools/Tests/journal_skill_preview_ui.lua"),"@Tools/Tests/journal_skill_preview_ui.lua")[0];}
        finally
        {
            lua.DoString("if CloseJournalSkillPreview then CloseJournalSkillPreview() end");
            lua.Global.Set<string,object>("CheckSkillPreview",null);lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();
        }
    }
}
finally{host.Shutdown();Time.timeScale=oldTime;UnityEngine.Random.state=oldRandom;UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
