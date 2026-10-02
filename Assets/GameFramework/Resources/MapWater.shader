// 共享水面、水幕、落点泡沫和水花材质。水面只改变着色，保持六边形接缝处的几何不动。
Shader "ProjectY/Map Water"
{
    Properties
    {
        _Color ("Color", Color) = (0.20, 0.45, 0.57, 1)
        _FlowTex ("Seamless flow noise (RGBA)", 2D) = "gray" {}
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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

            float WaterHash(float2 cell)
            {
                float3 q = frac(float3(cell.x, cell.y, cell.x) * 0.1031);
                q += dot(q, q.yzx + 33.33);
                return frac((q.x + q.y) * q.z);
            }

            // 五次插值的随机势函数及解析梯度：不需要四次贴图差分求流场。
            float3 WaterPotential(float2 p)
            {
                float2 cell = floor(p), f = frac(p);
                float2 u = f*f*f*(f*(f*6.0-15.0)+10.0);
                float2 du = 30.0*f*f*(f*(f-2.0)+1.0);
                float a = WaterHash(cell), b = WaterHash(cell+float2(1,0));
                float c = WaterHash(cell+float2(0,1)), d = WaterHash(cell+1);
                float mixed = a-b-c+d;
                return float3(a+(b-a)*u.x+(c-a)*u.y+mixed*u.x*u.y,
                    (b-a+mixed*u.y)*du.x, (c-a+mixed*u.x)*du.y);
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

            // 有限支撑的随机波包：每处波峰有独立寿命、方向、波长，并在消散后换代。
            // 支撑半径为一个格点间距，四个邻格点足够；边界的波高和导数同时归零。
            float3 WaterPacket(float2 q, float2 node, float time)
            {
                float seed = WaterHash(node);
                float lifetime = 4.5 + frac(seed * 19.31) * 4.0;
                float clock = (time + seed * 17.0) / lifetime;
                float age = frac(clock);
                float generation = WaterHash(node + floor(clock) * float2(19.1, 7.7) + 43.6);
                float angle = generation * 6.2831853;
                float2 direction = float2(cos(angle), sin(angle));
                float frequency = 7.0 + frac(generation * 13.7) * 6.0;
                float2 r = q - node;
                float support = saturate(1.0 - dot(r, r));
                float envelope = support * support * support;
                float life = 16.0 * age * age * (1.0 - age) * (1.0 - age);
                float amplitude = (0.025 + frac(generation * 7.3) * 0.016) * life;
                float phase = frequency * dot(r, direction)
                    - time * (2.5 + generation * 2.2) + seed * 6.2831853;
                float wave = sin(phase), slope = cos(phase);
                float2 gradient = -6.0 * r * support * support * wave
                    + envelope * frequency * direction * slope;
                // q 的格点间距为1.45格半径，斜率须换回p坐标。
                return float3(amplitude * envelope * wave, amplitude * gradient / 1.45);
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
                    float3 potentialA = WaterPotential(p * 0.39 + float2(0.037, -0.021) * time);
                    float3 potentialB = WaterPotential(p * 0.83 + float2(-0.026, 0.043) * time + 19.7);
                    // 势函数梯度旋转90度形成curl；不同尺度以不同方向演化，产生局部旋转与变速。
                    float2 curl = float2(potentialA.z, -potentialA.y) * 0.075
                        + float2(potentialB.z, -potentialB.y) * 0.032;
                    float2 velocity = float2(0.055, 0.028) + curl;
                    float directionLengthSq = dot(flow.xy, flow.xy);
                    float2 direction = directionLengthSq > 0.0001
                        ? flow.xy * rsqrt(directionLengthSq) : float2(0.0, 1.0);
                    // 当前流向是每格常量，在共边渐变回连续全局流场，避免弯道露出六边形拼缝。
                    float2 local = input.localXZ;
                    float edgeDistance = max(abs(local.x), max(abs(dot(local, float2(0.5, 0.8660254))),
                        abs(dot(local, float2(0.5, -0.8660254)))));
                    float river = saturate(flow.z) * (1.0 - smoothstep(0.57, 0.865, edgeDistance));
                    float4 carried = AdvectWater(p, time, velocity, potentialA.x * 0.31);
                    float4 riverCarried = AdvectWater(p, time, velocity + direction * 0.31,
                        potentialA.x * 0.31);
                    carried = lerp(carried, riverCarried, river * 0.72);
                    float2 warped = p + potentialA.yz * 0.12 + potentialB.yz * 0.055;
                    float2 q = (warped - float2(0.043, 0.019) * time) / 1.45;
                    float2 node = floor(q);
                    float3 waves = WaterPacket(q, node, time)
                        + WaterPacket(q, node+float2(1,0), time)
                        + WaterPacket(q, node+float2(0,1), time)
                        + WaterPacket(q, node+1, time);
                    // 河道追加沿实际下游运动的短波，只在河格内部增强，避免边界不连续。
                    float riverPhase = dot(warped, direction) * 9.7 - time * 5.6 + carried.a * 3.1;
                    float riverAmplitude = river * 0.012 * smoothstep(0.28, 0.73, carried.g);
                    waves += float3(sin(riverPhase) * riverAmplitude,
                        direction * cos(riverPhase) * riverAmplitude * 9.7);
                    float detail = 1.0 - smoothstep(0.05, 0.38, max(fwidth(p.x), fwidth(p.y)));
                    float top = smoothstep(0.45, 0.9, normal.y);
                    float crest = smoothstep(0.007, 0.027, waves.x)
                        * smoothstep(0.25, 0.65, carried.b) * detail * top;
                    albedo *= 0.98 + (carried.r - 0.5) * 0.11 + waves.x * detail * 0.75;
                    albedo = lerp(albedo, half3(0.65, 0.82, 0.83), crest * 0.32);
                    albedo *= 1.0 - saturate(flow.w) * 0.025;
                    // 波面斜率驱动光照起伏，主要运动来自明暗和波峰变化，而非画在水面的白线。
                    normal = normalize(normal + half3(-waves.y, 0, -waves.z) * detail * top);
                    smoothness = 0.43;
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
                half4 result = UniversalFragmentPBR(lighting, surface);
                result.rgb = MixFog(result.rgb, input.fogAndVertexLight.x);
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
