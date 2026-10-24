// Unity MCP execute_code body. Pure camera math plus a temporary Camera; no Play or scene edits.
if (EditorApplication.isPlayingOrWillChangePlaymode || EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var savedScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
bool wasDirty = savedScene.isDirty;
int checks = 0;
System.Action<bool, string> check = (ok, message) => { if (!ok) throw new System.Exception(message); checks++; };
var cameraObject = new GameObject("Strategy camera validation");
UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject, scene);
var camera = cameraObject.AddComponent<Camera>(); camera.enabled = false; camera.orthographic = true;
// Keep portrait and high-resolution fixtures independent of the current Editor Game view size.
var target = new RenderTexture(2048,2048,0); camera.targetTexture = target;
System.Action<ProjectY.Samples.StrategyCameraRig, Rect> apply = (rig, viewport) =>
{
    camera.pixelRect = viewport; camera.aspect = viewport.width / viewport.height;
    camera.orthographicSize = rig.RenderZoom;
    var rotation = Quaternion.Euler(rig.RenderPitch, rig.RenderYaw, 0);
    camera.transform.SetPositionAndRotation(rig.RenderFocus - rotation * Vector3.forward * 5000, rotation);
};
try
{
    foreach (var viewport in new[] {new Rect(0,0,800,600),new Rect(240,0,1040,720),new Rect(0,0,720,1280)})
    foreach (float pitch in new[] {20f,50f,85f})
    foreach (float yaw in new[] {-170f,-35f,90f})
    foreach (float size in new[] {3f,15f,600f})
    {
        var rig = new ProjectY.Samples.StrategyCameraRig {Focus = new Vector3(30,7,-20),Zoom = size,Pitch = pitch,Yaw = yaw}; rig.Snap();
        apply(rig, viewport);
        var pointer = viewport.center + new Vector2(viewport.width * .21f, viewport.height * -.17f);
        var plane = new Plane(Vector3.up, rig.RenderFocus);
        var ray = camera.ScreenPointToRay(pointer);
        float distance;
        check(plane.Raycast(ray, out distance), "Pointer must hit focus plane");
        var anchor = ray.GetPoint(distance);
        var delta = new Vector2(61,-37);
        rig.Pan(-delta, viewport.height); apply(rig, viewport);
        check(Vector2.Distance((Vector2)camera.WorldToScreenPoint(anchor), pointer + delta) < .35f, "Drag projection mismatch: pitch="+pitch+", yaw="+yaw+", size="+size+", viewport="+viewport);
        var stopped = rig.RenderFocus; rig.Tick(.5f);
        check(Vector3.Distance(rig.RenderFocus, stopped) < .001f, "No drift after manual pan");

        apply(rig, viewport); ray = camera.ScreenPointToRay(pointer); plane = new Plane(Vector3.up, rig.RenderFocus);
        plane.Raycast(ray, out distance); anchor = ray.GetPoint(distance);
        rig.Scroll(2, pointer, viewport, 1, 2000);
        for (int frame = 0; frame < 30; frame++)
        {
            rig.Tick(1f/60); apply(rig, viewport);
            check(Vector2.Distance((Vector2)camera.WorldToScreenPoint(anchor), pointer) < .35f, "Zoom anchor drifted");
        }
        check(rig.RenderZoom < size, "Positive wheel must zoom in");
    }

    foreach (int fps in new[] {30,60,144})
    {
        var a = new ProjectY.Samples.StrategyCameraRig {Zoom=15}; a.Snap();
        var b = new ProjectY.Samples.StrategyCameraRig {Zoom=15}; b.Snap();
        var viewport = new Rect(100,0,1180,720);
        for (int frame=0;frame<fps;frame++)
        { a.PanKeyboard(Vector2.right,720,1f/fps); b.PanKeyboard(Vector2.one,720,1f/fps); }
        apply(a,viewport); float straight = Vector2.Distance((Vector2)camera.WorldToScreenPoint(Vector3.zero),viewport.center);
        apply(b,viewport); float diagonal = Vector2.Distance((Vector2)camera.WorldToScreenPoint(Vector3.zero),viewport.center);
        check(Mathf.Abs(straight - diagonal) < .2f && Mathf.Abs(straight - 396) < .2f, "Keyboard projected speed must match diagonals and frame rates");
        a.Scroll(3,viewport.center,viewport,3,100); for(int frame=0;frame<fps;frame++) a.Tick(1f/fps);
        check(Mathf.Abs(a.RenderZoom - 15*Mathf.Exp(-.36f)) < .002f,"Zoom response must match frame rates");
    }

    var motion = new ProjectY.Samples.StrategyCameraRig {Zoom=15}; motion.Snap();
    motion.Focus = new Vector3(100,3,40); motion.Tick(.02f);
    var interrupted = motion.RenderFocus; motion.Pan(new Vector2(10,0),720); var manual = motion.RenderFocus; motion.Tick(1);
    check(Vector3.Distance(manual,motion.RenderFocus)<.001f && Vector3.Distance(interrupted,manual)<1,"Manual pan must cancel recenter target");
    motion.Scroll(100,new Vector2(500,300),new Rect(0,0,1000,600),3,80); motion.Tick(2);
    check(Mathf.Abs(motion.RenderZoom-3)<.001f,"Near zoom limit");
    motion.Scroll(-100,new Vector2(500,300),new Rect(0,0,1000,600),3,80); motion.Tick(2);
    check(Mathf.Abs(motion.RenderZoom-80)<.001f,"Far zoom limit");
    motion.Rotate(new Vector2(10000,10000)); motion.Tick(2);
    check(motion.RenderPitch>=20 && motion.RenderPitch<=85,"Pitch limit");
    motion.Focus=new Vector3(200,0,200); motion.Scroll(2,Vector2.zero,new Rect(0,0,1000,600),3,80); motion.Stop();
    var frozen=motion.RenderFocus; var frozenSize=motion.RenderZoom; motion.Tick(1);
    check(Vector3.Distance(frozen,motion.RenderFocus)<.001f && Mathf.Abs(frozenSize-motion.RenderZoom)<.001f,"Camera handoff must discard residual movement");
    motion.Focus = new Vector3(-400,20,100); motion.Zoom=25; motion.Snap();
    check(motion.RenderFocus==motion.Focus && motion.RenderZoom==25,"Scene switch must snap without crossing worlds");

    var bounds=new Bounds(new Vector3(12,8,-5),new Vector3(80,15,120));
    foreach(float aspect in new[]{.5625f,1.33333f,1.77778f})
    {
        var rig=new ProjectY.Samples.StrategyCameraRig {Focus=bounds.center,Yaw=-35,Pitch=50};
        rig.Zoom=ProjectY.Samples.StrategyCameraRig.FitSize(bounds,rig.Yaw,rig.Pitch,aspect,8);rig.Snap();apply(rig,new Rect(0,0,720*aspect,720));
        for(int x=-1;x<=1;x+=2)for(int y=-1;y<=1;y+=2)for(int z=-1;z<=1;z+=2)
        {
            var point=camera.WorldToViewportPoint(bounds.center+Vector3.Scale(bounds.extents,new Vector3(x,y,z)));
            check(point.x>0 && point.x<1 && point.y>0 && point.y<1,"Fit must include all corners even in portrait view");
        }
    }
    check(savedScene.isDirty==wasDirty,"Active scene dirty state changed");
    return "PASS strategy camera: "+checks+" checks; projected drag/zoom, cropped/portrait viewport, 30/60/144 FPS, diagonal speed, limits, interruption, scene snap and fit";
}
finally
{
    camera.targetTexture = null; UnityEngine.Object.DestroyImmediate(target);
    UnityEngine.Object.DestroyImmediate(cameraObject);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
