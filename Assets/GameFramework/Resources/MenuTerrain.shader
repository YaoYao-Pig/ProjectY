Shader "ProjectY/MenuTerrain"
{
    Properties { _BaseColor("Color",Color)=(1,1,1,1) }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct A {float4 positionOS:POSITION;float3 normalOS:NORMAL;float4 color:COLOR;};
            struct V {float4 positionCS:SV_POSITION;float3 normalWS:TEXCOORD0;float4 color:COLOR;};
            CBUFFER_START(UnityPerMaterial) float4 _BaseColor; CBUFFER_END
            V vert(A a){V o;o.positionCS=TransformObjectToHClip(a.positionOS.xyz);o.normalWS=TransformObjectToWorldNormal(a.normalOS);o.color=a.color;return o;}
            half4 frag(V i):SV_Target {float shade=.55+.45*saturate(dot(normalize(i.normalWS),normalize(float3(-.5,1,.7))));return half4(i.color.rgb*_BaseColor.rgb*shade,1);}
            ENDHLSL
        }
    }
}
