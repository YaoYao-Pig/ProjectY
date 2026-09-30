// 经 Unity MCP 在现有 GM Prefab 上增加显式引用；不生成/重载 C# 脚本。
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var config=ProjectY.Editor.PanelAssets.LoadOrCreate();var entry=config.Get("GM");
var root=UnityEditor.PrefabUtility.LoadPrefabContents(entry.PrefabPath);
try{
 var reference=root.GetComponent<ProjectY.UI.LuaReference>();
 var frame=(UnityEngine.RectTransform)reference.GetText("Title").transform.parent;
 frame.sizeDelta=new UnityEngine.Vector2(1040,590);
 reference.GetText("Title").text="GM · 角色与 NPC";
 reference.GetText("Title").rectTransform.sizeDelta=new UnityEngine.Vector2(820,34);
 ((UnityEngine.RectTransform)reference.GetButton("Close").transform).anchoredPosition=new UnityEngine.Vector2(962,-20);
 var result=reference.GetText("Result");result.rectTransform.sizeDelta=new UnityEngine.Vector2(490,170);result.alignment=UnityEngine.TextAnchor.UpperLeft;
 System.Action<string,UnityEngine.Component> bind=(key,value)=>{
  var rows=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
  var index=rows.FindIndex(r=>r.Key==key);var next=new ProjectY.UI.LuaReference.Entry(key,value);if(index<0)rows.Add(next);else rows[index]=next;reference.SetEditorBindings(rows.ToArray());
 };
 System.Func<string,UnityEngine.Transform,float,float,float,float,UnityEngine.RectTransform> rect=(name,parent,x,y,w,h)=>{
  var value=(UnityEngine.RectTransform)new UnityEngine.GameObject(name,typeof(UnityEngine.RectTransform)).transform;value.SetParent(parent,false);
  value.anchorMin=value.anchorMax=value.pivot=new UnityEngine.Vector2(0,1);value.anchoredPosition=new UnityEngine.Vector2(x,-y);value.sizeDelta=new UnityEngine.Vector2(w,h);return value;
 };
 System.Func<string,UnityEngine.Transform,string,float,float,float,float,UnityEngine.UI.Text> text=(name,parent,caption,x,y,w,h)=>{
  var value=rect(name,parent,x,y,w,h).gameObject.AddComponent<UnityEngine.UI.Text>();value.font=UnityEngine.Resources.GetBuiltinResource<UnityEngine.Font>("LegacyRuntime.ttf");
  value.text=caption;value.fontSize=15;value.color=new UnityEngine.Color(.92f,.89f,.79f);value.raycastTarget=false;value.alignment=UnityEngine.TextAnchor.MiddleLeft;return value;
 };
 if(!System.Array.Exists(reference.GetEditorBindings(),r=>r.Key=="NpcSearch")){
  var title=text("NpcTitle",frame,"查找 NPC · 名称 / ID",560,83,300,28);title.color=new UnityEngine.Color(.78f,.65f,.39f);bind("NpcTitle",title);
  var searchRect=rect("NpcSearch",frame,560,120,452,36);var image=searchRect.gameObject.AddComponent<UnityEngine.UI.Image>();image.color=new UnityEngine.Color(.20f,.25f,.21f);
  var search=searchRect.gameObject.AddComponent<UnityEngine.UI.InputField>();search.targetGraphic=image;search.contentType=UnityEngine.UI.InputField.ContentType.Standard;search.characterLimit=80;
  var inputText=text("Text",searchRect,"",10,0,432,36);search.textComponent=inputText;bind("NpcSearch",search);bind("NpcSearchText",inputText);
  var scrollerRect=rect("NpcScroll",frame,554,166,464,350);var background=scrollerRect.gameObject.AddComponent<UnityEngine.UI.Image>();background.color=new UnityEngine.Color(.04f,.06f,.05f,.7f);
  var viewport=rect("Viewport",scrollerRect,0,0,464,350);viewport.gameObject.AddComponent<UnityEngine.UI.RectMask2D>();
  var content=rect("NpcRows",viewport,0,0,464,0);content.anchorMax=new UnityEngine.Vector2(1,1);content.sizeDelta=UnityEngine.Vector2.zero;
  var layout=content.gameObject.AddComponent<UnityEngine.UI.VerticalLayoutGroup>();layout.spacing=8;layout.padding=new UnityEngine.RectOffset(6,6,6,6);layout.childControlHeight=true;layout.childControlWidth=true;layout.childForceExpandWidth=true;layout.childForceExpandHeight=false;
  content.gameObject.AddComponent<UnityEngine.UI.ContentSizeFitter>().verticalFit=UnityEngine.UI.ContentSizeFitter.FitMode.PreferredSize;
  var scroll=scrollerRect.gameObject.AddComponent<UnityEngine.UI.ScrollRect>();scroll.viewport=viewport;scroll.content=content;scroll.horizontal=false;scroll.vertical=true;scroll.scrollSensitivity=26;scroll.movementType=UnityEngine.UI.ScrollRect.MovementType.Clamped;
  bind("NpcRows",content);bind("NpcScroll",scroll);
  var count=text("NpcCount",frame,"",860,83,152,28);count.alignment=UnityEngine.TextAnchor.MiddleRight;count.fontSize=13;bind("NpcCount",count);
  var hint=text("NpcHint",frame,"留空显示全部叙事 NPC。点击条目传送，关闭 GM 后按 E 交谈。",560,526,452,46);hint.fontSize=13;bind("NpcHint",hint);
 }
 reference.ValidateBindings();UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);ProjectY.Editor.LuaViewHints.Export(reference,entry.ViewType);
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
UnityEditor.AssetDatabase.SaveAssets();return entry.PrefabPath;
