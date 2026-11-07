using System;
using System.Collections.Generic;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    /// <summary>Persist the precision attack selector on the shared BattleHUD prefab.</summary>
    public static class AnatomyBattleHUDAssets
    {
        private static RectTransform Node(Transform parent,string name)
        {
            var existing=parent.Find(name) as RectTransform;
            if(existing!=null)return existing;
            var rect=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;
            rect.SetParent(parent,false);rect.gameObject.layer=5;return rect;
        }
        private static T Component<T>(RectTransform rect) where T:UnityEngine.Component
        {
            var component=rect.GetComponent<T>();
            return component!=null?component:rect.gameObject.AddComponent<T>();
        }
        private static void Bind(List<LuaReference.Entry> bindings,string key,UnityEngine.Component component)
        {bindings.RemoveAll(entry=>entry.Key==key);bindings.Add(new LuaReference.Entry(key,component));}
        private static Text Label(RectTransform parent,string name,Font font,int size,List<Text> labels)
        {
            var label=Component<Text>(Node(parent,name));label.font=font;label.fontSize=size;label.text="";
            label.color=new Color(.89f,.86f,.76f);label.raycastTarget=false;
            label.alignment=TextAnchor.MiddleCenter;label.horizontalOverflow=HorizontalWrapMode.Wrap;
            label.verticalOverflow=VerticalWrapMode.Truncate;label.resizeTextForBestFit=true;
            label.resizeTextMinSize=10;label.resizeTextMaxSize=size;
            if(!labels.Contains(label))labels.Add(label);return label;
        }
        private static void Stretch(RectTransform rect,float bottom,float height)
        {
            rect.anchorMin=new Vector2(0,0);rect.anchorMax=new Vector2(1,0);rect.pivot=Vector2.zero;
            rect.offsetMin=new Vector2(0,bottom);rect.offsetMax=new Vector2(0,bottom+height);
        }
        [MenuItem("Project Y/UI/同步精准打击部位选择")]
        public static void Sync()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode || EditorApplication.isCompiling)
                throw new InvalidOperationException("Anatomy HUD authoring requires idle Edit Mode.");
            var entry=PanelAssets.LoadOrCreate().Get("BattleHUD");
            var root=PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                var reference=root.GetComponent<LuaReference>();
                var hud=(BattleHUDView)reference.Get("HUD");var layout=hud.EditorLayout;
                var bindings=new List<LuaReference.Entry>(reference.GetEditorBindings());
                var labels=new List<Text>(layout.Labels);
                var panel=Node(layout.Deck,"AnatomyControls");
                panel.anchorMin=panel.anchorMax=panel.pivot=Vector2.zero;
                panel.anchoredPosition=new Vector2(14,32);panel.sizeDelta=new Vector2(layout.Deck.sizeDelta.x-28,198);
                var background=Component<Image>(panel);background.color=new Color(.055f,.063f,.062f,.99f);background.raycastTarget=true;
                var title=Label(panel,"AnatomyTitle",hud.Font,18,labels);Stretch(title.rectTransform,167,29);
                var help=Label(panel,"AnatomyHelp",hud.Font,12,labels);Stretch(help.rectTransform,0,30);
                Bind(bindings,"AnatomyPanel",panel);Bind(bindings,"AnatomyTitle",title);Bind(bindings,"AnatomyHelp",help);
                Bind(bindings,"SkillControls",layout.Skills);Bind(bindings,"ItemControls",layout.Items);
                for(int part=0;part<6;part++)
                {
                    var rect=Node(panel,"AnatomyPart"+part);int column=part%3,row=part/3;
                    rect.anchorMin=new Vector2(column/3f,0);rect.anchorMax=new Vector2((column+1)/3f,0);rect.pivot=Vector2.zero;
                    rect.offsetMin=new Vector2(column==0?0:3,101-row*61);rect.offsetMax=new Vector2(column==2?0:-3,156-row*61);
                    var image=Component<Image>(rect);image.color=new Color(.17f,.21f,.18f);
                    var button=Component<Button>(rect);button.targetGraphic=image;
                    button.navigation=new Navigation {mode=Navigation.Mode.None};
                    var colors=button.colors;colors.highlightedColor=new Color(1,.91f,.68f);colors.pressedColor=new Color(.7f,.76f,.68f);button.colors=colors;
                    var caption=Label(rect,"Label",hud.Font,17,labels);
                    caption.rectTransform.anchorMin=Vector2.zero;caption.rectTransform.anchorMax=Vector2.one;
                    caption.rectTransform.offsetMin=new Vector2(4,4);caption.rectTransform.offsetMax=new Vector2(-4,-4);
                    Bind(bindings,"AnatomyPart"+part,button);Bind(bindings,"AnatomyPart"+part+"Text",caption);
                }
                panel.gameObject.SetActive(false);layout.Anatomy=panel;layout.Labels=labels.ToArray();hud.SetEditorLayout(layout);
                reference.SetEditorBindings(bindings.ToArray());reference.ValidateBindings();
                PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);LuaViewHints.Export(reference,entry.ViewType);
            }
            finally {PrefabUtility.UnloadPrefabContents(root);}
        }
    }
}
