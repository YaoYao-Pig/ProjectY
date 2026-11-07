Shader "ProjectY/Skill Range"
{
    Properties { [HDR] _Color ("Highlight color", Color) = (.24,.55,1,1) }
    SubShader
    {
        Tags { "Queue"="Transparent+10" "RenderType"="Transparent" "RenderPipeline"="UniversalPipeline" }
        Pass
        {
            Tags { "LightMode"="SRPDefaultUnlit" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest LEqual
            Cull Off
            Offset -1, -1
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; };
            struct v2f { float4 vertex : SV_POSITION; float2 hexPosition : TEXCOORD0; };
            CBUFFER_START(UnityPerMaterial)
            half4 _Color;
            CBUFFER_END
            v2f vert(appdata v)
            {
                v2f o;o.vertex=TransformObjectToHClip(v.vertex.xyz);o.hexPosition=v.uv;return o;
            }
            half4 frag(v2f i) : SV_Target
            {
                float2 p=abs(i.hexPosition);
                float d=max(p.x,.5*p.x+.8660254*p.y)/.8660254;
                float edge=abs(d-.92);
                float stroke=1-smoothstep(.012,.038,edge);
                float halo=exp2(-edge*22);
                float fill=1-smoothstep(.88,.92,d);
                float pulse=.9+.1*sin(_Time.y*2.5);
                float opacity=saturate(fill*.16+stroke*.7+halo*.3)*_Color.a;
                clip(opacity-.003);
                return half4(_Color.rgb*(1+stroke*2.2+halo*.65)*pulse,opacity);
            }
            ENDHLSL
        }
    }
}
