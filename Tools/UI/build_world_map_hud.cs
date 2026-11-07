// Unity MCP execute_code method body. Run only after HudModeTransition is compiled
// and the UIWorldMap* LuaTxt keys are exported. No Refresh, compilation or Play switch.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("World-map HUD assets require Edit Mode.");
var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
if(config==null)throw new System.InvalidOperationException("PanelConfig is missing.");
var definition=config.Get("MainHud");definition.Validate(true);
var table=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Localization/LuaTxt.json"));
var language=new System.Collections.Generic.Dictionary<string,string>();
foreach(var row in table["rows"])language.Add((string)row["id"],(string)row["txt"]);
var requiredIds=new[]{"UIWorldMapTitle","UIWorldMapSubtitle","UIWorldMapFiltersTitle","UIWorldMapLegendTitle","UIWorldMapLegendBody","UIWorldMapHint",
    "UIWorldMapSiteTags","UIWorldMapAvailableMissions","UIWorldMapActiveMissions","UIWorldMapReadyMissions","UIWorldMapPlayerMarker","UIWorldMapRoute",
    "UIWorldMapClose","UIWorldMapHome","UIWorldMapMissions"};
foreach(var id in requiredIds)if(!language.ContainsKey(id))throw new System.InvalidOperationException("Export LuaTxt before building the HUD: "+id);
var manifest=Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText("Art/Localization/ui-text-bindings.json"));
var paper=new Color(.94f,.91f,.83f,.97f);var ink=new Color(.14f,.20f,.18f);var muted=new Color(.36f,.41f,.36f);var gold=new Color(.64f,.47f,.24f);
var cream=new Color(.98f,.96f,.89f);var dark=new Color(.075f,.11f,.10f,.96f);
System.Action<RectTransform> stretch=r=>{r.anchorMin=Vector2.zero;r.anchorMax=Vector2.one;r.pivot=new Vector2(.5f,.5f);r.offsetMin=r.offsetMax=Vector2.zero;};
System.Func<Transform,string,RectTransform> node=(parent,name)=>{
    var existing=parent.Find(name);
    if(existing!=null){if(!(existing is RectTransform))throw new System.InvalidOperationException("Expected RectTransform: "+name);return (RectTransform)existing;}
    var created=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;created.gameObject.layer=5;created.SetParent(parent,false);return created;
};
System.Action<RectTransform,float,float,float,float> box=(r,x,y,w,h)=>{
    r.anchorMin=r.anchorMax=new Vector2(0,1);r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(x,-y);r.sizeDelta=new Vector2(w,h);
};
System.Func<RectTransform,Color,bool,UnityEngine.UI.Image> paint=(r,color,hit)=>{
    var image=r.GetComponent<UnityEngine.UI.Image>();if(image==null)image=r.gameObject.AddComponent<UnityEngine.UI.Image>();
    image.color=color;image.raycastTarget=hit;return image;
};
System.Action<ProjectY.UI.LuaReference,string,Component> bind=(reference,key,target)=>{
    if(target==null)throw new System.InvalidOperationException("Cannot bind missing HUD component: "+key);
    var entries=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
    entries.RemoveAll(e=>e.Key==key);entries.Add(new ProjectY.UI.LuaReference.Entry(key,target));reference.SetEditorBindings(entries.ToArray());
};
System.Action<ProjectY.UI.LuaReference,UnityEngine.UI.Text,string> localize=(reference,text,id)=>{
    text.text=language[id];var entries=new System.Collections.Generic.List<ProjectY.UI.LuaReference.LocalizedText>(reference.GetEditorLocalizations());
    entries.RemoveAll(e=>e.Target==text);entries.Add(new ProjectY.UI.LuaReference.LocalizedText(text,id));reference.SetEditorLocalizations(entries.ToArray());
};
System.Func<RectTransform,CanvasGroup> canvasGroup=r=>{
    var group=r.GetComponent<CanvasGroup>();if(group==null)group=r.gameObject.AddComponent<CanvasGroup>();group.ignoreParentGroups=false;return group;
};
var root=UnityEditor.PrefabUtility.LoadPrefabContents(definition.PrefabPath);
try{
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();
    var view=(ProjectY.UI.MainHudView)reference.Get("HUD");var viewFields=new UnityEditor.SerializedObject(view);var layout=viewFields.FindProperty("layout");
    System.Func<string,RectTransform> layoutRect=key=>{
        var property=layout.FindPropertyRelative(key);var value=property==null?null:property.objectReferenceValue as RectTransform;
        if(value==null)throw new System.InvalidOperationException("MainHud layout binding is missing: "+key);return value;
    };
    var mainGroups=new System.Collections.Generic.List<CanvasGroup>();var mapGroups=new System.Collections.Generic.List<CanvasGroup>();
    var motionRects=new System.Collections.Generic.List<RectTransform>();var motionDirections=new System.Collections.Generic.List<Vector2>();
    var motionIsMap=new System.Collections.Generic.List<bool>();var motionOrder=new System.Collections.Generic.List<int>();
    // Keep each authored Rect and every existing serialized reference. Only its
    // full-screen parent receives motion; MainHudView can continue placing the child.
    System.Action<RectTransform,Vector2> wrapMain=(content,direction)=>{
        if(content==null)throw new System.InvalidOperationException("Missing main HUD motion content.");
        var wrapperName=content.name+"Motion";RectTransform wrapper;
        if(content.parent!=null&&content.parent.name==wrapperName)wrapper=(RectTransform)content.parent;
        else{
            var parent=content.parent;if(parent==null)throw new System.InvalidOperationException("Main HUD content has no parent.");
            var sibling=content.GetSiblingIndex();wrapper=node(parent,wrapperName);stretch(wrapper);wrapper.SetSiblingIndex(sibling);
            var anchorMin=content.anchorMin;var anchorMax=content.anchorMax;var pivot=content.pivot;var position=content.anchoredPosition3D;var size=content.sizeDelta;
            var rotation=content.localRotation;var scale=content.localScale;
            content.SetParent(wrapper,false);content.anchorMin=anchorMin;content.anchorMax=anchorMax;content.pivot=pivot;
            content.sizeDelta=size;content.anchoredPosition3D=position;content.localRotation=rotation;content.localScale=scale;
        }
        stretch(wrapper);wrapper.localRotation=Quaternion.identity;wrapper.localScale=Vector3.one;
        var group=canvasGroup(wrapper);group.alpha=1;group.interactable=group.blocksRaycasts=true;
        motionOrder.Add(mainGroups.Count);mainGroups.Add(group);motionRects.Add(wrapper);motionDirections.Add(direction);motionIsMap.Add(false);
    };
    wrapMain(layoutRect("Header"),Vector2.up);wrapMain(layoutRect("Party"),Vector2.left);wrapMain(layoutRect("Journal"),Vector2.down);
    wrapMain(layoutRect("Interaction"),Vector2.down);wrapMain(layoutRect("Hint"),Vector2.up);wrapMain((RectTransform)reference.Get("CharacterSkills"),Vector2.down);
    var safe=layoutRect("Safe");var actions=safe.Find("AreaActions")??safe.Find("AreaActionsMotion/AreaActions");
    if(actions==null)throw new System.InvalidOperationException("MainHud AreaActions is missing.");
    wrapMain((RectTransform)actions,Vector2.up);wrapMain(layoutRect("Rail"),Vector2.right);wrapMain(layoutRect("Menu"),Vector2.right);wrapMain(layoutRect("Clock"),Vector2.up);
    var worldControls=reference.Get("TimeControls").transform.parent as RectTransform;
    if(worldControls==null||worldControls.name!="WorldControls")throw new System.InvalidOperationException("MainHud WorldControls binding is invalid.");
    wrapMain(worldControls,Vector2.right);

    var map=node(root.transform,"MapHud");stretch(map);map.SetAsLastSibling();map.gameObject.SetActive(true);
    var mapReference=map.GetComponent<ProjectY.UI.LuaReference>();if(mapReference==null)mapReference=map.gameObject.AddComponent<ProjectY.UI.LuaReference>();
    var mapGroup=canvasGroup(map);mapGroup.alpha=1;mapGroup.interactable=mapGroup.blocksRaycasts=true;
    bind(reference,"MapHud",mapReference);bind(mapReference,"Root",map);bind(mapReference,"Group",mapGroup);
    System.Func<string,Vector2,RectTransform> mapMotion=(name,direction)=>{
        var wrapper=node(map,name+"Motion");stretch(wrapper);var group=canvasGroup(wrapper);group.alpha=0;group.interactable=group.blocksRaycasts=false;
        // The serialized baseline matches normalized clip time zero.
        var distances=new[]{120f,270f,260f,110f};wrapper.anchoredPosition=direction*distances[mapGroups.Count];
        motionOrder.Add(mapGroups.Count);mapGroups.Add(group);motionRects.Add(wrapper);motionDirections.Add(direction);motionIsMap.Add(true);
        return node(wrapper,name);
    };
    System.Func<Transform,string,string,float,float,float,float,int,Color,UnityEngine.UI.Text> text=(parent,key,id,x,y,w,h,size,color)=>{
        var rect=node(parent,key);box(rect,x,y,w,h);var label=rect.GetComponent<UnityEngine.UI.Text>();if(label==null)label=rect.gameObject.AddComponent<UnityEngine.UI.Text>();
        label.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");label.fontSize=size;label.color=color;label.raycastTarget=false;
        label.supportRichText=false;label.alignment=TextAnchor.MiddleLeft;label.horizontalOverflow=HorizontalWrapMode.Wrap;label.verticalOverflow=VerticalWrapMode.Truncate;
        bind(mapReference,key,label);localize(mapReference,label,id);localize(reference,label,id);return label;
    };
    System.Func<Transform,string,string,float,float,float,UnityEngine.UI.Button> button=(parent,key,id,x,y,w)=>{
        var rect=node(parent,key);box(rect,x,y,w,38);var background=paint(rect,new Color(.78f,.73f,.62f,.35f),true);
        var control=rect.GetComponent<UnityEngine.UI.Button>();if(control==null)control=rect.gameObject.AddComponent<UnityEngine.UI.Button>();
        control.targetGraphic=background;control.navigation=new UnityEngine.UI.Navigation{mode=UnityEngine.UI.Navigation.Mode.None};
        var colors=control.colors;colors.highlightedColor=new Color(.88f,.93f,.88f);colors.pressedColor=new Color(.70f,.81f,.72f);control.colors=colors;
        bind(mapReference,key,control);text(rect,key+"Text",id,7,0,w-14,38,15,ink).alignment=TextAnchor.MiddleCenter;return control;
    };
    System.Action<Transform,string,string,float> toggle=(parent,key,id,y)=>{
        var rect=node(parent,key);box(rect,16,y,204,38);var background=paint(rect,new Color(.78f,.73f,.62f,.22f),true);
        var control=rect.GetComponent<UnityEngine.UI.Toggle>();bool created=control==null;if(created)control=rect.gameObject.AddComponent<UnityEngine.UI.Toggle>();
        control.targetGraphic=background;control.navigation=new UnityEngine.UI.Navigation{mode=UnityEngine.UI.Navigation.Mode.None};
        var check=node(rect,"Check");box(check,11,11,16,16);control.graphic=paint(check,gold,false);if(created)control.isOn=true;
        bind(mapReference,key,control);text(rect,key+"Text",id,38,0,158,38,15,ink);
    };
    var top=mapMotion("Top",Vector2.up);top.anchorMin=new Vector2(0,1);top.anchorMax=new Vector2(1,1);top.pivot=new Vector2(.5f,1);
    top.anchoredPosition=new Vector2(0,-16);top.sizeDelta=new Vector2(-32,78);paint(top,paper,true);
    paint(node(top,"Rule"),gold,false);var topRule=(RectTransform)top.Find("Rule");topRule.anchorMin=new Vector2(0,1);topRule.anchorMax=Vector2.one;topRule.pivot=new Vector2(.5f,1);topRule.anchoredPosition=Vector2.zero;topRule.sizeDelta=new Vector2(0,3);
    var title=text(top,"Title","UIWorldMapTitle",20,9,400,32,25,ink);title.rectTransform.anchorMax=Vector2.one;title.rectTransform.sizeDelta=new Vector2(-178,32);
    var subtitle=text(top,"Subtitle","UIWorldMapSubtitle",22,44,500,24,13,muted);subtitle.rectTransform.anchorMax=Vector2.one;subtitle.rectTransform.sizeDelta=new Vector2(-182,24);
    var close=(RectTransform)button(top,"Close","UIWorldMapClose",0,20,104).transform;close.anchorMin=close.anchorMax=Vector2.one;close.anchoredPosition=new Vector2(-124,-20);

    var filters=mapMotion("Filters",Vector2.left);box(filters,16,112,236,326);paint(filters,paper,true);
    text(filters,"FiltersTitle","UIWorldMapFiltersTitle",17,12,200,30,18,ink);
    toggle(filters,"SiteTags","UIWorldMapSiteTags",52);toggle(filters,"AvailableMissions","UIWorldMapAvailableMissions",96);
    toggle(filters,"ActiveMissions","UIWorldMapActiveMissions",140);toggle(filters,"ReadyMissions","UIWorldMapReadyMissions",184);
    toggle(filters,"PlayerMarker","UIWorldMapPlayerMarker",228);toggle(filters,"Route","UIWorldMapRoute",272);

    var legend=mapMotion("Legend",Vector2.right);box(legend,0,112,226,250);legend.anchorMin=legend.anchorMax=Vector2.one;legend.anchoredPosition=new Vector2(-242,-112);paint(legend,paper,true);
    text(legend,"LegendTitle","UIWorldMapLegendTitle",17,12,192,30,18,ink);
    var legendBody=text(legend,"LegendBody","UIWorldMapLegendBody",20,54,186,178,14,muted);legendBody.alignment=TextAnchor.UpperLeft;legendBody.lineSpacing=1.25f;

    var bottom=mapMotion("Bottom",Vector2.down);bottom.anchorMin=Vector2.zero;bottom.anchorMax=new Vector2(1,0);bottom.pivot=new Vector2(.5f,0);
    bottom.anchoredPosition=new Vector2(0,16);bottom.sizeDelta=new Vector2(-32,74);paint(bottom,paper,true);
    var hint=text(bottom,"Hint","UIWorldMapHint",20,12,760,48,14,muted);hint.rectTransform.anchorMax=Vector2.one;hint.rectTransform.sizeDelta=new Vector2(-318,48);
    var home=(RectTransform)button(bottom,"Home","UIWorldMapHome",0,18,132).transform;home.anchorMin=home.anchorMax=Vector2.one;home.anchoredPosition=new Vector2(-292,-18);
    var missions=(RectTransform)button(bottom,"Missions","UIWorldMapMissions",0,18,132).transform;missions.anchorMin=missions.anchorMax=Vector2.one;missions.anchoredPosition=new Vector2(-148,-18);

    var markerRoot=node(map,"MarkerRoot");stretch(markerRoot);markerRoot.SetAsFirstSibling();bind(mapReference,"MarkerRoot",markerRoot);
    var markersVisibility=canvasGroup(markerRoot);markersVisibility.alpha=0;markersVisibility.interactable=markersVisibility.blocksRaycasts=false;
    var marker=node(markerRoot,"MarkerTemplate");marker.anchorMin=marker.anchorMax=new Vector2(.5f,.5f);marker.pivot=new Vector2(.5f,0);marker.anchoredPosition=Vector2.zero;marker.sizeDelta=new Vector2(186,32);
    paint(marker,dark,false);var markerGroup=canvasGroup(marker);markerGroup.alpha=1;markerGroup.interactable=markerGroup.blocksRaycasts=false;
    var markerReference=marker.GetComponent<ProjectY.UI.LuaReference>();if(markerReference==null)markerReference=marker.gameObject.AddComponent<ProjectY.UI.LuaReference>();
    var icon=node(marker,"Icon");box(icon,7,7,18,18);var iconImage=paint(icon,gold,false);iconImage.sprite=UnityEditor.AssetDatabase.GetBuiltinExtraResource<Sprite>("UI/Skin/Knob.psd");
    var markerLabelRect=node(marker,"Label");box(markerLabelRect,32,0,146,32);var markerLabel=markerLabelRect.GetComponent<UnityEngine.UI.Text>();if(markerLabel==null)markerLabel=markerLabelRect.gameObject.AddComponent<UnityEngine.UI.Text>();
    markerLabel.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");markerLabel.text="";markerLabel.fontSize=14;markerLabel.color=cream;markerLabel.alignment=TextAnchor.MiddleLeft;
    markerLabel.raycastTarget=false;markerLabel.supportRichText=false;markerLabel.horizontalOverflow=HorizontalWrapMode.Overflow;
    var follower=marker.GetComponent<ProjectY.UI.UIFollower>();if(follower==null)follower=marker.gameObject.AddComponent<ProjectY.UI.UIFollower>();follower.SetEditorBindings(marker,markerGroup);
    var followerFields=new UnityEditor.SerializedObject(follower);followerFields.FindProperty("worldOffset").vector3Value=new Vector3(0,.6f,0);
    followerFields.FindProperty("screenOffset").vector2Value=new Vector2(0,10);followerFields.FindProperty("orthographicFade").vector2Value=new Vector2(100000,100001);
    followerFields.FindProperty("perspectiveFade").vector2Value=new Vector2(100000,100001);followerFields.FindProperty("minScale").floatValue=1;followerFields.FindProperty("maxScale").floatValue=1;
    followerFields.FindProperty("interactiveChildren").boolValue=false;followerFields.ApplyModifiedPropertiesWithoutUndo();
    bind(markerReference,"Root",marker);bind(markerReference,"Label",markerLabel);bind(markerReference,"Icon",iconImage);bind(markerReference,"Follower",follower);
    bind(mapReference,"MarkerTemplate",markerReference);marker.gameObject.SetActive(false);

    var animation=root.GetComponent<ProjectY.UI.AnimationWrap>();if(animation==null)animation=root.AddComponent<ProjectY.UI.AnimationWrap>();
    var animator=root.GetComponent<Animator>();animator.enabled=true;animator.cullingMode=AnimatorCullingMode.AlwaysAnimate;
    var transition=root.GetComponent<ProjectY.UI.HudModeTransition>();if(transition==null)transition=root.AddComponent<ProjectY.UI.HudModeTransition>();
    bind(reference,"MapTransition",transition);
    var transitionFields=new UnityEditor.SerializedObject(transition);
    var animationBinding=transitionFields.FindProperty("animation");var mainBindings=transitionFields.FindProperty("mainGroups");var mapBindings=transitionFields.FindProperty("mapGroups");
    if(animationBinding==null||mainBindings==null||mapBindings==null)throw new System.InvalidOperationException("HudModeTransition serialization contract changed.");
    animationBinding.objectReferenceValue=animation;mainBindings.arraySize=mainGroups.Count;mapBindings.arraySize=mapGroups.Count;
    for(int i=0;i<mainGroups.Count;i++)mainBindings.GetArrayElementAtIndex(i).objectReferenceValue=mainGroups[i];
    for(int i=0;i<mapGroups.Count;i++)mapBindings.GetArrayElementAtIndex(i).objectReferenceValue=mapGroups[i];
    transitionFields.ApplyModifiedPropertiesWithoutUndo();
    var labels=viewFields.FindProperty("layout.Labels");var allLabels=root.GetComponentsInChildren<UnityEngine.UI.Text>(true);labels.arraySize=allLabels.Length;
    for(int i=0;i<allLabels.Length;i++)labels.GetArrayElementAtIndex(i).objectReferenceValue=allLabels[i];viewFields.ApplyModifiedPropertiesWithoutUndo();
    reference.ValidateBindings();mapReference.ValidateBindings();markerReference.ValidateBindings();
    foreach(var key in new[]{"SiteTags","AvailableMissions","ActiveMissions","ReadyMissions","PlayerMarker","Route"})mapReference.GetToggle(key);
    foreach(var key in new[]{"Close","Home","Missions"})mapReference.GetButton(key);
    foreach(var group in mainGroups)if(group==null)throw new System.InvalidOperationException("Empty main HUD animation group.");
    foreach(var group in mapGroups)if(group==null)throw new System.InvalidOperationException("Empty map HUD animation group.");

    const string animationFolder="Assets/DynamicAsset/UI/Animations";const string animationPath=animationFolder+"/map-overview.anim";
    if(!UnityEditor.AssetDatabase.IsValidFolder(animationFolder))UnityEditor.AssetDatabase.CreateFolder("Assets/DynamicAsset/UI","Animations");
    var clip=UnityEditor.AssetDatabase.LoadAssetAtPath<AnimationClip>(animationPath);bool newClip=clip==null;
    if(newClip)clip=new AnimationClip();else clip.ClearCurves();clip.name="map-overview";clip.legacy=false;clip.frameRate=60;
    var settings=UnityEditor.AnimationUtility.GetAnimationClipSettings(clip);settings.loopTime=false;UnityEditor.AnimationUtility.SetAnimationClipSettings(clip,settings);
    System.Func<float,float,float,float,AnimationCurve> curve=(start,end,from,to)=>{
        var value=new AnimationCurve();value.AddKey(new Keyframe(0,from,0,0));if(start>0)value.AddKey(new Keyframe(start,from,0,0));
        value.AddKey(new Keyframe(end,to,0,0));if(end<1)value.AddKey(new Keyframe(1,to,0,0));return value;
    };
    for(int i=0;i<motionRects.Count;i++){
        var path=UnityEditor.AnimationUtility.CalculateTransformPath(motionRects[i],root.transform);
        var mainDistances=new[]{100f,240f,180f,300f,140f,180f,160f,140f,480f,170f,540f};
        var mapDistances=new[]{120f,270f,260f,110f};
        var direction=motionDirections[i]*(motionIsMap[i]?mapDistances[motionOrder[i]]:mainDistances[motionOrder[i]]);
        bool entering=motionIsMap[i];float start=entering ? .52f+motionOrder[i]*.06f : motionOrder[i]*.018f;float end=start+(entering ? .30f : .27f);
        var from=entering?direction:Vector2.zero;var to=entering?Vector2.zero:direction;
        UnityEditor.AnimationUtility.SetEditorCurve(clip,UnityEditor.EditorCurveBinding.FloatCurve(path,typeof(RectTransform),"m_AnchoredPosition.x"),curve(start,end,from.x,to.x));
        UnityEditor.AnimationUtility.SetEditorCurve(clip,UnityEditor.EditorCurveBinding.FloatCurve(path,typeof(RectTransform),"m_AnchoredPosition.y"),curve(start,end,from.y,to.y));
        UnityEditor.AnimationUtility.SetEditorCurve(clip,UnityEditor.EditorCurveBinding.FloatCurve(path,typeof(CanvasGroup),"m_Alpha"),curve(start,end,entering?0:1,entering?1:0));
    }
    if(newClip)UnityEditor.AssetDatabase.CreateAsset(clip,animationPath);else UnityEditor.EditorUtility.SetDirty(clip);
    var animationFields=new UnityEditor.SerializedObject(animation);var clips=animationFields.FindProperty("clips");var retained=new System.Collections.Generic.List<AnimationClip>();
    for(int i=0;i<clips.arraySize;i++){
        var existing=clips.GetArrayElementAtIndex(i).objectReferenceValue as AnimationClip;
        if(existing==null)throw new System.InvalidOperationException("Existing AnimationWrap has an empty clip binding.");
        if(existing!=clip&&existing.name!="map-overview")retained.Add(existing);
    }
    retained.Add(clip);clips.arraySize=retained.Count;for(int i=0;i<retained.Count;i++)clips.GetArrayElementAtIndex(i).objectReferenceValue=retained[i];
    animationFields.FindProperty("useUnscaledTime").boolValue=true;animationFields.ApplyModifiedPropertiesWithoutUndo();
    if(!animation.HasClip("map-overview"))throw new System.InvalidOperationException("Map overview animation binding was not saved.");

    var stale=new System.Collections.Generic.List<Newtonsoft.Json.Linq.JToken>();foreach(var entry in manifest)if((string)entry["prefab"]==definition.PrefabPath)stale.Add(entry);
    foreach(var entry in stale)entry.Remove();
    foreach(var binding in reference.GetEditorLocalizations()){
        if(binding.Target==null||!binding.Target.transform.IsChildOf(root.transform))throw new System.InvalidOperationException("Invalid MainHud localization target: "+binding.Id);
        var target=binding.Target.transform;var parts=new System.Collections.Generic.List<string>();while(target!=root.transform){parts.Insert(0,target.name);target=target.parent;}
        var legacy=binding.Target as UnityEngine.UI.Text;var tmp=binding.Target as TMPro.TMP_Text;
        if(legacy==null&&tmp==null)throw new System.InvalidOperationException("Unsupported MainHud localization target: "+binding.Id);
        manifest.Add(new Newtonsoft.Json.Linq.JObject{["prefab"]=definition.PrefabPath,["node"]=string.Join("/",parts.ToArray()),["type"]=legacy!=null?"Text":binding.Target.GetType().Name,
            ["text"]=legacy!=null?legacy.text:tmp.text,["id"]=binding.Id});
    }
    reference.ValidateBindings();mapReference.ValidateBindings();markerReference.ValidateBindings();
    UnityEditor.AssetDatabase.SaveAssetIfDirty(clip);UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,definition.PrefabPath);
    ProjectY.Editor.LuaViewHints.Register(typeof(ProjectY.UI.HudModeTransition),"CS.ProjectY.UI.HudModeTransition");
    ProjectY.Editor.LuaViewHints.Export(reference,definition.ViewType);ProjectY.Editor.LuaViewHints.Export(mapReference,"WorldMapHudWidgetView");
    ProjectY.Editor.LuaViewHints.Export(markerReference,"WorldMapMarkerWidgetView");
    System.IO.File.WriteAllText("Art/Localization/ui-text-bindings.json",manifest.ToString(Newtonsoft.Json.Formatting.Indented)+"\n",new System.Text.UTF8Encoding(false));
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
return "Saved MainHud map HUD, eleven main/four map motion groups, reversible map-overview clip, marker template and localization/view bindings. No compile/Refresh/Play transition.";
