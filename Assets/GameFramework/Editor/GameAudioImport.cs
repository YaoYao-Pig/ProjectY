using System;
using UnityEditor;
using UnityEngine;

namespace ProjectY.Editor
{
    /// <summary>Applies the project's music and short combat effect import policy.</summary>
    public sealed class GameAudioImport : AssetPostprocessor
    {
        private const string MusicRoot = "Assets/GameFramework/Resources/Audio/Music/";
        private const string EffectsRoot = "Assets/GameFramework/Resources/Audio/Effects/";

        public override uint GetVersion() => 1;

        private void OnPreprocessAudio()
        {
            bool music = assetPath.StartsWith(MusicRoot, StringComparison.Ordinal);
            bool effects = assetPath.StartsWith(EffectsRoot, StringComparison.Ordinal);
            if (!music && !effects) return;
            var importer = (AudioImporter)assetImporter;
            var settings = importer.defaultSampleSettings;
            settings.loadType = music ? AudioClipLoadType.Streaming : AudioClipLoadType.DecompressOnLoad;
            settings.compressionFormat = music ? AudioCompressionFormat.Vorbis : AudioCompressionFormat.PCM;
            settings.quality = .85f;
            settings.sampleRateSetting = AudioSampleRateSetting.PreserveSampleRate;
            settings.preloadAudioData = effects;
            importer.defaultSampleSettings = settings;
            importer.forceToMono = effects;
            importer.loadInBackground = false;
            importer.ambisonic = false;
        }
    }
}
