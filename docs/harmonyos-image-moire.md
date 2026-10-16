# 图像抗摩尔纹（anti-moiré / descreen）：原理、方案与端侧落地

> 适用前提：HarmonyOS（及一般移动端）应用展示**高分辨率扫描件/网点图**（漫画、报纸、传真、翻拍屏幕照）时出现横竖条纹，需做去/抗摩尔纹。
> 核实时间：2026-10-16（同日经二次核验修订，记录见 §9）。方法：GitHub 实访 + 源码核对 + 本机 HarmonyOS SDK 头文件实查。
> 项目特化的现状分析、file:line 与借鉴建议留在 manbo-reader `docs/antimoire-survey.md`，本文只留通用机制与方案判断。

## 1. 先分清三类摩尔纹（最常见的选型错误）

把下面三类混为一谈会直接选错算法：

| 类型 | 成因 | 发生环节 | 解法方向 |
| --- | --- | --- | --- |
| **A. minification 摩尔纹** | 高分原图被缩小时，采样窗口与网点 / 像素栅格拍频 | 显示期缩放 | 解码期一次性高质量降采样到≈显示分辨率 |
| **B. 网点本体（screentone）** | 印刷/扫描的半色调网点本身就是高频周期图案（漫画灰阶即由此构成） | 图内固有信息 | 空间域保边滤波去网纹，或按目标频率**重新生成**网点 |
| **C. 屏摄摩尔纹** | 相机 CFA 与屏幕子像素拍频，产生彩色横竖条纹 | 采集期（源头已污染） | 频域陷波，或去摩尔纹深度模型 |

**判据**：条纹随缩放比例变化 → A；条纹固定在图上、缩放后仍在原位置 → B；整页彩色条纹且换一张图就变 → C。

## 2. 核心机制：摩尔纹源自最终的缩放比例，不是源自图像内容

这是本主题最有价值的一条结论，直接决定方案取舍。

**「先模糊 / 先缩小再放大回原尺寸」这类低通做法无法解决 A**——图最终仍是原始大分辨率，缩放照旧发生，条纹照旧出现，只是内容更糊。

解 A 只有一条路：**让最终缩放比例接近 1:1**，即解码后就降采样并保持该小尺寸。网点在这次高质量面积平均中被合成为平滑灰阶。

代价是放大时细节变少，故应做成可选项而非默认开。

**第三方背书**：Kindle Comic Converter 走同一条路，README 明说缩到设备原生分辨率"可以改善续航、翻页速度"，大图用 `LANCZOS`、小图才用 `BICUBIC`（[image.py:603](https://github.com/ciromattia/kcc/blob/master/kindlecomicconverter/image.py)）。

## 3. 渲染层已被主流平台放弃（两条负面证据）

不要指望在渲染管线里做抗摩尔纹：

- **浏览器**：MDN `image-rendering` 的 `auto` 默认由 UA 决定（Firefox 3.0 起 Gecko 用双线性）；规范里的 `high-quality` **无浏览器支持**；`crisp-edges` / `pixelated` 是最近邻，**反而放大摩尔纹**（[MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/image-rendering)）。
- **Android**：`BitmapFactory.Options.inSampleSize` 只做子采样（省内存，非抗锯齿），`inDither` 在 **API 24 已废弃并忽略**（[Android Reference](https://developer.android.com/reference/android/graphics/BitmapFactory.Options)）。

**渲染层唯一值得做的**：把「缩小时的插值质量」做成用户可见开关（低 / 中 Mipmap / 高），默认选 Mipmap。ArkUI 的 `ImageInterpolation.Medium` 即系统 Mipmap 三角过滤，是把窗口内高频成分按面积平均掉，成本仅一处 `.interpolation()` 属性。

> ⚠️ 存疑：`ImageInterpolation.Medium` 是否严格等于 Mipmap，本次仅据第三方项目的文案认定，**未查 HarmonyOS 官方 API 文档交叉验证**。照搬前请用 `devecocli docs search` 确认。

## 4. 方案盘点

### 4.1 空间域（端侧首选）

| 项目 | 做法 | license / 端侧 |
| --- | --- | --- |
| [natethegreate/Screentone-Remover](https://github.com/natethegreate/Screentone-Remover) | 面向 doujin/manga 网点：GaussianBlur 5×5（档 1/2）/ 7×7（档 3）→ bilateral(σ_color=30/50/80, σ_space=80) → 3×3 Laplacian 回边（`sh_point=5.56, sh_low=-1.14`） | 无声明 / 高 |
| [GrantMoyer/doubletone](https://github.com/GrantMoyer/doubletone) | 扫描半调图去网 | CC0 / 中 |
| [gmelodie/silentMoire](https://github.com/gmelodie/silentMoire) | 合成横/竖/斜摩尔纹 + FFT 域去噪 | MIT / 中 |

**最有价值的工艺细节：用双边滤波替代纯高斯**。纯高斯会把网点背景色阶和线条一起糊掉，双边滤波保边，对线条密集的内容是决定性差异。另两条边缘路线（未验证，二次核验补录）：[Patrickctyyx/Screentone-Removal](https://github.com/Patrickctyyx/Screentone-Removal)（无 license）——线稿/网点**分离**路线；[Johnknee109/Manga-Screentone-Remover](https://github.com/Johnknee109/Manga-Screentone-Remover)（无 license）——「模糊去网点 → Real-ESRGAN 修复 → 线稿重融合」流水线。

### 4.2 频域（需自带 FFT）

| 项目 | 做法 | 备注 |
| --- | --- | --- |
| [6o6o/fft-descreen](https://github.com/6o6o/fft-descreen) | 归一化幅度谱阈值建 mask → 膨胀 + 高斯羽化 → 乘性衰减 | MIT，最贴合扫描件网纹 |
| [ciromattia/kcc](https://github.com/ciromattia/kcc) `--eraserainbow` | `rfft2` → 高频（≥0.30 cycles/pixel）+ 135°/45° 对角线族（±10°）掩膜 → 幅度 ×0.1 → `irfft2`，RGB↔YUV 切换 | 目标是彩 e-ink 彩虹纹，非网点；ISC 许可 |
| [Its-my-right/pocketbook_cfa_interference_breaker](https://github.com/Its-my-right/pocketbook_cfa_interference_breaker) | 纯 C + FFTW 的 **in-place 帧缓冲**滤波，双半径带通（`radius_min` / `radius_max_diviser`） | ⚠️ **GPL-3.0**（不可并入闭源项目）；构建目标 armv7-a softfp（koreader 平台），非 arm64 |
| [Hakkin/PtDescreen](https://github.com/Hakkin/PtDescreen) | C + FFTW：FFT 峰值检测找网点频率/角度后掩膜（GIMP Descreen 同类思路） | GPL-2.0；2015 起停更，非网点图会误报 |

收益边界参考 KCC issue：#771 维护者直言彩屏灰阶彩虹纹"本质是彩 e-ink 的物理限制"，**降分辨率 / 模糊只是缓解**。

### 4.3 选择性掩膜（最值得借鉴的思路）

[puff-dayo/simple-comic-reader](https://github.com/puff-dayo/simple-comic-reader) 是唯一做到"选择性处理"的实现：`Demoire: ON/OFF` 开关（仅 zip），算法为空间域 + 频域双掩膜融合——局部标准差（`std_k=11, std_mult=0.7`）做线纹理掩膜，256×256 分块 FFT 峰值/中位数比 > 8.0 判定周期性做频域掩膜，相加后高斯羽化 σ=4.0。

**价值**：只在有周期性网纹的区域处理，线条区不动，避免全图一刀切的画质损失，从而可以放宽默认强度。

### 4.4 AI 去摩尔纹：成熟但场景错配，且无端侧生态

- **数据集全不覆盖网点**：见 [Awesome-Demoireing](https://github.com/rebeccaeexu/Awesome-Demoireing)（88★）。TIP-2018 "No text scenes"、LCDMoiré（AIM 2019 挑战赛数据集）"Only text scenes" 且非真实、FHDMi / UHDM / TMM22 为 "Diverse scenes"——**无一个数据集覆盖漫画 screentone**。这类模型针对"相机 CFA 与屏幕子像素拍频"的合成彩色条纹训练，用在黑白漫画网点上大概率损伤线条。
- **端侧硬数据**：UHDM（[CVMI-Lab/UHDM](https://github.com/CVMI-Lab/UHDM)，Apache-2.0）官方 demo 注明 **CPU 下 4K 单图约 80s**。MBCNN（[arXiv:1909.11947](https://arxiv.org/abs/1909.11947)）、LBPNet、FHDe²Net、UniDemoire（MIT）均无端侧实证。
- **唯一端侧实时路线不可用**：[DDA](https://github.com/zyxxmu/DDA)（ICLR 2023）超网按 patch 复杂度分配大小网络、骁龙 8 Gen1 实时，但**无 license、仅 PyTorch 权重、无 onnx/ncnn/mnn 移植**。
- **端侧生态为空**：检索 `demoireing onnx` / `moire removal ncnn`，**GitHub 仓库检索 0 结果**（仓库搜索不覆盖代码内容），无任何第三方端侧推理移植。
- **方向相反的 MangaJaNai**（[the-database/MangaJaNai](https://github.com/the-database/MangaJaNai)）：不去网点，而是**按目标频率重新生成网点**——针对 1200p/1300p/1400p/1500p/1600p/1920p/2048p 七种常见数字版高度各训一个模型，"多数情况下正确复原了低质源图里已不可见的网点"。**但 license 为 CC BY-NC 4.0（非商业），商业应用不可用**（GUI 为 GPL-3.0）。
- **反向检索亦为空**：`halftone removal neural` / `screentone removal deep learning` 等 6 组检索全部 0 结果；搜到的 `sketch2manga`、`ScreenStyle`、`ComfyUI-MangaScreen` 都是**生成**网点而非去除。唯一 NN 反例是 [curegit/deep-descreen](https://github.com/curegit/deep-descreen)（AGPL-3.0，实验性、未发布权重）：CNN 去扫描件印刷网点、保线稿。**结论：漫画 screentone removal 的深度学习方向没有成熟、可端侧的开源生态。**
- **生态实测**：manga-image-translator 完整克隆 grep 后，`manga_translator/` 下无任何 moire / descreen / halftone 处理——"超分生态顺手处理网点"是错觉。

### 4.5 同类产品现状

mihon（24.4k★）全库 920 个 `.kt` 检索 descreen / moire 0 命中（唯一滤镜相关是灰度用的 `ColorMatrixColorFilter`）；Calibre（26.2k★）代码层 0 命中（`descreen` 仅命中 `is_widescreen` 子串与词典文件）；koreader 的相关需求仍是 open FR（[#11877](https://github.com/koreader/koreader/issues/11877)）。**主流阅读器基本都把抗摩尔纹交给用户手动降分辨率**，是可差异化项，但无人做也说明重要性未达共识，宜保持可选项。

## 5. HarmonyOS 端侧三通道（本机 SDK 实查，2026-10-16）

| 通道 | 可行性 | 依据与限制 |
| --- | --- | --- |
| **ArkTS / ImageKit** | **高**，零新依赖 | `PixelMap.scale(f, f, image.AntiAliasingLevel.HIGH)` 可用；空间域模糊 / 双边 / 锐化均有原生原语。⚠️ **勿用 ArkTS 手写逐像素循环**，太慢，必须走原生滤镜 |
| **C++ NDK** | **高**，频域需自备 FFT | 空间域十几行可完成；频域需移植 FFTW。SDK 自带 `llvm/lib/aarch64-linux-ohos/libomp`（OpenMP 可并行），但**全 SDK 无任何 FFT 库**（fftw / pocketfft 均无） |
| **GPU shader（Vulkan/GLSL）** | 中 | 空间域 5-tap / 双边可 GPU 化；**FFT 在移动 GPU 上不划算**（多 pass + tile 约束），且图形管线通常已被页翻引擎占用上下文 |

**成本 / 收益粗判**：空间域三级滤波 1~2 天、零新依赖；频域方案 5~10 天 + FFTW 移植，收益仅限扫描 / 翻拍件，对数字原生内容边际收益低。

## 6. 工程配方

### 6.1 最小可行实现（空间域）

在解码后、显示前，按强度档执行：

```
GaussianBlur 5×5（档 1/2）/ 7×7（档 3） → bilateralFilter(d=7, σ_color = 30/50/80, σ_space = 80) → 3×3 Laplacian 回边（sh_point=5.56, sh_low=-1.14）
```

用 ImageKit 原语即可完成，无新依赖，天然"只动网点不动线条"。

### 6.2 两个必查的耦合点（易踩）

任何**改变降噪像素内容**的方案，都要检查：

1. **裁剪 / 检测签名**——自动裁白边、整页检测等若在降噪后的像素上做，开关一翻结论就变。需把该开关编进缓存指纹，否则跨模式复用旧结果会错裁。
2. **缓存键**——切块 / 分片缓存的 key 必须覆盖所有影响像素内容的开关，否则换档后命中旧产物。

### 6.3 参数设计：两轴解耦

把「强度」做成**降采样倍率 × 滤波强度**两个独立参数，而不是一个绑死的档位。单轴设计会让"去条纹"与"保细节"直接对立，用户只能二选一；两轴解耦后弱档也能保持较高分辨率、靠滤波压条纹，显著改善放大体验。

### 6.4 跳过护栏

降采样前设两条跳过条件，避免无谓拷贝与画质损失：

- 竖长条图（如高 > 宽 × 2.2）跳过：它们通常按宽度贴合显示、缩放比小，摩尔纹非主要问题，按最长边缩会把宽度压垮变糊。
- 原图最长边已 ≤ 目标分辨率时跳过：不会再大幅缩小，本就无条纹。

## 7. 一句话记忆点

> **摩尔纹源自最终的缩放比例，不是源自图像内容**——所以 minification 型只能"让缩放接近 1:1"，网点本体型才是"保边滤网点"，AI 模型是为屏摄型而生、对网点场景是错配。而在此之前，先确认开关在所有渲染路径上都接了线。

## 8. 存疑

- `ImageInterpolation.Medium` = Mipmap 未经官方文档交叉验证（§3）。
- AIM/NTIRE 去摩尔纹挑战赛页面无法访问（CodaLab 搜索接口已废弃、`aim2023.csalab.org` 连接失败），**无有效链接，不做断言**。
- SRMoire / DynaMoire 在 arXiv（title + all 多组关键词）与 GitHub 仓库搜索均 0 命中，**无法核验是否存在**。
- Skia / Impeller 的具体滤波实现未能核验（skia.org 404、Direct3D 文档 404、OpenCV 文档站 403），故 §3 未据此下结论。
- `Moire-Pattern-Detection`（AmadeusITGroup，license `NOASSERTION`）未深入读源码；`doubletone`（CC0，0★）、`MopReM`（MIT，屏摄文档域）未做源码验证，仅记录存在性；`deep-descreen`（AGPL-3.0，1★）已读源码：实验性 CNN 去扫描件网点、未发布权重（见 §4.4）。

## 9. 二次核验修订记录（2026-10-16）

外部主张全部回一手来源复核，修正如下：

| # | 原表述 | 修正后 | 依据 |
|---|---|---|---|
| 1 | pocketbook 项目「纯 C、arm64 可编译」 | **GPL-3.0**（不可并入闭源项目）；构建目标 **armv7-a softfp**，非 arm64 | 仓库 `LICENSE` 与 `makefile` |
| 2 | KCC 掩膜「环形半径 + 135°/45° 方向掩膜」 | 高频（≥0.30 cycles/pixel）+ 135°/45° 对角线族（±10°，含 +90°/+180° 变体），幅度 ×0.1；补 ISC 许可 | `rainbow_artifacts_eraser.py:20-30` |
| 3 | 数据集「AIM-2018 "No text scenes"」 | 该行实为 **TIP-2018**；「Only text scenes」对应 AIM 2019 的 LCDMoiré | Awesome-Demoireing 数据集表 |
| 4 | Calibre「`descreen` 1 命中」 | 代码层 0 命中（`is_widescreen` 子串与词典文件） | 全仓检索 |
| 5 | Screentone-Remover「GaussianBlur(5/7)、σ_color=10×level」 | 三档 = Gaussian 5×5/7×7 → bilateral σ_color=**30/50/80** | `stremove.py:18-26` |
| 6 | 否定性措辞「全网 0 结果」 | 「**GitHub 仓库检索 0 结果**」（仓库搜索不覆盖代码内容） | GitHub Search API 语义 |

补录：PtDescreen（GPL-2.0，§4.2）、deep-descreen（实验性 NN 去网点，§4.4）、koreader FR #11877（§4.5）、线稿/网点分离与「模糊→超分→线稿重融合」两条边缘路线（§4.1 注）。

---

来源项目特化版本：manbo-reader `docs/antimoire-survey.md`（含本项目现状 file:line、NextE/reader-kit 对照与具体借鉴建议）。
