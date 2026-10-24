Shader "ProjectY/Block Particle"
{
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "RenderPipeline"="UniversalPipeline" }
        Pass
        {
            Name "BlockParticles"
            Tags { "LightMode"="UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 3.0
            #pragma multi_compile_fog
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                half4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                half4 color : COLOR;
                half fogFactor : TEXCOORD0;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                // Hard face contrast preserves the cube silhouette without Bloom.
                half faceShade = .66h + .34h * saturate(dot(normalWS, normalize(float3(-.35, .8, .4))));
                // Matches BlockParticleEffects.HdrColorRange. Profile emission is a
                // multiplier encoded in vertex RGB, with no per-renderer material overrides.
                output.color = half4(input.color.rgb * 8.0h * faceShade, input.color.a);
                output.fogFactor = ComputeFogFactor(output.positionCS.z);
                return output;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                return half4(MixFog(input.color.rgb, input.fogFactor), input.color.a);
            }
            ENDHLSL
        }
    }
    Fallback Off
}
