// 地图共享的哑光材质；地表图案使用世界米制尺寸，远景自动淡出细缝以减轻闪烁。
Shader "ProjectY/Map Preview Instanced"
{
    Properties { _Color ("Color", Color) = (1,1,1,1) _EmissionColor ("Emission", Color) = (0,0,0,0) _UseVertexColor ("Vertex color", Float) = 0 _UseSurfacePattern ("Surface pattern", Float) = 0 }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 200
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
        CBUFFER_START(UnityPerMaterial)
            half4 _EmissionColor;
            float _UseVertexColor, _UseSurfacePattern;
        CBUFFER_END
        // Keep the existing CPU property-block contract for instanced map batches.
        UNITY_INSTANCING_BUFFER_START(Props)
            UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
            UNITY_DEFINE_INSTANCED_PROP(float4, _SurfaceData)
            UNITY_DEFINE_INSTANCED_PROP(float4, _SurfaceFinish)
        UNITY_INSTANCING_BUFFER_END(Props)
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
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        struct Attributes
        {
            float4 positionOS : POSITION;
            float3 normalOS : NORMAL;
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
            o.worldNormal = TransformObjectToWorldNormal(v.normalOS);
            o.color = v.color;
            o.surfaceData = v.surfaceData; o.finish = v.finish;
            o.fogAndVertexLight = half4(ComputeFogFactor(position.positionCS.z), VertexLighting(o.worldPos, o.worldNormal));
            return o;
        }
        float hash(float2 p) { return frac(sin(dot(p, float2(127.1,311.7))) * 43758.5453); }
        float noise(float2 p)
        {
            float2 i = floor(p), f = frac(p); f = f*f*(3-2*f);
            return lerp(lerp(hash(i),hash(i+float2(1,0)),f.x),lerp(hash(i+float2(0,1)),hash(i+1),f.x),f.y);
        }
        float pattern(float2 p, float4 data)
        {
            float kind = data.x; p /= max(.1, data.y);
            float detail = 1-saturate(max(fwidth(p.x),fwidth(p.y))*1.5);
            float value = 1;
            if (kind < .5) return 1;
            if (kind < 2.5 || (kind > 4.5 && kind < 5.5) || kind > 8.5)
            {
                if (kind > 4.5) p.y *= .16;
                if (kind > 8.5) p.y *= 12;
                p.x += fmod(floor(p.y),2)*.5;
                float2 f=frac(p), fw=max(fwidth(p),.002);
                float2 edge=min(f,1-f);
                float joint=1-min(smoothstep(data.w, data.w+fw.x,edge.x),smoothstep(data.w,data.w+fw.y,edge.y));
                if (kind > 1.5 && kind < 2.5)
                {
                    float2 rounded=abs(f-.5); joint=max(joint,smoothstep(.57,.63+max(fw.x,fw.y),length(rounded)));
                }
                value += (hash(floor(p))-.5)*data.z*2*detail - joint*data.z*detail;
            }
            else
            {
                float coarse=noise(p*.43), fine=noise(p*2.7);
                value += ((coarse-.5)*1.4 + (fine-.5)*.4*detail)*data.z;
                if (kind > 5.5 && kind < 6.5) value -= pow(1-abs(noise(p*.8)*2-1),12)*data.z*.35;
            }
            return value;
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
            if (_UseSurfacePattern > .5)
            {
                float3 n=abs(IN.worldNormal);
                float2 p=n.y>.6 ? IN.worldPos.xz : (n.x>n.z ? IN.worldPos.zy : IN.worldPos.xy);
                o.albedo *= pattern(p, data);
                // 苔藓以连续的大块覆盖出现，世界坐标保证相邻格之间没有独立贴片边界。
                if (data.x > 7.5 && data.x < 8.5)
                {
                    float damp = noise(p / max(.1,data.y) * .38) + noise(p*.9)*.18;
                    float moss = smoothstep(.43,.72,damp);
                    o.albedo = lerp(o.albedo, finish.rgb*(.8+.3*noise(p*.5)), moss*.85);
                }
            }
            o.metallic = 0;
            o.smoothness = _UseSurfacePattern > .5 ? finish.w : .08;
            o.emission = _EmissionColor.rgb;
            o.alpha = 1;
            o.occlusion = 1;
            o.normalTS = half3(0, 0, 1);
            InputData lighting = (InputData)0;
            lighting.positionWS = IN.worldPos;
            lighting.normalWS = NormalizeNormalPerPixel(IN.worldNormal);
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
            half4 result = UniversalFragmentPBR(lighting, o);
            result.rgb = MixFog(result.rgb, IN.fogAndVertexLight.x);
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
