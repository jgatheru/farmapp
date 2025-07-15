import 'package:flutter/material.dart'; // Import for IconData

/// Model for a dynamic statistical item fetched from an API.
class StatisticItem {
  final String title;
  final String value; // Use String to handle mixed types
  final IconData iconData; // Renamed to iconData for clarity, as it's the actual IconData object
  final String route;

  StatisticItem({
    required this.title,
    required this.value,
    required this.iconData, // Use iconData here
    required this.route,
  });

  // A static map to convert string icon names to IconData objects
  static const Map<String, IconData> _iconMap = {
    'pets': Icons.pets,
    'local_drink': Icons.local_drink,
    'health_and_safety': Icons.health_and_safety,
    'grass': Icons.grass,
    'account_balance': Icons.account_balance,
    'shop': Icons.shop,
    'agriculture_sharp': Icons.agriculture_sharp,
    'agriculture': Icons.agriculture,
    'shelves': Icons.shelves,
    'local_shipping': Icons.local_shipping,
    'calendar_today': Icons.calendar_today,
    'restaurant': Icons.restaurant,
    'medical_services': Icons.medical_services,
    'money_off': Icons.money_off,
    'attach_money': Icons.attach_money,
    'bar_chart': Icons.bar_chart,
    'show_chart': Icons.show_chart,
    'pie_chart': Icons.pie_chart,
    'receipt_long': Icons.receipt_long,
    // Add any other icons your API might send for statistics here
  };

  factory StatisticItem.fromJson(Map<String, dynamic> json) {
    final String iconNameString = json['iconName'] as String? ?? '';
    // Corrected access: Use StatisticItem._iconMap
    final IconData mappedIcon = StatisticItem._iconMap[iconNameString] ?? Icons.info;

    return StatisticItem(
      title: json['title'] as String? ?? 'Unknown',
      value: json['value'].toString(),
      iconData: mappedIcon, // Assign the *mapped IconData* to iconData
      route: json['route'] as String? ?? '',
    );
  }
}