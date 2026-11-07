Shader "ProjectY/UI/MenuTransition"
{
    Properties { [PerRendererData] _MainTex("Texture",2D)="white"{} _Speed("Camera speed",Range(0,1))=0 }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        Cull Off Lighting Off ZWrite Off ZTest Always Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            struct A{float4 vertex:POSITION;float2 uv:TEXCOORD0;float4 color:COLOR;};
            struct V{float4 vertex:SV_POSITION;float2 uv:TEXCOORD0;float4 color:COLOR;};
            sampler2D _MainTex;float4 _MainTex_TexelSize;float _Speed;
            V vert(A v){V o;o.vertex=UnityObjectToClipPos(v.vertex);o.uv=v.uv;o.color=v.color;return o;}
            fixed4 frag(V i):SV_Target
            {
                float2 d=float2(_MainTex_TexelSize.x*10*_Speed,0);fixed4 c=tex2D(_MainTex,i.uv)*.28;
                c+=(tex2D(_MainTex,i.uv+d)+tex2D(_MainTex,i.uv-d))*.22;c+=(tex2D(_MainTex,i.uv+2*d)+tex2D(_MainTex,i.uv-2*d))*.14;
                float vignette=smoothstep(.3,.86,length((i.uv-.5)*float2(1.05,1)));c.rgb*=1-vignette*.28;c.rgb*=1-.28*(1-smoothstep(0,.4,i.uv.y));c.rgb*=1-_Speed*.14;return c*i.color;
            }
            ENDCG
        }
    }
}
