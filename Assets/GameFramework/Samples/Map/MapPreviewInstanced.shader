// 预览专用的纯色哑光材质；实例颜色支持 Region 混色，复用已导入的地块网格。
Shader "ProjectY/Map Preview Instanced"
{
    Properties { _Color ("Color", Color) = (1,1,1,1) }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200
        CGPROGRAM
        #pragma surface surf Lambert addshadow fullforwardshadows
        #pragma target 3.0
        #pragma multi_compile_instancing
        struct Input { float3 worldPos; };
        UNITY_INSTANCING_BUFFER_START(Props)
            UNITY_DEFINE_INSTANCED_PROP(fixed4, _Color)
        UNITY_INSTANCING_BUFFER_END(Props)
        void surf(Input IN, inout SurfaceOutput o)
        {
            fixed4 color = UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
            o.Albedo = color.rgb;
            o.Alpha = 1;
        }
        ENDCG
    }
    Fallback "Diffuse"
}
