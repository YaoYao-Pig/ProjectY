using System;
using System.Collections.Generic;
using System.IO;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    public static class BankAssets
    {
        [MenuItem("Project Y/经济/同步银行界面")]
        public static void Sync()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Bank asset authoring requires Edit Mode.");
            var config=PanelAssets.LoadOrCreate();var entry=config.Entries.Find(e=>e.Name=="Bank");
            if(entry==null)entry=PanelAssets.Save(new PanelDefinition{Name="Bank",Module="Economy",Kind=UIKind.Panel,Layer="Popup",Modal=true,ModalDimAlpha=.65f,Cache=true,CloseOnBack=true,PauseWorldOnOpen=true},null);
            if(entry.Prefab!=null)return;
            Directory.CreateDirectory(Path.GetDirectoryName(entry.PrefabPath));
            var root=new GameObject(entry.PrefabName,typeof(RectTransform),typeof(LuaReference),typeof(LuaPanel));
            try
            {
                var bindings=new List<LuaReference.Entry>();Action<string,Component> bind=(key,c)=>bindings.Add(new LuaReference.Entry(key,c));
                var page=Node("Page",root.transform,0,0,1120,640);page.anchorMin=page.anchorMax=page.pivot=new Vector2(.5f,.5f);page.anchoredPosition=Vector2.zero;
                Paint(page,new Color(.055f,.08f,.075f,.99f));
                bind("Root",root.transform);
                Text Label(string key,float x,float y,float w,float h,int size,Color color)
                {
                    var rect=Node(key,page,x,y,w,h);var label=rect.gameObject.AddComponent<Text>();label.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
                    label.fontSize=size;label.color=color;label.raycastTarget=false;label.supportRichText=false;label.horizontalOverflow=HorizontalWrapMode.Wrap;
                    label.verticalOverflow=VerticalWrapMode.Truncate;bind(key,label);return label;
                }
                void Button(string key,float x,float y,float w,float h)
                {
                    var rect=Node(key,page,x,y,w,h);var image=Paint(rect,new Color(.18f,.25f,.21f));var button=rect.gameObject.AddComponent<Button>();button.targetGraphic=image;
                    button.navigation=new Navigation{mode=Navigation.Mode.None};bind(key,button);
                    var label=Label(key+"Label",x+5,y+3,w-10,h-6,16,new Color(.94f,.88f,.72f));label.alignment=TextAnchor.MiddleCenter;
                }
                var paper=new Color(.88f,.88f,.80f);var muted=new Color(.59f,.69f,.64f);var gold=new Color(.91f,.77f,.48f);
                Label("Title",28,16,970,44,24,gold);Label("Caption",28,65,1040,28,18,paper);Label("Tags",28,102,1045,42,14,muted);
                Button("Close",1020,20,72,34);
                Paint(Node("Divider",page,777,158,1,432),new Color(.3f,.4f,.32f));
                Label("Legend",28,155,720,26,14,muted);
                var chartRect=Node("Chart",page,85,200,650,275);chartRect.gameObject.AddComponent<CanvasRenderer>();
                var chart=chartRect.gameObject.AddComponent<BankChartGraphic>();chart.raycastTarget=true;bind("Chart",chart);
                Label("AxisHigh",15,194,65,24,13,muted);Label("AxisLow",15,455,65,24,13,muted);
                Label("DateRange",85,478,650,22,13,muted);Label("OHLC",28,510,720,52,15,paper);
                Button("Range",28,569,166,34);
                Label("Position",805,160,278,180,18,paper);Label("Risk",805,347,278,145,15,gold);
                Button("InvestSmall",805,506,132,38);Button("InvestLarge",951,506,132,38);Button("Claim",805,555,278,40);
                Label("Hint",28,610,1050,24,13,muted);
                var style=root.AddComponent<NarrativeView>();style.SetEditorBindings(page,null,root.GetComponentsInChildren<Text>(true),false);bind("Style",style);
                var reference=root.GetComponent<LuaReference>();reference.SetEditorBindings(bindings.ToArray());reference.ValidateBindings();
                entry.Prefab=PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);EditorUtility.SetDirty(config);
                LuaViewHints.Register(typeof(NarrativeView),"CS.ProjectY.UI.NarrativeView");
                LuaViewHints.Register(typeof(BankChartGraphic),"CS.ProjectY.UI.BankChartGraphic");LuaViewHints.Export(reference,entry.ViewType);AssetDatabase.SaveAssets();
            }
            finally{UnityEngine.Object.DestroyImmediate(root);}
        }
        private static RectTransform Node(string name,Transform parent,float x,float y,float width,float height)
        {
            var rect=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;rect.SetParent(parent,false);
            rect.anchorMin=rect.anchorMax=rect.pivot=new Vector2(0,1);rect.anchoredPosition=new Vector2(x,-y);rect.sizeDelta=new Vector2(width,height);return rect;
        }
        private static Image Paint(RectTransform rect,Color color){var image=rect.gameObject.AddComponent<Image>();image.color=color;return image;}
    }
}
