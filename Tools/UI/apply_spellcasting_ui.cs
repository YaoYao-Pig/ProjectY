// Run through Unity MCP after the coordinated C# compilation. Edits prefab assets only.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new InvalidOperationException("Spellcasting UI installation requires idle Edit Mode.");
var panelConfig = UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
var sceneBefore = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
bool dirtyBefore = sceneBefore.isDirty;
System.Func<Transform,string,RectTransform> node = (parent,name) =>
{
    var found = parent.Find(name) as RectTransform;
    if (found != null) return found;
    var rect = (RectTransform)new GameObject(name, typeof(RectTransform)).transform;
    rect.SetParent(parent, false); rect.gameObject.layer = 5; return rect;
};
System.Action<ProjectY.UI.LuaReference,string,Component> bind = (reference,key,target) =>
{
    var entries = new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>();
    foreach (var entry in reference.GetEditorBindings()) if (entry.Key != key) entries.Add(entry);
    entries.Add(new ProjectY.UI.LuaReference.Entry(key,target)); reference.SetEditorBindings(entries.ToArray());
};
var healthEntry = panelConfig.Get("HudHealth");
var healthRoot = UnityEditor.PrefabUtility.LoadPrefabContents(healthEntry.PrefabPath);
try
{
    var reference = healthRoot.GetComponent<ProjectY.UI.LuaReference>();
    var effects = reference.Get("EffectSlots").GetComponent<ProjectY.UI.ArcLayoutGroup>();
    if (effects == null) throw new InvalidOperationException("Install the ground health HUD before casting points.");
    // Reserve both inner point rows before the first 22px status icon row.
    var arcSettings=new UnityEditor.SerializedObject(effects);
    arcSettings.FindProperty("radius").floatValue=2.25f;arcSettings.ApplyModifiedPropertiesWithoutUndo();
    var rect = node(healthRoot.transform,"CastingPointRing");
    if(rect.GetComponent<CanvasRenderer>()==null)rect.gameObject.AddComponent<CanvasRenderer>();
    rect.anchorMin=Vector2.zero;rect.anchorMax=Vector2.one;rect.pivot=new Vector2(.5f,.5f);
    rect.offsetMin=rect.offsetMax=Vector2.zero;rect.localScale=Vector3.one;rect.localRotation=Quaternion.identity;
    var ring = rect.GetComponent<ProjectY.UI.CastingPointRing>();
    if (ring == null) ring = rect.gameObject.AddComponent<ProjectY.UI.CastingPointRing>();
    ring.SetEditorBindings(effects);ring.raycastTarget=false;rect.gameObject.SetActive(false);
    bind(reference,"CastingPoints",ring);reference.ValidateBindings();
    ProjectY.Editor.LuaViewHints.Register(typeof(ProjectY.UI.CastingPointRing),"CS.ProjectY.UI.CastingPointRing");
    UnityEditor.PrefabUtility.SaveAsPrefabAsset(healthRoot,healthEntry.PrefabPath);
    ProjectY.Editor.LuaViewHints.Export(reference,healthEntry.ViewType);
}
finally { UnityEditor.PrefabUtility.UnloadPrefabContents(healthRoot); }

var battleEntry = panelConfig.Get("BattleHUD");
var battleRoot = UnityEditor.PrefabUtility.LoadPrefabContents(battleEntry.PrefabPath);
try
{
    var reference=battleRoot.GetComponent<ProjectY.UI.LuaReference>();
    var hud=(ProjectY.UI.BattleHUDView)reference.Get("HUD");
    var layout=hud.EditorLayout;
    var controls=node(layout.Deck,"CastingControls");
    controls.anchorMin=controls.anchorMax=controls.pivot=Vector2.zero;
    controls.anchoredPosition=new Vector2(0,248);controls.sizeDelta=new Vector2(layout.Deck.sizeDelta.x,42);
    var backdrop=controls.GetComponent<UnityEngine.UI.Image>();
    if(backdrop==null)backdrop=controls.gameObject.AddComponent<UnityEngine.UI.Image>();
    backdrop.color=new Color(.055f,.11f,.085f,.96f);backdrop.raycastTarget=false;
    var labels=new System.Collections.Generic.List<UnityEngine.UI.Text>(layout.Labels);
    System.Func<string,float,int,Color,UnityEngine.UI.Text> text=(name,y,size,tint)=>
    {
        var rect=node(controls,name);rect.anchorMin=new Vector2(0,0);rect.anchorMax=new Vector2(1,0);rect.pivot=Vector2.zero;
        rect.offsetMin=new Vector2(10,y);rect.offsetMax=new Vector2(-88,y+18);
        var label=rect.GetComponent<UnityEngine.UI.Text>();if(label==null)label=rect.gameObject.AddComponent<UnityEngine.UI.Text>();
        label.font=hud.Font;label.fontSize=size;label.color=tint;label.text="";label.raycastTarget=false;
        label.alignment=TextAnchor.MiddleLeft;label.horizontalOverflow=HorizontalWrapMode.Wrap;
        label.verticalOverflow=VerticalWrapMode.Truncate;label.resizeTextForBestFit=true;label.resizeTextMinSize=10;label.resizeTextMaxSize=size;
        if(!labels.Contains(label))labels.Add(label);bind(reference,name,label);return label;
    };
    text("CastingStatus",22,13,new Color(.55f,1,.7f,1));
    text("CastingDetail",3,12,new Color(.85f,.9f,.84f,1));
    System.Action<string,float> button=(name,x)=>
    {
        var rect=node(controls,name);rect.anchorMin=rect.anchorMax=new Vector2(1,.5f);rect.pivot=new Vector2(.5f,.5f);
        rect.anchoredPosition=new Vector2(x,0);rect.sizeDelta=new Vector2(30,30);
        var image=rect.GetComponent<UnityEngine.UI.Image>();if(image==null)image=rect.gameObject.AddComponent<UnityEngine.UI.Image>();
        image.color=new Color(.2f,.35f,.27f,1);
        var control=rect.GetComponent<UnityEngine.UI.Button>();if(control==null)control=rect.gameObject.AddComponent<UnityEngine.UI.Button>();
        control.targetGraphic=image;control.navigation=new UnityEngine.UI.Navigation{mode=UnityEngine.UI.Navigation.Mode.None};
        var caption=node(rect,"Label");caption.anchorMin=Vector2.zero;caption.anchorMax=Vector2.one;
        caption.offsetMin=caption.offsetMax=Vector2.zero;
        var label=caption.GetComponent<UnityEngine.UI.Text>();if(label==null)label=caption.gameObject.AddComponent<UnityEngine.UI.Text>();
        label.font=hud.Font;label.fontSize=23;label.alignment=TextAnchor.MiddleCenter;label.text="";
        label.color=new Color(.74f,1,.83f,1);label.raycastTarget=false;
        if(!labels.Contains(label))labels.Add(label);bind(reference,name,control);bind(reference,name+"Text",label);
    };
    button("CastingLess",-57);button("CastingMore",-21);
    bind(reference,"CastingPanel",controls);layout.Casting=controls;layout.Labels=labels.ToArray();hud.SetEditorLayout(layout);
    controls.gameObject.SetActive(false);reference.ValidateBindings();
    UnityEditor.PrefabUtility.SaveAsPrefabAsset(battleRoot,battleEntry.PrefabPath);
    ProjectY.Editor.LuaViewHints.Export(reference,battleEntry.ViewType);
}
finally { UnityEditor.PrefabUtility.UnloadPrefabContents(battleRoot); }
if (UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=sceneBefore || sceneBefore.isDirty!=dirtyBefore)
    throw new InvalidOperationException("Spellcasting UI migration changed the active scene.");
return "Saved casting-point arc and battle strength controls; preserved existing bindings and active scene.";
