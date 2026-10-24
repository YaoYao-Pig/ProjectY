using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json;
using ProjectY.UI;
using TMPro;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    public static class UILocalizationAssets
    {
        private sealed class Binding { public string prefab,node,type,text,id; }
        private const string Manifest="Art/Localization/ui-text-bindings.json";

        [MenuItem("Project Y/UI/同步 UI 多语言绑定")]
        public static void Sync()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("UI language bindings require Edit Mode.");
            LuaLanguage.ReloadDefaults();
            var bindings=JsonConvert.DeserializeObject<Binding[]>(File.ReadAllText(Manifest));
            foreach(var group in bindings.GroupBy(row=>row.prefab))
            {
                if(!group.Key.StartsWith(PanelConfig.PrefabRoot+"/",StringComparison.Ordinal))throw new InvalidDataException("Unexpected UI prefab path: "+group.Key);
                var root=PrefabUtility.LoadPrefabContents(group.Key);
                try
                {
                    var reference=root.GetComponent<LuaReference>();
                    if(reference==null)throw new InvalidOperationException("UI prefab needs LuaReference: "+group.Key);
                    var entries=new List<LuaReference.LocalizedText>(reference.GetEditorLocalizations());
                    foreach(var row in group)
                    {
                        LuaLanguage.Get(row.id);
                        var node=string.IsNullOrEmpty(row.node)?root.transform:root.transform.Find(row.node);
                        if(node==null)throw new InvalidOperationException("Missing UI language target: "+row.node);
                        Component target=row.type=="Text"?(Component)node.GetComponent<Text>():node.GetComponent<TMP_Text>();
                        if(target==null)throw new InvalidOperationException("UI text component changed: "+row.node);
                        string current=target is Text legacy?legacy.text:((TMP_Text)target).text;
                        if(current!=row.text && !entries.Any(entry=>entry.Target==target&&entry.Id==row.id))
                            throw new InvalidOperationException("UI text changed since audit; review before binding: "+group.Key+" / "+row.node);
                        entries.RemoveAll(entry=>entry.Target==target);
                        entries.Add(new LuaReference.LocalizedText(target,row.id));
                    }
                    reference.SetEditorLocalizations(entries.ToArray());
                    PrefabUtility.SaveAsPrefabAsset(root,group.Key);
                }
                finally{PrefabUtility.UnloadPrefabContents(root);}
            }
            AssetDatabase.SaveAssets();
            Debug.Log("UI language bindings saved through Unity: "+bindings.Length);
        }
        [MenuItem("Project Y/UI/验证 UI 多语言绑定")]
        public static void Validate()
        {
            var failures=new List<string>();int labels=0;
            foreach(var guid in AssetDatabase.FindAssets("t:Prefab",new[]{PanelConfig.PrefabRoot}))
            {
                string path=AssetDatabase.GUIDToAssetPath(guid);var prefab=AssetDatabase.LoadAssetAtPath<GameObject>(path);
                var reference=prefab.GetComponent<LuaReference>();
                if(reference==null)throw new InvalidOperationException("UI prefab needs LuaReference: "+path);
                var bindings=reference.GetEditorLocalizations();
                foreach(var binding in bindings)
                {
                    if(binding.Target==null)failures.Add(path+": missing "+binding.Id);
                    LuaLanguage.Get(binding.Id);labels++;
                }
                foreach(var component in prefab.GetComponentsInChildren<Component>(true))
                {
                    var tmp=component as TMP_Text;var legacy=component as Text;
                    string text=tmp!=null?tmp.text:legacy!=null?legacy.text:null;
                    if(text==null||!System.Text.RegularExpressions.Regex.IsMatch(text,@"\p{IsCJKUnifiedIdeographs}"))continue;
                    if(component is UITxt localized&&!string.IsNullOrEmpty(localized.LocalizationId))continue;
                    if(!bindings.Any(binding=>binding.Target==component))failures.Add(path+" / "+component.name+": "+text);
                }
            }
            if(failures.Count>0)throw new InvalidOperationException("UI text lacks language bindings:\n"+string.Join("\n",failures));
            Debug.Log("PASS UI prefab language coverage: "+labels+" bindings.");
        }
    }
}
