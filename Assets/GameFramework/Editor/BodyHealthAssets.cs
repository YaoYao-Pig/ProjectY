using System;
using System.Collections.Generic;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    /// <summary>Add the body-health view to the existing inventory without replacing its authored layout.</summary>
    public static class BodyHealthAssets
    {
        private static readonly Color Paper = new Color(.92f,.94f,.94f), Gold = new Color(.88f,.73f,.43f);
        private static RectTransform Box(string name,Transform parent,float x,float y,float width,float height)
        {
            var node = new GameObject(name,typeof(RectTransform));
            var rect = (RectTransform)node.transform;rect.SetParent(parent,false);
            rect.anchorMin=rect.anchorMax=rect.pivot=new Vector2(0,1);
            rect.anchoredPosition=new Vector2(x,-y);rect.sizeDelta=new Vector2(width,height);return rect;
        }
        private static Text Label(string name,Transform parent,float x,float y,float width,float height,int size)
        {
            var text=Box(name,parent,x,y,width,height).gameObject.AddComponent<Text>();
            text.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");text.fontSize=size;text.color=Paper;
            text.supportRichText=true;text.raycastTarget=false;return text;
        }
        private static Button Button(string name,Transform parent,float x,float y,float width,float height,
            List<LuaReference.Entry> bindings,List<LuaReference.LocalizedText> localized,string languageKey)
        {
            var rect=Box(name,parent,x,y,width,height);var image=rect.gameObject.AddComponent<Image>();
            image.color=new Color(.16f,.22f,.24f);var button=rect.gameObject.AddComponent<Button>();button.targetGraphic=image;
            button.navigation=new Navigation {mode=Navigation.Mode.None};
            var label=Label("Label",rect,6,3,width-12,height-6,14);label.alignment=TextAnchor.MiddleCenter;
            label.text=LuaLanguage.Get(languageKey);bindings.Add(new LuaReference.Entry(name,button));bindings.Add(new LuaReference.Entry(name+"Text",label));
            localized.Add(new LuaReference.LocalizedText(label,languageKey));return button;
        }
        private static void Scroll(string key,RectTransform parent,Text text,float y,float height,List<LuaReference.Entry> bindings)
        {
            if(bindings.Exists(e=>e.Key==key))return;
            var root=Box(key,parent,244,y,280,height);
            root.gameObject.AddComponent<Image>().color=new Color(.065f,.085f,.105f,.7f);
            var viewport=Box("Viewport",root,5,4,260,height-8);viewport.gameObject.AddComponent<RectMask2D>();
            var hit=viewport.gameObject.AddComponent<Image>();hit.color=Color.clear;
            var scroll=root.gameObject.AddComponent<ScrollRect>();scroll.horizontal=false;scroll.vertical=true;scroll.inertia=false;
            scroll.movementType=ScrollRect.MovementType.Clamped;scroll.scrollSensitivity=28;
            var content=text.rectTransform;content.SetParent(viewport,false);
            content.anchorMin=new Vector2(0,1);content.anchorMax=Vector2.one;content.pivot=new Vector2(0,1);
            content.anchoredPosition=Vector2.zero;content.sizeDelta=Vector2.zero;
            text.horizontalOverflow=HorizontalWrapMode.Wrap;text.verticalOverflow=VerticalWrapMode.Overflow;text.lineSpacing=1.16f;
            var fitter=text.gameObject.AddComponent<ContentSizeFitter>();fitter.verticalFit=ContentSizeFitter.FitMode.PreferredSize;
            var barRect=Box("Scrollbar",root,270,3,7,height-6);barRect.gameObject.AddComponent<Image>().color=new Color(.11f,.15f,.17f);
            var bar=barRect.gameObject.AddComponent<Scrollbar>();bar.direction=Scrollbar.Direction.BottomToTop;
            var handle=Box("Handle",barRect,0,0,7,height-6);var image=handle.gameObject.AddComponent<Image>();image.color=new Color(.45f,.55f,.58f);
            handle.anchorMin=Vector2.zero;handle.anchorMax=Vector2.one;handle.offsetMin=handle.offsetMax=Vector2.zero;
            bar.handleRect=handle;bar.targetGraphic=image;scroll.viewport=viewport;scroll.content=content;scroll.verticalScrollbar=bar;
            scroll.verticalScrollbarVisibility=ScrollRect.ScrollbarVisibility.AutoHide;
            bindings.Add(new LuaReference.Entry(key,scroll));
        }
        [MenuItem("Project Y/装备/同步身体健康界面")]
        public static void Sync()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Health UI authoring requires Edit Mode.");
            var entry=PanelAssets.LoadOrCreate().Entries.Find(e=>e.Name=="Inventory");
            if(entry==null)throw new InvalidOperationException("Inventory must already exist.");
            var root=PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                var reference=root.GetComponent<LuaReference>();
                var bindings=new List<LuaReference.Entry>(reference.GetEditorBindings());
                var localized=new List<LuaReference.LocalizedText>(reference.GetEditorLocalizations());
                if(!bindings.Exists(e=>e.Key=="HealthOverlay"))
                {
                    var character=(InventoryCharacterView)reference.Get("Character");
                    var parent=character.transform.parent;
                    // Place the entry above the equipment callouts, aligned to the preview's top right.
                    var toggle=Button("Health",parent,432,-18,100,30,bindings,localized,"BodyOpen");
                    var overlay=Box("HealthOverlay",parent,0,0,540,520);
                    overlay.gameObject.AddComponent<Image>().color=new Color(.055f,.075f,.09f,.99f);
                    bindings.Add(new LuaReference.Entry("HealthOverlay",overlay));
                    var heading=Label("HealthHeading",overlay,16,12,300,32,20);heading.color=Gold;
                    heading.text=LuaLanguage.Get("BodyTitle");localized.Add(new LuaReference.LocalizedText(heading,"BodyTitle"));
                    Button("HealthBack",overlay,380,10,144,32,bindings,localized,"BodyBack");
                    var hint=Label("HealthHint",overlay,18,47,506,22,12);hint.color=new Color(.56f,.65f,.70f);
                    hint.text=LuaLanguage.Get("BodySelectHint");localized.Add(new LuaReference.LocalizedText(hint,"BodySelectHint"));
                    // Left/right are the actor's own: their left appears on the viewer's right.
                    float[,] rects={{94,80,56,62},{73,152,98,116},{176,156,38,151},{29,156,38,151},{125,277,44,154},{75,277,44,154}};
                    for(int i=0;i<6;i++)
                    {
                        var rect=Box("HealthPart"+i,overlay,rects[i,0],rects[i,1],rects[i,2],rects[i,3]);
                        var graphic=rect.gameObject.AddComponent<BodyPartGraphic>();graphic.Configure(i);graphic.color=Color.white;
                        var outline=rect.gameObject.AddComponent<Outline>();outline.effectColor=new Color(.48f,.55f,.62f);outline.effectDistance=new Vector2(2,-2);
                        var button=rect.gameObject.AddComponent<Button>();button.targetGraphic=graphic;button.transition=Selectable.Transition.None;
                        button.navigation=new Navigation {mode=Navigation.Mode.None};
                        bindings.Add(new LuaReference.Entry("HealthPart"+i,button));bindings.Add(new LuaReference.Entry("HealthPartImage"+i,graphic));
                        bindings.Add(new LuaReference.Entry("HealthPartOutline"+i,outline));
                    }
                    var part=Label("HealthPartName",overlay,244,82,280,34,21);part.color=Gold;bindings.Add(new LuaReference.Entry("HealthPartName",part));
                    var detail=Label("HealthDetail",overlay,244,124,280,220,14);bindings.Add(new LuaReference.Entry("HealthDetail",detail));
                    Button("HealthTreat",overlay,244,358,280,62,bindings,localized,"BodyTreat");
                    var note=Label("HealthNote",overlay,244,430,280,70,12);note.color=new Color(.65f,.70f,.73f);
                    note.text=LuaLanguage.Get("BodyTreatmentNote");localized.Add(new LuaReference.LocalizedText(note,"BodyTreatmentNote"));
                    var legend=Label("HealthLegend",overlay,16,450,212,58,12);
                    legend.text=LuaLanguage.Get("BodyLegend");localized.Add(new LuaReference.LocalizedText(legend,"BodyLegend"));
                    overlay.gameObject.SetActive(false);toggle.transform.SetAsLastSibling();
                    reference.SetEditorBindings(bindings.ToArray());reference.SetEditorLocalizations(localized.ToArray());
                }
                var health=(RectTransform)bindings.Find(e=>e.Key=="HealthOverlay").Target;
                Scroll("HealthDetailsScroll",health,reference.GetText("HealthDetail"),124,198,bindings);
                var treat=(RectTransform)reference.GetButton("HealthTreat").transform;
                treat.anchoredPosition=new Vector2(244,-336);treat.sizeDelta=new Vector2(280,52);
                foreach(var item in localized)if(item.Id=="BodyTreatmentNote")item.Target.gameObject.SetActive(false);
                if(!bindings.Exists(e=>e.Key=="HealthDiseases"))
                {
                    var title=Label("HealthDiseaseHeading",health,244,390,280,26,16);title.color=Gold;
                    title.text=LuaLanguage.Get("BodyDiseaseHeading");localized.Add(new LuaReference.LocalizedText(title,"BodyDiseaseHeading"));
                    var diseases=Label("HealthDiseases",health,244,430,280,48,12);bindings.Add(new LuaReference.Entry("HealthDiseases",diseases));
                    Scroll("HealthDiseaseScroll",health,diseases,420,64,bindings);
                    Button("HealthDiseaseTreat",health,244,486,280,28,bindings,localized,"BodyDiseaseTreat");
                }
                reference.SetEditorBindings(bindings.ToArray());reference.SetEditorLocalizations(localized.ToArray());
                root.GetComponent<InventoryPanelView>().EditorLayout.Labels=root.GetComponentsInChildren<Text>(true);
                reference.ValidateBindings();PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);
                LuaViewHints.Register(typeof(BodyPartGraphic),"CS.ProjectY.UI.BodyPartGraphic");LuaViewHints.Export(reference,entry.ViewType);
            }
            finally {PrefabUtility.UnloadPrefabContents(root);}
            AssetDatabase.SaveAssets();Debug.Log("Body health view and explicit inventory bindings saved.");
        }
    }
}
