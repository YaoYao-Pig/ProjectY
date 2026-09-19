using System;
using System.IO;
using System.Text.RegularExpressions;

namespace ProjectY
{
    /// <summary>Resolves xLua require names to ordinary .lua files below an explicit source root.</summary>
    public sealed class LuaFileLoader
    {
        private static readonly Regex ModuleName = new Regex(@"\A[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*\z");
        public string RootDirectory { get; }

        public LuaFileLoader(string rootDirectory)
        {
            if (string.IsNullOrWhiteSpace(rootDirectory)) throw new ArgumentException("Lua root is required.", nameof(rootDirectory));
            if (rootDirectory.Contains("://"))
                throw new NotSupportedException("LuaFileLoader requires a local directory. URI-based StreamingAssets needs an asynchronous preload provider.");
            RootDirectory = Path.GetFullPath(rootDirectory);
            if (!Directory.Exists(RootDirectory)) throw new DirectoryNotFoundException("Lua source directory not found: " + RootDirectory);
        }

        public static bool IsValidModuleName(string module) => module != null && ModuleName.IsMatch(module);

        public byte[] Load(ref string module)
        {
            // Only dot-separated identifiers are accepted; absolute paths and traversal never reach the filesystem.
            if (!IsValidModuleName(module)) return null;
            var filename = Path.Combine(RootDirectory, module.Replace('.', Path.DirectorySeparatorChar) + ".lua");
            if (!File.Exists(filename)) return null;
            var bytes = File.ReadAllBytes(filename);
            // Keep a real filename in xLua traceback/debugger information.
            module = filename.Replace('\\', '/');
            // Lua loadbuffer does not have loadfile's UTF-8 BOM handling.
            if (bytes.Length >= 3 && bytes[0] == 0xef && bytes[1] == 0xbb && bytes[2] == 0xbf)
            {
                var source = new byte[bytes.Length - 3];
                Buffer.BlockCopy(bytes, 3, source, 0, source.Length);
                return source;
            }
            return bytes;
        }
    }
}
