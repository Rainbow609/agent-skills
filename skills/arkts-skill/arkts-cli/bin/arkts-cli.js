#!/usr/bin/env node
/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

'use strict';

const childProcess = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const rootDir = path.resolve(__dirname, '..');
const compilerDir = path.join(rootDir, 'runtime', 'compiler');
const es2abcRuntimeDir = path.join(rootDir, 'runtime', 'ark', 'es2abc');
const jsvmRuntimeDir = path.join(rootDir, 'runtime', 'ark', 'jsvm');

const { etsStandaloneChecker } = require(path.join(compilerDir, 'compile_plugin'));
const ts = require(path.join(compilerDir, 'node_modules', 'typescript'));
const { processUISyntax } = require(path.join(compilerDir, 'lib', 'process_ui_syntax'));

const EXIT_OK = 0;
const EXIT_DIAGNOSTIC_ERROR = 1;
const EXIT_ABC_ERROR = 2;
const EXIT_UNSUPPORTED_INPUT = 3;
const EXIT_VM_ERROR = 4;

const UI_DECORATORS = new Set([
  'Component',
  'ComponentV2',
  'Entry',
  'EntryV2',
  'Builder',
  'BuilderParam',
  'Styles',
  'CustomDialog',
  'Extend',
  'AnimatableExtend',
  'Reusable',
  'ReusableV2',
  'LocalBuilder'
]);

main();

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help || !args.input) {
    printHelp();
    process.exit(args.help ? EXIT_OK : EXIT_DIAGNOSTIC_ERROR);
  }

  const inputPath = resolveFile(args.input, '--input');
  const inputDir = args.inputDir ? resolveDirectory(args.inputDir, '--input-dir') : null;
  const outDir = path.resolve(args.outDir || path.join(process.cwd(), 'arkts-out'));
  const cacheDir = path.resolve(args.cacheDir || path.join(outDir, '.cache'));
  const bundleName = args.bundleName || 'com.example.arktscli';
  const moduleName = args.moduleName || 'entry';
  const packageManagerType = args.packageManagerType || 'npm';

  ensureDir(outDir);
  ensureDir(cacheDir);

  const workspace = createWorkspace({
    inputPath,
    inputDir,
    outDir,
    cacheDir,
    bundleName,
    moduleName
  });

  const diagnostics = [];
  const logger = createLogger(diagnostics);
  runChecker(workspace, {
    moduleName,
    packageManagerType,
    logger
  });

  if (hasErrors(diagnostics)) {
    process.exit(EXIT_DIAGNOSTIC_ERROR);
  }

  const emitted = emitTransformedSources(workspace, path.join(outDir, 'build'));
  const abcOutputPath = buildOutputFilePath(path.join(outDir, 'abc'), workspace.entryRelativePath, '.abc');
  compileJsToAbc(emitted.entry.jsPath, abcOutputPath);

  let runResult = null;
  if (args.run) {
    runResult = runAbcWithArkVm(abcOutputPath);
  }

  process.stdout.write('Syntax Check: OK\n');
  process.stdout.write(`Transformed TS: ${emitted.entry.tsPath}\n`);
  process.stdout.write(`Emitted JS: ${emitted.entry.jsPath}\n`);
  process.stdout.write(`ABC: ${abcOutputPath}\n`);
  if (runResult) {
    process.stdout.write('Run Result:\n');
    if (runResult.stdout) {
      process.stdout.write(runResult.stdout);
      if (!runResult.stdout.endsWith('\n')) {
        process.stdout.write('\n');
      }
    }
    if (runResult.stderr) {
      process.stderr.write(runResult.stderr);
      if (!runResult.stderr.endsWith('\n')) {
        process.stderr.write('\n');
      }
    }
  }
  process.exit(EXIT_OK);
}

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index++) {
    const item = argv[index];
    if (item === '--help' || item === '-h') {
      args.help = true;
      continue;
    }
    if (!item.startsWith('--')) {
      throw new Error(`Unknown argument: ${item}`);
    }
    const [rawKey, inlineValue] = item.slice(2).split('=', 2);
    const key = rawKey.replace(/-([a-z])/g, (_, char) => char.toUpperCase());
    if (inlineValue !== undefined) {
      args[key] = inlineValue;
      continue;
    }
    const next = argv[index + 1];
    if (next === undefined || next.startsWith('--')) {
      args[key] = true;
      continue;
    }
    args[key] = next;
    index++;
  }
  return args;
}

function printHelp() {
  const text = [
    'Usage:',
    '  node ./bin/arkts-cli.js --input /abs/path/file.ets [options]',
    '',
    'Options:',
    '  --input-dir PATH            Source root for multi-file local imports',
    '  --out-dir PATH              Output root directory',
    '  --cache-dir PATH            Temporary work directory',
    '  --bundle-name NAME          Bundle name used in generated module.json',
    '  --module-name NAME          Module name used in generated module.json',
    '  --package-manager-type TYPE npm or ohpm',
    '  --run                       Execute generated abc with packaged ark_js_vm',
    '  --help                      Show this message'
  ].join('\n');
  process.stdout.write(`${text}\n`);
}

function resolveFile(filePath, optionName) {
  const resolved = path.resolve(filePath);
  if (!fs.existsSync(resolved) || !fs.statSync(resolved).isFile()) {
    fail(`Invalid value for ${optionName}: ${resolved}`, EXIT_DIAGNOSTIC_ERROR);
  }
  return resolved;
}

function resolveDirectory(dirPath, optionName) {
  const resolved = path.resolve(dirPath);
  if (!fs.existsSync(resolved) || !fs.statSync(resolved).isDirectory()) {
    fail(`Invalid value for ${optionName}: ${resolved}`, EXIT_DIAGNOSTIC_ERROR);
  }
  return resolved;
}

function ensureDir(directory) {
  fs.mkdirSync(directory, { recursive: true });
}

function createWorkspace(options) {
  const projectDir = path.join(options.cacheDir, 'workspace', options.moduleName);
  const sourceDir = path.join(projectDir, 'src', 'main', 'ets');
  const moduleJsonPath = path.join(projectDir, 'module.json');
  const compilerTypes = createCompilerTypes(projectDir);
  const sourceRoot = options.inputDir || path.dirname(options.inputPath);
  const entryRelativePath = path.relative(sourceRoot, options.inputPath);
  if (entryRelativePath.startsWith('..') || path.isAbsolute(entryRelativePath)) {
    fail(`The value for --input must be inside the selected source root: ${sourceRoot}`, EXIT_DIAGNOSTIC_ERROR);
  }

  ensureDir(sourceDir);
  const sourceFiles = collectSourceFiles({
    inputPath: options.inputPath,
    sourceRoot,
    useDirectoryMode: Boolean(options.inputDir)
  });
  validatePureNonUiSources(sourceFiles);

  for (const filePath of sourceFiles) {
    const relativePath = path.relative(sourceRoot, filePath);
    const workspacePath = path.join(sourceDir, relativePath);
    ensureDir(path.dirname(workspacePath));
    const sourceText = fs.readFileSync(filePath, 'utf8');
    fs.writeFileSync(workspacePath, sourceText);
  }

  const workspaceInput = path.join(sourceDir, entryRelativePath);
  fs.writeFileSync(moduleJsonPath, JSON.stringify({
    app: {
      bundleName: options.bundleName,
      minAPIVersion: 12
    },
    module: {
      name: options.moduleName,
      type: 'entry'
    }
  }, null, 2));
  return {
    projectDir,
    workspaceInput,
    entryRelativePath,
    moduleJsonPath,
    compilerTypes,
    buildDir: path.join(options.outDir, 'workspace-build'),
    checkerCacheDir: path.join(options.cacheDir, 'checker'),
    sourceDir,
    workspaceSourceFiles: sourceFiles.map((filePath) => {
      const relativePath = path.relative(sourceRoot, filePath);
      return {
        sourcePath: filePath,
        relativePath,
        workspacePath: path.join(sourceDir, relativePath)
      };
    })
  };
}

function collectSourceFiles(options) {
  if (!options.useDirectoryMode) {
    return [options.inputPath];
  }

  const sourceFiles = [];
  walkDirectory(options.sourceRoot, (filePath) => {
    if (filePath.endsWith('.ets')) {
      sourceFiles.push(filePath);
    }
  });
  if (sourceFiles.length === 0) {
    fail(`No .ets files were found under --input-dir: ${options.sourceRoot}`, EXIT_DIAGNOSTIC_ERROR);
  }
  return sourceFiles.sort();
}

function walkDirectory(directory, onFile) {
  const entries = fs.readdirSync(directory, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      walkDirectory(fullPath, onFile);
      continue;
    }
    if (entry.isFile()) {
      onFile(fullPath);
    }
  }
}

function validatePureNonUiSources(filePaths) {
  const unsupportedFile = filePaths.find((filePath) => !isPureNonUiArkTs(filePath));
  if (unsupportedFile) {
    fail([
      'Unsupported input: UI ArkTS syntax was detected. This tool only supports pure non-UI .ets files.',
      `Detected in: ${unsupportedFile}`
    ].join('\n'), EXIT_UNSUPPORTED_INPUT);
  }
}

function createCompilerTypes(projectDir) {
  const packageName = 'arkts-console';
  const packageDir = path.join(projectDir, 'node_modules', '@types', packageName);
  ensureDir(packageDir);
  fs.writeFileSync(path.join(packageDir, 'index.d.ts'), [
    'declare class Console {',
    '  log(...args: Object[]): void;',
    '  info(...args: Object[]): void;',
    '}',
    'declare const console: Console;',
    ''
  ].join('\n'));
  return [packageName];
}

function createLogger(diagnostics) {
  const write = (level, values) => {
    const message = values.map(formatLogValue).join(' ').trim();
    if (!message) {
      return;
    }
    diagnostics.push({ level, message });
    const stream = level === 'error' ? process.stderr : process.stdout;
    stream.write(`${message}\n`);
  };
  return {
    debug: (...args) => write('debug', args),
    info: (...args) => write('info', args),
    warn: (...args) => write('warn', args),
    error: (...args) => write('error', args)
  };
}

function formatLogValue(value) {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (value instanceof Error) {
    return value.stack || value.message;
  }
  return String(value);
}

function hasErrors(diagnostics) {
  return diagnostics.some((item) => item.level === 'error' || item.message.includes('ArkTS:ERROR'));
}

function runChecker(workspace, options) {
  ensureDir(workspace.buildDir);
  ensureDir(workspace.checkerCacheDir);
  etsStandaloneChecker({ './main': workspace.workspaceInput }, options.logger, {
    projectPath: workspace.projectDir,
    buildPath: workspace.buildDir,
    cachePath: workspace.checkerCacheDir,
    aceModuleBuild: workspace.buildDir,
    aceModuleJsonPath: workspace.moduleJsonPath,
    modulePath: workspace.projectDir,
    packageManagerType: options.packageManagerType,
    compilerTypes: workspace.compilerTypes,
    compatibleSdkVersion: 12,
    compileMode: 'moduleJson',
    moduleRootPath: workspace.projectDir,
    strictCheckerOnly: true,
    allowEtsAnnotations: true,
    projectArkOption: {
      arkTSVersion: 'ArkTS_1_1',
      tscConfig: {
        targetESVersion: 'ES2021'
      }
    }
  });
}

function emitTransformedSources(workspace, outputDir) {
  ensureDir(outputDir);
  const moduleOutputDir = path.join(outputDir, 'modules');
  const oldCompileTool = process.env.compileTool;
  const oldCompiler = process.env.compiler;
  const oldCompileMode = process.env.compileMode;
  process.env.compileTool = 'rollup';
  process.env.compiler = 'on';
  process.env.compileMode = 'moduleJson';

  try {
    const printer = ts.createPrinter({ newLine: ts.NewLineKind.LineFeed });
    const emittedFiles = {};

    for (const sourceFileInfo of workspace.workspaceSourceFiles) {
      const sourceText = fs.readFileSync(sourceFileInfo.workspacePath, 'utf8');
      const sourceFile = ts.createSourceFile(
        sourceFileInfo.workspacePath,
        sourceText,
        ts.ScriptTarget.ES2021,
        true,
        ts.ScriptKind.TS
      );
      const transformResult = ts.transform(sourceFile, [
        processUISyntax(null, false, undefined, sourceFileInfo.workspacePath, { getHashByFilePath: () => '' }, {})
      ]);
      const transformedTs = printer.printFile(transformResult.transformed[0]);
      transformResult.dispose();

      const tsPath = buildOutputFilePath(outputDir, sourceFileInfo.relativePath, '.ts');
      ensureDir(path.dirname(tsPath));
      fs.writeFileSync(tsPath, transformedTs);

      const transpiled = ts.transpileModule(transformedTs, {
        compilerOptions: {
          module: ts.ModuleKind.CommonJS,
          target: ts.ScriptTarget.ES2021
        },
        fileName: tsPath
      });
      const moduleJsPath = buildOutputFilePath(moduleOutputDir, sourceFileInfo.relativePath, '.js');
      ensureDir(path.dirname(moduleJsPath));
      fs.writeFileSync(moduleJsPath, transpiled.outputText);
      emittedFiles[sourceFileInfo.relativePath] = {
        tsPath,
        moduleJsPath,
        moduleId: toModuleId(sourceFileInfo.relativePath),
        moduleText: rewriteRelativeRequires(transpiled.outputText, sourceFileInfo.relativePath)
      };
    }

    const entryJsPath = buildOutputFilePath(outputDir, workspace.entryRelativePath, '.js');
    ensureDir(path.dirname(entryJsPath));
    fs.writeFileSync(entryJsPath, createBundleSource(emittedFiles, workspace.entryRelativePath));

    return {
      files: emittedFiles,
      entry: {
        tsPath: emittedFiles[workspace.entryRelativePath].tsPath,
        jsPath: entryJsPath
      }
    };
  } finally {
    process.env.compileTool = oldCompileTool;
    process.env.compiler = oldCompiler;
    process.env.compileMode = oldCompileMode;
  }
}

function buildOutputFilePath(rootDir, relativePath, extension) {
  const parsed = path.parse(relativePath);
  return path.join(rootDir, parsed.dir, `${parsed.name}${extension}`);
}

function toModuleId(relativePath) {
  const normalizedPath = relativePath.split(path.sep).join(path.posix.sep);
  return normalizedPath.replace(/\.(ets|ts|js)$/i, '');
}

function rewriteRelativeRequires(sourceText, relativePath) {
  const currentModuleId = toModuleId(relativePath);
  const currentDir = path.posix.dirname(currentModuleId);
  return sourceText.replace(/require\((['"])([^'"]+)\1\)/g, (match, quote, request) => {
    if (!request.startsWith('.')) {
      return match;
    }
    const normalizedRequest = toModuleId(
      path.posix.normalize(path.posix.join(currentDir === '.' ? '' : currentDir, request))
    );
    return `require(${quote}${normalizedRequest}${quote})`;
  });
}

function createBundleSource(emittedFiles, entryRelativePath) {
  const moduleEntries = Object.values(emittedFiles)
    .sort((left, right) => left.moduleId.localeCompare(right.moduleId))
    .map((file) => [
      `    ${JSON.stringify(file.moduleId)}: function(module, exports, require) {`,
      indentBlock(file.moduleText.trimEnd(), '      '),
      '    }'
    ].join('\n'))
    .join(',\n');

  return [
    'if (typeof globalThis.console === "undefined") {',
    '  globalThis.console = {',
    '    log: (...args) => print(...args),',
    '    info: (...args) => print(...args)',
    '  };',
    '}',
    '(function() {',
    '  const __modules = {',
    moduleEntries,
    '  };',
    '  const __cache = Object.create(null);',
    '  function __require(moduleId) {',
    '    const factory = __modules[moduleId];',
    '    if (!factory) {',
    '      throw new Error("Cannot find module \'" + moduleId + "\'");',
    '    }',
    '    if (__cache[moduleId]) {',
    '      return __cache[moduleId].exports;',
    '    }',
    '    const module = { exports: {} };',
    '    __cache[moduleId] = module;',
    '    factory(module, module.exports, __require);',
    '    return module.exports;',
    '  }',
    `  __require(${JSON.stringify(toModuleId(entryRelativePath))});`,
    '})();',
    ''
  ].join('\n');
}

function indentBlock(text, indent) {
  return text
    .split('\n')
    .map((line) => `${indent}${line}`)
    .join('\n');
}

function compileJsToAbc(jsPath, abcOutputPath) {
  const es2abc = resolveEs2abcRuntime();
  ensureDir(path.dirname(abcOutputPath));
  const command = buildEs2abcCommand(jsPath, abcOutputPath);

  try {
    childProcess.execFileSync(es2abc.binaryPath, command.args, {
      cwd: es2abc.cwd,
      env: createEs2abcEnv(es2abc),
      stdio: ['ignore', 'pipe', 'pipe'],
      windowsHide: true
    });
  } catch (error) {
    const message = formatExecError(error);
    fail(`Failed to generate abc.\n${message}`, EXIT_ABC_ERROR);
  }

  if (!fs.existsSync(abcOutputPath)) {
    fail(`ABC output was not generated: ${abcOutputPath}`, EXIT_ABC_ERROR);
  }
}

function resolveEs2abcRuntime() {
  return resolvePackagedRuntime({
    runtimeDir: es2abcRuntimeDir,
    exitCode: EXIT_ABC_ERROR,
    toolName: 'es2abc',
    binaryNameMap: {
      linux: 'es2abc',
      darwin: 'es2abc',
      win32: 'es2abc.exe'
    }
  });
}

function createEs2abcEnv(es2abc) {
  const env = { ...process.env };
  const extraDirs = [];

  if (fs.existsSync(es2abc.libDir) && fs.statSync(es2abc.libDir).isDirectory()) {
    extraDirs.push(es2abc.libDir);
  }
  extraDirs.push(es2abc.cwd);

  prependEnvPath(env, 'PATH', extraDirs);
  if (process.platform === 'linux') {
    prependEnvPath(env, 'LD_LIBRARY_PATH', extraDirs);
  } else if (process.platform === 'darwin') {
    prependEnvPath(env, 'DYLD_LIBRARY_PATH', extraDirs);
  }

  return env;
}

function prependEnvPath(env, key, values) {
  const existing = env[key];
  const list = values.filter(Boolean);
  if (existing) {
    list.push(existing);
  }
  env[key] = list.join(path.delimiter);
}

function formatExecError(error) {
  if (!error) {
    return 'Unknown es2abc execution failure.';
  }

  const parts = [];
  if (error.message) {
    parts.push(error.message);
  }
  if (error.stdout) {
    const stdout = Buffer.isBuffer(error.stdout) ? error.stdout.toString('utf8') : String(error.stdout);
    if (stdout.trim()) {
      parts.push(stdout.trim());
    }
  }
  if (error.stderr) {
    const stderr = Buffer.isBuffer(error.stderr) ? error.stderr.toString('utf8') : String(error.stderr);
    if (stderr.trim()) {
      parts.push(stderr.trim());
    }
  }
  return parts.join('\n').trim() || String(error);
}

function runAbcWithArkVm(abcPath) {
  const runtime = resolveArkVmRuntime();
  const command = buildArkVmCommand(runtime, abcPath);

  try {
    const output = childProcess.execFileSync(runtime.binaryPath, command.args, {
      cwd: runtime.cwd,
      env: createArkVmEnv(runtime),
      stdio: ['ignore', 'pipe', 'pipe'],
      windowsHide: true,
      encoding: 'utf8'
    });
    return {
      stdout: output || '',
      stderr: ''
    };
  } catch (error) {
    const stdout = readExecStream(error.stdout);
    const stderr = readExecStream(error.stderr);
    const message = formatExecError({
      ...error,
      stdout,
      stderr
    });
    fail(`Failed to execute abc with ark_js_vm.\n${message}`, EXIT_VM_ERROR);
  }
}

function resolveArkVmRuntime() {
  const runtime = resolvePackagedRuntime({
    runtimeDir: jsvmRuntimeDir,
    exitCode: EXIT_VM_ERROR,
    toolName: 'ark_js_vm',
    binaryNameMap: {
      linux: 'ark_js_vm',
      darwin: 'ark_js_vm',
      win32: 'ark_js_vm.exe'
    }
  });
  const stubPath = path.join(runtime.libDir, 'stub.an');
  const icuDataDir = path.join(runtime.packageRoot, 'data');
  const requiredFiles = [
    { path: stubPath, label: 'stub.an' },
    { path: runtime.libDir, label: 'runtime library directory', type: 'dir' },
    { path: icuDataDir, label: 'ICU data directory', type: 'dir' }
  ];

  for (const item of requiredFiles) {
    const exists = fs.existsSync(item.path);
    const valid = exists && (item.type === 'dir' ? fs.statSync(item.path).isDirectory() : fs.statSync(item.path).isFile());
    if (!valid) {
      fail(`Missing packaged ark_js_vm dependency: ${item.label}: ${item.path}`, EXIT_VM_ERROR);
    }
  }

  const hasIcuData = fs.readdirSync(icuDataDir).some((name) => name.endsWith('.dat'));
  if (!hasIcuData) {
    fail(`Missing packaged ark_js_vm ICU data file under: ${icuDataDir}`, EXIT_VM_ERROR);
  }

  return {
    ...runtime,
    stubPath,
    icuDataDir
  };
}

function resolvePackagedRuntime(options) {
  const platform = os.platform();
  const packageDirName = resolvePlatformPackageDir(platform, options.toolName, options.exitCode);
  const binaryName = options.binaryNameMap[platform];
  if (!binaryName) {
    fail(`Unsupported host platform for ${options.toolName} packaging: ${platform}`, options.exitCode);
  }

  const packageRoot = path.join(options.runtimeDir, packageDirName);
  const binDir = path.join(packageRoot, 'bin');
  const libDir = path.join(packageRoot, 'lib');
  const binaryPath = path.join(binDir, binaryName);

  if (!fs.existsSync(binaryPath)) {
    fail([
      `Missing packaged ${options.toolName} binary: ${binaryPath}`,
      'Expected layout:',
      `  ${path.join(options.runtimeDir, packageDirName, 'bin', binaryName)}`,
      `  ${path.join(options.runtimeDir, packageDirName, 'lib')} (optional, for dependent shared libraries)`
    ].join('\n'), options.exitCode);
  }

  return {
    binaryPath,
    cwd: binDir,
    libDir,
    packageRoot
  };
}

function resolvePlatformPackageDir(platform, toolName, exitCode) {
  const platformDirMap = {
    linux: 'linux',
    darwin: 'mac',
    win32: 'win'
  };
  const packageDirName = platformDirMap[platform];
  if (!packageDirName) {
    fail(`Unsupported host platform for ${toolName} packaging: ${platform}`, exitCode);
  }
  return packageDirName;
}

function buildEs2abcCommand(inputPath, outputPath) {
  return {
    args: [
      inputPath,
      '--output',
      outputPath
    ]
  };
}

function buildArkVmCommand(runtime, abcPath) {
  return {
    args: [
      '--stub-file',
      runtime.stubPath,
      '--icu-data-path',
      runtime.icuDataDir,
      abcPath
    ]
  };
}

function createArkVmEnv(runtime) {
  const env = { ...process.env };
  const extraDirs = [runtime.libDir, runtime.cwd];
  prependEnvPath(env, 'PATH', extraDirs);
  if (process.platform === 'linux') {
    prependEnvPath(env, 'LD_LIBRARY_PATH', extraDirs);
  } else if (process.platform === 'darwin') {
    prependEnvPath(env, 'DYLD_LIBRARY_PATH', extraDirs);
  }
  return env;
}

function readExecStream(stream) {
  if (!stream) {
    return '';
  }
  return Buffer.isBuffer(stream) ? stream.toString('utf8') : String(stream);
}

function isPureNonUiArkTs(filePath) {
  const sourceText = fs.readFileSync(filePath, 'utf8');
  const sourceFile = ts.createSourceFile(filePath, sourceText, ts.ScriptTarget.ES2021, true, ts.ScriptKind.TS);
  let hasUiSyntax = false;
  visit(sourceFile, (node) => {
    if (hasUiSyntax) {
      return;
    }
    if (typeof ts.isStructDeclaration === 'function' && ts.isStructDeclaration(node)) {
      hasUiSyntax = true;
      return;
    }
    if (ts.isDecorator(node)) {
      const name = getDecoratorName(node.expression);
      if (UI_DECORATORS.has(name)) {
        hasUiSyntax = true;
      }
    }
  });
  return !hasUiSyntax;
}

function visit(node, callback) {
  callback(node);
  ts.forEachChild(node, (child) => visit(child, callback));
}

function getDecoratorName(expression) {
  if (ts.isIdentifier(expression)) {
    return expression.text;
  }
  if (ts.isCallExpression(expression) && ts.isIdentifier(expression.expression)) {
    return expression.expression.text;
  }
  return '';
}

function fail(message, exitCode) {
  process.stderr.write(`${message}\n`);
  process.exit(exitCode);
}
