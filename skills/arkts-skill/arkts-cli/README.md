# arkts-cli

独立 ArkTS CLI 目录，目标是脱离 `developtools/ace_ets2bundle/compiler` 原目录直接运行。
当前目录已收敛为 Linux x64 的可分发版本，支持直接执行 `npm pack`。

当前约束：

- 输入只支持纯非 UI `.ets`
- 支持单入口 `.ets`，可选携带同一源码目录下的多个本地依赖 `.ets`
- 诊断复用 `ace_ets2bundle/compiler` 的 `etsStandaloneChecker`
- `.abc` 生成使用随包的 `es2abc`
- `.abc` 运行使用随包的 `ark_js_vm`

单文件示例：

```bash
node ./bin/arkts-cli.js \
  --input /abs/path/file.ets \
  --out-dir /abs/path/out
```

多文件示例：

```bash
node ./bin/arkts-cli.js \
  --input /abs/path/smoke_case/smoke.ets \
  --input-dir /abs/path/smoke_case \
  --out-dir /abs/path/out
```

其中 `--input` 指定单个入口文件，`--input-dir` 指定要复制进临时工作区的源码根目录。这样入口文件中的本地相对导入，例如 `import { A } from './aa'`，就能在检查、编译和运行阶段一起解析。

执行并查看运行结果：

```bash
node ./bin/arkts-cli.js \
  --input /abs/path/smoke_case/smoke.ets \
  --input-dir /abs/path/smoke_case \
  --out-dir /abs/path/out \
  --run
```

输出：

- `Syntax Check: OK` 语法检查结果
- `out/build/**/*.ts` 转换后的 TS 中间产物
- `out/build/modules/**/*.js` 每个源文件对应的 CommonJS 中间产物
- `out/build/**/*.js` 入口 bundle 产物
- `out/abc/**/*.abc` 字节码产物
- 传 `--run` 时输出 VM 运行结果

参数说明：

- `--input`：必填，入口 `.ets` 文件
- `--input-dir`：可选，多文件模式的源码根目录；不传时保持单文件模式
- `--out-dir`：输出目录根路径
- `--cache-dir`：临时工作目录
- `--run`：生成 `.abc` 后立即用随包 `ark_js_vm` 执行

当前行为：

- 单文件模式下，`arkts-cli` 只复制入口文件到临时工作区
- 多文件模式下，`arkts-cli` 会递归复制 `--input-dir` 下所有 `.ets` 文件，并保留相对目录结构
- `--input` 必须位于 `--input-dir` 之内
- `.abc` 生成和 `--run` 仍然只针对一个入口程序，不支持一次处理多个入口
- 如果任意源文件包含 UI ArkTS 语法，命令会直接失败

运行时布局：

- `runtime/compiler`：ArkTS 诊断与源码转换依赖
- `runtime/ark/es2abc/<platform>/bin/es2abc[.exe]`：随包字节码编译器
- `runtime/ark/es2abc/<platform>/lib`：`es2abc` 依赖的共享库（如需要）
- `runtime/ark/jsvm/<platform>/bin/ark_js_vm[.exe]`：随包 VM 可执行文件
- `runtime/ark/jsvm/<platform>/lib`：`ark_js_vm` 依赖共享库和 `stub.an`
- `runtime/ark/jsvm/<platform>/data`：ICU data 文件

说明：

- `arkts-cli` 运行时只查找包内相对路径，不依赖源码树下的 `out/.../es2abc`
- `arkts-cli` 运行 `--run` 时只查找包内相对路径，不依赖源码树下的 `out/.../ark_js_vm`、`stub.an` 或 ICU data
- Linux 平台默认查找 `runtime/ark/es2abc/linux/bin/es2abc`
- Linux 平台默认查找 `runtime/ark/jsvm/linux/bin/ark_js_vm`
- 当前 `package.json` 已限制 `npm pack` 只发布 `bin/`、`runtime/` 和本 README
- `arkts-cli --help` 可以查看最新参数列表
- 可用 `script/package_es2abc.sh /abs/path/to/es2abc [/abs/path/to/lib-dir]` 将已编译产物打进包内
- 可用 `script/package_ark_js_vm.sh /abs/path/to/ark_js_vm /abs/path/to/lib-dir /abs/path/to/stub.an /abs/path/to/icu-data-dir` 将 VM 产物打进包内
- 根目录 `script/` 仅用于维护和重新打包运行时，不属于 npm 分发内容
