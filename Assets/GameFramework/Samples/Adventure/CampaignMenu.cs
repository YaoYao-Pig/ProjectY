using System;
using System.Globalization;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Reflection bridge for the start/load panel; save ownership stays in CharacterSaveService.</summary>
    public static class CampaignMenu
    {
        public static Font Font(AdventureRuntimeDemo demo) => demo.CampaignFont;
        public static bool HasSession(AdventureRuntimeDemo demo) => demo.HasCampaignSession;
        public static string RandomSeed() => ProjectY.Data.ExpeditionPersistence.RandomSeed().ToString(CultureInfo.InvariantCulture);
        public static string LastError(AdventureRuntimeDemo demo) => demo.CampaignMenuError;
        public static ProjectY.Data.SaveCatalogEntry[] Saves(AdventureRuntimeDemo demo) => demo.CampaignSaves();
        public static bool NewGame(AdventureRuntimeDemo demo,string seedText,int size) => demo.CreateCampaign(seedText,size);
        public static bool NewGame(AdventureRuntimeDemo demo,string seedText,int size,int startId) => demo.CreateCampaign(seedText,size,startId);
        public static bool NewGame(AdventureRuntimeDemo demo,string seedText,int size,int startId,string worldName) => demo.CreateCampaign(seedText,size,startId,worldName);
        public static bool Load(AdventureRuntimeDemo demo,string id) => demo.LoadCampaign(id);
        public static void OnOpen(AdventureRuntimeDemo demo) => demo.SetCampaignMenuOpen(true);
        public static void OnClose(AdventureRuntimeDemo demo) => demo.SetCampaignMenuOpen(false);
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
        }
    }
    public sealed partial class AdventureRuntimeDemo
    {
        private bool campaignCameraWasEnabled;
        private int campaignCameraMask;
        private CameraClearFlags campaignCameraClearFlags;
        internal ProjectY.Data.CharacterSaveService MenuSaveService => (ProjectY.Data.CharacterSaveService)bootstrap.CallModule(Bridge,"campaign_save_service")[0];
        internal ProjectY.Data.WorldMenuSelection MenuPreview(string id)
        {
            try{return id==null?MenuSaveService.LatestMenuPreview():MenuSaveService.SelectedMenuPreview(id);}
            catch(Exception error) when(error is System.IO.InvalidDataException || error is System.IO.IOException || error is UnauthorizedAccessException || error is ArgumentException)
            {Debug.LogWarning("Menu preview unavailable: "+error.Message);return new ProjectY.Data.WorldMenuSelection{Status=3};}
        }
        internal bool DeleteCampaign(string id)
        {
            if(!CampaignMenu.CanDelete(this,id)){campaignMenuError=ProjectY.UI.LuaLanguage.Get("MenuDeleteActive");return false;}
            try{MenuSaveService.DeleteCampaignSlot(id);campaignMenuError="";return true;}
            catch(Exception error) when(error is System.IO.InvalidDataException || error is System.IO.IOException || error is UnauthorizedAccessException || error is ArgumentException)
            {Debug.LogWarning("Campaign deletion failed: "+error.Message);campaignMenuError=ProjectY.UI.LuaLanguage.Get("MenuDeleteFailed");return false;}
        }
        internal float[] MenuVolumes()=>new[]{bootstrap.Audio.MasterVolume,bootstrap.Audio.MusicVolumeSetting,bootstrap.Audio.EffectsVolume};
        internal void SetMenuOptions(float master,float music,float effects,bool reduced)
        {bootstrap.Audio.SetVolumes(master,music,effects);PlayerPrefs.SetInt(ProjectY.UI.StartMenuView.ReducedMotionPreference,reduced?1:0);PlayerPrefs.Save();}
        private bool campaignMenuOpen;
        private string campaignMenuError="";
        internal Font CampaignFont => font;
        internal bool HasCampaignSession => view!=null && fatalError==null;
        internal string CampaignMenuError => campaignMenuError;
        internal void SetCampaignMenuOpen(bool value)
        {
            if(campaignMenuOpen==value)return;campaignMenuOpen=value;
            if(value)
            {
                campaignMenuError="";campaignCameraWasEnabled=mapCamera.enabled;campaignCameraMask=mapCamera.cullingMask;campaignCameraClearFlags=mapCamera.clearFlags;
                // Keep a display camera alive for Overlay UI while excluding all gameplay geometry.
                mapCamera.cullingMask=0;mapCamera.clearFlags=CameraClearFlags.SolidColor;mapCamera.enabled=true;
            }
            else if(mapCamera!=null){mapCamera.cullingMask=campaignCameraMask;mapCamera.clearFlags=campaignCameraClearFlags;mapCamera.enabled=campaignCameraWasEnabled;}
        }
        private void OpenCampaignMenu(string mode)
        {
            if(settlementPresentationPending)return;
            if(campaignLoading!=null || equipmentOpen || growthOpen || storyOpen || pendingExitView!=null)return;
            if(view!=null && view.Phase!="map" && view.Phase!="area")return;
            bootstrap.CallModule("UI.CampaignMenuBridge",this,mode);
        }
        internal ProjectY.Data.SaveCatalogEntry[] CampaignSaves()
        {
            var values=bootstrap.CallModule(Bridge,"campaign_saves");
            return (ProjectY.Data.SaveCatalogEntry[])values[0];
        }
        internal bool CreateCampaign(string seedText,int size) => CreateCampaign(seedText,size,1);
        internal bool CreateCampaign(string seedText,int size,int startId,string worldName = "")
        {
            uint seed;
            if(!uint.TryParse(seedText,NumberStyles.None,CultureInfo.InvariantCulture,out seed))
            {campaignMenuError=ProjectY.UI.LuaLanguage.Get("UIStartMenuHintText");return false;}
            if(size!=2500 && size!=10000 && size!=30000 && size!=100000)
            {campaignMenuError=ProjectY.UI.LuaLanguage.Get("CampaignInvalidSize");return false;}
            if(startId<=0){campaignMenuError=ProjectY.UI.LuaLanguage.Get("StartOriginInvalid");return false;}
            return BeginCampaignLoading("begin",seed.ToString(CultureInfo.InvariantCulture),size,startId,worldName);
        }
        internal bool LoadCampaign(string id)
        {
            if(string.IsNullOrEmpty(id)){campaignMenuError=ProjectY.UI.LuaLanguage.Get("CampaignSelectSave");return false;}
            return BeginCampaignLoading("begin_load",id);
        }
    }
}
