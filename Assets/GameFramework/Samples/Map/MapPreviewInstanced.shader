// 地图共享的哑光材质；地表图案使用世界米制尺寸，远景自动淡出细缝以减轻闪烁。
Shader "ProjectY/Map Preview Instanced"
{
    Properties { _Color ("Color", Color) = (1,1,1,1) _EmissionColor ("Emission", Color) = (0,0,0,0) _UseVertexColor ("Vertex color", Float) = 0 _UseSurfacePattern ("Surface pattern", Float) = 0 }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200
        CGPROGRAM
        #pragma surface surf Standard vertex:vert addshadow fullforwardshadows
        #pragma target 3.0
        #pragma multi_compile_instancing
        struct Input { float3 worldPos; float3 worldNormal; fixed4 color : COLOR; float4 surfaceData; float4 finish; };
        fixed4 _EmissionColor;
        float _UseVertexColor, _UseSurfacePattern;
        UNITY_INSTANCING_BUFFER_START(Props)
            UNITY_DEFINE_INSTANCED_PROP(fixed4, _Color)
            UNITY_DEFINE_INSTANCED_PROP(float4, _SurfaceData)
            UNITY_DEFINE_INSTANCED_PROP(float4, _SurfaceFinish)
        UNITY_INSTANCING_BUFFER_END(Props)
        void vert(inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            o.surfaceData = v.texcoord1; o.finish = v.texcoord2;
        }
        float hash(float2 p) { return frac(sin(dot(p, float2(127.1,311.7))) * 43758.5453); }
        float noise(float2 p)
        {
            float2 i = floor(p), f = frac(p); f = f*f*(3-2*f);
            return lerp(lerp(hash(i),hash(i+float2(1,0)),f.x),lerp(hash(i+float2(0,1)),hash(i+1),f.x),f.y);
        }
        float pattern(float2 p, float4 data)
        {
            float kind = data.x; p /= max(.1, data.y);
            float detail = 1-saturate(max(fwidth(p.x),fwidth(p.y))*1.5);
            float value = 1;
            if (kind < .5) return 1;
            if (kind < 2.5 || (kind > 4.5 && kind < 5.5) || kind > 8.5)
            {
                if (kind > 4.5) p.y *= .16;
                if (kind > 8.5) p.y *= 12;
                p.x += fmod(floor(p.y),2)*.5;
                float2 f=frac(p), fw=max(fwidth(p),.002);
                float2 edge=min(f,1-f);
                float joint=1-min(smoothstep(data.w, data.w+fw.x,edge.x),smoothstep(data.w,data.w+fw.y,edge.y));
                if (kind > 1.5 && kind < 2.5)
                {
                    float2 rounded=abs(f-.5); joint=max(joint,smoothstep(.57,.63+max(fw.x,fw.y),length(rounded)));
                }
                value += (hash(floor(p))-.5)*data.z*2*detail - joint*data.z*detail;
            }
            else
            {
                float coarse=noise(p*.43), fine=noise(p*2.7);
                value += ((coarse-.5)*1.4 + (fine-.5)*.4*detail)*data.z;
                if (kind > 5.5 && kind < 6.5) value -= pow(1-abs(noise(p*.8)*2-1),12)*data.z*.35;
            }
            return value;
        }
        void surf(Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 color = UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
            color = lerp(color, IN.color, _UseVertexColor);
            o.Albedo = color.rgb;
            float4 data = _UseSurfacePattern > 1.5 ? UNITY_ACCESS_INSTANCED_PROP(Props, _SurfaceData) : IN.surfaceData;
            float4 finish = _UseSurfacePattern > 1.5 ? UNITY_ACCESS_INSTANCED_PROP(Props, _SurfaceFinish) : IN.finish;
            if (_UseSurfacePattern > .5)
            {
                float3 n=abs(IN.worldNormal);
                float2 p=n.y>.6 ? IN.worldPos.xz : (n.x>n.z ? IN.worldPos.zy : IN.worldPos.xy);
                o.Albedo *= pattern(p, data);
                // 苔藓以连续的大块覆盖出现，世界坐标保证相邻格之间没有独立贴片边界。
                if (data.x > 7.5 && data.x < 8.5)
                {
                    float damp = noise(p / max(.1,data.y) * .38) + noise(p*.9)*.18;
                    float moss = smoothstep(.43,.72,damp);
                    o.Albedo = lerp(o.Albedo, finish.rgb*(.8+.3*noise(p*.5)), moss*.85);
                }
            }
            o.Metallic = 0;
            o.Smoothness = _UseSurfacePattern > .5 ? finish.w : .08;
            o.Emission = _EmissionColor.rgb;
            o.Alpha = 1;
        }
        ENDCG
    }
    Fallback "Diffuse"
}
