Shader "ProjectY/Map Weather Cloud"
{
    Properties
    {
        _WeatherCloudTint ("Cloud Color And Opacity", Color) = (1,1,1,.65)
        _CloudDensity ("Cloud Optical Density", Range(1,12)) = 3.2
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "RenderType"="Transparent" }
        Pass
        {
            Name "WeatherCloud"
            Tags { "LightMode"="UniversalForwardOnly" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off ZTest LEqual Cull Back
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            CBUFFER_START(UnityPerMaterial)
                half _CloudDensity;
            CBUFFER_END

            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(float4, _WeatherCloudTint)
            UNITY_INSTANCING_BUFFER_END(Props)

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                half3 normalWS : TEXCOORD1;
                half fog : TEXCOORD2;
                float3 localPosition : TEXCOORD3;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            Varyings Vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                // Leave lanes between clouds so a tactical overhead view keeps its terrain readable.
                const float3 shapeScale = float3(.65, 1, .65);
                output.localPosition = input.positionOS.xyz;
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz * shapeScale);
                output.positionCS = TransformWorldToHClip(output.positionWS);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS / shapeScale);
                output.fog = ComputeFogFactor(output.positionCS.z);
                return output;
            }
            float CloudHash(float2 p)
            {
                float3 q = frac(float3(p.x, p.y, p.x) * float3(.1031,.1030,.0973));
                q += dot(q, q.yzx + 33.33);
                return frac((q.x+q.y)*q.z);
            }
            float CloudDetail(float2 p)
            {
                float2 cell = floor(p), f = frac(p);
                f = f*f*(3-2*f);
                return lerp(lerp(CloudHash(cell), CloudHash(cell+float2(1,0)), f.x),
                    lerp(CloudHash(cell+float2(0,1)), CloudHash(cell+1), f.x), f.y);
            }
            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                half4 tint = UNITY_ACCESS_INSTANCED_PROP(Props, _WeatherCloudTint);
                half3 normal = NormalizeNormalPerPixel(input.normalWS);
                half3 view = GetWorldSpaceNormalizeViewDir(input.positionWS);
                Light sun = GetMainLight();
                half facing = saturate(dot(normal, sun.direction)*.48+.52);
                half height = smoothstep(-.48, .72, input.localPosition.y);
                half pocket = CloudDetail(input.localPosition.xz*2.2 + input.localPosition.y*.7 + input.positionWS.xz*.035);
                half bodyShade = lerp(.62, 1.02, height) * lerp(.90, 1.02, pocket);
                half3 ambient = max(SampleSH(half3(0,1,0)), half3(.008,.01,.018));
                // Compress bright daylight before directional shading; a final hard clamp flattened every lit lobe.
                half sunPeak = max(sun.color.r, max(sun.color.g, sun.color.b));
                half3 softSun = sun.color / (1 + sunPeak*.65);
                half3 illumination = ambient*.32 + softSun*lerp(.24, 1.06, facing);
                half3 depthTint = lerp(half3(.82,.87,.96), half3(1,1,1), height);
                half3 color = tint.rgb * illumination * bodyShade * depthTint;
                half viewFacing = saturate(dot(normal, view));
                // Feather over a broad band before the mesh silhouette. Low-frequency erosion
                // breaks up identical round outlines without adding geometry or ray-march samples.
                half fringe = lerp(pocket, CloudDetail(input.localPosition.xy*5.1 + input.localPosition.z*.9), .38);
                half edge = smoothstep(lerp(.12, .30, fringe), .94, viewFacing);
                edge *= lerp(.78, 1, edge);
                half thickness = lerp(.55, 1.28, height) * lerp(.84, 1.10, pocket);
                // Match the three lobes in MapWeatherRenderer.CreateCloudMesh. Interior surfaces
                // fade out where another lobe contains them, so the cloud reads as one connected mass.
                float shell = min(length(input.localPosition-float3(-.55,-.08,0))-.55,
                    min(length(input.localPosition-float3(0,.15,0))-.72,
                        length(input.localPosition-float3(.55,-.08,.10))-.55));
                half outerShell = smoothstep(-.10, -.055, shell);
                // A dense core hides the lobes behind it, while optical thickness still fades at the silhouette.
                half opacity = (1-exp2(-max(tint.a,0)*_CloudDensity*thickness))*edge*outerShell;
                half rim = pow(1-viewFacing,3)*saturate(dot(-view,sun.direction));
                color += softSun * rim * .035;
                return half4(MixFog(color, input.fog), opacity);
            }
            ENDHLSL
        }
    }
    Fallback Off
}
