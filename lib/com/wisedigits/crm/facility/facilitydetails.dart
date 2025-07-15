import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../config.dart';
import 'facility.dart';

class FacilityDetailsPage extends StatelessWidget {
  final Facility facility;

  const FacilityDetailsPage({super.key, required this.facility});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(facility.name ?? 'Facility Details'),
        backgroundColor: Config.backgroundColor ?? Colors.blueGrey,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Facility',
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/addFacility',
                arguments: facility,
              ).then((value) {
                if (value == true) {
                  Navigator.pop(context, true);
                }
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...facility.getDisplayWidgets(),

          ],
        ),
      ),
    );
  }
}