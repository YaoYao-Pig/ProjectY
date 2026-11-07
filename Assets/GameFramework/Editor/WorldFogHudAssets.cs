using System;
using System.Collections.Generic;
using System.Linq;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    public static class WorldFogHudAssets
    {
        [MenuItem("Project Y/UI/同步大地图地点标签开关")]
        public static void SyncSiteTags() => Sync();

        [MenuItem("Project Y/UI/同步大地图时间与小队定位按钮")]
        public static void Sync()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Edit Mode required.");
            var entry=PanelAssets.LoadOrCreate().Entries.Single(item=>item.Name=="MainHud");
            var root=PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                var reference=root.GetComponent<LuaReference>();var bindings=reference.GetEditorBindings().ToList();
                var hud=root.GetComponent<MainHudView>();var fields=new SerializedObject(hud);
                var parent=(RectTransform)fields.FindProperty("layout.Common").objectReferenceValue;
                if(parent==null)throw new InvalidOperationException("MainHud Common binding is missing.");
                if(Bound<RectTransform>(bindings,"TimeControls")==null)
                {
                    var follow=Bound<Button>(bindings,"Follow");
                    var controls=follow!=null?(RectTransform)follow.transform.parent:Rect("WorldControls",parent,0,0,356,42);
                    if(!controls.IsChildOf(parent))throw new InvalidOperationException("MainHud WorldControls must belong to Common.");
                    if(follow==null){controls.anchorMin=controls.anchorMax=Vector2.one;controls.pivot=Vector2.one;controls.anchoredPosition=new Vector2(-148,-82);}
                    var clock=Rect("TimeControls",controls,0,0,244,42);
                    Bind(bindings,"TimeControls",clock);
                    Button("TimeStart","UIMainHudPanelCommonWorldControlsTimeControlsTimeStartLabel",clock,0,62,reference,bindings);
                    Button("TimePause","UIMainHudPanelCommonWorldControlsTimeControlsTimePauseLabel",clock,70,62,reference,bindings);
                    Button("TimeSpeed","UIMainHudPanelCommonWorldControlsTimeControlsTimeSpeedLabel",clock,140,104,reference,bindings);
                    Button("Follow","UIMainHudPanelCommonWorldControlsFollowLabel",controls,252,104,reference,bindings);
                }
                foreach(var key in new[]{"TimeStart","TimePause","TimeSpeed","Follow"})
                    if(Bound<Button>(bindings,key)==null||Bound<Text>(bindings,key+"Text")==null)throw new InvalidOperationException("MainHud time-control bindings are incomplete: "+key);
                BuildSiteTags(reference,bindings);
                reference.SetEditorBindings(bindings.ToArray());
                var labels=fields.FindProperty("layout.Labels");var texts=root.GetComponentsInChildren<Text>(true);
                labels.arraySize=texts.Length;
                for(int i=0;i<texts.Length;i++)labels.GetArrayElementAtIndex(i).objectReferenceValue=texts[i];
                fields.ApplyModifiedPropertiesWithoutUndo();reference.ValidateBindings();
                PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);LuaViewHints.Export(reference,entry.ViewType);
            }
            finally{PrefabUtility.UnloadPrefabContents(root);}
        }
        private static void BuildSiteTags(LuaReference reference,List<LuaReference.Entry> bindings)
        {
            if(Bound<Toggle>(bindings,"SiteTags")!=null)
            {
                if(Bound<Text>(bindings,"SiteTagsText")==null)throw new InvalidOperationException("MainHud SiteTagsText binding is missing.");
                return;
            }
            var follow=Bound<Button>(bindings,"Follow");
            if(follow==null)throw new InvalidOperationException("MainHud Follow binding is missing.");
            var existing=follow.transform.parent.Find("SiteTags");Toggle toggle;
            if(existing!=null)
            {
                toggle=existing.GetComponent<Toggle>();
                if(toggle==null)throw new InvalidOperationException("Existing MainHud SiteTags is not a Toggle.");
            }
            else
            {
                var copy=UnityEngine.Object.Instantiate(follow.gameObject,follow.transform.parent,false);copy.name="SiteTags";
                var rect=(RectTransform)copy.transform;rect.anchoredPosition=((RectTransform)follow.transform).anchoredPosition+new Vector2(0,-50);
                var button=copy.GetComponent<Button>();var image=button.targetGraphic;var colors=button.colors;
                UnityEngine.Object.DestroyImmediate(button);toggle=copy.AddComponent<Toggle>();toggle.targetGraphic=image;toggle.colors=colors;
                toggle.navigation=new Navigation {mode=Navigation.Mode.None};toggle.isOn=true;
            }
            var label=toggle.GetComponentInChildren<Text>(true);
            if(label==null)throw new InvalidOperationException("MainHud SiteTags label is missing.");
            label.text=LuaLanguage.Get("UIMainHudHideSiteTags");
            Bind(bindings,"SiteTags",toggle);Bind(bindings,"SiteTagsText",label);
            var localized=reference.GetEditorLocalizations().ToList();
            localized.RemoveAll(item=>item.Target==label);
            localized.Add(new LuaReference.LocalizedText(label,"UIMainHudHideSiteTags"));
            reference.SetEditorLocalizations(localized.ToArray());
        }
        private static T Bound<T>(List<LuaReference.Entry> bindings,string key) where T:Component
        {
            var entry=bindings.SingleOrDefault(item=>item.Key==key);
            if(entry.Key==null)return null;
            if(entry.Target is T component)return component;
            throw new InvalidOperationException("Invalid MainHud binding: "+key);
        }
        private static void Bind(List<LuaReference.Entry> bindings,string key,Component target)
        {bindings.RemoveAll(item=>item.Key==key);bindings.Add(new LuaReference.Entry(key,target));}
        private static RectTransform Rect(string name,Transform parent,float x,float y,float width,float height)
        {
            var existing=parent.Find(name)??parent.Find(name+"Motion/"+name);
            if(existing!=null)return (RectTransform)existing;
            var rect=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;rect.gameObject.layer=5;
            rect.SetParent(parent,false);rect.anchorMin=rect.anchorMax=new Vector2(0,1);rect.pivot=new Vector2(0,1);
            rect.anchoredPosition=new Vector2(x,-y);rect.sizeDelta=new Vector2(width,height);return rect;
        }
        private static void Button(string key,string textId,Transform parent,float x,float width,LuaReference reference,List<LuaReference.Entry> bindings)
        {
            if(Bound<Button>(bindings,key)!=null)return;
            var rect=Rect(key,parent,x,0,width,42);var image=rect.GetComponent<Image>()??rect.gameObject.AddComponent<Image>();
            image.color=new Color(.09f,.13f,.12f,.96f);var border=rect.GetComponent<Outline>()??rect.gameObject.AddComponent<Outline>();
            border.effectColor=new Color(.63f,.54f,.35f,.8f);border.effectDistance=new Vector2(1,-1);
            var button=rect.GetComponent<Button>()??rect.gameObject.AddComponent<Button>();button.targetGraphic=image;
            var colors=button.colors;colors.highlightedColor=new Color(1.22f,1.22f,1.1f,1);colors.disabledColor=new Color(.5f,.5f,.5f,.7f);button.colors=colors;
            var labelRect=Rect("Label",rect,4,2,width-8,38);var label=labelRect.GetComponent<Text>()??labelRect.gameObject.AddComponent<Text>();
            label.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");label.fontSize=15;label.alignment=TextAnchor.MiddleCenter;
            label.color=new Color(.93f,.89f,.78f);label.raycastTarget=false;label.text=LuaLanguage.Get(textId);
            Bind(bindings,key,button);Bind(bindings,key+"Text",label);
            var localized=reference.GetEditorLocalizations().ToList();localized.RemoveAll(item=>item.Target==label);
            localized.Add(new LuaReference.LocalizedText(label,textId));reference.SetEditorLocalizations(localized.ToArray());
        }
    }
}
