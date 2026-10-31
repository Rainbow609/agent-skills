# HarmonyOS 真机长时压测与自动化踩坑手册

> 来源：manbo-reader 阅读器性能战役（2026-10-29 ~ 10-31，MatePad Edge / API 26 真机，hvigor + hdc + SP_daemon + hitrace + uitest）。
> 项目侧完整数据与结论见 manbo-reader `docs/reader-decode-pipeline-perf.md`；本文只沉淀**跨项目可复用**的坑与配方。
> 标注「实测」的条目均在真机验证过；标注「推断」的未正面确认。
> 官方知识核验：2026-10-31，devecocli docs 官方知识库逐条比对（uitest / power-shell / hidumper / hitrace / hdc / hilog / aa / Image Kit / 状态管理 / SmartPerf / hvigorw），与官方口径有出入处已就地修正并注明。

## 1. uitest uiInput（手势注入）

- **每次调用有 2~4.6s 固定开销**（实测 4.6s）：uitest 会等 UI 空闲才返回。做「随机间隔操作」时必须把开销从 sleep 里扣除，否则实际节奏被拉长；开销因页/机而异，按批实测自校准（EMA）最稳。【实测】
- **动作前先确认语义**：翻页方向取决于阅读模式（RTL 时左点/左滑＝下一页）；竖屏条漫常被自动切成上下滚动模式，横向手势全部无效。**先用页码计数器（翻 1 次看增量）验证手势真的生效，再开始计时采数**。【实测：首轮 440 次竖滑页码纹丝不动，数据全废】
- dumpLayout 在 canvas 类页面（阅读器/播放器）**常常只剩状态栏窗口**；文本节点只在菜单/浮层打开时出现。判断「是否在目标页」要用应用日志或专设探针，不要依赖布局文本。
- 无 root 时**没有系统级旋转命令**（devecocli device 无 rotate；无 settings CLI）。竖屏测试＝物理旋转设备 + 脚本启动时从 dumpLayout 根节点 bounds 自动检测分辨率并按比例生成坐标。

## 2. 熄屏/锁屏（长时间任务头号杀手）

- 熄屏或锁屏会**冻结后台 JS**：进程活着、CPU 0%，任务静默停摆。`power-shell wakeup` 只亮屏不解锁，**锁屏下依然冻结**——必须「wakeup + 上滑解锁」两步。【实测：播种被锁屏冻结 78 分钟】
- 熄屏超时覆盖：`power-shell timeout -o <ms>`；但该覆盖**会被一次手动熄屏/用户交互清掉**，长任务要配看门狗周期检查 `hidumper -s DisplayManagerService -a '-a'` 的 ScreenPowerState（该字段官方未载，官方另有 `hidumper -s 3301 -a` 查屏幕状态）并自动唤醒+解锁；收尾务必 `power-shell timeout -r` 恢复。【实测】
- 识别「任务被冻结」：应用自身日志时间戳出现分钟级空洞 + hidumper 显示 ScreenPowerState=3。

## 3. SP_daemon（性能采样）

- **fps 只在目标应用真的在画帧时才有值**：静置页面 fps=0 是正常现象，不是采集故障；判卡顿用 fpsJitters（;; 分隔 ns）算 p95，不要用含空闲秒的 fps 均值。【实测】
- `-OUT` 模式与 `-t`（thermal）**不能同时用**（OUT 会是 0 字节）；stdout 模式（无 OUT）可以 `-f -t` 全要。并发两个 SP_daemon 实例会互相顶掉（后启动的清掉前者）。【实测】
- CSV 列随 flag 组合变化（如 `cpuN_Frequency` 未必导出，官方表作 `cpuFrequency`），分析脚本要先探测列名。
- fps 通道曾在某次重启后恒 0（重启设备/多 flag/清统计都无法恢复）——已知间歇问题；备用方案：`hitrace -t 15 -b 18432 -o x.ftrace graphic ace` 数 `RSUniRenderThread::Render()` 事件做头尾帧间隔对比。

## 4. hdc 连接管理

- `list targets` 出现 `Unknown` 条目且 shell 报 E001005（官方口径：设备未知或断连）：实测为 **hdc 服务端残留半连接**（推断）。`nc -z` 确认端口还通 → `hdc kill -r`（重启服务）→ `tconn ip:port` 即恢复。【实测：恢复配方有效】
- `hilog -T <tag>`（宿主侧流式）从**缓冲区头部**开始回放再接实时，时间窗口过滤必须做；hilog 行内 pid 有**不定长空格填充**，正则要用 `\s+`。
- shell 按物理路径直接读写应用沙箱/媒体库受隔离限制（实测均失败）；官方留有文件通道：可调试应用沙箱 `hdc file send/recv -b <bundle>`（API 15+，recv 需文件含 S_IRGRP 位），媒体库 API 21+ 可访问 `/mnt/data/<uid>/media_fuse/`（ls/recv/send/rm）。需要落盘的数据让应用自己写、shell 只 `file recv` 仍是最稳配方。

## 5. 应用侧：CLI 控制应用（绕过 UI）

- **Want 参数是官方「CLI 控制应用」的正道**：`aa start -b <bundle> -a <ability> --pi <int参数> --ps <字符串参数>`（官方限定：`--pi` 仅无符号整型，`--ps` 值不能以 `-` 开头）。启动时配置状态（调试开关、强制路径、直开目标文件）都用它；运行中动态控制需走「外部文件打开」等应用内既有管线复用。
- 跨层覆盖陷阱：**AppStorage 键会被 `PersistentStorage.persistProp`（在 loadContent 回调里绑定）回读覆盖**（官方：persistProp 须在 loadContent 之后调用，启动时以磁盘持久化值初始化 AppStorage），也会被「单本/分组设置」再覆盖——debug 强制开关要么在 persist 绑定之后应用，要么用**不参与持久化的专用测试键**。【实测：覆盖链两连】
- **长时压测必须屏蔽一次性浮层**（版本更新弹窗、新手引导）：给压测总开关加门禁，否则夜里跑到一半弹框，手势全打在弹层上。【实测】
- **插桩路径必须验证真的在执行**：性能代码加在错误的调用层（如同名方法在 provider 通道与直连通道各一份）时，A/B 会得出「无收益」的假结论。判定方法：给目标分支加 attempt 计数，**先看计数 >0 再取数**。【实测：区域直解加错层，白白跑掉两轮 2 小时】
- 容器归因用 gauge（覆盖写）每秒打容器长度进 PerfProbe，一轮 20 分钟即可判定哪个 Map 无界；注意 gauge 与累加计数语义要分开。

## 6. 图像解码（Image Kit）

- 大图 + 共享内存 PixelMap 会在 RS 主线程产生较长纹理上传（官方：SHARE_MEMORY 下 4K 单帧渲染耗时约 20ms）；`ImageSource.createPixelMapUsingAllocator(opts, AllocatorType.DMA)`（API 15+）DMA 内存免纹理上传（官方：4K 单帧渲染耗时降至约 4ms）并降 CPU。GPU 负载实测 −15%。【实测】
- `readPixelsToBuffer` 契约：按 `getPixelBytesNumber()` 写**紧凑像素（不含 stride）**，因此裁剪/扫描数学对 DMA PixelMap 无需改（仅限该接口读出的缓冲区；直接编辑 DMA PixelMap 底层内存官方要求必须用 stride）。
- `desiredRegion` 区域直解 + 「缩略图跑同一套检测算法求裁剪矩形」可以砍掉「全图拷贝 + 扫描 + 整页重建」三段；**观感一致性靠「同一套算法」保证，验收用同页截图逐像素比对（内容区 diff=0）**。【实测：309→77ms，0 差异】
- 性能优化要放对通道：本地包体（zip/cbz）通常走 provider 流式通道、http 页走另一条；先埋点确认实际执行层，再决定在哪优化。解码本身（硬件解码生效时）往往不是瓶颈——**先做逐段拆分（inflate/建源/解码/缩放/后处理）再选型**，避免给第三方解码库（libjpeg-turbo 等）白交学费。【实测：解码 21~34ms，后处理 ≈280ms 才是大头】

## 7. 打包

- 出 **.app（上架/分发格式）**必须 project 模式：`hvigorw --mode project -p buildMode=release assembleApp`（`--mode module` 下没有该 task，会报 task not found）；产物在 `<项目>/build/outputs/default/<name>-default-signed.app`。【实测】

## 8. 流程纪律

- 长测启动前设「硬校验门」：目标页已挂载（应用日志/探针）+ 关键计数在增长，任一不满足不起跑；数据窗口结束后重查计数增量，防止「手势打在错误界面」的静默作废。【实测：2 小时长测打在话列表上】
- 书架/内容型应用的测试书要留足页数余量，或每轮前重置阅读位置——读到末页后所有前进手势都是空操作。
- A/B 两轮必须同 seed/同节奏，且轮流先后以抵消热漂移；温度判定用平台值而非绝对值（电池/壳温会在 30 分钟内进平台）。
