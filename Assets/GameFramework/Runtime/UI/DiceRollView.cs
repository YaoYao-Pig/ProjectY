using System;
using System.Collections.Generic;
using ProjectY.Rendering;
using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using XLua;
using Object = UnityEngine.Object;

namespace ProjectY.UI
{
    /// <summary>Physics-authored presentation. Receives settled numbers, never rolls game randomness.</summary>
    [LuaCallCSharp]
    public sealed class DiceRollView : MonoBehaviour
    {
        [SerializeField] private DiceCatalog catalog;
        [SerializeField] private RawImage image;
        [SerializeField] private TMP_Text[] labels;
        private const float Step = 1f / 60, Duration = 2.25f;
        private static readonly Vector3 Origin = new Vector3(24000, 24000, 24000);
        private sealed class Toss
        {
            internal DiceCatalog.Die Model;
            internal int Value;
            internal Rigidbody Body;
            internal Transform Visual, Aura;
            internal MeshRenderer AuraRenderer;
            internal LineRenderer Trail;
            internal readonly List<Vector3> Positions = new List<Vector3>(480);
            internal readonly List<Quaternion> Rotations = new List<Quaternion>(480);
            internal readonly List<int> Impacts = new List<int>();
        }
        private readonly List<Toss> dice = new List<Toss>();
        private MaterialPropertyBlock auraBlock;
        private readonly UnityEngine.Rendering.Universal.UniversalRenderPipeline.SingleCameraRequest renderRequest =
            new UnityEngine.Rendering.Universal.UniversalRenderPipeline.SingleCameraRequest();
        private Scene stageScene;
        private PhysicsScene physics;
        private GameObject stage;
        private Camera cameraView;
        private RenderTexture texture;
        private PhysicMaterial contact;
        private Mesh auraMesh;
        private float elapsed;
        private float frameHalfWidth, frameHalfHeight;
        private bool rolling;
        public bool Settled { get; private set; }
        public int DieCount => dice.Count;
        public int SampleCount => dice.Count == 0 ? 0 : dice[0].Positions.Count;

        public void Prepare()
        {
            Release();
            if (catalog == null || image == null || labels == null || labels.Length != 6) throw new InvalidOperationException("Dice view bindings are missing.");
            if (auraBlock == null) auraBlock = new MaterialPropertyBlock();
#if UNITY_EDITOR
            if (!Application.isPlaying) stageScene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
            else
#endif
                stageScene = SceneManager.CreateScene("DiceStage_" + GetInstanceID(), new CreateSceneParameters { localPhysicsMode = LocalPhysicsMode.Physics3D });
            physics = stageScene.GetPhysicsScene();
            if (!physics.IsValid() || physics.Equals(Physics.defaultPhysicsScene)) throw new InvalidOperationException("Dice require an isolated physics scene.");
            stage = new GameObject("DiceStage") { hideFlags = HideFlags.HideAndDontSave };
            SceneManager.MoveGameObjectToScene(stage, stageScene);
            stage.transform.position = Origin;
            contact = new PhysicMaterial("DiceContact") { dynamicFriction = .65f, staticFriction = .7f, bounciness = .35f,
                frictionCombine = PhysicMaterialCombine.Average, bounceCombine = PhysicMaterialCombine.Maximum };
            Box("Floor", new Vector3(0, -.25f, 0), new Vector3(18, .5f, 10));
            Box("Left", new Vector3(-6, 2, 0), new Vector3(.3f, 4, 10));
            Box("Right", new Vector3(6, 2, 0), new Vector3(.3f, 4, 10));
            Box("Back", new Vector3(0, 2, 3), new Vector3(14, 4, .3f));
            Box("Front", new Vector3(0, 2, -3), new Vector3(14, 4, .3f));
            cameraView = Node("DiceCamera").AddComponent<Camera>();
            cameraView.enabled = false; cameraView.orthographic = true; cameraView.orthographicSize = 4.25f;
            cameraView.transform.localPosition = new Vector3(0, 11, -4.8f);
            cameraView.transform.LookAt(Origin + Vector3.up * .35f);
            cameraView.nearClipPlane = .1f; cameraView.farClipPlane = 30; cameraView.cullingMask = 1 << 31;
            cameraView.clearFlags = CameraClearFlags.SolidColor; cameraView.backgroundColor = Color.clear;
            cameraView.scene = stageScene;
#if UNITY_EDITOR
            cameraView.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(stageScene);
#endif
            UrpCameraRendering.ConfigurePreview(cameraView);
            Light("WarmKey", new Vector3(-3, 5, -3), new Color(1, .76f, .43f), 24);
            Light("BlueRim", new Vector3(3, 4, 3), new Color(.27f, .6f, 1), 28);
            Light("SoftFill", new Vector3(0, 6, 0), new Color(.8f, .9f, 1), 20);
            auraMesh = new Mesh { name = "DiceAuraQuad" };
            auraMesh.vertices = new[] { new Vector3(-1, 0, -1), new Vector3(-1, 0, 1), new Vector3(1, 0, 1), new Vector3(1, 0, -1) };
            auraMesh.uv = new[] { Vector2.zero, Vector2.up, Vector2.one, Vector2.right };
            auraMesh.triangles = new[] { 0, 1, 2, 0, 2, 3 }; auraMesh.RecalculateNormals();
            elapsed = 0; Settled = false;
        }

        public void AddDie(string kind, int value, string caption = null)
        {
            if (stage == null || rolling || dice.Count >= 6) throw new InvalidOperationException("Prepare a roll of 1..6 dice first.");
            var model = catalog.Get(kind); model.GetFace(value);
            labels[dice.Count].text = (caption ?? kind) + " · " + (kind=="D100"?value.ToString("D2"):value.ToString());
            var go = Node(kind); var body = go.AddComponent<Rigidbody>();
            body.mass = .08f; body.drag = .65f; body.angularDrag = .65f;
            body.maxAngularVelocity = 35; body.solverIterations = 12; body.solverVelocityIterations = 8;
            var collider = go.AddComponent<MeshCollider>(); collider.sharedMesh = model.Hull; collider.convex = true; collider.sharedMaterial = contact;
            var visual = Node("Model", go.transform); visual.AddComponent<MeshFilter>().sharedMesh = model.Visual;
            visual.AddComponent<MeshRenderer>().sharedMaterials = model.Materials;
            var aura = Node("LandingAura"); aura.AddComponent<MeshFilter>().sharedMesh = auraMesh;
            var auraRenderer = aura.AddComponent<MeshRenderer>(); auraRenderer.sharedMaterial = catalog.Aura;
            var trail = Node("AetherTrail").AddComponent<LineRenderer>();
            trail.sharedMaterial = catalog.Aura; trail.useWorldSpace = true; trail.widthMultiplier = .055f;
            trail.startColor = new Color(.2f,.65f,1,.65f); trail.endColor = Color.clear; trail.numCapVertices = 2;
            trail.enabled = false;
            var trailBlock = new MaterialPropertyBlock(); trailBlock.SetFloat("_Trail",1); trail.SetPropertyBlock(trailBlock);
            dice.Add(new Toss { Model = model, Value = value, Body = body, Visual = visual.transform,
                Aura = aura.transform, AuraRenderer = auraRenderer, Trail = trail });
        }

        public void Throw(int visualSeed)
        {
            if (dice.Count == 0 || rolling) throw new InvalidOperationException("No prepared dice or already rolling.");
            var random = new System.Random(visualSeed);
            for (int i = 0; i < dice.Count; i++)
            {
                var toss = dice[i];
                toss.Body.position = Origin + new Vector3((i - (dice.Count - 1) * .5f) * 1.65f, 2.4f + i * .22f, -.9f);
                toss.Body.rotation = Quaternion.Euler((float)random.NextDouble()*360, (float)random.NextDouble()*360, (float)random.NextDouble()*360);
                toss.Body.velocity = new Vector3((float)(random.NextDouble()-.5)*2, -1, 2.2f+(float)random.NextDouble());
                toss.Body.angularVelocity = new Vector3(8+(float)random.NextDouble()*10, -12+(float)random.NextDouble()*24, 6+(float)random.NextDouble()*10);
            }
            Physics.SyncTransforms();
            // Pre-simulation uses an isolated physics scene. No main-scene time, RNG or collider is touched.
            int quietFrames=0;
            for (int sample = 0; sample < 480; sample++)
            {
                bool asleep = sample > 90;
                bool quiet=sample>90;
                physics.Simulate(Step);
                foreach (var toss in dice)
                {
                    toss.Positions.Add(toss.Body.position); toss.Rotations.Add(toss.Body.rotation);
                    int count=toss.Positions.Count;
                    if(count>1)quiet &= (toss.Positions[count-1]-toss.Positions[count-2]).sqrMagnitude<.000004f &&
                        Quaternion.Angle(toss.Rotations[count-1],toss.Rotations[count-2])<.08f;
                    if(count>2 && toss.Positions[count-2].y-toss.Positions[count-3].y<-.015f && toss.Positions[count-1].y-toss.Positions[count-2].y>.008f)
                        toss.Impacts.Add(sample);
                    asleep &= toss.Body.IsSleeping();
                    if (sample == 240) { toss.Body.drag = 2; toss.Body.angularDrag = 2; }
                }
                quietFrames=quiet?quietFrames+1:0;
                if (asleep || quietFrames>=18) break;
            }
            var min=new Vector2(float.MaxValue,float.MaxValue);var max=new Vector2(float.MinValue,float.MinValue);
            foreach (var toss in dice)
            {
                var landed = TopFace(toss.Model, toss.Body.rotation);
                var target = toss.Model.GetFace(toss.Value);
                // Polyhedron symmetry changes the numbering orientation while preserving the entire physical silhouette.
                toss.Visual.localRotation = landed.Frame * Quaternion.Inverse(target.Frame);
                toss.Body.isKinematic = true;
                foreach(var position in toss.Positions)
                {
                    var local=cameraView.transform.InverseTransformPoint(position);
                    min=Vector2.Min(min,new Vector2(local.x,local.y));max=Vector2.Max(max,new Vector2(local.x,local.y));
                }
            }
            var center=(min+max)*.5f;
            cameraView.transform.position+=cameraView.transform.right*center.x+cameraView.transform.up*center.y;
            frameHalfWidth=(max.x-min.x)*.5f+.9f;frameHalfHeight=(max.y-min.y)*.5f+.9f;
            rolling = true; elapsed = 0; Settled = false; Advance(0);
        }

        public void Advance(float unscaledDelta)
        {
            if (!rolling) return;
            bool finished = elapsed > Duration + 1;
            elapsed += Mathf.Max(0, unscaledDelta);
            if (finished) { Render(false); UpdateLabels(); return; }
            float progress = Mathf.Clamp01(elapsed / Duration);
            Settled = progress >= 1;
            for(int index=0;index<dice.Count;index++)
            {
                var toss=dice[index];
                float frame = progress * (toss.Positions.Count - 1);
                int a = Mathf.FloorToInt(frame), b = Mathf.Min(a + 1, toss.Positions.Count - 1);
                toss.Body.transform.SetPositionAndRotation(Vector3.Lerp(toss.Positions[a], toss.Positions[b], frame-a), Quaternion.Slerp(toss.Rotations[a], toss.Rotations[b], frame-a));
                var local = toss.Body.transform.position - Origin;
                toss.Aura.localPosition = new Vector3(local.x, .01f, local.z);
                float reveal = Settled ? Mathf.Clamp01((elapsed-Duration)*3) : 0;
                float flash=0;
                foreach(int hit in toss.Impacts) if(frame>=hit) flash=Mathf.Max(flash,Mathf.Clamp01(1-(frame-hit)/16));
                toss.Aura.localScale = Vector3.one * (1.05f + reveal*.3f + flash*.45f);
                auraBlock.SetColor("_Color", new Color(.15f,.55f,1, .22f + reveal*.38f + flash*.35f));
                auraBlock.SetFloat("_Ring", Mathf.Max(reveal,flash)); toss.AuraRenderer.SetPropertyBlock(auraBlock);
                toss.Trail.enabled = !Settled && a > 3 && local.y > .8f;
                if (toss.Trail.enabled)
                {
                    toss.Trail.positionCount = 7;
                    for (int j=0;j<7;j++) toss.Trail.SetPosition(j,toss.Positions[Mathf.Max(0,a-j*2)]);
                }
            }
            Render(); UpdateLabels();
        }

        private void UpdateLabels()
        {
            for(int i=0;i<dice.Count;i++)
            {
                labels[i].enabled=Settled;
                var projected=cameraView.WorldToViewportPoint(dice[i].Body.transform.position);
                labels[i].rectTransform.anchoredPosition=new Vector2((projected.x-.5f)*image.rectTransform.rect.width,
                    (projected.y-.5f)*image.rectTransform.rect.height-48);
            }
        }

        public void Reveal() { if (rolling) { elapsed = Duration; Advance(0); } }
        public int VisibleValue(int index)
        {
            var toss = dice[index];
            return TopFace(toss.Model, toss.Body.rotation * toss.Visual.localRotation).Value;
        }
        private static DiceCatalog.Face TopFace(DiceCatalog.Die model, Quaternion rotation)
        {
            DiceCatalog.Face result = null; float dot = -2;
            foreach (var face in model.Faces)
            {
                float next = Vector3.Dot(rotation * face.Axis, Vector3.up);
                if (next > dot) { dot = next; result = face; }
            }
            return result ?? throw new InvalidOperationException("Die has no result faces.");
        }
        private void Render(bool force = true)
        {
            var rect = image.rectTransform.rect;
            float scale = image.canvas == null ? 1 : image.canvas.scaleFactor;
            int width = Mathf.Clamp(Mathf.CeilToInt(rect.width*scale), 64, 1920);
            int height = Mathf.Clamp(Mathf.CeilToInt(rect.height*scale), 64, 1080);
            bool changed=texture == null || texture.width != width || texture.height != height;
            if (changed)
            {
                ReleaseTexture(); texture = new RenderTexture(width, height, 24, RenderTextureFormat.ARGB32) { antiAliasing = 4, name = "DiceOverlay" };
                texture.Create(); cameraView.targetTexture = texture; image.texture = texture;
            }
            if(!force && !changed)return;
            cameraView.aspect = (float)width/height;
            cameraView.orthographicSize = Mathf.Max(frameHalfHeight,frameHalfWidth/cameraView.aspect);
            UrpCameraRendering.Render(cameraView, renderRequest);
        }
        private GameObject Node(string name, Transform parent = null)
        {
            var node = new GameObject(name) { layer = 31, hideFlags = HideFlags.HideAndDontSave };
            node.transform.SetParent(parent == null ? stage.transform : parent, false); return node;
        }
        private void Box(string name, Vector3 center, Vector3 size)
        {
            var go = Node(name); go.transform.localPosition = center;
            var box = go.AddComponent<BoxCollider>(); box.size = size; box.sharedMaterial = contact;
        }
        private void Light(string name, Vector3 position, Color color, float intensity)
        {
            var go = Node(name); go.transform.localPosition = position;
            var light = go.AddComponent<Light>(); light.type = LightType.Point; light.range = 16;
            light.color = color; light.intensity = intensity; light.cullingMask = 1 << 31;
        }
        public void Release()
        {
            rolling = false; Settled = false; dice.Clear(); ReleaseTexture();
            if(labels!=null)foreach(var label in labels)if(label!=null)label.enabled=false;
            if (stage != null) { stage.SetActive(false); DestroyOwned(stage); stage = null; }
            if (stageScene.IsValid() && stageScene.isLoaded)
            {
#if UNITY_EDITOR
                if (!Application.isPlaying) UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(stageScene);
                else
#endif
                    SceneManager.UnloadSceneAsync(stageScene);
            }
            stageScene = default; cameraView = null; DestroyOwned(contact); contact = null; DestroyOwned(auraMesh); auraMesh = null;
        }
        private void ReleaseTexture()
        {
            if (image != null) image.texture = null;
            if (cameraView != null) cameraView.targetTexture = null;
            if (texture != null) { texture.Release(); DestroyOwned(texture); texture = null; }
        }
        private static void DestroyOwned(Object value) { if (value == null) return; if (Application.isPlaying) Destroy(value); else DestroyImmediate(value); }
        private void OnDisable() => Release();
        private void OnDestroy() => Release();
#if UNITY_EDITOR
        [BlackList] public void SetEditorBindings(DiceCatalog value, RawImage target, TMP_Text[] captions) { catalog = value; image = target; labels=captions; }
#endif
    }
}
