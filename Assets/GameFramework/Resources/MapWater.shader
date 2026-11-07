// 共享水面、水幕、落点泡沫和水花材质。水面只改变着色，保持六边形接缝处的几何不动。
Shader "ProjectY/Map Water"
{
    Properties
    {
        _Color ("Color", Color) = (0.20, 0.45, 0.57, 1)
        _FlowTex ("Seamless flow noise (RGBA)", 2D) = "gray" {}
        [HideInInspector] _WaterBoundaryField ("Coverage / elevation / shore / optical depth", 2D) = "black" {}
        _WaterMode ("Mode: surface / curtain / foam / particle", Float) = 0
        _WaterScale ("Cell radius / world pattern scale", Float) = 1
        [HideInInspector] _WaterPreviewTime ("Preview time (-1 uses game time)", Float) = -1
        [HideInInspector] _WaterFlow ("Flow XZ / river intensity / relative depth", Vector) = (0, 1, 0, 0.2)
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Source blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Destination blend", Float) = 0
        [Toggle] _ZWrite ("Depth write", Float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 200
        Cull Back

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
        CBUFFER_START(UnityPerMaterial)
            float _WaterMode;
            float _WaterScale;
            float _WaterPreviewTime;
        CBUFFER_END
        TEXTURE2D(_FlowTex);
        SAMPLER(sampler_FlowTex);
        // 与原地图批次的 _Color 数组保持相同契约；xy 是世界 XZ 流向。
        UNITY_INSTANCING_BUFFER_START(Props)
            UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
            UNITY_DEFINE_INSTANCED_PROP(float4, _WaterFlow)
        UNITY_INSTANCING_BUFFER_END(Props)

        struct WaterAttributes
        {
            float4 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float2 uv : TEXCOORD0;
            half4 color : COLOR;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct WaterDepthVaryings
        {
            float4 positionCS : SV_POSITION;
            half3 normalWS : TEXCOORD0;
            UNITY_VERTEX_INPUT_INSTANCE_ID
            UNITY_VERTEX_OUTPUT_STEREO
        };

        WaterDepthVaryings WaterDepthVertex(WaterAttributes input)
        {
            WaterDepthVaryings output = (WaterDepthVaryings)0;
            UNITY_SETUP_INSTANCE_ID(input);
            UNITY_TRANSFER_INSTANCE_ID(input, output);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
            output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
            output.normalWS = TransformObjectToWorldNormal(input.normalOS);
            return output;
        }
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForwardOnly" }
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            ZTest LEqual
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex WaterVertex
            #pragma fragment WaterFragment
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile _ _FORWARD_PLUS
            // 保留环境漫反射和主光高光，不采样反射探针、屏幕反射或深度纹理。
            #define _ENVIRONMENTREFLECTIONS_OFF 1
            #include "MapWeatherLighting.hlsl"
        #include "WorldFogSampling.hlsl"
            #include "MapWaterSurface.hlsl"

            struct WaterVaryings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                half3 normalWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
                half4 fogAndVertexLight : TEXCOORD3;
                float2 localXZ : TEXCOORD4;
                half4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            WaterVaryings WaterVertex(WaterAttributes input)
            {
                WaterVaryings output = (WaterVaryings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                VertexPositionInputs position = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = position.positionCS;
                output.positionWS = position.positionWS;
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.uv = input.uv;
                output.localXZ = input.positionOS.xz;
                output.color = input.color;
                output.fogAndVertexLight = half4(ComputeFogFactor(position.positionCS.z),
                    VertexLighting(position.positionWS, output.normalWS));
                return output;
            }

            float4 AdvectWater(float2 p, float time, float2 velocity, float phaseOffset)
            {
                // 两个相隔半周期的平流层分别采样再混合；重置时权重和导数均为零。
                // 有限平流时间避免图案无限拉长，换周期时改变取样区域以生成新细节。
                float clock = time / 5.7 + phaseOffset;
                float phaseA = frac(clock), phaseB = frac(clock + 0.5);
                float weight = sin(3.14159265 * phaseA); weight *= weight;
                float2 jump = float2(0.371, 0.619);
                float2 uvA = (p - velocity * (phaseA * 5.7)) * 0.43 + floor(clock) * jump;
                float2 uvB = (p - velocity * (phaseB * 5.7)) * 0.43 + floor(clock + 0.5) * jump;
                // frac 的空间重置不参与纹理LOD，避免过零处出现模糊细带。
                float2 dx = ddx(p), dy = ddy(p), vx = ddx(velocity), vy = ddy(velocity);
                float cx = ddx(clock), cy = ddy(clock);
                float2 ax = (dx - 5.7 * (phaseA * vx + velocity * cx)) * 0.43;
                float2 ay = (dy - 5.7 * (phaseA * vy + velocity * cy)) * 0.43;
                float2 bx = (dx - 5.7 * (phaseB * vx + velocity * cx)) * 0.43;
                float2 by = (dy - 5.7 * (phaseB * vy + velocity * cy)) * 0.43;
                float4 a = SAMPLE_TEXTURE2D_GRAD(_FlowTex, sampler_FlowTex, uvA, ax, ay);
                float4 b = SAMPLE_TEXTURE2D_GRAD(_FlowTex, sampler_FlowTex, uvB, bx, by);
                return a * weight + b * (1.0 - weight);
            }

            half4 WaterFragment(WaterVaryings input, FRONT_FACE_TYPE frontFace : FRONT_FACE_SEMANTIC) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                half4 tint = UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
                float4 flow = UNITY_ACCESS_INSTANCED_PROP(Props, _WaterFlow);
                float time = _WaterPreviewTime >= 0 ? _WaterPreviewTime : _Time.y;
                float scale = max(_WaterScale, 0.001);
                half3 normal = NormalizeNormalPerPixel(input.normalWS)
                    * IS_FRONT_VFACE(frontFace, 1.0, -1.0);
                half3 albedo = tint.rgb;
                half alpha = tint.a;
                half smoothness = 0.28;

                if (_WaterMode < 0.5)
                {
                    float2 p = input.positionWS.xz / scale;
                    float4 boundary = WaterBoundary(input.positionWS.xz);
                    float depth = _WaterBoundaryEnabled > .5 ? boundary.a : max(0,flow.w);
                    half3 water = StylizedWater(input.positionWS, scale, time, boundary.b, depth);
                    // Retain a subtle downstream signal inside river cells, fading to the shared ocean pattern at seams.
                    float2 local = input.localXZ;
                    float edgeDistance = max(abs(local.x), max(abs(dot(local, float2(.5,.8660254))),
                        abs(dot(local, float2(.5,-.8660254)))));
                    float river = saturate(flow.z) * (1-smoothstep(.57,.865,edgeDistance));
                    if (river > .001 && max(fwidth(p.x),fwidth(p.y)) < .7)
                    {
                        float2 direction = normalize(flow.xy + float2(.00001,0));
                        float4 carried = AdvectWater(p,time,direction*.31,0);
                        water *= 1 + (carried.g-.5)*.04*river;
                    }
                    water = MixFog(water,input.fogAndVertexLight.x);
                    return half4(ApplyWorldFog(water,input.positionWS),1);
                }
                else if (_WaterMode < 1.5)
                {
                    // 水幕 UV：y=0 为底部，y=1 为顶部；正向采样位移表现为向下流动。
                    float seed = dot(input.positionWS.xz / scale, float2(0.071, 0.053));
                    float4 curtainWarp = SAMPLE_TEXTURE2D(_FlowTex, sampler_FlowTex,
                        float2(input.uv.x * 0.29 + seed, input.uv.y * 0.08 + time * 0.07));
                    float sideways = (curtainWarp.r - 0.5) * 0.18;
                    float4 falling = SAMPLE_TEXTURE2D(_FlowTex, sampler_FlowTex,
                        float2(input.uv.x * 1.25 + sideways + seed,
                            input.uv.y * 0.17 + time * 0.39));
                    float4 spray = SAMPLE_TEXTURE2D(_FlowTex, sampler_FlowTex,
                        float2(input.uv.x * 2.75 + sideways * 0.6 + seed + 0.23,
                            input.uv.y * 0.38 + time * 0.63));
                    // 宽窄不一的实心水束取代细密的噪声等高线。
                    float ribbons = smoothstep(0.35, 0.68, falling.r);
                    float smallStreams = smoothstep(0.47, 0.70, spray.g) * ribbons;
                    float sideFade = smoothstep(0.0, 0.07, input.uv.x)
                        * (1.0 - smoothstep(0.93, 1.0, input.uv.x));
                    float bottomFoam = (1.0 - smoothstep(0.015, 0.36,
                        input.uv.y + (spray.a - 0.5) * 0.16)) * (0.72 + falling.b * 0.28);
                    float topFoam = smoothstep(0.69, 0.99,
                        input.uv.y + (falling.b - 0.5) * 0.12) * (0.75 + spray.r * 0.25);
                    albedo *= 0.87 + falling.a * 0.17;
                    albedo = lerp(albedo, half3(0.75, 0.86, 0.86), saturate(
                        (ribbons * 0.19 + smallStreams * 0.12) * sideFade
                        + bottomFoam * 0.54 + topFoam * 0.38));
                    smoothness = 0.16;
                }
                else if (_WaterMode < 2.5)
                {
                    float2 centered = input.uv * 2.0 - 1.0;
                    float2 p = input.positionWS.xz / scale;
                    float4 foamWarp = SAMPLE_TEXTURE2D(_FlowTex, sampler_FlowTex,
                        p * 0.31 + float2(-0.024, 0.017) * time);
                    float4 foam = SAMPLE_TEXTURE2D(_FlowTex, sampler_FlowTex,
                        p * 1.17 + (foamWarp.rg - 0.5) * 0.46 + float2(-0.065, 0.049) * time);
                    float4 bubbles = SAMPLE_TEXTURE2D(_FlowTex, sampler_FlowTex,
                        p * 2.13 + (foam.ba - 0.5) * 0.17 + float2(0.041, -0.033) * time);
                    float2 warpedCenter = centered + (foamWarp.rg - 0.5) * 0.30
                        + (foam.ba - 0.5) * 0.14;
                    float radius = length(warpedCenter);
                    // 仅一至两层破碎扩散弧，半径、相位和开口都由噪声扰动。
                    float arcPhase = radius * 1.65 - time * 0.43
                        + (foamWarp.b - 0.5) * 0.67 + (foam.g - 0.5) * 0.22;
                    float arcs = 1.0 - smoothstep(0.035, 0.12 + fwidth(arcPhase),
                        abs(frac(arcPhase) - 0.5));
                    float arcBreakup = smoothstep(0.43, 0.64, foam.a)
                        * smoothstep(0.39, 0.59, bubbles.b);
                    float froth = smoothstep(0.36, 0.63,
                        bubbles.r + (foam.g - 0.5) * 0.25);
                    float edge = 1.0 - smoothstep(0.45, 1.0,
                        radius + (bubbles.a - 0.5) * 0.15);
                    // 最外沿始终归零，噪声只改变内部轮廓，避免任何矩形贴片边界。
                    edge *= (1.0 - smoothstep(0.78, 1.0, abs(centered.x)))
                        * (1.0 - smoothstep(0.78, 1.0, abs(centered.y)));
                    float centralFoam = 1.0 - smoothstep(0.05, 0.66, radius);
                    alpha *= edge * (0.07 + arcs * arcBreakup * 0.27
                        + froth * 0.44 + centralFoam * 0.12);
                    albedo = lerp(tint.rgb, half3(0.78, 0.87, 0.87), 0.55 + bubbles.g * 0.12);
                    smoothness = 0.10;
                }
                else
                {
                    float2 centered = input.uv * 2.0 - 1.0;
                    float radiusSq = dot(centered, centered);
                    float droplet = 1.0 - smoothstep(0.14, 1.0, radiusSq);
                    alpha *= input.color.a * droplet * droplet;
                    albedo *= input.color.rgb;
                    smoothness = 0.12;
                }

                SurfaceData surface = (SurfaceData)0;
                surface.albedo = albedo;
                surface.metallic = 0;
                surface.smoothness = smoothness;
                surface.normalTS = half3(0, 0, 1);
                surface.occlusion = 1;
                surface.alpha = alpha;
                InputData lighting = (InputData)0;
                lighting.positionWS = input.positionWS;
                lighting.normalWS = normal;
                lighting.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
                    lighting.shadowCoord = ComputeScreenPos(TransformWorldToHClip(input.positionWS));
                #else
                    lighting.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                #endif
                lighting.bakedGI = SampleSH(normal);
                lighting.vertexLighting = input.fogAndVertexLight.yzw;
                lighting.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                lighting.shadowMask = half4(1, 1, 1, 1);
                half4 result = ProjectYWeatherFragmentPBR(lighting, surface);
                result.rgb = MixFog(result.rgb, input.fogAndVertexLight.x);
                result.rgb = ApplyWorldFog(result.rgb, input.positionWS);
                result.a = alpha;
                return result;
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode"="DepthOnly" }
            ZWrite [_ZWrite]
            ColorMask R
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex WaterDepthVertex
            #pragma fragment WaterDepthFragment
            #pragma multi_compile_instancing
            half WaterDepthFragment(WaterDepthVaryings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                // 透明泡沫和粒子即使误进入深度队列，也不能把矩形写入深度图。
                clip(1.5 - _WaterMode);
                return input.positionCS.z;
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode"="DepthNormalsOnly" }
            ZWrite [_ZWrite]
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex WaterDepthVertex
            #pragma fragment WaterDepthNormalsFragment
            #pragma multi_compile_instancing
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            half4 WaterDepthNormalsFragment(WaterDepthVaryings input,
                FRONT_FACE_TYPE frontFace : FRONT_FACE_SEMANTIC) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                clip(1.5 - _WaterMode);
                half3 normal = normalize(input.normalWS) * IS_FRONT_VFACE(frontFace, 1.0, -1.0);
                #if defined(_GBUFFER_NORMALS_OCT)
                    float2 octNormal = PackNormalOctQuadEncode(normal);
                    half3 packedNormal = PackFloat2To888(saturate(octNormal * 0.5 + 0.5));
                    return half4(packedNormal, 0.0);
                #else
                    return half4(normal, 0.0);
                #endif
            }
            ENDHLSL
        }
    }
    Fallback Off
}
