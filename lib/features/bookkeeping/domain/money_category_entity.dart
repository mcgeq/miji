enum MoneyCategoryKind {
  expense('expense', '支出'),
  income('income', '收入');

  const MoneyCategoryKind(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static MoneyCategoryKind fromStorageValue(String value) {
    final normalized = value.toLowerCase();
    return MoneyCategoryKind.values.firstWhere(
      (kind) => kind.storageValue == normalized,
      orElse: () => MoneyCategoryKind.expense,
    );
  }
}

class MoneyCategoryEntity {
  const MoneyCategoryEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.kind,
    required this.color,
    required this.icon,
    required this.isSystem,
    this.isDeleted = false,
    this.deletedAt,
  });

  final String id;
  final String? userId;
  final String name;
  final MoneyCategoryKind kind;
  final String? color;
  final String? icon;
  final bool isSystem;
  final bool isDeleted;
  final DateTime? deletedAt;
}

class MoneySubCategoryEntity {
  const MoneySubCategoryEntity({
    required this.id,
    required this.categoryId,
    required this.userId,
    required this.name,
    required this.kind,
    required this.color,
    required this.icon,
    required this.isSystem,
    this.isDeleted = false,
    this.deletedAt,
  });

  final String id;
  final String categoryId;
  final String? userId;
  final String name;
  final MoneyCategoryKind kind;
  final String? color;
  final String? icon;
  final bool isSystem;
  final bool isDeleted;
  final DateTime? deletedAt;
}

class MoneyCategoryCatalog {
  const MoneyCategoryCatalog({
    required this.categories,
    required this.subCategories,
  });

  const MoneyCategoryCatalog.empty()
    : categories = const <MoneyCategoryEntity>[],
      subCategories = const <MoneySubCategoryEntity>[];

  final List<MoneyCategoryEntity> categories;
  final List<MoneySubCategoryEntity> subCategories;

  List<MoneySubCategoryEntity> subCategoriesFor(String categoryId) {
    return subCategories
        .where((subCategory) => subCategory.categoryId == categoryId)
        .toList();
  }

  MoneyCategoryEntity? categoryById(String? categoryId) {
    if (categoryId == null) {
      return null;
    }

    for (final category in categories) {
      if (category.id == categoryId) {
        return category;
      }
    }
    return null;
  }

  MoneySubCategoryEntity? subCategoryById(String? subCategoryId) {
    if (subCategoryId == null) {
      return null;
    }

    for (final subCategory in subCategories) {
      if (subCategory.id == subCategoryId) {
        return subCategory;
      }
    }
    return null;
  }
}

class MoneyCategorySelection {
  const MoneyCategorySelection({
    required this.category,
    required this.subCategory,
  });

  final MoneyCategoryEntity? category;
  final MoneySubCategoryEntity? subCategory;
}

class MoneyCategoryDraft {
  const MoneyCategoryDraft({
    required this.name,
    required this.kind,
    this.color,
    this.icon,
  });

  final String name;
  final MoneyCategoryKind kind;
  final String? color;
  final String? icon;
}

class MoneyCategoryUpdate {
  const MoneyCategoryUpdate({
    required this.id,
    required this.name,
    this.color,
    this.icon,
  });

  final String id;
  final String name;
  final String? color;
  final String? icon;
}

class MoneySubCategoryDraft {
  const MoneySubCategoryDraft({
    required this.categoryId,
    required this.name,
    required this.kind,
    this.color,
    this.icon,
  });

  final String categoryId;
  final String name;
  final MoneyCategoryKind kind;
  final String? color;
  final String? icon;
}

class MoneySubCategoryUpdate {
  const MoneySubCategoryUpdate({
    required this.id,
    required this.name,
    this.color,
    this.icon,
  });

  final String id;
  final String name;
  final String? color;
  final String? icon;
}
