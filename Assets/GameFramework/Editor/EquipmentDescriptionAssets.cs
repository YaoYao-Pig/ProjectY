using System;
using System.Collections.Generic;
using System.Linq;
using ProjectY.UI;
using TMPro;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    /// <summary>Migrates only existing description text and adds serialized terminology interaction.</summary>
    [InitializeOnLoad]
    public static class EquipmentDescriptionAssets
    {
        static EquipmentDescriptionAssets()=>LuaViewHints.Register(typeof(TMPTermLinkView),"CS.ProjectY.UI.TMPTermLinkView");

        [MenuItem("Project Y/装备/同步装备术语说明")]
        public static void Sync()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Equipment description synchronization requires Edit Mode.");
            var config=PanelAssets.LoadOrCreate();
            foreach(var name in new[]{"Inventory","Loot","EquipmentWorkbench"})
            {
                var entry=config.Entries.Find(row=>row.Name==name)??throw new InvalidOperationException("Missing equipment panel: "+name);
                var root=PrefabUtility.LoadPrefabContents(entry.PrefabPath);
                try
                {
                    Apply(name,root);
                    var reference=root.GetComponent<LuaReference>();reference.ValidateBindings();
                    PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);LuaViewHints.Export(reference,entry.ViewType);
                }
                finally{PrefabUtility.UnloadPrefabContents(root);}
            }
            AssetDatabase.SaveAssets();
            Debug.Log("Equipment TMP descriptions, terminology input and explanation cards saved on three panels.");
        }

        private static TMP_Text ConvertDescription(LuaReference reference,string key,TMP_FontAsset font)
        {
            var entries=reference.GetEditorBindings();var localizations=reference.GetEditorLocalizations();
            var component=reference.Get(key);TMP_Text text;
            if(component is TMP_Text existing)text=existing;
            else if(component is Text legacy)
            {
                var node=legacy.gameObject;string content=legacy.text;Color color=legacy.color;
                var entryIndices=new List<int>();var localizationIndices=new List<int>();
                for(int i=0;i<entries.Length;i++)if(entries[i].Target==legacy)entryIndices.Add(i);
                for(int i=0;i<localizations.Length;i++)if(localizations[i].Target==legacy)localizationIndices.Add(i);
                // Keep the node, RectTransform and every layout/scroll component; only replace its Graphic.
                UnityEngine.Object.DestroyImmediate(legacy);
                text=node.AddComponent<TextMeshProUGUI>();text.text=content;text.color=color;
                foreach(int i in entryIndices)entries[i].Target=text;
                foreach(int i in localizationIndices)localizations[i].Target=text;
                reference.SetEditorBindings(entries);reference.SetEditorLocalizations(localizations);
            }
            else throw new InvalidOperationException("Equipment description must bind Text or TMP_Text: "+key);
            text.font=font;text.fontSize=15;text.enableAutoSizing=false;text.enableWordWrapping=true;
            text.richText=true;text.raycastTarget=true;text.alignment=TextAlignmentOptions.TopLeft;
            text.overflowMode=TextOverflowModes.Overflow;text.lineSpacing=6;text.paragraphSpacing=8;
            EditorUtility.SetDirty(text);return text;
        }

        private static RectTransform DescriptionViewport(TMP_Text text)
        {
            // Editor-only discovery becomes one permanent serialized reference; runtime never searches.
            for(var parent=text.transform.parent;parent!=null;parent=parent.parent)
            {
                var scroll=parent.GetComponent<ScrollRect>();
                if(scroll!=null&&scroll.content!=null&&text.transform.IsChildOf(scroll.content))
                    return scroll.viewport!=null?scroll.viewport:(RectTransform)scroll.transform;
            }
            throw new InvalidOperationException("Equipment description requires its existing scroll viewport.");
        }

        private static RectTransform Bounds(string name,GameObject root)
        {
            if(name=="EquipmentWorkbench")return root.GetComponent<EquipmentWorkbenchView>().EditorLayout.Safe;
            return root.GetComponent<InventoryPanelView>().EditorLayout.Root;
        }

        private static void LocalizeCard(LuaReference reference,SkillTooltipView card)
        {
            var bindings=new List<LuaReference.LocalizedText>(reference.GetEditorLocalizations());var layout=card.EditorLayout;
            void Bind(Component target,string id)
            {
                if(target==null)throw new InvalidOperationException("Missing terminology-card text: "+id);
                bindings.RemoveAll(row=>row.Target==target);bindings.Add(new LuaReference.LocalizedText(target,id));
            }
            Bind(layout.Back.GetComponentInChildren<TMP_Text>(true),"UIBattleHUDPanelSafeAreaSkillTipBackLabel");
            Bind(layout.StatsTitle,"UIBattleHUDPanelSafeAreaSkillTipScrollViewportContentStatsTitle");
            Bind(layout.SynergyTitle,"UIBattleHUDPanelSafeAreaSkillTipScrollViewportContentSynergyTitle");
            Bind(layout.SynergyTemplate.Mask.Find("Unknown").GetComponent<TMP_Text>(),"UIBattleHUDPanelSafeAreaSkillTipScrollViewportContentSynergiesSynergyTemplateUndiscoveredMaskUnknown");
            Bind(layout.SynergyTemplate.Mask.Find("UnlockHint").GetComponent<TMP_Text>(),"UIBattleHUDPanelSafeAreaSkillTipScrollViewportContentSynergiesSynergyTemplateUndiscoveredMaskUnlockHint");
            reference.SetEditorLocalizations(bindings.ToArray());
        }

        internal static void Apply(string name,GameObject root)
        {
            if(name!="Inventory"&&name!="Loot"&&name!="EquipmentWorkbench")return;
            var reference=root.GetComponent<LuaReference>()??throw new InvalidOperationException("Equipment panel requires LuaReference.");
            var font=AssetDatabase.LoadAssetAtPath<TMP_FontAsset>(SkillTooltipAssets.FontPath)
                ??throw new InvalidOperationException("Missing tooltip font: "+SkillTooltipAssets.FontPath);
            var text=ConvertDescription(reference,name=="EquipmentWorkbench"?"Stats":"ItemDetail",font);
            var entries=new List<LuaReference.Entry>(reference.GetEditorBindings());var bounds=Bounds(name,root);
            var inputEntry=entries.Find(row=>row.Key=="DescriptionLinks");TMPTermLinkView input;
            RectTransform anchor;
            if(inputEntry.Target==null)
            {
                input=text.gameObject.GetComponent<TMPTermLinkView>()??text.gameObject.AddComponent<TMPTermLinkView>();
                anchor=(RectTransform)new GameObject("EquipmentDescriptionAnchor",typeof(RectTransform)).transform;
                anchor.SetParent(bounds,false);anchor.anchorMin=anchor.anchorMax=new Vector2(.5f,.5f);
                anchor.pivot=new Vector2(0,1);anchor.sizeDelta=new Vector2(2,2);
                entries.Add(new LuaReference.Entry("DescriptionLinks",input));
            }
            else
            {
                input=inputEntry.Target as TMPTermLinkView??throw new InvalidOperationException("DescriptionLinks must bind TMPTermLinkView.");
                if(input.transform!=text.transform)throw new InvalidOperationException("DescriptionLinks is bound to another text node.");
                anchor=input.Anchor;
            }
            input.SetEditorBindings(text,DescriptionViewport(text),anchor);EditorUtility.SetDirty(input);
            var tipEntry=entries.Find(row=>row.Key=="EquipmentTermTip");SkillTooltipView tip;
            if(tipEntry.Target==null)
            {
                tip=SkillTooltipAssets.Create(bounds,font);tip.name="EquipmentTermTip";
                entries.Add(new LuaReference.Entry("EquipmentTermTip",tip));
            }
            else tip=tipEntry.Target as SkillTooltipView??throw new InvalidOperationException("EquipmentTermTip must bind SkillTooltipView.");
            tip.SetEditorPreferRight(true);EditorUtility.SetDirty(tip);
            reference.SetEditorBindings(entries.ToArray());LocalizeCard(reference,tip);
            // Runtime font preparation remains responsible only for legacy labels.
            var inventory=root.GetComponent<InventoryPanelView>();
            if(inventory!=null){inventory.EditorLayout.Labels=root.GetComponentsInChildren<Text>(true).Where(label=>label!=null).ToArray();EditorUtility.SetDirty(inventory);}
            var workbench=root.GetComponent<EquipmentWorkbenchView>();
            if(workbench!=null){workbench.EditorLayout.Labels=root.GetComponentsInChildren<Text>(true).Where(label=>label!=null).ToArray();EditorUtility.SetDirty(workbench);}
            reference.ValidateBindings();EditorUtility.SetDirty(reference);
        }
    }
}
