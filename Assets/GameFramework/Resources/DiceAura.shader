Shader "ProjectY/DiceAura"
{
    Properties { _Color ("Color", Color) = (0.2,0.6,1,0.5) _Ring ("Ring", Float) = 0 _Trail ("Trail", Float) = 0 }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent" }
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; float4 color : COLOR; };
            struct Varyings { float4 positionCS : SV_POSITION; float2 uv : TEXCOORD0; float4 color : COLOR; };
            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float _Ring;
                float _Trail;
            CBUFFER_END
            Varyings Vert(Attributes input)
            {
                Varyings output; output.positionCS=TransformObjectToHClip(input.positionOS.xyz);
                output.uv=input.uv; output.color=input.color; return output;
            }
            half4 Frag(Varyings input) : SV_Target
            {
                if(_Trail>.5) return half4(input.color.rgb,input.color.a*exp(-pow((input.uv.y-.5)*4,2)));
                float radius=length(input.uv*2-1);
                float glow=exp(-radius*radius*5)*.45;
                float ring=exp(-pow((radius-.76)*70,2))*_Ring;
                float alpha=saturate(glow+ring)*_Color.a;
                return half4(_Color.rgb,alpha);
            }
            ENDHLSL
        }
    }
}
