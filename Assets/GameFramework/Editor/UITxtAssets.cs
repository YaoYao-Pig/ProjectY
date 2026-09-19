using System.IO;
using UnityEditor;
using UnityEngine;

namespace ProjectY.Editor
{
    public static class UITxtAssets
    {
        private static double batchStarted;
        [MenuItem("Project Y/UI/Import TMP Resources")]
        public static void ImportResources()
        {
            if (!File.Exists("Assets/TextMesh Pro/Resources/TMP Settings.asset"))
            {
                var package = UnityEditor.PackageManager.PackageInfo.FindForAssembly(typeof(TMPro.TMP_Text).Assembly);
                AssetDatabase.ImportPackage(Path.Combine(package.resolvedPath, "Package Resources/TMP Essential Resources.unitypackage"), false);
                return; // ImportPackage completes on subsequent editor updates.
            }
            AssetDatabase.Refresh();
            Debug.Log("PROJECT_Y_TMP_RESOURCES_READY");
        }

        // Run without -quit: Unity's package import is asynchronous.
        public static void ImportResourcesBatch()
        {
            batchStarted = EditorApplication.timeSinceStartup;
            EditorApplication.update += WaitForResources;
            ImportResources();
        }
        private static void WaitForResources()
        {
            if (!EditorApplication.isUpdating && !EditorApplication.isCompiling && TMPro.TMP_Settings.instance != null && TMPro.TMP_Settings.defaultFontAsset != null)
            {
                EditorApplication.update -= WaitForResources;
                Debug.Log("PROJECT_Y_TMP_RESOURCES_READY");
                EditorApplication.Exit(0);
            }
            else if (EditorApplication.timeSinceStartup - batchStarted > 120)
            {
                Debug.LogError("TMP essential resource import did not finish.");
                EditorApplication.Exit(1);
            }
        }
    }
}
