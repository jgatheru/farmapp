// main.dart
import 'package:farmapp/com/wisedigits/crm/appointments/addAppointment.dart';
import 'package:farmapp/com/wisedigits/crm/appointments/appointmentReport.dart';
import 'package:farmapp/com/wisedigits/crm/appointments/appointmentReportBySpeciliality.dart';
import 'package:farmapp/com/wisedigits/crm/appointments/appointments.dart';
import 'package:farmapp/com/wisedigits/crm/persons/persondetails.dart';
import 'package:farmapp/com/wisedigits/farm/animalcategory/addAnimalcategory.dart';
import 'package:farmapp/com/wisedigits/farm/animalcategory/animalcategory.dart';
import 'package:farmapp/com/wisedigits/farm/deliveries/deliveries.dart';
import 'package:farmapp/com/wisedigits/crm/facility/addFacility.dart';
import 'package:farmapp/com/wisedigits/crm/facility/facility.dart';
import 'package:farmapp/com/wisedigits/farm/feeding/feeding.dart';
import 'package:farmapp/com/wisedigits/farm/feedingplans/feedingplans.dart';
import 'package:farmapp/com/wisedigits/farm/feedingplans/feedingplanslist.dart';
import 'package:farmapp/com/wisedigits/farm/health/healthrecords.dart';
import 'package:farmapp/com/wisedigits/crm/persons/addPersons.dart';
import 'package:farmapp/com/wisedigits/crm/persons/persons.dart';
import 'package:farmapp/com/wisedigits/farm/reports/productivity.dart';
import 'package:farmapp/com/wisedigits/farm/reports/productivitylist.dart';
import 'package:farmapp/com/wisedigits/farm/reports/summary.dart';
import 'package:farmapp/com/wisedigits/pos/orders/orders.dart';

import 'com/wisedigits/farm/animals/addAnimals.dart';
import 'com/wisedigits/farm/animals/animals.dart';
import 'com/wisedigits/farm/deliveries/deliverieslist.dart';
import 'com/wisedigits/farm/production/production.dart';
import 'com/wisedigits/home.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'com/wisedigits/auth/SessionProvider.dart';
import 'com/wisedigits/auth/login.dart';
import 'com/wisedigits/farm/shades/addshades.dart';
import 'com/wisedigits/farm/shades/shades.dart';

void main() {
  runApp(
    ChangeNotifierProvider( // Wrap MyApp with ChangeNotifierProvider
      create: (context) => SessionProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sisi Pharmaceutical', // Added a title for the app
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(), // Added const for better performance
        '/home': (context) => const Home(), // Added const for better performance
        '/addShade': (context) => const ShadesFormPage(),
        '/viewShades': (context) => const ShadesListPage(),
        '/addAnimal': (context) => const ManageAnimalPage(),
        '/viewAnimals': (context) => const AnimalsListPage(),
        '/viewAnimalCategories': (context) => const AnimalCategoriesListPage(),
        '/addAnimalCategory': (context) => const AnimalCategoryFormPage(),
        '/viewProduction': (context) => const MilkProductionRecordsPage(),
        '/viewDeliveries': (context) => const DeliveriesListPage(),
        '/viewFeedingPlans': (context) => const FeedingPlansListPage(),
        '/viewFeeding': (context) => const FeedingsListPage(),
        '/viewHealthRecords': (context) => const HealthRecordsListPage(),
        '/viewPersons': (context)=> const PersonsListPage(),
        '/addPerson': (context)=>AddPersonPage(),
        '/viewFacilitys': (context)=>FacilityListPage(),
        '/addFacility': (context)=>AddFacilityPage(),
        '/viewAppointments': (context)=>AppointmentListPage(0),
        '/viewCompleteAppointments': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          // Extract reportType from the Map (default to 1)
          final reportType = (args as Map<String, dynamic>?)?['reportType'] ?? 1;
          return AppointmentListPage(reportType);
        },
        '/addAppointment': (context)=>AddAppointmentPage(),
        '/viewAppointmentReport': (context) => AppointmentReportPage(),
        '/viewAppointmentReportBySpeciality': (context) => SpecialityReportPage(),
        '/productivityReport': (context) => ReportPage(),
        '/viewOrders': (context) => OrdersPage(),
        '/summary': (context) => MilkProductionSummaryPage()
      },
    );
  }
}
