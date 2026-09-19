using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor.Build;

namespace ProjectY.Editor
{
    public static class LuaBuildFiles
    {
        /// <summary>Validated deterministic .lua build inputs. Keep development tests outside this source root.</summary>
        public static string[] Collect(string sourceRoot)
        {
            var root = Path.GetFullPath(sourceRoot).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            if (!Directory.Exists(root)) throw new BuildFailedException("Lua source directory not found: " + root);
            var hints = Path.Combine(root, "UI", "Types") + Path.DirectorySeparatorChar;
            var files = Directory.GetFiles(root, "*.lua", SearchOption.AllDirectories).Where(file => !file.StartsWith(hints, StringComparison.OrdinalIgnoreCase)).ToArray();
            Array.Sort(files, StringComparer.Ordinal);
            var modules = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var file in files)
            {
                var relative = file.Substring(root.Length + 1).Replace('\\', '/');
                var stem = relative.Substring(0, relative.Length - 4);
                // A dot in an actual filename cannot map back to a dot-separated require name.
                if (!relative.EndsWith(".lua", StringComparison.Ordinal) || stem.Contains(".") ||
                    !LuaFileLoader.IsValidModuleName(stem.Replace('/', '.')))
                    throw new BuildFailedException("Lua paths must use identifier segments and a lowercase .lua extension: " + relative);
                if (!modules.Add(stem)) throw new BuildFailedException("Case-colliding Lua module: " + relative);
            }
            if (!File.Exists(Path.Combine(root, "Main.lua"))) throw new BuildFailedException("Lua/Main.lua is required.");
            if (!File.Exists(Path.Combine(root, "Generated", "Manifest.lua"))) throw new BuildFailedException("Export config before building Lua scripts.");
            return files;
        }
    }
}
