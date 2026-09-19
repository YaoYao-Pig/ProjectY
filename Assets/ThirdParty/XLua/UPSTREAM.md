# xLua dependency

- Source: https://github.com/Tencent/xLua
- Pinned commit: `59bf42685dbe36fe0e1678a6ba8597f859ef7ca3`
- License: MIT, retained in `LICENSE.txt` and source headers.
- Imported unchanged: `Assets/XLua/Src`, `Assets/XLua/Resources`, `XLuaUnityDefaultConfig.cs`.
- Native plugin: upstream `Assets/Plugins/x86_64/xlua.dll`. Importer metadata restricts it to Windows x64 (the upstream legacy Linux/macOS enable flags were disabled).
- This initial integration targets Windows x64 Editor/player. For another target, add/build the matching native plugin from this exact revision, regenerate bridges and test on that platform.
- No hotfix injection is enabled. Lua is the main business runtime; C# hotfix is not needed for this framework.

Use **XLua > Generate Code** after changing exposed C# APIs or C#-to-Lua delegate signatures. Keep generated wrappers in source control. They are required for IL2CPP/AOT; editor reflection alone is not a player-build guarantee.
