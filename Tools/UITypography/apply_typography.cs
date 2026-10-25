// Explicit, repeatable font-only migration. No C# project compilation or scene mutation.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling||UnityEditor.EditorApplication.isUpdating)
    throw new System.InvalidOperationException("Typography requires idle Edit Mode");
var manifest=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Tools/UITypography/roles.json"));
var folder="Assets/DynamicAsset/UI/Fonts/";
var sources=new System.Collections.Generic.Dictionary<string,UnityEngine.Font>{
    {"title",UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Font>(folder+"SourceHanSerifSC-SemiBold.otf")},
    {"body",UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Font>(folder+"LXGWWenKai-Regular.ttf")}};
var rich=new System.Collections.Generic.Dictionary<string,TMPro.TMP_FontAsset>{
    {"title",UnityEditor.AssetDatabase.LoadAssetAtPath<TMPro.TMP_FontAsset>(folder+"SourceHanSerifSC-SemiBold.asset")},
    {"body",UnityEditor.AssetDatabase.LoadAssetAtPath<TMPro.TMP_FontAsset>(folder+"LXGWWenKai-Regular.asset")}};
if(sources.Values.Any(f=>f==null)||rich.Values.Any(f=>f==null))throw new System.InvalidOperationException("Import typography fonts first");
var records=new System.Collections.Generic.List<object>();
foreach(var entry in ((Newtonsoft.Json.Linq.JObject)manifest["roles"]).Properties())
{
    var path=(string)manifest["prefabRoot"]+entry.Name+".prefab";
    var root=UnityEditor.PrefabUtility.LoadPrefabContents(path);
    try
    {
        var targets=new System.Collections.Generic.Dictionary<UnityEngine.Component,string>();
        foreach(var role in ((Newtonsoft.Json.Linq.JObject)entry.Value).Properties())foreach(var node in role.Value)
        {
            var transform=root.transform.Find((string)node);
            if(transform==null)throw new System.InvalidOperationException(path+": missing "+node);
            UnityEngine.Component text=transform.GetComponent<UnityEngine.UI.Text>();
            if(text==null)text=transform.GetComponent<TMPro.TMP_Text>();
            if(text==null)throw new System.InvalidOperationException(path+": text component missing "+node);
            targets.Add(text,role.Name);
        }
        // These arrays are existing font-override lists, not layout or business bindings.
        var arrays=new System.Collections.Generic.Dictionary<UnityEngine.Component,string[]>();
        foreach(var view in root.GetComponents<ProjectY.UI.NarrativeView>())arrays.Add(view,new[]{"labels","richLabels"});
        foreach(var view in root.GetComponents<ProjectY.UI.StoryGrowthView>())arrays.Add(view,new[]{"labels"});
        foreach(var view in root.GetComponents<ProjectY.UI.InventoryPanelView>())arrays.Add(view,new[]{"layout.Labels"});
        foreach(var view in root.GetComponents<ProjectY.UI.EquipmentWorkbenchView>())arrays.Add(view,new[]{"layout.Labels"});
        System.Func<string> snapshot=()=>
        {
            var rows=new System.Collections.Generic.List<string>();
            foreach(var c in root.GetComponentsInChildren<UnityEngine.Component>(true))
            {
                if(c==null)throw new System.InvalidOperationException("Missing script in "+path);
                var json=Newtonsoft.Json.Linq.JObject.Parse(UnityEditor.EditorJsonUtility.ToJson(c));
                var fields=(Newtonsoft.Json.Linq.JObject)json.Properties().First().Value;
                if(targets.ContainsKey(c))
                {
                    if(c is UnityEngine.UI.Text){var data=(Newtonsoft.Json.Linq.JObject)fields["m_FontData"];data.Remove("m_Font");data.Remove("m_FontStyle");}
                    else{fields.Remove("m_fontAsset");fields.Remove("m_sharedMaterial");fields.Remove("m_fontStyle");}
                }
                if(arrays.ContainsKey(c))foreach(var array in arrays[c])
                {
                    var parts=array.Split('.');var container=fields;
                    for(int i=0;i<parts.Length-1;i++)container=(Newtonsoft.Json.Linq.JObject)container[parts[i]];
                    container.Remove(parts[parts.Length-1]);
                }
                rows.Add(c.GetInstanceID()+":"+json.ToString(Newtonsoft.Json.Formatting.None));
            }
            return string.Join("\n",rows.ToArray());
        };
        var before=snapshot();var removed=0;
        foreach(var target in targets)
        {
            var text=target.Key as UnityEngine.UI.Text;
            if(text!=null)
            {
                text.font=sources[target.Value];
                if(text.fontStyle==UnityEngine.FontStyle.Bold)text.fontStyle=UnityEngine.FontStyle.Normal;
                else if(text.fontStyle==UnityEngine.FontStyle.BoldAndItalic)text.fontStyle=UnityEngine.FontStyle.Italic;
            }
            else
            {
                var tmp=(TMPro.TMP_Text)target.Key;tmp.font=rich[target.Value];tmp.fontSharedMaterial=tmp.font.material;
                tmp.fontStyle&=~TMPro.FontStyles.Bold;
            }
        }
        foreach(var view in arrays)
        {
            var serialized=new UnityEditor.SerializedObject(view.Key);
            foreach(var field in view.Value)
            {
                var list=serialized.FindProperty(field);
                if(list==null||!list.isArray)throw new System.InvalidOperationException("Missing font override array: "+field);
                var keep=new System.Collections.Generic.List<UnityEngine.Object>();
                for(int i=0;i<list.arraySize;i++)
                {
                    var value=list.GetArrayElementAtIndex(i).objectReferenceValue;
                    if(targets.ContainsKey((UnityEngine.Component)value))removed++;else keep.Add(value);
                }
                list.arraySize=keep.Count;
                for(int i=0;i<keep.Count;i++)list.GetArrayElementAtIndex(i).objectReferenceValue=keep[i];
            }
            serialized.ApplyModifiedPropertiesWithoutUndo();
        }
        if(before!=snapshot())throw new System.InvalidOperationException("Non-font fields changed in "+path);
        foreach(var reference in root.GetComponentsInChildren<ProjectY.UI.LuaReference>(true))reference.ValidateBindings();
        UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,path);
        records.Add(new{prefab=path,labels=targets.Select(t=>new{path=UnityEditor.AnimationUtility.CalculateTransformPath(t.Key.transform,root.transform),role=t.Value,type=t.Key.GetType().Name}).ToArray(),removedFontOverrides=removed,nonFontStatePreserved=true});
    }
    finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
}
var output="Art/UITypography/2026-10-25/application.json";
System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(output));
System.IO.File.WriteAllText(output,Newtonsoft.Json.JsonConvert.SerializeObject(records,Newtonsoft.Json.Formatting.Indented));
return new{prefabs=records.Count,report=output};
