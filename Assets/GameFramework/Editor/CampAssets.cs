using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ProjectY.UI;
using ProjectY.Samples;
using TMPro;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.Rendering.Universal;
using UnityEngine.UI;
using Object=UnityEngine.Object;

namespace ProjectY.Editor
{
    /// <summary>Native authoring of the camp scene, imported models and explicitly bound UI.</summary>
    public static partial class CampAssets
    {
        private const string Root="Assets/DynamicAsset/CampPresentation";
        private static readonly Dictionary<string,Material> materials=new Dictionary<string,Material>();
        private static readonly Color Ink=new Color(.075f,.09f,.078f),Gold=new Color(.85f,.73f,.49f),Paper=new Color(.91f,.88f,.78f),Muted=new Color(.64f,.68f,.59f);
        private static void Folder(string path)
        {
            path=path.Replace('\\','/');if(AssetDatabase.IsValidFolder(path))return;
            string parent=Path.GetDirectoryName(path).Replace('\\','/');Folder(parent);AssetDatabase.CreateFolder(parent,Path.GetFileName(path));
        }
        [MenuItem("Project Y/营地/同步场景与界面")]
        public static void Sync()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Camp authoring requires idle Edit Mode.");
            Folder(Root+"/Materials");Folder(Root+"/Scenes");Folder(Root+"/Meshes");ImportModels();BuildScene();BuildPanel();AssetDatabase.SaveAssets();
            Debug.Log("Camp scene, thirteen model variants, UI bindings and localization saved.");
        }
        private static Material Material(string name,string hex)
        {
            var path=Root+"/Materials/"+name+".mat";var value=AssetDatabase.LoadAssetAtPath<Material>(path);
            if(value==null){value=new Material(Shader.Find("Universal Render Pipeline/Lit"));AssetDatabase.CreateAsset(value,path);}
            if(!ColorUtility.TryParseHtmlString("#"+hex,out var color))throw new InvalidOperationException("Invalid camp palette.");
            value.SetColor("_BaseColor",color);value.SetFloat("_Smoothness",.15f);value.SetFloat("_Metallic",name.Contains("Iron")||name.Contains("Steel")||name.Contains("Brass")?.28f:0);
            if(name.EndsWith("Ember")||name.EndsWith("Flame")){value.EnableKeyword("_EMISSION");value.SetColor("_EmissionColor",color*1.6f);}
            EditorUtility.SetDirty(value);return value;
        }
        private static void ImportModels()
        {
            materials.Clear();
            string json=File.ReadAllText("Art/CampPresentation/Integration/kit-manifest.json");
            foreach(System.Text.RegularExpressions.Match match in System.Text.RegularExpressions.Regex.Matches(json,"\"([A-Za-z]+)\": \"([0-9a-f]{6})\""))
                materials.Add("Camp_"+match.Groups[1].Value,Material("Camp_"+match.Groups[1].Value,match.Groups[2].Value));
            if(materials.Count<20)throw new InvalidOperationException("Camp material manifest is incomplete.");
            foreach(string file in Directory.GetFiles(Root+"/Models","*.fbx"))
            {
                string path=file.Replace('\\','/');AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
                var importer=(ModelImporter)AssetImporter.GetAtPath(path);importer.globalScale=1;importer.useFileScale=true;importer.bakeAxisConversion=true;
                importer.importAnimation=false;importer.animationType=ModelImporterAnimationType.None;importer.isReadable=false;
                foreach(var source in AssetDatabase.LoadAllAssetsAtPath(path).OfType<Material>())
                {
                    if(!materials.TryGetValue(source.name,out var target))throw new InvalidOperationException("Missing camp material: "+source.name);
                    importer.AddRemap(new AssetImporter.SourceAssetIdentifier(typeof(Material),source.name),target);
                }
                importer.SaveAndReimport();
            }
        }
        private static GameObject Model(string family,int level) => AssetDatabase.LoadAssetAtPath<GameObject>(Root+"/Models/Camp_"+family+"_L"+level+".fbx")??throw new InvalidOperationException("Missing camp model.");
        private static GameObject Instance(GameObject prefab,Transform parent,Vector3 position,float yaw=0,float scale=1)
        {
            var go=(GameObject)PrefabUtility.InstantiatePrefab(prefab,parent);go.transform.localPosition=position;go.transform.localRotation=Quaternion.Euler(0,yaw,0);go.transform.localScale=Vector3.one*scale;return go;
        }
        private static GameObject Primitive(string name,PrimitiveType type,Transform parent,Vector3 position,Vector3 scale,Material material)
        {
            var go=GameObject.CreatePrimitive(type);go.name=name;go.transform.SetParent(parent,false);go.transform.localPosition=position;go.transform.localScale=scale;
            go.GetComponent<Renderer>().sharedMaterial=material;Object.DestroyImmediate(go.GetComponent<Collider>());return go;
        }
        private static void BuildScene()
        {
            var previous=SceneManager.GetActiveScene();var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,NewSceneMode.Additive);
            try
            {
                var root=new GameObject("CampPresentation");SceneManager.MoveGameObjectToScene(root,scene);var stage=root.AddComponent<CampStage>();
                CreateGround(root.transform);
                var camera=new GameObject("CampCamera").AddComponent<Camera>();camera.transform.SetParent(root.transform,false);
                camera.transform.localPosition=new Vector3(12,12,18);camera.transform.LookAt(new Vector3(0,.8f,0));camera.orthographic=true;camera.orthographicSize=7.1f;
                camera.nearClipPlane=.1f;camera.farClipPlane=70;camera.cullingMask=1<<30;camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=Color.clear;camera.enabled=false;
                ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);camera.GetUniversalAdditionalCameraData().renderShadows=true;stage.Camera=camera;
                AddLight(root.transform,"WarmKey",LightType.Directional,new Vector3(45,-35,0),new Color(1,.86f,.65f),1.65f);
                AddLight(root.transform,"CoolFill",LightType.Directional,new Vector3(25,145,0),new Color(.59f,.72f,.78f),.55f);
                stage.FireLight=AddLight(root.transform,"HearthLight",LightType.Point,Vector3.zero,new Color(1,.47f,.16f),1.8f);stage.FireLight.transform.localPosition=new Vector3(0,1.1f,1.4f);stage.FireLight.range=5;
                string[] families={"Workbench","Forge","Warehouse","Medical"};int[] ids={1,4,3,2};
                Vector3[] places={new Vector3(-4,0,0),new Vector3(3.8f,0,-1.9f),new Vector3(4.1f,0,3.5f),new Vector3(-1.3f,0,-4)};
                float[] angles={10,-12,-25,8};stage.Facilities=new CampStage.Facility[4];
                for(int i=0;i<4;i++)
                {
                    var group=new GameObject(families[i]);group.transform.SetParent(root.transform,false);group.transform.localPosition=places[i];group.transform.localRotation=Quaternion.Euler(0,angles[i],0);
                    var variants=new GameObject[3];for(int level=0;level<3;level++){variants[level]=Instance(Model(families[i],level),group.transform,Vector3.zero);variants[level].SetActive(level==0);}
                    var anchor=new GameObject("LabelAnchor").transform;anchor.SetParent(group.transform,false);anchor.localPosition=new Vector3(0,i==3?2.7f:2.2f,.15f);
                    var hit=group.AddComponent<BoxCollider>();hit.center=new Vector3(0,1,0);hit.size=new Vector3(i==3?4:3.8f,2.8f,3.2f);
                    var halo=new GameObject("SelectionRing");halo.transform.SetParent(group.transform,false);var line=halo.AddComponent<LineRenderer>();line.useWorldSpace=false;line.loop=true;line.widthMultiplier=.035f;line.positionCount=48;
                    line.sharedMaterial=materials["Camp_Brass"];for(int n=0;n<48;n++){float a=n*2*Mathf.PI/48;line.SetPosition(n,new Vector3(Mathf.Cos(a)*2,.025f,Mathf.Sin(a)*1.5f));}halo.SetActive(false);
                    stage.Facilities[i]=new CampStage.Facility{Id=ids[i],Levels=variants,LabelAnchor=anchor,HitVolume=hit,Hover=halo};
                }
                Instance(AssetDatabase.LoadAssetAtPath<GameObject>(Root+"/Models/Camp_Firepit.fbx"),root.transform,new Vector3(0,.02f,1.5f));
                var tree=AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/MapLowPoly/Models/Tree_Conifer.fbx");
                if(tree==null)throw new InvalidOperationException("Existing camp backdrop tree is missing.");
                Vector3[] trees={new Vector3(-7,0,-2),new Vector3(-5.5f,0,-5.5f),new Vector3(2.8f,0,-6),new Vector3(6.7f,0,-3.8f),new Vector3(7.7f,0,.3f),new Vector3(-7.5f,0,2.7f)};
                for(int i=0;i<trees.Length;i++)Instance(tree,root.transform,trees[i],i*47,1.3f+i%3*.2f);
                var random=new System.Random(271026);
                for(int i=0;i<38;i++)
                {
                    float a=(float)random.NextDouble()*Mathf.PI*2,r=6+(float)random.NextDouble()*2;
                    var scale=new Vector3(.16f+(float)random.NextDouble()*.24f,.1f+(float)random.NextDouble()*.16f,.17f+(float)random.NextDouble()*.21f);
                    Primitive("EdgeStone",PrimitiveType.Sphere,root.transform,new Vector3(Mathf.Cos(a)*r,.035f,Mathf.Sin(a)*r*.7f),scale,materials["Camp_Stone"]);
                }
                Vector3[] party={new Vector3(-1.7f,0,2.7f),new Vector3(1.2f,0,2.2f),new Vector3(-3.3f,0,1.2f),new Vector3(2.1f,0,-1),new Vector3(-.6f,0,-2.5f),new Vector3(3,0,4.1f)};
                stage.PartyAnchors=new Transform[party.Length];for(int i=0;i<party.Length;i++){var a=new GameObject("PartyPose"+i).transform;a.SetParent(root.transform,false);a.localPosition=party[i];a.localRotation=Quaternion.Euler(0,new[]{70f,-50f,155f,65f,175f,-110f}[i],0);stage.PartyAnchors[i]=a;}
                foreach(var node in root.GetComponentsInChildren<Transform>(true))node.gameObject.layer=30;
                EditorSceneManager.SaveScene(scene,CampSceneView.ScenePath);
                var scenes=EditorBuildSettings.scenes.ToList();var entry=scenes.Find(s=>s.path==CampSceneView.ScenePath);
                if(entry==null)scenes.Add(new EditorBuildSettingsScene(CampSceneView.ScenePath,true));else entry.enabled=true;EditorBuildSettings.scenes=scenes.ToArray();
            }
            finally{EditorSceneManager.CloseScene(scene,true);if(previous.IsValid())SceneManager.SetActiveScene(previous);}
        }
        private static Light AddLight(Transform parent,string name,LightType type,Vector3 angles,Color color,float intensity)
        {var light=new GameObject(name).AddComponent<Light>();light.transform.SetParent(parent,false);light.type=type;light.transform.localRotation=Quaternion.Euler(angles);light.color=color;light.intensity=intensity;light.cullingMask=1<<30;light.shadows=type==LightType.Directional?LightShadows.Soft:LightShadows.None;return light;}
        private static void CreateGround(Transform parent)
        {
            var vertices=new List<Vector3>{new Vector3(0,0,0)};var triangles=new List<int>();const int sides=48;
            for(int i=0;i<sides;i++){float a=i*Mathf.PI*2/sides,r=1+.04f*Mathf.Sin(i*2.1f);vertices.Add(new Vector3(Mathf.Cos(a)*8.8f*r,0,Mathf.Sin(a)*6.6f*r));}
            for(int i=0;i<sides;i++){triangles.Add(0);triangles.Add(1+(i+1)%sides);triangles.Add(1+i);}
            var mesh=new Mesh{name="CampGround"};mesh.SetVertices(vertices);mesh.SetTriangles(triangles,0);mesh.RecalculateNormals();
            var meshPath=Root+"/Meshes/CampGround.asset";var previous=AssetDatabase.LoadAssetAtPath<Mesh>(meshPath);
            if(previous==null)AssetDatabase.CreateAsset(mesh,meshPath);else{EditorUtility.CopySerialized(mesh,previous);Object.DestroyImmediate(mesh);mesh=previous;}
            var ground=new GameObject("ForestClearing",typeof(MeshFilter),typeof(MeshRenderer));ground.transform.SetParent(parent,false);ground.GetComponent<MeshFilter>().sharedMesh=mesh;ground.GetComponent<MeshRenderer>().sharedMaterial=materials["Camp_Grass"];
            Primitive("WornCentralSoil",PrimitiveType.Cylinder,parent,new Vector3(0,.006f,.3f),new Vector3(9,.008f,7),materials["Camp_Earth"]);
        }
    }
}
