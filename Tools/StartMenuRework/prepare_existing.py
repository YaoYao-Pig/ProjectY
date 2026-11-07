from pathlib import Path
import hashlib, json

root=Path(__file__).resolve().parents[2]
stage=root/'Tools/StartMenuRework/Existing';stage.mkdir(exist_ok=True)
records=[]
def edit(relative, changes):
    source=root/relative;original=source.read_bytes();text=original.decode('utf-8-sig')
    for old,new in changes:
        assert text.count(old)==1,(relative,old,text.count(old))
        text=text.replace(old,new)
    target=stage/source.name;target.write_text(text,encoding='utf-8')
    records.append({'path':relative,'staged':str(target.relative_to(root)),'before':hashlib.sha256(original).hexdigest()})

edit('Assets/GameFramework/Runtime/Data/CharacterSaveState.cs',[
    ('public string savedAt, worldName;', 'public string savedAt, worldName, createdAt;')])
edit('Assets/GameFramework/Runtime/Data/CharacterSaveService.cs',[
    ('internal string WorldName;', 'internal string WorldName, CreatedAt;'),
    ('private string currentWorldName = "";', 'private string currentWorldName = "";\n        private string currentCreatedAt = "";'),
    ('var document = new CharacterSaveDocument { version =', 'currentCreatedAt=NormalizeCreationTime(currentCreatedAt,path);\n            var document = new CharacterSaveDocument { createdAt=currentCreatedAt, version ='),
    ('var prepared = PrepareDocument(JsonUtility.FromJson<CharacterSaveDocument>(File.ReadAllText(path, Encoding.UTF8)), current);', 'var document=JsonUtility.FromJson<CharacterSaveDocument>(File.ReadAllText(path, Encoding.UTF8));\n            var prepared = PrepareDocument(document, current);\n            prepared.CreatedAt=NormalizeCreationTime(document.createdAt,path);'),
    ('currentWorldName=prepared.WorldName;', 'currentWorldName=prepared.WorldName;currentCreatedAt=prepared.CreatedAt;')])
edit('Assets/GameFramework/Runtime/Data/CampaignSaveCatalog.cs',[
    ('public string SavedAtUtc { get; internal set; }','public string SavedAtUtc { get; internal set; }\n        public string CreatedAtUtc { get; internal set; }'),
    ('public string savedAt, worldName;', 'public string savedAt, worldName, createdAt;'),
    ('currentWorldName=(worldName ?? "").Trim();','currentWorldName=(worldName ?? "").Trim();currentCreatedAt=DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture);'),
    ('document.version>28','document.version>32'),
    ('entry.WorldName=(document.worldName ?? "").Trim();','entry.WorldName=(document.worldName ?? "").Trim();\n                entry.CreatedAtUtc=NormalizeCreationTime(document.createdAt,path);')])
edit('Assets/GameFramework/Runtime/Audio/GameAudioService.cs',[
    ('public void SetVolumes(float master, float music, float effects)','internal float MasterVolume => _masterVolume;\n        internal float MusicVolumeSetting => _musicVolume;\n        internal float EffectsVolume => _effectsVolume;\n\n        public void SetVolumes(float master, float music, float effects)')])
edit('Assets/GameFramework/Samples/Adventure/CampaignMenu.cs',[
    ('public static void OnClose(AdventureRuntimeDemo demo) => demo.SetCampaignMenuOpen(false);', '''public static void OnClose(AdventureRuntimeDemo demo) => demo.SetCampaignMenuOpen(false);
        public static ProjectY.Data.WorldMenuSelection Preview(AdventureRuntimeDemo demo) => demo.MenuPreview(null);
        public static ProjectY.Data.WorldMenuSelection PreviewSave(AdventureRuntimeDemo demo,string id) => demo.MenuPreview(id);
        public static bool CanDelete(AdventureRuntimeDemo demo,string id) => !demo.HasCampaignSession || ProjectY.Data.CampaignSaves.CurrentId(demo.MenuSaveService)!=id;
        public static bool Delete(AdventureRuntimeDemo demo,string id) => demo.DeleteCampaign(id);
        public static float[] Volumes(AdventureRuntimeDemo demo) => demo.MenuVolumes();
        public static void SetOptions(AdventureRuntimeDemo demo,float master,float music,float effects,bool reduced) => demo.SetMenuOptions(master,music,effects,reduced);
        public static void Quit()
        {
#if UNITY_EDITOR
            UnityEditor.EditorApplication.isPlaying=false;
#else
            Application.Quit();
#endif
        }'''),
    ('private bool campaignMenuOpen;', '''private bool campaignCameraWasEnabled;
        internal ProjectY.Data.CharacterSaveService MenuSaveService => (ProjectY.Data.CharacterSaveService)bootstrap.CallModule(Bridge,"campaign_save_service")[0];
        internal ProjectY.Data.WorldMenuSelection MenuPreview(string id)
        {
            try{return id==null?MenuSaveService.LatestMenuPreview():MenuSaveService.SelectedMenuPreview(id);}
            catch(Exception error) when(error is System.IO.IOException || error is UnauthorizedAccessException || error is ArgumentException)
            {Debug.LogWarning("Menu preview unavailable: "+error.Message);return new ProjectY.Data.WorldMenuSelection{Status=3};}
        }
        internal bool DeleteCampaign(string id)
        {
            if(!CampaignMenu.CanDelete(this,id)){campaignMenuError=ProjectY.UI.LuaLanguage.Get("MenuDeleteActive");return false;}
            try{MenuSaveService.DeleteCampaignSlot(id);campaignMenuError="";return true;}
            catch(Exception error) when(error is System.IO.IOException || error is UnauthorizedAccessException || error is ArgumentException)
            {Debug.LogWarning("Campaign deletion failed: "+error.Message);campaignMenuError=ProjectY.UI.LuaLanguage.Get("MenuDeleteFailed");return false;}
        }
        internal float[] MenuVolumes()=>new[]{bootstrap.Audio.MasterVolume,bootstrap.Audio.MusicVolumeSetting,bootstrap.Audio.EffectsVolume};
        internal void SetMenuOptions(float master,float music,float effects,bool reduced)
        {bootstrap.Audio.SetVolumes(master,music,effects);PlayerPrefs.SetInt(ProjectY.UI.StartMenuView.ReducedMotionPreference,reduced?1:0);PlayerPrefs.Save();}
        private bool campaignMenuOpen;'''),
    ('internal void SetCampaignMenuOpen(bool value) {campaignMenuOpen=value;if(value)campaignMenuError="";}', '''internal void SetCampaignMenuOpen(bool value)
        {
            if(campaignMenuOpen==value)return;campaignMenuOpen=value;
            if(value){campaignMenuError="";campaignCameraWasEnabled=mapCamera.enabled;mapCamera.enabled=false;}
            else mapCamera.enabled=campaignCameraWasEnabled;
        }''')])
edit('Assets/GameFramework/Samples/Adventure/CampaignLoading.cs',[
    ('worldMap = map;', '''worldMap = map;
                // The map is already committed. Cache only a bounded visual synopsis; never regenerate from the menu.
                var menuSnapshot=CampaignPreviewCapture.Capture(map);
                try{MenuSaveService.StoreMenuPreview(menuSnapshot);}
                catch(Exception error) when(error is System.IO.IOException || error is UnauthorizedAccessException)
                {Debug.LogWarning("Menu preview could not be saved: "+error.Message);}''')])
edit('Lua/Game/Adventure/DemoBridge.lua',[
    ("if command=='campaign_saves' then", "if command=='campaign_save_service' then return adventure.characterSaves end\n    if command=='campaign_saves' then")])
edit('Assets/GameFramework/Samples/Adventure/AdventureRuntimeDemo.cs',[
    ('if (campaignLoading != null) { environment?.HideWeather(); AdvanceCampaignLoading(); return; }', 'if (campaignLoading != null) { environment?.HideWeather(); AdvanceCampaignLoading(); return; }\n            if (campaignMenuOpen) { environment?.HideWeather(); return; }')])
edit('Assets/GameFramework/Runtime/UI/link.xml',[
    ('<assembly fullname="Assembly-CSharp">','''<assembly fullname="Assembly-CSharp">
    <type fullname="ProjectY.UI.StartMenuView" preserve="all" />
    <type fullname="ProjectY.UI.StartMenuStage" preserve="all" />
    <type fullname="ProjectY.Samples.CampaignMenu" preserve="all" />
    <type fullname="ProjectY.Data.WorldMenuSelection" preserve="all" />
    <type fullname="ProjectY.Data.WorldMenuSnapshot" preserve="all" />''')])
(stage/'manifest.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
print('Prepared',len(records),'files; original hashes recorded.')
