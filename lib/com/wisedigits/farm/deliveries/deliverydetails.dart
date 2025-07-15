import 'package:farmapp/com/wisedigits/farm/deliveries/deliverieslist.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../config.dart';
import 'deliveries.dart'; // Import the Delivery model (adjust path as needed)

class DeliveryDetailsPage extends StatelessWidget {
  final DeliveryReport delivery;

  const DeliveryDetailsPage({super.key, required this.delivery});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Config.themeColor,
        foregroundColor: Colors.white,
        title: Text('Delivery #${delivery.date}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 5.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //...delivery.getDisplayWidgets(),
                const SizedBox(height: 16),
                if (delivery.notes != null && delivery.notes!.isNotEmpty) ...[
                  const Text(
                    'Full Notes:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    delivery.notes!,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    return Chip(
      avatar: Icon(icon, size: 18, color: color ?? Config.themeColor),
      label: Text('$label: $value'),
      backgroundColor: (color ?? Config.themeColor).withOpacity(0.1),
      labelStyle: TextStyle(color: color ?? Colors.black87),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}