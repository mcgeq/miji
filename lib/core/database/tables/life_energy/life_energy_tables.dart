import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';

/// 收入与工时：算「真实时薪」需要的全部输入。
///
/// **主键是 userId，一个账号一份**（不是账本级）。时薪描述的是「这个人干什么
/// 工作」，跟「这笔账记在哪个账本」无关；做成账本级的话，用户切到家庭账本就得
/// 重填一遍，而两个账本里的时薪其实是同一个数。
///
/// 所有金额都是 **minor（分）**，与流水同口径。输入项一律是「到手」——
/// 税率、社保这些需要推断的东西既不问用户，也不替他猜。
class LifeEnergyProfiles extends Table {
  TextColumn get userId => text().references(Users, #id)();

  /// 每个付薪周期实际拿到手的钱。
  IntColumn get payAmountMinor => integer()();

  /// `month` / `year` / `day` / `hour`。界面统一折算到月，
  /// 因为所有下游算式（月工时、月净收入）都是月口径。
  TextColumn get payCycle => text().withDefault(const Constant('month'))();

  /// 跟随账本主币种，只用于金额格式化。
  TextColumn get currencyCode => text().withDefault(const Constant('CNY'))();

  /// `net` 直接填到手 / `gross` 填税前自动推算。
  ///
  /// **不在这里加一列「税」**：税是「月薪 + 参数 + 月份」的函数，落库就要维护
  /// 「什么时候重算」，而漏算一次的表现是用户对不上工资条。纯函数现算。
  TextColumn get compensationMode =>
      text().withDefault(const Constant('net'))();

  /// 税前月薪（分）。只在 `gross` 口径下当输入；`net` 口径下这一列恒为 0。
  ///
  /// 为什么不复用 [payAmountMinor]：切到税前模式时，反推税前是**多解**的
  /// （社保基数封顶后，税前差 1,000 到手可能只差 600）。给一个空位让用户填
  /// 合同上那个数，比拿一个算不准的换算结果糊弄过去诚实。
  IntColumn get grossMonthlyMinor => integer().withDefault(const Constant(0))();

  /// 社保基数怎么定：`auto` 跟随税前并夹到上下限 / `manual` 用 [socialBaseMinor]。
  ///
  /// 基数**不等于月薪**：按上年度月平均工资核定，月薪从 2 万涨到 3 万，当年
  /// 7 月之前大概率还按 2 万缴。所以必须是一个独立可改的字段。
  TextColumn get socialBaseMode => text().withDefault(const Constant('auto'))();
  IntColumn get socialBaseMinor => integer().withDefault(const Constant(0))();
  IntColumn get socialBaseFloorMinor =>
      integer().withDefault(const Constant(682100))();
  IntColumn get socialBaseCeilingMinor =>
      integer().withDefault(const Constant(3581100))();

  /// 个人四项比例（万分比整数：800 = 8%）。
  ///
  /// 用整数不用 double：`0.08` 在浮点里是 `0.08000000000000002`，累乘 12 个月
  /// 能差出几分钱，而「几分钱对不上」正是这个功能最不该有的错。
  IntColumn get ratePensionBp => integer().withDefault(const Constant(800))();
  IntColumn get rateMedicalBp => integer().withDefault(const Constant(200))();
  IntColumn get rateUnemploymentBp =>
      integer().withDefault(const Constant(50))();
  IntColumn get rateHousingFundBp =>
      integer().withDefault(const Constant(1200))();

  /// 单位五项比例。只进年度账，**永不进时薪** —— 动它就等于改公司成本，
  /// 和用户口袋里的钱无关。
  IntColumn get ratePensionErBp =>
      integer().withDefault(const Constant(1600))();
  IntColumn get rateMedicalErBp => integer().withDefault(const Constant(950))();
  IntColumn get rateUnemploymentErBp =>
      integer().withDefault(const Constant(50))();
  IntColumn get rateInjuryErBp => integer().withDefault(const Constant(40))();
  IntColumn get rateHousingFundErBp =>
      integer().withDefault(const Constant(1200))();

  /// 大额医疗互助（分/月）。各地 3 元或按比例不等，可填 0。
  IntColumn get medicalFixedMinor => integer().withDefault(const Constant(0))();

  /// 专项附加扣除合计（分/月）。减的是**计税基数**不是税额。
  IntColumn get specialDeductionMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get workDaysPerMonth => integer().withDefault(const Constant(22))();

  /// 每天**合同**工作分钟（不含通勤、不含加班）。
  IntColumn get workMinutesPerDay =>
      integer().withDefault(const Constant(480))();

  /// 每个工作日往返通勤分钟。这一项常被漏掉，却是把「一天 8 小时」变成
  /// 「一天 9.7 小时」的那个变量。
  IntColumn get commuteMinutesPerDay =>
      integer().withDefault(const Constant(0))();

  /// **常规**加班（典型月份），不是本月实际。
  ///
  /// 临时加班不进这里：它走 `overtime_entries` 按月聚合，只影响「本期」视图。
  /// 一旦为了某次加班改这个字段，所有单品的换算天数都会跟着变，用户会以为
  /// 功能在乱算。
  IntColumn get overtimeMinutesPerMonth =>
      integer().withDefault(const Constant(0))();

  /// 工作开销：为了上班才多花的部分。六项分开存，方便逐项解释口径。
  IntColumn get costTransportMinor =>
      integer().withDefault(const Constant(0))();
  IntColumn get costMealMinor => integer().withDefault(const Constant(0))();
  IntColumn get costClothingMinor => integer().withDefault(const Constant(0))();
  IntColumn get costChildcareMinor =>
      integer().withDefault(const Constant(0))();
  IntColumn get costDecompressMinor =>
      integer().withDefault(const Constant(0))();
  IntColumn get costOtherMinor => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// 同步四件套。
  ///
  /// 这张表（v26 起）当初没有这四列 —— 那时它只是「一份读数」，没有冲突判定
  /// 的需要。接入同步后它是**账号级单例**：两端同时改档案时，没有 version 就
  /// 没法判断谁该覆盖谁，所以补上（schemaVersion 33）。
  TextColumn get deviceId => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  String get tableName => 'life_energy_profiles';

  @override
  Set<Column<Object>> get primaryKey => {userId};
}

/// 职业段：从某个月起、在哪家公司、拿多少钱、什么工作条件。
///
/// **一条段 = 相邻两条之间的区间**，不存 `end`：多存一个结束月就有两份真相，
/// 编辑中间某段时要么批量改邻居、要么留下空洞。
///
/// 为什么要存「工作单位」而不是只存金额：同公司涨 25% 和跳槽涨 25%，到手
/// 几乎一样，真实时薪能差一半（2026-10-18 设计稿第六节）。不存公司名，这两件
/// 事在读历史时长得一模一样。
///
/// 为什么要存**条件覆盖**：`life_energy_profiles` 上的通勤 / 加班 / 开销只有
/// 一份，表示「现在」。换过工作后，旧段的时薪若用现在的通勤去算，会得出一个
/// 既不是当时也不是现在的数（示例：16,000 那段 53.6 会变成 47.6）。所以凡是
/// 会影响时薪分母或分子的条件，都要能跟着段走。
///
/// 覆盖列全部 **nullable，null = 继承档案**。只写真正变过的那几项：历史段
/// 不需要解释开销的六项构成，只存一个合计。
@DataClassName('SalarySegmentRow')
class SalarySegments extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();

  /// 工作单位。纯文本、可空。空值**不参与**「涨薪还是跳槽」的判断——
  /// 只有相邻两段都填了且不同才算跳槽，否则用户补填第一条时整段历史会重洗。
  TextColumn get employer => text().nullable()();

  /// 从哪个月起生效。月粒度：涨薪是「按月」的事件，累计预扣也按月推进。
  IntColumn get effectiveYear => integer()();
  IntColumn get effectiveMonth => integer()();

  /// 金额（分）。口径由 [payCycle] 决定，与档案同一套枚举。
  ///
  /// 到手（分）。**恒为到手**，与口径无关 —— 税前那列是 [grossAmountMinor]。
  ///
  /// 两列各管一件事：切换口径只会换「用哪一列当输入」，不会把已有的数重新
  /// 解释一遍（重新解释会让「之前的保持不变」直接失效）。
  IntColumn get amountMinor => integer()();

  /// 税前月薪（分）。只在使用「税前推算」时写；null = 这一段是在「直接填到手」
  /// 模式下记的，历史里没有税前数字，到时候直接用 [amountMinor]。
  IntColumn get grossAmountMinor => integer().nullable()();

  /// null = 继承档案的周期。段上单独存是因为换工作可能从月薪变日薪。
  TextColumn get payCycle => text().nullable()();

  IntColumn get workDaysPerMonth => integer().nullable()();
  IntColumn get workMinutesPerDay => integer().nullable()();
  IntColumn get commuteMinutesPerDay => integer().nullable()();
  IntColumn get overtimeMinutesPerMonth => integer().nullable()();

  /// 工作开销**月合计**覆盖（分）。六项细目只留在档案里：历史段只需要
  /// 「分子减多少」，逐项拆开没人填，也没人会去看三年前的通勤费明细。
  IntColumn get workCostMonthlyMinor => integer().nullable()();

  /// 该段的五险一金参数快照（JSON）。null = 跟随档案。
  ///
  /// 不拆成十几列：参数还会加项（补充公积金、专项扣除新条目），而 JSON 加
  /// 字段不需要迁移；而且这些数从不参与查询 / 排序，它们的唯一用途是「把那一刻
  /// 的尺子原样抬回来」。
  TextColumn get payrollJson => text().nullable()();

  /// 「转正」「调岗」这类备注。**不存「涨薪 / 跳槽」**——那是从 employer
  /// 和金额推出来的，让人手填两遍迟早对不上。
  TextColumn get note => text().nullable()();

  TextColumn get deviceId => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'salary_segments';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 想买清单。
///
/// **不是支出**：不进流水、不进统计、不影响预算。只有用户标记「买了」并选择
/// 记一笔时，才落一条正常的 `money_transactions`。
///
/// `ledgerId` 不加外键：清单是记账的旁支，账本被删（软删）后记录仍应留在原处，
/// 让它跟着账本一起坏掉没有好处。空值表示「创建时还没有账本」。
class WishlistItems extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get ledgerId => text().nullable()();

  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  IntColumn get targetAmountMinor => integer()();

  /// `want` / `strong` / `need` 三档。刻意不给五星：星级会变成自我评分游戏。
  TextColumn get desireLevel => text().withDefault(const Constant('want'))();

  /// `waiting` 冷却中 / `ready` 可以决定了 / `bought` 已买 / `dropped` 已放弃。
  ///
  /// `ready` 是**派生状态**，不落「已到期」这件事本身：判断只看
  /// `cooldownUntil` 与当前时间，避免定时任务漏跑就永远卡在「冷却中」。
  TextColumn get status => text().withDefault(const Constant('waiting'))();

  DateTimeColumn get cooldownUntil => dateTime().nullable()();

  /// 书里的三个问题。可空 = 还没回答；三问全不通过也照样能加进清单。
  BoolColumn get q1Satisfaction => boolean().nullable()();
  BoolColumn get q2Aligned => boolean().nullable()();
  BoolColumn get q3NoJob => boolean().nullable()();

  DateTimeColumn get decidedAt => dateTime().nullable()();

  /// 买了之后可选关联的那笔流水。
  TextColumn get transactionId => text().nullable()();

  TextColumn get deviceId => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'wishlist_items';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 加班记录：临时加班 / 连续一周加班，按月聚合成「本期修正」。
///
/// 只存**时长**，不存起止时刻。一问「18:30–21:00」就变成考勤，而且用户填不出
/// 一周前的准确时刻，只会填个大概 —— 那还不如直接问时长。
///
/// 本期修正**不单独存一张表**：每次由当月记录聚合出来。既存一份「本月加班
/// 16 小时」又存明细，两边迟早打架。
class OvertimeEntries extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get ledgerId => text().nullable()();

  /// 加班发生在哪一天。「连续一周」就是这一周里的五条记录。
  DateTimeColumn get workDate => dateTime()();

  IntColumn get minutes => integer()();

  /// `paid` 给钱 / `timeOff` 调休 / `none` 白干。
  ///
  /// 分开存是因为同一份时长下三种补偿的净效应方向相反：给钱会让本期时薪
  /// **上升**，白干会**下降**，调休净额为零。
  TextColumn get compType => text().withDefault(const Constant('paid'))();

  /// 实际拿到的加班费（不是按倍率推算的应得金额）。
  IntColumn get payAmountMinor => integer().withDefault(const Constant(0))();

  /// 因为这次加班多花的钱（打车回家、宵夜）。进本期工作开销。
  IntColumn get extraCostMinor => integer().withDefault(const Constant(0))();

  /// 休息日加班要多算一趟往返通勤：工作日加班不用（往返本来就在每天那 70 分钟里）。
  BoolColumn get isRestDay => boolean().withDefault(const Constant(false))();

  TextColumn get note => text().nullable()();

  TextColumn get deviceId => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'overtime_entries';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 年终奖：**按纳税年度**记，一个人一年一条。
///
/// 为什么不挂在职业段上：单独计税的「全年一次性奖金」是按**发放年度**算税的，
/// 而且一个纳税年度**只能用一次**单独计税。这两条决定它跟「段」不是一条时间轴 ——
/// 你在 A 公司干到 6 月、7 月跳去 B，1 月发的 A 公司奖金属于**发放那一年**，
/// 用「年末所在段」或「年初所在段」去归属都会猜错一半。挂年度、另存一个「哪家
/// 发的」文本，就没有需要猜的地方。
///
/// `taxYear = 0` 表示**没填年度**（旧数据迁移过来的，或者用户还没想好属于哪年）：
/// 任何一年的账都不会把它算进去，界面上单独列出来提醒补年份。0 是显式哨兵值，
/// 不用 null —— 那样唯一索引就管不住「一年只能有一条」。
@DataClassName('BonusPaymentRecord')
@TableIndex.sql(
  // 必须是**部分索引**：软删的行仍然占着 (user_id, tax_year)，全量唯一会让
  // 「删掉一年再补同一年」直接撞索引。
  'CREATE UNIQUE INDEX bonus_payments_user_year '
  'ON bonus_payments(user_id, tax_year) WHERE is_deleted = 0',
)
class BonusPayments extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();

  /// 纳税年度（发放年度）。0 = 未指定。
  IntColumn get taxYear => integer()();

  IntColumn get amountMinor => integer()();

  /// 谁发的（公司简称，可空）。不参与任何计算，只为了让人分得清两条记录。
  TextColumn get sourceLabel => text().nullable()();

  TextColumn get note => text().nullable()();

  TextColumn get deviceId => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'bonus_payments';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
