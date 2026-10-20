arkts-as-casts
类型转换只支持 as T 语法，不支持尖括号类型断言等其他 cast 写法。
arkts-extends-only-class
接口不能继承 class，只能继承接口类型。
arkts-identifiers-as-prop-names
对象属性名必须使用标识符形式，不支持非标识符属性名。
arkts-implements-only-iface
class 的 implements 子句只能指定接口，不能指定 class。
arkts-instanceof-ref-types
instanceof 只在受支持的引用类型场景中可用，不能作为通用运行时类型判断。
arkts-limited-esobj
ESObject 类型的使用受限制，不应作为常规 ArkTS 类型使用。
arkts-limited-stdlib
标准库 API 的使用受 ArkTS 限制，不能调用不在允许范围内的库接口。
arkts-limited-throw
throw 语句不能抛出任意类型的值，只能抛出 ArkTS 支持的异常值类型。
arkts-no-aliases-by-index
不支持索引访问类型，不能用 T[K] 形式声明类型别名或成员类型。
arkts-no-ambient-decls
不支持 ambient module 声明。
arkts-no-ambiguity-obj-literal
对象字面量不能在多个候选类型之间产生歧义，必须能确定唯一目标类型。
arkts-no-any-unknown
禁止使用 any 和 unknown，应使用显式、可静态确定的具体类型。
arkts-no-as-const
不支持 as const 断言。
arkts-no-call-signatures
不支持带 call signature 的对象类型，应使用 class 或显式函数类型建模。
arkts-no-class-literals
不支持 class 表达式，class 必须用声明形式定义。
arkts-no-classes-as-obj
不推荐把 class 当作普通对象值使用。
arkts-no-comma-outside-loops
逗号运算符只能出现在 for 循环相关位置，不能在普通表达式中使用。
arkts-no-conditional-types
不支持条件类型。
arkts-no-ctor-prop-decls
构造函数参数不能同时声明类字段，不能使用参数属性写法。
arkts-no-ctor-signatures-funcs
不支持构造函数函数类型签名。
arkts-no-ctor-signatures-iface
接口中不支持 construct signature。
arkts-no-ctor-signatures-type
不支持带 constructor signature 的类型，应使用 class 表达构造能力。
arkts-no-decl-merging
不支持声明合并，同名接口、命名空间等声明不能依赖 TypeScript 合并语义。
arkts-no-decorators-except-arkui
除 ArkUI 允许的装饰器外，不支持普通 TypeScript 装饰器。
arkts-no-definite-assignment
不推荐使用确定赋值断言。
arkts-no-delete
不支持 delete 运算符。
arkts-no-destruct-assignment
不支持解构赋值。
arkts-no-destruct-decls
变量声明不支持解构形式。
arkts-no-destruct-params
函数参数不支持解构形式。
arkts-no-dts-sendable-type-export
SDK 的 ts 声明文件中不能导出 Sendable class 或 Sendable interface。
arkts-no-enum-merging
不支持 enum 声明合并。
arkts-no-enum-mixed-types
枚举成员初始化值必须是同类型的编译期常量表达式。
arkts-no-export-assignment
不支持 export = 赋值导出。
arkts-no-extend-same-prop
接口不能继承带有同名但类型不一致成员的多个接口。
arkts-no-for-in
不支持 for..in 语句。
arkts-no-func-apply-bind-call
不支持 Function.apply、Function.bind 和 Function.call。
arkts-no-func-apply-call
不支持 Function.apply 和 Function.call。
arkts-no-func-bind
不推荐使用 Function.bind。
arkts-no-func-expressions
不支持 function 表达式，应使用箭头函数或函数声明。
arkts-no-func-props
不支持在函数对象上声明或追加属性。
arkts-no-generators
不支持生成器函数和 yield 表达式。
arkts-no-generic-lambdas
不支持泛型箭头函数，应使用泛型函数声明。
arkts-no-globalthis
不推荐使用 globalThis。
arkts-no-implicit-return-types
函数返回类型推断受限制，复杂或不稳定返回类型需要显式标注。
arkts-no-import-assertions
不支持 import assertion。
arkts-no-import-default-as
不支持 import { default as ... } 形式导入默认导出。
arkts-no-in
不支持 in 运算符。
arkts-no-indexed-signatures
不支持索引签名。
arkts-no-inferred-generic-params
泛型函数调用的类型参数推断受限制，必要时需要显式传入类型实参。
arkts-no-intersection-types
不支持交叉类型，应使用继承等静态结构表达组合关系。
arkts-no-is
不支持 is 类型谓词，类型收窄应使用 instanceof 或 as 等受支持方式。
arkts-no-jsx
不支持 JSX 表达式。
arkts-no-mapped-types
不支持 mapped type。
arkts-no-method-reassignment
不支持重新赋值对象或类的方法。
arkts-no-misplaced-imports
import 语句必须位于其他语句之前，不能出现在普通语句之后。
arkts-no-module-wildcards
模块名不支持通配符。
arkts-no-multiple-static-blocks
一个 class 最多只能包含一个 static block。
arkts-no-namespace-import-in-ts-import-ets
ts 文件从 ets 文件导入时不允许使用 namespace import。
arkts-no-nested-funcs
不支持嵌套函数声明。
arkts-no-new-target
不支持 new.target。
arkts-no-noninferrable-arr-literals
数组字面量的元素类型必须可推断且一致，不能形成不可推断数组类型。
arkts-no-ns-as-obj
命名空间不能作为普通对象使用。
arkts-no-ns-statements
命名空间内部只允许声明，不支持普通语句或空语句。
arkts-no-obj-literals-as-types
对象字面量不能作为类型声明使用。
arkts-no-polymorphic-unops
一元 +、-、~ 运算符只能用于 number。
arkts-no-private-identifiers
不支持 #private 私有标识符。
arkts-no-props-by-index
不支持用索引访问字段，字段访问应使用点号属性访问。
arkts-no-prototype-assignment
不支持 prototype 赋值。
arkts-no-regexp-literals
不支持正则表达式字面量。
arkts-no-require
不支持 require 和 import assignment。
arkts-no-side-effects-imports
shared module 中不支持仅用于副作用的 import。
arkts-no-special-exports
不支持特殊 export type 声明。
arkts-no-special-imports
不支持特殊 import type 声明。
arkts-no-spread
spread 只能把数组或数组派生类展开到 rest 参数或数组字面量中。
arkts-no-standalone-this
独立函数中不支持使用 this。
arkts-no-structural-typing
不支持结构类型兼容，类型关系不能只依赖成员形状匹配。
arkts-no-symbol
不支持 Symbol() API。
arkts-no-ts-deps
ArkTS 当前不允许依赖 TypeScript 代码。
arkts-no-ts-import-ets
ts 文件从 ets 文件导入时，只允许导入 Sendable class 和 Sendable interface。
arkts-no-ts-re-export-ets
ts 文件中不能重新导出来自 ets 文件的实体。
arkts-no-ts-sendable-type-inheritance
ts 文件中不能在 implements 或 extends 子句里使用 Sendable 类型。
arkts-no-type-query
typeof 只能用于表达式上下文，不能用于类型查询。
arkts-no-types-in-catch
catch 子句变量不支持类型标注。
arkts-no-typing-with-this
类型标注中不支持 this type。
arkts-no-umd
不支持 UMD 模块定义。
arkts-no-untyped-obj-literals
对象字面量必须对应显式声明的 class 或 interface 类型。
arkts-no-utility-types
部分 TypeScript utility type 不受支持。
arkts-no-var
禁止使用 var，应使用 let 或 const。
arkts-no-with
不支持 with 语句。
arkts-sendable-as-expr
不能把非 Sendable 数据强制转换为 Sendable 类型。
arkts-sendable-beta-compatible
当 compatibleSdkVersionStage 低于 API12 beta3 时，不支持 Sendable function 和 Sendable type alias。
arkts-sendable-class-decorator
Sendable class 只能使用 @Sendable 装饰器。
arkts-sendable-class-inheritance
Sendable class 的继承关系受限制，只能继承符合 Sendable 约束的类型。
arkts-sendable-computed-prop-name
Sendable class 和 Sendable interface 中不允许使用计算属性名。
arkts-sendable-decorator-limited
@Sendable 装饰器只能用于 class、function 和 type alias。
arkts-sendable-definite-assignment
Sendable class 中不允许使用确定赋值断言。
arkts-sendable-explicit-field-type
Sendable class 的字段必须显式标注类型。
arkts-sendable-function-as-expr
不能把非 Sendable function 强制转换为 Sendable type alias。
arkts-sendable-function-assignment
只有 Sendable function 或 Sendable type alias 对象可以赋值给 Sendable type alias。
arkts-sendable-function-decorator
Sendable function 只能使用 @Sendable 装饰器。
arkts-sendable-function-imported-variables
Sendable function 只能捕获导入变量。
arkts-sendable-function-overload-decorator
声明 Sendable 重载函数时，每个重载声明都必须添加 @Sendable 装饰器。
arkts-sendable-function-property
Sendable function 的属性使用受限制。
arkts-sendable-generic-types
泛型 Sendable 类型的类型实参必须是 Sendable 数据类型。
arkts-sendable-imported-variables
Sendable class 只能捕获导入变量。
arkts-sendable-obj-init
Sendable 类型对象不能用对象字面量或数组字面量初始化。
arkts-sendable-prop-types
Sendable class 和 Sendable interface 的属性必须是 Sendable 数据类型。
arkts-sendable-typeAlias-declaration
只有 FunctionType 可以声明为 Sendable type alias。
arkts-sendable-typealias-decorator
Sendable type alias 只能使用 @Sendable 装饰器。
arkts-shared-module-exports
shared module 只能导出 Sendable 实体。
arkts-shared-module-no-wildcard-export
shared module 中不允许使用 export * from ...。
arkts-strict-typing
强制执行严格类型检查。
arkts-strict-typing-required
不允许用源码注释关闭类型检查。
arkts-taskpool-concurrent-function-args
传给 taskpool 的函数必须是带 @Concurrent 装饰器的普通函数。
arkts-unique-names
类型和命名空间等声明必须使用唯一名称，不能依赖同名声明合并。
artkts-no-side-effect-import-in-ts-import-ets
ts 文件从 ets 文件导入时不允许使用仅副作用导入。
