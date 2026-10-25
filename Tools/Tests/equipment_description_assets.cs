// Unity MCP execute_code body after the single approved compile + EquipmentDescriptionAssets.Sync.
// Uses isolated prefab clones in a preview scene; no game commands, player state, Play or asset writes.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required.");
var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var canvasObject=new UnityEngine.GameObject("EquipmentDescriptionCheck",typeof(UnityEngine.RectTransform),typeof(UnityEngine.Canvas));
UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(canvasObject,scene);
canvasObject.GetComponent<UnityEngine.Canvas>().renderMode=UnityEngine.RenderMode.ScreenSpaceOverlay;
System.Action<bool,string> check=(ok,message)=>{if(!ok)throw new System.Exception(message);};
int panels=0;
try
{
    foreach(var name in new[]{"Inventory","Loot","EquipmentWorkbench"})
    {
        var entry=config.Entries.Find(row=>row.Name==name);
        var root=UnityEngine.Object.Instantiate(entry.Prefab,canvasObject.transform,false);
        // Match LuaPanel.Initialize: serialized panel prefabs may have a zero scale until attached to UIHost.
        var panelRect=(UnityEngine.RectTransform)root.transform;
        panelRect.anchorMin=UnityEngine.Vector2.zero;panelRect.anchorMax=UnityEngine.Vector2.one;
        panelRect.offsetMin=panelRect.offsetMax=UnityEngine.Vector2.zero;
        panelRect.localRotation=UnityEngine.Quaternion.identity;panelRect.localScale=UnityEngine.Vector3.one;
        var panelPosition=panelRect.anchoredPosition3D;panelPosition.z=0;panelRect.anchoredPosition3D=panelPosition;
        root.SetActive(true);
        try
        {
            var reference=root.GetComponent<ProjectY.UI.LuaReference>();reference.ValidateBindings();
            var text=reference.Get(name=="EquipmentWorkbench"?"Stats":"ItemDetail") as TMPro.TMP_Text;
            var input=reference.Get("DescriptionLinks") as ProjectY.UI.TMPTermLinkView;
            var card=reference.Get("EquipmentTermTip") as ProjectY.UI.SkillTooltipView;
            check(text!=null&&input!=null&&card!=null&&input.SourceText==text,name+": incorrect serialized terminology bindings");
            var originalRect=text.rectTransform;var originalParent=text.transform.parent;int textId=text.GetInstanceID();
            var migrate=typeof(ProjectY.Editor.EquipmentDescriptionAssets).GetMethod("Apply",System.Reflection.BindingFlags.Static|System.Reflection.BindingFlags.NonPublic);
            migrate.Invoke(null,new object[]{name,root});
            check(input.SourceText.GetInstanceID()==textId&&text.rectTransform==originalRect&&text.transform.parent==originalParent,name+": repeated migration replaced text or layout");
            check(root.GetComponentsInChildren<ProjectY.UI.TMPTermLinkView>(true).Length==1&&root.GetComponentsInChildren<ProjectY.UI.SkillTooltipView>(true).Length==1,name+": duplicate interaction/card");
            var inventory=root.GetComponent<ProjectY.UI.InventoryPanelView>();
            if(inventory!=null)foreach(var label in inventory.EditorLayout.Labels)check(label!=null,name+": null legacy label");
            var workbench=root.GetComponent<ProjectY.UI.EquipmentWorkbenchView>();
            if(workbench!=null)foreach(var label in workbench.EditorLayout.Labels)check(label!=null,name+": null workbench label");
            // The real controllers call Prepare before rendering descriptions; it sizes their native frames.
            UnityEngine.Canvas.ForceUpdateCanvases();
            if(inventory!=null)inventory.Prepare();
            if(workbench!=null)workbench.Prepare();
            check(text.richText&&text.raycastTarget&&text.fontSize>=14&&text.fontSize<=15,name+": body typography not configured");
            text.text="<link=\"term:1\"><u>Term</u></link> body\n\nSecond paragraph";
            UnityEngine.UI.ScrollRect scroll=null;
            for(var parent=text.transform.parent;parent!=null;parent=parent.parent){scroll=parent.GetComponent<UnityEngine.UI.ScrollRect>();if(scroll!=null)break;}
            check(scroll!=null&&scroll.content!=null&&scroll.viewport==input.EditorViewport,name+": scrolling/clipping changed");
            UnityEngine.Canvas.ForceUpdateCanvases();scroll.StopMovement();scroll.verticalNormalizedPosition=0;UnityEngine.Canvas.ForceUpdateCanvases();text.ForceMeshUpdate();
            check(text.rectTransform.lossyScale.sqrMagnitude>.01f&&input.EditorViewport.lossyScale.sqrMagnitude>.01f,name+": fixture panel geometry is collapsed");
            var info=text.textInfo.linkInfo[0];var character=text.textInfo.characterInfo[info.linkTextfirstCharacterIndex];
            var world=text.rectTransform.TransformPoint((character.bottomLeft+character.topRight)*.5f);
            var hit=UnityEngine.RectTransformUtility.WorldToScreenPoint(null,world);
            check(input.ClickAt(hit,null)&&input.TakeLink()=="term:1"&&input.TakeLink()=="",name+": visible TMP link not delivered exactly once");
            var outside=input.EditorViewport.TransformPoint(new UnityEngine.Vector3(input.EditorViewport.rect.xMax+20,input.EditorViewport.rect.yMax+20,0));
            check(!input.ClickAt(UnityEngine.RectTransformUtility.WorldToScreenPoint(null,outside),null),name+": clipped text was clickable");
            var pointer=new UnityEngine.EventSystems.PointerEventData(UnityEngine.EventSystems.EventSystem.current){position=hit,button=UnityEngine.EventSystems.PointerEventData.InputButton.Left,eligibleForClick=true};
            pointer.pointerCurrentRaycast=new UnityEngine.EventSystems.RaycastResult{gameObject=text.gameObject};
            input.OnPointerEnter(pointer);check(input.IsHovered(),name+": enter not observed");
            pointer.pointerCurrentRaycast=new UnityEngine.EventSystems.RaycastResult();check(!input.IsHovered(),name+": missing exit left stale hover");
            pointer.pointerCurrentRaycast=new UnityEngine.EventSystems.RaycastResult{gameObject=text.gameObject};
            input.OnPointerDown(pointer);pointer.dragging=true;input.OnPointerUp(pointer);pointer.dragging=false;input.OnPointerClick(pointer);
            check(input.TakeLink()=="",name+": scroll drag produced a link click");
            input.OnPointerDown(pointer);var before=text.rectTransform.anchoredPosition;text.rectTransform.anchoredPosition+=new UnityEngine.Vector2(0,12);
            input.OnPointerUp(pointer);input.OnPointerClick(pointer);text.rectTransform.anchoredPosition=before;
            check(input.TakeLink()=="",name+": moved scroll content produced a link click");
            input.OnPointerDown(pointer);input.OnPointerUp(pointer);input.OnPointerClick(pointer);check(input.TakeLink()=="term:1",name+": normal left click rejected");
            check(input.ClickAt(hit,null),name+": stale-text setup failed");text.text="Changed description";check(input.TakeLink()=="",name+": previous selection retained a queued link");
            card.Begin("Term","Explanation");card.Show(input.Anchor);check(card.Visible,name+": explanation card did not open");card.Hide();input.Clear();
            check(!card.Visible&&!input.IsHovered()&&input.TakeLink()=="",name+": interaction cleanup failed");
            panels++;
        }
        finally{UnityEngine.Object.DestroyImmediate(root);}
    }
}
finally{UnityEngine.Object.DestroyImmediate(canvasObject);UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
return "PASS "+panels+" equipment TMP panels: idempotent migration, serialized bindings, clipping, term click, drag rejection, stale hover/link cleanup and shared tooltip";
