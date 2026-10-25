// Unity MCP execute_code body. Inspect the real, isolated physics trajectories without entering Play.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required.");
var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/Presentation/DiceRollPanel.prefab");
var root=UnityEngine.Object.Instantiate(prefab);root.GetComponent<Canvas>().enabled=false;
var view=root.GetComponent<ProjectY.UI.DiceRollView>();
var image=(UnityEngine.UI.RawImage)root.GetComponent<ProjectY.UI.LuaReference>().Get("Image");
image.rectTransform.anchorMin=image.rectTransform.anchorMax=new Vector2(.5f,.5f);image.rectTransform.sizeDelta=new Vector2(1216,382);
System.Func<object,string,object> field=(value,name)=>value.GetType().GetField(name,System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance).GetValue(value);
var kinds=new[]{new[]{"D20"},new[]{"D100","D10"},new[]{"D20","D10","D4","D6","D8","D12"}};
var values=new[]{new[]{20},new[]{40,3},new[]{20,8,4,6,8,12}};
var seeds=new[]{101,37,20261024};var reports=new System.Collections.Generic.List<object>();
try
{
    for(int test=0;test<kinds.Length;test++)
    {
        view.Prepare();for(int i=0;i<kinds[test].Length;i++)view.AddDie(kinds[test][i],values[test][i]);view.Throw(seeds[test]);
        var dice=(System.Collections.IList)field(view,"dice");var camera=(Camera)field(view,"cameraView");
        float minX=float.MaxValue,maxX=float.MinValue,minTravel=float.MaxValue,maxEntry=float.MinValue;
        foreach(var die in dice)
        {
            var positions=(System.Collections.Generic.List<Vector3>)field(die,"Positions");
            minX=Mathf.Min(minX,positions[0].x);maxX=Mathf.Max(maxX,positions[0].x);
            minTravel=Mathf.Min(minTravel,positions[positions.Count-1].x-positions[0].x);
            maxEntry=Mathf.Max(maxEntry,camera.WorldToViewportPoint(positions[0]).x);
            if((int)field(die,"FirstContactSample")<=(int)field(die,"ReleaseSample")+4)throw new System.Exception("Missing airborne travel before contact.");
        }
        if(maxX-minX>.4f||minTravel<6||maxEntry>.15f)throw new System.Exception("Throw must be compact, enter from the side and travel forward.");
        view.Advance(.45f);
        foreach(var die in dice)
        {
            var positions=(System.Collections.Generic.List<Vector3>)field(die,"Positions");var body=(Rigidbody)field(die,"Body");
            if(Vector3.Distance(body.transform.position,positions[27])>.01f)throw new System.Exception("Flight was time-compressed.");
        }
        view.Advance(2.6f);
        if(!view.Settled)throw new System.Exception("Throw did not settle in its presentation time.");
        for(int i=0;i<values[test].Length;i++)if(view.VisibleValue(i)!=values[test][i])throw new System.Exception("Result face mismatch.");
        reports.Add(new{dice=kinds[test].Length,samples=view.SampleCount,minForwardTravel=minTravel,initialViewportX=maxEntry});
        view.Release();
    }
}
finally{view.Release();UnityEngine.Object.DestroyImmediate(root);}
return new{result="PASS single, percentile pair and mixed handful: shared launch, forward flight, physical initial timing, settling and exact result faces",cases=reports};
