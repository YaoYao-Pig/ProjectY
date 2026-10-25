// Opaque equipment finish: preserves the low-poly surface and adds a host-clock glow.
Shader "ProjectY/Equipment Arcane"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _Metallic ("Metallic", Range(0,1)) = .3
        _Smoothness ("Smoothness", Range(0,1)) = .4
        [HDR] _ArcaneColor ("Glow Color", Color) = (0.4,0.8,1,1)
        [HDR] _ArcaneAccent ("Accent Color", Color) = (1,0.8,0.4,1)
        _ArcaneEmission ("Emission", Range(0,8)) = 2
        _ArcanePulseSpeed ("Pulse Speed", Float) = 1
        _ArcanePulseAmount ("Pulse Amount", Range(0,1)) = .2
        _ArcaneFlowSpeed ("Flow Speed", Float) = .4
        _ArcaneFlowScale ("Flow Scale", Float) = 4
        _ArcaneTime ("Host Time", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 200
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
        CBUFFER_START(UnityPerMaterial)
            half4 _BaseColor, _ArcaneColor, _ArcaneAccent;
            half _Metallic, _Smoothness, _ArcaneEmission, _ArcanePulseSpeed, _ArcanePulseAmount;
            float _ArcaneFlowSpeed, _ArcaneFlowScale, _ArcaneTime;
        CBUFFER_END
        ENDHLSL
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForwardOnly" }
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
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
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionOS : TEXCOORD2;
                half4 fogAndVertexLight : TEXCOORD3;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            Varyings Vert(Attributes input)
            {
                Varyings output=(Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input,output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                VertexPositionInputs position=GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS=position.positionCS;output.positionWS=position.positionWS;
                output.positionOS=input.positionOS.xyz;output.normalWS=TransformObjectToWorldNormal(input.normalOS);
                output.fogAndVertexLight=half4(ComputeFogFactor(position.positionCS.z),VertexLighting(output.positionWS,output.normalWS));
                return output;
            }
            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                InputData lighting=(InputData)0;
                lighting.positionWS=input.positionWS;lighting.normalWS=NormalizeNormalPerPixel(input.normalWS);
                lighting.viewDirectionWS=GetWorldSpaceNormalizeViewDir(input.positionWS);
                #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
                    lighting.shadowCoord=ComputeScreenPos(TransformWorldToHClip(input.positionWS));
                #else
                    lighting.shadowCoord=TransformWorldToShadowCoord(input.positionWS);
                #endif
                lighting.bakedGI=SampleSH(lighting.normalWS);lighting.vertexLighting=input.fogAndVertexLight.yzw;
                lighting.normalizedScreenSpaceUV=GetNormalizedScreenSpaceUV(input.positionCS);lighting.shadowMask=half4(1,1,1,1);
                // An angled band runs along model-local geometry, not screen or world position.
                float phase=dot(input.positionOS,float3(.61,1,.37))*_ArcaneFlowScale-_ArcaneTime*_ArcaneFlowSpeed;
                float wave=.5+.5*sin(phase*6.2831853);
                float band=smoothstep(.78,.98,wave);
                float rim=pow(1-saturate(dot(lighting.normalWS,lighting.viewDirectionWS)),3);
                float pulse=1-_ArcanePulseAmount*.5+sin(_ArcaneTime*_ArcanePulseSpeed)*_ArcanePulseAmount*.5;
                SurfaceData surface=(SurfaceData)0;
                surface.albedo=_BaseColor.rgb;surface.alpha=1;surface.metallic=_Metallic;surface.smoothness=_Smoothness;
                surface.normalTS=half3(0,0,1);surface.occlusion=1;
                surface.emission=lerp(_ArcaneColor.rgb,_ArcaneAccent.rgb,band)*_ArcaneEmission*pulse*(.13+band*.50+rim*.28);
                half4 result=UniversalFragmentPBR(lighting,surface);
                result.rgb=MixFog(result.rgb,input.fogAndVertexLight.x);
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
