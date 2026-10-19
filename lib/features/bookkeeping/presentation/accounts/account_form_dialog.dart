import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/attachments/attachment_providers.dart';
import 'package:miji/core/attachments/attachment_store.dart';
import 'package:miji/core/presentation/app_color_utils.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_color_picker.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_currency_codes.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_icon_catalog.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_presentation_helpers.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/components/account_card_background.dart';

class AccountFormResult {
  const AccountFormResult.create(this.draft) : update = null;

  const AccountFormResult.update(this.update) : draft = null;

  final MoneyAccountDraft? draft;
  final MoneyAccountUpdate? update;
}

/// 背景色预设：比「标识色」更柔的梯度 —— 背景要大面积铺色，
/// 饱和度压低一档才不压内容；深浅两端都配好了可读的前景色。
const _backgroundPickerSections = <AppColorPickerSection>[
  AppColorPickerSection(
    label: '浅色',
    colors: ['#BAE6FD', '#BBF7D0', '#FDE68A', '#FBCFE8', '#DDD6FE', '#E2E8F0'],
  ),
  AppColorPickerSection(
    label: '中等',
    colors: ['#7DD3FC', '#86EFAC', '#FCD34D', '#F9A8D4', '#C4B5FD', '#CBD5E1'],
  ),
  AppColorPickerSection(
    label: '深色',
    colors: ['#0284C7', '#16A34A', '#D97706', '#DB2777', '#7C3AED', '#475569'],
  ),
];

const _defaultBackgroundColor = '#BAE6FD';

class AccountFormDialog extends ConsumerStatefulWidget {
  const AccountFormDialog({
    super.key,
    this.account,
    this.defaultCurrencyCode,
    this.initialType,
  });

  final MoneyAccountEntity? account;
  final String? defaultCurrencyCode;

  /// 新建时的初始账户类型（例如从「分期」空态直接新建信用账户）。
  final MoneyAccountType? initialType;

  @override
  ConsumerState<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends ConsumerState<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _initialBalanceController;
  late MoneyAccountType _type;
  late String _currencyCode;
  late String _selectedColor;
  late String _selectedIcon;
  late MoneyAccountBackgroundStyle _backgroundStyle;
  String? _backgroundColor;
  String? _backgroundImage;
  late int _statementDay;
  late int _budgetCycleStartDay;
  late int _repaymentDay;
  late bool _autoRepaymentReminderEnabled;

  /// 本次会话里收编进附件目录的背景图。表单确认后只保留提交的那张，
  /// 其余（含中途换掉的）在 dispose 时清掉，不留孤儿文件。
  final List<String> _sessionImportedBackgrounds = <String>[];

  /// 确认提交时最终生效的背景图；null 表示不保留任何本次新收编的文件。
  String? _committedBackgroundImage;

  /// 同上，自定义图标图片的会话收编清单。
  final List<String> _sessionImportedIcons = <String>[];

  /// 确认提交时最终生效的自定义图标（相对路径）；null 表示不保留。
  String? _committedCustomIcon;

  bool _isImportingImage = false;
  FToast? _toast;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _nameController = TextEditingController(text: account?.name ?? '');
    _descriptionController = TextEditingController(
      text: account?.description ?? '',
    );
    _initialBalanceController = TextEditingController(
      text: account == null
          ? '0'
          : ((account.type.isCreditLike
                        ? account.effectiveCreditLimitMinor
                        : account.initialBalanceMinor) /
                    100)
                .toStringAsFixed(2),
    );
    _type = account?.type == MoneyAccountType.internal
        ? MoneyAccountType.cash
        : account?.type ?? widget.initialType ?? MoneyAccountType.cash;
    _currencyCode = account?.currencyCode ?? _normalizedDefaultCurrencyCode;
    _selectedColor = account?.color ?? defaultAccountColorForType(_type);
    _selectedIcon = account?.icon ?? defaultAccountIconForType(_type);
    _backgroundStyle =
        account?.resolvedBackgroundStyle ??
        MoneyAccountBackgroundStyle.defaultStyle;
    _backgroundColor = account?.backgroundColor;
    _backgroundImage = account?.backgroundImage;
    _statementDay = account?.statementDay ?? 1;
    _budgetCycleStartDay =
        account?.budgetCycleStartDay ?? account?.statementDay ?? 1;
    _repaymentDay = account?.repaymentDay ?? 10;
    _autoRepaymentReminderEnabled =
        account?.autoRepaymentReminderEnabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _initialBalanceController.dispose();
    _cleanupSessionBackgrounds();
    _cleanupSessionIcons();
    super.dispose();
  }

  /// 清掉本次会话收编、但最终没有提交的背景图文件。
  ///
  /// 确认路径之外的全部删除（幂等）；账户原有的背景图不在这里动 ——
  /// 更新是否成功由调用方决定，旧文件留给仓库层/维护任务处理。
  void _cleanupSessionBackgrounds() {
    final store = AttachmentStore();
    for (final path in _sessionImportedBackgrounds) {
      if (path == _committedBackgroundImage) {
        continue;
      }
      // fire-and-forget：dispose 里不能 await，删除失败只是留下一个孤儿
      // 文件，不影响任何功能。
      store.deleteStored(path).catchError((_) {});
    }
  }

  /// 同 [_cleanupSessionBackgrounds]，清理的是自定义图标图片。
  void _cleanupSessionIcons() {
    final store = AttachmentStore();
    for (final path in _sessionImportedIcons) {
      if (path == _committedCustomIcon) {
        continue;
      }
      store.deleteStored(path).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogScaffold(
      title: _isEditing ? '编辑账户' : '新增账户',
      maxWidth: 440,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: Form(
        key: _formKey,
        child: AppFormColumn(
          children: [
            _AccountAppearancePreview(
              name: _nameController.text,
              type: _type,
              currencyCode: _currencyCode,
              color: _selectedColor,
              icon: _selectedIcon,
              backgroundStyle: _backgroundStyle,
              backgroundColor: _backgroundColor,
              backgroundImage: _backgroundImage,
            ),
            AppTextFormField(
              controller: _nameController,
              autofocus: !_isEditing,
              textInputAction: TextInputAction.next,
              labelText: '账户名称',
              prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
              validator: _validateName,
              onChanged: (_) => setState(() {}),
            ),
            FormDropdown<MoneyAccountType>(
              initialSelection: _type,
              label: '账户类型',
              width: double.infinity,
              leadingIcon: const Icon(Icons.category_rounded),
              onSelected: (value) {
                if (value == null) return;
                setState(() {
                  final previousType = _type;
                  final shouldUseTypeColor =
                      _selectedColor ==
                      defaultAccountColorForType(previousType);
                  if (shouldUseTypeColor) {
                    _selectedColor = defaultAccountColorForType(value);
                  }
                  if (!previousType.isCreditLike && value.isCreditLike) {
                    _budgetCycleStartDay = _statementDay;
                  }
                  _type = value;
                });
              },
              entries: visibleMoneyAccountTypes
                  .map(
                    (type) => DropdownMenuEntry(
                      value: type,
                      leadingIcon: Icon(accountIconDataForType(type), size: 18),
                      label: type.label,
                    ),
                  )
                  .toList(),
            ),
            AppAmountField(
              controller: _initialBalanceController,
              labelText: _balanceFieldLabel,
              currencyCode: _currencyCode,
              helperText: _balanceFieldHelperText,
              textInputAction: TextInputAction.next,
              validator: _validateAmount,
            ),
            if (_type.isCreditLike) ...[
              _buildBillingCycleFields(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _autoRepaymentReminderEnabled,
                onChanged: (value) {
                  setState(() => _autoRepaymentReminderEnabled = value);
                },
                title: const Text('自动还款提醒'),
                subtitle: const Text('根据还款日每月提醒，欠款为 0 时不弹系统通知'),
              ),
            ],
            AppTextFormField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 3,
              labelText: '备注',
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
            _AccountIconPickerField(
              selectedIcon: _selectedIcon,
              fallbackType: _type,
              fallbackColor: _selectedColor,
              isBusy: _isImportingImage,
              onSelected: (name) => setState(() => _selectedIcon = name),
              onPickCustom: _pickCustomIcon,
            ),
            _buildBackgroundSection(),
            AppColorPickerField(
              title: '标识颜色',
              selectedColor: _selectedColor,
              onSelected: (color) {
                setState(() => _selectedColor = color);
              },
            ),
          ],
        ),
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        confirmTooltip: _isEditing ? '保存' : '创建',
      ),
    );
  }

  /// 「卡片背景」分组：样式三选 + 按样式展开的颜色 / 图片选择。
  Widget _buildBackgroundSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSlidingSegmentedControl<MoneyAccountBackgroundStyle>(
          value: _backgroundStyle,
          onChanged: (style) {
            setState(() {
              _backgroundStyle = style;
              if (style == MoneyAccountBackgroundStyle.color &&
                  _backgroundColor == null) {
                _backgroundColor = _defaultBackgroundColor;
              }
            });
          },
          segments: const [
            AppSlidingSegment(
              value: MoneyAccountBackgroundStyle.defaultStyle,
              label: '默认',
              icon: Icons.style_rounded,
            ),
            AppSlidingSegment(
              value: MoneyAccountBackgroundStyle.color,
              label: '纯色',
              icon: Icons.format_color_fill_rounded,
            ),
            AppSlidingSegment(
              value: MoneyAccountBackgroundStyle.image,
              label: '图片',
              icon: Icons.image_rounded,
            ),
          ],
        ),
        if (_backgroundStyle == MoneyAccountBackgroundStyle.color)
          AppColorPickerField(
            title: '卡片背景色',
            selectedColor: _backgroundColor ?? _defaultBackgroundColor,
            sections: _backgroundPickerSections,
            onSelected: (color) {
              setState(() => _backgroundColor = color);
            },
          ),
        if (_backgroundStyle == MoneyAccountBackgroundStyle.image) ...[
          _BackgroundImageField(
            storedPath: _backgroundImage,
            isBusy: _isImportingImage,
            onPick: _pickBackgroundImage,
            onRemove: () => setState(() => _backgroundImage = null),
          ),
          Text(
            '背景图仅保存在本设备，不会同步到其他端',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickBackgroundImage() async {
    if (_isImportingImage) {
      return;
    }
    setState(() => _isImportingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null || !mounted) {
        return;
      }
      final session = ref.read(authSessionControllerProvider);
      final userId = session.userId;
      if (userId == null) {
        _showErrorToast('登录状态失效，请重新进入');
        return;
      }

      final relativePath = await ref
          .read(attachmentStoreProvider)
          .importFile(userId: userId, sourcePath: picked.path);
      _sessionImportedBackgrounds.add(relativePath);
      if (!mounted) {
        return;
      }
      setState(() {
        _backgroundImage = relativePath;
        _backgroundStyle = MoneyAccountBackgroundStyle.image;
      });
    } catch (_) {
      if (mounted) {
        _showErrorToast('背景图导入失败，请重试');
      }
    } finally {
      if (mounted) {
        setState(() => _isImportingImage = false);
      }
    }
  }

  void _showErrorToast(String message) {
    final toast = _toast ??= FToast()..init(context);
    AppToast.error(toast, context, message);
  }

  /// 从文件系统挑一张图片 / SVG 当账户图标，收编进附件目录。
  ///
  /// 走 `file_selector` 而不是 image_picker：相册选择器通常不给 SVG，
  /// 而矢量图标恰恰是自定义图标的理想素材（任意尺寸不糊、体积小）。
  Future<String?> _pickCustomIcon() async {
    if (_isImportingImage) {
      return null;
    }
    setState(() => _isImportingImage = true);
    try {
      const typeGroup = XTypeGroup(
        label: '图片',
        extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'svg'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null || !mounted) {
        return null;
      }
      final session = ref.read(authSessionControllerProvider);
      final userId = session.userId;
      if (userId == null) {
        _showErrorToast('登录状态失效，请重新进入');
        return null;
      }

      final relativePath = await ref
          .read(attachmentStoreProvider)
          .importFile(userId: userId, sourcePath: file.path);
      _sessionImportedIcons.add(relativePath);
      if (!mounted) {
        return null;
      }
      final iconName = AccountIconCatalog.customIconName(relativePath);
      setState(() => _selectedIcon = iconName);
      return iconName;
    } catch (_) {
      if (mounted) {
        _showErrorToast('自定义图标导入失败，请重试');
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isImportingImage = false);
      }
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final account = widget.account;
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    // 背景字段只在对应样式下生效；default 全空（升级前数据保持一致）。
    final backgroundStyle =
        _backgroundStyle == MoneyAccountBackgroundStyle.defaultStyle
        ? null
        : _backgroundStyle;
    final backgroundColor = backgroundStyle == null
        ? null
        : (_backgroundColor ?? _defaultBackgroundColor);
    final backgroundImage = backgroundStyle == MoneyAccountBackgroundStyle.image
        ? _backgroundImage
        : null;
    _committedBackgroundImage = backgroundImage;
    // 自定义图标是 'file:<相对路径>'；预置图标原样存。
    _committedCustomIcon = AccountIconCatalog.isCustomIcon(_selectedIcon)
        ? AccountIconCatalog.customIconPath(_selectedIcon)
        : null;

    if (account == null) {
      Navigator.of(context).pop(
        AccountFormResult.create(
          MoneyAccountDraft(
            name: name,
            description: description.isEmpty ? null : description,
            type: _type,
            initialBalanceMinor: parseMoneyAmountToMinor(
              _initialBalanceController.text,
            ),
            currencyCode: _currencyCode,
            color: _selectedColor,
            icon: _selectedIcon,
            backgroundStyle: backgroundStyle,
            backgroundColor: backgroundColor,
            backgroundImage: backgroundImage,
            statementDay: _type.isCreditLike ? _statementDay : null,
            budgetCycleStartDay: _type.isCreditLike
                ? _budgetCycleStartDay
                : null,
            repaymentDay: _type.isCreditLike ? _repaymentDay : null,
            autoRepaymentReminderEnabled:
                _type.isCreditLike && _autoRepaymentReminderEnabled,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      AccountFormResult.update(
        MoneyAccountUpdate(
          id: account.id,
          name: name,
          description: description.isEmpty ? null : description,
          type: _type,
          currencyCode: _currencyCode,
          initialBalanceMinor: parseMoneyAmountToMinor(
            _initialBalanceController.text,
          ),
          color: _selectedColor,
          icon: _selectedIcon,
          backgroundStyle: backgroundStyle,
          backgroundColor: backgroundColor,
          backgroundImage: backgroundImage,
          statementDay: _type.isCreditLike ? _statementDay : null,
          budgetCycleStartDay: _type.isCreditLike ? _budgetCycleStartDay : null,
          repaymentDay: _type.isCreditLike ? _repaymentDay : null,
          autoRepaymentReminderEnabled:
              _type.isCreditLike && _autoRepaymentReminderEnabled,
        ),
      ),
    );
  }

  Widget _buildBillingCycleFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fields = <Widget>[
          _buildBillingCycleField(
            label: '账单日',
            child: FormDropdown<int>(
              initialSelection: _statementDay,
              label: '账单日',
              width: double.infinity,
              leadingIcon: const Icon(Icons.receipt_long_rounded),
              onSelected: (value) {
                if (value == null) return;
                setState(() {
                  final shouldFollowStatementDay =
                      _budgetCycleStartDay == _statementDay;
                  _statementDay = value;
                  if (shouldFollowStatementDay) {
                    _budgetCycleStartDay = value;
                  }
                });
              },
              entries: _billingDayEntries,
            ),
          ),
          _buildBillingCycleField(
            label: '预算周期起始日',
            child: FormDropdown<int>(
              initialSelection: _budgetCycleStartDay,
              label: '预算周期起始日',
              width: double.infinity,
              leadingIcon: const Icon(Icons.date_range_rounded),
              onSelected: (value) {
                if (value == null) return;
                setState(() => _budgetCycleStartDay = value);
              },
              entries: _billingDayEntries,
            ),
          ),
          _buildBillingCycleField(
            label: '还款日',
            child: FormDropdown<int>(
              initialSelection: _repaymentDay,
              label: '还款日',
              width: double.infinity,
              leadingIcon: const Icon(Icons.event_available_rounded),
              onSelected: (value) {
                if (value == null) return;
                setState(() => _repaymentDay = value);
              },
              entries: _billingDayEntries,
            ),
          ),
        ];

        if (constraints.maxWidth < 520) {
          return AppFormColumn(children: fields);
        }

        final rowChildren = <Widget>[];
        for (var index = 0; index < fields.length; index += 1) {
          if (index > 0) {
            rowChildren.add(const SizedBox(width: 12));
          }
          rowChildren.add(Expanded(child: fields[index]));
        }
        return Row(children: rowChildren);
      },
    );
  }

  Widget _buildBillingCycleField({
    required String label,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
        child,
      ],
    );
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '请输入账户名称';
    }
    if (text.length > 30) {
      return '账户名称最多30个字符';
    }
    return null;
  }

  String? _validateAmount(String? value) {
    try {
      final amountMinor = parseMoneyAmountToMinor(value ?? '');
      if (amountMinor < 0) {
        return '$_balanceFieldLabel不能小于0';
      }

      final account = widget.account;
      if (account == null) {
        return null;
      }

      if (_type.isCreditLike) {
        final usedCreditMinor = account.type.isCreditLike
            ? account.usedCreditMinor
            : 0;
        if (amountMinor < usedCreditMinor) {
          return '信用额度不能小于已占用额度';
        }
        return null;
      }

      final newBalanceMinor = account.type.isCreditLike
          ? amountMinor
          : account.balanceMinor + (amountMinor - account.initialBalanceMinor);
      if (newBalanceMinor < 0) {
        return '$_balanceFieldLabel调整过低，账户余额不能小于0';
      }

      return null;
    } catch (_) {
      return '请输入有效金额';
    }
  }

  String get _balanceFieldLabel {
    return _type.isCreditLike ? '信用额度' : '初始余额';
  }

  String? get _balanceFieldHelperText {
    if (_type.isCreditLike) {
      return _isEditing ? '不能低于已占用额度' : '创建后已入账负债和冻结额度为 0';
    }
    return _isEditing ? '修改后会按差额同步调整当前余额' : null;
  }

  String get _normalizedDefaultCurrencyCode {
    final value = widget.defaultCurrencyCode?.trim().toUpperCase();
    if (value != null && supportedMoneyCurrencyCodes.contains(value)) {
      return value;
    }
    return defaultMoneyCurrencyCode;
  }

  List<DropdownMenuEntry<int>> get _billingDayEntries {
    return List.generate(31, (index) {
      final day = index + 1;
      return DropdownMenuEntry(value: day, label: '$day 日');
    });
  }
}

/// 表单顶部的卡片实时预览：用当前表单状态渲染一张真实卡片，
/// 改图标 / 背景 / 名称立即反映，所见即所得。
class _AccountAppearancePreview extends StatelessWidget {
  const _AccountAppearancePreview({
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.color,
    required this.icon,
    required this.backgroundStyle,
    this.backgroundColor,
    this.backgroundImage,
  });

  final String name;
  final MoneyAccountType type;
  final String currencyCode;
  final String color;
  final String icon;
  final MoneyAccountBackgroundStyle backgroundStyle;
  final String? backgroundColor;
  final String? backgroundImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewAccount = MoneyAccountEntity(
      id: 'preview',
      userId: 'preview',
      name: name.trim().isEmpty ? '账户名称' : name.trim(),
      type: type,
      balanceMinor: 1234567,
      initialBalanceMinor: 0,
      creditLimitMinor: null,
      postedDebtMinor: null,
      frozenCreditMinor: null,
      statementDay: null,
      budgetCycleStartDay: null,
      repaymentDay: null,
      autoRepaymentReminderEnabled: false,
      currencyCode: currencyCode,
      isShared: false,
      isVirtual: false,
      color: color,
      icon: icon,
      backgroundStyle:
          backgroundStyle == MoneyAccountBackgroundStyle.defaultStyle
          ? null
          : backgroundStyle.storageValue,
      backgroundColor: backgroundColor,
      backgroundImage: backgroundStyle == MoneyAccountBackgroundStyle.image
          ? backgroundImage
          : null,
      isActive: true,
      isDeleted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return AccountCardBackground(
      account: previewAccount,
      child: Row(
        children: [
          _PreviewIcon(account: previewAccount),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  previewAccount.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AccountCardScope.textColorOf(
                      context,
                      fallback: theme.colorScheme.onSurface,
                    ),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${type.label} · $currencyCode',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AccountCardScope.textColorOf(
                      context,
                      fallback: theme.colorScheme.onSurfaceVariant,
                    ).withValues(alpha: AccountCardScope.secondaryOpacity),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatMoneyMinor(previewAccount.displayBalanceMinor, currencyCode),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AccountCardScope.textColorOf(
                context,
                fallback: theme.colorScheme.onSurface,
              ),
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// 预览卡上的图标：与列表卡 `_AccountIcon` 同一套视觉
/// （默认背景 = 品牌色浅底；自定义背景 = 磨砂反色；自定义 logo 不套壳）。
class _PreviewIcon extends StatelessWidget {
  const _PreviewIcon({required this.account});

  final MoneyAccountEntity account;

  static const double _slot = 42;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scope = AccountCardScope.maybeOf(context);

    // 与列表卡一致：自定义品牌 logo 铺满槽位、不套浅色底壳。
    if (AccountIconView.usesCustomImage(account)) {
      return SizedBox(
        width: _slot,
        height: _slot,
        child: Center(
          child: AccountIconView(
            account: account,
            size: 21,
            imageSize: accountCardLogoSize,
          ),
        ),
      );
    }

    final accentColor = account.color == null
        ? appColorFromHex(defaultAccountColorForType(account.type))
        : appColorFromHex(account.color);

    if (scope != null) {
      final isLight = theme.brightness == Brightness.light;
      final frosted = isLight ? Colors.white : Colors.black;
      return Container(
        width: _slot,
        height: _slot,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: frosted.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(theme.radiusTokens.md),
          border: Border.all(color: scope.onColor.withValues(alpha: 0.28)),
        ),
        child: AccountIconView(
          account: account,
          size: 21,
          color: scope.onColor,
        ),
      );
    }

    return Container(
      width: _slot,
      height: _slot,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: AccountIconView(account: account, size: 21, color: accentColor),
    );
  }
}

/// 账户图标选择字段：点击打开分组网格，选中即刻回填；网格头部有
/// 「自定义图片」入口（任意位图 / SVG）。
class _AccountIconPickerField extends StatelessWidget {
  const _AccountIconPickerField({
    required this.selectedIcon,
    required this.fallbackType,
    required this.fallbackColor,
    required this.isBusy,
    required this.onSelected,
    required this.onPickCustom,
  });

  final String selectedIcon;
  final MoneyAccountType fallbackType;
  final String fallbackColor;
  final bool isBusy;
  final ValueChanged<String> onSelected;
  final Future<String?> Function() onPickCustom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controls = theme.controlTokens;
    final radius = theme.radiusTokens;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius.md),
        onTap: () => _openPicker(context),
        child: Container(
          height: controls.compactFieldHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(radius.md),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                Icons.emoji_symbols_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              if (isBusy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                _SelectedIconGlyph(
                  selectedIcon: selectedIcon,
                  fallbackType: fallbackType,
                  fallbackColor: fallbackColor,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AccountIconCatalog.isCustomIcon(selectedIcon)
                      ? '账户图标 · 自定义'
                      : '账户图标',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showAppResponsiveDialog<String>(
      context: context,
      expandCompactSheet: true,
      builder: (dialogContext) {
        return AppDialogScaffold(
          title: '选择账户图标',
          maxWidth: 420,
          titleTextAlign: TextAlign.center,
          actionsAlignment: WrapAlignment.center,
          body: SingleChildScrollView(
            child: _AccountIconGrid(
              selectedIcon: selectedIcon,
              onSelected: (name) => Navigator.of(dialogContext).pop(name),
              onPickCustom: onPickCustom,
            ),
          ),
          actions: const [
            // 点图标即选中返回，这里不放确认按钮。
          ],
        );
      },
    );

    if (selected != null) {
      onSelected(selected);
    }
  }
}

/// 字段里展示的当前图标：预置字形着标识色，自定义图片 / SVG 原样出。
class _SelectedIconGlyph extends StatelessWidget {
  const _SelectedIconGlyph({
    required this.selectedIcon,
    required this.fallbackType,
    required this.fallbackColor,
  });

  final String selectedIcon;
  final MoneyAccountType fallbackType;
  final String fallbackColor;

  @override
  Widget build(BuildContext context) {
    if (!AccountIconCatalog.isCustomIcon(selectedIcon)) {
      return Icon(
        AccountIconCatalog.forName(selectedIcon) ??
            accountIconDataForType(fallbackType),
        size: 22,
        color: Theme.of(context).colorScheme.primary,
      );
    }

    final now = DateTime.now();
    final pseudoAccount = MoneyAccountEntity(
      id: 'field-preview',
      userId: 'field-preview',
      name: '',
      type: fallbackType,
      balanceMinor: 0,
      initialBalanceMinor: 0,
      creditLimitMinor: null,
      postedDebtMinor: null,
      frozenCreditMinor: null,
      statementDay: null,
      budgetCycleStartDay: null,
      repaymentDay: null,
      autoRepaymentReminderEnabled: false,
      currencyCode: 'CNY',
      isShared: false,
      isVirtual: false,
      color: fallbackColor,
      icon: selectedIcon,
      isActive: true,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    );
    return AccountIconView(account: pseudoAccount, size: 22, imageSize: 28);
  }
}

/// 分组图标网格；顶部是「自定义图片」入口。
class _AccountIconGrid extends StatelessWidget {
  const _AccountIconGrid({
    required this.selectedIcon,
    required this.onSelected,
    required this.onPickCustom,
  });

  final String selectedIcon;
  final ValueChanged<String> onSelected;
  final Future<String?> Function() onPickCustom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCustomSelected = AccountIconCatalog.isCustomIcon(selectedIcon);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Text(
            '自定义',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _CustomIconCell(
              isSelected: isCustomSelected,
              storedPath: AccountIconCatalog.customIconPath(selectedIcon),
              onTap: () async {
                final iconName = await onPickCustom();
                if (iconName != null) {
                  onSelected(iconName);
                }
              },
            ),
          ],
        ),
        for (final group in AccountIconCatalog.groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Text(
              group.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in group.entries)
                _AccountIconCell(
                  entry: entry,
                  isSelected: !isCustomSelected && entry.name == selectedIcon,
                  onSelected: onSelected,
                ),
            ],
          ),
        ],
        const SizedBox(height: 6),
      ],
    );
  }
}

/// 「自定义图片」格：显示当前自定义图标（或加号占位），点击走文件选择。
class _CustomIconCell extends StatelessWidget {
  const _CustomIconCell({
    required this.isSelected,
    required this.storedPath,
    required this.onTap,
  });

  final bool isSelected;
  final String? storedPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: '从文件选择图片或 SVG',
      child: InkWell(
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 52,
          height: 52,
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(theme.radiusTokens.md),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: storedPath == null
              ? Icon(
                  Icons.add_photo_alternate_rounded,
                  size: 24,
                  color: colorScheme.onSurfaceVariant,
                )
              : _StoredIconThumb(storedPath: storedPath!),
        ),
      ),
    );
  }
}

/// 自定义图标缩略图（相对路径 → 本机文件，异步解析；SVG / 位图分别渲染）。
class _StoredIconThumb extends ConsumerStatefulWidget {
  const _StoredIconThumb({required this.storedPath});

  final String storedPath;

  @override
  ConsumerState<_StoredIconThumb> createState() => _StoredIconThumbState();
}

class _StoredIconThumbState extends ConsumerState<_StoredIconThumb> {
  Future<File?>? _future;
  String? _resolvedFor;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(attachmentStoreProvider);
    if (_resolvedFor != widget.storedPath) {
      _resolvedFor = widget.storedPath;
      _future = store.existingFile(widget.storedPath);
    }

    return FutureBuilder<File?>(
      future: _future,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) {
          return Icon(
            Icons.add_photo_alternate_rounded,
            size: 24,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );
        }
        // 52 的格子里给到 34：品牌 logo 多为透明底，按小图缩会看不清。
        const thumbSize = 34.0;
        if (file.path.toLowerCase().endsWith('.svg')) {
          return SvgPicture.file(
            file,
            width: thumbSize,
            height: thumbSize,
            fit: BoxFit.contain,
          );
        }
        return Image.file(
          file,
          width: thumbSize,
          height: thumbSize,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        );
      },
    );
  }
}

class _AccountIconCell extends StatelessWidget {
  const _AccountIconCell({
    required this.entry,
    required this.isSelected,
    required this.onSelected,
  });

  final AccountIconEntry entry;
  final bool isSelected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: entry.name,
      child: InkWell(
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
        onTap: () => onSelected(entry.name),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(theme.radiusTokens.md),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Icon(
            entry.iconData,
            size: 24,
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// 背景图选择字段：缩略图 + 更换 / 移除。
class _BackgroundImageField extends StatelessWidget {
  const _BackgroundImageField({
    required this.storedPath,
    required this.isBusy,
    required this.onPick,
    required this.onRemove,
  });

  final String? storedPath;
  final bool isBusy;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(radius.md),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          _BackgroundThumbnail(storedPath: storedPath),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              storedPath == null ? '选择背景图片' : '已设置背景图片',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          if (isBusy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              tooltip: storedPath == null ? '从相册选择' : '更换图片',
              onPressed: onPick,
              icon: const Icon(Icons.photo_library_rounded, size: 20),
            ),
          if (storedPath != null && !isBusy)
            IconButton(
              tooltip: '移除背景图',
              onPressed: onRemove,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}

/// 已收编背景图的缩略图（相对路径 → 本机文件，异步解析）。
class _BackgroundThumbnail extends ConsumerStatefulWidget {
  const _BackgroundThumbnail({required this.storedPath});

  final String? storedPath;

  @override
  ConsumerState<_BackgroundThumbnail> createState() =>
      _BackgroundThumbnailState();
}

class _BackgroundThumbnailState extends ConsumerState<_BackgroundThumbnail> {
  Future<File?>? _future;
  String? _resolvedFor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final path = widget.storedPath;
    final store = ref.watch(attachmentStoreProvider);

    if (path == null) {
      return Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
        ),
        child: Icon(
          Icons.image_outlined,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (_resolvedFor != path) {
      _resolvedFor = path;
      _future = store.existingFile(path);
    }

    return Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      ),
      child: FutureBuilder<File?>(
        future: _future,
        builder: (context, snapshot) {
          final file = snapshot.data;
          if (file == null) {
            return Icon(
              Icons.image_outlined,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            );
          }
          return Image.file(file, fit: BoxFit.cover, gaplessPlayback: true);
        },
      ),
    );
  }
}
