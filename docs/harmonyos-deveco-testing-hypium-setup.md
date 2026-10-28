# DevEco Testing Hypium（Python UI 自动化）安装与环境配置

> 适用前提：回答「Python 版 Hypium 怎么装、装哪些组件、版本怎么配套」。
> 核实自官方《应用UI测试（基于Python）》指南、下载中心与 PyPI/华为云镜像实查
> （2026-10-16 实测）；社区流传的 5.0.3.300 手工 tar.gz 流程是旧版等价做法，版本号早已换代。

## 先分清两个 Hypium（社区高频混淆）

| | @ohos/hypium | DevEco Testing Hypium |
| --- | --- | --- |
| 是什么 | ArkTS 应用**单元测试**框架（arkxtest JsUnit 体系） | **设备 UI 自动化测试**框架（Python，UIDriver/BY 控件选择器/投屏） |
| 分发 | ohpm/npm 包 | PyPI `hypium` + 官网离线包 + PyCharm 插件 |
| 详见 | `harmonyos-unit-testing.md` | 本文 |

名字同源（都出自华为测试体系），认错包是常见事故——`pip install` 装不到单测框架，
ohpm 也装不到 UI 自动化框架。

## 前置环境

1. **Python 3.10**（官方推荐版本，[python.org](https://www.python.org/)）。
2. **hdc**：按官方「调试工具-hdc」的环境准备章节配置（要用它连设备）。
3. **PyCharm ≥2024.2 社区版**（插件与工程模板需要）：
   🌟 官方明示项目创建功能只支持 **2024.2–2026.2**；2024.3 因 PyCharm 自身原因只能选单设备模板。

## 框架安装（两条路）

**方式一：镜像一条命令（官方推荐）**

```bash
pip install hypium -U --trusted-host mirrors.huaweicloud.com \
  -i https://mirrors.huaweicloud.com/repository/pypi/simple
```

🌟 PyPI 公共源也有 `hypium`，但 2026-10-16 实查最新只有 **6.1.0.210**；**26.x 线不在公共 PyPI**，
要最新版本走华为云镜像（依赖 xdevice 系自动解析）或离线包。

**方式二：离线包（26.x 新版本的唯一途径）**

1. 下载中心取 [DevEco Testing Hypium](https://developer.huawei.com/consumer/cn/download/deveco-testing-hypium)
   （当前 Release 26.0.0.500，2026-08-29 发布；直链获取配方见
   `harmonyos-mcp-ecosystem.md` §1.3）。
2. 解压后得 `hypium-26.0.0.500.zip`，**再次解压**进入目录执行自动安装（6.1+ 支持）：

   ```bash
   python install.py -g hypium_basic   # -g 指安装组合
   ```

3. 手工等价做法（旧版通用，**顺序敏感**，与依赖方向一致）：

   ```bash
   python -m pip install xdevice-<版本>-py3-none-any.whl
   python -m pip install xdevice_devicetest-<版本>-py3-none-any.whl
   python -m pip install xdevice_ohos-<版本>-py3-none-any.whl
   python -m pip install hypium-<版本>-py3-none-any.whl
   ```

   🌟 社区教程里的 `xdevice-5.0.3.300.tar.gz` 四连装就是这条路的旧版本写法——组件顺序仍成立，
   版本号请以实际下载包为准，不要照抄 5.0.3.300。

## PyCharm 插件（UiViewer：投屏 + 控件透视）

- 安装包内 `hypium-pycharm-plugin-26.0.0.500.zip` **免解压**，PyCharm → Settings → Plugin →
  齿轮 → Install Plugin from Disk 直接装，装完重启。
- 🌟 6.0 起插件包名由 `DevEcoTesting-Hypium` 改为 `hypium-pycharm-plugin`，搜旧名会扑空；
  插件市场也可直接搜「DevEco Testing Hypium」安装。

## 版本配套铁律

- 🌟 **ROM ≥6.1 且 hypium ≥6.1 时，UiViewer 也必须 ≥6.1**，否则用例执行中 UiViewer 断连。
- 🌟 **Mac 的 UiViewer 需在设置面板手动指定 hdc 路径**（官方注意事项原文），不指则连不上设备。
- 三件套（ROM / hypium / UiViewer-插件）尽量取同一版本线：26.x 配 26.x。
- 2026-10-16 实测边界：**脚本驱动不受此限**——7.0 ROM（模拟器+真机）+ hypium 6.1.0.210 跨线可用，
  uitest agent 首连自动部署协商（实测记录见 `harmonyos-deveco-testing-platform.md`）；该铁律主要约束 UiViewer 投屏。

## 安装包解剖（26.0.0.500 实测）

外层 zip 三组件，用途各异别装混：

| 文件 | 内容 | 用途 |
| --- | --- | --- |
| `hypium-26.0.0.500.zip` | xdevice 系 + hypium wheels | Python 框架本体（本文主角） |
| `hypium-driver-js-26.0.0500.zip` | hypium-driver npm tgz + api_reference.md | Node 驱动库（MCP 底座，见 ecosystem §1.3） |
| `hypium-pycharm-plugin-26.0.0.500.zip` | HypiumAssist jar | PyCharm 插件（UiViewer 投屏） |

## 官方操作指导

[应用UI测试（基于Python）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/hypium-python-guidelines)
——含工程模板、UiViewer 功能区、用例执行与报告全流程；版本说明见
[DevEco Testing 26.0.0 Release Notes](https://developer.huawei.com/consumer/cn/doc/harmonyos-releases/deveco-testing-releasenotes-2600)。

脚本工程结构、API 速查与 hypium-perf 场景化性能脚本见 `harmonyos-deveco-testing-platform.md`。
