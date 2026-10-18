import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/sync/delta_sync/delta_package_models.dart';
import 'package:miji/core/sync/delta_sync/delta_package_store.dart';
import 'package:miji/core/sync/delta_sync/delta_sync_service.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/core/sync/webdav/webdav_models.dart';
import 'package:miji/features/life_energy/data/life_energy_remote_apply.dart';
import 'package:miji/features/life_energy/data/life_energy_repository.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';

/// 「换一台设备还能看到」这件事，只有真的跑一遍才能证明。
///
/// 两台内存库 + 一个共享的假 package store：A 写 → 上传；B 拉取 → 落地。
/// 这里跑的是**完整链路**（日志 → 打包 → 下载 → 版本比对 → apply），
/// 任何一环没接好，断言就会挂。
void main() {
  late AppDatabase deviceA;
  late AppDatabase deviceB;
  late _SharedPackageStore store;
  final now = DateTime.utc(2026, 10, 18, 9);

  setUp(() async {
    deviceA = AppDatabase(NativeDatabase.memory());
    deviceB = AppDatabase(NativeDatabase.memory());
    store = _SharedPackageStore();
    for (final db in [deviceA, deviceB]) {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: 'user-1',
              username: 'demo',
              email: 'demo@example.com',
              displayName: 'Demo',
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  });

  tearDown(() async {
    await deviceA.close();
    await deviceB.close();
  });

  var changeCounter = 0;

  LifeEnergyRepository repositoryOf(AppDatabase db, String deviceId) {
    return LifeEnergyRepository(
      db,
      now: () => now,
      syncLogger: SyncChangeLogger(
        database: db,
        identityResolver: FixedSyncIdentityResolver(
          SyncIdentity(deviceId: deviceId, datasetId: 'dataset-a'),
        ),
        // 自增而不是时间戳：同一微秒内连写两条会撞主键。
        createId: () => '$deviceId-${changeCounter += 1}',
        now: () => now,
      ),
    );
  }

  DeltaSyncService serviceOf(AppDatabase db, String deviceId) {
    return DeltaSyncService(
      database: db,
      identityResolver: FixedSyncIdentityResolver(
        SyncIdentity(deviceId: deviceId, datasetId: 'dataset-a'),
      ),
      packageStore: store,
      readConfig: () async => _config,
      applyRemoteChange: db.applyRemoteLifeEnergyChange,
      now: () => now.add(Duration(microseconds: store.packageCount)),
    );
  }

  test('A 写的档案 / 段 / 年终奖 / 想买 / 加班，B 拉一次就都有', () async {
    final a = repositoryOf(deviceA, 'device-a');
    await a.saveProfile(
      const WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1300000,
        workDaysPerMonth: 21,
        workMinutesPerDay: 470,
        commuteMinutesPerDay: 80,
        costTransportMinor: 50000,
      ),
    );
    final segmentId = await a.createSalarySegment(
      userId: 'user-1',
      effectiveYear: 2025,
      effectiveMonth: 7,
      amountMinor: 1600000,
      grossAmountMinor: 2000000,
    );
    await a.saveBonus(
      userId: 'user-1',
      taxYear: 2026,
      amountMinor: 4500000,
      sourceLabel: '云图科技',
    );
    await a.createWishlistEntry(
      userId: 'user-1',
      title: '降噪耳机',
      targetAmountMinor: 129900,
      cooldownUntil: now.add(const Duration(days: 7)),
    );
    await a.createOvertimeEntry(userId: 'user-1', workDate: now, minutes: 120);

    final upload = await serviceOf(deviceA, 'device-a').syncNow('pw');
    expect(upload.uploadedPackages, 1);
    expect(upload.uploadedChanges, greaterThanOrEqualTo(5));

    // B 拉取：拿到的每一条都要真的落库（不然 appliedRemoteChanges 是空话）。
    final pull = await serviceOf(deviceB, 'device-b').syncNow('pw');
    expect(pull.appliedRemoteChanges, greaterThanOrEqualTo(5));
    expect(pull.remoteConflicts, 0);

    final b = LifeEnergyRepository(deviceB);
    final profile = await b.fetchProfile('user-1');
    expect(profile, isNotNull);
    expect(profile!.payAmountMinor, 1300000);
    expect(profile.workDaysPerMonth, 21);
    expect(profile.commuteMinutesPerDay, 80);

    final segments = await b.fetchSalarySegments('user-1');
    expect(segments.map((s) => s.id), contains(segmentId));
    // 按 id 找：saveProfile 还会补一条「当前段」，`.last` 拿到的是那一条。
    final segment = segments.firstWhere((s) => s.id == segmentId);
    expect(segment.effectiveMonth, 7);
    expect(segment.grossAmountMinor, 2000000);

    final bonuses = await b.fetchBonuses('user-1');
    expect(bonuses.single.taxYear, 2026);
    expect(bonuses.single.amountMinor, 4500000);
    expect(bonuses.single.sourceLabel, '云图科技');

    expect(
      (await b.watchWishlist(userId: 'user-1').first).single.title,
      '降噪耳机',
    );
    expect(
      (await b
              .watchOvertimeEntries(
                userId: 'user-1',
                monthStart: DateTime.utc(2026, 10),
              )
              .first)
          .single
          .minutes,
      120,
    );
  });

  test('再拉一次不会重复写：cursor 前进之后同一包不再应用', () async {
    final a = repositoryOf(deviceA, 'device-a');
    await a.saveProfile(
      const WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1200000,
        workDaysPerMonth: 22,
        workMinutesPerDay: 480,
      ),
    );
    await serviceOf(deviceA, 'device-a').syncNow('pw');

    final firstPull = await serviceOf(deviceB, 'device-b').syncNow('pw');
    expect(firstPull.appliedRemoteChanges, greaterThan(0));

    final secondPull = await serviceOf(deviceB, 'device-b').syncNow('pw');
    expect(secondPull.downloadedPackages, 0);
    expect(secondPull.appliedRemoteChanges, 0);

    final b = LifeEnergyRepository(deviceB);
    final profile = await b.fetchProfile('user-1');
    expect(profile!.payAmountMinor, 1200000);
    final rows = await deviceB.select(deviceB.lifeEnergyProfiles).get();
    expect(rows, hasLength(1));
  });

  test('A 删掉的清单项，B 拉下来也消失（软删同步）', () async {
    final a = repositoryOf(deviceA, 'device-a');
    await a.saveProfile(
      const WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1200000,
        workDaysPerMonth: 22,
        workMinutesPerDay: 480,
      ),
    );
    final wishId = await a.createWishlistEntry(
      userId: 'user-1',
      title: '降噪耳机',
      targetAmountMinor: 129900,
    );
    await serviceOf(deviceA, 'device-a').syncNow('pw');
    await serviceOf(deviceB, 'device-b').syncNow('pw');

    final b = LifeEnergyRepository(deviceB);
    expect(await b.watchWishlist(userId: 'user-1').first, hasLength(1));

    await a.deleteWishlistEntry('user-1', wishId);
    await serviceOf(deviceA, 'device-a').syncNow('pw');
    await serviceOf(deviceB, 'device-b').syncNow('pw');

    expect(await b.watchWishlist(userId: 'user-1').first, isEmpty);
    // 行还在（软删），只是不再出现在列表里。
    final rows = await deviceB.select(deviceB.wishlistItems).get();
    expect(rows.single.isDeleted, isTrue);
  });
}

const _config = WebDavConfig(
  providerType: WebDavProviderType.custom,
  endpointUrl: 'https://example.com/dav/',
  username: 'user',
  password: 'pass',
  remoteDirectory: '.miji/snapshots',
);

/// 两台设备共享的「远端」。
class _SharedPackageStore implements DeltaPackageStore {
  final List<DeltaPackage> _packages = <DeltaPackage>[];

  int get packageCount => _packages.length;

  @override
  Future<DeltaRemotePackageInfo> upload({
    required WebDavConfig config,
    required String password,
    required DeltaPackage package,
  }) async {
    _packages.add(package);
    return _infoFor(package);
  }

  @override
  Future<List<DeltaRemotePackageInfo>> listPackages({
    required WebDavConfig config,
    required String datasetId,
    required String deviceId,
  }) async {
    return _packages
        .where(
          (package) =>
              package.metadata.datasetId == datasetId &&
              package.metadata.deviceId == deviceId,
        )
        .map(_infoFor)
        .toList();
  }

  @override
  Future<List<DeltaRemotePackageInfo>> listRemotePackages({
    required WebDavConfig config,
    required String datasetId,
    required String localDeviceId,
  }) async {
    return _packages
        .where(
          (package) =>
              package.metadata.datasetId == datasetId &&
              package.metadata.deviceId != localDeviceId,
        )
        .map(_infoFor)
        .toList();
  }

  @override
  Future<DeltaPackage> download({
    required WebDavConfig config,
    required String password,
    required DeltaRemotePackageInfo remotePackage,
  }) async {
    return _packages.firstWhere(
      (package) =>
          package.metadata.deviceId == remotePackage.deviceId &&
          package.metadata.sequence == remotePackage.sequence,
    );
  }

  DeltaRemotePackageInfo _infoFor(DeltaPackage package) {
    return DeltaRemotePackageInfo(
      file: WebDavRemoteFileInfo(
        fileName:
            '${package.metadata.deviceId}-${package.metadata.sequence}.json',
        url: Uri.parse('https://example.com/dav/pkg'),
        sizeBytes: 1,
        updatedAt: package.metadata.createdAt,
      ),
      datasetId: package.metadata.datasetId,
      deviceId: package.metadata.deviceId,
      sequence: package.metadata.sequence,
    );
  }
}
