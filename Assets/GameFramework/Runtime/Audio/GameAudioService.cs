using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Audio
{
    /// <summary>Owns two crossfading music voices and a bounded, non-spatial effects pool.</summary>
    public sealed class GameAudioService : IDisposable
    {
        private const string CatalogPath = "Audio/catalog";
        private const string MasterPreference = "ProjectY.Audio.Master";
        private const string MusicPreference = "ProjectY.Audio.Music";
        private const string EffectsPreference = "ProjectY.Audio.Effects";
        private const int EffectVoiceCount = 16;

        [Serializable]
        private sealed class Catalog
        {
            public float crossFadeSeconds;
            public MusicEntry[] music;
            public EffectEntry[] effects;
        }

        [Serializable]
        private sealed class MusicEntry
        {
            public string cue;
            public string clip;
            public float gain;
        }

        [Serializable]
        private sealed class EffectEntry
        {
            public string cue;
            public string[] clips;
            public float gain;
            public float cooldownSeconds;
            public int maxConcurrent;
            public float pitchMin;
            public float pitchMax;
        }

        private sealed class MusicVoice
        {
            public MusicEntry Entry;
            public AudioClip Clip;
            public AudioSource Source;
            public float Weight;
            public float FadeFrom;
            public float FadeTo;
            public bool Started;
            public bool NeedsPlay;
        }

        private sealed class EffectCue
        {
            public EffectEntry Entry;
            public AudioClip[] Clips;
            public int LastVariant = -1;
            public int ActiveCount;
            public double NextAllowedTime;
        }

        private sealed class EffectVoice
        {
            public AudioSource Source;
            public EffectCue Cue;
            public float Gain;
            public float Remaining;
        }

        private readonly Dictionary<string, MusicVoice> _music = new Dictionary<string, MusicVoice>(StringComparer.Ordinal);
        private readonly Dictionary<string, EffectCue> _effects = new Dictionary<string, EffectCue>(StringComparer.Ordinal);
        private readonly EffectVoice[] _effectVoices = new EffectVoice[EffectVoiceCount];
        private readonly System.Random _random = new System.Random();
        private readonly float _crossFadeSeconds;
        private readonly GameObject _root;
        private float _masterVolume;
        private float _musicVolume;
        private float _effectsVolume;
        private float _fadeElapsed;
        private double _elapsed;
        private string _musicCue;
        private bool _fading;
        private bool _paused;
        private bool _disposed;

        public bool HasActiveEffects
        {
            get
            {
                ThrowIfDisposed();
                for (int i = 0; i < _effectVoices.Length; i++)
                    if (_effectVoices[i].Cue != null) return true;
                return false;
            }
        }

        public GameAudioService(Transform owner)
        {
            if (owner == null) throw new ArgumentNullException(nameof(owner));
            var asset = Resources.Load<TextAsset>(CatalogPath);
            if (asset == null) throw new InvalidOperationException("Missing required audio catalog: Resources/" + CatalogPath + ".json");
            var catalog = JsonUtility.FromJson<Catalog>(asset.text);
            if (catalog == null) throw new InvalidOperationException("Audio catalog is empty: " + CatalogPath);
            RequirePositive(catalog.crossFadeSeconds, "crossFadeSeconds");
            _crossFadeSeconds = catalog.crossFadeSeconds;
            LoadMusic(catalog.music);
            LoadEffects(catalog.effects);
            if (!_music.ContainsKey("exploration") || !_music.ContainsKey("battle"))
                throw new InvalidOperationException("Audio catalog requires exploration and battle music cues.");
            if (!_effects.ContainsKey("hit") || !_effects.ContainsKey("hurt"))
                throw new InvalidOperationException("Audio catalog requires hit and hurt effect cues.");
            _masterVolume = ReadVolume(MasterPreference, .8f);
            _musicVolume = ReadVolume(MusicPreference, .45f);
            _effectsVolume = ReadVolume(EffectsPreference, .8f);

            // Validate and load the complete catalog before creating any owned scene objects.
            _root = new GameObject("GameAudio");
            try
            {
                _root.transform.SetParent(owner, false);
                foreach (var voice in _music.Values)
                {
                    voice.Source = CreateSource(true);
                    voice.Source.clip = voice.Clip;
                }
                for (int i = 0; i < _effectVoices.Length; i++)
                    _effectVoices[i] = new EffectVoice { Source = CreateSource(false) };
            }
            catch
            {
                DestroyRoot();
                throw;
            }
        }

        public void SetMusic(string cue)
        {
            ThrowIfDisposed();
            if (cue == null || !_music.TryGetValue(cue, out var selected))
                throw new ArgumentException("Unknown music cue: " + cue, nameof(cue));
            if (_musicCue == cue) return;
            _musicCue = cue;
            _fadeElapsed = 0f;
            _fading = true;
            foreach (var voice in _music.Values)
            {
                // Reversing an unfinished transition begins at the audible weights.
                voice.FadeFrom = voice.Weight;
                voice.FadeTo = voice == selected ? 1f : 0f;
            }
            if (!selected.Started)
            {
                selected.Started = true;
                selected.NeedsPlay = true;
                if (!_paused) ResumeMusic(selected);
            }
        }

        public void PlayEffect(string cue, float gain = 1f)
        {
            ThrowIfDisposed();
            if (cue == null || !_effects.TryGetValue(cue, out var effect))
                throw new ArgumentException("Unknown effect cue: " + cue, nameof(cue));
            RequireNonnegative(gain, nameof(gain));
            if (_paused || _elapsed < effect.NextAllowedTime || effect.ActiveCount >= effect.Entry.maxConcurrent) return;

            EffectVoice available = null;
            for (int i = 0; i < _effectVoices.Length; i++)
            {
                if (_effectVoices[i].Cue != null) continue;
                available = _effectVoices[i];
                break;
            }
            // A saturated pool drops new sounds instead of cutting off already audible impacts.
            if (available == null) return;

            int count = effect.Clips.Length;
            int variant = _random.Next(count == 1 || effect.LastVariant < 0 ? count : count - 1);
            if (count > 1 && effect.LastVariant >= 0 && variant >= effect.LastVariant) variant++;
            effect.LastVariant = variant;
            effect.NextAllowedTime = _elapsed + effect.Entry.cooldownSeconds;
            effect.ActiveCount++;
            available.Cue = effect;
            available.Gain = gain;
            available.Source.clip = effect.Clips[variant];
            available.Source.pitch = Mathf.Lerp(effect.Entry.pitchMin, effect.Entry.pitchMax, (float)_random.NextDouble());
            available.Source.volume = EffectVolume(available);
            available.Remaining = available.Source.clip.length / available.Source.pitch;
            if (Application.isPlaying) available.Source.Play();
        }

        public void Tick(float unscaledDeltaTime)
        {
            ThrowIfDisposed();
            RequireNonnegative(unscaledDeltaTime, nameof(unscaledDeltaTime));
            if (_paused) return;
            _elapsed += unscaledDeltaTime;
            if (_fading)
            {
                _fadeElapsed += unscaledDeltaTime;
                float progress = Mathf.Clamp01(_fadeElapsed / _crossFadeSeconds);
                foreach (var voice in _music.Values)
                {
                    voice.Weight = Mathf.Lerp(voice.FadeFrom, voice.FadeTo, progress);
                    voice.Source.volume = MusicVolume(voice);
                    if (progress < 1f || voice.FadeTo > 0f || !voice.Started) continue;
                    voice.Source.Stop();
                    voice.Started = false;
                    voice.NeedsPlay = false;
                }
                _fading = progress < 1f;
            }

            for (int i = 0; i < _effectVoices.Length; i++)
            {
                var voice = _effectVoices[i];
                if (voice.Cue == null) continue;
                voice.Remaining -= unscaledDeltaTime;
                // Editor checks advance logical state without emitting audio.
                bool finished = Application.isPlaying ? !voice.Source.isPlaying : voice.Remaining <= 0f;
                if (finished) ReleaseEffect(voice);
            }
        }

        public void SetPaused(bool paused)
        {
            ThrowIfDisposed();
            if (_paused == paused) return;
            _paused = paused;
            foreach (var voice in _music.Values)
            {
                if (!voice.Started) continue;
                if (paused) voice.Source.Pause();
                else ResumeMusic(voice);
            }
            for (int i = 0; i < _effectVoices.Length; i++)
            {
                var voice = _effectVoices[i];
                if (voice.Cue == null) continue;
                if (paused) voice.Source.Pause();
                else if (Application.isPlaying) voice.Source.UnPause();
            }
        }

        public void StopEffects()
        {
            ThrowIfDisposed();
            for (int i = 0; i < _effectVoices.Length; i++)
                if (_effectVoices[i].Cue != null) ReleaseEffect(_effectVoices[i]);
            foreach (var effect in _effects.Values) effect.NextAllowedTime = _elapsed;
        }

        public void SetVolumes(float master, float music, float effects)
        {
            ThrowIfDisposed();
            RequireVolume(master, nameof(master));
            RequireVolume(music, nameof(music));
            RequireVolume(effects, nameof(effects));
            _masterVolume = master;
            _musicVolume = music;
            _effectsVolume = effects;
            foreach (var voice in _music.Values) voice.Source.volume = MusicVolume(voice);
            for (int i = 0; i < _effectVoices.Length; i++)
                if (_effectVoices[i].Cue != null) _effectVoices[i].Source.volume = EffectVolume(_effectVoices[i]);
            PlayerPrefs.SetFloat(MasterPreference, master);
            PlayerPrefs.SetFloat(MusicPreference, music);
            PlayerPrefs.SetFloat(EffectsPreference, effects);
            PlayerPrefs.Save();
        }

        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;
            // Owner teardown may have already destroyed its audio child before shutdown runs.
            if (_root != null)
            {
                foreach (var voice in _music.Values)
                    if (voice.Source != null) voice.Source.Stop();
                for (int i = 0; i < _effectVoices.Length; i++)
                    if (_effectVoices[i].Source != null) _effectVoices[i].Source.Stop();
                DestroyRoot();
            }
            _music.Clear();
            _effects.Clear();
            Array.Clear(_effectVoices, 0, _effectVoices.Length);
            // Resources clips may be shared by other consumers; only owned scene objects are destroyed.
        }

        private AudioSource CreateSource(bool loop)
        {
            var source = _root.AddComponent<AudioSource>();
            source.playOnAwake = false;
            source.loop = loop;
            source.spatialBlend = 0f;
            source.dopplerLevel = 0f;
            source.volume = 0f;
            source.priority = loop ? 64 : 128;
            return source;
        }

        private void ResumeMusic(MusicVoice voice)
        {
            if (!Application.isPlaying) return;
            if (voice.NeedsPlay)
            {
                voice.Source.Play();
                voice.NeedsPlay = false;
            }
            else voice.Source.UnPause();
        }

        private void ReleaseEffect(EffectVoice voice)
        {
            voice.Source.Stop();
            voice.Source.clip = null;
            voice.Cue.ActiveCount--;
            voice.Cue = null;
            voice.Remaining = 0f;
        }

        private float MusicVolume(MusicVoice voice) => Mathf.Clamp01(_masterVolume * _musicVolume * voice.Entry.gain * voice.Weight);
        private float EffectVolume(EffectVoice voice) => Mathf.Clamp01(_masterVolume * _effectsVolume * voice.Cue.Entry.gain * voice.Gain);

        private void LoadMusic(MusicEntry[] entries)
        {
            if (entries == null || entries.Length != 2)
                throw new InvalidOperationException("Audio catalog must contain exactly two music cues: exploration and battle.");
            foreach (var entry in entries)
            {
                if (entry == null || string.IsNullOrWhiteSpace(entry.cue)) throw new InvalidOperationException("Audio catalog contains an empty music cue.");
                if (_music.ContainsKey(entry.cue)) throw new InvalidOperationException("Duplicate music cue: " + entry.cue);
                RequireVolume(entry.gain, entry.cue + ".gain");
                _music.Add(entry.cue, new MusicVoice { Entry = entry, Clip = LoadClip(entry.clip, entry.cue) });
            }
        }

        private void LoadEffects(EffectEntry[] entries)
        {
            if (entries == null) throw new InvalidOperationException("Audio catalog is missing effects.");
            foreach (var entry in entries)
            {
                if (entry == null || string.IsNullOrWhiteSpace(entry.cue)) throw new InvalidOperationException("Audio catalog contains an empty effect cue.");
                if (_effects.ContainsKey(entry.cue)) throw new InvalidOperationException("Duplicate effect cue: " + entry.cue);
                RequireVolume(entry.gain, entry.cue + ".gain");
                RequirePositive(entry.cooldownSeconds, entry.cue + ".cooldownSeconds");
                RequirePositive(entry.pitchMin, entry.cue + ".pitchMin");
                RequirePositive(entry.pitchMax, entry.cue + ".pitchMax");
                if (entry.pitchMin < .5f || entry.pitchMax > 2f || entry.pitchMax < entry.pitchMin)
                    throw new InvalidOperationException("Effect pitch must satisfy 0.5 <= pitchMin <= pitchMax <= 2: " + entry.cue);
                if (entry.maxConcurrent < 1 || entry.maxConcurrent > EffectVoiceCount)
                    throw new InvalidOperationException("Effect maxConcurrent must be between 1 and 16: " + entry.cue);
                if (entry.clips == null || entry.clips.Length == 0) throw new InvalidOperationException("Effect cue has no clips: " + entry.cue);
                var clips = new AudioClip[entry.clips.Length];
                var paths = new HashSet<string>(StringComparer.Ordinal);
                for (int i = 0; i < clips.Length; i++)
                {
                    if (!paths.Add(entry.clips[i])) throw new InvalidOperationException("Duplicate effect variant: " + entry.cue + " / " + entry.clips[i]);
                    clips[i] = LoadClip(entry.clips[i], entry.cue);
                }
                _effects.Add(entry.cue, new EffectCue { Entry = entry, Clips = clips });
            }
        }

        private static AudioClip LoadClip(string path, string cue)
        {
            if (string.IsNullOrWhiteSpace(path)) throw new InvalidOperationException("Missing audio clip path for cue: " + cue);
            var clip = Resources.Load<AudioClip>(path);
            if (clip == null || clip.length <= 0f)
                throw new InvalidOperationException("Missing or empty audio clip for " + cue + ": Resources/" + path);
            return clip;
        }

        private static float ReadVolume(string key, float defaultValue)
        {
            float value = PlayerPrefs.GetFloat(key, defaultValue);
            RequireVolume(value, key);
            return value;
        }

        private static void RequireVolume(float value, string name)
        {
            RequireNonnegative(value, name);
            if (value > 1f) throw new ArgumentOutOfRangeException(name, value, "Volume must be between 0 and 1.");
        }

        private static void RequirePositive(float value, string name)
        {
            RequireNonnegative(value, name);
            if (value == 0f) throw new ArgumentOutOfRangeException(name, value, "Value must be positive.");
        }

        private static void RequireNonnegative(float value, string name)
        {
            if (float.IsNaN(value) || float.IsInfinity(value) || value < 0f)
                throw new ArgumentOutOfRangeException(name, value, "Value must be finite and nonnegative.");
        }

        private void ThrowIfDisposed()
        {
            if (_disposed) throw new ObjectDisposedException(nameof(GameAudioService));
        }

        private void DestroyRoot()
        {
            if (Application.isPlaying) UnityEngine.Object.Destroy(_root);
            else UnityEngine.Object.DestroyImmediate(_root);
        }
    }
}
