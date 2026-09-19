using System.IO;
using UnityEngine;

namespace ProjectY
{
    public static class LuaScriptPaths
    {
        public const string DirectoryName = "Lua";

        public static string RuntimeRoot
        {
            get
            {
#if UNITY_EDITOR
                return Path.GetFullPath(Path.Combine(Application.dataPath, "..", DirectoryName));
#else
                return Path.Combine(Application.streamingAssetsPath, DirectoryName);
#endif
            }
        }
    }
}
