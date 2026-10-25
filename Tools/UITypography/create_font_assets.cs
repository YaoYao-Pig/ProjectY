// Run as a Unity MCP execute_code method body in the existing idle Editor.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling||UnityEditor.EditorApplication.isUpdating)
    throw new System.InvalidOperationException("Typography requires idle Edit Mode");
var folder="Assets/DynamicAsset/UI/Fonts/";
var sources=new[]{"SourceHanSerifSC-SemiBold.otf","LXGWWenKai-Regular.ttf"};
foreach(var file in sources.Concat(new[]{"SourceHanSerif-LICENSE.txt","LXGWWenKai-OFL.txt"}))
    UnityEditor.AssetDatabase.ImportAsset(folder+file,UnityEditor.ImportAssetOptions.ForceSynchronousImport);
var fallback=UnityEditor.AssetDatabase.LoadAssetAtPath<TMPro.TMP_FontAsset>(folder+"NotoSansCJKsc.asset");
if(fallback==null)throw new System.InvalidOperationException("Existing Noto fallback is missing");
var report=new System.Collections.Generic.List<string>();
foreach(var source in sources)
{
    var name=System.IO.Path.GetFileNameWithoutExtension(source);
    var font=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Font>(folder+source);
    if(font==null)throw new System.InvalidOperationException("Font import failed: "+source);
    var path=folder+name+".asset";
    var asset=UnityEditor.AssetDatabase.LoadAssetAtPath<TMPro.TMP_FontAsset>(path);
    if(asset==null)
    {
        asset=TMPro.TMP_FontAsset.CreateFontAsset(font,64,6,UnityEngine.TextCore.LowLevel.GlyphRenderMode.SDFAA,2048,2048,TMPro.AtlasPopulationMode.Dynamic,true);
        if(asset==null)throw new System.InvalidOperationException("TMP font creation failed: "+source);
        asset.name=name;
        asset.fallbackFontAssetTable=new System.Collections.Generic.List<TMPro.TMP_FontAsset>{fallback};
        asset.TryAddCharacters(" 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+-/%.,:;!?()[]");
        UnityEditor.AssetDatabase.CreateAsset(asset,path);
        UnityEditor.AssetDatabase.AddObjectToAsset(asset.material,asset);
        foreach(var texture in asset.atlasTextures)UnityEditor.AssetDatabase.AddObjectToAsset(texture,asset);
        UnityEditor.EditorUtility.SetDirty(asset);
        UnityEditor.AssetDatabase.SaveAssetIfDirty(asset);
    }
    if(asset.sourceFontFile!=font||asset.atlasPopulationMode!=TMPro.AtlasPopulationMode.Dynamic||!asset.isMultiAtlasTexturesEnabled||!asset.fallbackFontAssetTable.Contains(fallback))
        throw new System.InvalidOperationException("Unexpected TMP font configuration: "+path);
    report.Add(path);
}
return string.Join("\n",report.ToArray());
