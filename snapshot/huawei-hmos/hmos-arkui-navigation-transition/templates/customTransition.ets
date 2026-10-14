// customTransition 页面级自定义转场动画框架模板
// 归属组件：NavDestination
// API: customTransition(delegate: NavDestinationTransitionDelegate)
// @since: 15
// 来源: interface_sdk-js/api/@internal/component/ets/nav_destination.d.ts:1274
//
// NavDestinationTransitionDelegate 签名:
//   (operation: NavigationOperation, isEnter: boolean) => Array<NavDestinationTransition> | undefined
//
// 注意: customTransition 是页面级转场，无法在转场过程中响应交互。
//       如需交互（如手势返回），请使用 customNavContentTransition（Navigation 整体级）。
//
// ⚠️ 编译错误防护（ArkTS:10505001）：
// customTransition 是 NavDestination 的链式属性方法，delegate 作为参数传入。
// 不要在 struct 中定义名为 pageTransition 的方法并使用 NavDestinationTransitionDelegate 签名。
// pageTransition 是 CustomComponent 的生命周期方法（签名 () => void），与 customTransition 无关。
// 错误写法会导致编译报错：Property 'pageTransition' in type 'X' is not assignable
//   to the same property in base type 'CustomComponent'.

@Entry
@Component
struct CustomTransitionPage {
  @State pageStack: NavPathStack = new NavPathStack()

  build() {
    Navigation(this.pageStack) {
      // 导航首页内容
      Column() {
        Button('Push Detail Page')
          .onClick(() => {
            this.pageStack.pushPath({ name: 'CustomDetailPage' })
          })
      }
    }
    .navDestination(this.navDestinationBuilder)
  }

  @Builder
  navDestinationBuilder(name: string, param: unknown): void {
    if (name === 'CustomDetailPage') {
      CustomDetailPage()
    }
  }
}

@Component
struct CustomDetailPage {
  build() {
    NavDestination() {
      Column() {
        Text('Custom Transition Page')
          .fontSize(20)
          .margin(20)
      }
      .width('100%')
      .height('100%')
    }
    .title('Custom Detail')
    // 自定义转场动画 — 代理函数按 operation(PUSH/POP) × isEnter(入场/退场) 返回动画配置
    .customTransition(this.customTransitionDelegate)
  }

  // NavDestinationTransitionDelegate:
  // (operation: NavigationOperation, isEnter: boolean) => Array<NavDestinationTransition> | undefined
  private customTransitionDelegate = (operation: NavigationOperation, isEnter: boolean): Array<NavDestinationTransition> | undefined => {
    if (operation === NavigationOperation.PUSH && isEnter) {
      // PUSH 入场：缩放 + 淡入
      return [
        {
          duration: 300,
          curve: Curve.EaseInOut,
          delay: 0,
          event: () => {
            this.getUIContext()?.animateTo({
              duration: 300,
              curve: Curve.EaseInOut,
            }, () => {
              // 在闭包内修改组件 UI 状态，系统据此生成转场动画
              // 具体动画效果由开发者在此闭包中实现
            })
          },
          onTransitionEnd: () => {
            // 转场动画结束回调
          }
        }
      ]
    }

    if (operation === NavigationOperation.POP && !isEnter) {
      // POP 退场：缩放 + 淡出
      return [
        {
          duration: 300,
          curve: Curve.EaseInOut,
          delay: 0,
          event: () => {
            this.getUIContext()?.animateTo({
              duration: 300,
              curve: Curve.EaseInOut,
            }, () => {
              // POP 退场动画效果
            })
          },
          onTransitionEnd: () => {
            // 退场动画结束回调
          }
        }
      ]
    }

    // 返回 undefined 使用系统默认转场
    return undefined
  }
}
