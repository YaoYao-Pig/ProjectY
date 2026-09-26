Shader "ProjectY/Exploration Grid"
{
    Properties { _Color ("Fill color", Color) = (1,.84,.2,.58) }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest LEqual
            Cull Off
            Offset -1, -1
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma multi_compile_fog
            #include "UnityCG.cginc"
            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; };
            struct v2f { float4 vertex : SV_POSITION; float3 world : TEXCOORD0; float2 cell : TEXCOORD1; UNITY_FOG_COORDS(2) };
            fixed4 _Color, _HoverColor, _SelectedColor;
            float4 _SquadCenters[4];
            float4 _FadeRadii;
            int _SquadCount, _HoveredCell, _SelectedCell;
            v2f vert(appdata v)
            {
                v2f o;o.vertex=UnityObjectToClipPos(v.vertex);o.world=mul(unity_ObjectToWorld,v.vertex).xyz;o.cell=v.uv;
                UNITY_TRANSFER_FOG(o,o.vertex);return o;
            }
            fixed4 frag(v2f i) : SV_Target
            {
                float nearest=1e10;
                [unroll] for(int n=0;n<4;n++)
                    if(n<_SquadCount && abs(i.cell.x-_SquadCenters[n].w)<.1)
                        nearest=min(nearest,distance(i.world.xz,_SquadCenters[n].xz));
                float fade=1-smoothstep(_FadeRadii.x,_FadeRadii.y,nearest);
                fixed4 color=_Color;color.a*=fade;
                if(abs(i.cell.y-_HoveredCell)<.1) color=_HoverColor;
                if(abs(i.cell.y-_SelectedCell)<.1) color=_SelectedColor;
                clip(color.a-.001);
                UNITY_APPLY_FOG(i.fogCoord,color);return color;
            }
            ENDCG
        }
    }
}
