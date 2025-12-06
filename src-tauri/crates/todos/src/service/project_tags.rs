use common::{error::MijiResult, utils::date::DateUtils};
use entity::project_tag;
use sea_orm::{
    ActiveValue::Set, ColumnTrait, DbConn, EntityTrait, QueryFilter, QueryOrder, QuerySelect,
    RelationTrait,
};

/// 项目标签服务
#[derive(Debug, Clone, Default)]
pub struct ProjectTagsService;

impl ProjectTagsService {
    /// 为项目添加标签
    pub async fn add_tag(
        &self,
        db: &DbConn,
        project_serial_num: String,
        tag_serial_num: String,
    ) -> MijiResult<()> {
        let now = DateUtils::local_now();

        let new_relation = project_tag::ActiveModel {
            project_serial_num: Set(project_serial_num),
            tag_serial_num: Set(tag_serial_num),
            orders: Set(None),
            created_at: Set(now),
            updated_at: Set(Some(now)),
        };

        project_tag::Entity::insert(new_relation).exec(db).await?;

        Ok(())
    }

    /// 批量为项目添加标签
    pub async fn add_tags_batch(
        &self,
        db: &DbConn,
        project_serial_num: String,
        tag_serial_nums: Vec<String>,
    ) -> MijiResult<()> {
        let now = DateUtils::local_now();

        let relations: Vec<project_tag::ActiveModel> = tag_serial_nums
            .into_iter()
            .map(|tag_serial_num| project_tag::ActiveModel {
                project_serial_num: Set(project_serial_num.clone()),
                tag_serial_num: Set(tag_serial_num),
                orders: Set(None),
                created_at: Set(now),
                updated_at: Set(Some(now)),
            })
            .collect();

        if !relations.is_empty() {
            project_tag::Entity::insert_many(relations).exec(db).await?;
        }

        Ok(())
    }

    /// 删除项目标签
    pub async fn remove_tag(
        &self,
        db: &DbConn,
        project_serial_num: String,
        tag_serial_num: String,
    ) -> MijiResult<()> {
        project_tag::Entity::delete_many()
            .filter(project_tag::Column::ProjectSerialNum.eq(project_serial_num))
            .filter(project_tag::Column::TagSerialNum.eq(tag_serial_num))
            .exec(db)
            .await?;

        Ok(())
    }

    /// 删除项目的所有标签
    pub async fn remove_all_tags(
        &self,
        db: &DbConn,
        project_serial_num: String,
    ) -> MijiResult<u64> {
        let result = project_tag::Entity::delete_many()
            .filter(project_tag::Column::ProjectSerialNum.eq(project_serial_num))
            .exec(db)
            .await?;

        Ok(result.rows_affected)
    }

    /// 获取项目的所有标签
    pub async fn get_project_tags(
        &self,
        db: &DbConn,
        project_serial_num: String,
    ) -> MijiResult<Vec<entity::tag::Model>> {
        use entity::tag;
        use sea_orm::JoinType;

        // 使用 join 查询，通过关联关系，可以控制排序
        let tags = tag::Entity::find()
            .join(JoinType::InnerJoin, tag::Relation::ProjectTag.def())
            .filter(project_tag::Column::ProjectSerialNum.eq(project_serial_num))
            .order_by_asc(project_tag::Column::Orders)
            .all(db)
            .await?;

        Ok(tags)
    }

    /// 更新项目标签（先删除所有，再添加新的）
    pub async fn update_project_tags(
        &self,
        db: &DbConn,
        project_serial_num: String,
        tag_serial_nums: Vec<String>,
    ) -> MijiResult<()> {
        // 删除现有标签
        self.remove_all_tags(db, project_serial_num.clone()).await?;

        // 添加新标签
        if !tag_serial_nums.is_empty() {
            self.add_tags_batch(db, project_serial_num, tag_serial_nums)
                .await?;
        }

        Ok(())
    }
}
