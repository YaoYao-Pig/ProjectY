// Unity MCP execute_code method body. Run after MapHudLayout is compiled.
// Targeted PNG import and native Prefab edits only: no Refresh, compile, Play or tests.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling || UnityEditor.EditorApplication.isUpdating)
    throw new System.InvalidOperationException("Map parchment migration requires idle Edit Mode.");

var slices = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Art/UI/MapParchment/sprites.json"));
var sprites = new System.Collections.Generic.Dictionary<string, Sprite>();
foreach (var atlas in slices["atlases"])
{
    var path = (string)atlas["path"];
    if (!path.StartsWith("Assets/DynamicAsset/UI/Skins/MapParchment/", System.StringComparison.Ordinal) || !System.IO.File.Exists(path))
        throw new System.InvalidOperationException("Invalid map atlas path: " + path);
    UnityEditor.AssetDatabase.ImportAsset(path, UnityEditor.ImportAssetOptions.ForceSynchronousImport);
    var importer = UnityEditor.AssetImporter.GetAtPath(path) as UnityEditor.TextureImporter;
    if (importer == null) throw new System.InvalidOperationException("Texture importer missing: " + path);
    importer.textureType = UnityEditor.TextureImporterType.Sprite;
    importer.spriteImportMode = UnityEditor.SpriteImportMode.Multiple;
    importer.spritePixelsPerUnit = 100;
    importer.alphaSource = UnityEditor.TextureImporterAlphaSource.FromInput;
    importer.alphaIsTransparency = true;
    importer.sRGBTexture = true;
    importer.mipmapEnabled = false;
    importer.isReadable = false;
    importer.filterMode = FilterMode.Bilinear;
    importer.wrapMode = TextureWrapMode.Clamp;
    importer.npotScale = UnityEditor.TextureImporterNPOTScale.None;
    importer.textureCompression = UnityEditor.TextureImporterCompression.Uncompressed;
    importer.maxTextureSize = 2048;
    var settings = new UnityEditor.TextureImporterSettings();
    importer.ReadTextureSettings(settings);
    settings.spriteMeshType = SpriteMeshType.FullRect;
    importer.SetTextureSettings(settings);
    var metadata = new System.Collections.Generic.List<UnityEditor.SpriteMetaData>();
    foreach (var entry in atlas["sprites"])
    {
        var rect = entry["rectUnityBottomLeft"];
        var border = entry["borderUnityLeftBottomRightTop"];
        metadata.Add(new UnityEditor.SpriteMetaData {
            name = (string)entry["name"],
            rect = new Rect((float)rect["x"], (float)rect["y"], (float)rect["width"], (float)rect["height"]),
            border = new Vector4((float)border[0], (float)border[1], (float)border[2], (float)border[3]),
            alignment = (int)entry["alignment"], pivot = new Vector2(.5f, .5f)
        });
    }
    importer.spritesheet = metadata.ToArray();
    importer.SaveAndReimport();
    var texture = UnityEditor.AssetDatabase.LoadAssetAtPath<Texture2D>(path);
    if (texture == null || texture.width != (int)atlas["width"] || texture.height != (int)atlas["height"])
        throw new System.InvalidOperationException("Map atlas changed size during import: " + path);
    foreach (var asset in UnityEditor.AssetDatabase.LoadAllAssetsAtPath(path))
    {
        var sprite = asset as Sprite;
        if (sprite != null) sprites.Add(sprite.name, sprite);
    }
    foreach (var entry in metadata)
    {
        Sprite sprite;
        if (!sprites.TryGetValue(entry.name, out sprite) || sprite.rect != entry.rect || sprite.border != entry.border)
            throw new System.InvalidOperationException("Map atlas slice mismatch: " + entry.name);
    }
}
if (sprites.Count != 14) throw new System.InvalidOperationException("Expected fourteen map parchment sprites.");

var fonts = "Assets/DynamicAsset/UI/Fonts/";
var titleFont = UnityEditor.AssetDatabase.LoadAssetAtPath<Font>(fonts + "SourceHanSerifSC-SemiBold.otf");
var bodyFont = UnityEditor.AssetDatabase.LoadAssetAtPath<Font>(fonts + "NotoSansCJKsc-Regular.otf");
if (titleFont == null || bodyFont == null) throw new System.InvalidOperationException("Map HUD fonts are missing.");
var languageTable = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Localization/LuaTxt.json"));
var language = new System.Collections.Generic.Dictionary<string, string>();
foreach (var row in languageTable["rows"]) language.Add((string)row["id"], (string)row["txt"]);
var requiredIds = new[] { "UIWorldMapTitle", "UIWorldMapSubtitle", "UIWorldMapFiltersTitle", "UIWorldMapLegendTitle", "UIWorldMapHint",
    "UIWorldMapSiteTags", "UIWorldMapAvailableMissions", "UIWorldMapActiveMissions", "UIWorldMapReadyMissions", "UIWorldMapPlayerMarker",
    "UIWorldMapRoute", "UIWorldMapClose", "UIWorldMapHome", "UIWorldMapMissions" };
foreach (var id in requiredIds)
    if (!language.ContainsKey(id)) throw new System.InvalidOperationException("Export map HUD LuaTxt key first: " + id);
var manifest = Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText("Art/Localization/ui-text-bindings.json"));
var config = UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
if (config == null) throw new System.InvalidOperationException("PanelConfig is missing.");
var definition = config.Get("MainHud");
definition.Validate(true);
const string sitePath = "Assets/GameFramework/Resources/UI/WorldSiteOverlay.prefab";
if (UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(sitePath) == null)
    throw new System.InvalidOperationException("WorldSiteOverlay prefab is missing.");
var ink = new Color(.224f, .231f, .208f, 1);
var muted = new Color(.39f, .42f, .36f, 1);
System.Action<RectTransform> stretch = rect => {
    rect.anchorMin = Vector2.zero; rect.anchorMax = Vector2.one; rect.pivot = new Vector2(.5f, .5f);
    rect.offsetMin = rect.offsetMax = Vector2.zero; rect.localScale = Vector3.one; rect.localRotation = Quaternion.identity;
};
System.Action<RectTransform, float, float, float, float> box = (rect, x, y, width, height) => {
    rect.anchorMin = rect.anchorMax = rect.pivot = new Vector2(0, 1);
    rect.anchoredPosition = new Vector2(x, -y); rect.sizeDelta = new Vector2(width, height);
    rect.localScale = Vector3.one; rect.localRotation = Quaternion.identity;
};
System.Func<Transform, string, RectTransform> requireNode = (parent, name) => {
    var rect = parent.Find(name) as RectTransform;
    if (rect == null) throw new System.InvalidOperationException("Missing authored map HUD node: " + name);
    return rect;
};
System.Func<Transform, string, RectTransform> node = (parent, name) => {
    var child = parent.Find(name);
    if (child != null) {
        var rect = child as RectTransform;
        if (rect == null) throw new System.InvalidOperationException("Expected RectTransform: " + name);
        return rect;
    }
    var created = (RectTransform)new GameObject(name, typeof(RectTransform)).transform;
    created.gameObject.layer = 5; created.SetParent(parent, false); return created;
};
System.Func<RectTransform, string, bool, float, UnityEngine.UI.Image> paper = (rect, name, raycast, multiplier) => {
    var image = rect.GetComponent<UnityEngine.UI.Image>();
    if (image == null) image = rect.gameObject.AddComponent<UnityEngine.UI.Image>();
    image.enabled = true; image.sprite = sprites[name]; image.overrideSprite = null; image.color = Color.white;
    image.type = UnityEngine.UI.Image.Type.Sliced; image.pixelsPerUnitMultiplier = multiplier;
    image.preserveAspect = false; image.raycastTarget = raycast;
    foreach (var shadow in rect.GetComponents<UnityEngine.UI.Shadow>()) shadow.enabled = false;
    return image;
};
System.Func<RectTransform, string, UnityEngine.UI.Image> icon = (rect, name) => {
    var image = rect.GetComponent<UnityEngine.UI.Image>();
    if (image == null) image = rect.gameObject.AddComponent<UnityEngine.UI.Image>();
    image.enabled = true; image.sprite = sprites[name]; image.overrideSprite = null; image.color = Color.white;
    image.type = UnityEngine.UI.Image.Type.Simple; image.preserveAspect = true; image.raycastTarget = false;
    return image;
};
System.Action<ProjectY.UI.LuaReference, string, Component> bind = (reference, key, target) => {
    if (target == null) throw new System.InvalidOperationException("Cannot bind empty map HUD target: " + key);
    var bindings = new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
    bindings.RemoveAll(value => value.Key == key); bindings.Add(new ProjectY.UI.LuaReference.Entry(key, target));
    reference.SetEditorBindings(bindings.ToArray());
};
System.Action<ProjectY.UI.LuaReference, UnityEngine.UI.Text, string> localize = (reference, label, id) => {
    label.text = language[id];
    var bindings = new System.Collections.Generic.List<ProjectY.UI.LuaReference.LocalizedText>(reference.GetEditorLocalizations());
    bindings.RemoveAll(value => value.Target == label); bindings.Add(new ProjectY.UI.LuaReference.LocalizedText(label, id));
    reference.SetEditorLocalizations(bindings.ToArray());
};
System.Action<UnityEngine.UI.Text, int, bool> typography = (label, size, heading) => {
    label.font = heading ? titleFont : bodyFont; label.fontSize = size; label.fontStyle = FontStyle.Normal;
    label.color = ink; label.raycastTarget = false; label.supportRichText = false;
    label.resizeTextForBestFit = false; label.horizontalOverflow = HorizontalWrapMode.Wrap;
    label.verticalOverflow = VerticalWrapMode.Truncate; label.alignment = TextAnchor.MiddleLeft;
};
System.Func<Transform, string, CanvasGroup> motionGroup = (parent, path) => {
    var rect = requireNode(parent, path); var group = rect.GetComponent<CanvasGroup>();
    if (group == null) throw new System.InvalidOperationException("Motion group missing: " + path);
    return group;
};
System.Action<RectTransform> clearPanel = rect => {
    var image = rect.GetComponent<UnityEngine.UI.Image>(); if (image != null) image.enabled = false;
    foreach (var shadow in rect.GetComponents<UnityEngine.UI.Shadow>()) shadow.enabled = false;
};

var root = UnityEditor.PrefabUtility.LoadPrefabContents(definition.PrefabPath);
GameObject siteRoot = null;
try
{
    siteRoot = UnityEditor.PrefabUtility.LoadPrefabContents(sitePath);
    var reference = root.GetComponent<ProjectY.UI.LuaReference>();
    if (reference == null) throw new System.InvalidOperationException("MainHud LuaReference is missing.");
    var mapReference = reference.GetReference("MapHud");
    var map = (RectTransform)mapReference.transform;
    var view = (ProjectY.UI.MainHudView)reference.Get("HUD");
    var viewFields = new UnityEditor.SerializedObject(view);
    System.Func<string, RectTransform> mainRect = key => {
        var property = viewFields.FindProperty("layout." + key);
        var value = property == null ? null : property.objectReferenceValue as RectTransform;
        if (value == null) throw new System.InvalidOperationException("MainHud layout binding missing: " + key);
        return value;
    };
    // Motion wrappers, clip paths and transition group references remain unchanged.
    var top = requireNode(map, "TopMotion/Top");
    var filters = requireNode(map, "FiltersMotion/Filters");
    var legend = requireNode(map, "LegendMotion/Legend");
    var bottom = requireNode(map, "BottomMotion/Bottom");
    stretch(top); stretch(bottom); clearPanel(top); clearPanel(bottom);
    requireNode(top, "Rule").gameObject.SetActive(false);
    var titleCard = node(top, "TitleCard"); box(titleCard, 16, 16, 210, 76);
    paper(titleCard, "MapParchment_Title", true, 2);
    var title = mapReference.GetText("Title"); title.rectTransform.SetParent(titleCard, false);
    box(title.rectTransform, 16, 5, 178, 42); typography(title, 25, true);
    var subtitle = mapReference.GetText("Subtitle"); subtitle.rectTransform.SetParent(titleCard, false);
    box(subtitle.rectTransform, 17, 49, 176, 21); typography(subtitle, 12, false); subtitle.color = muted;
    localize(reference, title, "UIWorldMapTitle"); localize(mapReference, title, "UIWorldMapTitle");
    localize(reference, subtitle, "UIWorldMapSubtitle"); localize(mapReference, subtitle, "UIWorldMapSubtitle");

    System.Action<string, RectTransform, string, string, float> styleButton = (key, parent, id, spriteName, width) => {
        var control = mapReference.GetButton(key); var rect = (RectTransform)control.transform;
        rect.SetParent(parent, false); box(rect, 0, 0, width, key == "Close" ? 36 : 40);
        control.targetGraphic = paper(rect, "MapParchment_Button", true, 2);
        control.navigation = new UnityEngine.UI.Navigation { mode = UnityEngine.UI.Navigation.Mode.None };
        control.transition = UnityEngine.UI.Selectable.Transition.ColorTint;
        var colors = control.colors; colors.normalColor = Color.white; colors.highlightedColor = new Color(1.04f, 1.04f, 1.01f, 1);
        colors.pressedColor = new Color(.91f, .89f, .82f, 1); colors.selectedColor = Color.white;
        colors.disabledColor = new Color(.78f, .78f, .73f, .7f); colors.colorMultiplier = 1; colors.fadeDuration = .09f; control.colors = colors;
        var picture = node(rect, key + "Icon"); box(picture, 12, key == "Close" ? 9 : 10, 20, 20);
        bind(mapReference, key + "Icon", icon(picture, spriteName));
        var label = mapReference.GetText(key + "Text"); box(label.rectTransform, 38, 0, width - 45, key == "Close" ? 36 : 40);
        typography(label, 15, false); label.alignment = TextAnchor.MiddleCenter;
        localize(reference, label, id); localize(mapReference, label, id);
    };
    styleButton("Close", top, "UIWorldMapClose", "MapParchment_Back", 96);
    var back = (RectTransform)mapReference.GetButton("Close").transform;
    back.anchorMin = back.anchorMax = back.pivot = Vector2.one; back.anchoredPosition = new Vector2(-16, -16);

    box(filters, 16, 110, 208, 316); paper(filters, "MapParchment_Panel", true, 2);
    var filtersTitle = mapReference.GetText("FiltersTitle"); box(filtersTitle.rectTransform, 16, 11, 176, 30); typography(filtersTitle, 18, true);
    var filterKeys = new[] { "SiteTags", "AvailableMissions", "ActiveMissions", "ReadyMissions", "PlayerMarker", "Route" };
    var filterIds = new[] { "UIWorldMapSiteTags", "UIWorldMapAvailableMissions", "UIWorldMapActiveMissions", "UIWorldMapReadyMissions", "UIWorldMapPlayerMarker", "UIWorldMapRoute" };
    var filterSprites = new[] { "MapParchment_Town", "MapParchment_Available", "MapParchment_InProgress", "MapParchment_Ready", "MapParchment_Party", "MapParchment_Route" };
    for (int i = 0; i < filterKeys.Length; i++)
    {
        var key = filterKeys[i]; var toggle = mapReference.GetToggle(key); var rect = (RectTransform)toggle.transform;
        box(rect, 12, 50 + i * 42, 184, 40);
        var background = rect.GetComponent<UnityEngine.UI.Image>();
        if (background == null) throw new System.InvalidOperationException("Filter background missing: " + key);
        background.enabled = true; background.sprite = null; background.overrideSprite = null; background.type = UnityEngine.UI.Image.Type.Simple;
        background.color = new Color(.60f, .51f, .34f, .035f); background.raycastTarget = true; toggle.targetGraphic = background;
        toggle.navigation = new UnityEngine.UI.Navigation { mode = UnityEngine.UI.Navigation.Mode.None };
        var empty = node(rect, "CheckBox"); box(empty, 7, 11, 18, 18); icon(empty, "MapParchment_CheckboxOff"); empty.SetAsFirstSibling();
        var check = requireNode(rect, "Check"); box(check, 7, 11, 18, 18); toggle.graphic = icon(check, "MapParchment_CheckboxOn");
        var category = node(rect, "CategoryIcon"); box(category, 35, 9, 22, 22); bind(mapReference, key + "Icon", icon(category, filterSprites[i]));
        var label = mapReference.GetText(key + "Text"); box(label.rectTransform, 64, 0, 114, 40); typography(label, 14, false);
        localize(reference, label, filterIds[i]); localize(mapReference, label, filterIds[i]);
    }
    localize(reference, filtersTitle, "UIWorldMapFiltersTitle"); localize(mapReference, filtersTitle, "UIWorldMapFiltersTitle");

    box(legend, 0, 0, 150, 190); legend.anchorMin = legend.anchorMax = legend.pivot = Vector2.one;
    legend.anchoredPosition = new Vector2(-16, -152); paper(legend, "MapParchment_Panel", true, 2);
    var legendTitle = mapReference.GetText("LegendTitle"); box(legendTitle.rectTransform, 15, 10, 120, 29); typography(legendTitle, 18, true);
    localize(reference, legendTitle, "UIWorldMapLegendTitle"); localize(mapReference, legendTitle, "UIWorldMapLegendTitle");
    mapReference.GetText("LegendBody").gameObject.SetActive(false);
    for (int i = 0; i < 4; i++)
    {
        var key = "Legend" + filterKeys[i + 1]; var row = node(legend, key); box(row, 12, 46 + i * 33, 126, 28);
        var picture = node(row, "Icon"); box(picture, 0, 3, 22, 22); bind(mapReference, key + "Icon", icon(picture, filterSprites[i + 1]));
        var labelRect = node(row, "Label"); box(labelRect, 31, 0, 95, 28);
        var label = labelRect.GetComponent<UnityEngine.UI.Text>(); if (label == null) label = labelRect.gameObject.AddComponent<UnityEngine.UI.Text>();
        typography(label, 14, false); bind(mapReference, key + "Text", label);
        localize(reference, label, filterIds[i + 1]); localize(mapReference, label, filterIds[i + 1]);
    }

    var helpCard = node(bottom, "HelpCard"); box(helpCard, 0, 0, 340, 38);
    helpCard.anchorMin = helpCard.anchorMax = helpCard.pivot = Vector2.zero; helpCard.anchoredPosition = new Vector2(16, 16);
    paper(helpCard, "MapParchment_Button", true, 2);
    var hint = mapReference.GetText("Hint"); hint.rectTransform.SetParent(helpCard, false);
    box(hint.rectTransform, 13, 0, 314, 38); typography(hint, 13, false); hint.color = muted;
    localize(reference, hint, "UIWorldMapHint"); localize(mapReference, hint, "UIWorldMapHint");
    var actionsCard = node(bottom, "ActionsCard"); box(actionsCard, 0, 0, 276, 40);
    actionsCard.anchorMin = actionsCard.anchorMax = actionsCard.pivot = new Vector2(1, 0); actionsCard.anchoredPosition = new Vector2(-16, 16);
    clearPanel(actionsCard);
    styleButton("Home", actionsCard, "UIWorldMapHome", "MapParchment_Party", 134);
    styleButton("Missions", actionsCard, "UIWorldMapMissions", "MapParchment_Journal", 134);
    mapReference.GetButton("Missions").GetComponent<RectTransform>().anchoredPosition = new Vector2(142, 0);

    var markerReference = mapReference.GetReference("MarkerTemplate"); var marker = (RectTransform)markerReference.Get("Root");
    marker.sizeDelta = new Vector2(86, 26); marker.pivot = new Vector2(.5f, 0); clearPanel(marker);
    var markerIcon = markerReference.GetImage("Icon"); box(markerIcon.rectTransform, 0, 2, 22, 22); icon(markerIcon.rectTransform, "MapParchment_Party");
    var markerKeys = new[] { "AvailableIcon", "ActiveIcon", "ReadyIcon" };
    for (int i = 0; i < markerKeys.Length; i++)
    {
        var picture = node(marker, markerKeys[i]); box(picture, i * 26, 2, 22, 22);
        bind(markerReference, markerKeys[i], icon(picture, filterSprites[i + 1]));
    }
    var count = markerReference.GetText("Label"); typography(count, 12, false); count.text = ""; count.alignment = TextAnchor.UpperRight;
    count.horizontalOverflow = HorizontalWrapMode.Overflow; count.rectTransform.anchorMin = count.rectTransform.anchorMax = count.rectTransform.pivot = Vector2.one;
    count.rectTransform.anchoredPosition = new Vector2(-2, 0); count.rectTransform.sizeDelta = new Vector2(24, 16);
    var countOutline=count.GetComponent<UnityEngine.UI.Outline>();if(countOutline==null)countOutline=count.gameObject.AddComponent<UnityEngine.UI.Outline>();
    countOutline.effectColor=new Color(.97f,.94f,.84f,.9f);countOutline.effectDistance=new Vector2(1,-1);
    var markerFollower = (ProjectY.UI.UIFollower)markerReference.Get("Follower");
    var markerGroup = marker.GetComponent<CanvasGroup>(); if (markerGroup == null) throw new System.InvalidOperationException("Marker visibility group missing.");
    markerFollower.SetEditorBindings(marker, markerGroup);
    var followerFields = new UnityEditor.SerializedObject(markerFollower);
    followerFields.FindProperty("screenOffset").vector2Value = new Vector2(0, 16);
    followerFields.FindProperty("minScale").floatValue = 1; followerFields.FindProperty("maxScale").floatValue = 1;
    followerFields.FindProperty("interactiveChildren").boolValue = false; followerFields.ApplyModifiedPropertiesWithoutUndo();
    marker.gameObject.SetActive(false);

    var mapLayout = map.GetComponent<ProjectY.Samples.MapHudLayout>();
    if (mapLayout == null) mapLayout = map.gameObject.AddComponent<ProjectY.Samples.MapHudLayout>();
    var layoutFields = new UnityEditor.SerializedObject(mapLayout);
    var fieldNames = new[] { "root", "title", "filters", "legend", "help", "actions", "back", "availableSprite", "activeSprite", "readySprite", "partySprite" };
    var fieldValues = new UnityEngine.Object[] { map, titleCard, filters, legend, helpCard, actionsCard, back,
        sprites["MapParchment_Available"], sprites["MapParchment_InProgress"], sprites["MapParchment_Ready"], sprites["MapParchment_Party"] };
    for (int i = 0; i < fieldNames.Length; i++)
    {
        var property = layoutFields.FindProperty(fieldNames[i]);
        if (property == null || fieldValues[i] == null) throw new System.InvalidOperationException("MapHudLayout contract missing: " + fieldNames[i]);
        property.objectReferenceValue = fieldValues[i];
    }
    var worldControls = reference.Get("TimeControls").transform.parent as RectTransform;
    if (worldControls == null || worldControls.name != "WorldControls") throw new System.InvalidOperationException("WorldControls binding changed.");
    var mainCards = new[] { mainRect("Party"), mainRect("Header"), (RectTransform)reference.Get("CharacterSkills"), mainRect("Journal"),
        mainRect("Rail"), mainRect("Menu"), mainRect("Clock"), worldControls };
    var mainGroups = new System.Collections.Generic.List<CanvasGroup>();
    foreach (var card in mainCards)
    {
        if (card.parent == null || card.parent.name != card.name + "Motion") throw new System.InvalidOperationException("Main HUD motion parent changed: " + card.name);
        var group = card.parent.GetComponent<CanvasGroup>(); if (group == null) throw new System.InvalidOperationException("Main HUD motion group missing: " + card.name);
        mainGroups.Add(group);
    }
    var mapCards = new[] { titleCard, filters, legend, helpCard, actionsCard, back };
    var mapGroups = new[] { motionGroup(map, "TopMotion"), motionGroup(map, "FiltersMotion"), motionGroup(map, "LegendMotion"),
        motionGroup(map, "BottomMotion"), motionGroup(map, "BottomMotion"), motionGroup(map, "TopMotion") };
    System.Action<string, RectTransform[], CanvasGroup[]> obstacles = (name, cards, groups) => {
        var list = layoutFields.FindProperty(name);
        if (list == null || !list.isArray || cards.Length != groups.Length) throw new System.InvalidOperationException("Map obstacle contract changed: " + name);
        list.arraySize = cards.Length;
        for (int i = 0; i < cards.Length; i++) {
            var item = list.GetArrayElementAtIndex(i); var rectField = item.FindPropertyRelative("Rect"); var groupField = item.FindPropertyRelative("Group");
            if (rectField == null || groupField == null || cards[i] == null || groups[i] == null) throw new System.InvalidOperationException("Empty map obstacle: " + name);
            rectField.objectReferenceValue = cards[i]; groupField.objectReferenceValue = groups[i];
        }
    };
    obstacles("mainObstacles", mainCards, mainGroups.ToArray()); obstacles("mapObstacles", mapCards, mapGroups);
    layoutFields.ApplyModifiedPropertiesWithoutUndo(); bind(mapReference, "Layout", mapLayout);
    // Keep existing font overrides, but prevent MainHud.Prepare from replacing serif headings.
    var labels = viewFields.FindProperty("layout.Labels"); var keptLabels = new System.Collections.Generic.List<UnityEngine.UI.Text>();
    for (int i = 0; i < labels.arraySize; i++) {
        var label = labels.GetArrayElementAtIndex(i).objectReferenceValue as UnityEngine.UI.Text;
        if (label == null) throw new System.InvalidOperationException("MainHud font override contains an empty label.");
        if (label != title && label != filtersTitle && label != legendTitle) keptLabels.Add(label);
    }
    foreach (var label in map.GetComponentsInChildren<UnityEngine.UI.Text>(true))
        if (label != title && label != filtersTitle && label != legendTitle && !keptLabels.Contains(label)) keptLabels.Add(label);
    labels.arraySize = keptLabels.Count;
    for (int i = 0; i < keptLabels.Count; i++) labels.GetArrayElementAtIndex(i).objectReferenceValue = keptLabels[i];
    viewFields.ApplyModifiedPropertiesWithoutUndo();

    var siteReference = siteRoot.GetComponent<ProjectY.UI.LuaReference>();
    if (siteReference == null) throw new System.InvalidOperationException("WorldSiteOverlay LuaReference missing.");
    var tagReference = siteReference.GetReference("TagTemplate"); var tag = (RectTransform)tagReference.Get("Root");
    tag.sizeDelta = new Vector2(tag.sizeDelta.x, 24); paper(tag, "MapParchment_Tag", false, 4);
    foreach(var oldShadow in tag.GetComponentsInChildren<UnityEngine.UI.Shadow>(true))UnityEngine.Object.DestroyImmediate(oldShadow);
    var tagLabel = tagReference.GetText("Label"); typography(tagLabel, 14, false); tagLabel.alignment = TextAnchor.MiddleCenter;
    tagLabel.horizontalOverflow = HorizontalWrapMode.Overflow; stretch(tagLabel.rectTransform);
    tagLabel.rectTransform.offsetMin = new Vector2(10, 1); tagLabel.rectTransform.offsetMax = new Vector2(-10, -1);
    var tagFollower = (ProjectY.UI.UIFollower)tagReference.Get("Follower");
    var tagGroup = tag.GetComponent<CanvasGroup>(); if (tagGroup == null) throw new System.InvalidOperationException("Site tag visibility group missing.");
    tagFollower.SetEditorBindings(tag, tagGroup);
    var tagFields = new UnityEditor.SerializedObject(tagFollower);
    tagFields.FindProperty("screenOffset").vector2Value = new Vector2(0, -26);
    tagFields.FindProperty("minScale").floatValue = 1; tagFields.FindProperty("maxScale").floatValue = 1;
    tagFields.ApplyModifiedPropertiesWithoutUndo(); tag.gameObject.SetActive(false);

    foreach (var nested in root.GetComponentsInChildren<ProjectY.UI.LuaReference>(true)) nested.ValidateBindings();
    siteReference.ValidateBindings(); tagReference.ValidateBindings();
    foreach (var key in filterKeys) mapReference.GetToggle(key);
    foreach (var key in new[] { "Close", "Home", "Missions" }) mapReference.GetButton(key);
    foreach (var key in markerKeys) {
        var image = markerReference.GetImage(key); if (image.sprite == null) throw new System.InvalidOperationException("Marker icon missing: " + key);
    }
    if (mapReference.Get("Layout") != mapLayout || tagReference.GetImage("Background").sprite != sprites["MapParchment_Tag"])
        throw new System.InvalidOperationException("Map layout or site tag binding was not retained.");
    // Rebuild only MainHud's manifest rows because title/action text changed parent paths.
    var stale = new System.Collections.Generic.List<Newtonsoft.Json.Linq.JToken>();
    foreach (var entry in manifest) if ((string)entry["prefab"] == definition.PrefabPath) stale.Add(entry);
    foreach (var entry in stale) entry.Remove();
    foreach (var binding in reference.GetEditorLocalizations())
    {
        if (binding.Target == null || !binding.Target.transform.IsChildOf(root.transform) || !language.ContainsKey(binding.Id))
            throw new System.InvalidOperationException("Invalid MainHud localization binding: " + binding.Id);
        var legacy = binding.Target as UnityEngine.UI.Text; var tmp = binding.Target as TMPro.TMP_Text;
        if (legacy == null && tmp == null) throw new System.InvalidOperationException("Unsupported MainHud localization target: " + binding.Id);
        manifest.Add(new Newtonsoft.Json.Linq.JObject {
            ["prefab"] = definition.PrefabPath,
            ["node"] = UnityEditor.AnimationUtility.CalculateTransformPath(binding.Target.transform, root.transform),
            ["type"] = legacy != null ? "Text" : binding.Target.GetType().Name,
            ["text"] = legacy != null ? legacy.text : tmp.text, ["id"] = binding.Id
        });
    }
    bool savedMain, savedSites;
    UnityEditor.PrefabUtility.SaveAsPrefabAsset(root, definition.PrefabPath, out savedMain);
    UnityEditor.PrefabUtility.SaveAsPrefabAsset(siteRoot, sitePath, out savedSites);
    if (!savedMain || !savedSites) throw new System.InvalidOperationException("Map parchment prefab save failed.");
    ProjectY.Editor.LuaViewHints.Register(typeof(ProjectY.Samples.MapHudLayout), "CS.ProjectY.Samples.MapHudLayout");
    ProjectY.Editor.LuaViewHints.Export(reference, definition.ViewType);
    ProjectY.Editor.LuaViewHints.Export(mapReference, "WorldMapHudWidgetView");
    ProjectY.Editor.LuaViewHints.Export(markerReference, "WorldMapMarkerWidgetView");
    ProjectY.Editor.LuaViewHints.Export(siteReference, "WorldSiteOverlayView");
    ProjectY.Editor.LuaViewHints.Export(tagReference, "WorldSiteTagView");
    System.IO.File.WriteAllText("Art/Localization/ui-text-bindings.json", manifest.ToString(Newtonsoft.Json.Formatting.Indented) + "\n", new System.Text.UTF8Encoding(false));
}
finally
{
    if (siteRoot != null) UnityEditor.PrefabUtility.UnloadPrefabContents(siteRoot);
    UnityEditor.PrefabUtility.UnloadPrefabContents(root);
}
return "Imported fourteen map parchment sprites; saved MainHud/MapHud and WorldSiteOverlay, six map/eight main obstacles, icon bindings, localization manifest and Lua view hints. Existing Motion wrappers and animation clips retained. No compile/Refresh/Play/test operation.";
