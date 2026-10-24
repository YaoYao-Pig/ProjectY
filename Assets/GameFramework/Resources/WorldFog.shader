Shader "ProjectY/World Exploration Fog"
{
    Properties
    {
        _WorldFogMask ("Exploration mask", 2D) = "black" {}
        _FogColor ("Cloud color", Color) = (.45,.53,.57,1)
        _FogPreviewTime ("Preview time", Float) = -1
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent+20" "RenderType"="Transparent" }
        Pass
        {
            Name "ExplorationClouds"
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            TEXTURE2D(_WorldFogMask); SAMPLER(sampler_WorldFogMask);
            float4 _WorldFogMask_TexelSize;
            CBUFFER_START(UnityPerMaterial)
                float4 _WorldFogBounds, _FogColor;
                float _FogPreviewTime;
            CBUFFER_END
            struct Attributes { float3 positionOS : POSITION; };
            struct Varyings { float4 positionCS : SV_POSITION; float3 world : TEXCOORD0; };
            float Hash(float2 p) { return frac(sin(dot(p,float2(127.1,311.7)))*43758.5453); }
            float Noise(float2 p)
            {
                float2 i=floor(p),f=frac(p);f=f*f*(3-2*f);
                return lerp(lerp(Hash(i),Hash(i+float2(1,0)),f.x),lerp(Hash(i+float2(0,1)),Hash(i+1),f.x),f.y);
            }
            float Clouds(float2 p)
            {
                float n=0,a=.53;
                [unroll] for(int i=0;i<4;i++){n+=Noise(p)*a;p=p*2.03+float2(8.7,19.3);a*=.5;}
                return n;
            }
            half3 SoftMask(float2 uv)
            {
                float2 d=_WorldFogMask_TexelSize.xy*3;
                half3 mask=SAMPLE_TEXTURE2D(_WorldFogMask,sampler_WorldFogMask,uv).rgb*.25;
                mask+=(SAMPLE_TEXTURE2D(_WorldFogMask,sampler_WorldFogMask,uv+float2(d.x,0)).rgb
                    +SAMPLE_TEXTURE2D(_WorldFogMask,sampler_WorldFogMask,uv-float2(d.x,0)).rgb
                    +SAMPLE_TEXTURE2D(_WorldFogMask,sampler_WorldFogMask,uv+float2(0,d.y)).rgb
                    +SAMPLE_TEXTURE2D(_WorldFogMask,sampler_WorldFogMask,uv-float2(0,d.y)).rgb)*.125;
                mask+=(SAMPLE_TEXTURE2D(_WorldFogMask,sampler_WorldFogMask,uv+d).rgb
                    +SAMPLE_TEXTURE2D(_WorldFogMask,sampler_WorldFogMask,uv-d).rgb
                    +SAMPLE_TEXTURE2D(_WorldFogMask,sampler_WorldFogMask,uv+float2(d.x,-d.y)).rgb
                    +SAMPLE_TEXTURE2D(_WorldFogMask,sampler_WorldFogMask,uv+float2(-d.x,d.y)).rgb)*.0625;
                return mask;
            }
            Varyings Vert(Attributes input)
            {
                Varyings output;output.world=TransformObjectToWorld(input.positionOS);
                float time=_FogPreviewTime>=0?_FogPreviewTime:_Time.y;
                output.world.y+=sin(output.world.x*.17+time*.23)*.28+cos(output.world.z*.13-time*.17)*.22;
                output.positionCS=TransformWorldToHClip(output.world);return output;
            }
            half4 Frag(Varyings input) : SV_Target
            {
                float time=_FogPreviewTime>=0?_FogPreviewTime:_Time.y;
                float2 uv=(input.world.xz-_WorldFogBounds.xy)*_WorldFogBounds.zw;
                half3 mask=SoftMask(uv);
                float2 p=input.world.xz*.18;
                float n=Clouds(p+float2(time*.025,-time*.018));
                float billow=Clouds(p*.55+float2(-time*.013,time*.02)+n*.8);
                float reveal=smoothstep(.12+n*.14,.8+n*.12,mask.r);
                float unknown=1-smoothstep(.1,.85,mask.g);
                float alpha=(1-reveal)*lerp(.22+billow*.13,.96,unknown)*smoothstep(.03,.4,mask.b);
                half3 color=_FogColor.rgb*(.58+n*.32+billow*.34);
                color+=half3(.055,.065,.07)*smoothstep(.42,.78,billow);
                return half4(color,alpha);
            }
            ENDHLSL
        }
    }
}
