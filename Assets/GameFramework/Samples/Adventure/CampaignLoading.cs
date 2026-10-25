using System;
using System.Collections;
using UnityEngine;
using XLua;
using LuaLanguage = ProjectY.UI.LuaLanguage;

namespace ProjectY.Samples
{
    public sealed partial class AdventureRuntimeDemo
    {
        private const string LoadingBridge = "UI.LoadingBridge";
        private const string CampaignLoadingBridge = "Game.Adventure.CampaignLoadingBridge";
        private IEnumerator campaignLoading;
        private int loadingToken;
        private bool campaignLoadingCommitted;
        private string campaignLoadingPage;

        private bool BeginCampaignLoading(string command, string argument, int size = 0, int startId = 0, string worldName = "")
        {
            if (campaignLoading != null) { campaignMenuError = LuaLanguage.Get("CampaignLoadingBusy"); return false; }
            campaignLoadingPage = command == "begin_load" ? "load" : "new";
            try
            {
                loadingToken = Convert.ToInt32(bootstrap.CallModule(LoadingBridge, "begin",
                    LuaLanguage.Get(campaignLoadingPage == "load" ? "CampaignLoadingLoadTitle" : "UIStartMenuTitleText2"), font)[0]);
                bootstrap.CallModule(CampaignLoadingBridge, command, loadingToken, argument, size, startId, worldName);
                campaignLoadingCommitted = false;
                campaignLoading = CampaignLoadingFrames();
                return true;
            }
            catch (Exception error)
            {
                EndCampaignLoading();
                campaignMenuError = error.Message;
                Debug.LogException(error, this);
                return false;
            }
        }

        private void ReportLoading(float progress, string stage)
            => bootstrap.CallModule(LoadingBridge, "report", loadingToken, progress, stage);

        // Advanced once per Update even while the modal panel pauses world time.
        // All returned Lua handles are consumed and disposed in the same step.
        private IEnumerator CampaignLoadingFrames()
        {
            yield return null; // Let the initial loading screen reach a rendered frame.
            MapPreviewData map;
            while (true)
            {
                var values = bootstrap.CallModule(CampaignLoadingBridge, "step", loadingToken);
                if ((bool)values[0])
                {
                    using (var root = (LuaTable)values[1]) map = MapPreviewData.Read(root);
                    break;
                }
                ReportLoading(Convert.ToSingle(values[1]), (string)values[2]);
                yield return null;
            }
            ReportLoading(.65f, LuaLanguage.Get("CampaignLoadingResources"));
            yield return null;
            MapPreviewRenderer candidate = new MapPreviewRenderer(previewShader, transform);
            try
            {
                candidate.SetVisible(false);
                foreach (var progress in candidate.BuildIncremental(map, asset => {
                    if (!assets.TryGetValue(asset.Id, out var binding) || binding.path != asset.Path || binding.prefab == null)
                        throw new InvalidOperationException(LuaLanguage.Format("CampaignLoadingAssetMismatch", asset.Id));
                    return binding.prefab;
                }))
                {
                    ReportLoading(.65f + progress * .28f, LuaLanguage.Get("CampaignLoadingRender"));
                    yield return null;
                }
                ReportLoading(.94f, LuaLanguage.Get(campaignLoadingPage == "load" ? "CampaignLoadingRestore" : "CampaignLoadingCreate"));
                yield return null;
                // Candidate layout and renderer are ready. Commit live Data and save identity only now.
                campaignLoadingCommitted = true;
                AdventureViewData next;
                using (var state = (LuaTable)bootstrap.CallModule(CampaignLoadingBridge, "commit", loadingToken)[0])
                {
                    next = AdventureViewData.Read(state);
                    var warning = state.Get<string>("warning");
                    if (!string.IsNullOrEmpty(warning)) next.Error = warning;
                }
                Feedback?.Clear();
                narrativeData = (ProjectY.Data.NarrativeData)bootstrap.CallModule("Game.Narrative.Bridge", "data")[0];
                if (HasArea) ClearAreaView();
                worldPartyView?.Dispose(); worldPartyView = null;
                worldWaterView?.Dispose(); worldWaterView = null;
                ClearWorldSites();
                mapRenderer.Dispose(); mapRenderer = candidate; candidate = null;
                worldMap = map;
                SetView(next);
                displayedTravel = view.Travel.Position; followTravel = false;
                fatalError = null; campaignMenuError = "";
                FitMap(); cameraRig.Snap(); cameraDragButton = -1;
                ReportLoading(1, LuaLanguage.Get("CampaignLoadingReady"));
                yield return null; // Present 100% before releasing the modal input blocker.
            }
            finally { candidate?.Dispose(); }
        }

        private void AdvanceCampaignLoading()
        {
            Exception failure = null;
            try { if (campaignLoading.MoveNext()) return; }
            catch (Exception error) { failure = error; }
            EndCampaignLoading();
            if (failure == null) return;
            // A failure after Data commit cannot resume the previous presentation as if it were still current.
            if (campaignLoadingCommitted) fatalError = failure.Message;
            campaignMenuError = failure.Message;
            Debug.LogException(failure, this);
            bootstrap.CallModule("UI.CampaignMenuBridge", this, campaignLoadingPage, failure.Message);
        }

        private void EndCampaignLoading()
        {
            (campaignLoading as IDisposable)?.Dispose();
            campaignLoading = null;
            if (loadingToken == 0) return;
            var token = loadingToken; loadingToken = 0;
            if (GameBootstrap.Instance != bootstrap) return; // Runtime already destroyed; its shutdown owns the UI.
            try { bootstrap.CallModule(CampaignLoadingBridge, "release", token); }
            finally { bootstrap.CallModule(LoadingBridge, "finish", token); }
        }

        private void OnDisable() => EndCampaignLoading();
    }
}
