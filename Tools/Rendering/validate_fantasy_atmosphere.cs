// Edit Mode proof that shadows affect volumetric lighting, including perspective and odd-sized targets.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.Exception("Edit Mode required");
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); bool dirty = originalScene.isDirty;
var originalPipeline = QualitySettings.renderPipeline; var originalTarget = RenderTexture.active;
var manager = UnityEngine.Rendering.VolumeManager.instance; var previousStack = manager.stack; var stack = manager.CreateStack();
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Rendering.FantasyPresentation presentation = null;
UnityEngine.Rendering.VolumeProfile profile = null;
Material material = null; RenderTexture target = null; Texture2D fogImage = null;
var results = new System.Collections.Generic.List<object>();
try
{
    manager.stack = stack;
    var host = new GameObject("Atmosphere Verification"); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host, scene);
    material = new Material(Shader.Find("Universal Render Pipeline/Lit")); material.color = new Color(.4f, .45f, .35f);
    for (int i = 0; i < 5; i++)
    {
        var obj = GameObject.CreatePrimitive(PrimitiveType.Cube); obj.transform.SetParent(host.transform, false); obj.GetComponent<Renderer>().sharedMaterial = material;
        if (i == 0) { obj.transform.position = new Vector3(0, -.1f, 0); obj.transform.localScale = new Vector3(20, .2f, 30); }
        else { obj.transform.position = new Vector3((i - 2.5f) * 2.7f, 2.7f, 0); obj.transform.localScale = new Vector3(1.3f, 5.4f, 1.4f); }
    }
    var sunObject = new GameObject("Sun"); sunObject.transform.SetParent(host.transform, false);
    var sun = sunObject.AddComponent<Light>(); sun.type = LightType.Directional; sun.shadows = LightShadows.Soft; sun.intensity = 1.8f;
    sun.color = new Color(1, .9f, .75f); sun.transform.rotation = Quaternion.Euler(35, 15, 0);
    var cameraObject = new GameObject("Camera"); cameraObject.transform.SetParent(host.transform, false);
    var camera = cameraObject.AddComponent<Camera>(); camera.enabled = false; camera.scene = scene;
    camera.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.clearFlags = CameraClearFlags.SolidColor; camera.backgroundColor = new Color(.15f, .2f, .25f);
    camera.nearClipPlane = .1f; camera.farClipPlane = 100; camera.aspect = 801f / 501; camera.orthographicSize = 7;
    camera.transform.position = new Vector3(0, 4, 18); camera.transform.LookAt(new Vector3(0, 2, 0));
    target = new RenderTexture(801, 501, 24, RenderTextureFormat.ARGB32); target.Create(); camera.targetTexture = target;
    presentation = new ProjectY.Rendering.FantasyPresentation(camera, host.transform); presentation.SetStyle(ProjectY.Rendering.WorldVisualStyle.MedievalFantasy);
    presentation.SetShadowDistance(80);
    var volume = host.GetComponentInChildren<UnityEngine.Rendering.Volume>(); profile = volume.profile;
    ProjectY.Rendering.FantasyAtmosphere atmosphere;
    if (!profile.TryGet<ProjectY.Rendering.FantasyAtmosphere>(out atmosphere)) throw new System.Exception("Atmosphere component missing");
    atmosphere.density.value = .018f; atmosphere.strength.value = 1; // Amplify the fixture, never the authored profile.
    foreach (bool ortho in new[] { true, false })
    {
        camera.orthographic = ortho;
        Color[] shadowed = null;
        foreach (float shadows in new[] { 1f, 0f })
        {
            sun.shadowStrength = shadows; manager.Update(stack, camera.transform, 1); ProjectY.Rendering.UrpCameraRendering.Render(camera);
            var fog = Shader.GetGlobalTexture("_FantasyFogTexture") as RenderTexture;
            if (fog == null || fog.width != 401 || fog.height != 251) throw new System.Exception("Half-resolution atmosphere pass did not run");
            if (fogImage == null) fogImage = new Texture2D(fog.width, fog.height, TextureFormat.RGBAFloat, false, true);
            RenderTexture.active = fog; fogImage.ReadPixels(new Rect(0, 0, fog.width, fog.height), 0, 0); fogImage.Apply();
            var values = fogImage.GetPixels();
            if (values.Any(c => float.IsNaN(c.r) || float.IsInfinity(c.r) || c.a < 0 || c.a > 1.001f)) throw new System.Exception("Invalid scattering/transmission");
            if (shadows == 1) shadowed = values;
            else
            {
                int changed = 0;
                for (int i = 0; i < values.Length; i++) if (values[i].r - shadowed[i].r > .0002f) changed++;
                if (changed < 50) throw new System.Exception("Main-light shadows did not affect volumetric lighting");
                results.Add(new { orthographic = ortho, shadowedFogPixels = changed, halfWidth = fog.width, halfHeight = fog.height });
            }
        }
    }
    // Dedicated portrait renderer is still excluded even with a world atmosphere volume active.
    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera); manager.Update(stack, camera.transform, 0);
    ProjectY.Rendering.UrpCameraRendering.Render(camera);
    return results;
}
finally
{
    RenderTexture.active = originalTarget;
    if (presentation != null) presentation.Dispose();
    manager.stack = previousStack; manager.DestroyStack(stack); RenderTexture.active = originalTarget;
    if (profile != null) { foreach (var component in profile.components) UnityEngine.Object.DestroyImmediate(component); UnityEngine.Object.DestroyImmediate(profile); }
    if (fogImage != null) UnityEngine.Object.DestroyImmediate(fogImage);
    if (material != null) UnityEngine.Object.DestroyImmediate(material);
    if (target != null) { target.Release(); UnityEngine.Object.DestroyImmediate(target); }
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if (QualitySettings.renderPipeline != originalPipeline || originalScene.isDirty != dirty) throw new System.Exception("Verification leaked rendering/scene state");
}
