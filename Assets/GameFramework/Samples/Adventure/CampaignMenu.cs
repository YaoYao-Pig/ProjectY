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
    }
    public sealed partial class AdventureRuntimeDemo
    {
        private bool campaignMenuOpen;
        private string campaignMenuError="";
        internal Font CampaignFont => font;
        internal bool HasCampaignSession => view!=null && fatalError==null;
        internal string CampaignMenuError => campaignMenuError;
        internal void SetCampaignMenuOpen(bool value) {campaignMenuOpen=value;if(value)campaignMenuError="";}
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
