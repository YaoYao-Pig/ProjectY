#ifndef PROJECT_Y_MAP_WEATHER_INCLUDED
#define PROJECT_Y_MAP_WEATHER_INCLUDED

// Shared global field: R = cloud coverage, G = rain intensity; XZ coordinates in world metres.
// The weather presentation owns this texture and disables it before releasing its resources.
TEXTURE2D(_WorldWeatherMap);
SAMPLER(sampler_WorldWeatherMap);
float _WorldWeatherEnabled;
float4 _WorldWeatherRect; // minX, minZ, inverse width, inverse depth

float2 ProjectYWeather(float3 positionWS)
{
    if (_WorldWeatherEnabled < .5) return float2(0, 0);
    float2 uv = (positionWS.xz - _WorldWeatherRect.xy) * _WorldWeatherRect.zw;
    if (any(uv < 0) || any(uv > 1)) return float2(0, 0);
    return saturate(SAMPLE_TEXTURE2D_LOD(_WorldWeatherMap, sampler_WorldWeatherMap, uv, 0).rg);
}

half ProjectYWeatherAttenuation(float3 positionWS)
{
    float2 weather = ProjectYWeather(positionWS);
    return lerp(1.0, .42, weather.x) * lerp(1.0, .90, weather.y);
}

#endif
