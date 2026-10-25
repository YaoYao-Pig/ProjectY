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
                if(!bindings.Any(item=>item.Key=="TimeControls"))
                {
                    var controls=Rect("WorldControls",parent,0,0,356,42);
                    controls.anchorMin=controls.anchorMax=Vector2.one;controls.pivot=Vector2.one;controls.anchoredPosition=new Vector2(-148,-82);
                    var clock=Rect("TimeControls",controls,0,0,244,42);
                    bindings.Add(new LuaReference.Entry("TimeControls",clock));
                    Button("TimeStart","开始",clock,0,62,bindings);
                    Button("TimePause","暂停",clock,70,62,bindings);
                    Button("TimeSpeed","速度 1×",clock,140,104,bindings);
                    Button("Follow","回到小队",controls,252,104,bindings);
                }
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
            if(bindings.Any(item=>item.Key=="SiteTags"))return;
            var follow=(Button)bindings.Single(item=>item.Key=="Follow").Target;
            var copy=UnityEngine.Object.Instantiate(follow.gameObject,follow.transform.parent,false);
            copy.name="SiteTags";
            var rect=(RectTransform)copy.transform;
            rect.anchoredPosition=((RectTransform)follow.transform).anchoredPosition+new Vector2(0,-50);
            var button=copy.GetComponent<Button>();var image=button.targetGraphic;var colors=button.colors;
            UnityEngine.Object.DestroyImmediate(button);
            var toggle=copy.AddComponent<Toggle>();toggle.targetGraphic=image;toggle.colors=colors;
            toggle.navigation=new Navigation {mode=Navigation.Mode.None};toggle.isOn=true;
            var label=copy.GetComponentInChildren<Text>(true);
            label.text=LuaLanguage.Get("UIMainHudHideSiteTags");
            bindings.Add(new LuaReference.Entry("SiteTags",toggle));
            bindings.Add(new LuaReference.Entry("SiteTagsText",label));
            var localized=reference.GetEditorLocalizations().ToList();
            localized.Add(new LuaReference.LocalizedText(label,"UIMainHudHideSiteTags"));
            reference.SetEditorLocalizations(localized.ToArray());
        }
        private static RectTransform Rect(string name,Transform parent,float x,float y,float width,float height)
        {
            var rect=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;rect.gameObject.layer=5;
            rect.SetParent(parent,false);rect.anchorMin=rect.anchorMax=new Vector2(0,1);rect.pivot=new Vector2(0,1);
            rect.anchoredPosition=new Vector2(x,-y);rect.sizeDelta=new Vector2(width,height);return rect;
        }
        private static void Button(string key,string caption,Transform parent,float x,float width,List<LuaReference.Entry> bindings)
        {
            var rect=Rect(key,parent,x,0,width,42);var image=rect.gameObject.AddComponent<Image>();
            image.color=new Color(.09f,.13f,.12f,.96f);var border=rect.gameObject.AddComponent<Outline>();
            border.effectColor=new Color(.63f,.54f,.35f,.8f);border.effectDistance=new Vector2(1,-1);
            var button=rect.gameObject.AddComponent<Button>();button.targetGraphic=image;
            var colors=button.colors;colors.highlightedColor=new Color(1.22f,1.22f,1.1f,1);colors.disabledColor=new Color(.5f,.5f,.5f,.7f);button.colors=colors;
            var label=Rect("Label",rect,4,2,width-8,38).gameObject.AddComponent<Text>();
            label.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");label.fontSize=15;label.alignment=TextAnchor.MiddleCenter;
            label.color=new Color(.93f,.89f,.78f);label.raycastTarget=false;label.text=caption;
            bindings.Add(new LuaReference.Entry(key,button));bindings.Add(new LuaReference.Entry(key+"Text",label));
        }
    }
}
