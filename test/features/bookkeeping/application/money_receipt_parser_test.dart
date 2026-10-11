import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/ocr/ocr_line.dart';
import 'package:miji/features/bookkeeping/application/money_receipt_parser.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

void main() {
  // 固定在某个时刻，让「不能晚于当前时间」这条校验可预期。
  final now = DateTime(2026, 10, 11, 13, 0, 0);

  group('parsePaymentScreenshotText', () {
    test('parses an Alipay payment success screenshot', () {
      const raw = '''
支付成功
¥38.50
收钱方  张三烧烤店
付款方式  余额宝
2026-10-11 12:35:20
''';

      final draft = parsePaymentScreenshotText(raw, now: now);

      expect(draft.amountMinor, 3850);
      expect(draft.merchant, '张三烧烤店');
      expect(draft.paymentMethod, MoneyPaymentMethod.alipay);
      expect(draft.type, MoneyTransactionType.expense);
      expect(draft.occurredAt, DateTime(2026, 10, 11, 12, 35, 20));
    });

    test('parses a WeChat payment success screenshot', () {
      const raw = '''
支付成功
￥38.50
当前状态  支付成功
商户全称
某某便利超市
支付方式  零钱
交易时间  2026年10月11日 12:35:20
''';

      final draft = parsePaymentScreenshotText(raw, now: now);

      expect(draft.amountMinor, 3850);
      // 商户名换到了标签的下一行，这是微信的常见排版。
      expect(draft.merchant, '某某便利超市');
      expect(draft.paymentMethod, MoneyPaymentMethod.wechatPay);
      expect(draft.occurredAt, DateTime(2026, 10, 11, 12, 35, 20));
    });

    test('ignores discounted / bonus amounts', () {
      const raw = '''
支付成功
¥128.00
优惠 ¥8.00
立减 5.00
收钱方  星巴克
''';

      final draft = parsePaymentScreenshotText(raw, now: now);

      expect(draft.amountMinor, 12800);
      expect(draft.merchant, '星巴克');
    });

    test('detects incoming payments', () {
      const raw = '''
收款成功
￥520.00
收款方名称  李四
''';

      final draft = parsePaymentScreenshotText(raw, now: now);

      expect(draft.type, MoneyTransactionType.income);
      expect(draft.amountMinor, 52000);
      expect(draft.merchant, '李四');
    });

    test('falls back to today when only a time is present', () {
      const raw = '''
支付成功
¥25.00
付款时间  09:15
''';

      final draft = parsePaymentScreenshotText(raw, now: now);

      expect(draft.occurredAt, DateTime(2026, 10, 11, 9, 15));
    });

    test('drops a timestamp that lies in the future', () {
      const raw = '''
支付成功
¥10.00
2026-10-11 23:59:00
''';

      final draft = parsePaymentScreenshotText(raw, now: now);

      // 未来时间多半是识别错了（年份/月份串位），宁可不填。
      expect(draft.occurredAt, isNull);
      expect(draft.amountMinor, 1000);
    });

    test('does not treat a zero amount as recognized', () {
      const draft = MoneyReceiptDraft();

      expect(draft.amountMinor, isNull);
      expect(
        parsePaymentScreenshotText('支付成功\n¥0.00', now: now).amountMinor,
        isNull,
      );
    });

    test('returns an empty draft for blank input', () {
      final draft = parsePaymentScreenshotText('   \n\n  ', now: now);

      expect(draft.isEmpty, isTrue);
      expect(draft.recognizedFieldCount, 0);
      expect(draft.type, MoneyTransactionType.expense);
    });

    test('does not mistake other fields for the merchant', () {
      const raw = '''
支付成功
¥66.00
当前状态  支付成功
交易单号  2026101122001234567890
''';

      final draft = parsePaymentScreenshotText(raw, now: now);

      expect(draft.merchant, isNull);
    });

    test(
      'recovers the amount when OCR splits the symbol onto its own line',
      () {
        const raw = '''
支付成功
¥
38.50
收钱方  张三烧烤店
''';

        final draft = parsePaymentScreenshotText(raw, now: now);

        // 大字号金额里「¥」小、数字大，版面分析常把它们切成两行。
        expect(draft.amountMinor, 3850);
      },
    );

    test('recovers an amount line that carries no symbol at all', () {
      const raw = '''
支付成功
38.50
收钱方  张三烧烤店
''';

      expect(parsePaymentScreenshotText(raw, now: now).amountMinor, 3850);
    });

    test('never mistakes a bare integer for the amount', () {
      const raw = '''
支付成功
2026
交易单号
1234567890
''';

      // 裸数字兜底强制要求小数点，就是为了挡住页码、年份、单号片段。
      expect(parsePaymentScreenshotText(raw, now: now).amountMinor, isNull);
    });

    test('counts how many fields were recognized', () {
      const raw = '''
支付成功
¥38.50
收钱方  张三烧烤店
付款方式  花呗
''';

      final draft = parsePaymentScreenshotText(raw, now: now);

      expect(draft.paymentMethod, MoneyPaymentMethod.huabei);
      // 金额 / 商户 / 支付方式各一项，截图里没有时间。
      expect(draft.recognizedFieldCount, 3);
    });
  });

  // 下面四组用的是**真实截图跑出来的 OCR 文本**（scriptures/IMG_4561~4563），
  // 三种版式分别来自微信、银行 App、支付宝。它们暴露了两类先前完全漏掉的情况：
  //   1. 金额带负号（`-5000.00`），且不带货币符号；
  //   2. 收款方是页面大标题，**整行都没有标签**，只能靠「在金额正上方」定位。
  group('真实截图 OCR 文本', () {
    test('微信账单详情：金额带负号、商户在标题行', () {
      const raw = '''
10:43  5G  41
全部账单
扫二维码付款-给星空钢琴杨老师
-5000.00
当前状态  支付成功
收款方备注  二维码收款
付款方留言  葛奕姝2027学琴费用，明年11月开始
新学期
支付方式  零钱通
转账时间  2026年10月11日08:45:44
转账单号  100010730120261011016951192775
24
账单服务
对订单有疑惑  发起群收款
申请电子凭证
收款方服务
向收款方留言
''';

      final draft = parsePaymentScreenshotText(raw, now: now);

      // 「-」是流出信号，金额本身不带 ¥。
      expect(draft.amountMinor, 500000);
      expect(draft.type, MoneyTransactionType.expense);
      // 收款方是标题行，strip 掉「扫二维码付款-给」前缀。
      expect(draft.merchant, '星空钢琴杨老师');
      expect(draft.paymentMethod, MoneyPaymentMethod.wechatPay);
      expect(draft.occurredAt, DateTime(2026, 10, 11, 8, 45, 44));
      // 折行的用途说明要并回来（图上就是分两行排的）。
      expect(draft.notes, '葛奕姝2027学琴费用，明年11月开始新学期');
      expect(draft.recognizedFieldCount, 4);
    });

    test('银行 App 交易详情：`- ￥ 18.40`、带「分类」字段', () {
      const raw = '''
10:52  5G
53
交易详情
未入账
支付宝-上海壹佰米网络科技有限公司
- ￥ 18.40
交易卡号  信用卡6225********9892
交易时间  2026-10-1017:46:55
国家或地区  中国
银行交易类型  消费
薪福专区  轻松查工资，科学理工资
分类  餐饮
所属账本  请选择
备注
记录点什么..
在此商户的交易
''';

      final draft = parsePaymentScreenshotText(raw, now: now);

      // 负号与货币符号之间夹着空格。
      expect(draft.amountMinor, 1840);
      // 「支付宝-」是渠道前缀，不是商户名的一部分。
      expect(draft.merchant, '上海壹佰米网络科技有限公司');
      expect(draft.paymentMethod, MoneyPaymentMethod.creditCard);
      // 合并行的 `2026-10-10` + `17:46:55`（OCR 丢掉了中间的空格）。
      expect(draft.occurredAt, DateTime(2026, 10, 10, 17, 46, 55));
      expect(draft.categoryName, '餐饮');
      // `备注` 后面跟的是输入框占位符，不能当备注。
      expect(draft.notes, isNull);
    });

    test('支付宝账单详情：商户在标题行、分类是「餐饮美食」', () {
      const raw = '''
10:53  5G  34
账单详情
叮咚买菜>
-18.40
交易成功
支付时间  2026-10-10 17:46:56
付款方式  招商银行信用卡(9892)
商品说明  叮咚买菜-2610102931172842272
支付奖励  立即领取2积分
收款方全称  上海壹佰米网络科技有限公司
服务详情
叮咚买菜收银台  进入小程序》
收银台
更多√
账单管理  已解锁"生鲜水果"贴纸，去兑换好礼
账单分类  餐饮美食
请选择
为您推荐  买菜 ＋
计入收支
''';

      final draft = parsePaymentScreenshotText(raw, now: now);

      expect(draft.amountMinor, 1840);
      // 标题行 `叮咚买菜>` 比下面的「收款方全称」更像用户想看到的商户名。
      expect(draft.merchant, '叮咚买菜');
      expect(draft.paymentMethod, MoneyPaymentMethod.creditCard);
      expect(draft.occurredAt, DateTime(2026, 10, 10, 17, 46, 56));
      expect(draft.categoryName, '餐饮美食');
    });

    test('同样的截图，标签与值被切成两行时照样能抽出来', () {
      // ML Kit 会不会把同一视觉行的左右两列并成一行并不确定，两种都得能跑。
      const raw = '''
交易详情
未入账
支付宝-上海壹佰米网络科技有限公司
- ￥ 18.40
交易卡号
信用卡6225********9892
交易时间
2026-10-10 17:46:55
国家或地区
中国
银行交易类型
消费
分类
餐饮
所属账本
请选择
备注
记录点什么..
''';

      final draft = parsePaymentScreenshotText(raw, now: now);

      expect(draft.amountMinor, 1840);
      expect(draft.merchant, '上海壹佰米网络科技有限公司');
      expect(draft.paymentMethod, MoneyPaymentMethod.creditCard);
      expect(draft.categoryName, '餐饮');
      expect(draft.notes, isNull);
    });

    test('正号金额判为收入', () {
      const raw = '''
收款成功
+ ¥520.00
收款方  李四
''';

      final draft = parsePaymentScreenshotText(raw, now: now);

      expect(draft.amountMinor, 52000);
      expect(draft.type, MoneyTransactionType.income);
    });

    test('折扣行里的负号金额不会被当成付款金额', () {
      const raw = '''
支付宝-某某超市
-88.00
优惠
-8.00
''';

      // 「优惠」那一行整行跳过，取到的是真正的付款金额。
      expect(parsePaymentScreenshotText(raw, now: now).amountMinor, 8800);
    });
  });

  // -------------------------------------------------------------------------
  // 金额行宽松匹配：银行那张截图（`- ¥ 18.40`）在真机上认不出金额，
  // 而微信（`-5000.00`）、支付宝（`-18.40`）都正常——差别就在那个货币符号。
  // 一旦 OCR 把 `¥` 认成别的字形，带符号的那一轮匹配不上，整行又因为有杂字
  // 不算纯数字，两轮全落空。所以判据必须改成「剥掉一小段装饰后是金额」。
  // -------------------------------------------------------------------------
  group('金额行的装饰容错', () {
    test('货币符号被认成别的字形，数字照样捞得回来', () {
      // `Y` 是 `¥` 最常见的误认；这里连「任意怪字形」都要能兜住。
      for (final symbol in <String>['¥', '￥', 'Y', 'y', '羊', 'Z']) {
        final draft = parsePaymentScreenshotText(
          '交易详情\n支付宝-上海壹佰米网络科技有限公司\n- $symbol 18.40\n'
          '交易卡号  信用卡6225********9892',
          now: now,
        );
        expect(draft.amountMinor, 1840, reason: '符号为 $symbol 时');
        // 减号还在前缀里，方向不能丢。
        expect(
          draft.type,
          MoneyTransactionType.expense,
          reason: '符号为 $symbol 时',
        );
      }
    });

    test('符号连同整行都被吃掉、只剩减号加数字', () {
      expect(parsePaymentScreenshotText('- 18.40', now: now).amountMinor, 1840);
    });

    test('符号与数字被切成两行时靠「整行只有金额」兜住', () {
      expect(
        parsePaymentScreenshotText('支付成功\n- ¥\n18.40', now: now).amountMinor,
        1840,
      );
    });

    test('放宽装饰之后，裸整数依然一律不认', () {
      // 页码、年份、单号片段：没有小数点就不是金额。
      for (final raw in <String>[
        '2026',
        '1234567890',
        '订单号\n2610102931172842272',
        '交易时间  2026-10-10 17:46:55',
        '交易卡号  信用卡6225********9892',
      ]) {
        expect(
          parsePaymentScreenshotText(raw, now: now).amountMinor,
          isNull,
          reason: raw,
        );
      }
    });

    test('一行里有两串数字的，不算金额', () {
      // 装饰部分不许出现数字，`1000 18.40` 这种行必须挡住。
      expect(
        parsePaymentScreenshotText('1000 18.40', now: now).amountMinor,
        isNull,
      );
    });

    test('优惠 / 立减行里的数字仍然被跳过', () {
      expect(
        parsePaymentScreenshotText('立减 5.00\n¥128.00', now: now).amountMinor,
        12800,
      );
    });
  });

  group('matchCategoryIdByName', () {
    const catalog = MoneyCategoryCatalog(
      categories: <MoneyCategoryEntity>[
        MoneyCategoryEntity(
          id: 'c-food',
          userId: null,
          name: '餐饮',
          kind: MoneyCategoryKind.expense,
          color: null,
          icon: null,
          isSystem: true,
        ),
        MoneyCategoryEntity(
          id: 'c-transport',
          userId: null,
          name: '交通',
          kind: MoneyCategoryKind.expense,
          color: null,
          icon: null,
          isSystem: true,
        ),
      ],
      subCategories: <MoneySubCategoryEntity>[],
    );

    test('名字全等时直接命中', () {
      expect(matchCategoryIdByName(catalog, '餐饮'), 'c-food');
    });

    test('互相包含时命中：支付宝写「餐饮美食」，本地叫「餐饮」', () {
      expect(matchCategoryIdByName(catalog, '餐饮美食'), 'c-food');
    });

    test('对不上就返回 null，不硬塞近似分类', () {
      expect(matchCategoryIdByName(catalog, '宠物'), isNull);
      expect(matchCategoryIdByName(catalog, '其他支出'), isNull);
    });

    test('单字不做包含匹配，避免命中一大片', () {
      expect(matchCategoryIdByName(catalog, '餐'), isNull);
    });

    test('空名字返回 null', () {
      expect(matchCategoryIdByName(catalog, null), isNull);
      expect(matchCategoryIdByName(catalog, '   '), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 版面还原：真实截图里 OCR 会把「左标签」和「右值」识别成两个独立的块，
  // 而且块的先后顺序不保证是阅读顺序。纯文本入口在这里必然错位。
  // -------------------------------------------------------------------------

  group('OcrPage.mergeVisualLines', () {
    test('同一水平行上的块并成一句，且按 x 排序（标签在前）', () {
      final page = OcrPage(const [
        // 故意把「值」排在「标签」前面，模拟识别引擎的块顺序。
        OcrLine(
          text: '招商银行信用卡(9892)',
          left: 400,
          top: 700,
          right: 760,
          bottom: 730,
        ),
        OcrLine(text: '付款方式', left: 96, top: 702, right: 200, bottom: 728),
      ]);

      expect(page.mergeVisualLines(), <String>['付款方式  招商银行信用卡(9892)']);
    });

    test('上下相邻但 y 区间不重叠的行不会被误并', () {
      final page = OcrPage(const [
        OcrLine(text: '叮咚买菜>', left: 96, top: 400, right: 300, bottom: 440),
        OcrLine(text: '-18.40', left: 96, top: 460, right: 300, bottom: 500),
      ]);

      expect(page.mergeVisualLines(), <String>['叮咚买菜>', '-18.40']);
    });

    test('空白块不参与合并', () {
      final page = OcrPage(const [
        OcrLine(text: '   ', left: 0, top: 0, right: 10, bottom: 10),
        OcrLine(text: '餐饮美食', left: 96, top: 0, right: 200, bottom: 10),
      ]);

      expect(page.mergeVisualLines(), <String>['餐饮美食']);
    });
  });

  group('parseReceiptPage', () {
    test('块顺序被打乱时仍能抽对字段——这正是纯文本入口失手的地方', () {
      // 支付宝账单详情页的块布局：标签在左、值在右，且块顺序杂乱无章。
      final page = OcrPage(const [
        OcrLine(
          text: '招商银行信用卡(9892)',
          left: 400,
          top: 700,
          right: 760,
          bottom: 730,
        ),
        OcrLine(
          text: '叮咚买菜-2610102931172842272',
          left: 400,
          top: 760,
          right: 900,
          bottom: 790,
        ),
        OcrLine(text: '-18.40', left: 96, top: 500, right: 300, bottom: 560),
        OcrLine(text: '叮咚买菜>', left: 96, top: 420, right: 300, bottom: 460),
        OcrLine(text: '付款方式', left: 96, top: 702, right: 200, bottom: 728),
        OcrLine(text: '商品说明', left: 96, top: 762, right: 200, bottom: 788),
        OcrLine(text: '账单分类', left: 96, top: 900, right: 200, bottom: 926),
        OcrLine(text: '餐饮美食', left: 400, top: 902, right: 520, bottom: 928),
      ]);

      final draft = parseReceiptPage(page, now: now);

      expect(draft.amountMinor, 1840);
      expect(draft.merchant, '叮咚买菜');
      expect(draft.paymentMethod, MoneyPaymentMethod.creditCard);
      expect(draft.categoryName, '餐饮美食');
      expect(draft.type, MoneyTransactionType.expense);
    });

    test('无坐标的纯文本退化为行序，结果与旧入口一致', () {
      const raw = '''
支付成功
¥38.50
收钱方  张三烧烤店
付款方式  余额宝
''';

      final draft = parseReceiptPage(OcrPage.fromPlainText(raw), now: now);

      expect(draft.amountMinor, 3850);
      expect(draft.merchant, '张三烧烤店');
      expect(draft.paymentMethod, MoneyPaymentMethod.alipay);
    });
  });
}
