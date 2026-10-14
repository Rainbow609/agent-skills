# 测试提示词

> 本 Skill 评测基于 `test-cases/` 下两个测试工程：
>
> | 工程 | compatibleSdkVersion | 验证路径 | 输入条数 |
> |------|---------------------|----------|----------|
> | `Accessibility-before` | "26.0.0"（API 26） | 放行：正常适配产出代码 | 24 |
> | `Accessibility-api10-before` | "4.0.0(10)"（API 10） | 阻断：API 版本门禁拦截，仅给版本提升建议，不产出代码 | 9 |
>
> 执行方式：将装配 Skill 的 Agent 工作目录置于对应工程内，逐条输入下列提示词，核对预期输出。
> 完整用例说明见两工程内的 `skill-eval-cases-full.md` 与 `skill-eval-cases-api10-block.md`。

## 基础功能测试

> 以下场景 1~22 在 `Accessibility-before` 工程（API 26，放行侧）中执行，页面位于 `entry/src/main/ets/pages/`。

### 测试场景 1：泛化诉求走 D0 默认能力门（B01a / Index.ets）
**提示词**：
```
我们的应用准备适配无障碍，但还不知道从哪里开始，帮我看看从哪里入手。
```
**预期输出**：
- 走 D0 门：输出默认播报四要素（组件类型/文本内容/操作结果/当前状态）、需适配边界（无文本图标/自绘内容/显式状态）、无障碍可达三前提（可识别/功能操作信息/状态行为）
- 明确询问默认能力是否满足，不生成属性代码

### 测试场景 2：有文本标准组件免适配判定（B01b / B01DefaultAdapt.ets）
**提示词**：
```
设置页里那两个'保存设置''恢复默认'按钮，读屏用户用起来有问题吗？需要专门处理吗？
```
**预期输出**：
- 判定有文本标准组件、默认能力满足 → 告知"已默认适配、免适配收尾"
- 不生成多余属性代码（避免过度适配）

### 测试场景 3：无文本图标播报 A 类（B02 / B02PlayIcon.ets）
**提示词**：
```
这个页面里的播放图标没有文字，读屏不知道它是干什么的，帮我加上说明。
```
**预期输出**：
- 跳过 D0 直接路由 A 类；text 表达"是什么"
- 说明改后播报效果（系统仍补充组件类型与操作提示）
- 落地 Image `.accessibilityText('播放')`

### 测试场景 4：操作后果说明 B 类 + 必达警示（B04 / B04FullScreen.ets）
**提示词**：
```
这个全屏按钮聚焦时只说'单指双击即可执行'，太含糊了，用户根本不知道点了会进入全屏。帮我加上说明，而且这个提示必须保证每个人都听到。
```
**预期输出**：
- B 类 description：在文本后播报并替代默认新手提醒
- 必达警示：用户关闭新手提醒开关后 description 也不播报，不能承诺"必达"
- 落地 Button `.accessibilityDescription('单指双击即可全屏')`

### 测试场景 5：整组朗读降噪 C 类（B05 / B05DateGroup.ets）
**提示词**：
```
日期是年、月、日三段文字，读屏要分别聚焦三次才能听完，太碎了，能不能一次读完？帮我改好。
```
**预期输出**：
- 容器聚合：成为单一聚焦单元、子文本拼接播报
- 不给每个 Text 单独加 text；说明组文本来源优先级
- 落地容器 `.accessibilityGroup(true)`

### 测试场景 6：可识别性三值语义 D 类（B06 / B06DecorHeader.ets）
**提示词**：
```
页头那个纯装饰的小圆点图标不要读出来，但它下面的返回按钮必须保留能读；还有下面那个三方内容区和它里面所有东西都不要读，帮我处理。
```
**预期输出**：
- 三值语义：no 只隐藏当前节点 / no-hide-descendants 连同后代 / yes 强制可识别
- 确定性诉求不给 auto，改给显式取值
- 落地装饰 Image `.accessibilityLevel('no')` + 返回 Button `.accessibilityLevel('yes')` + 三方容器 `.accessibilityLevel('no-hide-descendants')`

### 测试场景 7：checked 与 selected 区分 E 类（B07 / B07CheckedAndTabs.ets）
**提示词**：
```
页面里的开关和标签页，读屏听不出当前开的是哪个、选中的是哪个，是不是都标记成'勾选状态'就行了？帮我适配。
```
**预期输出**：
- 纠正"都标勾选"的误用思路：checked=物理状态（Toggle）/ selected=互斥单选（TabContent），不混用，附四要素对比表
- 状态随 @State 切换同步
- 落地 Toggle `.accessibilityChecked(this.isOn)` + TabContent `.accessibilitySelected(this.currentIndex === 0/1/2)` ×3（含 Tabs onChange/currentIndex）

### 测试场景 8：复选框选中状态 + 状态源三要素（B08 / B08Checkbox.ets）
**提示词**：
```
给工程里的复选框加上选中状态播报。
```
**预期输出**：
- 版本门禁放行（本工程三字段均 ≥13）
- 输出 checked 并补状态源三要素（@State/.select/.onChange）保证语义同步
- 落地 Checkbox `.accessibilityChecked(this.isAgreed / this.isSubscribed)`

### 测试场景 9：A+E 正交组合（B09 / B09FavoriteIcon.ets）
**提示词**：
```
这个收藏图标没有文字读不出用途，另外还要让读屏知道当前是否已收藏，两个问题一起帮我适配。
```
**预期输出**：
- A+E 组合一次落齐：text 传用途、checked 传状态，状态不塞 text，附对比表
- 落地 Image `.accessibilityText('收藏')` + `.accessibilityChecked(this.isFavorite)`

### 测试场景 10：自绘组件虚拟节点 F 类（B10 / B10LineChart.ets）
**提示词**：
```
用 Canvas 画的折线图读屏完全读不到，请让读屏能读出当前的数据趋势，帮我实现。
```
**预期输出**：
- F 类：先版本检查（≥11 放行）
- @Builder 虚拟节点（builder 必须为函数、函数直传）；说明辅助工具读取虚拟节点语义而非绘制内容
- 落地 @Builder 语义节点（"近7日销量折线图，整体呈上升趋势，最高92"）+ Canvas `.accessibilityVirtualNode(() => { this.customAccessibilityNode(); })`

### 测试场景 11：自绘仪表盘虚拟节点（B11 / B11Dashboard.ets）
**提示词**：
```
给自绘的仪表盘加上读屏能读的内容。
```
**预期输出**：
- 版本门禁双路径说明：三字段均 ≥11（本工程 API 26）放行；<11 阻断路径由 api10 工程验证
- 输出 @Builder 语义节点 + 虚拟节点挂载（builder 必须为函数、直传调用）
- 落地 @Builder 语义节点（"仪表盘：当前转速 2450 转/分"）+ Canvas `.accessibilityVirtualNode(() => {...})`

### 测试场景 12：A 类就地模式（B12 / Player.ets）
**提示词**：
```
把播放器页面里唯一的那个播放图片按钮，改成读屏播报'播放'。
```
**预期输出**：
- 就地模式：在原属性链（id/尺寸/圆角/背景/边距/onClick）上追加，不改无关文件，附改动说明
- 落地 Image `.accessibilityText('播放')`

### 测试场景 13：hover+focus 事件组合（B13 / B13FocusCard.ets）
**提示词**：
```
这张卡片，读屏用户单指摸到时希望能预览详情（展开），焦点进入时展开、焦点离开时收起，帮我实现。
```
**预期输出**：
- hover 双参签名（isHover 首参，12+）；focus（isFocus 移入移出，18+ 对满足版本工程仅软提示不阻断）；逐方法标注版本差异
- 说明属性方法可叠加
- 落地 `.onAccessibilityHover((isHover: boolean, event: AccessibilityHoverEvent) => {...})` + `.onAccessibilityFocus((isFocus: boolean) => {...})`

### 测试场景 14：C+D+A 组合一次落齐（B14 / B14Birthday.ets）
**提示词**：
```
把生日的三段文字合成一次播报，但年份那段还要能单独聚焦并念'出生年份'，帮我改好。
```
**预期输出**：
- 分组默认行为 + 年份反 group（level('yes')）例外说明 + 覆盖语义提示
- 落地容器 `.accessibilityGroup(true)` + 年份 `.accessibilityLevel('yes')` + `.accessibilityText('出生年份')`

### 测试场景 15：G 类首焦点（B16 / B16DefaultFocus.ets）
**提示词**：
```
搜索页里搜索输入框是核心组件，希望进入页面后读屏第一个聚焦、第一个朗读的就是它，帮我实现。
```
**预期输出**：
- G 类首焦点：与 nextFocusId 语义差异说明，18+ 软提示（本工程满足版本）
- 落地 TextInput `.accessibilityDefaultFocus(true)`

### 测试场景 16：下一焦点基础用法（B17 / B17NextFocus.ets）
**提示词**：
```
姓名输入框聚焦后，希望下一个聚焦的是手机号输入框而不是默认的邮箱，帮我实现。
```
**预期输出**：
- 下一焦点：值为目标组件 id（string），目标须配套 `.id()`
- 落地姓名 `.accessibilityNextFocusId('phone_input')` + 手机号 `.id('phone_input')`

### 测试场景 17：下一焦点子节点参与模式（B18 / B18NextFocusChild.ets）
**提示词**：
```
搜索框聚焦后，希望下一个焦点进入会员卡片里面的子内容，帮我实现。
```
**预期输出**：
- 26+ 子节点参与模式：isConsiderDescendants=true；18+ 基础/26+ 模式版本说明
- 落地 `.accessibilityNextFocusId('member_card', { isConsiderDescendants: true })` + 卡片 `.id('member_card')`

### 测试场景 18：下一焦点子节点跳过模式（B19 / B19NextFocusSkipChild.ets）
**提示词**：
```
搜索框聚焦后，希望下一个焦点跳过会员卡片里的子内容、直接到'下一步'按钮，帮我实现。
```
**预期输出**：
- 26+ 子节点跳过模式：isConsiderDescendants=false
- 落地 `.accessibilityNextFocusId('next_step_btn', { isConsiderDescendants: false })` + 按钮 `.id('next_step_btn')`

### 测试场景 19：无障碍触摸回调更新文本（B20 / B20HoverText.ets）
**提示词**：
```
质检卡片被读屏用户摸到时，希望卡片上的文字自动变成'已检查完成'，怎么做？帮我实现。
```
**预期输出**：
- 无障碍触摸回调：hover 双参签名，isHover=true 触摸进入时更新 @State；提示需开启无障碍，12+
- 落地 `.onAccessibilityHover((isHover: boolean, event: AccessibilityHoverEvent) => {...})` 内更新 message

### 测试场景 20：A+B 组合一次落齐（B21 / B21IconAction.ets）
**提示词**：
```
这个点赞图标既没有文字说明是什么，聚焦时也听不出点了会发生什么，两个都帮我补上。
```
**预期输出**：
- A+B 组合：text=是什么、description=操作后果，职责分工 + 必达警示
- 落地 Image `.accessibilityText('点赞')` + `.accessibilityDescription('单指双击即可点赞')`

### 测试场景 21：组文本优先级（B22 / B22ProductCard.ets）
**提示词**：
```
商品卡片聚合播报时，我不想让它把子文本一段一段拼起来，要直接读完整一句'华为手机，4999 元，已售 1024 件'，怎么弄？
```
**预期输出**：
- 组文本优先级：容器自身用户文本优先于组内文本聚合
- 落地容器 `.accessibilityGroup(true)` + `.accessibilityText('华为手机，4999 元，已售 1024 件')`

### 测试场景 22：List 单选选中状态（B23 / B23ThemeList.ets）
**提示词**：
```
主题选择列表，读屏用户听不出当前选的是哪个主题，帮我适配。
```
**预期输出**：
- List 单选场景：列表项容器 selected，与视觉'✓'/高亮同焦点单元，状态随点击同步
- 落地项容器 Row `.accessibilitySelected(this.selectedIndex === index)`

## 边界条件测试

> 以下场景 23~31 在 `Accessibility-api10-before` 工程（`compatibleSdkVersion = "4.0.0(10)"`，阻断侧）中执行。
> 9 条用例通用阻断预期：
> 1. 读工程 `build-profile.json5`：compatibleSdkVersion = 10、targetSdkVersion = 26（compileSdkVersion 未显式配置，以 compatibleSdkVersion 为判定下限）；
> 2. 按"三字段任一低于属性下限 → 阻断"判定，全部涉诉属性下限（11/12/13/18）均高于 10 → 阻断；
> 3. 输出三要素：① 需 API X+ 的说明；② compatibleSdkVersion 提升到目标 API 的具体修改建议（版本串格式 "X.Y.Z(N)"，如 11=`4.1.0(11)`、12=`5.0.0(12)`、13=`5.0.1(13)`）；③ 明确不生成属性代码的原因（低版本 SDK 无法编译）；
> 4. 终态：页面零改动，工程保持可编译（阻断≠报错，是 Skill 主动拦截）。

### 测试场景 23：checked 物理状态阻断（B08 / B08Checkbox.ets，下限 API 13）
**提示词**：
```
给工程里的复选框加上选中状态播报。
```
**预期输出**：
- 路由 E 类 → 10 < 13 阻断；说明需 API 13+，给字段提升建议，不生成 checked 代码

### 测试场景 24：List 单选 selected 阻断（B23 / B23ThemeList.ets，下限 API 13）
**提示词**：
```
主题选择列表，读屏用户听不出当前选的是哪个主题，帮我适配。
```
**预期输出**：
- 路由 E 类 List 单选（selected，13+）→ 10 < 13 阻断；说明需 API 13+，给提升建议

### 测试场景 25：checked/selected 误用纠正 + 阻断（B07 / B07CheckedAndTabs.ets，下限 API 13）
**提示词**：
```
页面里的开关和标签页，读屏听不出当前开的是哪个、选中的是哪个，是不是都标记成'勾选状态'就行了？帮我适配。
```
**预期输出**：
- 路由 E 类（checked=物理状态 / selected=互斥单选，先纠正"都标勾选"的误用思路）→ 版本门禁 10 < 13 阻断
- 无 checked/selected 代码；含"需 API 13+"说明与字段提升建议

### 测试场景 26：虚拟节点最小差边界阻断（B10 / B10LineChart.ets，下限 API 11）
**提示词**：
```
用 Canvas 画的折线图读屏完全读不到，请让读屏能读出当前的数据趋势，帮我实现。
```
**预期输出**：
- 路由 F 类虚拟节点 → 10 < 11 阻断（差距最小、最易误放行的边界）
- 建议提升（如 `compatibleSdkVersion: "4.0.0(10)" → "4.1.0(11)"`），不生成 virtualNode/@Builder 代码

### 测试场景 27：自绘仪表盘虚拟节点阻断（B11 / B11Dashboard.ets，下限 API 11）
**提示词**：
```
给自绘的仪表盘加上读屏能读的内容。
```
**预期输出**：
- 路由 F 类 → 10 < 11 阻断；说明需 API 11+，给提升建议，不生成虚拟节点代码

### 测试场景 28：A+E 组合诉求整体拦截（B09 / B09FavoriteIcon.ets，下限 API 12/13）
**提示词**：
```
这个收藏图标没有文字读不出用途，另外还要让读屏知道当前是否已收藏，两个问题一起帮我适配。
```
**预期输出**：
- text（12+）与 checked（13+）均高于 10 → 组合诉求整体被版本门禁拦截，不拆开部分落地（不留半成品）
- 两个属性各自的版本下限均应说明

### 测试场景 29：hover+focus 逐方法标注版本差异（B13 / B13FocusCard.ets，下限 API 12/18）
**提示词**：
```
这张卡片，读屏用户单指摸到时希望能预览详情（展开），焦点进入时展开、焦点离开时收起，帮我实现。
```
**预期输出**：
- 路由事件组合：onAccessibilityHover（12+）+ onAccessibilityFocus（18+），逐方法标注版本差异
- 10 低于两者 → 整体阻断，给字段提升建议；无 hover/focus 回调代码

### 测试场景 30：G 类首焦点阻断、软提示规则不适用（B16 / B16DefaultFocus.ets，下限 API 18）
**提示词**：
```
搜索页里搜索输入框是核心组件，希望进入页面后读屏第一个聚焦、第一个朗读的就是它，帮我实现。
```
**预期输出**：
- 路由 G 类首焦点（defaultFocus，18+）→ 10 < 18 阻断
- G 类"满足版本仅软提示"规则不适用于本工程（版本不满足必须阻断）；给提升建议

### 测试场景 31：hover 触摸回调阻断（B20 / B20HoverText.ets，下限 API 12）
**提示词**：
```
质检卡片被读屏用户摸到时，希望卡片上的文字自动变成'已检查完成'，怎么做？帮我实现。
```
**预期输出**：
- 路由事件回调 onAccessibilityHover（12+）→ 10 < 12 阻断；给提升建议（如提升至 "5.0.0(12)"）
- 无 onAccessibilityHover 代码

## 错误处理测试

> 以下场景 32~33 在 `Accessibility-before` 工程（API 26，放行侧）中执行，验证语义硬规则的防护行为。

### 测试场景 32：覆盖语义强制确认（B03 / B03SubmitOrder.ets，两轮输入）
**提示词**（第 1 轮）：
```
这个按钮本来显示'提交订单'，我希望读屏聚焦它时念'支付 99 元'，直接帮我改。
```
**提示词**（第 2 轮，等待确认后）：
```
我确认，就这么改。
```
**预期输出**：
- 第 1 轮：触发覆盖语义警告（原文本"提交订单"不再播报），不改文件等待确认
- 第 2 轮：确认后就地落地 Button `.accessibilityText('支付 99 元')`
- 说明操作后果应放 description

### 测试场景 33：覆盖语义答疑（B15 / B15OverrideQuery.ets）
**提示词**：
```
这个'提交订单'按钮之前配过读屏文案和提示说明，现在为什么没有系统默认的读文本和操作提示了？
```
**预期输出**：
- 覆盖语义答疑：text 覆盖原文本播报、description 替代新手提醒（关闭开关后也不播报）
- 给恢复默认（删两属性）或调整建议；答疑零代码改动

---

## 执行说明

- **放行侧（场景 1~22、32~33）**：产出代码后工程编译应 BUILD SUCCESSFUL，属性落地与各场景"落地"一致；
- **阻断侧（场景 23~31）**：判定标准为 9/9 零代码产出 + 阻断说明与提升建议齐备 + 编译结果与改动前一致（无任何代码变更）；
- 完整评测口径（轮次统计、能力分布、判定矩阵）见两工程内 `skill-eval-cases-full.md`、`skill-eval-cases-api10-block.md`。
