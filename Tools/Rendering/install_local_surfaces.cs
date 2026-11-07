// Unity MCP method body. Creates the missing local look asset through AssetDatabase; preserves existing tuning.
const string path = "Assets/GameFramework/Resources/Rendering/MapAreaPresentation.asset";
var existing = UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Samples.MapAreaPresentationSettings>(path);
if (existing != null) return new { path, existing = true, materials = existing.materials.Length, lights = existing.lights.Length };
var settings = ScriptableObject.CreateInstance<ProjectY.Samples.MapAreaPresentationSettings>();
settings.interiorAmbientScale=1.15f; settings.interiorSunScale=.35f;
settings.undergroundAmbient=new Color(.48f,.55f,.65f); settings.undergroundSunIntensity=.22f;
var details = new List<ProjectY.Samples.MapAreaPresentationSettings.MaterialDetail>();
Action<string,string[],Vector4,float> add = (folder,names,pattern,relief) => {
    foreach (var name in names)
    {
        var material = UnityEditor.AssetDatabase.LoadAssetAtPath<Material>(folder + "/" + name + ".mat");
        if (material == null) throw new System.Exception("Missing authored surface material: " + folder + "/" + name);
        details.Add(new ProjectY.Samples.MapAreaPresentationSettings.MaterialDetail { material = material, pattern = pattern, relief = relief });
    }
};
var timber = new Vector4(5,.30f,.18f,.035f);
var stone = new Vector4(9,.85f,.18f,.035f);
var rock = new Vector4(6,1.2f,.18f,.03f);
add("Assets/DynamicAsset/MapLowPoly/Materials",new [] {"M_MapLP_Timber","M_MapLP_TimberLight","M_MapLP_Gable"},timber,.012f);
add("Assets/DynamicAsset/MapLowPoly/Materials",new [] {"M_MapLP_Stone"},stone,.026f);
add("Assets/DynamicAsset/MapLowPoly/Materials",new [] {"M_MapLP_Rock","M_MapLP_RockDark","M_MapLP_RockLight"},rock,.07f);
add("Assets/DynamicAsset/MapLowPoly/Materials",new [] {"M_MapLP_Plaster","M_MapLP_PlasterShade"},new Vector4(3,.8f,.06f,0),.012f);
add("Assets/DynamicAsset/TownInteriorLowPoly/Materials",new [] {"M_MapLP_InteriorWood"},timber,.012f);
add("Assets/DynamicAsset/TownInteriorLowPoly/Materials",new [] {"M_MapLP_InteriorBrick"},new Vector4(9,.55f,.18f,.035f),.026f);
add("Assets/DynamicAsset/TownInteriorLowPoly/Materials",new [] {"M_MapLP_InteriorSlate"},new Vector4(1,.8f,.21f,.04f),.035f);
add("Assets/DynamicAsset/TownExpansionLowPoly/Materials",new [] {"M_MapLP_ChapelStone"},stone,.026f);
add("Assets/DynamicAsset/AssetExpansion202610/Mine/Materials",new [] {"Mine_Timber","Mine_TimberEnd","Mine_Plank"},timber,.012f);
add("Assets/DynamicAsset/AssetExpansion202610/Mine/Materials",new [] {"Mine_Stone","Mine_StoneDark","Mine_StoneLight"},rock,.07f);
foreach (var folder in new [] {"Shipwreck", "ShipwreckV2"})
    add("Assets/DynamicAsset/AssetExpansion202610/"+folder+"/Materials",new [] {"M_MapLP_SWWood","M_MapLP_SWEnd","M_MapLP_SWDeck","M_MapLP_SWPlank"},timber,.012f);
add("Assets/DynamicAsset/AssetExpansion202610/ShipwreckProps/Materials",new [] {"M_MapLP_SPWood","M_MapLP_SPEnd"},timber,.012f);
add("Assets/DynamicAsset/AssetExpansion202610/Dungeon/Materials",new [] {"M_MapLP_Timber","M_MapLP_TimberLight"},timber,.012f);
add("Assets/DynamicAsset/AssetExpansion202610/Dungeon/Materials",new [] {"M_MapLP_Stone"},stone,.026f);
add("Assets/DynamicAsset/AssetExpansion202610/Dungeon/Materials",new [] {"M_MapLP_Rock","M_MapLP_RockDark","M_MapLP_RockLight"},rock,.06f);
settings.materials = details.ToArray();
var fixture = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/AssetExpansion202610/ShipwreckProps/Prefabs/SWP_CabinLantern.prefab");
if (fixture == null) throw new System.Exception("Missing lantern fixture");
settings.lights = new [] {
    new ProjectY.Samples.MapAreaPresentationSettings.PropLight { assetId=25, position=new Vector3(0,1.96f,0), intensity=8, range=13, emissionSlots=new [] {3,4}, emission=3 },
    new ProjectY.Samples.MapAreaPresentationSettings.PropLight { assetId=45, position=new Vector3(.55f,2.43f,-.22f), intensity=4, range=9, emissionSlots=new [] {2} },
    new ProjectY.Samples.MapAreaPresentationSettings.PropLight { assetId=104, position=new Vector3(-.66f,2.73f,0), intensity=5, range=11, emissionSlots=new [] {3} },
    new ProjectY.Samples.MapAreaPresentationSettings.PropLight { assetId=66, position=new Vector3(-6.5f,.85f,-1.07f), intensity=10, range=14, emissionSlots=new [] {5}, emission=2 },
    new ProjectY.Samples.MapAreaPresentationSettings.PropLight { assetId=64, position=new Vector3(3.2f,1.1f,2.6f), intensity=6, range=13, fixture=fixture, fixtureScale=1.2f },
    new ProjectY.Samples.MapAreaPresentationSettings.PropLight { assetId=901, position=new Vector3(1.6f,2.05f,.48f), intensity=5, range=11, fixture=fixture, fixtureScale=.9f },
    new ProjectY.Samples.MapAreaPresentationSettings.PropLight { assetId=905, position=new Vector3(-.8f,1.01f,.1f), intensity=4, range=9, fixture=fixture, fixtureScale=.9f },
    new ProjectY.Samples.MapAreaPresentationSettings.PropLight { assetId=835, position=new Vector3(0,.48f,0), intensity=3, range=7, emissionSlots=new [] {1} }
};
UnityEditor.AssetDatabase.CreateAsset(settings,path);
UnityEditor.AssetDatabase.SaveAssetIfDirty(settings);
return new { path, materials = settings.materials.Length, lights = settings.lights.Length };
