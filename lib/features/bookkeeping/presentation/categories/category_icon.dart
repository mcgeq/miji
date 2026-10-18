import 'package:flutter/material.dart';

/// 分类 / 子分类的 `icon` 字段归一化。
///
/// 现状：种子数据（`money_seed_data.dart`）与新建分类写入的都是 **Material
/// 图标名**（`restaurant`、`breakfast_dining`、`category`…），但分类下拉菜单
/// 曾把它当成 emoji 直接 `Text(...)` 渲染，于是界面上出现了英文单词。
///
/// 这里统一约定：
/// * 非 ASCII（emoji）→ 原样按文字渲染，为后续「emoji 图标」留出空间；
/// * Material 图标名 → 查 [materialIconForCategoryIcon] 映射成 [IconData]；
/// * 都不认识 → 返回 null，由调用方回退到通用图标。
bool isEmojiCategoryIcon(String? icon) {
  final value = icon?.trim();
  if (value == null || value.isEmpty) {
    return false;
  }
  for (final rune in value.runes) {
    if (rune > 0x2000) {
      return true;
    }
  }
  return false;
}

/// Material 图标名 → [IconData]，未知返回 null。
IconData? materialIconForCategoryIcon(String? icon) {
  final value = icon?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return switch (value) {
    'accessibility_new' => Icons.accessibility_new,
    'account_balance' => Icons.account_balance,
    'account_balance_wallet' => Icons.account_balance_wallet,
    'add_card' => Icons.add_card,
    'apartment' => Icons.apartment,
    'apps' => Icons.apps,
    'assignment' => Icons.assignment,
    'attractions' => Icons.attractions,
    'auto_stories' => Icons.auto_stories,
    'badge' => Icons.badge,
    'bakery_dining' => Icons.bakery_dining,
    'bolt' => Icons.bolt,
    'breakfast_dining' => Icons.breakfast_dining,
    'build' => Icons.build,
    'business_center' => Icons.business_center,
    'calendar_month' => Icons.calendar_month,
    'campaign' => Icons.campaign,
    'candlestick_chart' => Icons.candlestick_chart,
    'card_giftcard' => Icons.card_giftcard,
    'cast_for_education' => Icons.cast_for_education,
    'category' => Icons.category,
    'celebration' => Icons.celebration,
    'chair' => Icons.chair,
    'checkroom' => Icons.checkroom,
    'child_care' => Icons.child_care,
    'child_friendly' => Icons.child_friendly,
    'cloud' => Icons.cloud,
    'co_present' => Icons.co_present,
    'confirmation_number' => Icons.confirmation_number,
    'content_cut' => Icons.content_cut,
    'copyright' => Icons.copyright,
    'credit_card' => Icons.credit_card,
    'currency_bitcoin' => Icons.currency_bitcoin,
    'delete' => Icons.delete,
    'delivery_dining' => Icons.delivery_dining,
    'dentistry' => Icons.medical_services,
    'description' => Icons.description,
    'device_thermostat' => Icons.device_thermostat,
    'devices' => Icons.devices,
    'diamond' => Icons.diamond,
    'dinner_dining' => Icons.dinner_dining,
    'directions_boat' => Icons.directions_boat,
    'directions_bus' => Icons.directions_bus,
    'directions_car' => Icons.directions_car,
    'domain' => Icons.domain,
    'donut_large' => Icons.donut_large,
    'eco' => Icons.eco,
    'elderly' => Icons.elderly,
    'emoji_events' => Icons.emoji_events,
    'family_restroom' => Icons.family_restroom,
    'favorite' => Icons.favorite,
    'festival' => Icons.festival,
    'fitness_center' => Icons.fitness_center,
    'flight' => Icons.flight,
    'flight_takeoff' => Icons.flight_takeoff,
    'folder' => Icons.folder,
    'gpp_bad' => Icons.gpp_bad,
    'grass' => Icons.grass,
    'groups' => Icons.groups,
    'handyman' => Icons.handyman,
    'health_and_safety' => Icons.health_and_safety,
    'home' => Icons.home,
    'hotel' => Icons.hotel,
    'house' => Icons.house,
    'imagesearch_roller' => Icons.imagesearch_roller,
    'inventory_2' => Icons.inventory_2,
    'keyboard_return' => Icons.keyboard_return,
    'kitchen' => Icons.kitchen,
    'label' => Icons.label,
    'laptop_mac' => Icons.laptop_mac,
    'lightbulb' => Icons.lightbulb,
    'live_tv' => Icons.live_tv,
    'local_cafe' => Icons.local_cafe,
    'local_dining' => Icons.local_dining,
    'local_fire_department' => Icons.local_fire_department,
    'local_gas_station' => Icons.local_gas_station,
    'local_grocery_store' => Icons.local_grocery_store,
    'local_hospital' => Icons.local_hospital,
    'local_hotel' => Icons.local_hotel,
    'local_mall' => Icons.local_mall,
    'local_parking' => Icons.local_parking,
    'local_shipping' => Icons.local_shipping,
    'local_taxi' => Icons.local_taxi,
    'luggage' => Icons.luggage,
    'lunch_dining' => Icons.lunch_dining,
    'map' => Icons.map,
    'medical_services' => Icons.medical_services,
    'medication' => Icons.medication,
    'menu_book' => Icons.menu_book,
    'mic' => Icons.mic,
    'more_horiz' => Icons.more_horiz,
    'museum' => Icons.museum,
    'music_note' => Icons.music_note,
    'palette' => Icons.palette,
    'payments' => Icons.payments,
    'pedal_bike' => Icons.pedal_bike,
    'pets' => Icons.pets,
    'phone_iphone' => Icons.phone_iphone,
    'play_circle' => Icons.play_circle,
    'query_stats' => Icons.query_stats,
    'real_estate_agent' => Icons.real_estate_agent,
    'receipt' => Icons.receipt,
    'receipt_long' => Icons.receipt_long,
    'record_voice_over' => Icons.record_voice_over,
    'recycling' => Icons.recycling,
    'redeem' => Icons.redeem,
    'request_quote' => Icons.request_quote,
    'restaurant' => Icons.restaurant,
    'savings' => Icons.savings,
    'schedule' => Icons.schedule,
    'school' => Icons.school,
    'sell' => Icons.sell,
    'shield' => Icons.shield,
    'shopping_bag' => Icons.shopping_bag,
    'shopping_cart' => Icons.shopping_cart,
    'show_chart' => Icons.show_chart,
    'solar_power' => Icons.solar_power,
    'spa' => Icons.spa,
    'sports_esports' => Icons.sports_esports,
    'stacked_line_chart' => Icons.stacked_line_chart,
    'store' => Icons.store,
    'store_mall_directory' => Icons.store_mall_directory,
    'storefront' => Icons.storefront,
    'subscriptions' => Icons.subscriptions,
    'subway' => Icons.subway,
    'support_agent' => Icons.support_agent,
    'swap_horiz' => Icons.swap_horiz,
    'sync' => Icons.sync,
    'task_alt' => Icons.task_alt,
    'theater_comedy' => Icons.theater_comedy,
    'theaters' => Icons.theaters,
    'toll' => Icons.toll,
    'toys' => Icons.toys,
    'train' => Icons.train,
    'trending_up' => Icons.trending_up,
    'tv' => Icons.tv,
    'vaccines' => Icons.vaccines,
    'verified_user' => Icons.verified_user,
    'volunteer_activism' => Icons.volunteer_activism,
    'warning' => Icons.warning,
    'watch' => Icons.watch,
    'water_drop' => Icons.water_drop,
    'wifi' => Icons.wifi,
    'work' => Icons.work,
    'workspace_premium' => Icons.workspace_premium,
    'yard' => Icons.yard,
    _ => null,
  };
}

/// 分类图标：emoji 或 Material 图标，两者都不可用时回退到 [fallback]。
class CategoryIconWidget extends StatelessWidget {
  const CategoryIconWidget(
    this.icon, {
    super.key,
    this.size = 18,
    this.color,
    this.fallback = Icons.category_rounded,
  });

  final String? icon;
  final double size;
  final Color? color;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedColor = color ?? colorScheme.primary;
    if (isEmojiCategoryIcon(icon)) {
      return Text(
        icon!.trim(),
        style: TextStyle(fontSize: size * 0.92, height: 1),
      );
    }
    return Icon(
      materialIconForCategoryIcon(icon) ?? fallback,
      size: size,
      color: resolvedColor,
    );
  }
}
