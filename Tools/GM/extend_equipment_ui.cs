// Unity MCP authoring for the permanent GM equipment browser and virtual-list references.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
ProjectY.UI.LuaLanguage.ReloadDefaults();
var entry=ProjectY.Editor.PanelAssets.LoadOrCreate().Get("GM");
var root=UnityEditor.PrefabUtility.LoadPrefabContents(entry.PrefabPath);
try{
 var reference=root.GetComponent<ProjectY.UI.LuaReference>();
 var bindings=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
 var texts=new System.Collections.Generic.List<ProjectY.UI.LuaReference.LocalizedText>(reference.GetEditorLocalizations());
 var frame=reference.GetText("Title").transform.parent;
 if(!bindings.Exists(row=>row.Key=="EquipmentBrowser")){
  reference.GetText("Result").rectTransform.sizeDelta=new UnityEngine.Vector2(490,70);
  var open=UnityEngine.Object.Instantiate(reference.GetButton("GrantSkill"),frame,false);open.name="EquipmentOpen";
  var openRect=(UnityEngine.RectTransform)open.transform;openRect.anchoredPosition=new UnityEngine.Vector2(24,-354);openRect.sizeDelta=new UnityEngine.Vector2(492,36);
  var openText=open.GetComponentInChildren<UnityEngine.UI.Text>();openText.rectTransform.sizeDelta=new UnityEngine.Vector2(492,36);openText.text=ProjectY.UI.LuaLanguage.Get("GMEquipmentOpen");
  bindings.Add(new ProjectY.UI.LuaReference.Entry("EquipmentOpen",open));bindings.Add(new ProjectY.UI.LuaReference.Entry("EquipmentOpenText",openText));texts.Add(new ProjectY.UI.LuaReference.LocalizedText(openText,"GMEquipmentOpen"));
  var pageBindings=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>();
  var pageTexts=new System.Collections.Generic.List<ProjectY.UI.LuaReference.LocalizedText>();
  System.Func<string,UnityEngine.Transform,float,float,float,float,UnityEngine.RectTransform> rect=(name,parent,x,y,w,h)=>{
   var value=(UnityEngine.RectTransform)new UnityEngine.GameObject(name,typeof(UnityEngine.RectTransform)).transform;value.SetParent(parent,false);
   value.anchorMin=value.anchorMax=value.pivot=new UnityEngine.Vector2(0,1);value.anchoredPosition=new UnityEngine.Vector2(x,-y);value.sizeDelta=new UnityEngine.Vector2(w,h);return value;
  };
  System.Action<string,UnityEngine.Component> bind=(key,value)=>pageBindings.Add(new ProjectY.UI.LuaReference.Entry(key,value));
  System.Func<string,UnityEngine.Transform,string,float,float,float,float,UnityEngine.UI.Text> label=(name,parent,id,x,y,w,h)=>{
   var value=rect(name,parent,x,y,w,h).gameObject.AddComponent<UnityEngine.UI.Text>();value.font=reference.GetText("Title").font;
   value.fontSize=15;value.color=new UnityEngine.Color(.92f,.89f,.79f);value.raycastTarget=false;value.supportRichText=false;value.alignment=UnityEngine.TextAnchor.MiddleLeft;
   value.text=id==null?"":ProjectY.UI.LuaLanguage.Get(id);
   if(id!=null){texts.Add(new ProjectY.UI.LuaReference.LocalizedText(value,id));pageTexts.Add(new ProjectY.UI.LuaReference.LocalizedText(value,id));}
   return value;
  };
  System.Func<string,UnityEngine.Transform,string,float,float,float,float,UnityEngine.UI.Button> button=(name,parent,id,x,y,w,h)=>{
   var node=rect(name,parent,x,y,w,h);var image=node.gameObject.AddComponent<UnityEngine.UI.Image>();image.color=new UnityEngine.Color(.13f,.18f,.15f);
   var value=node.gameObject.AddComponent<UnityEngine.UI.Button>();value.targetGraphic=image;value.navigation=new UnityEngine.UI.Navigation{mode=UnityEngine.UI.Navigation.Mode.None};
   var caption=label("Text",node,id,0,0,w,h);caption.alignment=UnityEngine.TextAnchor.MiddleCenter;return value;
  };
  var page=rect("EquipmentBrowser",frame,0,78,1040,512);var pageReference=page.gameObject.AddComponent<ProjectY.UI.LuaReference>();
  var backdrop=page.gameObject.AddComponent<UnityEngine.UI.Image>();backdrop.color=new UnityEngine.Color(.055f,.075f,.068f,1);bind("Root",page);
  var title=label("Title",page,"GMEquipmentTitle",24,4,660,34);title.fontSize=22;title.color=new UnityEngine.Color(.78f,.65f,.39f);bind("Title",title);
  var help=label("Help",page,"GMEquipmentHelp",24,42,992,28);help.fontSize=13;bind("Help",help);
  bind("SearchLabel",label("SearchLabel",page,"GMEquipmentSearch",24,78,90,34));
  var inputRect=rect("Search",page,118,78,530,34);var inputBackground=inputRect.gameObject.AddComponent<UnityEngine.UI.Image>();inputBackground.color=new UnityEngine.Color(.20f,.25f,.21f);
  var input=inputRect.gameObject.AddComponent<UnityEngine.UI.InputField>();input.targetGraphic=inputBackground;input.characterLimit=80;input.contentType=UnityEngine.UI.InputField.ContentType.Standard;
  var inputText=label("Text",inputRect,null,10,0,510,34);input.textComponent=inputText;bind("Search",input);bind("SearchText",inputText);
  var count=label("Count",page,null,700,78,316,34);count.alignment=UnityEngine.TextAnchor.MiddleRight;bind("Count",count);
  var result=label("Result",page,null,24,120,992,32);result.fontSize=14;bind("Result",result);
  var list=rect("List",page,24,162,992,276);var listReference=list.gameObject.AddComponent<ProjectY.UI.LuaReference>();var scroll=list.gameObject.AddComponent<UnityEngine.UI.ScrollRect>();
  var viewport=rect("Viewport",list,0,0,970,276);viewport.gameObject.AddComponent<UnityEngine.UI.RectMask2D>();var viewportImage=viewport.gameObject.AddComponent<UnityEngine.UI.Image>();viewportImage.color=new UnityEngine.Color(.04f,.06f,.05f,1);
  var content=rect("Content",viewport,0,0,970,276);scroll.viewport=viewport;scroll.content=content;scroll.vertical=true;scroll.horizontal=false;scroll.scrollSensitivity=34;scroll.movementType=UnityEngine.UI.ScrollRect.MovementType.Clamped;
  var barRect=rect("Scrollbar",list,976,0,16,276);var barImage=barRect.gameObject.AddComponent<UnityEngine.UI.Image>();barImage.color=new UnityEngine.Color(.08f,.11f,.09f);
  var handle=rect("Handle",barRect,0,0,16,276);var handleImage=handle.gameObject.AddComponent<UnityEngine.UI.Image>();handleImage.color=new UnityEngine.Color(.45f,.42f,.27f);
  var bar=barRect.gameObject.AddComponent<UnityEngine.UI.Scrollbar>();bar.handleRect=handle;bar.targetGraphic=handleImage;bar.direction=UnityEngine.UI.Scrollbar.Direction.BottomToTop;bar.navigation=new UnityEngine.UI.Navigation{mode=UnityEngine.UI.Navigation.Mode.None};scroll.verticalScrollbar=bar;
  listReference.SetEditorBindings(new[]{new ProjectY.UI.LuaReference.Entry("ScrollRect",scroll)});bind("List",listReference);
  var template=rect("Template",page,0,0,970,64);var templateReference=template.gameObject.AddComponent<ProjectY.UI.LuaReference>();
  var card=template.gameObject.AddComponent<UnityEngine.UI.Image>();card.color=new UnityEngine.Color(.085f,.115f,.10f);
  var rowTitle=label("Title",template,null,16,3,776,28);rowTitle.fontSize=16;
  var detail=label("Detail",template,null,16,34,776,24);detail.fontSize=13;detail.color=new UnityEngine.Color(.78f,.76f,.68f);
  var add=button("Add",template,"GMEquipmentAdd",814,14,140,36);var addText=add.GetComponentInChildren<UnityEngine.UI.Text>();
  templateReference.SetEditorBindings(new[]{new ProjectY.UI.LuaReference.Entry("Root",template),new ProjectY.UI.LuaReference.Entry("Title",rowTitle),new ProjectY.UI.LuaReference.Entry("Detail",detail),new ProjectY.UI.LuaReference.Entry("Add",add),new ProjectY.UI.LuaReference.Entry("AddText",addText)});
  templateReference.SetEditorLocalizations(new[]{new ProjectY.UI.LuaReference.LocalizedText(addText,"GMEquipmentAdd")});template.gameObject.SetActive(false);bind("Template",templateReference);
  var back=button("Back",page,"GMEquipmentBack",24,450,176,36);bind("Back",back);bind("BackText",back.GetComponentInChildren<UnityEngine.UI.Text>());
  pageReference.SetEditorBindings(pageBindings.ToArray());pageReference.SetEditorLocalizations(pageTexts.ToArray());pageReference.ValidateBindings();
  bindings.Add(new ProjectY.UI.LuaReference.Entry("EquipmentBrowser",pageReference));page.gameObject.SetActive(false);
 }
 reference.SetEditorBindings(bindings.ToArray());reference.SetEditorLocalizations(texts.ToArray());reference.ValidateBindings();
 UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);ProjectY.Editor.LuaViewHints.Export(reference,entry.ViewType);
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
return entry.PrefabPath;
