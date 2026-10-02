// Unity MCP execute_code body. Edit Mode, temporary scene and cloned VolumeProfile only.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
bool originalDirty = originalScene.isDirty;
var originalPipeline = QualitySettings.renderPipeline;
var previousTarget = RenderTexture.active;
var volumeManager = UnityEngine.Rendering.VolumeManager.instance;
var previousStack = volumeManager.stack;
var previewStack = volumeManager.CreateStack();
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var temporaryMaterials = new System.Collections.Generic.List<Material>();
var errors = new System.Collections.Generic.List<string>();
Application.LogCallback log = (message, stack, type) => { if (type == LogType.Error || type == LogType.Exception) errors.Add(message); };
ProjectY.Rendering.FantasyPresentation presentation = null;
UnityEngine.Rendering.VolumeProfile profile = null;
RenderTexture target = null;
Texture2D image = null;
Camera camera = null;
var outputs = new System.Collections.Generic.List<object>();
Application.logMessageReceived += log;
try
{
    volumeManager.stack = previewStack;
    var host = new GameObject("Pixel Art Preview");
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host, scene);
    var cameraObject = new GameObject("Camera"); cameraObject.transform.SetParent(host.transform, false);
    camera = cameraObject.AddComponent<Camera>(); camera.enabled = false; camera.scene = scene;
    camera.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic = true; camera.orthographicSize = 1.65f;
    camera.transform.position = new Vector3(3.2f, 2.5f, 7); camera.transform.LookAt(new Vector3(0, .8f, 0));
    camera.nearClipPlane = .1f; camera.farClipPlane = 35;
    camera.clearFlags = CameraClearFlags.SolidColor; camera.backgroundColor = new Color(.12f, .17f, .23f);
    var sunObject = new GameObject("Sun"); sunObject.transform.SetParent(host.transform, false);
    var sun = sunObject.AddComponent<Light>(); sun.type = LightType.Directional; sun.intensity = 1.8f;
    sun.color = new Color(1, .88f, .74f); sun.shadows = LightShadows.Soft; sun.transform.rotation = Quaternion.Euler(42, 145, 0);
    var fillObject = new GameObject("Cool Fill"); fillObject.transform.SetParent(host.transform, false);
    var fill = fillObject.AddComponent<Light>(); fill.type = LightType.Point; fill.range = 12; fill.intensity = 3;
    fill.color = new Color(.38f, .6f, 1); fill.transform.position = new Vector3(-3, 3, 1);
    var ground = GameObject.CreatePrimitive(PrimitiveType.Cube); ground.transform.SetParent(host.transform, false);
    ground.transform.position = new Vector3(0, -.18f, 0); ground.transform.localScale = new Vector3(9, .2f, 7);
    var groundMaterial = new Material(Shader.Find("Universal Render Pipeline/Lit")); temporaryMaterials.Add(groundMaterial);
    groundMaterial.SetColor("_BaseColor", new Color(.2f, .27f, .3f)); groundMaterial.SetFloat("_Smoothness", .12f);
    ground.GetComponent<Renderer>().sharedMaterial = groundMaterial;
    var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab");
    var animations = UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Samples.PawnAnimationSet>("Assets/DynamicAsset/PawnAnimation/PawnAnimations.asset");
    for (int i = 0; i < 3; i++)
    {
        var root = UnityEngine.Object.Instantiate(prefab); root.transform.SetParent(host.transform, false);
        root.transform.position = new Vector3((i - 1) * 1.55f, 0, 0); root.transform.rotation = Quaternion.Euler(0, 16 - 16 * i, 0);
        var view = root.GetComponentInChildren<ProjectY.Samples.PawnCustomizationView>(true); view.gameObject.SetActive(true);
        var look = view.Catalog.Rules.Randomize(42 + i, "human", i == 1 ? "female" : "male");
        look.hair = "hair_" + i; view.Apply(look);
        var animator = view.GetComponent<Animator>(); animator.runtimeAnimatorController = animations.Controller;
        animator.applyRootMotion = false; animator.cullingMode = AnimatorCullingMode.AlwaysAnimate; animator.enabled = false;
        animator.Rebind(); animator.Play("Idle", 0, .25f); animator.Update(0);
        // Static snapshots make the fixture independent of Editor GPU skinning update timing.
        foreach (var skin in root.GetComponentsInChildren<SkinnedMeshRenderer>(true))
        {
            if (!skin.enabled || !skin.gameObject.activeInHierarchy || skin.sharedMesh == null) continue;
            var baked = new Mesh(); skin.BakeMesh(baked);
            var proxy = new GameObject("Snapshot", typeof(MeshFilter), typeof(MeshRenderer)); proxy.transform.SetParent(skin.transform, false);
            proxy.GetComponent<MeshFilter>().sharedMesh = baked;
            var meshRenderer = proxy.GetComponent<MeshRenderer>(); meshRenderer.sharedMaterials = skin.sharedMaterials;
            for (int m = 0; m < skin.sharedMaterials.Length; m++) { var block = new MaterialPropertyBlock(); skin.GetPropertyBlock(block, m); meshRenderer.SetPropertyBlock(block, m); }
            skin.enabled = false;
        }
    }
    presentation = new ProjectY.Rendering.FantasyPresentation(camera, host.transform);
    presentation.SetStyle(ProjectY.Rendering.WorldVisualStyle.PixelInk);
    var volume = host.GetComponentInChildren<UnityEngine.Rendering.Volume>();
    profile = volume.profile; // Unity clones components, leaving the shared authored profile intact.
    ProjectY.Rendering.PixelArt effect;
    if (!profile.TryGet<ProjectY.Rendering.PixelArt>(out effect)) throw new System.Exception("Pixel Art profile missing");
    System.IO.Directory.CreateDirectory("Docs/Previews/Rendering");
    foreach (var size in new[] { new Vector2Int(1280, 720), new Vector2Int(853, 601), new Vector2Int(1920, 1080) })
    {
        target = new RenderTexture(size.x, size.y, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB); target.Create(); camera.targetTexture = target; camera.aspect = size.x / (float)size.y;
        image = new Texture2D(size.x, size.y, TextureFormat.RGB24, false);
        Color32[] before = null;
        foreach (bool enabled in new[] { false, true })
        {
            effect.enableEffect.value = enabled;
            // URP 14 SingleCameraRequest does not update volumes like the normal frame loop does.
            volumeManager.Update(previewStack, camera.transform, 1);
            ProjectY.Rendering.UrpCameraRendering.Render(camera);
            RenderTexture.active = target; image.ReadPixels(new Rect(0, 0, size.x, size.y), 0, 0); image.Apply();
            var colors = image.GetPixels32();
            if (!enabled) before = colors;
            else
            {
                int changed = 0, pink = 0, violations = 0, comparisons = 0;
                int blockSize = Mathf.Max(1, Mathf.CeilToInt(size.y / (float)effect.referenceHeight.value));
                for (int y = 0; y < size.y; y++) for (int x = 0; x < size.x; x++)
                {
                    int at = y * size.x + x; var c = colors[at]; var old = before[at];
                    if (Mathf.Abs(c.r - old.r) + Mathf.Abs(c.g - old.g) + Mathf.Abs(c.b - old.b) > 6) changed++;
                    if (c.r > 225 && c.b > 225 && c.g < 30) pink++;
                    if (x % blockSize != 0)
                    {
                        var left = colors[at - 1]; comparisons++;
                        if (Mathf.Abs(c.r - left.r) + Mathf.Abs(c.g - left.g) + Mathf.Abs(c.b - left.b) > 3) violations++;
                    }
                }
                if (changed < colors.Length / 100 || pink > 30 || violations > comparisons / 1000) throw new System.Exception("Invalid pixel render: changed=" + changed + " pink=" + pink + " grid violations=" + violations);
                outputs.Add(new { width = size.x, height = size.y, blockSize, changed, pink, gridViolations = violations });
            }
            if (size.x == 1280) System.IO.File.WriteAllBytes("Docs/Previews/Rendering/pixel-art-" + (enabled ? "after" : "before") + ".png", image.EncodeToPNG());
        }
        camera.targetTexture = null; RenderTexture.active = previousTarget;
        UnityEngine.Object.DestroyImmediate(image); image = null; target.Release(); UnityEngine.Object.DestroyImmediate(target); target = null;
    }
    // The dedicated portrait renderer must ignore the enabled world effect entirely.
    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    target = new RenderTexture(320, 240, 24); target.Create(); camera.targetTexture = target;
    image = new Texture2D(320, 240, TextureFormat.RGB24, false);
    Color32[] portrait = null;
    foreach (bool enabled in new[] { false, true })
    {
        effect.enableEffect.value = enabled; volumeManager.Update(previewStack, camera.transform, 0); ProjectY.Rendering.UrpCameraRendering.Render(camera);
        RenderTexture.active = target; image.ReadPixels(new Rect(0, 0, 320, 240), 0, 0); image.Apply();
        var colors = image.GetPixels32();
        if (!enabled) portrait = colors;
        else if (!portrait.SequenceEqual(colors)) throw new System.Exception("World pixel effect leaked into preview renderer");
    }
    var shader = UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Rendering/PixelArt.shader");
    if (UnityEditor.ShaderUtil.ShaderHasError(shader) || errors.Count > 0) throw new System.Exception("Shader/render error: " + string.Join("; ", errors.ToArray()));
}
finally
{
    Application.logMessageReceived -= log;
    volumeManager.stack = previousStack;
    volumeManager.DestroyStack(previewStack);
    RenderTexture.active = previousTarget;
    if (camera != null) camera.targetTexture = null;
    if (presentation != null) presentation.Dispose();
    if (profile != null) { foreach (var component in profile.components) UnityEngine.Object.DestroyImmediate(component); UnityEngine.Object.DestroyImmediate(profile); }
    if (image != null) UnityEngine.Object.DestroyImmediate(image);
    if (target != null) { target.Release(); UnityEngine.Object.DestroyImmediate(target); }
    foreach (var material in temporaryMaterials) UnityEngine.Object.DestroyImmediate(material);
    foreach (var root in scene.GetRootGameObjects()) foreach (var filter in root.GetComponentsInChildren<MeshFilter>(true))
        if (filter.gameObject.name == "Snapshot") UnityEngine.Object.DestroyImmediate(filter.sharedMesh);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
if (QualitySettings.renderPipeline != originalPipeline || originalScene.isDirty != originalDirty) throw new System.Exception("Rendering or scene state was not restored");
var report = new { outputs, previewUnaffected = true, stateRestored = true, playMode = false };
System.IO.File.WriteAllText("Docs/Previews/Rendering/pixel-art-validation.json", Newtonsoft.Json.JsonConvert.SerializeObject(report, Newtonsoft.Json.Formatting.Indented));
return report;
