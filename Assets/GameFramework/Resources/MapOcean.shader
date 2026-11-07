Shader "ProjectY/Map Ocean"
{
    Properties
    {
        _WaterBoundaryField ("Coverage / elevation / shore / optical depth", 2D) = "black" {}
        [HideInInspector] _WaterPreviewTime ("Preview time", Float) = -1
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent+10" "RenderType"="Transparent" }
        Pass
        {
            Name "ExteriorOcean"
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off ZTest Always Cull Off
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "MapWaterSurface.hlsl"
            CBUFFER_START(UnityPerMaterial)
                float4 _OceanParameters;
                float _WaterPreviewTime;
            CBUFFER_END
            struct Attributes { float3 positionOS : POSITION; };
            struct Varyings { float4 positionCS : SV_POSITION; };
            Varyings Vert(Attributes input)
            {
                Varyings output;output.positionCS=TransformObjectToHClip(input.positionOS);return output;
            }
            half4 Frag(Varyings input) : SV_Target
            {
                float2 screenUV=GetNormalizedScreenSpaceUV(input.positionCS);
                float raw=SampleSceneDepth(screenUV);
                #if UNITY_REVERSED_Z
                    float nearDepth=1,farDepth=0;bool sky=raw<.000001;
                #else
                    float nearDepth=UNITY_NEAR_CLIP_VALUE,farDepth=1;bool sky=raw>.999999;
                    raw=lerp(UNITY_NEAR_CLIP_VALUE,1,raw);
                #endif
                float3 scene=ComputeWorldSpacePosition(screenUV,raw,UNITY_MATRIX_I_VP);
                if(!sky)
                {
                    float4 surface=WaterBoundary(scene.xz);
                    // Most foreground pixels need no ocean intersection or lighting work.
                    if(surface.r>.5 && scene.y>=surface.g-.002)return 0;
                }
                float3 origin=ComputeWorldSpacePosition(screenUV,nearDepth,UNITY_MATRIX_I_VP);
                float3 farPoint=ComputeWorldSpacePosition(screenUV,farDepth,UNITY_MATRIX_I_VP);
                float3 direction=normalize(farPoint-origin);
                float slope=abs(direction.y)<.0001?-.0001:direction.y;
                float travel=(_OceanParameters.x-origin.y)/slope;
                float3 world=origin+direction*max(0,travel);
                // Local coast heights can differ sharply. Bracket the height field instead of
                // fixed-point iteration, which can oscillate between low and high shores.
                // Uniform water retains the single-plane fast path.
                if(_OceanParameters.z<.5)
                {
                    float upperTravel=(_OceanParameters.w-origin.y)/slope;
                    float nearTravel=max(0,min(travel,upperTravel));
                    float farTravel=max(travel,upperTravel);
                    [loop] for(int i=0;i<12;i++)
                    {
                        travel=(nearTravel+farTravel)*.5;
                        world=origin+direction*travel;
                        float4 coast=WaterBoundary(world.xz);
                        float elevation=clamp(coast.g,_OceanParameters.x,_OceanParameters.w);
                        if((world.y-elevation)*slope<0)nearTravel=travel;
                        else farTravel=travel;
                    }
                }
                if(travel<0 || abs(direction.y)<.0001)world=farPoint;
                float4 boundary=WaterBoundary(world.xz);
                if(!sky)
                {
                    // Preserve foreground land, boats and real water. Only fill exterior surfaces below sea level.
                    if(travel<0 || length(scene-origin)<=travel+.002 || boundary.r>.5)return 0;
                }
                float time=_WaterPreviewTime>=0?_WaterPreviewTime:_Time.y;
                float2 uv=(world.xz-_WaterBoundaryBounds.xy)*_WaterBoundaryBounds.zw;
                float beyond=length(max(abs(uv-.5)-.5,0)/_WaterBoundaryBounds.zw)/_OceanParameters.y;
                float seaward=max(0,-boundary.r)+beyond;
                float depth=lerp(boundary.a,2.5+seaward*.18,smoothstep(1,8,seaward));
                half3 color=StylizedWater(world,_OceanParameters.y,time,boundary.b,depth);
                color=MixFog(color,ComputeFogFactor(TransformWorldToHClip(world).z));
                return half4(color,1);
            }
            ENDHLSL
        }
    }
}
