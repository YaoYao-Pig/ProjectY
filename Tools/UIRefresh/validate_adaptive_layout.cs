// Insert inside render_preview.cs's capture lambda after its final layout/font refresh,
// before RenderPreview/Render. Requires root (GameObject), name (string), captures (List<string>).
// Read-only presentation checks; no classes, imports, scene creation or layout mutation.
{
    const float adaptiveTolerance=1f;
    var adaptiveFailures=new System.Collections.Generic.List<string>();
    int adaptiveWidgets=0,adaptiveTexts=0;
    System.Func<UnityEngine.Transform,string> adaptivePath=adaptiveTransform=>UnityEditor.AnimationUtility.CalculateTransformPath(adaptiveTransform,root.transform);
    System.Func<UnityEngine.RectTransform,UnityEngine.RectTransform,UnityEngine.Rect> adaptiveBounds=(adaptiveChild,adaptiveParent)=>{
        var adaptiveCorners=new UnityEngine.Vector3[4];adaptiveChild.GetWorldCorners(adaptiveCorners);
        var adaptiveMin=new UnityEngine.Vector2(float.PositiveInfinity,float.PositiveInfinity);
        var adaptiveMax=new UnityEngine.Vector2(float.NegativeInfinity,float.NegativeInfinity);
        foreach(var adaptiveCorner in adaptiveCorners){
            var adaptivePoint=(UnityEngine.Vector2)adaptiveParent.InverseTransformPoint(adaptiveCorner);
            adaptiveMin=UnityEngine.Vector2.Min(adaptiveMin,adaptivePoint);adaptiveMax=UnityEngine.Vector2.Max(adaptiveMax,adaptivePoint);
        }
        return UnityEngine.Rect.MinMaxRect(adaptiveMin.x,adaptiveMin.y,adaptiveMax.x,adaptiveMax.y);
    };
    System.Func<UnityEngine.Transform,bool> adaptiveVisibleText=adaptiveTransform=>{
        if(adaptiveTransform==null||!adaptiveTransform.gameObject.activeInHierarchy)return false;
        var adaptiveTmp=adaptiveTransform.GetComponent<TMPro.TMP_Text>();
        if(adaptiveTmp!=null)return adaptiveTmp.isActiveAndEnabled&&!string.IsNullOrEmpty(adaptiveTmp.text);
        var adaptiveLegacy=adaptiveTransform.GetComponent<UnityEngine.UI.Text>();
        return adaptiveLegacy!=null&&adaptiveLegacy.isActiveAndEnabled&&!string.IsNullOrEmpty(adaptiveLegacy.text);
    };
    System.Action<UnityEngine.Transform,bool> adaptiveCheckText=(adaptiveTransform,adaptiveSingleLine)=>{
        var adaptiveRect=(UnityEngine.RectTransform)adaptiveTransform;
        var adaptiveTmp=adaptiveTransform.GetComponent<TMPro.TMP_Text>();
        var adaptiveLegacy=adaptiveTransform.GetComponent<UnityEngine.UI.Text>();
        float adaptivePreferredHeight=adaptiveTmp!=null?adaptiveTmp.preferredHeight:adaptiveLegacy.preferredHeight;
        float adaptivePreferredWidth=adaptiveTmp!=null?adaptiveTmp.preferredWidth:adaptiveLegacy.preferredWidth;
        if(adaptivePreferredHeight>adaptiveRect.rect.height+adaptiveTolerance)
            adaptiveFailures.Add(adaptivePath(adaptiveTransform)+": preferredHeight "+adaptivePreferredHeight+" exceeds rect height "+adaptiveRect.rect.height);
        if(adaptiveTmp!=null&&adaptiveTmp.isTextOverflowing)
            adaptiveFailures.Add(adaptivePath(adaptiveTransform)+": TMP text overflows");
        if(adaptiveSingleLine&&adaptivePreferredWidth>adaptiveRect.rect.width+adaptiveTolerance)
            adaptiveFailures.Add(adaptivePath(adaptiveTransform)+": label preferredWidth "+adaptivePreferredWidth+" exceeds rect width "+adaptiveRect.rect.width);
        adaptiveTexts++;
    };
    System.Action<UnityEngine.Transform,UnityEngine.Rect,UnityEngine.Rect> adaptiveCheckInside=(adaptiveTransform,adaptiveBox,adaptiveSafe)=>{
        if(adaptiveBox.xMin<adaptiveSafe.xMin-adaptiveTolerance||adaptiveBox.xMax>adaptiveSafe.xMax+adaptiveTolerance||
           adaptiveBox.yMin<adaptiveSafe.yMin-adaptiveTolerance||adaptiveBox.yMax>adaptiveSafe.yMax+adaptiveTolerance)
            adaptiveFailures.Add(adaptivePath(adaptiveTransform)+": text rect "+adaptiveBox+" enters padding outside "+adaptiveSafe);
    };
    System.Action<System.Collections.Generic.List<System.Collections.Generic.KeyValuePair<string,UnityEngine.Rect>>> adaptiveCheckOverlap=adaptiveRows=>{
        for(int adaptiveA=0;adaptiveA<adaptiveRows.Count;adaptiveA++)for(int adaptiveB=adaptiveA+1;adaptiveB<adaptiveRows.Count;adaptiveB++){
            var adaptiveFirst=adaptiveRows[adaptiveA].Value;var adaptiveSecond=adaptiveRows[adaptiveB].Value;
            if(UnityEngine.Mathf.Min(adaptiveFirst.xMax,adaptiveSecond.xMax)-UnityEngine.Mathf.Max(adaptiveFirst.xMin,adaptiveSecond.xMin)>adaptiveTolerance&&
               UnityEngine.Mathf.Min(adaptiveFirst.yMax,adaptiveSecond.yMax)-UnityEngine.Mathf.Max(adaptiveFirst.yMin,adaptiveSecond.yMin)>adaptiveTolerance)
                adaptiveFailures.Add(adaptiveRows[adaptiveA].Key+" overlaps "+adaptiveRows[adaptiveB].Key);
        }
    };
    foreach(var adaptiveWidget in root.GetComponentsInChildren<UnityEngine.RectTransform>()){
        var adaptiveKind=adaptiveWidget.name;
        if(adaptiveKind.EndsWith("(Clone)",System.StringComparison.Ordinal))adaptiveKind=adaptiveKind.Substring(0,adaptiveKind.Length-7);
        bool adaptiveColumn=adaptiveKind=="NarrativeEntryWidget"||adaptiveKind=="DialogueEntryWidget"||adaptiveKind=="StoryChoiceWidget"||adaptiveKind=="JournalSkillWidget";
        bool adaptiveReward=adaptiveKind=="MissionRewardWidget",adaptiveTab=adaptiveKind=="TabButtonWidget";
        if(!adaptiveColumn&&!adaptiveReward&&!adaptiveTab)continue;
        adaptiveWidgets++;
        var adaptiveSafe=adaptiveWidget.rect;
        if(adaptiveColumn){
            var adaptiveLayout=adaptiveWidget.GetComponent<UnityEngine.UI.VerticalLayoutGroup>();
            if(adaptiveLayout==null||!adaptiveLayout.isActiveAndEnabled){adaptiveFailures.Add(adaptivePath(adaptiveWidget)+": active VerticalLayoutGroup is required");continue;}
            adaptiveSafe=UnityEngine.Rect.MinMaxRect(adaptiveSafe.xMin+adaptiveLayout.padding.left,adaptiveSafe.yMin+adaptiveLayout.padding.bottom,
                adaptiveSafe.xMax-adaptiveLayout.padding.right,adaptiveSafe.yMax-adaptiveLayout.padding.top);
        }else if(adaptiveReward){
            adaptiveSafe=UnityEngine.Rect.MinMaxRect(adaptiveSafe.xMin+12,adaptiveSafe.yMin+12,adaptiveSafe.xMax-12,adaptiveSafe.yMax-12);
        }else{
            adaptiveSafe=UnityEngine.Rect.MinMaxRect(adaptiveSafe.xMin+16,adaptiveSafe.yMin,adaptiveSafe.xMax-16,adaptiveSafe.yMax);
        }
        var adaptiveFields=adaptiveColumn?new[]{"Title","Body"}:adaptiveReward?new[]{"Name","Amount","Note"}:new[]{"Label"};
        var adaptiveRows=new System.Collections.Generic.List<System.Collections.Generic.KeyValuePair<string,UnityEngine.Rect>>();
        foreach(var adaptiveField in adaptiveFields){
            var adaptiveText=adaptiveWidget.Find(adaptiveField);
            if(adaptiveText==null){adaptiveFailures.Add(adaptivePath(adaptiveWidget)+": missing direct text "+adaptiveField);continue;}
            if(!adaptiveVisibleText(adaptiveText))continue;
            adaptiveCheckText(adaptiveText,adaptiveTab);
            var adaptiveBox=adaptiveBounds((UnityEngine.RectTransform)adaptiveText,adaptiveWidget);
            adaptiveCheckInside(adaptiveText,adaptiveBox,adaptiveSafe);
            adaptiveRows.Add(new System.Collections.Generic.KeyValuePair<string,UnityEngine.Rect>(adaptivePath(adaptiveText),adaptiveBox));
        }
        adaptiveCheckOverlap(adaptiveRows);
    }
    captures.Add(name+": adaptive layout "+(adaptiveFailures.Count==0?"PASS":"FAIL")+"; "+adaptiveWidgets+" active widgets / "+adaptiveTexts+" nonempty active texts / "+adaptiveFailures.Count+" failures (1 px tolerance)");
    if(adaptiveFailures.Count>0)throw new System.InvalidOperationException(name+" adaptive layout validation failed:\n"+string.Join("\n",adaptiveFailures.ToArray()));
}
