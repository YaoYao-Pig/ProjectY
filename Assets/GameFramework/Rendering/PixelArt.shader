Shader "Hidden/ProjectY/PixelArt"
{
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        ZWrite Off ZTest Always Cull Off

        HLSLINCLUDE
        #pragma target 3.5
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

        float4 _PixelSourceSize; // width, height, reciprocal width/height
        float4 _PixelGridSize;
        float4 _PixelStyle; // integer block size, color intervals, color strength, dither strength
        float4 _PixelInk; // strength, width in virtual pixels, relative depth threshold, crease strength

        float EyeDepth(float2 uv)
        {
            float depth = SampleSceneDepth(saturate(uv));
            // LinearEyeDepth assumes perspective; world-map and preview cameras are orthographic.
            #if UNITY_REVERSED_Z
                float orthographicDepth = lerp(_ProjectionParams.z, _ProjectionParams.y, depth);
            #else
                float orthographicDepth = lerp(_ProjectionParams.y, _ProjectionParams.z, depth);
            #endif
            return lerp(LinearEyeDepth(depth, _ZBufferParams), orthographicDepth, unity_OrthoParams.w);
        }

        float InkEdge(float2 uv)
        {
            if (_PixelInk.x <= 0) return 0;
            float2 stepUV = _PixelSourceSize.zw * _PixelStyle.x * _PixelInk.y;
            float center = EyeDepth(uv);
            float left = EyeDepth(uv - float2(stepUV.x, 0));
            float right = EyeDepth(uv + float2(stepUV.x, 0));
            float down = EyeDepth(uv - float2(0, stepUV.y));
            float up = EyeDepth(uv + float2(0, stepUV.y));
            // Second differences reject continuous ground slopes. Ink falls on the near side.
            float discontinuity = max(left + right - 2 * center, down + up - 2 * center);
            float threshold = max(.035, center * _PixelInk.z);
            float silhouette = smoothstep(threshold, threshold * 2, discontinuity);
            float3 n = SampleSceneNormals(uv);
            float crease = 0;
            crease = max(crease, 1 - dot(n, SampleSceneNormals(saturate(uv + float2(stepUV.x, 0)))));
            crease = max(crease, 1 - dot(n, SampleSceneNormals(saturate(uv - float2(stepUV.x, 0)))));
            crease = max(crease, 1 - dot(n, SampleSceneNormals(saturate(uv + float2(0, stepUV.y)))));
            crease = max(crease, 1 - dot(n, SampleSceneNormals(saturate(uv - float2(0, stepUV.y)))));
            // Sky/cleared normals are zero. Only draw interior creases on actual opaque geometry.
            crease = smoothstep(.45, .8, crease) * _PixelInk.w * step(.5, dot(n, n));
            return max(silhouette, crease) * _PixelInk.x;
        }

        float Bayer4(uint2 pixel)
        {
            // 4x4 ordered matrix, fixed in the virtual pixel grid (no temporal noise).
            uint2 low = pixel & 1u;
            uint2 high = (pixel >> 1u) & 1u;
            uint a = ((low.x ^ low.y) << 1u) | low.y;
            uint b = ((high.x ^ high.y) << 1u) | high.y;
            return (a * 4u + b + 0.5) / 16.0 - 0.5;
        }

        half4 Pixelate(Varyings input) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
            float2 uv = (input.texcoord - _BlitScaleBias.zw) / _BlitScaleBias.xy;
            float2 cell = min(floor(uv * _PixelGridSize.xy), _PixelGridSize.xy - 1);
            // The last row/column can be partial: sample inside the source instead of wrapping.
            float2 sourcePixel = min((cell + 0.5) * _PixelStyle.x, _PixelSourceSize.xy - 0.5);
            float2 sourceUV = sourcePixel * _PixelSourceSize.zw * _BlitScaleBias.xy + _BlitScaleBias.zw;
            half4 source = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, sourceUV);
            float3 color = saturate(source.rgb);
            #ifndef UNITY_COLORSPACE_GAMMA
                color = LinearToSRGB(color);
            #endif
            float threshold = Bayer4((uint2)cell) * _PixelStyle.w;
            float3 reduced = saturate(floor(color * _PixelStyle.y + 0.5 + threshold) / _PixelStyle.y);
            color = lerp(color, reduced, _PixelStyle.z);
            float edge = InkEdge(sourcePixel * _PixelSourceSize.zw);
            color = lerp(color, float3(.035, .03, .045), edge);
            #ifndef UNITY_COLORSPACE_GAMMA
                color = SRGBToLinear(color);
            #endif
            return half4(color, source.a);
        }

        half4 ExpandPixels(Varyings input) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
            float2 uv = (input.texcoord - _BlitScaleBias.zw) / _BlitScaleBias.xy;
            float2 cell = min(floor(uv * _PixelSourceSize.xy / _PixelStyle.x), _PixelGridSize.xy - 1);
            float2 sampleUV = (cell + 0.5) * _PixelGridSize.zw * _BlitScaleBias.xy + _BlitScaleBias.zw;
            return SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointClamp, sampleUV);
        }
        ENDHLSL

        Pass
        {
            Name "PixelateAndQuantize"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Pixelate
            ENDHLSL
        }
        Pass
        {
            Name "IntegerPointUpscale"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment ExpandPixels
            ENDHLSL
        }
    }
    Fallback Off
}
