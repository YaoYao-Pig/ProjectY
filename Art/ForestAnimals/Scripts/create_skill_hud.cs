// 通过 Unity MCP 编辑 Prefab 和 LuaReference；只保存本次技能栏与队员选择绑定。
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var config=ProjectY.Editor.PanelAssets.LoadOrCreate();
var ink=new UnityEngine.Color(.055f,.075f,.068f,.97f);var card=new UnityEngine.Color(.12f,.16f,.14f,.97f);
var gold=new UnityEngine.Color(.78f,.65f,.39f);var paper=new UnityEngine.Color(.92f,.89f,.79f);
System.Func<string,UnityEngine.Transform,UnityEngine.Vector4,UnityEngine.RectTransform> rect=(name,parent,box)=>{
 var r=(UnityEngine.RectTransform)new UnityEngine.GameObject(name,typeof(UnityEngine.RectTransform)).transform;r.SetParent(parent,false);
 r.anchorMin=r.anchorMax=new UnityEngine.Vector2(0,1);r.pivot=new UnityEngine.Vector2(0,1);r.anchoredPosition=new UnityEngine.Vector2(box.x,-box.y);r.sizeDelta=new UnityEngine.Vector2(box.z,box.w);return r;
};
System.Action<UnityEngine.GameObject,string,UnityEngine.Component> bind=(root,key,value)=>{
 var reference=root.GetComponent<ProjectY.UI.LuaReference>();var rows=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
 int index=rows.FindIndex(row=>row.Key==key);var bindingEntry=new ProjectY.UI.LuaReference.Entry(key,value);
 if(index<0)rows.Add(bindingEntry);else rows[index]=bindingEntry;reference.SetEditorBindings(rows.ToArray());
};
System.Func<UnityEngine.RectTransform,UnityEngine.Color,bool,UnityEngine.UI.Image> paint=(r,color,hit)=>{
 var image=r.gameObject.AddComponent<UnityEngine.UI.Image>();image.color=color;image.raycastTarget=hit;return image;
};
System.Func<string,UnityEngine.Transform,string,UnityEngine.Vector4,UnityEngine.UI.Text> label=(name,parent,value,box)=>{
 var text=rect(name,parent,box).gameObject.AddComponent<UnityEngine.UI.Text>();text.font=UnityEngine.Resources.GetBuiltinResource<UnityEngine.Font>("LegacyRuntime.ttf");
 text.fontSize=14;text.text=value;text.color=paper;text.raycastTarget=false;text.alignment=UnityEngine.TextAnchor.MiddleLeft;text.supportRichText=false;return text;
};
System.Action<UnityEngine.GameObject> selection=root=>{
 var image=paint(rect("Selected",root.transform,new UnityEngine.Vector4(0,0,0,3)),gold,false);
 image.rectTransform.anchorMin=new UnityEngine.Vector2(0,1);image.rectTransform.anchorMax=UnityEngine.Vector2.one;image.rectTransform.sizeDelta=new UnityEngine.Vector2(0,3);
 bind(root,"Selected",image);image.gameObject.SetActive(false);
};
var entry=config.Entries.Find(e=>e.Name=="CharacterSkill");
if(entry==null)entry=ProjectY.Editor.PanelAssets.Save(new ProjectY.UI.PanelDefinition {Name="CharacterSkill",Module="MainHud",Kind=ProjectY.UI.UIKind.Widget,Layer="Main",Cache=true,Modal=false,CloseOnBack=false},null);
if(entry.Prefab==null){
 var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
 try{
  var root=new UnityEngine.GameObject(entry.PrefabName,typeof(UnityEngine.RectTransform));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
  ProjectY.Editor.PanelAssets.ConfigureRoot(root,entry,true);var r=(UnityEngine.RectTransform)root.transform;r.sizeDelta=new UnityEngine.Vector2(134,62);
  var image=paint(r,card,true);var button=root.AddComponent<UnityEngine.UI.Button>();button.targetGraphic=image;button.navigation=new UnityEngine.UI.Navigation {mode=UnityEngine.UI.Navigation.Mode.None};
  bind(root,"Button",button);bind(root,"Pointer",root.AddComponent<ProjectY.UI.UIPointerState>());
  bind(root,"Title",label("Title",r,"技能",new UnityEngine.Vector4(9,3,116,24)));
  var contexts=label("Contexts",r,"生活 + 战斗",new UnityEngine.Vector4(9,26,116,16));contexts.fontSize=10;contexts.color=gold;bind(root,"Contexts",contexts);
  var state=label("State",r,"点击使用",new UnityEngine.Vector4(9,43,116,16));state.fontSize=11;bind(root,"State",state);selection(root);
  root.GetComponent<ProjectY.UI.LuaReference>().ValidateBindings();entry.Prefab=UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);
 }finally{UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
}
ProjectY.Editor.LuaViewHints.Export(entry.Prefab.GetComponent<ProjectY.UI.LuaReference>(),entry.ViewType);
var partyEntry=config.Get("HudParty");var party=UnityEditor.PrefabUtility.LoadPrefabContents(partyEntry.PrefabPath);
try{
 var reference=party.GetComponent<ProjectY.UI.LuaReference>();var entries=reference.GetEditorBindings();
 if(!System.Array.Exists(entries,e=>e.Key=="Button")){
  var image=party.GetComponent<UnityEngine.UI.Image>();image.raycastTarget=true;
  var button=party.AddComponent<UnityEngine.UI.Button>();button.targetGraphic=image;button.navigation=new UnityEngine.UI.Navigation {mode=UnityEngine.UI.Navigation.Mode.None};bind(party,"Button",button);selection(party);
 }
 reference.ValidateBindings();UnityEditor.PrefabUtility.SaveAsPrefabAsset(party,partyEntry.PrefabPath);ProjectY.Editor.LuaViewHints.Export(reference,partyEntry.ViewType);
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(party);}
var hudEntry=config.Get("MainHud");var hud=UnityEditor.PrefabUtility.LoadPrefabContents(hudEntry.PrefabPath);
try{
 var reference=hud.GetComponent<ProjectY.UI.LuaReference>();
 if(!System.Array.Exists(reference.GetEditorBindings(),e=>e.Key=="CharacterSkills")){
  var parent=reference.GetTransform("PartyRows").parent;
  var panel=rect("CharacterSkills",parent,new UnityEngine.Vector4(16,0,712,116));panel.anchorMin=panel.anchorMax=UnityEngine.Vector2.zero;panel.pivot=UnityEngine.Vector2.zero;panel.anchoredPosition=new UnityEngine.Vector2(16,80);paint(panel,ink,true);bind(hud,"CharacterSkills",panel);
  var title=label("SkillActor",panel,"选择队员 · 生活技能",new UnityEngine.Vector4(12,3,530,24));title.color=gold;bind(hud,"SkillActor",title);
  title.rectTransform.anchorMax=UnityEngine.Vector2.one;title.rectTransform.sizeDelta=new UnityEngine.Vector2(-152,24);
  var cancelRect=rect("CancelSkill",panel,new UnityEngine.Vector4(-104,5,92,22));cancelRect.anchorMin=cancelRect.anchorMax=UnityEngine.Vector2.one;
  var cancelImage=paint(cancelRect,card,true);var cancel=cancelRect.gameObject.AddComponent<UnityEngine.UI.Button>();cancel.targetGraphic=cancelImage;cancel.navigation=new UnityEngine.UI.Navigation{mode=UnityEngine.UI.Navigation.Mode.None};bind(hud,"CancelSkill",cancel);
  var cancelText=label("Label",cancelRect,"取消  Esc",new UnityEngine.Vector4(0,0,92,22));cancelText.fontSize=12;cancelText.alignment=UnityEngine.TextAnchor.MiddleCenter;bind(hud,"CancelSkillText",cancelText);
  var viewport=rect("Viewport",panel,new UnityEngine.Vector4(10,29,692,62));viewport.anchorMax=UnityEngine.Vector2.one;viewport.sizeDelta=new UnityEngine.Vector2(-20,62);viewport.gameObject.AddComponent<UnityEngine.UI.RectMask2D>();
  var content=rect("CharacterSkillSlots",viewport,new UnityEngine.Vector4(0,0,0,62));var group=content.gameObject.AddComponent<UnityEngine.UI.HorizontalLayoutGroup>();group.spacing=7;group.childControlWidth=false;group.childControlHeight=false;group.childForceExpandWidth=false;group.childForceExpandHeight=false;
  var fitter=content.gameObject.AddComponent<UnityEngine.UI.ContentSizeFitter>();fitter.horizontalFit=UnityEngine.UI.ContentSizeFitter.FitMode.PreferredSize;
  var scroll=viewport.gameObject.AddComponent<UnityEngine.UI.ScrollRect>();scroll.viewport=viewport;scroll.content=content;scroll.horizontal=true;scroll.vertical=false;scroll.scrollSensitivity=30;scroll.movementType=UnityEngine.UI.ScrollRect.MovementType.Clamped;
  paint(viewport,new UnityEngine.Color(0,0,0,.01f),true);bind(hud,"CharacterSkillSlots",content);
  var empty=label("SkillEmpty",panel,"点击下方队员卡片进行选择",new UnityEngine.Vector4(14,40,680,35));empty.fontSize=13;empty.rectTransform.anchorMax=UnityEngine.Vector2.one;empty.rectTransform.sizeDelta=new UnityEngine.Vector2(-28,35);bind(hud,"SkillEmpty",empty);
  var hint=label("SkillHint",panel,"生活技能 · 悬停查看说明",new UnityEngine.Vector4(12,93,688,20));hint.fontSize=11;hint.rectTransform.anchorMax=UnityEngine.Vector2.one;hint.rectTransform.sizeDelta=new UnityEngine.Vector2(-24,20);bind(hud,"SkillHint",hint);
 }
 reference.ValidateBindings();UnityEditor.PrefabUtility.SaveAsPrefabAsset(hud,hudEntry.PrefabPath);ProjectY.Editor.LuaViewHints.Export(reference,hudEntry.ViewType);
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(hud);}
UnityEditor.EditorUtility.SetDirty(config);UnityEditor.AssetDatabase.SaveAssets();
return new{widget=entry.PrefabPath,hud=hudEntry.PrefabPath,party=partyEntry.PrefabPath};
