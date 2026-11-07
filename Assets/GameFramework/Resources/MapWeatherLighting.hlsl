#ifndef PROJECT_Y_MAP_WEATHER_LIGHTING_INCLUDED
#define PROJECT_Y_MAP_WEATHER_LIGHTING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "MapWeather.hlsl"

// URP 14 forward PBR composition with local weather applied only to direct sunlight.
// Keep one BRDF evaluation and one additional-light loop; GI, indoor lights and emission retain
// their normal URP behavior. Recheck this composition when upgrading the render pipeline.
half4 ProjectYWeatherFragmentPBR(InputData inputData, SurfaceData surfaceData)
{
    #if defined(_SPECULARHIGHLIGHTS_OFF)
        bool specularHighlightsOff = true;
    #else
        bool specularHighlightsOff = false;
    #endif
    BRDFData brdfData;
    InitializeBRDFData(surfaceData, brdfData);
    #if defined(DEBUG_DISPLAY)
        half4 debugColor;
        if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor)) return debugColor;
    #endif

    BRDFData clearCoat = CreateClearCoatBRDFData(surfaceData, brdfData);
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor ao = CreateAmbientOcclusionFactor(inputData, surfaceData);
    uint meshRenderingLayers = GetMeshRenderingLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, ao);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lighting = CreateLightingData(inputData, surfaceData);
    lighting.giColor = GlobalIllumination(brdfData, clearCoat, surfaceData.clearCoatMask,
        inputData.bakedGI, ao.indirectAmbientOcclusion, inputData.positionWS,
        inputData.normalWS, inputData.viewDirectionWS, inputData.normalizedScreenSpaceUV);
    #ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
    #endif
    {
        lighting.mainLightColor = LightingPhysicallyBased(brdfData, clearCoat, mainLight,
            inputData.normalWS, inputData.viewDirectionWS, surfaceData.clearCoatMask, specularHighlightsOff)
            * ProjectYWeatherAttenuation(inputData.positionWS);
    }

    #if defined(_ADDITIONAL_LIGHTS)
        uint pixelLightCount = GetAdditionalLightsCount();
        #if USE_FORWARD_PLUS
        for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
        {
            FORWARD_PLUS_SUBTRACTIVE_LIGHT_CHECK
            Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, ao);
            #ifdef _LIGHT_LAYERS
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
            #endif
            {
                lighting.additionalLightsColor += LightingPhysicallyBased(brdfData, clearCoat, light,
                    inputData.normalWS, inputData.viewDirectionWS, surfaceData.clearCoatMask, specularHighlightsOff);
            }
        }
        #endif
        LIGHT_LOOP_BEGIN(pixelLightCount)
            Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, ao);
            #ifdef _LIGHT_LAYERS
            if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
            #endif
            {
                lighting.additionalLightsColor += LightingPhysicallyBased(brdfData, clearCoat, light,
                    inputData.normalWS, inputData.viewDirectionWS, surfaceData.clearCoatMask, specularHighlightsOff);
            }
        LIGHT_LOOP_END
    #endif
    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
        lighting.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif
    #if REAL_IS_HALF
        return min(CalculateFinalColor(lighting, surfaceData.alpha), HALF_MAX);
    #else
        return CalculateFinalColor(lighting, surfaceData.alpha);
    #endif
}

#endif
