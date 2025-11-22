use sea_orm_migration::prelude::*;

use crate::schema::{Categories, SubCategories};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 sub_categories 表（包含 icon 字段）
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
                    .col(ColumnDef::new(SubCategories::Icon).string().null())
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
                    .to_owned(),
            )
            .await?;

        // 创建索引
        manager
            .create_index(
                Index::create()
                    .name("idx_subcategories_category_name")
                    .table(SubCategories::Table)
                    .col(SubCategories::CategoryName)
                    .col(SubCategories::Name)
                    .unique()
                    .to_owned(),
            )
            .await?;

        // 定义所有子分类及其图标（name, category, icon）
        let subcategories: Vec<(&str, &str, &str)> = vec![
            // ====================== 餐饮（Food） ======================
            ("Restaurant", "Food", "🍽️"),
            ("Groceries", "Food", "🛒"),
            ("Snacks", "Food", "🍰"),
            ("Takeout", "Food", "📦"),
            ("CoffeeTea", "Food", "☕"),
            ("Alcohol", "Food", "🍷"),
            ("CookingIngredients", "Food", "🥕"),
            ("DiningVouchers", "Food", "🎫"),
            ("FoodDeliveryFee", "Food", "📱"),
            // ====================== 交通（Transport） ======================
            ("Bus", "Transport", "🚌"),
            ("Taxi", "Transport", "🚖"),
            ("RideShare", "Transport", "🚗"),
            ("Fuel", "Transport", "⛽"),
            ("TollBridge", "Transport", "🛣️"),
            ("Parking", "Transport", "🅿️"),
            ("ParkingFine", "Transport", "⚠️"),
            ("Train", "Transport", "🚄"),
            ("Flight", "Transport", "✈️"),
            ("Ferry", "Transport", "⛴️"),
            ("BikeRental", "Transport", "🚲"),
            // ====================== 娱乐（Entertainment） ======================
            ("Movies", "Entertainment", "🎬"),
            ("Concerts", "Entertainment", "🎤"),
            ("Theater", "Entertainment", "🎭"),
            ("Exhibition", "Entertainment", "🖼️"),
            ("AmusementPark", "Entertainment", "🎠"),
            ("Karaoke", "Entertainment", "🎤"),
            ("Gaming", "Entertainment", "🎮"),
            ("Streaming", "Entertainment", "📺"),
            ("E-sports", "Entertainment", "🏆"),
            ("HobbySupplies", "Entertainment", "🎨"),
            // ====================== 公共事业（Utilities） ======================
            ("Electricity", "Utilities", "💡"),
            ("Water", "Utilities", "💧"),
            ("Gas", "Utilities", "🔥"),
            ("Internet", "Utilities", "🌐"),
            ("Cable", "Utilities", "📺"),
            ("PropertyManagement", "Utilities", "🏢"),
            ("GarbageDisposal", "Utilities", "🗑️"),
            ("Heating", "Utilities", "🔥"),
            ("SolarPanel", "Utilities", "☀️"),
            ("PhoneBill", "Utilities", "📞"),
            ("PropertyRental", "Utilities", "🏡"),
            // ====================== 购物（Shopping） ======================
            ("Clothing", "Shopping", "👕"),
            ("Footwear", "Shopping", "👟"),
            ("Accessories", "Shopping", "💍"),
            ("Electronics", "Shopping", "📱"),
            ("Cosmetics", "Shopping", "💄"),
            ("Jewelry", "Shopping", "💍"),
            ("HouseholdGoods", "Shopping", "🧻"),
            ("Toys", "Shopping", "🧸"),
            ("BooksMagazines", "Shopping", "📚"),
            ("BabyProducts", "Shopping", "👶"),
            // ====================== 工资收入（Salary） ======================
            ("MonthlySalary", "Salary", "💵"),
            ("Bonus", "Salary", "🎉"),
            ("Overtime", "Salary", "⏰"),
            ("Commission", "Salary", "📊"),
            ("Allowance", "Salary", "🎓"),
            ("RetirementPension", "Salary", "👴"),
            ("PartTimeJob", "Salary", "👷"),
            // ====================== 投资收入（Investment） ======================
            ("StockDividend", "Investment", "📈"),
            ("BondInterest", "Investment", "📉"),
            ("FundDistribution", "Investment", "🎁"),
            ("RentalIncome", "Investment", "🏠"),
            ("CryptoIncome", "Investment", "🪙"),
            ("Royalties", "Investment", "©️"),
            ("DividendReinvestment", "Investment", "🔄"),
            // ====================== 资金转账（Transfer） ======================
            ("AccountTransfer", "Transfer", "↔️"),
            ("LoanRepayment", "Transfer", "📉"),
            ("InvestmentWithdrawal", "Transfer", "💸"),
            ("FriendFamilyTransfer", "Transfer", "❤️"),
            ("PlatformWithdrawal", "Transfer", "📱"),
            ("CreditCardRepayment", "Transfer", "💳"),
            // ====================== 教育支出（Education） ======================
            ("Tuition", "Education", "🏫"),
            ("Textbooks", "Education", "📖"),
            ("Courses", "Education", "🎓"),
            ("StudyAbroad", "Education", "✈️"),
            ("Tutoring", "Education", "🏫"),
            ("ExamFees", "Education", "📝"),
            ("EducationalTools", "Education", "🔬"),
            // ====================== 医疗支出（Healthcare） ======================
            ("DoctorVisit", "Healthcare", "🏥"),
            ("Medications", "Healthcare", "💊"),
            ("Hospitalization", "Healthcare", "🛌"),
            ("Dental", "Healthcare", "👅"),
            ("PhysicalExamination", "Healthcare", "🩺"),
            ("Vaccination", "Healthcare", "💉"),
            // ====================== 保险支出（Insurance） ======================
            ("HealthInsurance", "Insurance", "🏥"),
            ("CarInsurance", "Insurance", "🚗"),
            ("LifeInsurance", "Insurance", "❤️"),
            ("PropertyInsurance", "Insurance", "🏠"),
            ("TravelInsurance", "Insurance", "✈️"),
            ("PetInsurance", "Insurance", "🐶"),
            // ====================== 储蓄收入（Savings） ======================
            ("BankInterest", "Savings", "💰"),
            ("FixedDeposit", "Savings", "📅"),
            ("MoneyMarketFund", "Savings", "🐷"),
            ("ShortTermBond", "Savings", "📈"),
            // ====================== 礼品（Gift） ======================
            ("GiftSent", "Gift", "🎁"),
            ("GiftReceived", "Gift", "🎁"),
            ("CharityDonation", "Gift", "❤️"),
            ("CorporateGift", "Gift", "🏢"),
            // ====================== 贷款（Loan） ======================
            ("Mortgage", "Loan", "🏠"),
            ("CarLoan", "Loan", "🚗"),
            ("PersonalLoan", "Loan", "👤"),
            ("CreditCardPayment", "Loan", "💳"),
            ("OverduePenalty", "Loan", "⚠️"),
            // ====================== 商业支出（Business） ======================
            ("OfficeSupplies", "Business", "📄"),
            ("EquipmentPurchase", "Business", "💻"),
            ("TravelExpenses", "Business", "✈️"),
            ("Marketing", "Business", "📢"),
            ("ConsultingFees", "Business", "👨💼"),
            // ====================== 出行（Travel） ======================
            ("Hotel", "Travel", "🏨"),
            ("TourPackage", "Travel", "🗺️"),
            ("AirTicket", "Travel", "✈️"),
            ("VisaFee", "Travel", "🛂"),
            ("TouristGuide", "Travel", "🗣️"),
            ("TravelSouvenirs", "Travel", "🎁"),
            // ====================== 慈善捐赠（Charity） ======================
            ("Donation", "Charity", "❤️"),
            ("MaterialDonation", "Charity", "📦"),
            ("ProjectSupport", "Charity", "🌱"),
            // ====================== 订阅服务（Subscription） ======================
            ("Netflix", "Subscription", "🎬"),
            ("Spotify", "Subscription", "🎵"),
            ("Software", "Subscription", "💻"),
            ("CloudStorage", "Subscription", "☁️"),
            ("KnowledgePaid", "Subscription", "📚"),
            // ====================== 宠物（Pet） ======================
            ("PetFood", "Pet", "🍖"),
            ("PetVet", "Pet", "🩺"),
            ("PetToys", "Pet", "🧶"),
            ("PetGrooming", "Pet", "🛁"),
            ("PetBoarding", "Pet", "🏠"),
            // ====================== 家居（Home） ======================
            ("Furniture", "Home", "🛋️"),
            ("HouseholdAppliances", "Home", "📺"),
            ("DecorItems", "Home", "🖼️"),
            ("CleaningTools", "Home", "🧹"),
            ("Gardening", "Home", "🌻"),
            // ====================== 其他（Others） ======================
            ("Other", "Others", "❓"),
        ];

        // 插入初始数据
        for (name, category_name, icon) in subcategories {
            let insert = Query::insert()
                .into_table(SubCategories::Table)
                .columns([
                    SubCategories::Name,
                    SubCategories::CategoryName,
                    SubCategories::Icon,
                    SubCategories::CreatedAt,
                    SubCategories::UpdatedAt,
                ])
                .values_panic([
                    name.into(),
                    category_name.into(),
                    icon.into(),
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
            .drop_index(
                Index::drop()
                    .name("idx_subcategories_category_name")
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(Table::drop().table(SubCategories::Table).to_owned())
            .await?;

        Ok(())
    }
}
