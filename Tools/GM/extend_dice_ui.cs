// Unity MCP authoring: saved GM dice combination controls, component references and language keys.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
ProjectY.UI.LuaLanguage.ReloadDefaults();
var entry=ProjectY.Editor.PanelAssets.LoadOrCreate().Get("GM");
var root=UnityEditor.PrefabUtility.LoadPrefabContents(entry.PrefabPath);
try{
 var reference=root.GetComponent<ProjectY.UI.LuaReference>();
 var bindings=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
 var texts=new System.Collections.Generic.List<ProjectY.UI.LuaReference.LocalizedText>(reference.GetEditorLocalizations());
 var frame=reference.GetText("Title").transform.parent;
 if(!bindings.Exists(row=>row.Key=="Frame"))bindings.Add(new ProjectY.UI.LuaReference.Entry("Frame",frame));
 System.Action<string,UnityEngine.Component> bind=(key,value)=>bindings.Add(new ProjectY.UI.LuaReference.Entry(key,value));
 System.Func<string,UnityEngine.Transform,float,float,float,float,UnityEngine.RectTransform> rect=(name,parent,x,y,w,h)=>{
  var value=(UnityEngine.RectTransform)new UnityEngine.GameObject(name,typeof(UnityEngine.RectTransform)).transform;value.SetParent(parent,false);
  value.anchorMin=value.anchorMax=value.pivot=new UnityEngine.Vector2(0,1);value.anchoredPosition=new UnityEngine.Vector2(x,-y);value.sizeDelta=new UnityEngine.Vector2(w,h);return value;
 };
 System.Func<string,UnityEngine.Transform,string,float,float,float,float,UnityEngine.UI.Text> label=(key,parent,id,x,y,w,h)=>{
  var value=rect(key,parent,x,y,w,h).gameObject.AddComponent<UnityEngine.UI.Text>();
  value.font=reference.GetText("Title").font;value.fontSize=16;value.color=new UnityEngine.Color(.92f,.89f,.79f);
  value.raycastTarget=false;value.alignment=UnityEngine.TextAnchor.MiddleLeft;
  value.text=id==null?"":ProjectY.UI.LuaLanguage.Get(id);bind(key,value);
  if(id!=null)texts.Add(new ProjectY.UI.LuaReference.LocalizedText(value,id));return value;
 };
 System.Func<string,UnityEngine.Transform,string,float,float,float,float,UnityEngine.UI.Button> button=(key,parent,id,x,y,w,h)=>{
  var node=rect(key,parent,x,y,w,h);var background=node.gameObject.AddComponent<UnityEngine.UI.Image>();background.color=new UnityEngine.Color(.13f,.18f,.15f);
  var value=node.gameObject.AddComponent<UnityEngine.UI.Button>();value.targetGraphic=background;value.navigation=new UnityEngine.UI.Navigation{mode=UnityEngine.UI.Navigation.Mode.None};bind(key,value);
  var caption=label(key+"Text",node,id,0,0,w,h);caption.alignment=UnityEngine.TextAnchor.MiddleCenter;return value;
 };
 if(!bindings.Exists(row=>row.Key=="DiceSettings")){
  reference.GetText("Result").rectTransform.sizeDelta=new UnityEngine.Vector2(490,120);
  button("DiceOpen",frame,"GMDiceOpen",24,408,492,36);
  var page=rect("DiceSettings",frame,0,78,1040,512);bind("DiceSettings",page);
  var background=page.gameObject.AddComponent<UnityEngine.UI.Image>();background.color=new UnityEngine.Color(.055f,.075f,.068f,1);
  var title=label("DiceTitle",page,"GMDiceTitle",24,6,460,34);title.fontSize=22;title.color=new UnityEngine.Color(.78f,.65f,.39f);
  var total=label("DiceTotal",page,null,716,6,300,34);total.alignment=UnityEngine.TextAnchor.MiddleRight;
  var help=label("DiceHelp",page,"GMDiceHelp",24,44,992,50);help.fontSize=14;
  var kinds=new[]{"D4","D6","D8","D10","D12","D20","D100"};
  for(int i=0;i<kinds.Length;i++){
   var kind=kinds[i];var row=rect("Row"+kind,page,24+(i%2)*504,108+(i/2)*62,488,46);
   var card=row.gameObject.AddComponent<UnityEngine.UI.Image>();card.color=new UnityEngine.Color(.085f,.115f,.10f);
   label("Dice"+kind+"Label",row,"GMDice"+kind+"Label",16,0,224,46);
   button("Dice"+kind+"Minus",row,"GMDiceRemove",286,5,40,36);
   var count=label("Dice"+kind+"Count",row,null,326,0,72,46);count.alignment=UnityEngine.TextAnchor.MiddleCenter;count.text=kind=="D6"?"1":"0";
   button("Dice"+kind+"Plus",row,"GMDiceAdd",398,5,40,36);
  }
  var error=label("DiceError",page,null,24,360,992,42);error.fontSize=14;error.color=new UnityEngine.Color(.93f,.54f,.49f);
  button("DiceClear",page,"GMDiceClear",24,428,160,40);
  button("DiceBack",page,"GMDiceBack",202,428,160,40);
  button("DiceThrow",page,"GMDiceThrow",816,428,200,40);
  page.gameObject.SetActive(false);
 }
 reference.SetEditorBindings(bindings.ToArray());reference.SetEditorLocalizations(texts.ToArray());reference.ValidateBindings();
 UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);ProjectY.Editor.LuaViewHints.Export(reference,entry.ViewType);
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
return entry.PrefabPath;
