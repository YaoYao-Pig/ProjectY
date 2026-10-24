using System;
using System.Linq;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    public static class GroundHealthAssets
    {
        [MenuItem("Project Y/UI/同步脚下 HP AP 圆环")]
        public static void Sync()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Ground HUD migration requires Edit Mode.");
            var config=AssetDatabase.LoadAssetAtPath<PanelConfig>(PanelConfig.AssetPath);
            var entry=config.Get("HudHealth");
            var root=PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                Build(root);
                var reference=root.GetComponent<LuaReference>();reference.ValidateBindings();
                PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);
                LuaViewHints.Export(reference,entry.ViewType);
                entry.IsWorldUI=true;EditorUtility.SetDirty(config);AssetDatabase.SaveAssetIfDirty(config);
            }
            finally{PrefabUtility.UnloadPrefabContents(root);}
            Debug.Log("Foot HP/AP rings, curved labels and separate damage follower saved.");
        }

        public static void Build(GameObject root)
        {
            var reference=root.GetComponent<LuaReference>();
            var rect=(RectTransform)root.transform;
            rect.anchorMin=rect.anchorMax=rect.pivot=new Vector2(.5f,.5f);rect.sizeDelta=new Vector2(128,82);
            root.GetComponent<Image>().enabled=false;
            reference.GetText("Name").gameObject.SetActive(false);
            BattleFeedbackAssets.SetupHealth(root);
            var hp=reference.GetImage("Health");var ap=reference.GetImage("AP");var trail=reference.GetImage("HealthTrail");
            // Keep the old containers inert so existing asset references remain valid.
            var hpTrack=hp.transform.parent;var apTrack=ap.transform.parent;
            ConfigureRing(Node("HPBorder",root.transform),.96f,.14f,new Color(.015f,.02f,.025f,1),false);
            ConfigureRing(Node("HPTrack",root.transform),.93f,.08f,new Color(.22f,.065f,.07f,1),false);
            ConfigureRing(trail.rectTransform,.93f,.08f,new Color(1,.68f,.56f,1),true,root.transform);
            ConfigureRing(hp.rectTransform,.93f,.08f,new Color(.88f,.24f,.24f,1),true,root.transform);
            ConfigureRing(Node("APBorder",root.transform),.75f,.13f,new Color(.015f,.02f,.025f,1),false);
            ConfigureRing(Node("APRingTrack",root.transform),.72f,.07f,new Color(.055f,.12f,.23f,1),false);
            ConfigureRing(ap.rectTransform,.72f,.07f,new Color(.24f,.62f,1,1),true,root.transform);
            ConfigureText(reference.GetText("HealthText"),root.transform,1.08f,-1,16,Color.white);
            ConfigureText(reference.GetText("APText"),root.transform,.58f,3,13,new Color(.65f,.85f,1,1));
            if(hpTrack!=root.transform)hpTrack.gameObject.SetActive(false);
            if(apTrack!=root.transform)apTrack.gameObject.SetActive(false);
            var team=reference.GetImage("Team");team.raycastTarget=false;
            var teamRect=team.rectTransform;teamRect.SetParent(root.transform,false);
            teamRect.anchorMin=teamRect.anchorMax=new Vector2(0,.5f);teamRect.pivot=new Vector2(.5f,.5f);
            teamRect.sizeDelta=new Vector2(4,4);teamRect.anchoredPosition=new Vector2(3,0);teamRect.localRotation=Quaternion.Euler(0,0,45);
            var canvas=Ensure<Canvas>(root);canvas.renderMode=RenderMode.WorldSpace;
            var effects=(RectTransform)reference.Get("EffectSlots");Stretch(effects);
            var grid=effects.GetComponent<GridLayoutGroup>();if(grid!=null)UnityEngine.Object.DestroyImmediate(grid);
            Ensure<ArcLayoutGroup>(effects.gameObject).SetEditorBindings(canvas);
            Bind(reference,"WorldCanvas",canvas);
            var raycaster=Ensure<GraphicRaycaster>(root);raycaster.blockingObjects=GraphicRaycaster.BlockingObjects.ThreeD;
            var settings=new SerializedObject(root.GetComponent<UIFollower>());
            settings.FindProperty("worldCanvas").objectReferenceValue=canvas;
            settings.FindProperty("groundPlane").boolValue=true;
            settings.FindProperty("worldOffset").vector3Value=new Vector3(0,.035f,0);
            settings.FindProperty("screenOffset").vector2Value=Vector2.zero;
            settings.FindProperty("interactiveChildren").boolValue=true;settings.ApplyModifiedPropertiesWithoutUndo();
            var damage=Node("DamageAnchor",root.transform);damage.anchorMin=damage.anchorMax=damage.pivot=new Vector2(.5f,.5f);damage.sizeDelta=Vector2.zero;
            var visibility=Ensure<CanvasGroup>(damage.gameObject);visibility.blocksRaycasts=false;visibility.interactable=false;
            var follower=Ensure<UIFollower>(damage.gameObject);follower.SetEditorBindings(damage,visibility);
            var damageSettings=new SerializedObject(follower);damageSettings.FindProperty("worldCanvas").objectReferenceValue=canvas;damageSettings.ApplyModifiedPropertiesWithoutUndo();
            var numbers=root.GetComponent<DamageNumberAnimation>();
            var serialized=new SerializedObject(numbers);var template=(DamageNumberPopup)serialized.FindProperty("template").objectReferenceValue;
            template.transform.SetParent(damage,false);((RectTransform)template.transform).anchoredPosition=Vector2.zero;
            numbers.SetEditorBindings(template,follower);Bind(reference,"DamageFollower",follower);
        }

        private static void ConfigureRing(RectTransform rect,float radius,float thickness,Color color,bool filled,Transform parent=null)
        {
            if(parent!=null)rect.SetParent(parent,false);
            Stretch(rect);rect.SetAsLastSibling();
            var image=Ensure<Image>(rect.gameObject);image.enabled=true;image.sprite=null;image.color=color;image.raycastTarget=false;
            image.type=filled?Image.Type.Filled:Image.Type.Simple;image.fillMethod=Image.FillMethod.Radial360;image.fillOrigin=2;image.fillClockwise=true;image.fillAmount=1;
            Ensure<HealthRingMesh>(rect.gameObject).SetEditorShape(radius,thickness);
        }
        private static void ConfigureText(Text text,Transform parent,float radius,float lift,int fontSize,Color tint)
        {
            text.transform.SetParent(parent,false);Stretch(text.rectTransform);text.transform.SetAsLastSibling();
            text.fontSize=fontSize;text.fontStyle=FontStyle.Bold;text.resizeTextForBestFit=false;text.alignment=TextAnchor.MiddleCenter;
            text.horizontalOverflow=HorizontalWrapMode.Overflow;text.verticalOverflow=VerticalWrapMode.Overflow;text.supportRichText=false;
            text.color=tint;text.raycastTarget=false;
            // Arc deformation must happen before the outline duplicates glyph vertices.
            var outline=text.GetComponent<Outline>();if(outline!=null)UnityEngine.Object.DestroyImmediate(outline);
            Ensure<ArcText>(text.gameObject).SetEditorShape(radius,lift);
            var arcSettings=new SerializedObject(text.GetComponent<ArcText>());arcSettings.FindProperty("worldBillboard").boolValue=true;arcSettings.ApplyModifiedPropertiesWithoutUndo();
            outline=text.gameObject.AddComponent<Outline>();outline.effectColor=Color.black;outline.effectDistance=new Vector2(1.25f,-1.25f);
        }
        private static void Stretch(RectTransform rect)
        {rect.anchorMin=Vector2.zero;rect.anchorMax=Vector2.one;rect.pivot=new Vector2(.5f,.5f);rect.offsetMin=rect.offsetMax=Vector2.zero;rect.localScale=Vector3.one;rect.localRotation=Quaternion.identity;}
        private static RectTransform Node(string name,Transform parent)
        {var node=parent.Find(name);if(node!=null)return (RectTransform)node;var rect=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;rect.SetParent(parent,false);return rect;}
        private static T Ensure<T>(GameObject root) where T:Component
        {var component=root.GetComponent<T>();return component!=null?component:root.AddComponent<T>();}
        private static void Bind(LuaReference reference,string key,Component target)
        {var entries=reference.GetEditorBindings().Where(entry=>entry.Key!=key).ToList();entries.Add(new LuaReference.Entry(key,target));reference.SetEditorBindings(entries.ToArray());}
    }
}
