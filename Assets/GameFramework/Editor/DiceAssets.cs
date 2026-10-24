using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ProjectY.UI;
using TMPro;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;
using Object = UnityEngine.Object;

namespace ProjectY.Editor
{
    /// <summary>Explicit import and editable UI asset generation. Never runs on domain reload.</summary>
    public static class DiceAssets
    {
        public const string Root = "Assets/DynamicAsset/Dice";
        public const string CatalogPath = Root + "/DiceCatalog.asset";
        private static readonly string[] Names = { "D4", "D6", "D8", "D10", "D100", "D12", "D20" };
        private static readonly Color Gold = new Color(.9f,.66f,.29f);

        [MenuItem("Project Y/UI/同步实体检定骰子")]
        public static void Sync()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Sync dice in Edit Mode.");
            foreach (var folder in new[] { Root, Root+"/Models", Root+"/Meshes", Root+"/Materials" }) PanelAssets.EnsureFolder(folder);
            var catalog = AssetDatabase.LoadAssetAtPath<DiceCatalog>(CatalogPath);
            if (catalog == null) { catalog = ScriptableObject.CreateInstance<DiceCatalog>(); AssetDatabase.CreateAsset(catalog,CatalogPath); }
            var models = new List<DiceCatalog.Die>();
            foreach (var name in Names) models.Add(Import(name));
            catalog.Dice = models.ToArray();
            catalog.Aura = Material("Aura", "ProjectY/DiceAura",new Color(.15f,.55f,1,.6f),0,0);
            EditorUtility.SetDirty(catalog);
            var config = PanelAssets.LoadOrCreate(); var entry = config.Entries.Find(value=>value.Name=="DiceRoll");
            if (entry == null) entry = PanelAssets.Save(new PanelDefinition { Name="DiceRoll",Module="Presentation",Kind=UIKind.Panel,
                Layer="Overlay",Modal=true,ModalDimAlpha=.78f,Cache=true,CloseOnBack=false,PauseWorldOnOpen=true,CloseOnSceneChange=true },null);
            PanelAssets.Generate(entry);
            var root = PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                if (root.transform.childCount==0) BuildPanel(root);
                var reference = root.GetComponent<LuaReference>();
                ((DiceRollView)reference.Get("Dice")).SetEditorBindings(catalog,(RawImage)reference.Get("Image"),
                    Enumerable.Range(0,6).Select(i=>(TMP_Text)reference.Get("Digit"+i)).ToArray());
                reference.ValidateBindings(); PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);
                LuaViewHints.Register(typeof(DiceRollView),"CS.ProjectY.UI.DiceRollView");
                LuaViewHints.Export(reference,entry.ViewType);
            }
            finally { PrefabUtility.UnloadPrefabContents(root); }
            AssetDatabase.SaveAssets();
            Debug.Log("Dice assets ready: D4, D6, D8, D10, D100, D12, D20 and DiceRoll Overlay.");
        }

        private static DiceCatalog.Die Import(string name)
        {
            string path=Root+"/Models/"+name+".fbx";
            var importer=AssetImporter.GetAtPath(path) as ModelImporter;
            if (importer==null) throw new InvalidOperationException("Missing dice model: "+path);
            if (importer.importAnimation || !importer.isReadable)
            { importer.importAnimation=false;importer.isReadable=true;importer.SaveAndReimport(); }
            var source=AssetDatabase.LoadAssetAtPath<GameObject>(path);
            var root=Object.Instantiate(source);root.transform.SetPositionAndRotation(Vector3.zero,Quaternion.identity);
            root.transform.localScale=Vector3.one;
            try
            {
                var gold=Material("Gold","Universal Render Pipeline/Lit",Gold,.7f,.7f);
                gold.EnableKeyword("_EMISSION");gold.SetColor("_EmissionColor",Gold*.18f);EditorUtility.SetDirty(gold);
                var jewel=Material("Aether","Universal Render Pipeline/Lit",new Color(.035f,.55f,.85f),.35f,.85f);
                jewel.EnableKeyword("_EMISSION");jewel.SetColor("_EmissionColor",new Color(.02f,.4f,.8f)*1.5f);EditorUtility.SetDirty(jewel);
                Color bodyColor;
                switch(name)
                {
                    case "D4":bodyColor=new Color(.18f,.025f,.06f);break;
                    case "D8":bodyColor=new Color(.018f,.16f,.095f);break;
                    case "D12":bodyColor=new Color(.12f,.035f,.23f);break;
                    case "D10":case "D100":bodyColor=new Color(.02f,.12f,.2f);break;
                    default:bodyColor=new Color(.035f,.065f,.2f);break;
                }
                var body=Material(name+"_Enamel","Universal Render Pipeline/Lit",bodyColor,.3f,.75f);
                body.EnableKeyword("_EMISSION");body.SetColor("_EmissionColor",bodyColor*.35f);EditorUtility.SetDirty(body);
                var materials=new[]{body,gold,jewel};var groups=new[]{new List<CombineInstance>(),new List<CombineInstance>(),new List<CombineInstance>()};
                Mesh hull=null;
                foreach(var filter in root.GetComponentsInChildren<MeshFilter>(true))
                {
                    var transform=root.transform.worldToLocalMatrix*filter.transform.localToWorldMatrix;
                    if(filter.name.EndsWith("_Collider",StringComparison.Ordinal))
                    { hull=new Mesh();hull.CombineMeshes(new[]{new CombineInstance{mesh=filter.sharedMesh,transform=transform}},true,true);continue; }
                    var renderer=filter.GetComponent<MeshRenderer>();
                    if(renderer==null)throw new InvalidOperationException("Dice mesh has no renderer: "+filter.name);
                    for(int i=0;i<filter.sharedMesh.subMeshCount;i++)
                    {
                        string material=renderer.sharedMaterials[i].name;
                        int slot=material.StartsWith("Dice_Gold",StringComparison.Ordinal)?1:material.StartsWith("Dice_Aether",StringComparison.Ordinal)?2:0;
                        groups[slot].Add(new CombineInstance{mesh=filter.sharedMesh,subMeshIndex=i,transform=transform});
                    }
                }
                if(hull==null)throw new InvalidOperationException("Dice collider hull missing: "+name);
                var merged=new List<Mesh>();
                try
                {
                    foreach(var group in groups){var mesh=new Mesh();mesh.CombineMeshes(group.ToArray(),true,true);merged.Add(mesh);}
                    var visual=new Mesh{name=name};visual.CombineMeshes(merged.Select(mesh=>new CombineInstance{mesh=mesh,transform=Matrix4x4.identity}).ToArray(),false,true);
                    var faces=new List<DiceCatalog.Face>();var markers=root.GetComponentsInChildren<Transform>(true);
                    string prefix=name+"_Face_";
                    foreach(var marker in markers.Where(t=>t.name.StartsWith(prefix,StringComparison.Ordinal)&&t.name.EndsWith("_Normal",StringComparison.Ordinal)))
                    {
                        int value=int.Parse(marker.name.Substring(prefix.Length,marker.name.Length-prefix.Length-7));
                        Vector3 Direction(string suffix)
                        { return root.transform.InverseTransformPoint(markers.Single(t=>t.name==prefix+value+"_"+suffix).position).normalized; }
                        faces.Add(new DiceCatalog.Face{Value=value,Normal=Direction("Normal"),Up=Direction("Up"),Axis=Direction("Axis")});
                    }
                    int sides=name=="D100"?10:int.Parse(name.Substring(1));
                    if(faces.Count!=sides)throw new InvalidOperationException("Wrong result face count: "+name);
                    hull.name=name+"_Hull";
                    return new DiceCatalog.Die{Name=name,Visual=SaveMesh(name,visual),Hull=SaveMesh(name+"_Hull",hull),Materials=materials,Faces=faces.ToArray()};
                }
                finally{foreach(var mesh in merged)Object.DestroyImmediate(mesh);}
            }
            finally{Object.DestroyImmediate(root);}
        }
        private static Mesh SaveMesh(string name,Mesh value)
        {
            string path=Root+"/Meshes/"+name+".asset";var existing=AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if(existing==null){AssetDatabase.CreateAsset(value,path);return value;}
            EditorUtility.CopySerialized(value,existing);Object.DestroyImmediate(value);EditorUtility.SetDirty(existing);return existing;
        }
        private static Material Material(string name,string shaderName,Color color,float metallic,float smoothness)
        {
            string path=Root+"/Materials/"+name+".mat";var value=AssetDatabase.LoadAssetAtPath<Material>(path);
            var shader=Shader.Find(shaderName);if(shader==null)throw new InvalidOperationException("Missing shader: "+shaderName);
            if(value==null){value=new Material(shader);AssetDatabase.CreateAsset(value,path);}else value.shader=shader;
            value.color=color;if(value.HasProperty("_BaseColor"))value.SetColor("_BaseColor",color);
            if(value.HasProperty("_Metallic"))value.SetFloat("_Metallic",metallic);
            if(value.HasProperty("_Smoothness"))value.SetFloat("_Smoothness",smoothness);
            EditorUtility.SetDirty(value);return value;
        }
        private static RectTransform Rect(string name,Transform parent,Vector2 min,Vector2 max,Vector2 lower,Vector2 upper)
        {
            var rect=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;rect.SetParent(parent,false);
            rect.anchorMin=min;rect.anchorMax=max;rect.offsetMin=lower;rect.offsetMax=upper;return rect;
        }
        private static TextMeshProUGUI Text(string name,Transform parent,string content,int size,Vector2 min,Vector2 max)
        {
            var rect=Rect(name,parent,min,max,Vector2.zero,Vector2.zero);var text=rect.gameObject.AddComponent<TextMeshProUGUI>();
            text.font=AssetDatabase.LoadAssetAtPath<TMP_FontAsset>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc.asset");
            if(text.font==null)throw new InvalidOperationException("Missing project CJK font.");
            text.text=content;text.fontSize=size;text.color=Gold;text.alignment=TextAlignmentOptions.Center;text.raycastTarget=false;return text;
        }
        private static Button Button(string name,Transform parent,string label,float left,float right)
        {
            var rect=Rect(name,parent,new Vector2(left,.065f),new Vector2(right,.14f),Vector2.zero,Vector2.zero);
            var image=rect.gameObject.AddComponent<Image>();image.color=new Color(.08f,.12f,.18f,.95f);
            var outline=rect.gameObject.AddComponent<Outline>();outline.effectColor=Gold;outline.effectDistance=Vector2.one;
            var button=rect.gameObject.AddComponent<Button>();button.targetGraphic=image;button.navigation=new Navigation{mode=Navigation.Mode.None};
            Text("Caption",rect,label,20,Vector2.zero,Vector2.one);return button;
        }
        private static void BuildPanel(GameObject root)
        {
            var rule=Rect("GoldRule",root.transform,new Vector2(.36f,.815f),new Vector2(.64f,.818f),Vector2.zero,Vector2.zero);
            rule.gameObject.AddComponent<Image>().color=Gold;
            var title=Text("Title",root.transform,"命运的回响",34,new Vector2(.1f,.84f),new Vector2(.9f,.94f));
            var detail=Text("Detail",root.transform,"掷出你的命运",17,new Vector2(.08f,.755f),new Vector2(.92f,.81f));
            detail.color=new Color(.72f,.78f,.85f);
            var dice=Rect("Dice",root.transform,new Vector2(.025f,.22f),new Vector2(.975f,.75f),Vector2.zero,Vector2.zero).gameObject.AddComponent<RawImage>();
            dice.raycastTarget=false;
            var result=Text("Result",root.transform,"",30,new Vector2(.1f,.17f),new Vector2(.9f,.255f));
            var next=Button("Continue",root.transform,"继续",.42f,.58f);
            var reveal=Button("Reveal",root.transform,"快速揭晓",.69f,.84f);
            var view=root.AddComponent<DiceRollView>();
            var reference=root.GetComponent<LuaReference>();var bindings=new List<LuaReference.Entry>(reference.GetEditorBindings());
            bindings.AddRange(new[]{new LuaReference.Entry("Dice",view),new LuaReference.Entry("Image",dice),new LuaReference.Entry("Title",title),
                new LuaReference.Entry("Detail",detail),new LuaReference.Entry("Result",result),new LuaReference.Entry("Continue",next),new LuaReference.Entry("Reveal",reveal)});
            for(int i=0;i<6;i++)
            {
                var label=Text("Digit"+i,dice.transform,"",15,new Vector2(.5f,.5f),new Vector2(.5f,.5f));
                label.rectTransform.sizeDelta=new Vector2(110,30);label.enabled=false;
                bindings.Add(new LuaReference.Entry("Digit"+i,label));
            }
            reference.SetEditorBindings(bindings.ToArray());
        }
    }
}
