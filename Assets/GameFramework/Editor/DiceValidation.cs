using System;
using System.IO;
using System.Linq;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using Object=UnityEngine.Object;

namespace ProjectY.Editor
{
    public static class DiceValidation
    {
        [MenuItem("Project Y/UI/验证实体检定骰子")]
        public static void Validate()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Dice validation is Edit Mode only.");
            var catalog=AssetDatabase.LoadAssetAtPath<DiceCatalog>(DiceAssets.CatalogPath);
            if(catalog==null)throw new InvalidOperationException("Sync dice assets first.");
            foreach(var model in catalog.Dice)
            {
                var vertices=model.Hull.vertices;
                if(model.Visual.vertexCount==0||model.Hull.bounds.size.magnitude>3||model.Hull.bounds.size.magnitude<1)
                    throw new InvalidOperationException("Invalid dice mesh/scale: "+model.Name);
                foreach(var a in model.Faces)foreach(var b in model.Faces)
                {
                    var symmetry=b.Frame*Quaternion.Inverse(a.Frame);
                    foreach(var vertex in vertices)
                        if(!vertices.Any(v=>(symmetry*vertex-v).sqrMagnitude<.00001f))
                            throw new InvalidOperationException("Number remapping changes silhouette: "+model.Name+" "+a.Value+" -> "+b.Value);
                }
            }
            int sceneCount=SceneManager.sceneCount;
            int previewCount=UnityEditor.SceneManagement.EditorSceneManager.previewSceneCount;
            var root=Object.Instantiate(PanelAssets.LoadOrCreate().Get("DiceRoll").Prefab);
            root.GetComponent<Canvas>().enabled=false;
            var reference=root.GetComponent<LuaReference>();
            var image=(RawImage)reference.Get("Image");image.rectTransform.anchorMin=image.rectTransform.anchorMax=new Vector2(.5f,.5f);
            image.rectTransform.sizeDelta=new Vector2(1280,620);
            var view=(DiceRollView)reference.Get("Dice");
            string output="Art/Dice/UnityPreview";Directory.CreateDirectory(output);
            try
            {
                using(var lua=new XLua.LuaEnv())
                {
                    lua.Global.Set("diceView",view);
                    lua.DoString("diceView:Prepare(); diceView:AddDie('D20',20); diceView:AddDie('D10',8); diceView:AddDie('D4',4); diceView:AddDie('D6',6); diceView:AddDie('D8',8); diceView:AddDie('D12',12); diceView:Throw(20261024)");
                    ValidateThrow(view);
                    var targets=new[]{20,8,4,6,8,12};
                    for(int frame=0;frame<40;frame++)
                    {
                        view.Advance(.075f);
                        if(frame==5)ValidateFlightTime(view,.45f);
                        if(frame%2==0)Save(image.texture as RenderTexture,output+"/roll-"+(frame/2).ToString("D2")+".png");
                    }
                    if(!view.Settled||view.SampleCount<90)throw new InvalidOperationException("Dice trajectory did not settle.");
                    for(int i=0;i<targets.Length;i++)if(view.VisibleValue(i)!=targets[i])throw new InvalidOperationException("Visible face differs from settled result at "+i);
                    Save(image.texture as RenderTexture,output+"/settled.png");
                    lua.DoString("diceView:Release(); diceView:Prepare(); diceView:AddDie('D100',0); diceView:AddDie('D10',0); diceView:Throw(37); diceView:Reveal()");
                    if(view.VisibleValue(0)!=0||view.VisibleValue(1)!=0||!view.Settled)throw new InvalidOperationException("Percentile zero/skip check failed.");
                    lua.DoString("diceView:Release()");lua.Global.Set("diceView",(object)null);
                }
            }
            finally{view.Release();Object.DestroyImmediate(root);}
            if(SceneManager.sceneCount!=sceneCount)throw new InvalidOperationException("Dice scene leaked.");
            if(UnityEditor.SceneManagement.EditorSceneManager.previewSceneCount!=previewCount)throw new InvalidOperationException("Dice preview scene leaked.");
            var definition=PanelAssets.LoadOrCreate().Get("DiceRoll");definition.Validate(true);
            if(!definition.Modal||!definition.PauseWorldOnOpen||definition.Layer!="Overlay"||definition.CloseOnBack)
                throw new InvalidOperationException("Dice UI input/pause contract is incorrect.");
            Debug.Log("PASS dice meshes/symmetries, compact launch, forward flight at physical speed, all seven die readings, xLua calls, skip/reopen, stage cleanup and Overlay bindings. Previews: "+output);
        }
        private static object Field(object target,string name)
        {
            var field=target.GetType().GetField(name,System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic);
            if(field==null)throw new InvalidOperationException("Missing dice validation field: "+name);
            return field.GetValue(target);
        }
        private static void ValidateThrow(DiceRollView view)
        {
            var dice=(System.Collections.IList)Field(view,"dice");
            var camera=(Camera)Field(view,"cameraView");
            float minX=float.MaxValue,maxX=float.MinValue;
            foreach(var die in dice)
            {
                var positions=(System.Collections.Generic.List<Vector3>)Field(die,"Positions");
                var start=positions[0];var end=positions[positions.Count-1];
                minX=Mathf.Min(minX,start.x);maxX=Mathf.Max(maxX,start.x);
                if(end.x-start.x<6)throw new InvalidOperationException("Dice need a forward throw, not an in-place spin.");
                int contact=(int)Field(die,"FirstContactSample"),release=(int)Field(die,"ReleaseSample");
                if(contact<=release+4)throw new InvalidOperationException("Dice did not fly before landing.");
                if(camera.WorldToViewportPoint(start).x>.15f)throw new InvalidOperationException("Dice must enter from the side of the composition.");
            }
            if(maxX-minX>.4f)throw new InvalidOperationException("Dice are spread across the table before the throw.");
        }
        private static void ValidateFlightTime(DiceRollView view,float seconds)
        {
            foreach(var die in (System.Collections.IList)Field(view,"dice"))
            {
                var positions=(System.Collections.Generic.List<Vector3>)Field(die,"Positions");
                var body=(Rigidbody)Field(die,"Body");
                if(Vector3.Distance(body.transform.position,positions[Mathf.RoundToInt(seconds*60)])>.01f)
                    throw new InvalidOperationException("Initial flight was compressed with the settling tail.");
            }
        }
        private static void Save(RenderTexture texture,string path)
        {
            var previous=RenderTexture.active;var pixels=new Texture2D(texture.width,texture.height,TextureFormat.RGBA32,false);
            try{RenderTexture.active=texture;pixels.ReadPixels(new Rect(0,0,texture.width,texture.height),0,0);pixels.Apply();File.WriteAllBytes(path,pixels.EncodeToPNG());}
            finally{RenderTexture.active=previous;Object.DestroyImmediate(pixels);}
        }
    }
}
