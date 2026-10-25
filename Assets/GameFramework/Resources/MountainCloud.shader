Shader "ProjectY/Mountain Cloud"
{
    Properties { _CloudData ("Opacity / phase", Vector) = (.3,0,0,0) }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "RenderPipeline"="UniversalPipeline" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off
        Pass
        {
            Tags { "LightMode"="UniversalForward" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "WorldFogSampling.hlsl"
            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(float4, _CloudData)
            UNITY_INSTANCING_BUFFER_END(Props)
            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; UNITY_VERTEX_INPUT_INSTANCE_ID };
            struct Varyings { float4 positionCS : SV_POSITION; float2 uv : TEXCOORD0; float3 positionWS : TEXCOORD1; UNITY_VERTEX_INPUT_INSTANCE_ID };
            Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input); UNITY_TRANSFER_INSTANCE_ID(input,output);
                output.positionWS=TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS=TransformWorldToHClip(output.positionWS);output.uv=input.uv;
                return output;
            }
            float hash(float2 p) { return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453); }
            float noise(float2 p)
            {
                float2 i=floor(p),f=frac(p);f=f*f*(3-2*f);
                return lerp(lerp(hash(i),hash(i+float2(1,0)),f.x),lerp(hash(i+float2(0,1)),hash(i+1),f.x),f.y);
            }
            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                float4 data=UNITY_ACCESS_INSTANCED_PROP(Props,_CloudData);
                float2 p=input.uv*2-1;
                float soft=saturate(1-dot(p,p));soft=soft*soft;
                float2 flow=input.uv*float2(5,3)+float2(_Time.y*.015,data.y);
                float density=noise(flow)*.65+noise(flow*2.1)*.35;
                half alpha=soft*smoothstep(.16,.72,density)*data.x;
                clip(alpha-.004);
                half3 color=ApplyWorldFog(lerp(half3(.61,.70,.75),half3(.91,.95,.95),density),input.positionWS);
                return half4(color,alpha);
            }
            ENDHLSL
        }
    }
}
