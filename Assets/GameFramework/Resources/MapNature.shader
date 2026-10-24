// Small foliage casts no shadows. Depth and normal passes share the animated vertices.
Shader "ProjectY/Map Nature"
{
    Properties
    {
        _NatureTint ("Instance tint", Color) = (1,1,1,1)
        _NatureData ("Phase / wind / kind / radius", Vector) = (0,1,1,1)
        _NatureFade ("Distance fade", Range(0,1)) = 1
        _NaturePreviewTime ("Preview time (-1 follows Unity)", Float) = -1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" "Queue"="AlphaTest" }
        Cull Off
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
        CBUFFER_START(UnityPerMaterial)
            float _NatureFade;
            float _NaturePreviewTime;
        CBUFFER_END
        UNITY_INSTANCING_BUFFER_START(Nature)
            UNITY_DEFINE_INSTANCED_PROP(half4, _NatureTint)
            UNITY_DEFINE_INSTANCED_PROP(float4, _NatureData)
        UNITY_INSTANCING_BUFFER_END(Nature)
        struct NatureAttributes
        {
            float4 positionOS : POSITION;
            float3 normalOS : NORMAL;
            half4 color : COLOR;
            float2 uv : TEXCOORD0;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };
        struct NatureVaryings
        {
            float4 positionCS : SV_POSITION;
            float3 positionWS : TEXCOORD0;
            half3 normalWS : TEXCOORD1;
            half4 color : COLOR;
            half fog : TEXCOORD2;
            UNITY_VERTEX_INPUT_INSTANCE_ID
            UNITY_VERTEX_OUTPUT_STEREO
        };
        NatureVaryings NatureVertex(NatureAttributes input)
        {
            NatureVaryings output = (NatureVaryings)0;
            UNITY_SETUP_INSTANCE_ID(input);
            UNITY_TRANSFER_INSTANCE_ID(input, output);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
            float4 data = UNITY_ACCESS_INSTANCED_PROP(Nature, _NatureData);
            float time = _NaturePreviewTime < 0 ? _Time.y : _NaturePreviewTime;
            float phase = data.x;
            float3 position = input.positionOS.xyz;
            float3 normal = input.normalOS;
            if (data.z > 3.5 && data.z < 4.5 && abs(input.uv.x) > 0.5)
            {
                float flap = (sin(time * (12.0 + sin(phase) * 2.0) + phase) * 0.92 + 0.20) * input.uv.x;
                float s = sin(flap), c = cos(flap);
                position.xy = float2(c * position.x - s * position.y, s * position.x + c * position.y);
                normal.xy = float2(c * normal.x - s * normal.y, s * normal.x + c * normal.y);
            }
            float3 world = TransformObjectToWorld(position);
            if (data.z < 3.5)
            {
                float rootWeight = input.uv.y * input.uv.y;
                float sway = sin(time * 1.45 + phase + world.x * 0.15 + world.z * 0.12)
                    + sin(time * 2.61 + phase * 1.7 + world.z * 0.29) * 0.28;
                world.xz += float2(0.82, 0.57) * sway * rootWeight * data.y * data.w * 0.045;
            }
            else
            {
                // World-space flight stays within 0.18 cell radii, regardless of instance scale.
                float rate = data.z > 4.5 ? 1.35 : 1.0;
                float t = time * rate;
                world += float3(sin(t * 0.73 + phase) * 0.105 + sin(t * 1.37 + phase * 1.3) * 0.025,
                    sin(t * 1.13 + phase * 1.9) * 0.045,
                    cos(t * 0.91 + phase) * 0.095 + sin(t * 1.71 + phase * 0.7) * 0.020) * data.w;
            }
            output.positionWS = world;
            output.positionCS = TransformWorldToHClip(world);
            output.normalWS = TransformObjectToWorldNormal(normal);
            output.color = input.color;
            output.fog = ComputeFogFactor(output.positionCS.z);
            return output;
        }
        void NatureClip(float4 positionCS)
        {
            // The same screen-space coverage is used by color, depth and depth-normal passes.
            float dither = frac(52.9829189 * frac(dot(floor(positionCS.xy), float2(0.06711056, 0.00583715))));
            clip(_NatureFade - dither - 0.0001);
        }
        ENDHLSL
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForwardOnly" }
            ZWrite On
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex NatureVertex
            #pragma fragment NatureFragment
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "WorldFogSampling.hlsl"
            half4 NatureFragment(NatureVaryings input, FRONT_FACE_TYPE face : FRONT_FACE_SEMANTIC) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                NatureClip(input.positionCS);
                half3 normal = normalize(input.normalWS) * IS_FRONT_VFACE(face, 1.0, -1.0);
                half4 tint = UNITY_ACCESS_INSTANCED_PROP(Nature, _NatureTint);
                half3 albedo = input.color.rgb * lerp(half3(1,1,1), tint.rgb, input.color.a);
                #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
                    float4 shadow = ComputeScreenPos(TransformWorldToHClip(input.positionWS));
                #else
                    float4 shadow = TransformWorldToShadowCoord(input.positionWS);
                #endif
                Light mainLight = GetMainLight(shadow);
                half diffuse = saturate(dot(normal, mainLight.direction) * 0.72 + 0.28);
                half3 color = albedo * (SampleSH(normal) + mainLight.color * diffuse
                    * mainLight.distanceAttenuation * mainLight.shadowAttenuation);
                return half4(ApplyWorldFog(MixFog(color, input.fog),input.positionWS), 1);
            }
            ENDHLSL
        }
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode"="DepthOnly" }
            ZWrite On
            ColorMask R
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex NatureVertex
            #pragma fragment NatureDepth
            #pragma multi_compile_instancing
            half NatureDepth(NatureVaryings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                NatureClip(input.positionCS);
                return input.positionCS.z;
            }
            ENDHLSL
        }
        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode"="DepthNormalsOnly" }
            ZWrite On
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex NatureVertex
            #pragma fragment NatureDepthNormals
            #pragma multi_compile_instancing
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            half4 NatureDepthNormals(NatureVaryings input, FRONT_FACE_TYPE face : FRONT_FACE_SEMANTIC) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                NatureClip(input.positionCS);
                half3 normal = normalize(input.normalWS) * IS_FRONT_VFACE(face, 1.0, -1.0);
                #if defined(_GBUFFER_NORMALS_OCT)
                    float2 encoded = PackNormalOctQuadEncode(normal);
                    return half4(PackFloat2To888(saturate(encoded * 0.5 + 0.5)), 0);
                #else
                    return half4(normal, 0);
                #endif
            }
            ENDHLSL
        }
    }
    Fallback Off
}
