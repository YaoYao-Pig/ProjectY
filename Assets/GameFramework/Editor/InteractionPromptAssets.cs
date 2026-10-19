using System;
using System.Collections.Generic;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    public static class InteractionPromptAssets
    {
        [MenuItem("Project Y/UI/同步物体交互按键提示")]
        public static void Sync()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("交互提示同步需要 Edit Mode。");
            var entry=PanelAssets.LoadOrCreate().Entries.Find(row=>row.Name=="HudInteraction");
            if(entry==null)entry=PanelAssets.Save(new PanelDefinition{Name="HudInteraction",Module="MainHud",Kind=UIKind.Widget,
                Layer="Overlay",Cache=true,Modal=false,CloseOnBack=false,PauseWorldOnOpen=false},null);
            PanelAssets.Generate(entry);var root=PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                var reference=root.GetComponent<LuaReference>();
                if(root.transform.childCount==0)
                {
                    var rect=(RectTransform)root.transform;rect.anchorMin=rect.anchorMax=rect.pivot=new Vector2(.5f,.5f);rect.sizeDelta=new Vector2(252,36);
                    var background=root.AddComponent<Image>();background.color=new Color(.035f,.055f,.07f,.94f);background.raycastTarget=false;
                    var group=root.GetComponent<CanvasGroup>();if(group==null)group=root.AddComponent<CanvasGroup>();group.blocksRaycasts=false;group.interactable=false;
                    var key=Label(root.transform,"Key","E",6,5,28,26,16);key.alignment=TextAnchor.MiddleCenter;key.color=new Color(.96f,.8f,.48f);
                    var text=Label(root.transform,"Label","交互",44,5,200,26,14);text.alignment=TextAnchor.MiddleLeft;
                    text.resizeTextForBestFit=true;text.resizeTextMinSize=11;text.resizeTextMaxSize=14;
                    var follower=root.AddComponent<UIFollower>();follower.SetEditorBindings(rect,group);
                    var settings=new SerializedObject(follower);settings.FindProperty("orthographicFade").vector2Value=new Vector2(18,36);settings.ApplyModifiedPropertiesWithoutUndo();
                    var bindings=new List<LuaReference.Entry>(reference.GetEditorBindings()) {
                        new LuaReference.Entry("Key",key),new LuaReference.Entry("Label",text),new LuaReference.Entry("Follower",follower)};
                    reference.SetEditorBindings(bindings.ToArray());
                }
                reference.ValidateBindings();PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);LuaViewHints.Export(reference,entry.ViewType);
            }
            finally{PrefabUtility.UnloadPrefabContents(root);}
            AssetDatabase.SaveAssets();Debug.Log("HudInteraction prefab and screen-follower bindings saved.");
        }
        private static Text Label(Transform parent,string name,string value,float x,float y,float width,float height,int size)
        {
            var rect=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;rect.SetParent(parent,false);
            rect.anchorMin=rect.anchorMax=rect.pivot=new Vector2(0,1);rect.anchoredPosition=new Vector2(x,-y);rect.sizeDelta=new Vector2(width,height);
            var text=rect.gameObject.AddComponent<Text>();text.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");text.text=value;
            text.fontSize=size;text.color=Color.white;text.raycastTarget=false;return text;
        }
    }
}
