import 'dart:developer' as developer;

class Person {
  final int id;
  final String name;

  Person({required this.id, required this.name});

  factory Person.fromJson(Map<String, dynamic> json) {
    final id = int.tryParse(json['id']?.toString() ?? '') ?? 0;
    if (id == 0) {
      developer.log('Warning: Invalid Person ID: ${json['id']}', name: 'Person.fromJson');
    }
    return Person(
      id: id,
      name: json['name']?.toString() ?? '',
    );
  }

  @override
  String toString() => 'Person(id: $id, name: $name)';
}

class Facility {
  final int id;
  final String name;

  Facility({required this.id, required this.name});

  factory Facility.fromJson(Map<String, dynamic> json) {
    final id = int.tryParse(json['id']?.toString() ?? '') ?? 0;
    if (id == 0) {
      developer.log('Warning: Invalid Facility ID: ${json['id']}', name: 'Facility.fromJson');
    }
    return Facility(
      id: id,
      name: json['name']?.toString() ?? '',
    );
  }

  @override
  String toString() => 'Facility(id: $id, name: $name)';
}

class Product {
  final int id;
  final String name;

  Product({required this.id, required this.name});

  factory Product.fromJson(Map<String, dynamic> json) {
    final id = int.tryParse(json['id']?.toString() ?? '') ?? 0;
    if (id == 0) {
      developer.log('Warning: Invalid Product ID: ${json['id']}', name: 'Product.fromJson');
    }
    return Product(
      id: id,
      name: json['name']?.toString() ?? '',
    );
  }

  @override
  String toString() => 'Product(id: $id, name: $name)';
}

class Appointment {
  final int id;
  final int? appointmentId;
  final String? type;
  final Facility? facility;
  final Person? person;
  final int? personScheduleId;
  final Person? employee;
  final int? agentId;
  final String? appointmentDate;
  final String? appointmentTime;
  final String? action;
  final String? reaction;
  final int? ratingId;
  final String? followup;
  final String? locale;
  final String? location;
  final String? longitude;
  final String? latitude;
  final int? status;
  final int? rescheduled;
  final String? remarks;
  final String? ipAddress;
  final int? createdBy;
  final String? createdOn;
  final int? lastEditedBy;
  final String? lastEditedOn;
  final String? missingTitle;
  final String? missingContent;
  final int? app;
  final String? currentLocation;
  final String? lastSeenDate;
  final String? lastSeenBy;
  final int timesSeenThisMonth;
  final int timesSeenThisQuarter;
  final int timesSeenThisYear;
  final String color;

  Appointment({
    required this.id,
    this.appointmentId,
    this.type,
    this.facility,
    this.person,
    this.personScheduleId,
    this.employee,
    this.agentId,
    this.appointmentDate,
    this.appointmentTime,
    this.action,
    this.reaction,
    this.ratingId,
    this.followup,
    this.locale,
    this.location,
    this.longitude,
    this.latitude,
    this.status,
    this.rescheduled,
    this.remarks,
    this.ipAddress,
    this.createdBy,
    this.createdOn,
    this.lastEditedBy,
    this.lastEditedOn,
    this.missingTitle,
    this.missingContent,
    this.app,
    this.currentLocation,
    this.lastSeenDate,
    this.lastSeenBy,
    required this.timesSeenThisMonth,
    required this.timesSeenThisQuarter,
    required this.timesSeenThisYear,
    required this.color,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    developer.log('Parsing Appointment JSON: $json', name: 'Appointment.fromJson');
    return Appointment(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      appointmentId: int.tryParse(json['appointmentid']?.toString() ?? '') ?? null,
      type: json['type']?.toString(),
      facility: json['facility'] != null ? Facility.fromJson(json['facility'] as Map<String, dynamic>) : null,
      person: json['person'] != null ? Person.fromJson(json['person'] as Map<String, dynamic>) : null,
      personScheduleId: int.tryParse(json['personscheduleid']?.toString() ?? '') ?? null,
      employee: json['employee'] != null ? Person.fromJson(json['employee'] as Map<String, dynamic>) : null,
      agentId: int.tryParse(json['agentid']?.toString() ?? '') ?? null,
      appointmentDate: json['appointmentdate']?.toString(),
      appointmentTime: json['appointmenttime']?.toString(),
      action: json['action']?.toString(),
      reaction: json['reaction']?.toString(),
      ratingId: int.tryParse(json['ratingid']?.toString() ?? '') ?? null,
      followup: json['followup']?.toString(),
      locale: json['locale']?.toString(),
      location: json['location']?.toString(),
      longitude: json['longitude']?.toString(),
      latitude: json['latitude']?.toString(),
      status: int.tryParse(json['status']?.toString() ?? '') ?? null,
      rescheduled: int.tryParse(json['rescheduled']?.toString() ?? '') ?? null,
      remarks: json['remarks']?.toString(),
      ipAddress: json['ipaddress']?.toString(),
      createdBy: int.tryParse(json['createdby']?.toString() ?? '') ?? null,
      createdOn: json['createdon']?.toString(),
      lastEditedBy: int.tryParse(json['lasteditedby']?.toString() ?? '') ?? null,
      lastEditedOn: json['lasteditedon']?.toString(),
      missingTitle: json['missing_title']?.toString(),
      missingContent: json['missing_content']?.toString(),
      app: int.tryParse(json['app']?.toString() ?? '') ?? null,
      currentLocation: json['current_location']?.toString(),
      lastSeenDate: json['last_seen_date']?.toString(),
      lastSeenBy: json['last_seen_by']?.toString(),
      timesSeenThisMonth: int.tryParse(json['times_seen_this_month']?.toString() ?? '') ?? 0,
      timesSeenThisQuarter: int.tryParse(json['times_seen_this_quarter']?.toString() ?? '') ?? 0,
      timesSeenThisYear: int.tryParse(json['times_seen_this_year']?.toString() ?? '') ?? 0,
      color: json['color']!.toString(),
    );
  }
}