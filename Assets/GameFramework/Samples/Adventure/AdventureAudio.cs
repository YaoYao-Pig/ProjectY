using System;
using System.Collections.Generic;
using UnityEngine;
using XLua;

namespace ProjectY.Samples
{
    public sealed class BattleAudioEvent
    {
        public int Shot;
        public bool Critical;
        public static BattleAudioEvent[] Read(LuaTable root)
        {
            using (var rows = root.Get<LuaTable>("audioEvents"))
            {
                // Initial and load snapshots intentionally carry no historical hits.
                if (rows == null) return Array.Empty<BattleAudioEvent>();
                var events = new BattleAudioEvent[rows.Length];
                for (int i = 0; i < events.Length; i++)
                    using (var row = rows.Get<int, LuaTable>(i + 1))
                    {
                        int shot = row.Get<int>("shot");
                        if (shot < 1) throw new InvalidOperationException("Invalid settled audio shot.");
                        events[i] = new BattleAudioEvent { Shot = shot, Critical = row.Get<bool>("critical") };
                    }
                return events;
            }
        }
    }

    public sealed partial class AdventureRuntimeDemo
    {
        private struct PendingAudio { public float Delay, Gain; }
        private readonly List<PendingAudio> pendingAudio = new List<PendingAudio>(128);
        private bool battleMusic;
        private bool settlementPresentationPending;

        // Settlement popups pause the world. Finish the last strike before opening them.
        private void AdvanceAudioSettlement()
        {
            float deltaTime = battleCinematic != null ? battleCinematic.Advance(Time.deltaTime) : Time.deltaTime;
            Feedback?.SetPlaybackRate(battleCinematic != null ? battleCinematic.PlaybackRate : 1);
            Feedback?.Tick(deltaTime);
            TickBattleAudio(deltaTime);
            if (HasArea)
            {
                squadRenderer.Tick(deltaTime);
                combatRenderer.Tick(deltaTime);
                TickVisualEffects(deltaTime);
                if (Input.GetKeyDown(KeyCode.Space))
                {
                    ClearBattleCinematic(); squadRenderer.Skip(); combatRenderer.Skip();
                    Feedback?.Skip(); ClearVisualEffects();
                }
            }
            if (pendingAudio.Count > 0 || bootstrap.Audio.HasActiveEffects || AnimationBusy) return;
            settlementPresentationPending = false;
            bootstrap.CallModule("UI.AdventureUIBridge", "sync", this);
        }

        private void SyncMusic()
        {
            if (campaignMenuOpen || view == null) battleMusic = false;
            else if (view.Phase == "battle") battleMusic = true;
            else if (pendingAudio.Count == 0 && !bootstrap.Audio.HasActiveEffects) battleMusic = false;
            bootstrap.Audio.SetMusic(battleMusic ? "battle" : "exploration");
        }

        private void QueueBattleAudio(AdventureViewData snapshot, float impactDelay)
        {
            foreach (var hit in snapshot.AudioEvents)
            {
                if (pendingAudio.Count == 128) pendingAudio.RemoveAt(0);
                pendingAudio.Add(new PendingAudio {
                    Delay = impactDelay + (hit.Shot - 1) * (Feedback != null ? Feedback.BurstHitInterval : .2f),
                    Gain = hit.Critical ? 1.12f : 1f
                });
            }
            snapshot.AudioEvents = Array.Empty<BattleAudioEvent>();
        }

        private void TickBattleAudio(float deltaTime)
        {
            if (deltaTime <= 0) return;
            for (int i = 0; i < pendingAudio.Count;)
            {
                var hit = pendingAudio[i]; hit.Delay -= deltaTime;
                if (hit.Delay > 0) { pendingAudio[i] = hit; i++; continue; }
                bootstrap.Audio.PlayEffect("hit", hit.Gain);
                bootstrap.Audio.PlayEffect("hurt", hit.Gain);
                pendingAudio.RemoveAt(i);
            }
        }

        private void ClearBattleAudio()
        {
            pendingAudio.Clear();
            settlementPresentationPending = false;
            // Teardown may run after the bootstrap has already released its services.
            if (bootstrap != null) bootstrap.StopAudioEffects();
        }
    }
}
