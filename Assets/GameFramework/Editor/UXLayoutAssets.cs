using System;
using System.Linq;
using ProjectY.UI;
using TMPro;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;
using Object=UnityEngine.Object;

namespace ProjectY.Editor
{
    /// <summary>Targeted migration of the Feishu UX layouts; run through Unity MCP in Edit Mode.</summary>
    public static class UXLayoutAssets
    {
        private static readonly Color Ink=new Color(.06f,.085f,.075f,.96f),Card=new Color(.13f,.19f,.16f,.97f),Paper=new Color(.92f,.89f,.80f),Gold=new Color(.83f,.71f,.48f),Blue=new Color(.29f,.48f,.73f),Red=new Color(.72f,.30f,.29f);
        private static PanelConfig config;
        private static TMP_FontAsset richFont;
        [MenuItem("Project Y/UI/应用 UX 布局")]
        public static void Apply()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("UX migration requires Edit Mode.");
            config=AssetDatabase.LoadAssetAtPath<PanelConfig>(PanelConfig.AssetPath);
            if(config==null||TMP_Settings.defaultFontAsset==null)throw new InvalidOperationException("UI registry and TMP resources are required.");
            richFont=LoadRichFont();
            LuaViewHints.Register(typeof(NarrativeView),"CS.ProjectY.UI.NarrativeView");
            LuaViewHints.Register(typeof(InventoryCharacterView),"CS.ProjectY.UI.InventoryCharacterView");
            Edit("TabButton",BuildTab,"Common");Edit("StatusEffect",BuildEffect,"Battle");
            Edit("NarrativeEntry",BuildEntry);Edit("Dialogue",BuildDialogue);Edit("MissionJournal",BuildJournal);
            Edit("HudParty",BuildParty);Edit("BattleHUD",BuildBattle);Edit("MainHud",BuildMain);
            Edit("HudStatusEffect",BuildHeadEffect,"MainHud");Edit("HudHealth",BuildHeadHealth);
            EditorUtility.SetDirty(config);AssetDatabase.SaveAssets();
            Debug.Log("UX layouts and explicit LuaReference bindings saved.");
        }
        [MenuItem("Project Y/UI/同步头顶 HP AP 与状态")]
        public static void ApplyHeadHealth()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Head HUD migration requires Edit Mode.");
            config=AssetDatabase.LoadAssetAtPath<PanelConfig>(PanelConfig.AssetPath);
            if(config==null)throw new InvalidOperationException("UI registry is required.");
            Edit("HudStatusEffect",BuildHeadEffect,"MainHud");Edit("HudHealth",BuildHeadHealth);
            Edit("BattleHUD",BuildBattle);Edit("MainHud",BuildHeadTooltip);
            EditorUtility.SetDirty(config);AssetDatabase.SaveAssets();
        }
        private static void BuildHeadEffect(GameObject root)
        {
            Box((RectTransform)root.transform,0,0,24,22);var plate=Paint((RectTransform)root.transform,Card,true);
            plate.sprite=AssetDatabase.GetBuiltinExtraResource<Sprite>("UI/Skin/Knob.psd");Bind(root,"Pointer",Ensure<UIPointerState>(root));
            var icon=Node("Icon",root.transform);Box(icon,4,0,16,16);Bind(root,"Icon",Paint(icon,Color.white));
            var glyph=Label(root,"Glyph",root.transform,"效",0,0,24,15,11);glyph.alignment=TextAnchor.MiddleCenter;glyph.color=Gold;
            var count=Label(root,"Count",root.transform,"",0,13,24,9,8);count.alignment=TextAnchor.MiddleCenter;
        }
        private static void BuildHeadHealth(GameObject root)
        {
            var reference=root.GetComponent<LuaReference>();var rect=(RectTransform)root.transform;
            rect.sizeDelta=new Vector2(160,50);rect.anchorMin=rect.anchorMax=new Vector2(.5f,.5f);rect.pivot=new Vector2(.5f,0);
            Paint(rect,Ink);
            var name=reference.GetText("Name");Box(name.rectTransform,7,0,148,17);name.fontSize=12;
            var health=reference.GetImage("Health");Box((RectTransform)health.transform.parent,6,19,148,12);health.color=Red;health.raycastTarget=false;Stretch(health.rectTransform);
            var hpText=reference.GetText("HealthText");Stretch(hpText.rectTransform);hpText.fontSize=10;hpText.resizeTextForBestFit=true;hpText.resizeTextMinSize=8;hpText.resizeTextMaxSize=10;
            var apTrack=Node("APTrack",root.transform);Box(apTrack,6,34,148,10);Paint(apTrack,new Color(.1f,.15f,.19f));
            var ap=Node("Fill",apTrack);Stretch(ap);Bind(root,"AP",Paint(ap,Blue));
            var apText=Label(root,"APText",apTrack,"",0,0,148,10,9);apText.alignment=TextAnchor.MiddleCenter;
            var team=Node("Team",root.transform);Box(team,1,2,2,42);Bind(root,"Team",Paint(team,Gold));
            var effects=Node("EffectSlots",root.transform);Box(effects,4,48,152,0);
            var grid=Ensure<GridLayoutGroup>(effects.gameObject);grid.constraint=GridLayoutGroup.Constraint.FixedColumnCount;grid.constraintCount=6;grid.cellSize=new Vector2(24,22);grid.spacing=new Vector2(1,2);Bind(root,"EffectSlots",effects);
            var settings=new SerializedObject(root.GetComponent<UIFollower>());settings.FindProperty("interactiveChildren").boolValue=true;
            settings.FindProperty("worldOffset").vector3Value=new Vector3(0,.32f,0);settings.FindProperty("screenOffset").vector2Value=new Vector2(0,4);
            settings.ApplyModifiedPropertiesWithoutUndo();
            BattleFeedbackAssets.SetupHealth(root);
        }
        private static void BuildHeadTooltip(GameObject root)
        {
            var style=root.GetComponent<MainHudView>();var serialized=new SerializedObject(style);var layout=serialized.FindProperty("layout");
            var common=(RectTransform)layout.FindPropertyRelative("Common").objectReferenceValue;
            var tooltip=Node("HealthTooltip",common);tooltip.anchorMin=tooltip.anchorMax=new Vector2(.5f,0);tooltip.pivot=new Vector2(.5f,0);
            tooltip.anchoredPosition=new Vector2(0,180);tooltip.sizeDelta=new Vector2(360,130);Paint(tooltip,Ink);Bind(root,"HealthTooltip",tooltip);
            Label(root,"HealthTipTitle",tooltip,"",12,6,336,26,17).color=Gold;
            var body=Label(root,"HealthTipBody",tooltip,"",12,36,336,86,13);body.alignment=TextAnchor.UpperLeft;
            tooltip.gameObject.SetActive(false);
            var labels=root.GetComponentsInChildren<Text>(true);var array=layout.FindPropertyRelative("Labels");array.arraySize=labels.Length;
            for(int i=0;i<labels.Length;i++)array.GetArrayElementAtIndex(i).objectReferenceValue=labels[i];serialized.ApplyModifiedPropertiesWithoutUndo();
        }
        private static TMP_FontAsset LoadRichFont()
        {
            const string path="Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc.asset";
            var asset=AssetDatabase.LoadAssetAtPath<TMP_FontAsset>(path);if(asset!=null)return asset;
            var font=AssetDatabase.LoadAssetAtPath<Font>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc-Regular.otf");
            if(font==null)throw new InvalidOperationException("Import the licensed Noto Sans CJK font before applying UX layouts.");
            asset=TMP_FontAsset.CreateFontAsset(font,40,5,UnityEngine.TextCore.LowLevel.GlyphRenderMode.SDFAA,1024,1024,AtlasPopulationMode.Dynamic,true);
            if(asset==null)throw new InvalidOperationException("Could not create the narrative TMP font.");
            asset.name="NotoSansCJKsc";asset.TryAddCharacters(" _0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz任务已完成主线支线招募基础旁白锁定");
            AssetDatabase.CreateAsset(asset,path);AssetDatabase.AddObjectToAsset(asset.material,asset);
            foreach(var texture in asset.atlasTextures)AssetDatabase.AddObjectToAsset(texture,asset);
            return asset;
        }
        private static void Edit(string name,Action<GameObject> build,string module=null)
        {
            var entry=config.Entries.Find(e=>e.Name==name);
            if(entry==null)
            {
                if(module==null)throw new InvalidOperationException("Missing existing panel "+name);
                entry=new PanelDefinition{Name=name,Module=module,Kind=UIKind.Widget};config.Entries.Add(entry);
            }
            var existing=entry.Prefab!=null;
            var folder=PanelConfig.PrefabRoot+"/"+entry.Module;
            if(!AssetDatabase.IsValidFolder(folder))AssetDatabase.CreateFolder(PanelConfig.PrefabRoot,entry.Module);
            var root=existing?PrefabUtility.LoadPrefabContents(entry.PrefabPath):new GameObject(entry.PrefabName,typeof(RectTransform),typeof(LuaReference),typeof(CanvasGroup));
            try
            {
                Bind(root,"Root",root.transform);build(root);root.GetComponent<LuaReference>().ValidateBindings();
                entry.Prefab=PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);LuaViewHints.Export(root.GetComponent<LuaReference>(),entry.ViewType);
            }
            finally{if(existing)PrefabUtility.UnloadPrefabContents(root);else Object.DestroyImmediate(root);}
        }
        private static T Ensure<T>(GameObject target) where T:Component=>target.GetComponent<T>()??target.AddComponent<T>();
        private static RectTransform Node(string name,Transform parent)
        {
            var found=parent.Find(name);if(found!=null)return (RectTransform)found;
            var rect=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;rect.SetParent(parent,false);return rect;
        }
        private static void Box(RectTransform r,float x,float y,float w,float h)
        {r.localScale=Vector3.one;r.anchorMin=r.anchorMax=r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(x,-y);r.sizeDelta=new Vector2(w,h);}
        private static void Stretch(RectTransform r,float l=0,float b=0,float right=0,float t=0)
        {r.anchorMin=Vector2.zero;r.anchorMax=Vector2.one;r.pivot=new Vector2(.5f,.5f);r.offsetMin=new Vector2(l,b);r.offsetMax=new Vector2(-right,-t);}
        private static Image Paint(RectTransform r,Color color,bool hit=false)
        {var image=Ensure<Image>(r.gameObject);image.color=color;image.raycastTarget=hit;return image;}
        private static void Bind(GameObject root,string key,Component target)
        {
            var reference=root.GetComponent<LuaReference>();var entries=reference.GetEditorBindings().ToList();
            entries.RemoveAll(e=>e.Key==key);entries.Add(new LuaReference.Entry(key,target));reference.SetEditorBindings(entries.ToArray());
        }
        private static Text Label(GameObject root,string key,Transform parent,string caption,float x,float y,float w,float h,int size=15)
        {
            var rect=Node(key,parent);Box(rect,x,y,w,h);var text=Ensure<Text>(rect.gameObject);
            text.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");text.text=caption;text.fontSize=size;text.color=Paper;
            text.raycastTarget=false;text.alignment=TextAnchor.MiddleLeft;Bind(root,key,text);return text;
        }
        private static UITxt Rich(GameObject root,string key,Transform parent,int size)
        {
            var rect=Node(key,parent);var old=rect.GetComponent<Text>();if(old!=null)Object.DestroyImmediate(old);
            var text=Ensure<UITxt>(rect.gameObject);text.font=TMP_Settings.defaultFontAsset;text.fontSize=size;text.color=Paper;text.richText=true;
            text.enableWordWrapping=true;text.raycastTarget=false;text.overflowMode=TextOverflowModes.Overflow;text.DefaultText="";
            Bind(root,key,text);return text;
        }
        private static Button Button(GameObject root,string key,Transform parent,string caption,float x,float y,float w,float h)
        {
            var rect=Node(key,parent);Box(rect,x,y,w,h);var image=Paint(rect,Card,true);var button=Ensure<Button>(rect.gameObject);
            button.targetGraphic=image;button.navigation=new Navigation{mode=Navigation.Mode.None};
            var label=Label(root,key+"Text",rect,caption,6,0,w-12,h);label.alignment=TextAnchor.MiddleCenter;
            Bind(root,key,button);return button;
        }
        private static ScrollRect Scroll(GameObject root,string key,Transform parent,float x,float y,float w,float h)
        {
            var rect=Node(key+"Scroll",parent);Box(rect,x,y,w,h);Paint(rect,new Color(0,0,0,.07f),true);
            var viewport=Node("Viewport",rect);Stretch(viewport);Ensure<RectMask2D>(viewport.gameObject);
            var content=Node(key,viewport);content.anchorMin=new Vector2(0,1);content.anchorMax=Vector2.one;content.pivot=new Vector2(.5f,1);content.sizeDelta=Vector2.zero;
            var group=Ensure<VerticalLayoutGroup>(content.gameObject);group.spacing=8;group.padding=new RectOffset(5,5,8,8);
            group.childControlHeight=group.childControlWidth=true;group.childForceExpandHeight=false;group.childForceExpandWidth=true;
            Ensure<ContentSizeFitter>(content.gameObject).verticalFit=ContentSizeFitter.FitMode.PreferredSize;
            var scroll=Ensure<ScrollRect>(rect.gameObject);scroll.viewport=viewport;scroll.content=content;scroll.horizontal=false;scroll.vertical=true;
            scroll.movementType=ScrollRect.MovementType.Clamped;scroll.scrollSensitivity=28;Bind(root,key,content);Bind(root,key+"Scroll",scroll);return scroll;
        }
        private static void RichStyle(GameObject root,params UITxt[] labels)
        {
            var style=Ensure<NarrativeView>(root);var serialized=new SerializedObject(style);var property=serialized.FindProperty("richLabels");property.arraySize=labels.Length;
            serialized.FindProperty("richFont").objectReferenceValue=richFont;
            for(int i=0;i<labels.Length;i++)property.GetArrayElementAtIndex(i).objectReferenceValue=labels[i];
            serialized.ApplyModifiedPropertiesWithoutUndo();Bind(root,"Style",style);
        }
        private static void BuildTab(GameObject root)
        {
            Box((RectTransform)root.transform,0,0,94,38);var background=Paint((RectTransform)root.transform,Card,true);
            var button=Ensure<Button>(root);button.targetGraphic=background;button.navigation=new Navigation{mode=Navigation.Mode.None};Bind(root,"Button",button);
            var label=Label(root,"Label",root.transform,"分类",0,0,94,38);label.alignment=TextAnchor.MiddleCenter;
            var selected=Node("Selected",root.transform);Box(selected,0,35,94,3);Bind(root,"Selected",Paint(selected,Gold));
        }
        private static void BuildEffect(GameObject root)
        {
            Box((RectTransform)root.transform,0,0,46,42);Paint((RectTransform)root.transform,Card,true);Bind(root,"Pointer",Ensure<UIPointerState>(root));
            var icon=Node("Icon",root.transform);Box(icon,8,2,30,28);Bind(root,"Icon",Paint(icon,Color.white));
            var glyph=Label(root,"Glyph",root.transform,"效",4,0,38,28,19);glyph.alignment=TextAnchor.MiddleCenter;glyph.color=Gold;
            var count=Label(root,"Count",root.transform,"",0,28,46,14,10);count.alignment=TextAnchor.MiddleCenter;
        }
        private static void BuildEntry(GameObject root)
        {
            var reference=root.GetComponent<LuaReference>();var layout=root.GetComponent<VerticalLayoutGroup>();layout.padding=new RectOffset(14,14,10,10);layout.spacing=5;
            var title=Rich(root,"Title",root.transform,17);title.color=Gold;var body=Rich(root,"Body",root.transform,16);
            var locked=Node("Locked",root.transform);Box(locked,13,12,18,20);Paint(locked,new Color(0,0,0,0));Ensure<LayoutElement>(locked.gameObject).ignoreLayout=true;
            var bodyPlate=Node("Body",locked);Box(bodyPlate,1,8,16,11);Paint(bodyPlate,Gold);
            var left=Node("ShackleLeft",locked);Box(left,4,2,3,8);Paint(left,Gold);
            var right=Node("ShackleRight",locked);Box(right,11,2,3,8);Paint(right,Gold);
            var top=Node("ShackleTop",locked);Box(top,4,1,10,3);Paint(top,Gold);
            Bind(root,"Locked",locked);locked.gameObject.SetActive(false);RichStyle(root,title,body);
        }
        private static void BuildDialogue(GameObject root)
        {
            var reference=root.GetComponent<LuaReference>();var page=(RectTransform)reference.GetText("Title").transform.parent;
            var choiceScroll=Scroll(root,"Choices",page,14,430,412,220);var rect=(RectTransform)choiceScroll.transform;
            rect.anchorMin=new Vector2(0,0);rect.anchorMax=new Vector2(1,0);rect.pivot=new Vector2(.5f,0);rect.sizeDelta=new Vector2(-28,220);rect.anchoredPosition=new Vector2(0,54);
            Bind(root,"ChoiceScroll",choiceScroll);
            var style=root.GetComponent<NarrativeView>();style.SetEditorBindings(page,(ScrollRect)reference.Get("Scroll"),root.GetComponentsInChildren<Text>(true),true);
            var serialized=new SerializedObject(style);serialized.FindProperty("choices").objectReferenceValue=rect;serialized.ApplyModifiedPropertiesWithoutUndo();
        }
        private static void BuildJournal(GameObject root)
        {
            var reference=root.GetComponent<LuaReference>();var page=(RectTransform)reference.GetText("Title").transform.parent;page.sizeDelta=new Vector2(1100,640);
            var title=reference.GetText("Title");Box(title.rectTransform,24,18,240,34);
            Box(reference.GetText("Caption").rectTransform,24,57,250,22);
            var tabs=Node("Tabs",page);Box(tabs,312,31,484,40);var tabLayout=Ensure<HorizontalLayoutGroup>(tabs.gameObject);
            tabLayout.spacing=16;tabLayout.childControlWidth=tabLayout.childControlHeight=false;tabLayout.childForceExpandHeight=tabLayout.childForceExpandWidth=false;Bind(root,"Tabs",tabs);
            Button(root,"Companions",page,"同行者",876,28,104,38);
            Scroll(root,"Missions",page,20,106,256,478);
            var scroll=(ScrollRect)reference.Get("Scroll");Box((RectTransform)scroll.transform,298,104,780,480);
            var content=(RectTransform)reference.Get("Content");
            var detail=Rich(root,"DetailTitle",content,27);detail.color=Gold;detail.transform.SetAsFirstSibling();
            var description=Rich(root,"Description",content,16);description.transform.SetSiblingIndex(1);
            var style=root.GetComponent<NarrativeView>();style.SetEditorBindings(page,scroll,root.GetComponentsInChildren<Text>(true),false);RichStyle(root,detail,description);
        }
        private static void BuildParty(GameObject root)
        {
            var reference=root.GetComponent<LuaReference>();Box((RectTransform)root.transform,0,0,190,82);
            Box(reference.GetText("Name").rectTransform,80,6,103,24);reference.GetText("Name").fontSize=13;
            var hp=reference.GetImage("Health");Box((RectTransform)hp.transform.parent,80,35,102,15);hp.color=Red;Stretch(hp.rectTransform);
            var hpText=reference.GetText("HealthText");Stretch(hpText.rectTransform);hpText.fontSize=10;
            BattleFeedbackAssets.SetupHealth(root);
            hpText.resizeTextForBestFit=true;hpText.resizeTextMinSize=8;hpText.resizeTextMaxSize=10;
            var ap=Node("APTrack",root.transform);Box(ap,80,56,102,13);Paint(ap,new Color(.12f,.17f,.20f));var fill=Node("AP",ap);Stretch(fill);Bind(root,"AP",Paint(fill,Blue));
            var apText=Label(root,"APText",ap,"",0,0,102,13,10);apText.alignment=TextAnchor.MiddleCenter;
            var portraitRect=Node("Portrait",root.transform);Box(portraitRect,7,8,64,66);var image=Ensure<RawImage>(portraitRect.gameObject);image.raycastTarget=false;
            var source=config.Get("CharacterGrowth").Prefab.GetComponent<LuaReference>().Get("Character");
            var portrait=Ensure<InventoryCharacterView>(portraitRect.gameObject);EditorUtility.CopySerialized(source,portrait);
            var serialized=new SerializedObject(portrait);serialized.FindProperty("image").objectReferenceValue=image;serialized.FindProperty("callouts").arraySize=0;
            serialized.FindProperty("portraitMode").boolValue=true;serialized.ApplyModifiedPropertiesWithoutUndo();Bind(root,"Portrait",portrait);
        }
        private static void MoveButton(GameObject root,string key,Transform parent,float x,float y,float w,float h)
        {
            var button=root.GetComponent<LuaReference>().GetButton(key);button.transform.SetParent(parent,false);Box((RectTransform)button.transform,x,y,w,h);
            var text=root.GetComponent<LuaReference>().GetText(key+"Text");Stretch(text.rectTransform,4,0,4,0);text.alignment=TextAnchor.MiddleCenter;
        }
        private static void BuildMain(GameObject root)
        {
            var reference=root.GetComponent<LuaReference>();var style=root.GetComponent<MainHudView>();var serialized=new SerializedObject(style);var layout=serialized.FindProperty("layout");
            var safe=(RectTransform)layout.FindPropertyRelative("Safe").objectReferenceValue;
            var common=Node("Common",root.transform);Stretch(common);common.SetAsLastSibling();
            var rail=Node("EntryRail",common);Box(rail,0,0,94,300);
            var menu=Node("Menu",common);Box(menu,0,0,314,410);Paint(menu,Ink,true);Bind(root,"Menu",menu);
            Button(root,"MenuToggle",rail,"菜单",0,0,94,54);Button(root,"Missions",rail,"任务",0,68,94,54);
            MoveButton(root,"Inventory",rail,0,136,94,54);MoveButton(root,"NavigationToggle",rail,0,204,94,54);
            reference.GetText("NavigationToggleText").text="地图";
            Label(root,"MenuTitle",menu,"旅途菜单",16,8,280,26,19).color=Gold;
            MoveButton(root,"Growth",menu,14,46,138,34);MoveButton(root,"Focus",menu,162,46,138,34);
            MoveButton(root,"Environment",menu,14,88,138,34);MoveButton(root,"GM",menu,162,88,138,34);
            MoveButton(root,"Leave",menu,14,130,138,34);MoveButton(root,"Stop",menu,162,130,138,34);
            MoveButton(root,"CameraMode",menu,14,172,138,34);MoveButton(root,"Restart",menu,14,172,138,34);
            Scroll(root,"MenuRows",menu,9,214,296,180);
            var clock=Node("Clock",common);Box(clock,0,0,112,112);var clockImage=Paint(clock,Ink);
            clockImage.sprite=AssetDatabase.GetBuiltinExtraResource<Sprite>("UI/Skin/Knob.psd");
            var needle=Node("Needle",clock);Box(needle,54,8,3,39);needle.pivot=new Vector2(.5f,0);needle.anchoredPosition=new Vector2(56,-56);Paint(needle,Gold);Bind(root,"ClockNeedle",needle);
            var time=Label(root,"ClockTime",clock,"",0,42,112,26,21);time.alignment=TextAnchor.MiddleCenter;
            var day=Label(root,"ClockDay",clock,"",0,72,112,20,12);day.alignment=TextAnchor.MiddleCenter;
            reference.GetText("Coins").transform.SetParent(clock,false);Box(reference.GetText("Coins").rectTransform,0,110,112,24);reference.GetText("Coins").alignment=TextAnchor.MiddleCenter;
            var header=(RectTransform)layout.FindPropertyRelative("Header").objectReferenceValue;Paint(header,new Color(0,0,0,0));
            Box(reference.GetText("Location").rectTransform,0,0,420,26);Box(reference.GetText("Subtitle").rectTransform,0,28,440,20);
            var rule=header.Find("GoldRule");if(rule!=null)rule.gameObject.SetActive(false);
            var skills=(RectTransform)reference.Get("CharacterSkills");
            var slots=(RectTransform)reference.Get("CharacterSkillSlots");var oldScroll=slots.GetComponentInParent<ScrollRect>();
            if(oldScroll!=null)oldScroll.enabled=false;
            slots.SetParent(skills,false);Stretch(slots,12,30,12,34);
            foreach(var group in slots.GetComponents<LayoutGroup>())Object.DestroyImmediate(group);
            var fitter=slots.GetComponent<ContentSizeFitter>();if(fitter!=null)Object.DestroyImmediate(fitter);
            var grid=slots.gameObject.AddComponent<GridLayoutGroup>();grid.constraint=GridLayoutGroup.Constraint.FixedColumnCount;grid.constraintCount=4;grid.spacing=new Vector2(6,0);grid.cellSize=new Vector2(122,70);
            Box(reference.GetText("SkillActor").rectTransform,12,4,344,24);Box(reference.GetText("SkillHint").rectTransform,12,110,526,24);
            Box(reference.GetText("SkillEmpty").rectTransform,14,42,500,50);
            Button(root,"SkillPrevious",skills,"‹",388,4,30,24);Button(root,"SkillNext",skills,"›",502,4,30,24);
            Label(root,"SkillPage",skills,"1 / 1",425,4,72,24,12).alignment=TextAnchor.MiddleCenter;
            MoveButton(root,"CancelSkill",skills,384,110,146,24);
            var previous=(RectTransform)reference.GetButton("SkillPrevious").transform;previous.anchorMin=previous.anchorMax=new Vector2(1,1);previous.anchoredPosition=new Vector2(-162,-4);
            var next=(RectTransform)reference.GetButton("SkillNext").transform;next.anchorMin=next.anchorMax=new Vector2(1,1);next.anchoredPosition=new Vector2(-42,-4);
            var page=reference.GetText("SkillPage").rectTransform;page.anchorMin=page.anchorMax=new Vector2(1,1);page.anchoredPosition=new Vector2(-126,-4);
            var cancel=(RectTransform)reference.GetButton("CancelSkill").transform;cancel.anchorMin=cancel.anchorMax=new Vector2(1,1);cancel.anchoredPosition=new Vector2(-158,-110);
            var actorText=reference.GetText("SkillActor").rectTransform;actorText.anchorMax=Vector2.one;actorText.sizeDelta=new Vector2(-188,24);
            var hint=reference.GetText("SkillHint").rectTransform;hint.anchorMax=Vector2.one;hint.sizeDelta=new Vector2(-186,24);
            var journal=(RectTransform)layout.FindPropertyRelative("Journal").objectReferenceValue;
            var journalTitle=journal.Find("JournalTitle") as RectTransform;if(journalTitle!=null)Box(journalTitle,14,5,450,24);
            Box(reference.GetText("Logs").rectTransform,14,34,452,96);
            layout.FindPropertyRelative("Common").objectReferenceValue=common;layout.FindPropertyRelative("Rail").objectReferenceValue=rail;
            layout.FindPropertyRelative("Menu").objectReferenceValue=menu;layout.FindPropertyRelative("Clock").objectReferenceValue=clock;
            layout.FindPropertyRelative("SkillGrid").objectReferenceValue=grid;
            var labels=root.GetComponentsInChildren<Text>(true);var array=layout.FindPropertyRelative("Labels");array.arraySize=labels.Length;
            for(int i=0;i<labels.Length;i++)array.GetArrayElementAtIndex(i).objectReferenceValue=labels[i];
            serialized.ApplyModifiedPropertiesWithoutUndo();
            BuildHeadTooltip(root);
        }
        private static void BuildBattle(GameObject root)
        {
            var reference=root.GetComponent<LuaReference>();var style=root.GetComponent<BattleHUDView>();var serialized=new SerializedObject(style);var layout=serialized.FindProperty("layout");
            var safe=(RectTransform)layout.FindPropertyRelative("SafeArea").objectReferenceValue;
            var controls=(RectTransform)reference.GetButton("Auto").transform.parent;
            controls.anchorMin=controls.anchorMax=controls.pivot=new Vector2(1,0);controls.anchoredPosition=new Vector2(-18,174);controls.sizeDelta=new Vector2(174,60);
            ((RectTransform)layout.FindPropertyRelative("Commands").objectReferenceValue).SetParent(safe,false);
            var oldActor=reference.GetEditorBindings().FirstOrDefault(e=>e.Key=="ActorName").Target;
            if(oldActor!=null)
            {
                var actor=oldActor.transform.parent.gameObject;
                var removed=new[]{"ActorName","HealthText","Health","AP","APFill","Resources","EffectSlots"};
                reference.SetEditorBindings(reference.GetEditorBindings().Where(e=>!removed.Contains(e.Key)).ToArray());
                Object.DestroyImmediate(actor);
            }
            var labels=root.GetComponentsInChildren<Text>(true);var array=layout.FindPropertyRelative("Labels");array.arraySize=labels.Length;
            for(int i=0;i<labels.Length;i++)array.GetArrayElementAtIndex(i).objectReferenceValue=labels[i];serialized.ApplyModifiedPropertiesWithoutUndo();
        }
    }
}
