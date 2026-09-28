// Unity MCP resource authoring: independent paused GM panel plus a MainHud entry.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var config=ProjectY.Editor.PanelAssets.LoadOrCreate();
if(!UnityEditor.AssetDatabase.IsValidFolder("Assets/DynamicAsset/UI/Prefabs/GM"))UnityEditor.AssetDatabase.CreateFolder("Assets/DynamicAsset/UI/Prefabs","GM");
var ink=new UnityEngine.Color(.055f,.075f,.068f,.98f);var card=new UnityEngine.Color(.13f,.18f,.15f);var gold=new UnityEngine.Color(.78f,.65f,.39f);var paper=new UnityEngine.Color(.92f,.89f,.79f);
System.Func<string,UnityEngine.Transform,UnityEngine.Vector4,UnityEngine.RectTransform> rect=(name,parent,box)=>{
 var r=(UnityEngine.RectTransform)new UnityEngine.GameObject(name,typeof(UnityEngine.RectTransform)).transform;r.SetParent(parent,false);r.anchorMin=r.anchorMax=new UnityEngine.Vector2(0,1);r.pivot=new UnityEngine.Vector2(0,1);r.anchoredPosition=new UnityEngine.Vector2(box.x,-box.y);r.sizeDelta=new UnityEngine.Vector2(box.z,box.w);return r;
};
System.Action<UnityEngine.GameObject,string,UnityEngine.Component> bind=(root,key,value)=>{
 var reference=root.GetComponent<ProjectY.UI.LuaReference>();var rows=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
 int index=rows.FindIndex(row=>row.Key==key);var binding=new ProjectY.UI.LuaReference.Entry(key,value);if(index<0)rows.Add(binding);else rows[index]=binding;reference.SetEditorBindings(rows.ToArray());
};
System.Func<UnityEngine.RectTransform,UnityEngine.Color,UnityEngine.UI.Image> paint=(r,color)=>{var image=r.gameObject.AddComponent<UnityEngine.UI.Image>();image.color=color;return image;};
System.Func<string,UnityEngine.Transform,string,UnityEngine.Vector4,UnityEngine.UI.Text> label=(name,parent,value,box)=>{
 var text=rect(name,parent,box).gameObject.AddComponent<UnityEngine.UI.Text>();text.font=UnityEngine.Resources.GetBuiltinResource<UnityEngine.Font>("LegacyRuntime.ttf");text.fontSize=15;text.text=value;text.color=paper;text.alignment=UnityEngine.TextAnchor.MiddleLeft;text.raycastTarget=false;return text;
};
System.Func<UnityEngine.GameObject,string,UnityEngine.Transform,string,UnityEngine.Vector4,UnityEngine.UI.Button> button=(root,key,parent,caption,box)=>{
 var r=rect(key,parent,box);var image=paint(r,card);var value=r.gameObject.AddComponent<UnityEngine.UI.Button>();value.targetGraphic=image;value.navigation=new UnityEngine.UI.Navigation{mode=UnityEngine.UI.Navigation.Mode.None};
 var text=label("Text",r,caption,new UnityEngine.Vector4(0,0,box.z,box.w));text.alignment=UnityEngine.TextAnchor.MiddleCenter;bind(root,key,value);bind(root,key+"Text",text);return value;
};
System.Action<UnityEngine.GameObject,string,string,UnityEngine.Transform,string,UnityEngine.Vector4> input=(root,key,textKey,parent,value,box)=>{
 var r=rect(key,parent,box);var image=paint(r,new UnityEngine.Color(.20f,.25f,.21f));var field=r.gameObject.AddComponent<UnityEngine.UI.InputField>();field.targetGraphic=image;field.contentType=UnityEngine.UI.InputField.ContentType.IntegerNumber;field.characterLimit=9;
 var text=label("Text",r,"",new UnityEngine.Vector4(9,0,box.z-18,box.w));field.textComponent=text;field.text=value;bind(root,key,field);bind(root,textKey,text);
};
var entry=config.Entries.Find(e=>e.Name=="GM");
if(entry==null)entry=ProjectY.Editor.PanelAssets.Save(new ProjectY.UI.PanelDefinition{Name="GM",Module="GM",Kind=ProjectY.UI.UIKind.Panel,Layer="Popup",Cache=true,Modal=true,PauseWorldOnOpen=true,CloseOnBack=true},null);
if(entry.Prefab==null){
 var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
 try{
  var root=new UnityEngine.GameObject(entry.PrefabName,typeof(UnityEngine.RectTransform));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);ProjectY.Editor.PanelAssets.ConfigureRoot(root,entry,true);
  paint((UnityEngine.RectTransform)root.transform,new UnityEngine.Color(0,0,0,.65f));
  var frame=rect("Frame",root.transform,new UnityEngine.Vector4(0,0,540,360));frame.anchorMin=frame.anchorMax=frame.pivot=new UnityEngine.Vector2(.5f,.5f);frame.anchoredPosition=UnityEngine.Vector2.zero;paint(frame,ink);
  var title=label("Title",frame,"GM · 角色调试",new UnityEngine.Vector4(24,15,390,34));title.fontSize=23;title.color=gold;bind(root,"Title",title);button(root,"Close",frame,"关闭",new UnityEngine.Vector4(462,20,54,28));
  var description=label("Description",frame,"槽位按队伍顺序从 1 开始 · F8 打开/关闭 · Esc 关闭",new UnityEngine.Vector4(24,51,492,26));description.fontSize=13;bind(root,"Description",description);
  bind(root,"Target",label("Target",frame,"",new UnityEngine.Vector4(24,83,492,26)));
  bind(root,"SlotLabel",label("SlotLabel",frame,"角色槽位",new UnityEngine.Vector4(24,119,86,34)));input(root,"Slot","SlotText",frame,"1",new UnityEngine.Vector4(114,119,88,34));
  button(root,"LevelUp",frame,"升 1 级",new UnityEngine.Vector4(340,119,176,34));
  bind(root,"SkillLabel",label("SkillLabel",frame,"技能 ID",new UnityEngine.Vector4(24,191,86,34)));input(root,"SkillId","SkillText",frame,"201",new UnityEngine.Vector4(114,191,112,34));
  button(root,"GrantSkill",frame,"获取技能",new UnityEngine.Vector4(340,191,176,34));
  var skillName=label("SkillName",frame,"",new UnityEngine.Vector4(114,230,402,24));skillName.fontSize=13;skillName.color=gold;bind(root,"SkillName",skillName);
  var result=label("Result",frame,"",new UnityEngine.Vector4(24,276,492,58));result.fontSize=14;bind(root,"Result",result);
  root.GetComponent<ProjectY.UI.LuaReference>().ValidateBindings();entry.Prefab=UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);
 }finally{UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
}
ProjectY.Editor.LuaViewHints.Export(entry.Prefab.GetComponent<ProjectY.UI.LuaReference>(),entry.ViewType);
var hudEntry=config.Get("MainHud");var hud=UnityEditor.PrefabUtility.LoadPrefabContents(hudEntry.PrefabPath);
try{
 var reference=hud.GetComponent<ProjectY.UI.LuaReference>();
 if(!System.Array.Exists(reference.GetEditorBindings(),e=>e.Key=="GM")){
  var header=reference.GetText("Location").transform.parent;
  var value=button(hud,"GM",header,"GM  F8",new UnityEngine.Vector4(-36,16,72,34));var r=(UnityEngine.RectTransform)value.transform;r.anchorMin=r.anchorMax=new UnityEngine.Vector2(.5f,1);
 }
 reference.ValidateBindings();UnityEditor.PrefabUtility.SaveAsPrefabAsset(hud,hudEntry.PrefabPath);ProjectY.Editor.LuaViewHints.Export(reference,hudEntry.ViewType);
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(hud);}
UnityEditor.EditorUtility.SetDirty(config);UnityEditor.AssetDatabase.SaveAssets();return entry.PrefabPath;
