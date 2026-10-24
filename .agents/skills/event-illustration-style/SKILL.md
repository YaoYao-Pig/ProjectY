---
name: event-illustration-style
description: 为 Project Y 的事件配图、剧情插图和冒险者形象制作或重绘干净平涂的奇幻漫画插画，统一细线勾边、简洁明暗和鲜明冷暖配色。用于插画生成与美术验收，不用于低多边形模型、写实绘画或 UI 布局。
---

# 事件插画：干净平涂奇幻漫画

## 风格基准

先查看 [已认可的冒险者参考图](references/approved-adventurer.png)。它是画风基准，不是要求所有事件复用同一个角色、红披风、酒馆或构图。用户认可的是第二版的干净色块，明确不喜欢第一版脏污、斑驳的质感。

目标：角色有表情、动作讲得清楚、颜色鲜明；缩小到事件窗口后仍一眼能看懂核心情境。

## 绘制规范

- **线条**：深蓝黑或近黑的细轮廓，略有手绘起伏；外轮廓比内部线稍重。用少量短线交代衣褶、发束与结构，不密集排线，不靠粗黑边堆体积。
- **色块**：大面积连续、干净、不透明的平涂。皮肤、布料、石墙和皮革以形状区分，不覆盖颗粒、斑驳、纸纹、脏污蒙版或遍布全图的磨损。
- **明暗**：每种材质以底色和一个明确阴影色为主，必要时加小面积高光。阴影边缘清楚，少量柔和变化可以保留，但不能形成写实塑形、厚涂或电影式光效。
- **配色**：清晰的冷暖对比，青蓝／青绿与砖红／橙棕是可选主调，金黄和米白作小面积点缀，暗部可用深蓝／灰紫。根据雪地、森林、夜晚等实际场景调整；不强行给所有事物染成相同颜色。避免满图灰褐、统一棕色滤镜和大面积死黑。
- **人物**：可信的成人比例与略夸张的漫画表情；面部轮廓简洁、眼神清楚、上眼睑利落。不同年龄、种族与服饰遵循事件内容，不默认复制参考人物。非人角色保持清晰轮廓与性格。
- **场景**：围绕一个叙事瞬间组织主体、关键道具和环境。背景用较少、较大的形状支持主体；真实需要的破损用少量边缘缺口和结构线表达。夜景保持脸、手和道具可辨，雾与魔法用简洁色层表达。
- **画幅**：重绘已有图片时保留原画幅比例、内容安全区与关键物件；只有确需改善阅读性时调整局部构图。完整铺满画面，不添加边框、对话框、文字、签名或水印。

## 事件重绘流程

1. 沿 [ForAI 索引](../../../ForAI/INDEX.md) 定位事件配置与配图来源，读取对应事件正文并查看旧图。锁定人物关系、关键道具、环境与尚未作出的选择；不把某个选项的成功结局画成事件已发生的事实。
2. 使用当前可用的 imagegen 工作流。旧事件图标为 **内容／构图目标**，本技能参考图标为 **仅画风参考**；生成参数遵循工具接口，不把本地路径或前次会话当成永久可用上下文。
3. 根据下方骨架填写具体事件。旧提示词只提取场景事实；去掉其中的 parchment、watercolor、weathered texture、woodcut 等与本风格冲突的渲染描述。
4. 生成后查看实际图片，按验收项检查。出现单一明显问题时定向修正，保留已正确的叙事内容；不要靠换成长提示词重复堆细节。
5. 依本次用户范围保存预览或替换资源。替换现有 Unity 插图时保留原路径和 `.meta`，先保存可恢复的旧图；不要仅因换图修改事件 ID、文本或选项。仅做预览时保留独立候选文件并明确尚未接入。不要为图片验收自行启动 Editor、Play 或编译。
6. 记录目标事件、实际提示词、生成工具、参考图、输出路径及检查结果；交付图片预览。项目路径与接入事实维护在所属 ForAI 文档，不在本技能复制清单。

## 提示词骨架

```text
Use case: style-transfer (existing illustration) / illustration-story (new illustration).
Input roles: existing event image = content/composition target; approved adventurer image = visual style only.
Scene: [event situation, actors and relationships, essential props, environment].
Preserve: [event facts, unresolved choice, aspect ratio, key silhouettes and safe framing].
Style: clean hand-inked fantasy comic illustration, thin dark organic contours, sparse purposeful interior strokes, broad smooth opaque flat colors, simple hard-edged cel shadows. Expressive faces and readable gestures, believable stylized anatomy.
Color and light: [scene-specific cool/warm balance], distinct clear subject colors, restrained gold/ivory accents, simplified blue or muted purple shadows. Faces and key objects remain legible.
Background: simplified large shapes supporting one clear narrative moment; full bleed.
Avoid: mottled grunge, all-over wear, parchment grain, paper texture, dirty color washes, dense crosshatching, muddy brown filter, photorealistic materials, painterly blending, 3D rendering, excessive glow, thick black outlines, UI, captions, borders, text and watermarks.
Do not copy the reference adventurer's identity, costume or tavern unless the event calls for them.
```

## 验收

- **内容正确**：事件的核心冲突、对象和动作可辨；没有新增影响剧情的角色、奖励或结果。
- **表面干净**：连续色块是第一印象；纹理不能盖过轮廓，石墙和皮革不布满随机斑点。
- **层次清楚**：主体与背景分开；暖色与冷色有组织，阴影没有吞掉脸和关键道具。
- **线与比例统一**：细线、疏线、表情鲜明；不变成照片、厚涂、3D、Q版或粗线美漫。
- **小图可读**：在实际事件图区域比例下，能直接看懂谁在做什么；手、道具与边缘裁切合理。

若画面“脏”：先删材质噪声、纸纹与密集排线，再提纯主体颜色；不要用过曝或提高全图饱和度掩盖问题。若夜景太暗：提高人物局部底色与背景的明度差，保留夜色，不添加泛光滤镜。
