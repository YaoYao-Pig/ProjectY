using System;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Presentation-only zoom threshold and reversible camera/HUD timeline.</summary>
    public sealed class WorldMapCameraMode
    {
        [Serializable] public sealed class Settings
        {
            [Min(1)] public float enterSizeInCells = 60;
            [Min(1)] public float exitSizeInCells = 48;
            [Range(.2f, 1.2f)] public float transitionSeconds = .55f;
            public void Validate()
            {
                if (exitSizeInCells <= 0 || enterSizeInCells <= exitSizeInCells || transitionSeconds <= 0)
                    throw new InvalidOperationException("World map camera requires separate enter/exit thresholds and a positive transition duration.");
            }
        }
        public bool Active { get; private set; }
        public float Progress { get; private set; }
        public float Blend => Mathf.SmoothStep(0, 1, Progress);
        public bool Visible => Active || Progress > 0;
        public bool Transitioning => Active ? Progress < 1 : Progress > 0;
        public static float EntrySize(Settings settings, float radius, float fitSize) => Mathf.Min(radius * settings.enterSizeInCells, fitSize * .85f);
        public static float ExitSize(Settings settings, float radius, float fitSize) => EntrySize(settings, radius, fitSize) * settings.exitSizeInCells / settings.enterSizeInCells;
        public void Tick(bool worldMap, float targetZoom, float radius, float fitSize, float deltaTime, Settings settings)
        {
            if (!worldMap) { Reset(); return; }
            if (!Active && targetZoom >= EntrySize(settings, radius, fitSize)) Active = true;
            else if (Active && targetZoom <= ExitSize(settings, radius, fitSize)) Active = false;
            Progress = Mathf.MoveTowards(Progress, Active ? 1 : 0, deltaTime / settings.transitionSeconds);
        }
        public void Reset() { Active = false; Progress = 0; }
    }
}
