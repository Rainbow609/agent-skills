/**
 * 自绘组件虚拟节点模板（F 类，accessibilityVirtualNode，API 11+）
 * 事实基准：references/api-facts.md、references/virtual-node.md
 * 约束：参数直传 @Builder 函数（对象包裹 { builder: ... } 会编译报错，2026-10 评测 vod-3 实测）
 */

// ========== F 类：Canvas 折线图可读（API 11+，输出前先查 build-profile 三字段 ≥ 11） ==========
@Entry
@Component
struct TrendChartPage {
  private context: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true));

  @Builder
  chartAccessibilityNode() {
    Column() {
      Text('最近 7 天访问趋势')
        .accessibilityText('折线图：最近 7 天数据呈上升趋势，峰值 92，今日 81')
    }
    .accessibilityGroup(true)                 // 总览整体播报
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height(240)
      .onReady(() => {
        // ...原有绘制逻辑保持不变（辅助工具不读绘制内容）
        this.drawTrend();
      })
      .accessibilityVirtualNode(() => {
        this.chartAccessibilityNode();        // 直传 builder 函数
      })
  }

  drawTrend() {
    // 原有绘制实现
  }
}

// ========== 分粒度虚拟节点（有结构的数据） ==========
@Builder
dashboardAccessibilityNode() {
  Column({ space: 8 }) {
    Text('仪表盘总览')
      .accessibilityText('当前时速 60 公里每小时，限速 80')
    Text('区间均值')
      .accessibilityText('最近 5 分钟均值 58')
  }
}

// ========== 可交互自绘区域（配合自定义动作，API 12+） ==========
@Builder
boardAccessibilityNode() {
  Column() {
    Text('棋盘 E2 格')
      .accessibilityText('E2 格，白方马，可走 D4/F3/G1')
      .accessibilityCustomActions([
        {
          name: '移动到 D4',
          action: 'move',
          onAction: () => this.moveTo('D4')
        }
      ])
  }
}
