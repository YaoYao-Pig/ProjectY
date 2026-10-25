// Presentation-only prefab layout pass. Run through Unity MCP in the existing idle Editor.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling||UnityEditor.EditorApplication.isUpdating)throw new System.Exception("Idle Edit Mode required");
// The whole red printed motif belongs in the fixed left cap, outside the stretch center.
var headerImporter=(UnityEditor.TextureImporter)UnityEditor.AssetImporter.GetAtPath("Assets/DynamicAsset/UI/Skins/CollageMatte/panel_header.png");
headerImporter.spriteBorder=new UnityEngine.Vector4(132,90,62,90);headerImporter.SaveAndReimport();
System.Action<UnityEngine.RectTransform,float,float,float,float> place=(r,x,y,w,h)=>{r.anchorMin=r.anchorMax=new UnityEngine.Vector2(0,1);r.pivot=new UnityEngine.Vector2(0,1);r.anchoredPosition=new UnityEngine.Vector2(x,-y);r.sizeDelta=new UnityEngine.Vector2(w,h);};
System.Action<UnityEngine.RectTransform,float,float,float,float> inset=(r,l,t,right,b)=>{r.anchorMin=UnityEngine.Vector2.zero;r.anchorMax=UnityEngine.Vector2.one;r.pivot=new UnityEngine.Vector2(.5f,.5f);r.offsetMin=new UnityEngine.Vector2(l,b);r.offsetMax=new UnityEngine.Vector2(-right,-t);};
System.Action<UnityEngine.GameObject,string,UnityEngine.Component> bind=(go,key,value)=>{var r=go.GetComponent<ProjectY.UI.LuaReference>();var entries=r.GetEditorBindings().Where(e=>e.Key!=key).ToList();entries.Add(new ProjectY.UI.LuaReference.Entry(key,value));r.SetEditorBindings(entries.ToArray());};
System.Func<UnityEngine.GameObject,UnityEngine.UI.LayoutElement> sizing=go=>{var c=go.GetComponent<UnityEngine.UI.LayoutElement>();return c!=null?c:go.AddComponent<UnityEngine.UI.LayoutElement>();};
System.Func<UnityEngine.GameObject,UnityEngine.UI.VerticalLayoutGroup> column=go=>{var c=go.GetComponent<UnityEngine.UI.VerticalLayoutGroup>();if(c==null)c=go.AddComponent<UnityEngine.UI.VerticalLayoutGroup>();c.childControlWidth=true;c.childControlHeight=true;c.childForceExpandWidth=true;c.childForceExpandHeight=false;return c;};
var paths=new[]{"Common/TabButtonWidget","Narrative/NarrativeEntryWidget","Narrative/DialogueEntryWidget","Adventure/StoryChoiceWidget","Adventure/JournalSkillWidget","Narrative/MissionJournalPanel","Narrative/DialoguePanel","Adventure/StoryEventPanel","Adventure/CharacterGrowthPanel","Equipment/InventoryPanel"};
ProjectY.Editor.LuaViewHints.Register(typeof(UnityEngine.UI.LayoutElement),"CS.UnityEngine.UI.LayoutElement");
ProjectY.Editor.LuaViewHints.Register(typeof(UnityEngine.UI.VerticalLayoutGroup),"CS.UnityEngine.UI.VerticalLayoutGroup");
ProjectY.Editor.LuaViewHints.Register(typeof(UnityEngine.UI.GridLayoutGroup),"CS.UnityEngine.UI.GridLayoutGroup");
ProjectY.Editor.LuaViewHints.Register(typeof(ProjectY.UI.NarrativeView),"CS.ProjectY.UI.NarrativeView");
ProjectY.Editor.LuaViewHints.Register(typeof(ProjectY.UI.StoryGrowthView),"CS.ProjectY.UI.StoryGrowthView");
ProjectY.Editor.LuaViewHints.Register(typeof(ProjectY.UI.InventoryCharacterView),"CS.ProjectY.UI.InventoryCharacterView");
foreach(var p in paths){
 var path="Assets/DynamicAsset/UI/Prefabs/"+p+".prefab";var go=UnityEditor.PrefabUtility.LoadPrefabContents(path);
 try{
  System.Func<string,UnityEngine.RectTransform> rect=name=>(UnityEngine.RectTransform)go.transform.Find(name);
  if(p.EndsWith("TabButtonWidget"))bind(go,"Sizing",sizing(go)); // neutral until MissionJournal applies its style
  if(p.EndsWith("NarrativeEntryWidget")){bind(go,"Layout",go.GetComponent<UnityEngine.UI.VerticalLayoutGroup>());bind(go,"Sizing",sizing(go));}
  if(p.EndsWith("DialogueEntryWidget")||p.EndsWith("StoryChoiceWidget")){bind(go,"Layout",column(go));bind(go,"Sizing",sizing(go));}
  if(p.EndsWith("JournalSkillWidget")){
   var g=column(go);g.padding=new UnityEngine.RectOffset(0,0,4,4);g.spacing=6;g.childAlignment=UnityEngine.TextAnchor.UpperLeft;
   foreach(var text in go.GetComponentsInChildren<UnityEngine.UI.Text>()){text.alignment=UnityEngine.TextAnchor.UpperLeft;text.horizontalOverflow=UnityEngine.HorizontalWrapMode.Wrap;text.verticalOverflow=UnityEngine.VerticalWrapMode.Overflow;}
  }
  if(p.EndsWith("MissionJournalPanel")){
   place(rect("Page/MatteTitle"),22,0,280,132);place(rect("Page/Title"),88,36,198,40);place(rect("Page/Caption"),88,78,198,24);
   place(rect("Page/Tabs"),316,16,542,80);var tabs=rect("Page/Tabs").GetComponent<UnityEngine.UI.HorizontalLayoutGroup>();
   tabs.spacing=8;tabs.childControlWidth=true;tabs.childControlHeight=true;tabs.childForceExpandWidth=true;tabs.childForceExpandHeight=false;tabs.childAlignment=UnityEngine.TextAnchor.MiddleLeft;tabs.childScaleWidth=false;tabs.childScaleHeight=false;
   place(rect("Page/Companions"),874,22,124,68);inset(rect("Page/Companions/CompanionsText"),18,14,18,14);
   place(rect("Page/Close"),1010,26,66,60);foreach(var label in rect("Page/Close").GetComponentsInChildren<UnityEngine.UI.Text>())inset(label.rectTransform,8,12,8,12);
   place(rect("Page/MissionsScroll"),20,132,256,452);
   var list=column(rect("Page/MissionsScroll/Viewport/Missions").gameObject);list.padding=new UnityEngine.RectOffset(12,12,18,18);list.spacing=12;
   inset(rect("Page/Scroll/Viewport"),16,22,16,22);
   var detail=column(rect("Page/Scroll/Viewport/Content").gameObject);detail.padding=new UnityEngine.RectOffset(16,16,8,16);detail.spacing=14;
   var grid=rect("Page/Scroll/Viewport/Content/Rewards").GetComponent<UnityEngine.UI.GridLayoutGroup>();grid.cellSize=new UnityEngine.Vector2(230,128);grid.spacing=new UnityEngine.Vector2(12,12);bind(go,"RewardsLayout",grid);
   place(rect("Page/PrimaryAction"),850,554,228,60);inset(rect("Page/PrimaryAction/PrimaryText"),28,12,28,12);
  }
  if(p.EndsWith("DialoguePanel")){
   place(rect("Page/Title"),78,25,316,40);place(rect("Page/Caption"),78,67,326,23);
   rect("Page/Hint").anchoredPosition=new UnityEngine.Vector2(0,30);rect("Page/Hint").sizeDelta=new UnityEngine.Vector2(-96,28);
   column(rect("Page/Scroll/Viewport/Content").gameObject).padding=new UnityEngine.RectOffset(4,4,8,12);
   column(rect("Page/ChoicesScroll/Viewport/Choices").gameObject).padding=new UnityEngine.RectOffset(4,4,6,8);
  }
  if(p.EndsWith("StoryEventPanel")){
   place(rect("Page/Title"),106,29,814,46);place(rect("Page/Description"),764,132,380,116);
   var description=rect("Page/Description").GetComponent<UnityEngine.UI.Text>();description.alignment=UnityEngine.TextAnchor.UpperLeft;description.horizontalOverflow=UnityEngine.HorizontalWrapMode.Wrap;
   place(rect("Page/Caption"),54,561,628,36);rect("Page/Caption").GetComponent<UnityEngine.UI.Text>().alignment=UnityEngine.TextAnchor.MiddleLeft;
   place(rect("Page/ChoicesScroll"),736,260,428,318);var list=column(rect("Page/ChoicesScroll/Viewport/Choices").gameObject);list.padding=new UnityEngine.RectOffset(4,4,4,12);list.spacing=10;
   var choices=rect("Page/ChoicesScroll/Viewport/Choices");choices.anchorMin=new UnityEngine.Vector2(0,1);choices.anchorMax=new UnityEngine.Vector2(1,1);choices.sizeDelta=new UnityEngine.Vector2(0,choices.sizeDelta.y);
   place(rect("Page/Continue"),916,576,246,54);inset(rect("Page/Continue/Label"),24,10,24,10);
  }
  if(p.EndsWith("CharacterGrowthPanel")){
   place(rect("Page/BookTitle"),322,32,500,32);place(rect("Page/BookSubtitle"),324,68,540,22);
   foreach(var name in new[]{"OverviewTab","SkillsTab","HistoryTab"}){var r=rect("Page/"+name);r.sizeDelta=new UnityEngine.Vector2(r.sizeDelta.x,44);inset(rect("Page/"+name+"/Label"),26,7,22,7);}
   var list=column(rect("Page/Skills/SkillRowsScroll/Viewport/SkillRows").gameObject);list.padding=new UnityEngine.RectOffset(22,22,16,18);list.spacing=12;
  }
  if(p.EndsWith("InventoryPanel")){
   foreach(var label in rect("Frame/Equipment/CharacterPreview").GetComponentsInChildren<UnityEngine.UI.Text>(true))if(label.name=="SlotName"){label.alignment=UnityEngine.TextAnchor.LowerCenter;label.fontSize=10;}
  }
  go.GetComponent<ProjectY.UI.LuaReference>().ValidateBindings();bool ok;UnityEditor.PrefabUtility.SaveAsPrefabAsset(go,path,out ok);if(!ok)throw new System.Exception(path);
  if(p.EndsWith("TabButtonWidget")||p.EndsWith("NarrativeEntryWidget")||p.EndsWith("DialogueEntryWidget")||p.EndsWith("StoryChoiceWidget")||p.EndsWith("MissionJournalPanel"))ProjectY.Editor.LuaViewHints.Export(go.GetComponent<ProjectY.UI.LuaReference>(),go.name+"View");
 }finally{UnityEditor.PrefabUtility.UnloadPrefabContents(go);}
}
return "10 prefabs updated: content safety insets, native preferred-height layout and neutral shared bindings. No 3D transforms or gameplay bindings modified.";
