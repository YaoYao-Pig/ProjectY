// Native camp composition pass. Operates only on the dedicated camp scene.
if(EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Camp art pass requires Edit Mode.");
var rootPath="Assets/DynamicAsset/CampPresentation";
foreach(var name in new[]{"Camp_BackdropTree","Camp_Clearing"})
{
    var path=rootPath+"/Models/"+name+".fbx";AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
    var importer=(ModelImporter)AssetImporter.GetAtPath(path);importer.bakeAxisConversion=true;importer.globalScale=1;importer.useFileScale=true;importer.importAnimation=false;importer.animationType=ModelImporterAnimationType.None;
    foreach(var asset in AssetDatabase.LoadAllAssetsAtPath(path))if(asset is Material)
    {
        var material=(Material)asset;var target=AssetDatabase.LoadAssetAtPath<Material>(rootPath+"/Materials/"+material.name+".mat");
        if(target==null)throw new System.InvalidOperationException("Missing camp dressing material "+material.name);
        importer.AddRemap(new AssetImporter.SourceAssetIdentifier(typeof(Material),material.name),target);
    }
    importer.SaveAndReimport();
}
var previous=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
var scene=UnityEditor.SceneManagement.EditorSceneManager.OpenScene(ProjectY.UI.CampSceneView.ScenePath,UnityEditor.SceneManagement.OpenSceneMode.Additive);
try
{
    var stage=scene.GetRootGameObjects()[0].GetComponent<ProjectY.UI.CampStage>();var root=stage.transform;
    var old=new System.Collections.Generic.List<GameObject>();var treePositions=new System.Collections.Generic.List<Vector3>();var treeScales=new System.Collections.Generic.List<float>();
    foreach(Transform child in root)
    {
        var source=PrefabUtility.GetCorrespondingObjectFromSource(child.gameObject);var path=source==null?"":AssetDatabase.GetAssetPath(source);
        if(path.EndsWith("/Tree_Conifer.fbx")||path.EndsWith("/Camp_BackdropTree.fbx"))
        {treePositions.Add(child.localPosition);treeScales.Add(path.EndsWith("/Tree_Conifer.fbx")?child.localScale.x*.56f:child.localScale.x);old.Add(child.gameObject);}
        else if(child.name=="ForestClearing"||child.name=="WornCentralSoil"||child.name=="EdgeStone"||child.name=="GroundPaths"||child.name=="CampClearing")old.Add(child.gameObject);
    }
    foreach(var item in old)UnityEngine.Object.DestroyImmediate(item);
    var clearing=(GameObject)PrefabUtility.InstantiatePrefab(AssetDatabase.LoadAssetAtPath<GameObject>(rootPath+"/Models/Camp_Clearing.fbx"),root);clearing.name="CampClearing";
    for(int i=0;i<treePositions.Count;i++)
    {
        var tree=(GameObject)PrefabUtility.InstantiatePrefab(AssetDatabase.LoadAssetAtPath<GameObject>(rootPath+"/Models/Camp_BackdropTree.fbx"),root);
        tree.transform.localPosition=treePositions[i];tree.transform.localScale=Vector3.one*treeScales[i];tree.transform.localRotation=Quaternion.Euler(0,i*47,0);
    }
    var paths=new GameObject("GroundPaths");paths.transform.SetParent(root,false);
    var material=AssetDatabase.LoadAssetAtPath<Material>(rootPath+"/Materials/Camp_Earth.mat");
    var goals=new[]{new Vector3(-4,0,.6f),new Vector3(3.7f,0,-1.1f),new Vector3(3.5f,0,3.5f),new Vector3(-1.3f,0,-2.8f)};
    for(int k=0;k<goals.Length;k++)
    {
        var start=new Vector3(0,.012f,1.5f);var end=goals[k];end.y=.012f;var direction=(end-start).normalized;var across=new Vector3(-direction.z,0,direction.x);
        var vertices=new Vector3[18];var triangles=new int[48];
        for(int i=0;i<=8;i++){float t=i/8f;var p=Vector3.Lerp(start,end,t)+across*Mathf.Sin(t*Mathf.PI)*.18f;float width=.62f+Mathf.Sin(i*1.7f+k)*.07f;vertices[i*2]=p-across*width;vertices[i*2+1]=p+across*width;}
        for(int i=0;i<8;i++){int n=i*6,v=i*2;triangles[n]=v;triangles[n+1]=v+1;triangles[n+2]=v+2;triangles[n+3]=v+1;triangles[n+4]=v+3;triangles[n+5]=v+2;}
        var mesh=new Mesh{name="CampPath"+k};mesh.vertices=vertices;mesh.triangles=triangles;mesh.RecalculateNormals();
        var path=rootPath+"/Meshes/CampPath"+k+".asset";var saved=AssetDatabase.LoadAssetAtPath<Mesh>(path);
        if(saved==null)AssetDatabase.CreateAsset(mesh,path);else{EditorUtility.CopySerialized(mesh,saved);UnityEngine.Object.DestroyImmediate(mesh);mesh=saved;}
        var node=new GameObject("Footpath"+k,typeof(MeshFilter),typeof(MeshRenderer));node.transform.SetParent(paths.transform,false);node.GetComponent<MeshFilter>().sharedMesh=mesh;node.GetComponent<MeshRenderer>().sharedMaterial=material;
    }
    foreach(var node in root.GetComponentsInChildren<Transform>(true))node.gameObject.layer=30;
    UnityEditor.SceneManagement.EditorSceneManager.SaveScene(scene);
    var settings=new System.Collections.Generic.List<EditorBuildSettingsScene>(EditorBuildSettings.scenes);
    if(settings.Count==1&&settings[0].path==ProjectY.UI.CampSceneView.ScenePath)settings.Insert(0,new EditorBuildSettingsScene("Assets/GameFramework/Samples/Adventure/AdventureDemo.unity",true));
    EditorBuildSettings.scenes=settings.ToArray();AssetDatabase.SaveAssets();
    return "Authored clearing, rooted trees, grass, worn paths and original application entry scene saved.";
}
finally{UnityEditor.SceneManagement.EditorSceneManager.CloseScene(scene,true);if(previous.IsValid())UnityEngine.SceneManagement.SceneManager.SetActiveScene(previous);}
