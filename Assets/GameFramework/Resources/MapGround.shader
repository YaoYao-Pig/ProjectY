// 大地图专用地表：真实纹理以世界坐标跨格连续采样，地块轮廓和共享模型保持不变。
Shader "ProjectY/Map Ground"
{
    Properties
    {
        _Color ("Instance ground color", Color) = (1, 1, 1, 1)
        _GroundTextures ("Biome ground textures", 2DArray) = "" {}
        _TileRadius ("World tile radius", Float) = 1
        _CliffLayer ("Rock texture layer", Float) = 1
        [HideInInspector] _GroundData ("Primary / secondary / blend / dry", Vector) = (0, 0, 0, 1)
        [HideInInspector] _GroundPreviewTime ("Preview time (-1 uses game time)", Float) = -1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 200
        Cull Back
        ZWrite On

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
        CBUFFER_START(UnityPerMaterial)
            float _TileRadius;
            float _CliffLayer;
            float _GroundPreviewTime;
            // x: texture size in tile radii; y: detail strength; z: wind strength.
            float4 _LayerData[16];
            float4 _LayerTint[16];
        CBUFFER_END
        TEXTURE2D_ARRAY(_GroundTextures);
        SAMPLER(sampler_GroundTextures);
        UNITY_INSTANCING_BUFFER_START(Props)
            UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
            UNITY_DEFINE_INSTANCED_PROP(float4, _GroundData)
        UNITY_INSTANCING_BUFFER_END(Props)
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForwardOnly" }
            HLSLPROGRAM
            #pragma target 3.5
            #pragma require 2darray
            #pragma vertex GroundVertex
            #pragma fragment GroundFragment
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile _ _FORWARD_PLUS
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "WorldFogSampling.hlsl"

            struct GroundAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct GroundVaryings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                half3 normalWS : TEXCOORD1;
                half4 fogAndVertexLight : TEXCOORD2;
                float surfaceDepth : TEXCOORD3;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            GroundVaryings GroundVertex(GroundAttributes input)
            {
                GroundVaryings output = (GroundVaryings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                VertexPositionInputs position = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = position.positionCS;
                output.positionWS = position.positionWS;
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                // 地块模型顶面在局部 Y=0；换算成世界格半径，不随柱体高度拉伸上沿过渡带。
                output.surfaceDepth = max(0.0, TransformObjectToWorld(float3(0, 0, 0)).y - position.positionWS.y)
                    / max(_TileRadius, 0.001);
                output.fogAndVertexLight = half4(ComputeFogFactor(position.positionCS.z),
                    VertexLighting(position.positionWS, output.normalWS));
                return output;
            }

            float3 GroundHash(float2 coordinate)
            {
                float3 value = frac(float3(coordinate.x, coordinate.y, coordinate.x) * float3(0.1031, 0.1030, 0.0973));
                value += dot(value, value.yxz + 33.33);
                return frac((value.xxy + value.yzz) * value.zyx);
            }

            float GroundMacro(float2 p)
            {
                float2 cell = floor(p), f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                float a = GroundHash(cell).x;
                float b = GroundHash(cell + float2(1, 0)).x;
                float c = GroundHash(cell + float2(0, 1)).x;
                float d = GroundHash(cell + 1.0).x;
                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }

            float2 GroundRotate(float2 p, float2 rotation)
            {
                return float2(rotation.x * p.x - rotation.y * p.y,
                    rotation.y * p.x + rotation.x * p.y);
            }

            half3 GroundNodeSample(float2 uv, float2 dx, float2 dy, float2 node, int layer)
            {
                float3 random = GroundHash(node + float2(17.19, 7.73) * layer);
                // 四个随机直角旋转搭配独立偏移，不需要每次采样计算三角函数。
                int turn = (int)(random.z * 4.0);
                float2 rotation = float2(turn == 0 ? 1.0 : (turn == 2 ? -1.0 : 0.0),
                    turn == 1 ? 1.0 : (turn == 3 ? -1.0 : 0.0));
                float2 sampleUV = GroundRotate(uv, rotation) + random.xy;
                // 只旋转连续坐标的导数，不能对随机格点索引或偏移求导。
                return SAMPLE_TEXTURE2D_ARRAY_GRAD(_GroundTextures, sampler_GroundTextures,
                    sampleUV, layer, GroundRotate(dx, rotation), GroundRotate(dy, rotation)).rgb;
            }

            half3 GroundTexture(int layer, float2 position, float2 dx, float2 dy, out float detailFade)
            {
                float textureSize = max(_LayerData[layer].x * _TileRadius, 0.001);
                float2 uv = position / textureSize;
                dx /= textureSize; dy /= textureSize;
                float footprint = max(length(dx), length(dy));
                detailFade = 1.0 - smoothstep(0.025, 0.18, footprint);
                // 将等边三角格斜投影到整数网格，每个三角只采三个共享格点。
                float2 grid = float2(uv.x - uv.y * 0.57735027, uv.y * 1.15470054);
                float2 cell = floor(grid), f = frac(grid);
                float2 node0, node1, node2;
                float3 weights;
                if (f.x + f.y <= 1.0)
                {
                    node0 = cell;
                    node1 = cell + float2(1, 0);
                    node2 = cell + float2(0, 1);
                    weights = float3(1.0 - f.x - f.y, f.x, f.y);
                }
                else
                {
                    node0 = cell + 1.0;
                    node1 = cell + float2(0, 1);
                    node2 = cell + float2(1, 0);
                    weights = float3(f.x + f.y - 1.0, 1.0 - f.x, 1.0 - f.y);
                }
                weights *= weights;
                weights /= dot(weights, float3(1, 1, 1));
                return GroundNodeSample(uv, dx, dy, node0, layer) * weights.x
                    + GroundNodeSample(uv, dx, dy, node1, layer) * weights.y
                    + GroundNodeSample(uv, dx, dy, node2, layer) * weights.z;
            }

            half3 GroundTextureDetail(half3 sampled, int layer, float detailFade)
            {
                half3 reference = max(_LayerTint[layer].rgb, half3(0.015, 0.015, 0.015));
                const half3 luminanceWeights = half3(0.2126, 0.7152, 0.0722);
                half value = dot(sampled, luminanceWeights);
                half referenceValue = dot(reference, luminanceWeights);
                // 相对配置色压缩亮度差；源图的平均亮度不会把整片地貌推成黑色或白色。
                half luminanceRatio = 1.0 + 0.38 * (value - referenceValue)
                    / (value + referenceValue + 0.035);
                half3 chroma = sampled / max(value, 0.035);
                half3 referenceChroma = reference / max(referenceValue, 0.035);
                half3 chromaRatio = 1.0 + 0.15 * (chroma - referenceChroma)
                    / (chroma + referenceChroma + 0.08);
                half3 relative = clamp(luminanceRatio * chromaRatio, 0.68, 1.35);
                return lerp(half3(1, 1, 1), relative, saturate(_LayerData[layer].y) * detailFade);
            }

            half3 GroundTop(float3 positionWS, float3 dx, float3 dy, float4 data,
                half3 color, float macro, float time)
            {
                int primary = (int)(data.x + 0.5);
                int secondary = (int)(data.y + 0.5);
                float blend = saturate(data.z);
                if (blend >= 0.999)
                {
                    primary = secondary;
                    blend = 0.0;
                }
                float detailFade;
                half3 sampled = GroundTexture(primary, positionWS.xz, dx.xz, dy.xz, detailFade);
                half3 relative = GroundTextureDetail(sampled, primary, detailFade);
                float wind = saturate(_LayerData[primary].z);
                if (blend > 0.001 && primary != secondary)
                {
                    float otherFade;
                    half3 otherSample = GroundTexture(secondary, positionWS.xz, dx.xz, dy.xz, otherFade);
                    half3 otherRelative = GroundTextureDetail(otherSample, secondary, otherFade);
                    // 主次交换时统一斑块方向，让同一对地貌共享同一片世界纹理过渡。
                    float blendOffset = (macro - 0.5) * 0.32 * (4.0 * blend * (1.0 - blend))
                        * (primary < secondary ? 1.0 : -1.0) * min(detailFade, otherFade);
                    float patchedBlend = saturate(blend + blendOffset);
                    half3 reference = lerp(_LayerTint[primary].rgb, _LayerTint[secondary].rgb, blend);
                    half3 textured = lerp(_LayerTint[primary].rgb * relative,
                        _LayerTint[secondary].rgb * otherRelative, patchedBlend);
                    relative = clamp(textured / max(reference, half3(0.015, 0.015, 0.015)), 0.68, 1.35);
                    wind = lerp(wind, saturate(_LayerData[secondary].z), patchedBlend);
                    detailFade = lerp(detailFade, otherFade, patchedBlend);
                }
                half3 albedo = color * relative * (0.97 + macro * 0.06);
                float dry = saturate(data.w);
                if (wind > 0.001 && dry > 0.001)
                {
                    float2 p = positionWS.xz / max(_TileRadius, 0.001);
                    float gust = sin(dot(p, float2(0.73, 0.41)) - time * 0.61 + macro * 1.7) * 0.6
                        + sin(dot(p, float2(-0.29, 0.57)) - time * 0.43) * 0.4;
                    // 草与林只改变极轻的明暗，石头和积雪的图案始终固定。
                    albedo *= 1.0 + gust * 0.028 * wind * dry * detailFade;
                }
                return albedo * lerp(0.90, 1.0, dry);
            }

            half3 GroundCliff(float3 positionWS, float3 dx, float3 dy, half3 normal,
                half3 color, float surfaceDepth)
            {
                int layer = (int)(_CliffLayer + 0.5);
                bool alongX = abs(normal.x) > abs(normal.z);
                float2 position = alongX ? positionWS.zy : positionWS.xy;
                float2 planeDx = alongX ? dx.zy : dx.xy;
                float2 planeDy = alongX ? dy.zy : dy.xy;
                float detailFade;
                half3 sampled = GroundTexture(layer, position, planeDx, planeDy, detailFade);
                half3 relative = GroundTextureDetail(sampled, layer, detailFade);
                half3 stone = _LayerTint[layer].rgb * half3(0.78, 0.71, 0.63);
                half3 cliffColor = lerp(color, stone, 0.80);
                // 保留硬边法线，仅柔化顶沿的色彩过渡；垂直面仍只显示岩土纹理。
                float rim = 1.0 - smoothstep(0.0, 0.18, surfaceDepth);
                cliffColor = lerp(cliffColor, color, rim * 0.72);
                return cliffColor * relative;
            }

            half4 GroundFragment(GroundVaryings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                half4 color = UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
                float4 data = UNITY_ACCESS_INSTANCED_PROP(Props, _GroundData);
                half3 normal = NormalizeNormalPerPixel(input.normalWS);
                // 在依赖法线的分支之前取导数，所有投影、图层和随机旋转复用同一组导数。
                float3 dx = ddx(input.positionWS), dy = ddy(input.positionWS);
                float topWeight = smoothstep(0.36, 0.78, normal.y);
                half3 albedo = 0;
                if (topWeight > 0.0)
                {
                    float macro = GroundMacro(input.positionWS.xz / max(_TileRadius, 0.001) * 0.16);
                    float time = _GroundPreviewTime >= 0.0 ? _GroundPreviewTime : _Time.y;
                    albedo = GroundTop(input.positionWS, dx, dy, data, color.rgb, macro, time) * topWeight;
                }
                if (topWeight < 1.0)
                {
                    // 纯侧面仅采岩土三次；只有实际坡面过渡带同时计算顶面和侧面。
                    albedo += GroundCliff(input.positionWS, dx, dy, normal, color.rgb, input.surfaceDepth)
                        * (1.0 - topWeight);
                }

                SurfaceData surface = (SurfaceData)0;
                surface.albedo = albedo;
                surface.metallic = 0;
                surface.smoothness = lerp(0.065, 0.11, topWeight);
                surface.normalTS = half3(0, 0, 1);
                surface.occlusion = 1;
                surface.alpha = 1;
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
                result.rgb = ApplyWorldFog(result.rgb, input.positionWS);
                result.a = 1;
                return result;
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On ZTest LEqual ColorMask 0
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #pragma multi_compile_instancing
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode"="DepthOnly" }
            ZWrite On ColorMask R
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            #pragma multi_compile_instancing
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode"="DepthNormalsOnly" }
            ZWrite On
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment
            #pragma multi_compile_instancing
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthNormalsPass.hlsl"
            ENDHLSL
        }
    }
    Fallback Off
}
