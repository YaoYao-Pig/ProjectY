using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ProjectY.Rendering
{
    [Serializable, VolumeComponentMenu("Project Y/Fantasy Atmosphere")]
    public sealed class FantasyAtmosphere : VolumeComponent, IPostProcessComponent
    {
        public BoolParameter enableEffect = new BoolParameter(false);
        [Tooltip("薄雾与光束的整体强度；0 可比较纯光照/调色。")]
        public ClampedFloatParameter strength = new ClampedFloatParameter(.7f, 0, 1);
        [Tooltip("每米雾密度；小数值保留人物、建筑和地面材质。")]
        public ClampedFloatParameter density = new ClampedFloatParameter(.007f, 0, .05f);
        [Tooltip("低空薄雾的基准世界高度，米。")]
        public FloatParameter baseHeight = new FloatParameter(.5f);
        [Tooltip("雾随高度消散的速度。")]
        public ClampedFloatParameter heightFalloff = new ClampedFloatParameter(.1f, .005f, 1);
        [Tooltip("从可见表面向镜头最多采样多少米，适应远距正交地图相机。")]
        public ClampedFloatParameter maximumDistance = new ClampedFloatParameter(70, 5, 200);
        [Tooltip("雾的环境色，日/月光束沿用实际主光颜色。")]
        public ColorParameter fogColor = new ColorParameter(new Color(.63f, .7f, .77f), false, false, true);
        [Tooltip("受主光阴影遮挡的体积光强度。")]
        public ClampedFloatParameter sunlight = new ClampedFloatParameter(1.25f, 0, 4);
        [Tooltip("朝光方向的散射集中程度，越高越接近可见光束。")]
        public ClampedFloatParameter anisotropy = new ClampedFloatParameter(.5f, 0, .8f);
        [Tooltip("半分辨率光线采样次数。提高会增加 GPU 开销。")]
        public ClampedIntParameter samples = new ClampedIntParameter(12, 4, 24);

        public bool IsActive() => enableEffect.value && strength.value > 0 && density.value > 0;
        public bool IsTileCompatible() => false;
    }
}
