use crate::schema::SubCategories;
use sea_orm_migration::prelude::*;
use std::collections::HashMap;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 1. 添加 icon 字段（允许 NULL，后续填充）
        let alter_stmt = Table::alter()
            .table(SubCategories::Table)
            .add_column(ColumnDef::new(SubCategories::Icon).string().null())
            .to_owned();
        manager.alter_table(alter_stmt).await?;

        // 2. 定义历史分类名称与图标的映射（根据需求自定义）
        let icon_mappings: HashMap<&str, &str> = [
            ("Restaurant", "🍽️"),
            ("Groceries", "🛒"),
            ("Snacks", "🍰"),
            ("Takeout", "📦"),
            ("CoffeeTea", "☕"),
            ("Alcohol", "🍷"),
            ("CookingIngredients", "🥕"),
            ("DiningVouchers", "🎫"),
            ("FoodDeliveryFee", "📱"),
            ("Bus", "🚌"),
            ("Taxi", "🚖"),
            ("RideShare", "🚗"),
            ("Fuel", "⛽"),
            ("TollBridge", "🛣️"),
            ("Parking", "🅿️"),
            ("ParkingFine", "⚠️"),
            ("Train", "🚄"),
            ("Flight", "✈️"),
            ("Ferry", "⛴️"),
            ("BikeRental", "🚲"),
            ("Movies", "🎬"),
            ("Concerts", "🎤"),
            ("Theater", "🎭"),
            ("Exhibition", "🖼️"),
            ("AmusementPark", "🎠"),
            ("Karaoke", "🎤"),
            ("Gaming", "🎮"),
            ("Streaming", "📺"),
            ("E-sports", "🏆"),
            ("HobbySupplies", "🎨"),
            ("Electricity", "💡"),
            ("Water", "💧"),
            ("Gas", "🔥"),
            ("Internet", "🌐"),
            ("Cable", "📺"),
            ("PropertyManagement", "🏢"),
            ("GarbageDisposal", "🗑️"),
            ("Heating", "🔥"),
            ("SolarPanel", "☀️"),
            ("Clothing", "👕"),
            ("Footwear", "👟"),
            ("Accessories", "💍"),
            ("Electronics", "📱"),
            ("Cosmetics", "💄"),
            ("Jewelry", "💍"),
            ("HouseholdGoods", "🧻"),
            ("Toys", "🧸"),
            ("BooksMagazines", "📚"),
            ("BabyProducts", "👶"),
            ("MonthlySalary", "💵"),
            ("Bonus", "🎉"),
            ("Overtime", "⏰"),
            ("Commission", "📊"),
            ("Allowance", "🎓"),
            ("RetirementPension", "👴"),
            ("PartTimeJob", "👷"),
            ("StockDividend", "📈"),
            ("BondInterest", "📉"),
            ("FundDistribution", "🎁"),
            ("RentalIncome", "🏠"),
            ("CryptoIncome", "🪙"),
            ("Royalties", "©️"),
            ("DividendReinvestment", "🔄"),
            ("AccountTransfer", "↔️"),
            ("LoanRepayment", "📉"),
            ("InvestmentWithdrawal", "💸"),
            ("FriendFamilyTransfer", "❤️"),
            ("PlatformWithdrawal", "📱"),
            ("Tuition", "🏫"),
            ("Textbooks", "📖"),
            ("Courses", "🎓"),
            ("StudyAbroad", "✈️"),
            ("Tutoring", "🏫"),
            ("ExamFees", "📝"),
            ("EducationalTools", "🔬"),
            ("DoctorVisit", "🏥"),
            ("Medications", "💊"),
            ("Hospitalization", "🛌"),
            ("Dental", "👅"),
            ("PhysicalExamination", "🩺"),
            ("Vaccination", "💉"),
            ("HealthInsurance", "🏥"),
            ("CarInsurance", "🚗"),
            ("LifeInsurance", "❤️"),
            ("PropertyInsurance", "🏠"),
            ("TravelInsurance", "✈️"),
            ("PetInsurance", "🐶"),
            ("BankInterest", "💰"),
            ("FixedDeposit", "📅"),
            ("MoneyMarketFund", "🐷"),
            ("ShortTermBond", "📈"),
            ("GiftSent", "🎁"),
            ("GiftReceived", "🎁"),
            ("CharityDonation", "❤️"),
            ("CorporateGift", "🏢"),
            ("Mortgage", "🏠"),
            ("CarLoan", "🚗"),
            ("PersonalLoan", "👤"),
            ("CreditCardPayment", "💳"),
            ("OverduePenalty", "⚠️"),
            ("OfficeSupplies", "📄"),
            ("EquipmentPurchase", "💻"),
            ("TravelExpenses", "✈️"),
            ("Marketing", "📢"),
            ("ConsultingFees", "👨💼"),
            ("Hotel", "🏨"),
            ("TourPackage", "🗺️"),
            ("AirTicket", "✈️"),
            ("VisaFee", "🛂"),
            ("TouristGuide", "🗣️"),
            ("TravelSouvenirs", "🎁"),
            ("Donation", "❤️"),
            ("MaterialDonation", "📦"),
            ("ProjectSupport", "🌱"),
            ("Netflix", "🎬"),
            ("Spotify", "🎵"),
            ("Software", "💻"),
            ("CloudStorage", "☁️"),
            ("KnowledgePaid", "📚"),
            ("PetFood", "🍖"),
            ("PetVet", "🩺"),
            ("PetToys", "🧶"),
            ("PetGrooming", "🛁"),
            ("PetBoarding", "🏠"),
            ("Furniture", "🛋️"),
            ("HouseholdAppliances", "📺"),
            ("DecorItems", "🖼️"),
            ("CleaningTools", "🧹"),
            ("Gardening", "🌻"),
            ("Other", "❓"),
        ]
        .iter()
        .cloned()
        .collect();
        // 3. 批量更新历史数据的 icon 字段
        for (name, icon) in icon_mappings {
            let update_stmt = Query::update()
                .table(SubCategories::Table)
                .value(SubCategories::Icon, Expr::value(icon))
                .and_where(Expr::col(SubCategories::Name).eq(name))
                .to_owned();
            manager.exec_stmt(update_stmt).await?;
        }

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 回滚时删除 icon 字段（谨慎操作，会丢失所有 icon 数据）
        manager
            .alter_table(
                Table::alter()
                    .table(SubCategories::Table)
                    .drop_column(SubCategories::Icon)
                    .to_owned(),
            )
            .await?;
        Ok(())
    }
}
