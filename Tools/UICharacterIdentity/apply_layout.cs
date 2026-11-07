// Run with Unity MCP execute_code in idle Edit Mode. Preserve existing bindings and artwork.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>("Assets/DynamicAsset/UI/Resources/PanelConfig.asset");
System.Action<RectTransform,float,float,float,float> place=(r,x,y,w,h)=>{r.anchorMin=r.anchorMax=r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(x,-y);r.sizeDelta=new Vector2(w,h);};
System.Action<UnityEngine.UI.Text,int,TextAnchor> label=(t,size,alignment)=>{t.supportRichText=true;t.resizeTextForBestFit=false;t.fontSize=size;t.lineSpacing=1;t.alignment=alignment;t.horizontalOverflow=HorizontalWrapMode.Wrap;t.verticalOverflow=VerticalWrapMode.Truncate;};
System.Action<RectTransform,float,float,float,float> stretch=(r,l,t,rr,b)=>{r.anchorMin=Vector2.zero;r.anchorMax=Vector2.one;r.offsetMin=new Vector2(l,b);r.offsetMax=new Vector2(-rr,-t);};
var changed=new System.Collections.Generic.List<string>();
foreach(var name in new[]{"CharacterGrowth","SkillAtlas","Inventory","EquipmentWorkbench","HudParty","BattleParty","BattleTurn","BattleHUD","MainHud","InspectionTarget","UnitDetails"})
{
    var entry=config.Entries.Find(e=>e.Name==name);var path=UnityEditor.AssetDatabase.GetAssetPath(entry.Prefab);
    var root=UnityEditor.PrefabUtility.LoadPrefabContents(path);
    try
    {
        System.Func<string,RectTransform> rect=p=>{var t=root.transform.Find(p);if(t==null)throw new System.Exception(name+" missing "+p);return (RectTransform)t;};
        if(name=="CharacterGrowth"||name=="SkillAtlas")
        {
            for(int i=1;i<=4;i++)
            {
                var button=rect("Page/Party"+i);var position=button.anchoredPosition;
                place(button,position.x,name=="CharacterGrowth"?76:22,button.sizeDelta.x,name=="CharacterGrowth"?74:70);
                var text=rect("Page/Party"+i+"/Label").GetComponent<UnityEngine.UI.Text>();
                stretch(text.rectTransform,10,name=="CharacterGrowth"?10:8,10,name=="CharacterGrowth"?10:8);label(text,12,TextAnchor.MiddleCenter);
            }
            if(name=="CharacterGrowth")
            {
                place(rect("Page/MatteBookHeader"),280,16,900,58);
                place(rect("Page/BookTitle"),322,18,500,32);place(rect("Page/BookSubtitle"),324,50,540,22);
                place(rect("Page/Summary"),294,154,880,25);
                var title=rect("Page/Hero/Title").GetComponent<UnityEngine.UI.Text>();place(title.rectTransform,18,24,218,70);label(title,14,TextAnchor.LowerLeft);
                place(rect("Page/Hero/Role"),20,98,200,25);
            }
        }
        if(name=="Inventory")
        {
            // Keep the 3D equipment view intact; grow the page and move this column together.
            rect("Frame").sizeDelta=new Vector2(1440,802);
            for(int i=1;i<=4;i++)
            {
                place(rect("Frame/Actor"+i),20+(i-1)*136,90,128,76);
                var text=rect("Frame/Actor"+i+"/Label").GetComponent<UnityEngine.UI.Text>();stretch(text.rectTransform,6,10,6,10);label(text,12,TextAnchor.MiddleCenter);
            }
            place(rect("Frame/Equipment"),20,186,540,520);place(rect("Frame/ActorStats"),24,724,532,66);
            place(rect("Frame/Equipment/Health"),432,14,100,30);
            place(rect("Frame/MatteLeatherBacking"),8,8,1424,786);
        }
        if(name=="EquipmentWorkbench")for(int i=1;i<=4;i++){var text=rect("SafeArea/Actors/Actor"+i+"/Label").GetComponent<UnityEngine.UI.Text>();stretch(text.rectTransform,8,9,8,9);label(text,12,TextAnchor.MiddleCenter);}
        if(name=="HudParty")
        {
            var text=rect("Name").GetComponent<UnityEngine.UI.Text>();place(text.rectTransform,80,2,104,48);label(text,11,TextAnchor.MiddleLeft);
            place(rect("Track"),80,51,102,12);place(rect("APTrack"),80,66,102,12);place(rect("APTrack/APText"),0,0,102,12);
        }
        var unitRoots=new System.Collections.Generic.List<Transform>();
        if(name=="BattleParty"||name=="BattleTurn")unitRoots.Add(root.transform);
        if(name=="BattleHUD")unitRoots.Add(rect("SafeArea/Initiative/TurnTemplate"));
        if(name=="MainHud")unitRoots.Add(rect("BattleContent/SafeArea/Initiative/TurnTemplate"));
        foreach(var unit in unitRoots)
        {
            var text=unit.Find("Name").GetComponent<UnityEngine.UI.Text>();label(text,11,TextAnchor.MiddleCenter);stretch(text.rectTransform,8,1,6,17);
            var detail=unit.Find("Detail").GetComponent<UnityEngine.UI.Text>();label(detail,10,TextAnchor.MiddleCenter);
            var dr=detail.rectTransform;dr.anchorMin=new Vector2(0,0);dr.anchorMax=new Vector2(1,0);dr.pivot=new Vector2(.5f,0);dr.anchoredPosition=new Vector2(1,4);dr.sizeDelta=new Vector2(-14,12);
            var health=(RectTransform)unit.Find("Health");health.anchorMin=new Vector2(0,0);health.anchorMax=new Vector2(1,0);health.pivot=new Vector2(.5f,0);health.anchoredPosition=new Vector2(0,2);health.sizeDelta=new Vector2(-14,2);
        }
        if(name=="InspectionTarget")
        {
            ((RectTransform)root.transform).sizeDelta=new Vector2(234,104);
            var sizing=root.GetComponent<UnityEngine.UI.LayoutElement>();if(sizing!=null){sizing.minHeight=104;sizing.preferredHeight=104;}
            place(rect("Title"),14,5,208,70);place(rect("Body"),14,79,208,20);rect("Body").GetComponent<TMPro.TMP_Text>().fontSize=12;
            var selected=rect("Selected");stretch(selected,0,0,230,0);
            var text=rect("Title").GetComponent<TMPro.TMP_Text>();text.richText=true;text.enableAutoSizing=false;
        }
        if(name=="UnitDetails")
        {
            place(rect("Page/TargetName"),310,96,762,82);var text=rect("Page/TargetName").GetComponent<TMPro.TMP_Text>();text.richText=true;text.enableAutoSizing=false;
            place(rect("Page/AttributeTitle"),310,181,350,30);place(rect("Page/TraitTitle"),680,181,392,30);
            place(rect("Page/AttributeScroll"),310,215,350,247);place(rect("Page/TraitScroll"),680,215,392,247);
        }
        UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,path);changed.Add(path);
    }
    finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
}
return string.Join("\n",changed.ToArray());
