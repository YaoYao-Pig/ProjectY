using System;
using System.IO;
using UnityEditor;
using UnityEngine;
using XLua;

namespace ProjectY.Editor
{
    public static class ForestAnimalValidation
    {
        [MenuItem("Project Y/远征/验证森林动物与骑乘")]
        public static void Run()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("仅在 Edit Mode 验证森林动物。");
            using(var lua=new LuaEnv())
            {
                var services=new FrameworkServices(null);
                var loader=new LuaFileLoader(LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
                try
                {
                    var path=Path.Combine(Directory.GetParent(Application.dataPath).FullName,"Tools/Tests/forest_animals_integration.lua");
                    Debug.Log((string)lua.DoString(File.ReadAllText(path),"@"+path)[0]);
                }
                finally {lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
            }
        }
    }
}
