using System;
using System.Runtime.CompilerServices;
using ProjectY.UI;
using UnityEngine;
using XLua;

namespace ProjectY
{
    [DisallowMultipleComponent]
    public sealed class GameBootstrap : MonoBehaviour
    {
        public static GameBootstrap Instance { get; private set; }
        [SerializeField] private bool openDemo = true;
        private LuaEnv lua;
        private Action<float, float> tick;
        private Action<float> fixedTick;
        private Action<float, float> lateTick;
        private Action<bool> pause;
        private Action shutdown;
        private Action back;
        private LuaFunction configQuery;
        private FrameworkServices services;
        private bool stopping;
#if UNITY_EDITOR
        private LuaFunction editorConsoleExecute;
        public bool IsEditorConsoleReady => !stopping && lua != null && configQuery != null;

        /// <summary>Editor bridge only. The caller must be on Unity's main thread.</summary>
        public object[] ExecuteEditorConsole(string runnerSource, string code, string chunkName)
        {
            if (!IsEditorConsoleReady) throw new InvalidOperationException("Lua runtime is not ready.");
            if (editorConsoleExecute == null)
                editorConsoleExecute = (LuaFunction)lua.DoString(runnerSource, "@Tools/LuaConsole/runtime.lua")[0];
            return editorConsoleExecute.Call(code, chunkName);
        }
#endif

        private void Awake()
        {
            if (Instance != null && Instance != this) { Destroy(gameObject); return; }
            Instance = this;
            DontDestroyOnLoad(gameObject);
            try
            {
                var ui = gameObject.AddComponent<UIHost>();
                ui.Initialize();
                services = new FrameworkServices(ui);
                lua = new LuaEnv();
                var loader = new LuaFileLoader(LuaScriptPaths.RuntimeRoot);
                lua.AddLoader(loader.Load);
                lua.Global.Set("Services", services);
                lua.Global.Set("OpenDemo", openDemo);
                lua.DoString("require('Main')", "GameBootstrap");
                tick = lua.Global.Get<Action<float, float>>("GameTick");
                fixedTick = lua.Global.Get<Action<float>>("GameFixedTick");
                lateTick = lua.Global.Get<Action<float, float>>("GameLateTick");
                pause = lua.Global.Get<Action<bool>>("GamePause");
                back = lua.Global.Get<Action>("GameBack");
                shutdown = lua.Global.Get<Action>("GameShutdown");
                configQuery = lua.Global.Get<LuaFunction>("GetConfigRow");
            }
            catch (Exception error) { Debug.LogException(error, this); Shutdown(); enabled = false; }
        }

        private void Update()
        {
            tick?.Invoke(Time.deltaTime, Time.unscaledDeltaTime);
            if (Input.GetKeyDown(KeyCode.Escape)) back?.Invoke();
            lua?.Tick();
        }
        private void FixedUpdate() => fixedTick?.Invoke(Time.fixedDeltaTime);
        private void LateUpdate() => lateTick?.Invoke(Time.deltaTime, Time.unscaledDeltaTime);
        private void OnApplicationPause(bool paused) => pause?.Invoke(paused);
        private void OnDestroy() { if (Instance == this) { Shutdown(); Instance = null; } }
        private void OnApplicationQuit() => Shutdown();

        /// <summary>The caller owns the returned LuaTable and must dispose it before the runtime shuts down.</summary>
        public LuaTable GetConfigRow(string tableName, object id)
        {
            if (stopping || configQuery == null) throw new InvalidOperationException("Lua runtime is not running.");
            if (!(id is int) && !(id is string)) throw new ArgumentException("Config keys must be int or string.", nameof(id));
            return (LuaTable)configQuery.Call(tableName, id)[0];
        }

        private void Shutdown()
        {
            if (stopping) return;
            stopping = true;
            ReleaseCallbacks();
            if (lua != null)
            {
                // Dispose performs managed/Lua collection after the callback invocation stack has unwound.
                lua.Dispose();
                lua = null;
            }
            services = null;
        }

        // Mono can keep the delegate used by shutdown.Invoke alive until its caller returns,
        // even after the field is cleared. End that stack frame before LuaEnv checks its bridges.
        [MethodImpl(MethodImplOptions.NoInlining)]
        private void ReleaseCallbacks()
        {
            try { shutdown?.Invoke(); }
            catch (Exception error) { Debug.LogException(error); }
            tick = null; fixedTick = null; lateTick = null; pause = null; back = null; shutdown = null;
            configQuery?.Dispose(); configQuery = null;
#if UNITY_EDITOR
            editorConsoleExecute?.Dispose(); editorConsoleExecute = null;
#endif
            services?.Player.ClearListeners();
            services?.UI.Shutdown();
            services?.Localization.Clear();
        }
    }
}
