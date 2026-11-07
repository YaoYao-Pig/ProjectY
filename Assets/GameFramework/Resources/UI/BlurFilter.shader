Shader "Hidden/ProjectY/UI/DualKawaseBlur"
{
    Properties { _MainTex("Source", 2D) = "white" {} }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        HLSLINCLUDE
        #include "UnityCG.cginc"
        sampler2D _MainTex;
        float4 _MainTex_TexelSize;
        float _Radius;
        struct Varyings { float4 position : SV_POSITION; float2 uv : TEXCOORD0; };
        Varyings Vertex(appdata_img input)
        {
            Varyings output;
            output.position = UnityObjectToClipPos(input.vertex);
            output.uv = input.texcoord;
            #if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0) output.uv.y = 1 - output.uv.y;
            #endif
            return output;
        }
        // Dual down/up kernels from ARM's Bandwidth-Efficient Rendering (SIGGRAPH 2015).
        half4 Down(Varyings input) : SV_Target
        {
            float2 step = abs(_MainTex_TexelSize.xy) * (.5 * _Radius);
            half3 diagonal = tex2D(_MainTex, input.uv + step).rgb;
            diagonal += tex2D(_MainTex, input.uv - step).rgb;
            diagonal += tex2D(_MainTex, input.uv + float2(step.x, -step.y)).rgb;
            diagonal += tex2D(_MainTex, input.uv + float2(-step.x, step.y)).rgb;
            return half4(tex2D(_MainTex, input.uv).rgb * .5 + diagonal * .125, 1);
        }
        half4 Up(Varyings input) : SV_Target
        {
            float2 step = abs(_MainTex_TexelSize.xy) * (.5 * _Radius);
            half3 axial = tex2D(_MainTex, input.uv + float2(2 * step.x, 0)).rgb;
            axial += tex2D(_MainTex, input.uv - float2(2 * step.x, 0)).rgb;
            axial += tex2D(_MainTex, input.uv + float2(0, 2 * step.y)).rgb;
            axial += tex2D(_MainTex, input.uv - float2(0, 2 * step.y)).rgb;
            half3 diagonal = tex2D(_MainTex, input.uv + step).rgb;
            diagonal += tex2D(_MainTex, input.uv - step).rgb;
            diagonal += tex2D(_MainTex, input.uv + float2(step.x, -step.y)).rgb;
            diagonal += tex2D(_MainTex, input.uv + float2(-step.x, step.y)).rgb;
            return half4((axial + 2 * diagonal) / 12, 1);
        }
        half4 Copy(Varyings input) : SV_Target { return half4(tex2D(_MainTex, input.uv).rgb, 1); }
        ENDHLSL
        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Down
            ENDHLSL
        }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Up
            ENDHLSL
        }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Copy
            ENDHLSL
        }
    }
}
