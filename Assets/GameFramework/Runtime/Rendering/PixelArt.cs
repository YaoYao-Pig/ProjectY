using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ProjectY.Rendering
{
    [Serializable, VolumeComponentMenu("Project Y/Pixel Art")]
    public sealed class PixelArt : VolumeComponent, IPostProcessComponent
    {
        public BoolParameter enableEffect = new BoolParameter(false);

        [Tooltip("目标纵向像素数。按整数倍形成方形像素；540 偏细腻，360 更明显。")]
        public ClampedIntParameter referenceHeight = new ClampedIntParameter(540, 180, 2160);

        [Tooltip("每个颜色通道的色阶数。越低越复古，32 保留较丰富的材质层次。")]
        public ClampedIntParameter colorLevels = new ClampedIntParameter(32, 4, 64);

        [Tooltip("色阶化强度；0 只做像素化，1 完全使用量化后的颜色。")]
        public ClampedFloatParameter colorStrength = new ClampedFloatParameter(.65f, 0, 1);

        [Tooltip("固定在像素网格上的有序抖色。0 关闭，不使用逐帧随机噪点。")]
        public ClampedFloatParameter ditherStrength = new ClampedFloatParameter(.15f, 0, 1);

        [Tooltip("漫画墨线强度；0 关闭。根据深度边界描边，UI 不受影响。")]
        public ClampedFloatParameter outlineStrength = new ClampedFloatParameter(.8f, 0, 1);

        [Tooltip("描边宽度，单位为虚拟像素。建议 1，过宽会吞掉远处人物细节。")]
        public ClampedIntParameter outlineWidth = new ClampedIntParameter(1, 1, 3);

        [Tooltip("相对深度突变阈值；提高可减少远景和地面上的线条。")]
        public ClampedFloatParameter outlineDepthThreshold = new ClampedFloatParameter(.012f, .002f, .1f);

        [Tooltip("硬折面内轮廓的墨线强度。保持低值以免把所有 lowpoly 面画黑。")]
        public ClampedFloatParameter creaseStrength = new ClampedFloatParameter(.22f, 0, 1);

        public bool IsActive() => enableEffect.value;
        public bool IsTileCompatible() => false;
    }
}
