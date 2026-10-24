using System.IO;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    public static class WorldSiteUIAssets
    {
        [MenuItem("Project Y/UI/同步大地图地点标签与遮罩")]
        public static void Sync()
        {
            const string folder = "Assets/GameFramework/Resources/UI";
            Directory.CreateDirectory(folder);
            var mask = new GameObject("SceneFocusMask", typeof(RectTransform), typeof(RawImage));
            var root = new GameObject("WorldSiteOverlay", typeof(RectTransform), typeof(LuaReference));
            try
            {
                mask.layer = root.layer = 5;
                var maskRect = (RectTransform)mask.transform; Stretch(maskRect);
                var image = mask.GetComponent<RawImage>(); image.raycastTarget = false;
                PrefabUtility.SaveAsPrefabAsset(mask, folder + "/SceneFocusMask.prefab");
                Stretch((RectTransform)root.transform);
                var tag = new GameObject("TagTemplate", typeof(RectTransform), typeof(CanvasGroup), typeof(Image), typeof(LuaReference), typeof(UIFollower));
                tag.layer = 5; tag.transform.SetParent(root.transform, false);
                var rect = (RectTransform)tag.transform; rect.anchorMin = rect.anchorMax = new Vector2(.5f, .5f);
                rect.pivot = new Vector2(.5f, 0); rect.sizeDelta = new Vector2(180, 34);
                var background = tag.GetComponent<Image>(); background.color = new Color(.055f, .075f, .085f, .92f); background.raycastTarget = false;
                var border = tag.AddComponent<Outline>(); border.effectColor = new Color(.65f, .54f, .32f, .8f); border.effectDistance = new Vector2(1, -1);
                var group = tag.GetComponent<CanvasGroup>(); group.interactable = group.blocksRaycasts = false;
                var labelObject = new GameObject("Label", typeof(RectTransform), typeof(Text)); labelObject.layer = 5; labelObject.transform.SetParent(tag.transform, false);
                var labelRect = (RectTransform)labelObject.transform; Stretch(labelRect); labelRect.offsetMin = new Vector2(14, 2); labelRect.offsetMax = new Vector2(-14, -2);
                var label = labelObject.GetComponent<Text>(); label.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
                label.fontSize = 16; label.alignment = TextAnchor.MiddleCenter; label.raycastTarget = false;
                label.horizontalOverflow = HorizontalWrapMode.Overflow; label.verticalOverflow = VerticalWrapMode.Truncate;
                label.resizeTextForBestFit = true; label.resizeTextMinSize = 11; label.resizeTextMaxSize = 16;
                var follower = tag.GetComponent<UIFollower>(); follower.SetEditorBindings(rect, group);
                var settings = new SerializedObject(follower);
                settings.FindProperty("worldOffset").vector3Value = new Vector3(0, .6f, 0);
                settings.FindProperty("screenOffset").vector2Value = new Vector2(0, 10);
                settings.FindProperty("orthographicFade").vector2Value = new Vector2(100000, 100001);
                settings.FindProperty("perspectiveFade").vector2Value = new Vector2(100000, 100001);
                settings.FindProperty("minScale").floatValue = 1; settings.FindProperty("maxScale").floatValue = 1;
                settings.ApplyModifiedPropertiesWithoutUndo();
                var reference = tag.GetComponent<LuaReference>();
                reference.SetEditorBindings(new LuaReference.Entry("Root", rect), new LuaReference.Entry("Label", label),
                    new LuaReference.Entry("Background", background), new LuaReference.Entry("Follower", follower));
                reference.ValidateBindings(); tag.SetActive(false);
                root.GetComponent<LuaReference>().SetEditorBindings(new LuaReference.Entry("TagTemplate", reference));
                PrefabUtility.SaveAsPrefabAsset(root, folder + "/WorldSiteOverlay.prefab");
            }
            finally { Object.DestroyImmediate(root); Object.DestroyImmediate(mask); }
            Debug.Log("World-site tag and inverse-mask prefab bindings saved.");
        }
        private static void Stretch(RectTransform rect)
        { rect.anchorMin = Vector2.zero; rect.anchorMax = Vector2.one; rect.offsetMin = rect.offsetMax = Vector2.zero; }
    }
}
