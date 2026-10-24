using System;
using System.Collections;
using UnityEngine;
using XLua;

namespace ProjectY.Samples
{
    public sealed partial class AdventureRuntimeDemo
    {
        private const string LoadingBridge = "UI.LoadingBridge";
        private const string CampaignLoadingBridge = "Game.Adventure.CampaignLoadingBridge";
        private IEnumerator campaignLoading;
        private int loadingToken;
        private bool campaignLoadingCommitted;

        private bool BeginCampaignLoading(string seedText, int size, int startId)
        {
            if (campaignLoading != null) { campaignMenuError = "世界正在加载，请稍候。"; return false; }
            try
            {
                loadingToken = Convert.ToInt32(bootstrap.CallModule(LoadingBridge, "begin", "创建世界", font)[0]);
                bootstrap.CallModule(CampaignLoadingBridge, "begin", loadingToken, seedText, size, startId);
                campaignLoadingCommitted = false;
                campaignLoading = CreateCampaignFrames();
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
        private IEnumerator CreateCampaignFrames()
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
            ReportLoading(.65f, "准备地图资源");
            yield return null;
            MapPreviewRenderer candidate = new MapPreviewRenderer(previewShader, transform);
            try
            {
                candidate.SetVisible(false);
                foreach (var progress in candidate.BuildIncremental(map, asset => {
                    if (!assets.TryGetValue(asset.Id, out var binding) || binding.path != asset.Path || binding.prefab == null)
                        throw new InvalidOperationException("地图资源绑定不一致：" + asset.Id);
                    return binding.prefab;
                }))
                {
                    ReportLoading(.65f + progress * .28f, "构建地图显示");
                    yield return null;
                }
                ReportLoading(.94f, "建立队伍并保存新远征");
                yield return null;
                // Candidate layout and renderer are ready. Commit live Data only now.
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
                ClearWorldSites();
                mapRenderer.Dispose(); mapRenderer = candidate; candidate = null;
                worldMap = map;
                SetView(next);
                displayedTravel = view.Travel.Position; followTravel = false;
                fatalError = null; campaignMenuError = "";
                FitMap(); cameraRig.Snap(); cameraDragButton = -1;
                ReportLoading(1, "世界已就绪");
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
            bootstrap.CallModule("UI.CampaignMenuBridge", this, "new", failure.Message);
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
