using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    [LuaCallCSharp]
    public sealed class UIHost : MonoBehaviour
    {
        private readonly Dictionary<LuaReference, LuaPanel> instances = new Dictionary<LuaReference, LuaPanel>();
        private readonly HashSet<LuaReference> widgets = new HashSet<LuaReference>();
        private readonly HashSet<LuaPanel> pauseOwners = new HashSet<LuaPanel>();
        private PanelConfig config;
        private RectTransform screenRoot;
        private RectTransform worldRoot;
        private Transform staging;
        private GameObject ownedEventSystem;
        private bool initialized;
        private float previousTimeScale;
        public int SceneVersion { get; private set; }
        public bool IsWorldPaused => pauseOwners.Count != 0;

        public void Initialize()
        {
            if (initialized) return;
            initialized = true;
            screenRoot = CreateRoot("UIRoot", RenderMode.ScreenSpaceOverlay);
            worldRoot = CreateRoot("WorldUIRoot", RenderMode.WorldSpace);
            var stagingObject = new GameObject("InactiveUI");
            stagingObject.SetActive(false);
            stagingObject.transform.SetParent(transform, false);
            staging = stagingObject.transform;
            SceneManager.activeSceneChanged += OnSceneChanged;
            SceneManager.sceneLoaded += OnSceneLoaded;
            SceneManager.sceneUnloaded += OnSceneUnloaded;
            EnsureEventSystem();
        }

        private RectTransform CreateRoot(string name, RenderMode mode)
        {
            var root = new GameObject(name, typeof(RectTransform), typeof(Canvas), typeof(CanvasScaler));
            root.transform.SetParent(transform, false);
            var canvas = root.GetComponent<Canvas>();
            canvas.renderMode = mode;
            var rect = (RectTransform)root.transform;
            rect.localPosition = Vector3.zero;
            rect.localRotation = Quaternion.identity;
            rect.localScale = Vector3.one;
            rect.sizeDelta = new Vector2(1280, 720);
            if (mode == RenderMode.ScreenSpaceOverlay)
            {
                var scaler = root.GetComponent<CanvasScaler>();
                scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
                scaler.referenceResolution = new Vector2(1280, 720);
                scaler.matchWidthOrHeight = 0.5f;
            }
            else canvas.worldCamera = Camera.main;
            return rect;
        }

        private void EnsureEventSystem()
        {
            foreach (var system in FindObjectsOfType<EventSystem>())
            {
                if (system.gameObject != ownedEventSystem && system.isActiveAndEnabled)
                {
                    if (ownedEventSystem != null) ownedEventSystem.SetActive(false);
                    return;
                }
            }
            if (ownedEventSystem == null)
            {
                ownedEventSystem = new GameObject("UIEventSystem", typeof(EventSystem), typeof(StandaloneInputModule));
                ownedEventSystem.transform.SetParent(transform, false);
            }
            ownedEventSystem.SetActive(true);
        }

        private void OnSceneChanged(Scene from, Scene to) { SceneVersion++; EnsureEventSystem(); }
        private void OnSceneLoaded(Scene scene, LoadSceneMode mode)
        {
            if (mode == LoadSceneMode.Single) SceneVersion++;
            EnsureEventSystem();
        }
        private void OnSceneUnloaded(Scene scene) => EnsureEventSystem();

        public PanelDefinition GetConfig(string name)
        {
            if (config == null)
            {
                config = Resources.Load<PanelConfig>(PanelConfig.ResourceName);
                if (config == null) throw new InvalidOperationException("Missing PanelConfig. Open Project Y/UI/Panel Generator.");
                config.Validate(false);
            }
            return config.Get(name);
        }

        public LuaReference CreateView(string name)
        {
            if (!initialized) throw new InvalidOperationException("Initialize UIHost before creating a Panel.");
            var definition = GetConfig(name);
            definition.Validate(true);
            if (definition.IsWidget) throw new ArgumentException(name + " is a Widget, not a Panel.");
            var instance = Instantiate(definition.Prefab, staging, false);
            instance.SetActive(false);
            try
            {
                instance.transform.SetParent(definition.IsWorldUI ? worldRoot : screenRoot, false);
                var panel = instance.GetComponent<LuaPanel>();
                panel.Initialize(this, definition);
                var view = panel.View;
                view.ValidateBindings();
                instances.Add(view, panel);
                return view;
            }
            catch { DestroyObject(instance); throw; }
        }

        public LuaReference CreateWidget(string name, Transform parent)
        {
            if (!initialized) throw new InvalidOperationException("Initialize UIHost before creating a Widget.");
            if (parent == null) throw new ArgumentNullException(nameof(parent));
            var definition = GetConfig(name);
            definition.Validate(true);
            if (!definition.IsWidget) throw new ArgumentException(name + " is a Panel, not a Widget.");
            var instance = Instantiate(definition.Prefab, staging, false);
            instance.SetActive(false);
            try
            {
                var view = instance.GetComponent<LuaReference>();
                view.ValidateBindings();
                instance.transform.SetParent(parent, false);
                widgets.Add(view);
                return view;
            }
            catch { DestroyObject(instance); throw; }
        }

        public void SetWidgetVisible(LuaReference view, bool visible) => view.gameObject.SetActive(visible);
        public void DestroyWidget(LuaReference view)
        {
            if (!widgets.Remove(view) || view == null) return;
            view.gameObject.SetActive(false); DestroyObject(view.gameObject);
        }

        public LuaPanel GetPanel(LuaReference view) => instances[view];
        public void SetVisible(LuaReference view, bool visible) => instances[view].SetVisible(visible);
        public void SetOrder(LuaReference view, int order) => instances[view].SetOrder(order);
        public void SetInteractable(LuaReference view, bool value) => instances[view].SetInteractable(value);

        internal void SetPauseLease(LuaPanel panel, bool acquire)
        {
            if (acquire)
            {
                if (pauseOwners.Contains(panel)) return;
                if (pauseOwners.Count == 0) { previousTimeScale = Time.timeScale; Time.timeScale = 0; }
                pauseOwners.Add(panel);
            }
            else if (pauseOwners.Remove(panel) && pauseOwners.Count == 0) Time.timeScale = previousTimeScale;
        }

        public void DestroyView(LuaReference view)
        {
            if (!instances.TryGetValue(view, out var panel)) return;
            instances.Remove(view);
            if (panel == null) return;
            panel.SetVisible(false); DestroyObject(panel.gameObject);
        }

        public void Shutdown()
        {
            if (!initialized) return;
            initialized = false;
            SceneManager.activeSceneChanged -= OnSceneChanged;
            SceneManager.sceneLoaded -= OnSceneLoaded;
            SceneManager.sceneUnloaded -= OnSceneUnloaded;
            foreach (var view in new List<LuaReference>(widgets)) DestroyWidget(view);
            foreach (var view in new List<LuaReference>(instances.Keys)) DestroyView(view);
            if (pauseOwners.Count != 0) { pauseOwners.Clear(); Time.timeScale = previousTimeScale; }
            // Children may already be gone when Unity destroys the host, or initialization failed partway.
            if (screenRoot != null) DestroyObject(screenRoot.gameObject);
            if (worldRoot != null) DestroyObject(worldRoot.gameObject);
            if (staging != null) DestroyObject(staging.gameObject);
            screenRoot = null; worldRoot = null; staging = null;
            if (ownedEventSystem != null)
            {
                ownedEventSystem.SetActive(false);
                DestroyObject(ownedEventSystem); ownedEventSystem = null;
            }
        }

        private void OnDestroy() => Shutdown();

        public static void DestroyObject(GameObject obj)
        {
            if (Application.isPlaying) Destroy(obj); else DestroyImmediate(obj);
        }
    }
}
