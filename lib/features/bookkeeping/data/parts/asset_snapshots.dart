part of 'package:miji/features/bookkeeping/data/drift_money_repository.dart';

mixin _AssetSnapshots on _DriftMoneyRepositoryBase {
  static const _liabilityTypes = <String>{
    'credit_card',
    'huabei',
    'baitiao',
    'meituan_credit',
    'other_credit',
  };

  @override
  Future<void> captureAssetSnapshotsForUser(String userId) async {
    try {
      await ensureReadyForUser(userId);

      final accounts =
          await (database.select(database.moneyAccounts)..where(
                (account) =>
                    account.userId.equals(userId) &
                    account.isActive.equals(true) &
                    account.isVirtual.equals(false) &
                    account.isDeleted.equals(false),
              ))
              .get();

      final today = _dateKey(_utcNow());
      final now = _utcNow();

      for (final account in accounts) {
        final existing =
            await (database.select(database.moneyAssetSnapshots)..where(
                  (snap) =>
                      snap.userId.equals(userId) &
                      snap.accountId.equals(account.id) &
                      snap.capturedDate.equals(today),
                ))
                .getSingleOrNull();

        if (existing != null) continue; // Already captured today

        await database
            .into(database.moneyAssetSnapshots)
            .insert(
              MoneyAssetSnapshotsCompanion.insert(
                id: _uuid.v4(),
                userId: userId,
                accountId: account.id,
                balanceMinor: account.balanceMinor,
                currencyCode: account.currencyCode,
                capturedDate: today,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    } catch (error) {
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<void> refreshAssetSnapshotsForUser(String userId) async {
    try {
      await ensureReadyForUser(userId);

      final accounts =
          await (database.select(database.moneyAccounts)..where(
                (account) =>
                    account.userId.equals(userId) &
                    account.isActive.equals(true) &
                    account.isVirtual.equals(false) &
                    account.isDeleted.equals(false),
              ))
              .get();

      final today = _dateKey(_utcNow());
      final now = _utcNow();

      for (final account in accounts) {
        final existing =
            await (database.select(database.moneyAssetSnapshots)..where(
                  (snap) =>
                      snap.userId.equals(userId) &
                      snap.accountId.equals(account.id) &
                      snap.capturedDate.equals(today),
                ))
                .getSingleOrNull();

        if (existing != null) {
          await (database.update(
            database.moneyAssetSnapshots,
          )..where((snap) => snap.id.equals(existing.id))).write(
            MoneyAssetSnapshotsCompanion(
              balanceMinor: Value(account.balanceMinor),
              updatedAt: Value(now),
            ),
          );
        } else {
          await database
              .into(database.moneyAssetSnapshots)
              .insert(
                MoneyAssetSnapshotsCompanion.insert(
                  id: _uuid.v4(),
                  userId: userId,
                  accountId: account.id,
                  balanceMinor: account.balanceMinor,
                  currencyCode: account.currencyCode,
                  capturedDate: today,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
      }
    } catch (error) {
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<List<MoneyNetWorthTrendPoint>> getNetWorthTrendForUser(
    String userId, {
    int days = 90,
  }) async {
    try {
      await ensureReadyForUser(userId);

      final cutoffDate = _dateKey(_utcNow().subtract(Duration(days: days)));

      final snapshots =
          await (database.select(database.moneyAssetSnapshots)
                ..where(
                  (snap) =>
                      snap.userId.equals(userId) &
                      snap.capturedDate.isBiggerOrEqualValue(cutoffDate) &
                      snap.isDeleted.equals(false),
                )
                ..orderBy([(snap) => OrderingTerm.asc(snap.capturedDate)]))
              .get();

      // Join with accounts to classify asset vs liability
      final accounts =
          await (database.select(database.moneyAccounts)..where(
                (account) =>
                    account.userId.equals(userId) &
                    account.isDeleted.equals(false),
              ))
              .get();
      final accountTypeMap = {for (final a in accounts) a.id: a.type};

      // Group by capturedDate
      final dateMap = <int, _DateTotals>{};
      for (final snap in snapshots) {
        final totals = dateMap.putIfAbsent(
          snap.capturedDate,
          () => _DateTotals(),
        );
        final accountType = accountTypeMap[snap.accountId];
        final isLiability =
            accountType != null && _liabilityTypes.contains(accountType);
        if (isLiability) {
          totals.liabilityMinor += snap.balanceMinor;
        } else {
          totals.assetMinor += snap.balanceMinor;
        }
      }

      // Also include today's live data for the latest point
      final today = _dateKey(_utcNow());
      final liveAccounts =
          await (database.select(database.moneyAccounts)..where(
                (account) =>
                    account.userId.equals(userId) &
                    account.isActive.equals(true) &
                    account.isVirtual.equals(false) &
                    account.isDeleted.equals(false),
              ))
              .get();

      final liveTotals = dateMap.putIfAbsent(today, () => _DateTotals());
      for (final account in liveAccounts) {
        final isLiability = _liabilityTypes.contains(account.type);
        if (isLiability) {
          liveTotals.liabilityMinor += account.balanceMinor;
        } else {
          liveTotals.assetMinor += account.balanceMinor;
        }
      }

      // Convert to trend points
      final points = dateMap.entries
          .map(
            (e) => MoneyNetWorthTrendPoint(
              date: _dateFromKey(e.key),
              assetMinor: e.value.assetMinor,
              liabilityMinor: e.value.liabilityMinor,
            ),
          )
          .toList();
      points.sort((a, b) => a.date.compareTo(b.date));

      return points;
    } catch (error) {
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }
}

class _DateTotals {
  int assetMinor = 0;
  int liabilityMinor = 0;
}
