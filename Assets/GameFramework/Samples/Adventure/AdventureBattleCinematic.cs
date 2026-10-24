using System.Collections.Generic;
using ProjectY.UI;
using UnityEngine;

namespace ProjectY.Samples
{
    public sealed partial class AdventureRuntimeDemo
    {
        [SerializeField] private BattleCinematicSettings battleCinematicSettings = new BattleCinematicSettings();
        private BattleCinematic battleCinematic;
        private readonly List<PawnView> cinematicParticipants = new List<PawnView>();
        private readonly HashSet<int> cinematicActorIds = new HashSet<int>();

        private void CaptureBattleCinematic(WorldEffectEvent[] events, float impactDelay, bool wasBattle)
        {
            if (!HasArea || !wasBattle || !battleCinematicSettings.Enabled) return;
            cinematicParticipants.Clear(); cinematicActorIds.Clear(); int lastShot = 1;
            foreach (var item in events)
            {
                // Actual attack recipients include misses and friendly interceptions.
                if (item.SkillId == 0 || (item.Outcome != "hit" && item.Outcome != "miss")) continue;
                cinematicActorIds.Add(item.SourceId);
                if (item.TargetId != 0) cinematicActorIds.Add(item.TargetId);
                lastShot = Mathf.Max(lastShot, item.Shot);
            }
            foreach (int id in cinematicActorIds)
            {
                var pawn = squadRenderer.PresentationPawn(id) ?? combatRenderer.PresentationPawn(id);
                // Non-rendered recipients have no model to focus; never reveal hidden actors.
                if (pawn != null) cinematicParticipants.Add(pawn);
            }
            if (cinematicParticipants.Count == 0) return;
            if (battleCinematic == null) battleCinematic = new BattleCinematic(battleCinematicSettings, SceneFocusMask.Create(mainHud.PresentationRoot));
            battleCinematic.Begin(cinematicParticipants, impactDelay + (lastShot - 1) * (Feedback != null ? Feedback.BurstHitInterval : .2f) + .30f);
        }
        private void ClearBattleCinematic()
        { battleCinematic?.Clear(); Feedback?.SetPlaybackRate(1); }
        private void DisposeBattleCinematic()
        { battleCinematic?.Dispose(); battleCinematic = null; Feedback?.SetPlaybackRate(1); }
    }
}
