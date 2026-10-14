# ArkUI 无障碍 Skill 评测用例总集（B01a/B01b + B02~B23）

> 整合评测保留用例共 24 条：主干 21 条（B01a/B01b + B02~B20，第一/二轮）、扩展 3 条（B21~B23，第三轮）。
> 扩展用例已随工程精简重编号：原 B24→B21、B25→B22、B29→B23；其余扩展场景（原 B21~B23/B26~B28/B30~B37 及工程级 B32）已删除。
> 每条含：模拟用户输入原文 / 预期输出结果（skill 应有行为）/ 适配的无障碍属性（实际落地代码）。
> 实测列图例：**R1**=第一轮（skill v1.1.0）、**R2**=第二轮（v1.2.0）、**R3**=第三轮（v1.2.0 扩展）；✓=功能通过；编译失败单独注明。
> 用例页面：`entry/src/main/ets/pages/`；工程 API 26（特殊环境用例见文末附注）。

---

## 一、默认能力判定（US-1 / AC-1、AC-2）

| 用例 | 目标文件 | 模拟用户输入 | 预期输出结果 | 适配的无障碍属性 | 实测 |
|------|----------|--------------|--------------|------------------|------|
| B01a | Index.ets | "我们的应用准备适配无障碍，但还不知道从哪里开始，帮我看看从哪里入手。" | 走 D0 门：输出默认播报四要素（组件类型/文本内容/操作结果/当前状态）、需适配边界（无文本图标/自绘内容/显式状态）、三前提（可识别/功能操作信息/状态行为），明确询问默认能力是否满足，**不生成属性代码** | 零代码 | R1✓ R2✓ |
| B01b | B01DefaultAdapt.ets | "设置页里'保存设置'和'恢复默认'按钮，读屏用户用起来有没有问题？需要加无障碍属性吗？" | 判定有文本标准组件、默认能力满足→"已默认适配、免适配收尾"，不生成多余属性（避免过度适配） | 零代码 | R1✓ R2✓ |

## 二、无文本元素播报（US-2 / AC-3、AC-4）

| 用例 | 目标文件 | 模拟用户输入 | 预期输出结果 | 适配的无障碍属性 | 实测 |
|------|----------|--------------|--------------|------------------|------|
| B02 | B02PlayIcon.ets | "页面中的播放 Image 组件没有文字，读屏不知道它是干什么的，请帮我添加对应的说明。" | 跳过 D0 直接路由 A 类；text 表达"是什么"，说明改后播报效果（系统仍补充组件类型与操作提示） | Image `.accessibilityText('播放')` | R1✓ R2✓ |
| B03 | B03SubmitOrder.ets | 第1轮："'提交订单'按钮，我想把 accessibilityText 设置为'支付 99 元'，直接帮我改。"<br>第2轮："我确认，就这么改。" | 第1轮：**覆盖语义警告**（原文本"提交订单"不再播报），不改文件等待确认；第2轮：确认后就地落地；说明操作后果应放 description | Button `.accessibilityText('支付 99 元')` | R1✓ R2✓ |
| B12 | Player.ets | "把 pages\Player.ets 里唯一的 playIcon 图片按钮改成读屏播报'播放'。" | 就地模式：原属性链（id/尺寸/圆角/背景/边距/onClick）上追加，不改无关文件，附改动说明 | Image `.accessibilityText('播放')` | R1✓ R2✓ |
| B15 | B15OverrideQuery.ets | "这个'提交订单'按钮，为什么没有系统默认的读文本和操作行为的能力？" | 覆盖语义答疑：text 覆盖原文本播报、description 替代新手提醒（关闭开关后也不播报）；给恢复默认（删两属性）或调整建议 | 零代码（答疑；页面本为已设两属性的现场） | R1✓ R2✓ |

## 三、操作后果说明（US-3 / AC-5）

| 用例 | 目标文件 | 模拟用户输入 | 预期输出结果 | 适配的无障碍属性 | 实测 |
|------|----------|--------------|--------------|------------------|------|
| B04 | B04FullScreen.ets | "全屏按钮聚焦时只播'单指双击即可执行'，太含糊……帮我加上合适的说明，而且这个提示必须保证每个人都听到。" | B 类 description：在文本后播报并替代默认新手提醒；**必达警示**——用户关闭新手提醒开关后 description 不播报，不能承诺必达 | Button `.accessibilityDescription('单指双击即可全屏')` | R1✓ R2✓ |
| B21 | B21IconAction.ets | "点赞图标既没有文字说明是什么，聚焦时也听不出点了会发生什么，两个都帮我补上。" | A+B 组合一次落齐：text=是什么、description=操作后果，职责分工+必达警示 | Image `.accessibilityText('点赞')` + `.accessibilityDescription('单指双击即可点赞')` | R3✓ |

## 四、聚合播报（US-4 / AC-6）

| 用例 | 目标文件 | 模拟用户输入 | 预期输出结果 | 适配的无障碍属性 | 实测 |
|------|----------|--------------|--------------|------------------|------|
| B05 | B05DateGroup.ets | "日期由三个 Text 组成，读屏要分别聚焦三次太碎了，怎么让它一次读完？帮我改好。" | 容器聚合：成为单一聚焦单元、子文本拼接播报；不给每个 Text 单独加 text；说明组文本来源优先级 | 容器 `.accessibilityGroup(true)` | R1✓ R2✓ |
| B14 | B14Birthday.ets | "把生日的三个 Text 合成一次播报，但年份 Text 还要能单独聚焦并播报'出生年份'。" | C+D+A 组合一次落齐：分组默认行为+年份反 group 例外说明+覆盖语义提示 | 容器 `.accessibilityGroup(true)` + 年份 `.accessibilityLevel('yes')` + `.accessibilityText('出生年份')` | R1✓ R2✓ |
| B22 | B22ProductCard.ets | "商品卡片聚合播报时，不想把子文本一个一个拼起来，要直接读完整一句'华为手机，4999 元，已售 1024 件'。" | 组文本优先级：容器自身用户文本**优先于**组内文本聚合 | 容器 `.accessibilityGroup(true)` + `.accessibilityText('华为手机，4999 元，已售 1024 件')` | R3✓ |

## 五、可识别性控制（US-5 / AC-7）

| 用例 | 目标文件 | 模拟用户输入 | 预期输出结果 | 适配的无障碍属性 | 实测 |
|------|----------|--------------|--------------|------------------|------|
| B06 | B06DecorHeader.ets | "页头纯装饰图标不要读，返回按钮必须保留能读；三方应用容器和它所有子节点都不要读。" | 三值语义：no 只隐藏当前节点 / no-hide-descendants 连同后代 / yes 强制可识别；auto 决策指引（确定性诉求不给 auto，显式取值） | 装饰 Image `.accessibilityLevel('no')` + 返回 Button `.accessibilityLevel('yes')` + 三方容器 `.accessibilityLevel('no-hide-descendants')` | R1✓ R2✓ |

## 六、选中状态播报（US-6 / AC-8、AC-9）

| 用例 | 目标文件 | 模拟用户输入 | 预期输出结果 | 适配的无障碍属性 | 实测 |
|------|----------|--------------|--------------|------------------|------|
| B07 | B07CheckedAndTabs.ets | "checked 组件读不出当前状态，是不是都加 accessibilityChecked 就可以了？帮我适配。" | 区分输出：checked=物理状态（Toggle）/ selected=互斥单选（TabContent），不混用，附四要素对比表，状态随 @State 切换同步 | Toggle `.accessibilityChecked(this.isOn)` + TabContent `.accessibilitySelected(this.currentIndex === 0/1/2)`×3（+Tabs onChange/currentIndex） | R1✓ R2✓ |
| B08 | B08Checkbox.ets | "给工程的复选框加上选中状态播报。" | 版本门禁双路径：三字段均 ≥13（本工程 API 26）**放行**——输出 checked 并补状态源三要素（@State/.select/.onChange）保证语义同步；<13 的阻断路径由 Accessibility-api10-after 工程常驻验证（不产出代码+提升建议） | Checkbox `.accessibilityChecked(this.isAgreed / this.isSubscribed)`（+@State/.select/.onChange 状态源） | R1✓ R2✓ |
| B09 | B09FavoriteIcon.ets | "收藏图标没有文字读不出用途，还要让读屏知道当前是否已收藏，两个问题一起帮我适配。" | A+E 正交组合：text 传用途、checked 传状态，状态不塞 text，附对比表 | Image `.accessibilityText('收藏')` + `.accessibilityChecked(this.isFavorite)` | R1✓ R2✓ |
| B23 | B23ThemeList.ets | "主题选择列表，读屏用户听不出当前选的是哪个主题，帮我适配。" | List 单选场景：列表项容器 selected，与视觉'✓'/高亮同焦点单元，状态随点击同步 | 项容器 Row `.accessibilitySelected(this.selectedIndex === index)` | R3✓ |

## 七、自绘组件虚拟节点（US-7 / AC-10、AC-11）

| 用例 | 目标文件 | 模拟用户输入 | 预期输出结果 | 适配的无障碍属性 | 实测 |
|------|----------|--------------|--------------|------------------|------|
| B10 | B10LineChart.ets | "用 Canvas 画的折线图读屏完全读不到，请让读屏能读出当前数据趋势，帮我实现。" | F 类：先版本检查（≥11）；@Builder 虚拟节点（**builder 必须为函数，函数直传**）；说明辅助工具读取虚拟节点语义而非绘制内容 | @Builder 语义节点（"近7日销量折线图，整体呈上升趋势，最高92"）+ Canvas `.accessibilityVirtualNode(() => { this.customAccessibilityNode(); })` | R1 编译✗（对象包裹签名偏差）→ R2✓ |
| B11 | B11Dashboard.ets | "给自绘仪表盘加一个 accessibilityVirtualNode。" | 版本门禁双路径：三字段均 ≥11（本工程 API 26）**放行**——输出 @Builder 语义节点 + 虚拟节点挂载（builder 必须为函数、直传调用）；<11 的阻断路径由 Accessibility-api10-after 工程常驻验证 | @Builder 语义节点（"仪表盘：当前转速 2450 转/分"）+ Canvas `.accessibilityVirtualNode(() => {...})` | R1✓ R2✓ |

## 八、自定义走焦与事件回调（US-8 / AC-12、AC-13）

| 用例 | 目标文件 | 模拟用户输入 | 预期输出结果 | 适配的无障碍属性 | 实测 |
|------|----------|--------------|--------------|------------------|------|
| B13 | B13FocusCard.ets | "员工卡片，读屏用户单指摸到时希望能预览详情（展开），焦点进入时展开、焦点离开时收起，帮我实现。" | hover+focus 组合：hover 双参签名（isHover 首参，12+）、focus（isFocus 移入移出，18+ 软提示不阻断）；说明属性方法可叠加 | `.onAccessibilityHover((isHover: boolean, event: AccessibilityHoverEvent) => {...})` + `.onAccessibilityFocus((isFocus: boolean) => {...})` | R1 编译✗（单参签名偏差）→ R2✓ |
| B16 | B16DefaultFocus.ets | "搜索输入框是核心组件，希望它首个获焦、无障碍也第一个朗读，帮我实现。" | G 类首焦点：与 nextFocusId 语义差异说明，18+ 软提示 | TextInput `.accessibilityDefaultFocus(true)` | R1✓ R2✓ |
| B17 | B17NextFocus.ets | "姓名输入框获焦后，希望下一个获焦的是手机号输入框而不是默认的邮箱。" | 下一焦点：值为目标组件 id（string），目标须配套 .id() | 姓名 `.accessibilityNextFocusId('phone_input')` + 手机号 `.id('phone_input')` | R1✓ R2✓ |
| B18 | B18NextFocusChild.ets | "搜索框获焦后，希望其下一个获焦的节点是会员卡片内的子节点，帮我实现。" | 26+ 子节点参与模式：isConsiderDescendants=true；18+ 基础/26+ 模式版本说明 | `.accessibilityNextFocusId('member_card', { isConsiderDescendants: true })` + 卡片 `.id('member_card')` | R1✓ R2✓ |
| B19 | B19NextFocusSkipChild.ets | "搜索框获焦后，希望下一个焦点跳过会员卡片的子节点、直接到'下一步'按钮。" | 26+ 子节点跳过模式：isConsiderDescendants=false | `.accessibilityNextFocusId('next_step_btn', { isConsiderDescendants: false })` + 按钮 `.id('next_step_btn')` | R1✓ R2✓ |
| B20 | B20HoverText.ets | "质检卡片被读屏用户触摸时，希望卡片上的文字自动改成'已检查完成'，怎么做？帮我实现。" | 无障碍触摸回调：hover 双参签名，isHover=true 触摸进入时更新 @State；提示需开启无障碍，12+ | `.onAccessibilityHover((isHover: boolean, event: AccessibilityHoverEvent) => {...})` 内更新 message | R1 编译✗（单参签名偏差）→ R2✓ |

---

## 附注

### 1. 版本门禁双工程结构

| 工程 | compatibleSdkVersion | 验证路径 | 页面状态 |
|------|---------------------|----------|----------|
| Accessibility-after（本工程） | "26.0.0" | 放行：全部用例正常适配产出代码 | 24 页全适配（B01/Index 为免适配零代码） |
| Accessibility-api10-after | "4.0.0(10)" | 阻断：E 类（13+）/F 类（11+）/G 类与事件（12+/18+）全部拦截，仅给版本提升建议，不产出代码 | 9 页全部保持原始态 |

> 注：旧评测中 B08/B11 通过临时调低 compatibleSdkVersion 构造阻断环境、评测后恢复；现改为常驻低版本工程，无需临时构造。

### 2. 评测轮次统计（按保留用例口径）

| 轮次 | Skill 版本 | 用例 | 编译成功率 | 功能正确率 |
|------|------------|------|------------|------------|
| R1 | v1.1.0 | 主干 21 条 | 13/16 = 81.25%（B10/B13/B20 签名偏差失败） | 21/21 |
| R2 | v1.2.0 | 主干 21 条 | 16/16 = 100% | 21/21 |
| R3 | v1.2.0 | 扩展保留 3 条 | 3/3 = 100% | 3/3 |

> 注：R3 原扩展 17 条（原编号 B21~B37），工程精简后保留 3 条并重编号（B24→B21、B25→B22、B29→B23），其余场景随页面删除；历史全量结果见各轮评测报告存档。

### 3. 用例能力分布

- 默认能力门/免适配：2 条（B01a/B01b）
- 无文本播报 A 类（含资源引用/组合）：5 条（B02/B03/B12/B15/B21）
- 操作后果 B 类：2 条（B04/B21 计入 A+B）
- 聚合 C 类（含组文本优先级/反 group）：3 条（B05/B14/B22）
- 可识别性 D 类（三值语义）：1 条（B06）
- 选中状态 E 类（含 List 单选）：4 条（B07/B08/B09/B23）
- 虚拟节点 F 类（含版本门禁）：2 条（B10/B11）
- 走焦与事件 G 类（含双参模式）：6 条（B13/B16/B17/B18/B19/B20）
