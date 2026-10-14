// disableAnimation 禁用转场动画配置模板
// API: NavPathStack.disableAnimation(value: boolean)
// @since: 11
// 来源: interface_sdk-js/api/@internal/component/ets/navigation.d.ts:1280
//
// 作用域: NavPathStack 级别，影响该 NavPathStack 关联的 Navigation 中所有页面跳转
// 单次禁用替代方案: 在 pushPath/pop 等方法中传 animated: false 参数

// ============================================================
// 全局禁用 — Navigation 级别禁用所有转场动画（AC-5.2）
// ============================================================

@Entry
@Component
struct GlobalDisableAnimationPage {
  @State pageStack: NavPathStack = new NavPathStack()
  @State isAnimationDisabled: boolean = false

  build() {
    Navigation(this.pageStack) {
      Column() {
        Button('Push Detail Page (animated)')
          .onClick(() => {
            // 转场动画由 disableAnimation 状态控制
            this.pageStack.pushPath({ name: 'DetailPage' })
          })
          .margin(10)

        Button('Push Detail Page (no animation)')
          .onClick(() => {
            // 单次禁用 — 传 animated: false 参数
            this.pageStack.pushPath({ name: 'DetailPage' }, false)
          })
          .margin(10)

        Button(this.isAnimationDisabled ? 'Enable Animation' : 'Disable Animation')
          .onClick(() => {
            this.isAnimationDisabled = !this.isAnimationDisabled
            // 全局禁用/启用 — 影响 NavPathStack 中所有跳转
            this.pageStack.disableAnimation(this.isAnimationDisabled)
          })
          .margin(10)
      }
    }
    .navDestination(this.navDestinationBuilder)
  }

  @Builder
  navDestinationBuilder(name: string, param: unknown): void {
    if (name === 'DetailPage') {
      DetailPage()
    }
  }
}

// ============================================================
// 单页禁用 — NavDestination 级别不单独禁用转场（AC-5.1）
// NavDestination 本身没有独立的 disableAnimation 属性，
// 通过 NavPathStack.disableAnimation(true) 在跳转到该页面前禁用，
// 跳转后恢复 disableAnimation(false)。
// ============================================================

@Entry
@Component
struct SinglePageDisableAnimationPage {
  @State pageStack: NavPathStack = new NavPathStack()

  build() {
    Navigation(this.pageStack) {
      Column() {
        Button('Push Detail Page (disable animation for this jump)')
          .onClick(() => {
            // 单页禁用方案1: 临时禁用 + 跳转后恢复
            this.pageStack.disableAnimation(true)
            this.pageStack.pushPath({ name: 'QuietDetailPage' })
            // 跳转后恢复（在下一帧恢复，避免影响当前跳转）
            setTimeout(() => {
              this.pageStack.disableAnimation(false)
            }, 100)

            // 单页禁用方案2: 直接使用 animated: false 参数（推荐）
            // this.pageStack.pushPath({ name: 'QuietDetailPage' }, false)
          })
          .margin(10)
      }
    }
    .navDestination(this.navDestinationBuilder)
  }

  @Builder
  navDestinationBuilder(name: string, param: unknown): void {
    if (name === 'QuietDetailPage') {
      QuietDetailPage()
    }
  }
}

@Component
struct DetailPage {
  build() {
    NavDestination() {
      Column() {
        Text('Detail Page')
          .fontSize(20)
          .margin(20)
      }
      .width('100%')
      .height('100%')
    }
    .title('Detail')
  }
}

@Component
struct QuietDetailPage {
  build() {
    NavDestination() {
      Column() {
        Text('Quiet Detail Page (no transition)')
          .fontSize(20)
          .margin(20)
      }
      .width('100%')
      .height('100%')
    }
    .title('Quiet Detail')
  }
}
