Shader "ProjectY/UI/World Site Dim"
{
    Properties { _MainTex ("Silhouette", 2D) = "black" {} }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            sampler2D _MainTex;
            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; half4 color : COLOR; };
            struct v2f { float4 position : SV_POSITION; float2 uv : TEXCOORD0; half4 color : COLOR; };
            v2f vert(appdata v)
            {
                v2f o; o.position = UnityObjectToClipPos(v.vertex); o.uv = v.uv; o.color = v.color;
                return o;
            }
            half4 frag(v2f i) : SV_Target { return half4(i.color.rgb, i.color.a * (1 - tex2D(_MainTex, i.uv).r)); }
            ENDHLSL
        }
    }
}
