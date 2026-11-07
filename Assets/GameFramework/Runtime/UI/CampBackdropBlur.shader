Shader "Hidden/ProjectY/CampBackdropBlur"
{
    Properties { _MainTex("Texture",2D)="white"{} }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }
        ZTest Always ZWrite Off Cull Off
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            sampler2D _MainTex; float4 _MainTex_TexelSize; float4 _Direction;
            struct v2f { float4 position:SV_POSITION; float2 uv:TEXCOORD0; };
            v2f vert(appdata_img v){v2f o;o.position=UnityObjectToClipPos(v.vertex);o.uv=v.texcoord;return o;}
            half4 frag(v2f i):SV_Target
            {
                float2 d=_Direction.xy*3.5;
                half3 c=tex2D(_MainTex,i.uv).rgb*.227027;
                c+=(tex2D(_MainTex,i.uv+d*1.384615).rgb+tex2D(_MainTex,i.uv-d*1.384615).rgb)*.316216;
                c+=(tex2D(_MainTex,i.uv+d*3.230769).rgb+tex2D(_MainTex,i.uv-d*3.230769).rgb)*.070270;
                return half4(c,1);
            }
            ENDHLSL
        }
    }
}
