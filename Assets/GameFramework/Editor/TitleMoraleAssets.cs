using System;
using System.Collections.Generic;
using System.Linq;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    /// <summary>Incremental native UI authoring for titles and the white morale ring.</summary>
    public static class TitleMoraleAssets
    {
        [MenuItem("Project Y/UI/同步称号与士气")]
        public static void Sync()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode || EditorApplication.isCompiling)
                throw new InvalidOperationException("Title/morale UI authoring requires idle Edit Mode.");
            var config=AssetDatabase.LoadAssetAtPath<PanelConfig>(PanelConfig.AssetPath);
            foreach(var id in new[]{"CharacterGrowth","HudHealth"})
            {
                var entry=config.Get(id);var root=PrefabUtility.LoadPrefabContents(entry.PrefabPath);
                try
                {
                    if(id=="CharacterGrowth")BuildTitles(root);else BuildMorale(root);
                    var reference=root.GetComponent<LuaReference>();reference.ValidateBindings();
                    PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);LuaViewHints.Export(reference,entry.ViewType);
                }
                finally{PrefabUtility.UnloadPrefabContents(root);}
            }
        }
        public static void BuildMorale(GameObject root)
        {
            var reference=root.GetComponent<LuaReference>();
            Ring(root.transform,"MoraleTrack",new Color(.16f,.17f,.18f,.85f),false);
            var ring=Ring(root.transform,"Morale",Color.white,true);Bind(reference,"Morale",ring);
        }
        private static Image Ring(Transform parent,string name,Color color,bool filled)
        {
            var child=parent.Find(name);
            var rect=child!=null?(RectTransform)child:(RectTransform)new GameObject(name,typeof(RectTransform),typeof(Image),typeof(HealthRingMesh)).transform;
            rect.SetParent(parent,false);rect.gameObject.layer=parent.gameObject.layer;
            rect.anchorMin=Vector2.zero;rect.anchorMax=Vector2.one;rect.offsetMin=rect.offsetMax=Vector2.zero;
            rect.localScale=Vector3.one;rect.localRotation=Quaternion.identity;
            var image=rect.GetComponent<Image>();image.sprite=null;image.color=color;image.raycastTarget=false;
            image.type=filled?Image.Type.Filled:Image.Type.Simple;image.fillMethod=Image.FillMethod.Radial360;image.fillAmount=1;
            rect.GetComponent<HealthRingMesh>().SetEditorShape(1,.025f);
            return image;
        }
        public static void BuildTitles(GameObject root)
        {
            var reference=root.GetComponent<LuaReference>();
            if(reference.GetEditorBindings().Any(v=>v.Key=="Titles"))return;
            var page=(RectTransform)reference.Get("Page");
            var tab=UnityEngine.Object.Instantiate(reference.GetButton("HistoryTab"),page,false);tab.name="TitlesTab";
            Place((RectTransform)tab.transform,796,180,148,36);
            var tabText=tab.GetComponentInChildren<Text>(true);tabText.text=LuaLanguage.Get("TitleTab");
            Bind(reference,"TitlesTab",tab);Bind(reference,"TitlesTabText",tabText);
            var content=(RectTransform)new GameObject("Titles",typeof(RectTransform)).transform;content.SetParent(page,false);content.gameObject.layer=page.gameObject.layer;
            Place(content,292,237,878,377);Bind(reference,"Titles",content);
            var source=reference.GetText("HistorySummary");
            var heading=UnityEngine.Object.Instantiate(source,content,false);heading.name="TitleSummary";heading.text="";
            Place(heading.rectTransform,0,0,878,32);Bind(reference,"TitleSummary",heading);
            var scroll=UnityEngine.Object.Instantiate((ScrollRect)reference.Get("HistoryRowsScroll"),content,false);scroll.name="TitleRowsScroll";
            Place((RectTransform)scroll.transform,0,49,350,328);FitScroll(scroll);Bind(reference,"TitleRowsScroll",scroll);Bind(reference,"TitleRows",scroll.content);
            var detailScroll=UnityEngine.Object.Instantiate((ScrollRect)reference.Get("HistoryRowsScroll"),content,false);detailScroll.name="TitleDetailScroll";
            Place((RectTransform)detailScroll.transform,378,49,490,260);FitScroll(detailScroll);Bind(reference,"TitleDetailScroll",detailScroll);
            detailScroll.content.GetComponent<VerticalLayoutGroup>().childControlHeight=true;
            var detail=UnityEngine.Object.Instantiate(reference.GetText("TraitDetail"),detailScroll.content,false);detail.name="TitleDetail";detail.text="";
            Place(detail.rectTransform,0,0,490,0);detail.supportRichText=false;detail.alignment=TextAnchor.UpperLeft;
            detail.horizontalOverflow=HorizontalWrapMode.Wrap;detail.verticalOverflow=VerticalWrapMode.Overflow;Bind(reference,"TitleDetail",detail);
            var equip=UnityEngine.Object.Instantiate(reference.GetButton("Invest"),content,false);equip.name="TitleEquip";
            Place((RectTransform)equip.transform,378,330,267,35);
            var equipText=equip.GetComponentInChildren<Text>(true);equipText.text=LuaLanguage.Get("TitleEquip");
            Bind(reference,"TitleEquip",equip);Bind(reference,"TitleEquipText",equipText);
            var localized=new List<LuaReference.LocalizedText>(reference.GetEditorLocalizations())
            {new LuaReference.LocalizedText(tabText,"TitleTab"),new LuaReference.LocalizedText(equipText,"TitleEquip")};
            reference.SetEditorLocalizations(localized.ToArray());
            var style=new SerializedObject(reference.Get("Style"));var labels=style.FindProperty("labels");
            foreach(var text in new[]{tabText,heading,detail,equipText}){int i=labels.arraySize;labels.InsertArrayElementAtIndex(i);labels.GetArrayElementAtIndex(i).objectReferenceValue=text;}
            var glyphs=style.FindProperty("glyphs");int sourceIndex=-1,courageIndex=-1;
            for(int i=0;i<glyphs.arraySize;i++)
            {
                string code=glyphs.GetArrayElementAtIndex(i).FindPropertyRelative("Code").stringValue;
                if(code=="defense")sourceIndex=i;
                if(code=="courage")courageIndex=i;
            }
            if(sourceIndex<0)throw new InvalidOperationException("Missing defense glyph for the courage attribute.");
            var sprite=glyphs.GetArrayElementAtIndex(sourceIndex).FindPropertyRelative("Sprite").objectReferenceValue;
            if(courageIndex<0)
            {
                int last=glyphs.arraySize;glyphs.InsertArrayElementAtIndex(last);
                glyphs.GetArrayElementAtIndex(last).FindPropertyRelative("Code").stringValue="courage";
                glyphs.GetArrayElementAtIndex(last).FindPropertyRelative("Sprite").objectReferenceValue=sprite;
            }
            style.ApplyModifiedPropertiesWithoutUndo();content.gameObject.SetActive(false);
        }
        private static void Place(RectTransform rect,float x,float y,float w,float h)
        {rect.anchorMin=rect.anchorMax=rect.pivot=new Vector2(0,1);rect.anchoredPosition=new Vector2(x,-y);rect.sizeDelta=new Vector2(w,h);}
        private static void FitScroll(ScrollRect scroll)
        {
            scroll.viewport.anchorMin=Vector2.zero;scroll.viewport.anchorMax=Vector2.one;
            scroll.viewport.offsetMin=scroll.viewport.offsetMax=Vector2.zero;
            scroll.content.anchorMin=new Vector2(0,1);scroll.content.anchorMax=Vector2.one;
            scroll.content.pivot=new Vector2(0,1);scroll.content.anchoredPosition=Vector2.zero;scroll.content.sizeDelta=Vector2.zero;
            scroll.horizontal=false;scroll.vertical=true;
        }
        private static void Bind(LuaReference reference,string key,Component value)
        {var entries=reference.GetEditorBindings().Where(v=>v.Key!=key).ToList();entries.Add(new LuaReference.Entry(key,value));reference.SetEditorBindings(entries.ToArray());}
    }
}
