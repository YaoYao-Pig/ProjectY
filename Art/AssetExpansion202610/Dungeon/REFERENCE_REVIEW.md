# 地牢参考与贴图审查

本批模型和贴图为原创制作。`References/` 中图像仅作为研究档案，不复制进 Unity，不作为可再分发游戏资产。每个模型及贴图在 manifest 中映射两份实际查看过的游戏画面，完整页面地址、图片地址和借鉴点在 `references.json`。

## 图像参考

已于 2026-10-01 下载并逐张查看九幅画面：Dark Souls III 的卡萨斯地下墓地、伊鲁席尔地下监牢和不死聚落，Dark Souls 的底层木桶区，以及 Skyrim 的乌斯腾格拉、Ruunvald、潮湿洞穴、黑暗经书台与奥术图书馆。画面实际内容包括罐器的敞口/封盖差异、厚壁陶器、烛台、石板拼缝、覆苔岩壁、弯曲木桶板与铁箍、讲台支撑和皮革书脊。借用功能逻辑、轮廓层次和低饱和材质关系，未复制作品标志、纹章或贴图。

## 小说意象

- J. R. R. Tolkien，《霍比特人》第五章 Riddles in the Dark：地下环境与人物脱困的叙事结构参考出版商的 [教师指南](https://www.penguinrandomhouse.com/books/179206/the-hobbit-by-jrr-tolkien/9780345339683/teachers-guide/)。以潮湿、狭窄、暗处生存的意象指导苔墙、储水桶和散落补给的选择，无逐字摘抄。
- J. R. R. Tolkien，《魔戒：护戒使者》第二卷第四章 A Journey in the Dark / 第五章 The Bridge of Khazad-dûm：档案室、墓石与废弃地下文明意象。章节与地点交叉定位使用 [Tolkien Gateway 的 Mazarbul 条目](https://beta.tolkiengateway.net/wiki/Chamber_of_Mazarbul)；模型采用原创日轮标记和账册，没有复制托尔金文字或符文。

## 贴图初审

六张贴图均由内置 imagegen 独立生成，原始像素未作脚本修图。尺寸为实际输出 1254 × 1254，sRGB Base Color；统一建议 Repeat、Trilinear、mipmap，2 米重复尺寸，URP/Lit，Metallic 0、Smoothness 0.12。逐份完整提示词和来源路径已保存于 `texture_manifest.json`。

使用实际图像的 3 × 3 重复审查板检查横纵拼接。原始文件不裁剪、不镜像；诊断板仅重复显示并缩放。另记录两边 RGB 差值与内部相邻像素差值，数值用于暴露异常，不能单独代表视觉通过。

现有 `MapPreviewInstanced.shader` 并无 `_BaseMap`，墙地使用程序图案，`MapAreaRenderer` 陈设批次只抽取纯色与发光。资源生产没有修改这些契约。独立贴图与材质规格可供 URP/Lit 使用，现有地牢生成器自动使用这些贴图需要后续接入。

六张实际 3×3 重复图已经逐张查看：砖缝在边界处可继续读取，没有空白边或明显亮暗断带。图案存在正常重复性，且原始边缘像素并非数学上完全相等。苔墙的边缘差最大，左右平均 13.00/255、上下 15.32/255；已试一次 imagegen 定向修图，新结果左右 15.46、上下 13.98，未整体改善，故保留原图并如实记录。不是以数值近似零宣称无缝，最终 Unity 材质实际观看另行记录。

## 模型审查完成

20 个模型各有 front/side/back/hero 四张真实 Blender 渲染，共 80 张最终图；`review.json` 为逐件、逐方向的亲看记录。模型合计 10692 三角形，20 件均 0 非流形边、0 退化面，有 UV 与材质槽，原点为包围盒底部中心、米制，Unity 正面为 +Z。

首轮真实图审发现五件罐/桶的环带切进斜腹而产生锯齿边，以及卷宗架卷轴悬空约 6cm；袋口也过于像盖子。七件模型已分别修复环带剖面、卷轴高度及袋口布结，并重渲 28 张图复查。修前证据留在 `Previews/BeforeFix/`，修后铜环/铁箍连续，卷轴落在架板，袋口两耳可辨。没有用程序检查代替看图，也没有把 Blender 审查写成 Unity 游戏内验收。
