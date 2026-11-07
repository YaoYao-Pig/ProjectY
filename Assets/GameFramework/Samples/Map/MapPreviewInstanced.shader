// 地图共享的哑光材质；地表图案使用世界米制尺寸，远景自动淡出细缝以减轻闪烁。
Shader "ProjectY/Map Preview Instanced"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        [HDR] _EmissionColor ("Emission", Color) = (0,0,0,0)
        _Metallic ("Metallic", Range(0,1)) = 0
        _Smoothness ("Smoothness", Range(0,1)) = .08
        _UseVertexColor ("Vertex color", Float) = 0
        _UseSurfacePattern ("Surface pattern", Float) = 0
        _DetailPattern ("Model surface detail", Vector) = (0,1,0,0)
        _DetailRelief ("Model relief metres", Float) = .025
        _SurfaceRelief ("Terrain relief metres", Float) = .03
        _BaseMap ("Base map", 2D) = "white" {}
        _BumpMap ("Normal map", 2D) = "bump" {}
        _MetallicGlossMap ("Metallic smoothness", 2D) = "white" {}
        _MaterialMaps ("Map flags and bump scale", Vector) = (0,0,1,0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 200
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
        CBUFFER_START(UnityPerMaterial)
            half _Metallic, _Smoothness;
            float _UseVertexColor, _UseSurfacePattern, _DetailRelief, _SurfaceRelief;
            float4 _DetailPattern, _BaseMap_ST, _MaterialMaps;
        CBUFFER_END
        // Keep the existing CPU property-block contract for instanced map batches.
        UNITY_INSTANCING_BUFFER_START(Props)
            UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
            UNITY_DEFINE_INSTANCED_PROP(half4, _EmissionColor)
            UNITY_DEFINE_INSTANCED_PROP(float4, _SurfaceData)
            UNITY_DEFINE_INSTANCED_PROP(float4, _SurfaceFinish)
        UNITY_INSTANCING_BUFFER_END(Props)
        TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
        TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);
        TEXTURE2D(_MetallicGlossMap); SAMPLER(sampler_MetallicGlossMap);
        #include "MapSurfaceDetail.hlsl"
        ENDHLSL
        Pass
        {
        Name "ForwardLit"
        Tags { "LightMode"="UniversalForwardOnly" }
        HLSLPROGRAM
        #pragma vertex vert
        #pragma fragment frag
        #pragma target 3.5
        #pragma multi_compile_instancing
        #pragma multi_compile_fog
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
        #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile_fragment _ _SHADOWS_SOFT
        #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
        #pragma multi_compile _ _FORWARD_PLUS
        #include "../../Resources/MapWeatherLighting.hlsl"
        #include "../../Resources/WorldFogSampling.hlsl"
        struct Attributes
        {
            float4 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
            float2 uv : TEXCOORD0;
            half4 color : COLOR;
            float4 surfaceData : TEXCOORD1;
            float4 finish : TEXCOORD2;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };
        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float3 worldPos : TEXCOORD0;
            float3 worldNormal : TEXCOORD1;
            float4 surfaceData : TEXCOORD2;
            float4 finish : TEXCOORD3;
            half4 fogAndVertexLight : TEXCOORD4;
            half4 color : COLOR;
            float3 objectPos : TEXCOORD5;
            float3 objectNormal : TEXCOORD6;
            float4 tangentWS : TEXCOORD7;
            float2 uv : TEXCOORD8;
            UNITY_VERTEX_INPUT_INSTANCE_ID
            UNITY_VERTEX_OUTPUT_STEREO
        };
        Varyings vert(Attributes v)
        {
            Varyings o = (Varyings)0;
            UNITY_SETUP_INSTANCE_ID(v);
            UNITY_TRANSFER_INSTANCE_ID(v, o);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
            VertexPositionInputs position = GetVertexPositionInputs(v.positionOS.xyz);
            o.positionCS = position.positionCS;
            o.worldPos = position.positionWS;
            o.objectPos = v.positionOS.xyz; o.objectNormal = v.normalOS;
            o.tangentWS = float4(TransformObjectToWorldDir(v.tangentOS.xyz), v.tangentOS.w * GetOddNegativeScale());
            o.uv = v.uv * _BaseMap_ST.xy + _BaseMap_ST.zw;
            o.worldNormal = TransformObjectToWorldNormal(v.normalOS);
            o.color = v.color;
            o.surfaceData = v.surfaceData; o.finish = v.finish;
            o.fogAndVertexLight = half4(ComputeFogFactor(position.positionCS.z), VertexLighting(o.worldPos, o.worldNormal));
            return o;
        }
        half4 frag(Varyings IN) : SV_Target
        {
            UNITY_SETUP_INSTANCE_ID(IN);
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
            SurfaceData o = (SurfaceData)0;
            half4 color = UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
            color = lerp(color, IN.color, _UseVertexColor);
            o.albedo = color.rgb;
            float4 data = _UseSurfacePattern > 1.5 ? UNITY_ACCESS_INSTANCED_PROP(Props, _SurfaceData) : IN.surfaceData;
            float4 finish = _UseSurfacePattern > 1.5 ? UNITY_ACCESS_INSTANCED_PROP(Props, _SurfaceFinish) : IN.finish;
            bool terrain = _UseSurfacePattern > .5;
            float2 p = terrain ? MapProject(IN.worldPos, IN.worldNormal) : MapProject(IN.objectPos, IN.objectNormal);
            float4 detail = MapSurface(p, MapOrientedPattern(terrain ? data : _DetailPattern, terrain ? IN.worldNormal : IN.objectNormal), terrain ? _SurfaceRelief : _DetailRelief);
            o.albedo *= detail.x;
            if (terrain && data.x > 7.5 && data.x < 8.5)
            {
                float damp = MapNoise(p / max(.1,data.y)*.38)+MapNoise(p*.9)*.18;
                float moss = smoothstep(.43,.72,damp);
                o.albedo = lerp(o.albedo,finish.rgb*(.8+.3*MapNoise(p*.5)),moss*.85);
            }
            if (!terrain && _MaterialMaps.x > .5) o.albedo *= SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,IN.uv).rgb;
            o.metallic = terrain ? 0 : _Metallic;
            o.smoothness = saturate((terrain ? finish.w : _Smoothness)+detail.w);
            if (!terrain && _MaterialMaps.w > .5)
            {
                half4 mask = SAMPLE_TEXTURE2D(_MetallicGlossMap,sampler_MetallicGlossMap,IN.uv);
                o.metallic *= mask.r; o.smoothness *= mask.a;
            }
            o.emission = UNITY_ACCESS_INSTANCED_PROP(Props, _EmissionColor).rgb;
            o.alpha = 1;
            o.occlusion = detail.z;
            o.normalTS = half3(0,0,1);
            float3 normal = normalize(IN.worldNormal);
            if (!terrain && _MaterialMaps.y > .5)
            {
                half3 mapped = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap,sampler_BumpMap,IN.uv),_MaterialMaps.z);
                float3 tangent = normalize(IN.tangentWS.xyz);
                float3 bitangent = cross(normal,tangent)*IN.tangentWS.w;
                normal = normalize(mapped.x*tangent+mapped.y*bitangent+mapped.z*normal);
            }
            InputData lighting = (InputData)0;
            lighting.positionWS = IN.worldPos;
            lighting.normalWS = MapReliefNormal(IN.worldPos, normal, detail.y);
            lighting.viewDirectionWS = GetWorldSpaceNormalizeViewDir(IN.worldPos);
            #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
                lighting.shadowCoord = ComputeScreenPos(TransformWorldToHClip(IN.worldPos));
            #else
                lighting.shadowCoord = TransformWorldToShadowCoord(IN.worldPos);
            #endif
            lighting.bakedGI = SampleSH(lighting.normalWS);
            lighting.vertexLighting = IN.fogAndVertexLight.yzw;
            lighting.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionCS);
            lighting.shadowMask = half4(1, 1, 1, 1);
            half4 result = ProjectYWeatherFragmentPBR(lighting, o);
            result.rgb = MixFog(result.rgb, IN.fogAndVertexLight.x);
                result.rgb = ApplyWorldFog(result.rgb, IN.worldPos);
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
            #pragma vertex DetailNormalsVertex
            #pragma fragment DetailNormalsFragment
            #pragma multi_compile_instancing
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            struct DetailNormalAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
                float4 surfaceData : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct DetailNormalVaryings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionOS : TEXCOORD2;
                float3 normalOS : TEXCOORD3;
                float4 surfaceData : TEXCOORD4;
                float4 tangentWS : TEXCOORD5;
                float2 uv : TEXCOORD6;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            DetailNormalVaryings DetailNormalsVertex(DetailNormalAttributes v)
            {
                DetailNormalVaryings o = (DetailNormalVaryings)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v,o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.positionCS = TransformWorldToHClip(o.positionWS);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.positionOS = v.positionOS.xyz; o.normalOS = v.normalOS;
                o.surfaceData = v.surfaceData;
                o.tangentWS = float4(TransformObjectToWorldDir(v.tangentOS.xyz),v.tangentOS.w*GetOddNegativeScale());
                o.uv = v.uv*_BaseMap_ST.xy+_BaseMap_ST.zw;
                return o;
            }
            half4 DetailNormalsFragment(DetailNormalVaryings i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                bool terrain = _UseSurfacePattern > .5;
                float4 data = _UseSurfacePattern > 1.5 ? UNITY_ACCESS_INSTANCED_PROP(Props,_SurfaceData) : i.surfaceData;
                float2 p = terrain ? MapProject(i.positionWS,i.normalWS) : MapProject(i.positionOS,i.normalOS);
                float4 detail = MapSurface(p,MapOrientedPattern(terrain ? data : _DetailPattern,terrain ? i.normalWS : i.normalOS),terrain ? _SurfaceRelief : _DetailRelief);
                float3 normal = normalize(i.normalWS);
                if (!terrain && _MaterialMaps.y > .5)
                {
                    half3 mapped = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap,sampler_BumpMap,i.uv),_MaterialMaps.z);
                    float3 tangent = normalize(i.tangentWS.xyz);
                    normal = normalize(mapped.x*tangent+mapped.y*cross(normal,tangent)*i.tangentWS.w+mapped.z*normal);
                }
                normal = MapReliefNormal(i.positionWS,normal,detail.y);
                #if defined(_GBUFFER_NORMALS_OCT)
                    return half4(PackFloat2To888(saturate(PackNormalOctQuadEncode(normal)*.5+.5)),0);
                #else
                    return half4(normal,0);
                #endif
            }
            ENDHLSL
        }
    }
    Fallback Off
}
