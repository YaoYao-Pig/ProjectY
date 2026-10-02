using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ProjectY.Samples;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    /// <summary>角色手记的可编辑 UGUI 资源。显式重建只替换本模块的布局。</summary>
    public static class CharacterJournalAssets
    {
        private static readonly Color Paper=new Color(.91f,.87f,.77f),Ink=new Color(.20f,.24f,.21f),Muted=new Color(.43f,.43f,.36f),Gold=new Color(.55f,.39f,.20f),Line=new Color(.67f,.61f,.49f,.45f);
        private static string[] codes;
        private static Dictionary<string,Sprite> sprites;
        [Serializable] private sealed class Attributes { public AttributeRow[] rows; }
        [Serializable] private sealed class AttributeRow { public string code; }
        [Serializable] private sealed class Passives { public Passive[] rows; }
        [Serializable] private sealed class Passive { public string[] attributeNames; }
        [Serializable] private sealed class Parts { public Part[] rows; }
        [Serializable] private sealed class Part { public int id;public string prefabPath; }
        [MenuItem("Project Y/UI/重建角色手记布局")]
        public static void Rebuild()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("请在 Edit Mode 重建角色手记。");
            PrepareSprites();
            Save("JournalAttribute",UIKind.Widget,Attribute);
            Save("JournalSkill",UIKind.Widget,Skill);
            Save("JournalEntry",UIKind.Widget,Entry);
            Save("TraitTag",UIKind.Widget,Tag);
            Save("TalentNode",UIKind.Widget,Talent);
            Save("CharacterGrowth",UIKind.Panel,Build);
            AssetDatabase.SaveAssets();
            Debug.Log("Character journal layout, portrait, icons and bindings rebuilt.");
        }
        [MenuItem("Project Y/UI/同步角色手记图标")]
        public static void SyncGlyphs()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("请在 Edit Mode 同步角色手记图标。");
            var glyphs=CreateGlyphBindings();var config=PanelAssets.LoadOrCreate();
            config.Get("CharacterGrowth");
            foreach(var name in new[]{"CharacterGrowth","SkillAtlas"})
            {
                // 技能图谱可尚未创建；已经注册的界面必须具有有效 Prefab 和 Style 绑定。
                var entry=config.Entries.Find(value=>value.Name==name);if(entry==null)continue;
                if(entry.Prefab==null)throw new InvalidOperationException("请先创建 "+name+" Prefab。");
                var root=PrefabUtility.LoadPrefabContents(entry.PrefabPath);
                try
                {
                    var style=(StoryGrowthView)root.GetComponent<LuaReference>().Get("Style");
                    style.SetJournalTheme(glyphs);PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);
                }
                finally{PrefabUtility.UnloadPrefabContents(root);}
            }
            AssetDatabase.SaveAssets();
            Debug.Log("Character journal glyphs synchronized from configured attributes/passives: "+codes.Length);
        }
        public static StoryGrowthView.GlyphEntry[] CreateGlyphBindings()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("请在 Edit Mode 生成属性图标绑定。");
            PrepareSprites();
            return codes.Select(code=>new StoryGrowthView.GlyphEntry{Code=code,Sprite=sprites[code]}).ToArray();
        }
        private static string[] ReadGlyphCodes()
        {
            var attributes=JsonUtility.FromJson<Attributes>(File.ReadAllText("Config/Tables/Progression/GrowthAttributeTable.json"));
            var passives=JsonUtility.FromJson<Passives>(File.ReadAllText("Config/Tables/Progression/PassiveSkillTable.json"));
            if(attributes==null || attributes.rows==null || passives==null || passives.rows==null)throw new InvalidOperationException("Missing journal attribute/passive configuration.");
            var result=new List<string>();var seen=new HashSet<string>(StringComparer.Ordinal);
            Action<string> add=code=>{
                if(string.IsNullOrEmpty(code) || !System.Text.RegularExpressions.Regex.IsMatch(code,"^[A-Za-z][A-Za-z0-9_]*$") || code=="disc" || code=="ring")
                    throw new InvalidOperationException("Invalid journal glyph code: "+code);
                if(seen.Add(code))result.Add(code);
            };
            foreach(var row in attributes.rows)
            {
                if(row==null || seen.Contains(row.code))throw new InvalidOperationException("Duplicate/invalid journal attribute.");
                add(row.code);
            }
            foreach(var row in passives.rows)
            {
                if(row==null || row.attributeNames==null || row.attributeNames.Length==0)throw new InvalidOperationException("Passive glyph requires its primary attribute.");
                add(row.attributeNames[0]);
            }
            return result.ToArray();
        }
        private static void Save(string name,UIKind kind,Action<GameObject> build)
        {
            var entry=PanelAssets.LoadOrCreate().Entries.Find(e=>e.Name==name);
            if(entry==null) entry=PanelAssets.Save(new PanelDefinition {Name=name,Module="Adventure",Kind=kind,Layer=kind==UIKind.Panel?"Popup":"Main",Modal=kind==UIKind.Panel,Cache=true,CloseOnBack=kind==UIKind.Panel,PauseWorldOnOpen=kind==UIKind.Panel},null);
            PanelAssets.Generate(entry);var root=PrefabUtility.LoadPrefabContents(entry.PrefabPath);
            try
            {
                var reference=root.GetComponent<LuaReference>();
                reference.SetEditorBindings(reference.GetEditorBindings().Where(e=>e.Key=="Root"||e.Key=="Panel"||e.Key=="Canvas").ToArray());
                foreach(var component in root.GetComponents<Component>())
                    if(component is StoryGrowthView||component is Image||component is Button) UnityEngine.Object.DestroyImmediate(component);
                while(root.transform.childCount>0) UnityEngine.Object.DestroyImmediate(root.transform.GetChild(0).gameObject);
                build(root);reference.ValidateBindings();PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);LuaViewHints.Export(reference,entry.ViewType);
            }
            finally {PrefabUtility.UnloadPrefabContents(root);}
        }
        private static RectTransform Rect(string name,Transform parent,float x,float y,float w,float h)
        {
            var r=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;r.SetParent(parent,false);
            r.anchorMin=r.anchorMax=new Vector2(0,1);r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(x,-y);r.sizeDelta=new Vector2(w,h);return r;
        }
        private static Image Paint(RectTransform r,Color color,bool hit=false,Sprite sprite=null)
        {var i=r.gameObject.AddComponent<Image>();i.color=color;i.raycastTarget=hit;i.sprite=sprite;return i;}
        private static Text Label(string name,Transform p,string value,float x,float y,float w,float h,int size,Color? color=null)
        {
            var t=Rect(name,p,x,y,w,h).gameObject.AddComponent<Text>();t.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");t.text=value;t.fontSize=size;
            t.color=color??Ink;t.raycastTarget=false;t.alignment=TextAnchor.MiddleLeft;t.supportRichText=false;return t;
        }
        private static void Bind(GameObject root,string key,Component target)
        {var r=root.GetComponent<LuaReference>();var entries=r.GetEditorBindings().ToList();entries.Add(new LuaReference.Entry(key,target));r.SetEditorBindings(entries.ToArray());}
        private static Button Button(GameObject root,string key,Transform p,string text,float x,float y,float w,float h,bool dark=false)
        {
            var r=Rect(key,p,x,y,w,h);var bg=Paint(r,dark?Ink:new Color(.77f,.73f,.63f,.32f),true);
            var b=r.gameObject.AddComponent<Button>();b.targetGraphic=bg;b.navigation=new Navigation {mode=Navigation.Mode.None};
            var colors=b.colors;colors.highlightedColor=new Color(1.08f,1.06f,.98f);colors.pressedColor=new Color(.85f,.84f,.77f);colors.disabledColor=new Color(.7f,.7f,.7f,.45f);b.colors=colors;
            var t=Label("Label",r,text,8,0,w-16,h,14,dark?Paper:Ink);t.alignment=TextAnchor.MiddleCenter;
            Bind(root,key,b);Bind(root,key+"Text",t);return b;
        }
        private static RectTransform Scroll(GameObject root,string key,Transform p,float x,float y,float w,float h,int columns=0,Vector2 cell=default(Vector2),bool graph=false)
        {
            var r=Rect(key+"Scroll",p,x,y,w,h);Paint(r,new Color(1,1,1,.015f),true);
            var viewport=Rect("Viewport",r,0,0,w,h);viewport.gameObject.AddComponent<RectMask2D>();
            var c=Rect(key,viewport,0,0,w,graph?h:0);
            if(!graph)
            {
                if(columns>0) {var g=c.gameObject.AddComponent<GridLayoutGroup>();g.constraint=GridLayoutGroup.Constraint.FixedColumnCount;g.constraintCount=columns;g.cellSize=cell;g.spacing=new Vector2(10,10);}
                else {var v=c.gameObject.AddComponent<VerticalLayoutGroup>();v.spacing=8;v.childControlWidth=true;v.childControlHeight=false;v.childForceExpandWidth=true;v.childForceExpandHeight=false;}
                c.gameObject.AddComponent<ContentSizeFitter>().verticalFit=ContentSizeFitter.FitMode.PreferredSize;
            }
            var s=r.gameObject.AddComponent<ScrollRect>();s.viewport=viewport;s.content=c;s.horizontal=graph;s.vertical=true;s.scrollSensitivity=30;s.movementType=ScrollRect.MovementType.Clamped;
            Bind(root,key,c);Bind(root,key+"Scroll",s);return c;
        }
        public static void Build(GameObject root)
        {
            PrepareSprites();
            var veil=Rect("Veil",root.transform,0,0,1280,720);veil.anchorMin=Vector2.zero;veil.anchorMax=Vector2.one;veil.offsetMin=veil.offsetMax=Vector2.zero;Paint(veil,new Color(.03f,.045f,.035f,.91f),true);
            var page=Rect("Page",root.transform,0,0,1200,664);page.anchorMin=page.anchorMax=page.pivot=new Vector2(.5f,.5f);page.anchoredPosition=Vector2.zero;Paint(page,Paper,true);
            var style=root.AddComponent<StoryGrowthView>();Bind(root,"Style",style);Bind(root,"Page",page);
            Paint(Rect("TopRule",page,20,16,1160,1),Gold);Paint(Rect("BottomRule",page,20,647,1160,1),Gold);
            var hero=Rect("Hero",page,20,30,246,602);Paint(hero,Ink);
            Label("Collection",hero,"边 境 远 征  /  同 行 者",18,15,218,28,12,new Color(.74f,.70f,.56f));
            Bind(root,"Title",Label("Title",hero,"艾岚",18,50,218,44,29,Paper));
            Bind(root,"Role",Label("Role",hero,"剑士",20,94,200,25,14,new Color(.74f,.70f,.56f)));
            var portrait=Rect("Portrait",hero,8,126,230,308);var raw=portrait.gameObject.AddComponent<RawImage>();raw.raycastTarget=true;
            var character=portrait.gameObject.AddComponent<InventoryCharacterView>();
            var parts=JsonUtility.FromJson<Parts>(File.ReadAllText("Config/Tables/Adventure/PawnPartTable.json")).rows;
            var bindings=parts.Select(p=>new MapRuntimeDemo.AssetBinding {id=p.id,path=p.prefabPath,prefab=AssetDatabase.LoadAssetAtPath<GameObject>(p.prefabPath)}).ToArray();
            character.Bind(raw,AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab").GetComponent<PawnView>(),bindings,Array.Empty<InventoryCharacterView.Callout>());
            var so=new SerializedObject(character);so.FindProperty("background").colorValue=Ink;so.ApplyModifiedPropertiesWithoutUndo();Bind(root,"Character",character);
            Bind(root,"HeroLevel",Label("HeroLevel",hero,"旅人 · 等级 1",18,442,210,28,19,Paper));
            Bind(root,"HeroHealth",Label("HeroHealth",hero,"生命  46 / 46",18,479,210,24,14,new Color(.77f,.80f,.69f)));
            Paint(Rect("ExperienceTrack",hero,18,518,210,3),new Color(.35f,.39f,.31f));
            var xp=Paint(Rect("ExperienceFill",hero,18,518,210,3),new Color(.76f,.61f,.36f));Bind(root,"ExperienceFill",xp.rectTransform);
            Bind(root,"HeroExperience",Label("HeroExperience",hero,"距下一次成长",18,530,210,25,12,new Color(.74f,.70f,.56f)));
            Label("OrbitHint",hero,"拖动旋转 · 滚轮缩放",18,572,210,20,11,new Color(.60f,.65f,.55f));
            Label("BookTitle",page,"旅 人 手 记",292,29,300,39,28);Label("BookSubtitle",page,"来历、选择，以及尚未走过的路。",294,69,540,26,13,Muted);
            Button(root,"Close",page,"关闭  ×",1084,34,86,31);
            for(int i=1;i<=4;i++) Button(root,"Party"+i,page,"同行者",292+(i-1)*216,107,204,31);
            Bind(root,"Summary",Label("Summary",page,"",294,145,880,25,13,Gold));
            Button(root,"OverviewTab",page,"总 览",292,180,148,36);Button(root,"SkillsTab",page,"天 赋 与 技 能",448,180,184,36);Button(root,"HistoryTab",page,"经 历",640,180,148,36);
            Paint(Rect("SectionRule",page,292,224,878,1),Line);
            var overview=Rect("Overview",page,292,240,878,362);Bind(root,"Overview",overview);
            Label("AttributesHeading",overview,"属 性",0,0,470,27,19);Label("AttributeNote",overview,"选择 + 为属性投入一点",0,29,480,20,12,Muted);
            Scroll(root,"Attributes",overview,0,62,534,300,3,new Vector2(170,58));
            Paint(Rect("Divider",overview,552,0,1,357),Line);Label("TraitsHeading",overview,"旅 途 印 记",576,0,298,27,19);
            Label("TraitsNote",overview,"每段经历，都会留下痕迹。",576,29,298,20,12,Muted);
            Scroll(root,"Traits",overview,576,62,300,142,2,new Vector2(143,37));
            Bind(root,"TraitDetail",Label("TraitDetail",overview,"选择一枚印记，回顾它的来由。",576,220,298,125,14,Muted));
            var skills=Rect("Skills",page,292,236,878,377);Bind(root,"Skills",skills);
            Button(root,"PreviousTree",skills,"‹",0,0,30,29);Button(root,"NextTree",skills,"›",536,0,30,29);
            Bind(root,"TreeTitle",Label("TreeTitle",skills,"",40,0,492,29,17));
            Scroll(root,"Graph",skills,0,35,570,342,0,default(Vector2),true);
            Paint(Rect("Divider",skills,585,0,1,377),Line);
            Bind(root,"TalentName",Label("TalentName",skills,"选择一项天赋",607,0,270,29,20));
            Bind(root,"TalentDetail",Label("TalentDetail",skills,"",607,39,268,68,13,Muted));
            Button(root,"Invest",skills,"投入天赋点",607,116,267,35,true);
            Bind(root,"SkillTitle",Label("SkillTitle",skills,"主动技能",607,170,270,27,17));
            Scroll(root,"SkillRows",skills,607,207,267,170);
            var history=Rect("History",page,292,237,878,377);Bind(root,"History",history);
            Bind(root,"HistorySummary",Label("HistorySummary",history,"",0,0,625,32,18));
            Button(root,"PreviousHistory",history,"上一页",674,0,94,30);Button(root,"NextHistory",history,"下一页",781,0,94,30);
            Scroll(root,"HistoryRows",history,0,49,878,328);
            Bind(root,"Hint",Label("Hint",page,"",294,618,878,22,12,Muted));
            style.SetEditorBindings(root.GetComponentsInChildren<Text>(true),Array.Empty<StoryGrowthView.ArtEntry>(),page);
            style.SetJournalTheme(codes.Select(code=>new StoryGrowthView.GlyphEntry {Code=code,Sprite=sprites[code]}).ToArray());
        }
        private static Button RootButton(GameObject root,float w,float h,Color color)
        {
            ((RectTransform)root.transform).sizeDelta=new Vector2(w,h);var image=Paint((RectTransform)root.transform,color,true);
            var button=root.AddComponent<Button>();button.targetGraphic=image;button.navigation=new Navigation {mode=Navigation.Mode.None};Bind(root,"Button",button);Bind(root,"Background",image);return button;
        }
        private static void Flexible(Text t,float x,float widthOffset)
        {t.rectTransform.anchorMax=new Vector2(1,1);t.rectTransform.anchoredPosition=new Vector2(x,t.rectTransform.anchoredPosition.y);t.rectTransform.sizeDelta=new Vector2(widthOffset,t.rectTransform.sizeDelta.y);}
        private static void Attribute(GameObject root)
        {
            RootButton(root,170,58,new Color(.96f,.94f,.88f,.65f));
            Bind(root,"Icon",Paint(Rect("Icon",root.transform,10,13,28,28),Gold));
            Bind(root,"Title",Label("Title",root.transform,"体力",48,3,82,23,13,Muted));
            Bind(root,"Body",Label("Body",root.transform,"8",48,25,84,27,22));
            Bind(root,"Plus",Label("Plus",root.transform,"+",137,15,28,28,21,Gold));
        }
        private static void Skill(GameObject root)
        {
            RootButton(root,267,84,new Color(.98f,.96f,.9f,.45f));
            var t=Label("Title",root.transform,"",12,6,243,24,15);var b=Label("Body",root.transform,"",12,34,243,42,12,Muted);Flexible(t,12,-24);Flexible(b,12,-24);Bind(root,"Title",t);Bind(root,"Body",b);
        }
        private static void Entry(GameObject root)
        {
            RootButton(root,878,93,new Color(1,1,1,.08f));Paint(Rect("Timeline",root.transform,9,0,1,93),Line);
            Paint(Rect("Dot",root.transform,5,17,9,9),Gold,sprite:sprites["disc"]);
            var t=Label("Title",root.transform,"",28,4,836,25,16,Gold);var b=Label("Body",root.transform,"",28,34,836,50,14,Muted);Flexible(t,28,-42);Flexible(b,28,-42);Bind(root,"Title",t);Bind(root,"Body",b);
        }
        private static void Tag(GameObject root)
        {
            RootButton(root,143,37,new Color(.75f,.78f,.66f,.50f));
            Bind(root,"Title",Label("Title",root.transform,"◆ 印记",10,0,123,37,13));
            var body=Label("Body",root.transform,"",0,0,1,1,1);body.gameObject.SetActive(false);Bind(root,"Body",body);
        }
        private static void Talent(GameObject root)
        {
            var button=RootButton(root,100,91,Color.clear);
            var disc=Paint(Rect("Seal",root.transform,24,0,52,52),Paper,true,sprites["disc"]);button.targetGraphic=disc;
            // Background means the colored seal, not the transparent hit area.
            var refs=root.GetComponent<LuaReference>();var all=refs.GetEditorBindings().Where(e=>e.Key!="Background").ToList();all.Add(new LuaReference.Entry("Background",disc));refs.SetEditorBindings(all.ToArray());
            var ring=Paint(Rect("Ring",root.transform,20,-4,60,60),Gold,false,sprites["ring"]);
            ring.rectTransform.anchorMin=ring.rectTransform.anchorMax=new Vector2(.5f,1);
            ring.rectTransform.pivot=new Vector2(.5f,.5f);ring.rectTransform.anchoredPosition=new Vector2(0,-26);
            Bind(root,"Ring",ring);
            Bind(root,"Icon",Paint(Rect("Icon",root.transform,34,10,32,32),Ink));
            var t=Label("Title",root.transform,"",0,56,100,22,13);t.alignment=TextAnchor.MiddleCenter;Bind(root,"Title",t);
            var rank=Label("Rank",root.transform,"",68,33,29,20,11,Gold);rank.alignment=TextAnchor.MiddleCenter;Bind(root,"Rank",rank);
        }
        private static void PrepareSprites()
        {
            codes=ReadGlyphCodes();
            sprites=new Dictionary<string,Sprite>();if(!AssetDatabase.IsValidFolder("Assets/DynamicAsset/UI/Art/Journal")) AssetDatabase.CreateFolder("Assets/DynamicAsset/UI/Art","Journal");
            foreach(var code in codes.Concat(new[]{"disc","ring"}))
            {
                var path="Assets/DynamicAsset/UI/Art/Journal/"+code+".asset";
                var existing=AssetDatabase.LoadAllAssetsAtPath(path).OfType<Sprite>().FirstOrDefault();if(existing!=null) {sprites.Add(code,existing);continue;}
                var points=code=="disc" || code=="ring"?Array.Empty<Vector2>():Glyph(code);
                var texture=new Texture2D(64,64,TextureFormat.RGBA32,false) {name=code,filterMode=FilterMode.Bilinear,wrapMode=TextureWrapMode.Clamp};
                var colors=new Color[4096];
                for(int y=0;y<64;y++) for(int x=0;x<64;x++)
                {
                    var p=new Vector2(x+.5f,y+.5f);float distance=100;
                    if(code=="disc") distance=(p-new Vector2(32,32)).magnitude-30;
                    else if(code=="ring") distance=Mathf.Abs((p-new Vector2(32,32)).magnitude-29)-.9f;
                    else for(int j=0;j<points.Length;j+=2)
                    {var a=points[j];var d=points[j+1]-a;var q=a+d*Mathf.Clamp01(Vector2.Dot(p-a,d)/d.sqrMagnitude);distance=Mathf.Min(distance,Vector2.Distance(p,q)-1.6f);}
                    colors[y*64+x]=new Color(1,1,1,Mathf.Clamp01(.7f-distance));
                }
                texture.SetPixels(colors);texture.Apply();AssetDatabase.CreateAsset(texture,path);
                var sprite=Sprite.Create(texture,new UnityEngine.Rect(0,0,64,64),new Vector2(.5f,.5f),64);sprite.name=code;AssetDatabase.AddObjectToAsset(sprite,texture);sprites.Add(code,sprite);
            }
        }
        private static Vector2[] Glyph(string code)
        {
            float[] p;
            switch(code)
            {
                case "vitality":p=new float[]{32,12,12,34,12,34,12,45,12,45,22,51,22,51,32,42,32,42,42,51,42,51,52,45,52,45,52,34,52,34,32,12};break;
                case "defense":case "endurance":case "shield":p=new float[]{14,49,32,55,32,55,50,49,50,49,47,27,47,27,32,10,32,10,17,27,17,27,14,49,32,18,32,45};break;
                case "intellect":case "staff":p=new float[]{32,55,38,38,38,38,55,32,55,32,38,26,38,26,32,9,32,9,26,26,26,26,9,32,9,32,26,38,26,38,32,55};break;
                case "speed":case "dagger":p=new float[]{36,55,17,31,17,31,30,31,30,31,25,10,25,10,48,36,48,36,35,36,35,36,36,55};break;
                case "scouting":p=new float[]{7,32,20,44,20,44,44,44,44,44,57,32,57,32,44,20,44,20,20,20,20,20,7,32,32,23,32,41,25,32,39,32};break;
                case "crafting":p=new float[]{18,8,40,40,23,43,36,54,36,54,53,40,53,40,41,29,41,29,23,43};break;
                case "cooking":p=new float[]{11,32,53,32,11,32,19,14,19,14,45,14,45,14,53,32,22,40,26,50,38,40,42,50};break;
                case "bow":p=new float[]{18,10,39,23,39,23,44,32,44,32,39,41,39,41,18,54,18,10,18,54,10,32,54,32,46,38,54,32,46,26,54,32};break;
                case "animalAffinity":p=new float[]{20,15,18,23,18,23,24,32,24,32,32,35,32,35,40,32,40,32,46,23,46,23,44,15,44,15,32,12,32,12,20,15,
                    8,36,11,43,11,43,17,42,17,42,19,36,19,36,14,31,14,31,8,36,
                    20,47,23,55,23,55,29,53,29,53,30,46,30,46,25,41,25,41,20,47,
                    34,46,36,53,36,53,42,54,42,54,45,47,45,47,40,41,40,41,34,46,
                    46,36,48,42,48,42,54,43,54,43,57,36,57,36,51,31,51,31,46,36};break;
                case "charisma":p=new float[]{18,42,18,49,18,49,24,54,24,54,31,52,31,52,35,46,35,46,31,39,31,39,24,37,24,37,18,42,
                    8,13,11,25,11,25,20,32,20,32,30,32,30,32,40,25,40,25,43,13,43,13,8,13,
                    40,54,57,54,57,54,57,38,57,38,48,38,48,38,43,33,43,33,43,38,43,38,40,38,40,38,40,54,45,48,53,48,45,43,51,43};break;
                case "strength":case "sword":case "polearm":case "unarmed":case "greatsword":case "firearms":
                    p=new float[]{15,12,48,50,48,50,52,54,52,54,54,43,54,43,23,14,13,27,32,11,9,7,18,16};break;
                default:throw new InvalidOperationException("No journal glyph asset or drawing recipe for "+code+". Add its Journal Sprite before synchronizing.");
            }
            var result=new Vector2[p.Length/2];for(int i=0;i<result.Length;i++) result[i]=new Vector2(p[i*2],p[i*2+1]);return result;
        }
    }
}
