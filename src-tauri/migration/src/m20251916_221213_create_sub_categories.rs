use sea_orm_migration::prelude::*;

use crate::schema::{Categories, SubCategories};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(SubCategories::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(SubCategories::Name)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(SubCategories::CategoryName)
                            .string_len(38)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(SubCategories::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(SubCategories::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .primary_key(
                        Index::create()
                            .col(SubCategories::Name)
                            .col(SubCategories::CategoryName),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_subcategory_category")
                            .from(SubCategories::Table, SubCategories::CategoryName)
                            .to(Categories::Table, Categories::Name)
                            .on_delete(ForeignKeyAction::Restrict)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .index(
                        Index::create()
                            .name("idx_subcategories_category_name")
                            .table(SubCategories::Table)
                            .col(SubCategories::CategoryName)
                            .col(SubCategories::Name)
                            .unique(),
                    )
                    .to_owned(),
            )
            .await?;
        // 插入 SubCategorySchema 中的所有子类别
        let subcategories = vec![
            // ====================== 餐饮（Food） ======================
            ("Restaurant", "Food"),         // 餐厅堂食
            ("Groceries", "Food"),          // 生鲜杂货（超市/菜市场食材）
            ("Snacks", "Food"),             // 零食甜品（便利店/甜品店）
            ("Takeout", "Food"),            // 外卖配送
            ("CoffeeTea", "Food"),          // 咖啡茶饮（饮品店消费）
            ("Alcohol", "Food"),            // 酒水饮料（酒吧/酒类专卖店）
            ("CookingIngredients", "Food"), // 烹饪原料（生鲜/调料）
            ("DiningVouchers", "Food"),     // 餐饮代金券（团购/优惠券消费）
            ("FoodDeliveryFee", "Food"),    // 外卖平台费
            // ====================== 交通（Transport） ======================
            ("Bus", "Transport"),         // 公共交通（公交/地铁/轻轨）
            ("Taxi", "Transport"),        // 出租车费用
            ("RideShare", "Transport"),   // 网约车（滴滴/美团打车）
            ("Fuel", "Transport"),        // 燃油费（汽油/柴油）
            ("TollBridge", "Transport"),  // 过路费/过桥费
            ("Parking", "Transport"),     // 停车费（商场/路边停车位）
            ("ParkingFine", "Transport"), // 停车罚款（违规停车罚金）
            ("Train", "Transport"),       // 火车票（高铁/动车/普速列车）
            ("Flight", "Transport"),      // 飞机票（经济舱/商务舱）
            ("Ferry", "Transport"),       // 轮渡费（跨江/跨海渡轮）
            ("BikeRental", "Transport"),  // 共享单车/电动车租赁
            // ====================== 娱乐（Entertainment） ======================
            ("Movies", "Entertainment"),        // 电影票（影院观影）
            ("Concerts", "Entertainment"),      // 音乐会/演唱会
            ("Theater", "Entertainment"),       // 话剧/音乐剧/戏剧
            ("Exhibition", "Entertainment"),    // 展览/艺术展/博物馆
            ("AmusementPark", "Entertainment"), // 游乐园/主题公园
            ("Karaoke", "Entertainment"),       // KTV/包厢消费
            ("Gaming", "Entertainment"),        // 游戏消费（线下桌游/电玩城）
            ("Streaming", "Entertainment"),     // 流媒体订阅（如Netflix/Spotify）
            ("E-sports", "Entertainment"),      // 电竞观赛（赛事门票/直播打赏）
            ("HobbySupplies", "Entertainment"), // 兴趣爱好用品（如乐器/模型）
            // ====================== 公共事业（Utilities） ======================
            ("Electricity", "Utilities"),        // 电费
            ("Water", "Utilities"),              // 水费
            ("Gas", "Utilities"),                // 燃气费
            ("Internet", "Utilities"),           // 宽带费
            ("Cable", "Utilities"),              // 有线电视费
            ("PropertyManagement", "Utilities"), // 物业费
            ("GarbageDisposal", "Utilities"),    // 垃圾处理费
            ("Heating", "Utilities"),            // 取暖费（北方冬季）
            ("SolarPanel", "Utilities"),         // 太阳能设备维护费
            ("PhoneBill", "Utilities"),          // 话费（手机/固话费用）
            // ====================== 购物（Shopping） ======================
            ("Clothing", "Shopping"),       // 服装（上衣/裤子/外套等）
            ("Footwear", "Shopping"),       // 鞋类（运动鞋/皮鞋/凉鞋）
            ("Accessories", "Shopping"),    // 配饰（项链/帽子/围巾）
            ("Electronics", "Shopping"),    // 电子产品（手机/电脑/耳机）
            ("Cosmetics", "Shopping"),      // 化妆品（护肤品/彩妆）
            ("Jewelry", "Shopping"),        // 珠宝首饰（项链/戒指）
            ("HouseholdGoods", "Shopping"), // 日用品（纸巾/洗洁精）
            ("Toys", "Shopping"),           // 玩具（儿童玩具/成人解压玩具）
            ("BooksMagazines", "Shopping"), // 书籍/杂志（纸质/电子）
            ("BabyProducts", "Shopping"),   // 母婴用品（奶粉/尿布）
            // ====================== 工资收入（Salary） ======================
            ("MonthlySalary", "Salary"),     // 月薪（固定工资）
            ("Bonus", "Salary"),             // 奖金（年终奖/项目奖）
            ("Overtime", "Salary"),          // 加班费
            ("Commission", "Salary"),        // 提成（销售类额外收入）
            ("Allowance", "Salary"),         // 津贴（餐补/交通补/住房补）
            ("RetirementPension", "Salary"), // 养老金（退休工资）
            ("PartTimeJob", "Salary"),       // 兼职收入（临时工作报酬）
            // ====================== 投资收入（Investment） ======================
            ("StockDividend", "Investment"),        // 股票分红
            ("BondInterest", "Investment"),         // 债券利息
            ("FundDistribution", "Investment"),     // 基金分红
            ("RentalIncome", "Investment"),         // 房产租金（住宅/商铺）
            ("CryptoIncome", "Investment"),         // 加密货币收益（挖矿/交易）
            ("Royalties", "Investment"),            // 版权收入（著作/专利）
            ("DividendReinvestment", "Investment"), // 股息再投资（自动复投收益）
            // ====================== 资金转账（Transfer） ======================
            ("AccountTransfer", "Transfer"), // 账户间转账（银行卡/支付宝互转）
            ("LoanRepayment", "Transfer"),   // 贷款还款（房贷/车贷月供）
            ("InvestmentWithdrawal", "Transfer"), // 投资取款（赎回基金/卖出股票）
            ("FriendFamilyTransfer", "Transfer"), // 亲友转账（借款/还款）
            ("PlatformWithdrawal", "Transfer"), // 平台提现（微信/支付宝提现到银行卡）
            // ====================== 教育支出（Education） ======================
            ("Tuition", "Education"),          // 学费（K12/大学/职业培训）
            ("Textbooks", "Education"),        // 教材/教辅书
            ("Courses", "Education"),          // 培训课程（语言/编程/考证）
            ("StudyAbroad", "Education"),      // 留学费用（学费/生活费）
            ("Tutoring", "Education"),         // 课外辅导（家教/1对1）
            ("ExamFees", "Education"),         // 考试报名费（雅思/CPA/公务员）
            ("EducationalTools", "Education"), // 学习工具（电子词典/错题打印机）
            // ====================== 医疗支出（Healthcare） ======================
            ("DoctorVisit", "Healthcare"), // 门诊挂号费（普通/专家号）
            ("Medications", "Healthcare"), // 药品费用（处方药/非处方药）
            ("Hospitalization", "Healthcare"), // 住院费（床位/手术/护理）
            ("Dental", "Healthcare"),      // 牙科费用（洗牙/补牙/正畸）
            ("PhysicalExamination", "Healthcare"), // 健康体检（常规体检/专项检查）
            ("Vaccination", "Healthcare"), // 疫苗接种（HPV/流感疫苗）
            // ====================== 保险支出（Insurance） ======================
            ("HealthInsurance", "Insurance"), // 健康险（重疾险/医疗险）
            ("CarInsurance", "Insurance"),    // 车险（交强险/商业险）
            ("LifeInsurance", "Insurance"),   // 人寿险（定期寿险/终身寿险）
            ("PropertyInsurance", "Insurance"), // 财产险（房屋险/家财险）
            ("TravelInsurance", "Insurance"), // 旅行险（意外/航班延误）
            ("PetInsurance", "Insurance"),    // 宠物保险（医疗/第三方责任）
            // ====================== 储蓄收入（Savings） ======================
            ("BankInterest", "Savings"),    // 银行活期利息
            ("FixedDeposit", "Savings"),    // 定期存款利息
            ("MoneyMarketFund", "Savings"), // 货币基金收益（余额宝/零钱通）
            ("ShortTermBond", "Savings"),   // 短期债券收益（国债/企业债）
            // ====================== 礼品（Gift） ======================
            ("GiftSent", "Gift"),        // 送出的礼物（节日/生日/慰问）
            ("GiftReceived", "Gift"),    // 收到的礼物（亲友馈赠）
            ("CharityDonation", "Gift"), // 慈善礼品（实物捐赠折现）
            ("CorporateGift", "Gift"),   // 企业礼品（商务礼品/员工福利）
            // ====================== 贷款（Loan） ======================
            ("Mortgage", "Loan"),          // 房贷还款（商业贷款/公积金贷款）
            ("CarLoan", "Loan"),           // 车贷还款（新车/二手车贷款）
            ("PersonalLoan", "Loan"),      // 个人消费贷（装修/旅游贷）
            ("CreditCardPayment", "Loan"), // 信用卡还款（账单全额/最低还款）
            ("OverduePenalty", "Loan"),    // 逾期罚息（贷款/信用卡滞纳金）
            // ====================== 商业支出（Business） ======================
            ("OfficeSupplies", "Business"), // 办公用品（文具/打印纸）
            ("EquipmentPurchase", "Business"), // 设备采购（办公电脑/打印机）
            ("TravelExpenses", "Business"), // 商务差旅（机票/酒店/交通）
            ("Marketing", "Business"),      // 市场营销（广告投放/推广费用）
            ("ConsultingFees", "Business"), // 咨询费（法律/财务/管理咨询）
            // ====================== 出行（Travel） ======================
            ("Hotel", "Travel"),           // 酒店住宿（经济型/豪华酒店）
            ("TourPackage", "Travel"),     // 旅游套餐（跟团游/自由行）
            ("AirTicket", "Travel"),       // 机票（国内/国际航班）
            ("VisaFee", "Travel"),         // 签证费（旅游签/商务签）
            ("TouristGuide", "Travel"),    // 导游服务（景区讲解/私人向导）
            ("TravelSouvenirs", "Travel"), // 旅行纪念品（当地特产/手工艺品）
            // ====================== 慈善捐赠（Charity） ======================
            ("Donation", "Charity"),         // 现金捐赠（线上/线下捐款）
            ("MaterialDonation", "Charity"), // 物资捐赠（衣物/食品/书籍）
            ("ProjectSupport", "Charity"),   // 公益项目资助（教育/环保/救灾）
            // ====================== 订阅服务（Subscription） ======================
            ("Netflix", "Subscription"),       // Netflix 订阅
            ("Spotify", "Subscription"),       // Spotify 订阅
            ("Software", "Subscription"),      // 软件订阅费（Adobe/Canva）
            ("CloudStorage", "Subscription"),  // 云存储服务（iCloud/百度网盘）
            ("KnowledgePaid", "Subscription"), // 知识付费（得到/知乎盐选）
            // ====================== 宠物（Pet） ======================
            ("PetFood", "Pet"),     // 宠物食品（主粮/零食）
            ("PetVet", "Pet"),      // 宠物医疗（看病/疫苗）
            ("PetToys", "Pet"),     // 宠物玩具（磨牙棒/猫爬架）
            ("PetGrooming", "Pet"), // 宠物美容（洗澡/修毛）
            ("PetBoarding", "Pet"), // 宠物寄养（外出托管）
            // ====================== 家居（Home） ======================
            ("Furniture", "Home"),           // 家具（沙发/床/衣柜）
            ("HouseholdAppliances", "Home"), // 家电（冰箱/洗衣机/空调）
            ("DecorItems", "Home"),          // 装饰品（摆件/绿植/挂画）
            ("CleaningTools", "Home"),       // 清洁工具（吸尘器/拖把）
            ("Gardening", "Home"),           // 园艺用品（花盆/肥料/园艺工具）
            // 未覆盖的子分类返回 Others
            ("Other", "Others"),
        ];
        // 使用循环逐行插入数据，避免类型不匹配
        for (name, category_name) in subcategories {
            let insert = Query::insert()
                .into_table(SubCategories::Table)
                .columns([
                    SubCategories::Name,
                    SubCategories::CategoryName,
                    SubCategories::CreatedAt,
                    SubCategories::UpdatedAt,
                ])
                .values_panic([
                    name.into(),
                    category_name.into(),
                    Expr::current_timestamp().into(),
                    Expr::current_timestamp().into(),
                ])
                .to_owned();
            manager.exec_stmt(insert).await?;
        }
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(SubCategories::Table).to_owned())
            .await?;

        Ok(())
    }
}
