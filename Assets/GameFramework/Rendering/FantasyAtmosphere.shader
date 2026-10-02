Shader "Hidden/ProjectY/FantasyAtmosphere"
{
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        ZWrite Off ZTest Always Cull Off
        HLSLINCLUDE
        #pragma target 3.5
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        TEXTURE2D_X(_FantasyFogTexture);
        float4 _FantasyFogSize;
        float4 _AtmosphereParameters; // density, base height, height falloff, samples
        float4 _AtmosphereLighting; // max distance, sunlight, anisotropy, strength
        float4 _AtmosphereColor;

        float SkyMask(float2 uv)
        {
            float depth = SampleSceneDepth(saturate(uv));
            #if UNITY_REVERSED_Z
                return 1-step(.000001,depth);
            #else
                return step(.999999,depth);
            #endif
        }

        float3 ScreenShafts(float2 uv, Light sun)
        {
            // Perspective sunbeams spread from the projected directional light. Orthographic maps
            // use the world-space shadow integration below; they have no finite vanishing point.
            if (unity_OrthoParams.w > .5 || _AtmosphereLighting.y <= 0) return 0;
            float4 clip = TransformWorldToHClip(_WorldSpaceCameraPos + sun.direction * 1000);
            if (clip.w <= 0) return 0;
            float2 sunUV = ComputeNormalizedDeviceCoordinates(_WorldSpaceCameraPos + sun.direction * 1000, UNITY_MATRIX_VP);
            float offscreen = saturate(1-length(max(abs(sunUV-.5)-.5,0))*3);
            if (offscreen <= 0) return 0;
            float openSun = (SkyMask(sunUV)+SkyMask(sunUV+float2(.012,0))+SkyMask(sunUV-float2(.012,0))+
                             SkyMask(sunUV+float2(0,.012))+SkyMask(sunUV-float2(0,.012))) / 5;
            int shaftSamples = max(32,(int)_AtmosphereParameters.w*3);
            float2 delta = (sunUV-uv) * (.96/shaftSamples);
            float jitter = frac(52.9829189*frac(dot(uv*_FantasyFogSize.xy,float2(.06711056,.00583715))));
            float2 p = uv + delta*jitter;
            float light = 0, total = 0, weight = 1;
            float decay = pow(.97,24.0/shaftSamples);
            [loop] for (int i=0;i<shaftSamples;i++)
            {
                p += delta; light += SkyMask(p)*weight; total += weight; weight *= decay;
            }
            float mask = pow(saturate(light/total),2.5);
            float falloff = exp(-length(uv-sunUV)*1.7);
            return sun.color * mask * falloff * offscreen * openSun * _AtmosphereLighting.y * .18;
        }

        float DepthForReconstruction(float raw)
        {
            #if UNITY_REVERSED_Z
                return raw;
            #else
                return lerp(UNITY_NEAR_CLIP_VALUE, 1, raw);
            #endif
        }

        float EyeDepth(float2 uv)
        {
            float raw = SampleSceneDepth(saturate(uv));
            #if UNITY_REVERSED_Z
                float ortho = lerp(_ProjectionParams.z, _ProjectionParams.y, raw);
            #else
                float ortho = lerp(_ProjectionParams.y, _ProjectionParams.z, raw);
            #endif
            return lerp(LinearEyeDepth(raw, _ZBufferParams), ortho, unity_OrthoParams.w);
        }

        half4 IntegrateFog(Varyings input) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
            float2 uv = (input.texcoord - _BlitScaleBias.zw) / _BlitScaleBias.xy;
            float raw = SampleSceneDepth(uv);
            Light sun = GetMainLight();
            float3 shafts = ScreenShafts(uv,sun);
            #if UNITY_REVERSED_Z
                if (raw < 0.000001) return half4(shafts, 1);
                float nearDepth = 1;
            #else
                if (raw > 0.999999) return half4(shafts, 1);
                float nearDepth = UNITY_NEAR_CLIP_VALUE;
            #endif
            float3 surface = ComputeWorldSpacePosition(uv, DepthForReconstruction(raw), UNITY_MATRIX_I_VP);
            float3 nearPosition = ComputeWorldSpacePosition(uv, nearDepth, UNITY_MATRIX_I_VP);
            float3 origin = lerp(_WorldSpaceCameraPos, nearPosition, unity_OrthoParams.w);
            float3 ray = surface - origin;
            float distance = max(length(ray), 0.001);
            float3 direction = ray / distance;
            // Only the last segment near visible geometry: a distant map camera won't fog the whole world.
            float segment = min(distance, _AtmosphereLighting.x);
            origin = surface - direction * segment;
            int samples = (int)_AtmosphereParameters.w;
            float stepLength = segment / samples;
            float g = _AtmosphereLighting.z;
            float cosine = dot(direction, sun.direction);
            float phase = (1 - g * g) / pow(max(1 + g * g - 2 * g * cosine, 0.08), 1.5);
            phase = min(phase * 0.25, 2.5);
            float3 ambient = max(SampleSH(float3(0, 1, 0)), float3(.005, .007, .01));
            float3 scatter = 0;
            float transmission = 1;
            [loop] for (int i = 0; i < samples; i++)
            {
                float3 p = origin + direction * ((i + 0.5) * stepLength);
                float heightDensity = exp2(-max(p.y - _AtmosphereParameters.y, 0) * _AtmosphereParameters.z);
                float extinction = 1 - exp(-_AtmosphereParameters.x * heightDensity * stepLength);
                float visibility = MainLightRealtimeShadow(TransformWorldToShadowCoord(p));
                visibility = lerp(visibility, 1, GetMainLightShadowFade(p));
                // Surface shadow strength can be intentionally soft. Air needs stronger extinction in
                // occluded columns, otherwise that residual sunlight turns shafts into a uniform veil.
                visibility = visibility * visibility * visibility;
                float3 illumination = _AtmosphereColor.rgb * ambient * .3 + sun.color * visibility * phase * _AtmosphereLighting.y;
                scatter += transmission * extinction * illumination;
                transmission *= 1 - extinction;
            }
            return half4(scatter + shafts, transmission);
        }

        void AccumulateFog(float2 uv, float weight, float depth, inout float4 fog, inout float total)
        {
            uv = saturate(uv);
            float neighbour = EyeDepth(uv);
            weight *= exp2(-abs(neighbour - depth) / max(.03, depth * .002));
            fog += SAMPLE_TEXTURE2D_X(_FantasyFogTexture, sampler_PointClamp, uv) * weight;
            total += weight;
        }

        half4 CompositeFog(Varyings input) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
            float2 uv = (input.texcoord - _BlitScaleBias.zw) / _BlitScaleBias.xy;
            half4 source = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord);
            float2 grid = uv * _FantasyFogSize.xy - .5;
            float2 cell = floor(grid);
            float2 f = frac(grid);
            float depth = EyeDepth(uv);
            float4 fog = 0; float weight = 0;
            // Depth-aware upsampling prevents light halos bleeding across roofs and character silhouettes.
            AccumulateFog((cell + float2(.5, .5)) * _FantasyFogSize.zw, (1-f.x)*(1-f.y), depth, fog, weight);
            AccumulateFog((cell + float2(1.5, .5)) * _FantasyFogSize.zw, f.x*(1-f.y), depth, fog, weight);
            AccumulateFog((cell + float2(.5, 1.5)) * _FantasyFogSize.zw, (1-f.x)*f.y, depth, fog, weight);
            AccumulateFog((cell + float2(1.5, 1.5)) * _FantasyFogSize.zw, f.x*f.y, depth, fog, weight);
            fog = weight > .0001 ? fog / weight : float4(0, 0, 0, 1);
            float3 lit = source.rgb * fog.a + fog.rgb;
            return half4(lerp(source.rgb, lit, _AtmosphereLighting.w), source.a);
        }
        ENDHLSL
        Pass
        {
            Name "ShadowedAtmosphere"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment IntegrateFog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            ENDHLSL
        }
        Pass
        {
            Name "DepthAwareComposite"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment CompositeFog
            ENDHLSL
        }
    }
    Fallback Off
}
