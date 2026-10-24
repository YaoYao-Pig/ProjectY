Shader "ProjectY/World Site Silhouette"
{
    Properties { _SiteMask ("Selected", Vector) = (1,1,1,1) }
    SubShader
    {
        Pass
        {
            ZWrite On ZTest LEqual Cull Back
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #include "UnityCG.cginc"
            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(float4, _SiteMask)
            UNITY_INSTANCING_BUFFER_END(Props)
            struct appdata { float4 vertex : POSITION; UNITY_VERTEX_INPUT_INSTANCE_ID };
            struct v2f { float4 position : SV_POSITION; float value : TEXCOORD0; };
            v2f vert(appdata v)
            {
                UNITY_SETUP_INSTANCE_ID(v);
                v2f o; o.position = UnityObjectToClipPos(v.vertex);
                o.value = UNITY_ACCESS_INSTANCED_PROP(Props, _SiteMask).x; return o;
            }
            half4 frag(v2f i) : SV_Target { return half4(i.value, i.value, i.value, 1); }
            ENDHLSL
        }
    }
}
