package com.mcgeq.miji.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import com.mcgeq.miji.MainActivity
import com.mcgeq.miji.R
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.LocalDate

/**
 * 满宽「今日支出」小组件（默认 5 格宽 × 2 格高，横贯屏幕一整行）。
 *
 * 版面尺寸全交给 `res/xml/money_widget_info.xml` 与 `res/layout/money_widget.xml`：
 * `minWidth=320dp` 是给 Android 11 及以下启动器的换算依据（5 格），
 * `targetCellWidth=5` 给 Android 12+；布局 match_parent 铺满，所以这里
 * 不需要（也不该）用 `onAppWidgetOptionsChanged` 手动算宽高。
 *
 * 版面五段：今日支出 + 笔数 / 大号金额 + 记一笔按钮 / 预算进度条 / 预算文案 /
 * 本周·本月·日均（见 layout 里的注释）。
 *
 * 这里**不做任何业务判断**：金额、笔数、遮罩、登录态全部由 Dart 侧算好写成文本
 * （见 `lib/features/bookkeeping/application/money_home_widget.dart`）。
 * 原生只负责两件 Dart 做不到的事：
 *
 * 1. **跨天判断**：把快照里的 `mw_date` 和今天比对。app 可能好几天没打开，
 *    这时候卡面必须写「截至 10-20」而不是拿昨天的数字冒充今天；
 * 2. **点击**：整块 → 打开 app 首页；「记一笔」按钮 → 直达记账表单。
 *
 * 为什么不让原生直接读 drift 的 sqlite：那会变成双写者，schema 现在 v34，
 * 以后每次迁移都得在 Kotlin 和 Dart 两侧同步，漏一次就是线上崩溃。
 */
class MoneyWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            appWidgetManager.updateAppWidget(appWidgetId, buildViews(context, widgetData))
        }
    }

    private fun buildViews(context: Context, widgetData: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.money_widget)

        val storedDate = widgetData.getString(KEY_DATE, null)
        // 只比到天：小组件刷新粒度本来就是分钟级，比到秒永远算「过期」。
        val stale = storedDate != null && storedDate != LocalDate.now().toString()

        val label = if (stale && storedDate != null) {
            // MM-dd 就够了：同一年的账没人需要看到年份。
            context.getString(R.string.money_widget_stale_label, storedDate.takeLast(5))
        } else {
            widgetData.getString(KEY_LABEL, null)
                ?: context.getString(R.string.money_widget_label_text)
        }

        val amount = widgetData.getString(KEY_AMOUNT, null)
            ?: context.getString(R.string.money_widget_amount_placeholder)

        val meta = if (stale) {
            context.getString(R.string.money_widget_stale_meta)
        } else {
            widgetData.getString(KEY_META, null)
                ?: context.getString(R.string.money_widget_meta_placeholder)
        }

        // 底部的三个周期量：Dart 侧已经按「遮罩 / 未解锁」处理成 •••• 或 compact 金额，
        // 这里只负责摆上去，不做任何格式化。
        val weekExpense = widgetData.getString(KEY_WEEK, null)
            ?: context.getString(R.string.money_widget_amount_compact_placeholder)
        val monthExpense = widgetData.getString(KEY_MONTH, null)
            ?: context.getString(R.string.money_widget_amount_compact_placeholder)
        val dailyExpense = widgetData.getString(KEY_DAILY, null)
            ?: context.getString(R.string.money_widget_amount_compact_placeholder)

        views.setTextViewText(R.id.widget_label, label)
        views.setTextViewText(R.id.widget_amount, amount)
        views.setTextViewText(R.id.widget_meta, meta)
        views.setTextViewText(R.id.widget_week, weekExpense)
        views.setTextViewText(R.id.widget_month, monthExpense)
        views.setTextViewText(R.id.widget_daily, dailyExpense)

        // 预算块：没配预算时整块收起。收起后省下的高度由上下两个 weight 带
        // 均摊，卡面不会被「挖掉一块」。
        //
        // 进度条只传数值不传画刷：RemoteViews 没有可用的 setProgressDrawable，
        // 所以「快满了 / 超支了」只能靠下面那行文字的颜色表达。
        val budgetVisible = widgetData.getString(KEY_BUDGET_VISIBLE, "0") == "1"
        if (budgetVisible) {
            val percent = widgetData.getString(KEY_BUDGET_PERCENT, "0")?.toIntOrNull() ?: 0
            val alert = widgetData.getString(KEY_BUDGET_ALERT, "0") == "1"
            views.setTextViewText(
                R.id.widget_budget_text,
                widgetData.getString(KEY_BUDGET_TEXT, "") ?: "",
            )
            views.setTextViewText(
                R.id.widget_budget_total,
                widgetData.getString(KEY_BUDGET_TOTAL, "") ?: "",
            )
            views.setProgressBar(R.id.widget_budget_bar, 100, percent.coerceIn(0, 100), false)
            views.setTextColor(R.id.widget_budget_text, budgetTextColor(context, alert))
        } else {
            views.setViewVisibility(R.id.widget_budget_bar, View.GONE)
            views.setViewVisibility(R.id.widget_budget_row, View.GONE)
        }

        // 两个点击目标，两个 PendingIntent（requestCode 必须不同，否则会互相覆盖）：
        // - 整块卡片 → 首页：用户想「看一眼就走」时不该被硬塞进记账表单；
        // - 按钮 → 记一笔：这是卡片唯一的动作按钮，必须一击直达。
        views.setOnClickPendingIntent(
            R.id.widget_root,
            open(context, HOME_URI, REQUEST_HOME),
        )
        views.setOnClickPendingIntent(
            R.id.widget_action,
            open(context, BOOKKEEPING_URI, REQUEST_BOOKKEEPING),
        )
        return views
    }

    /**
     * 预算那行的文字色：正常是次要灰，超支换成警示色。
     *
     * 用 `resources.getColor` 而不是 `context.getColor`：后者要 API 23，
     * 而这里没有声明更高的 minSdk，压到 21 会有 lint 报错。
     */
    @Suppress("DEPRECATION")
    private fun budgetTextColor(context: Context, alert: Boolean): Int =
        context.resources.getColor(
            if (alert) R.color.money_widget_danger else R.color.money_widget_muted,
        )

    /**
     * 点一下 → 打开 app 内某条路由。
     *
     * 走 `getLaunchIntentForPackage` 而不是自己拼 ComponentName：Flutter 的
     * 启动 Activity、taskAffinity、必要的 flag 都由系统给的那份 Intent 决定，
     * 手拼很容易漏掉某个 flag，表现为「点了开新任务」或「点了没反应」。
     *
     * URI 是**三斜线**：`miji://app/...` 会被解析成 host=app、path=/bookkeeping，
     * 路径少一段就跳不过去。路径与 `AppRoutes` 一一对应。
     */
    private fun open(context: Context, uri: String, requestCode: Int): PendingIntent {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        val intent = launch.apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse(uri)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private companion object {
        // 与 Dart 侧的 money_home_widget.dart 一一对应，改一处就要改另一处。
        const val KEY_LABEL = "mw_label"
        const val KEY_AMOUNT = "mw_amount"
        const val KEY_META = "mw_meta"

        // 底部的「本周 / 本月 / 日均」，值为 compact 金额或 ••••（Dart 侧已处理好）。
        const val KEY_WEEK = "mw_week"
        const val KEY_MONTH = "mw_month"
        const val KEY_DAILY = "mw_daily"

        // 预算块：可见性、两段文案、进度百分比、是否超支。
        // Dart 侧一律写成字符串（saveWidgetData<String> 是两端都稳的唯一类型）。
        const val KEY_BUDGET_VISIBLE = "mw_budget_visible"
        const val KEY_BUDGET_TEXT = "mw_budget_text"
        const val KEY_BUDGET_TOTAL = "mw_budget_total"
        const val KEY_BUDGET_PERCENT = "mw_budget_percent"
        const val KEY_BUDGET_ALERT = "mw_budget_alert"

        const val KEY_DATE = "mw_date"

        /** 与 `lib/core/router/app_routes.dart` 的 `AppRoutes.home` 保持一致。 */
        const val HOME_URI = "miji:///app/home"

        /** 与记账页的 `initialAction` 约定保持一致（和通知点击共用同一条路由）。 */
        const val BOOKKEEPING_URI = "miji:///app/bookkeeping?action=expense"

        // 两个 PendingIntent 必须用不同 requestCode：相同 requestCode + 相同 Intent
        // 结构会被系统当成同一个 PI，后绑定的会把先绑定的覆盖掉。
        const val REQUEST_HOME = 1001
        const val REQUEST_BOOKKEEPING = 1002
    }
}
