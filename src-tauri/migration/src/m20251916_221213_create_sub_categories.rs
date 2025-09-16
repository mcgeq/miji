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
            ("Restaurant", "Food"),
            ("Groceries", "Food"),
            ("Snacks", "Food"),
            ("Bus", "Transport"),
            ("Taxi", "Transport"),
            ("Fuel", "Transport"),
            ("Train", "Transport"),
            ("Flight", "Transport"),
            ("Parking", "Transport"),
            ("Movies", "Entertainment"),
            ("Concerts", "Entertainment"),
            ("Sports", "Entertainment"),
            ("Gaming", "Entertainment"),
            ("Streaming", "Entertainment"),
            ("Electricity", "Utilities"),
            ("Water", "Utilities"),
            ("Gas", "Utilities"),
            ("Internet", "Utilities"),
            ("Cable", "Utilities"),
            ("Clothing", "Shopping"),
            ("Electronics", "Shopping"),
            ("HomeDecor", "Shopping"),
            ("Furniture", "Shopping"),
            ("Toys", "Shopping"),
            ("MonthlySalary", "Salary"),
            ("Bonus", "Salary"),
            ("Overtime", "Salary"),
            ("Commission", "Salary"),
            ("StockDividend", "Investment"),
            ("BondInterest", "Investment"),
            ("PropertyRental", "Investment"),
            ("CryptoIncome", "Investment"),
            ("AccountTransfer", "Transfer"),
            ("LoanRepayment", "Transfer"),
            ("InvestmentWithdrawal", "Transfer"),
            ("Tuition", "Education"),
            ("Books", "Education"),
            ("Courses", "Education"),
            ("SchoolSupplies", "Education"),
            ("DoctorVisit", "Healthcare"),
            ("Medications", "Healthcare"),
            ("Hospitalization", "Healthcare"),
            ("Dental", "Healthcare"),
            ("InsurancePremiums", "Healthcare"),
            ("HealthInsurance", "Insurance"),
            ("CarInsurance", "Insurance"),
            ("LifeInsurance", "Insurance"),
            ("BankInterest", "Savings"),
            ("FixedDeposit", "Savings"),
            ("GiftSent", "Gift"),
            ("GiftReceived", "Gift"),
            ("Mortgage", "Loan"),
            ("PersonalLoan", "Loan"),
            ("CreditCardPayment", "Loan"),
            ("OfficeSupplies", "Business"),
            ("TravelExpenses", "Business"),
            ("Marketing", "Business"),
            ("ConsultingFees", "Business"),
            ("Hotel", "Travel"),
            ("TourPackage", "Travel"),
            ("Activities", "Travel"),
            ("Donation", "Charity"),
            ("Netflix", "Subscription"),
            ("Spotify", "Subscription"),
            ("Software", "Subscription"),
            ("PetFood", "Pet"),
            ("PetVet", "Pet"),
            ("PetToys", "Pet"),
            ("Furniture", "Home"),
            ("Renovation", "Home"),
            ("HomeMaintenance", "Home"),
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
