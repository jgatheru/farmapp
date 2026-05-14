import 'dart:convert';
import 'dart:math';
import 'package:farmapp/com/wisedigits/crm/persons/persondetails.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';

// Model class for Task Record
class TaskRecord {
  final int id;
  final String taskType;
  final DateTime date;
  final String? notes;

  TaskRecord({
    required this.id,
    required this.taskType,
    required this.date,
    this.notes,
  });

  factory TaskRecord.fromJson(Map<String, dynamic> json) {
    return TaskRecord(
      id: int.parse(json['id'].toString()),
      taskType: json['task_type'] as String,
      date: DateTime.parse(json['date'] as String),
      notes: json['notes'] as String?,
    );
  }
}

// Model classes for related entities
class Title {
  final int id;
  final String name;

  Title({required this.id, required this.name});

  factory Title.fromJson(Map<String, dynamic> json) {
    return Title(
      id: int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
    );
  }
}

class Position {
  final int id;
  final String name;

  Position({required this.id, required this.name});

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      id: int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
    );
  }
}

class Cadre {
  final int id;
  final String name;

  Cadre({required this.id, required this.name});

  factory Cadre.fromJson(Map<String, dynamic> json) {
    return Cadre(
      id: int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
    );
  }
}

class Speciality {
  final int id;
  final String name;

  Speciality({required this.id, required this.name});

  factory Speciality.fromJson(Map<String, dynamic> json) {
    return Speciality(
      id: int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
    );
  }
}

class Classe {
  final int id;
  final String name;

  Classe({required this.id, required this.name});

  factory Classe.fromJson(Map<String, dynamic> json) {
    return Classe(
      id: int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
    );
  }
}

class Category {
  final int id;
  final String name;

  Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
    );
  }
}

// Model class for a single Person
class Person {
  final int? id;
  final String? name;
  final int? titleid;
  final int? positionid;
  final int? cadreid;
  final int? specialityid;
  final String? specialityName;
  final int? classeid;
  final String? email;
  final String? tel;
  final int? regionid;
  final int? subregionid;
  final String? location;
  final int? categoryid;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? lastAppointment;
  final int? timesSeenMonth;
  final int? timesSeenQuarter;
  final int? timesSeenYear;
  final List<TaskRecord> taskRecords;
  final List<String>? displayFields;
  final Color? cardColor;

  Person({
    this.id,
    this.name,
    this.titleid,
    this.positionid,
    this.cadreid,
    this.specialityid,
    this.specialityName,
    this.classeid,
    this.email,
    this.tel,
    this.regionid,
    this.subregionid,
    this.location,
    this.categoryid,
    this.photoUrl,
    this.createdAt,
    this.lastAppointment,
    this.timesSeenMonth,
    this.timesSeenQuarter,
    this.timesSeenYear,
    this.taskRecords = const [],
    this.displayFields,
    this.cardColor,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    Color? parseColor(String? hexColor) {
      if (hexColor == null || hexColor.isEmpty) {
        print("parseColor: hexColor is null or empty");
        return null;
      }
      try {
        String hex = hexColor.replaceFirst('#', '').replaceFirst('0x', '');
        if (hex.length != 6 && hex.length != 8) {
          print("parseColor: Invalid hex length for $hexColor");
          return null;
        }
        final intColor = int.parse(hex, radix: 16);
        // Ensure 8-bit alpha channel if 6-digit hex
        return Color(hex.length == 6 ? (0xFF000000 | intColor) : intColor);
      } catch (e) {
        print("parseColor: Error parsing $hexColor: $e");
        return null;
      }
    }

    return Person(
      id: json['id'] is num ? (json['id'] as num).toInt() : null,
      name: json['name'] as String? ?? 'N/A',
      titleid: json['titleid'] is num ? (json['titleid'] as num).toInt() : null,
      positionid: json['positionid'] is num ? (json['positionid'] as num).toInt() : null,
      cadreid: json['cadreid'] is num ? (json['cadreid'] as num).toInt() : null,
      specialityid: json['specialityid'] is num ? (json['specialityid'] as num).toInt() : null,
      specialityName: json['specialityName'] as String? ?? 'N/A',
      classeid: json['classeid'] is num ? (json['classeid'] as num).toInt() : null,
      email: json['email'] as String? ?? 'N/A',
      tel: json['tel'] as String? ?? 'N/A',
      regionid: json['regionid'] is num ? (json['regionid'] as num).toInt() : null,
      subregionid: json['subregionid'] is num ? (json['subregionid'] as num).toInt() : null,
      location: json['location'] as String? ?? 'N/A',
      categoryid: json['categoryid'] is num ? (json['categoryid'] as num).toInt() : null,
      photoUrl: json['photo_url'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      lastAppointment: json['last_appointment'] != null
          ? DateFormat("yyyy-MM-dd").parse(json['last_appointment'] as String)
          : null,
      timesSeenMonth: json['times_seen_month'] is num ? (json['times_seen_month'] as num).toInt() : null,
      timesSeenQuarter: json['times_seen_quarter'] is num ? (json['times_seen_quarter'] as num).toInt() : null,
      timesSeenYear: json['times_seen_year'] is num ? (json['times_seen_year'] as num).toInt() : null,
      taskRecords: (json['task_records'] as List<dynamic>?)
          ?.map((e) => TaskRecord.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      displayFields: json['displayFields'] != null
          ? List<String>.from(json['displayFields'] as List)
          : null,
      cardColor: parseColor(json['cardColor'] as String?),
    );
  }

  Widget _buildDetailChip({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
    bool show = true,
  }) {
    if (!show) return const SizedBox.shrink();
    return Chip(
      avatar: Icon(icon, size: 18, color: color ?? Config.themeColor),
      label: Text('$label: $value'),
      backgroundColor: (color ?? Config.themeColor).withOpacity(0.1),
      labelStyle: TextStyle(color: color ?? Colors.black87),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  List<Widget> getDisplayWidgets() {
    final List<Widget> widgets = [];

    final Map<String, Widget> allPossibleFieldWidgets = {
      'name': Text(
        name ?? 'N/A',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Config.themeColor,
        ),
      ),
      'email': Text(
        email ?? 'N/A',
        style: const TextStyle(fontSize: 16, color: Colors.black87),
      ),
      'tel': _buildDetailChip(
        label: 'Phone',
        value: tel ?? 'N/A',
        icon: Icons.phone,
      ),
      'titleid': _buildDetailChip(
        label: 'Title ID',
        value: titleid?.toString() ?? 'N/A',
        icon: Icons.title,
      ),
      'positionid': _buildDetailChip(
        label: 'Position ID',
        value: positionid?.toString() ?? 'N/A',
        icon: Icons.work,
      ),
      'cadreid': _buildDetailChip(
        label: 'Cadre ID',
        value: cadreid?.toString() ?? 'N/A',
        icon: Icons.group,
      ),
      'specialityid': _buildDetailChip(
        label: 'Speciality',
        value: specialityName ?? 'N/A',
        icon: Icons.star,
      ),
      'classeid': _buildDetailChip(
        label: 'Classe ID',
        value: classeid?.toString() ?? 'N/A',
        icon: Icons.class_,
      ),
      'regionid': _buildDetailChip(
        label: 'Region ID',
        value: regionid?.toString() ?? 'N/A',
        icon: Icons.location_on,
      ),
      'subregionid': _buildDetailChip(
        label: 'Subregion ID',
        value: subregionid?.toString() ?? 'N/A',
        icon: Icons.location_city,
      ),
      'location': _buildDetailChip(
        label: 'Location',
        value: location ?? 'N/A',
        icon: Icons.place,
      ),
      'categoryid': _buildDetailChip(
        label: 'Category ID',
        value: categoryid?.toString() ?? 'N/A',
        icon: Icons.category,
      ),
      'created_at': Text(
        'Added: ${createdAt?.toLocal().toString().split(' ')[0] ?? 'N/A'}',
        style: const TextStyle(fontSize: 14, color: Colors.grey),
      ),
      'last_appointment': _buildDetailChip(
        label: 'Last Appointment',
        value: lastAppointment != null
            ? DateFormat('yyyy-MM-dd HH:mm').format(lastAppointment!)
            : 'N/A',
        icon: Icons.calendar_today,
      ),
      'times_seen_month': _buildDetailChip(
        label: 'Times Seen (Month)',
        value: timesSeenMonth?.toString() ?? '0',
        icon: Icons.event,
      ),
      'times_seen_quarter': _buildDetailChip(
        label: 'Times Seen (Quarter)',
        value: timesSeenQuarter?.toString() ?? '0',
        icon: Icons.event_note,
      ),
      'times_seen_year': _buildDetailChip(
        label: 'Times Seen (Year)',
        value: timesSeenYear?.toString() ?? '0',
        icon: Icons.event_available,
      ),
    };

    final fieldsToRender = displayFields ??
        [
          'name',
          'email',
          'tel',
          'titleid',
          'positionid',
          'cadreid',
          'specialityid',
          'classeid',
          'regionid',
          'subregionid',
          'location',
          'categoryid',
          'created_at',
          'last_appointment',
          'times_seen_month',
          'times_seen_quarter',
          'times_seen_year',
        ];

    if (fieldsToRender.contains('name') && allPossibleFieldWidgets.containsKey('name')) {
      widgets.add(allPossibleFieldWidgets['name']!);
      widgets.add(const SizedBox(height: 4));
    }
    if (fieldsToRender.contains('email') && allPossibleFieldWidgets.containsKey('email')) {
      widgets.add(allPossibleFieldWidgets['email']!);
      widgets.add(const SizedBox(height: 8));
    }

    final List<Widget> chips = [];
    for (final field in fieldsToRender) {
      if (field != 'name' && field != 'email' && allPossibleFieldWidgets.containsKey(field)) {
        final Widget fieldWidget = allPossibleFieldWidgets[field]!;
        if (fieldWidget is Chip || fieldWidget is SizedBox) {
          chips.add(fieldWidget);
        } else {
          widgets.add(fieldWidget);
          widgets.add(const SizedBox(height: 4));
        }
      }
    }

    if (chips.isNotEmpty) {
      widgets.add(Wrap(
        spacing: 12.0,
        runSpacing: 6.0,
        children: chips,
      ));
    }

    if (widgets.isNotEmpty && widgets.last is! SizedBox) {
      widgets.add(const SizedBox(height: 4));
    }

    return widgets;
  }
}

class PersonsListPage extends StatefulWidget {
  const PersonsListPage({super.key});

  @override
  State<PersonsListPage> createState() => _PersonsListPageState();
}

class _PersonsListPageState extends State<PersonsListPage> {
  List<Person> _persons = [];
  List<Person> _filteredPersons = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSearching = false;
  String? _selectedColor;
  final TextEditingController _searchController = TextEditingController();
  final String _phpEndpoint = '${Config.sisiUrl}/persons/getPersons.php';

  static const Map<String, Color> _colorOptions = {
    'All': Colors.transparent,
    'Green': Color(0xFFEBFCEB), // Extremely Pale Green
    'Blue': Color(0xFFF0F9FC),  // Extremely Pale Blue
    'Amber': Color(0xFFFFFBE9), // Extremely Pale Amber
    'Red': Color(0xFFFFF3F5),   // Extremely Pale Red
  };

  @override
  void initState() {
    super.initState();
    _fetchPersons();
    _searchController.addListener(_filterPersons);
  }

  Future<void> _fetchPersons() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;
      final employeeid = sessionProvider.currentUser?.employeeid;
      final agentid = sessionProvider.currentUser?.agentid;

      print(_phpEndpoint);
      final response = await http.get(
        Uri.parse(_phpEndpoint+'?employeeid='+employeeid!+'&agentid='+agentid!),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          setState(() {
            _persons = (responseData['data'] as List<dynamic>)
                .map((json) => Person.fromJson(json))
                .toList();

            _filteredPersons = _persons;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = responseData['message'] ?? 'Failed to fetch persons';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching persons: $e';
      });
    }
  }

  void _filterPersons() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPersons = _persons.where((person) {
        final name = person.name?.toLowerCase() ?? '';
        final email = person.email?.toLowerCase() ?? '';
        final tel = person.tel?.toLowerCase() ?? '';
        final location = person.location?.toLowerCase() ?? '';
        final speciality = person.specialityName?.toLowerCase() ?? '';

        final matchesText = name.contains(query) ||
            email.contains(query) ||
            tel.contains(query) ||
            location.contains(query) ||
            speciality.contains(query);

        // Color-based filtering
        final matchesColor = _selectedColor == null ||
            _selectedColor == 'All' ||
            (person.cardColor != null &&
                person.cardColor!.value == _colorOptions[_selectedColor]!.value);

        return matchesText && matchesColor;

      }).toList();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredPersons = _persons;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
          tooltip: 'Back to Home',
        ),
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search by name, email, phone, location, or speciality...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Config.backgroundColor?.withOpacity(0.1) ?? Colors.grey[800]!.withOpacity(0.1),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear, color: Colors.white70),
              onPressed: () {
                _searchController.clear();
                _filterPersons();
              },
            )
                : null,
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (value) => _filterPersons(),
        )
            : const Text('Persons'),
        backgroundColor: Config.backgroundColor ?? Colors.blueGrey,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Cancel' : 'Search',
            onPressed: _toggleSearch,
          ),
          // Add color filter dropdown
          DropdownButton<String>(
            value: _selectedColor ?? 'All',
            onChanged: (String? newValue) {
              setState(() {
                _selectedColor = newValue;
                _filterPersons();
              });
            },
            items: _colorOptions.keys.map((String colorName) {
              return DropdownMenuItem<String>(
                value: colorName,
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      color: _colorOptions[colorName],
                    ),
                    const SizedBox(width: 8),
                    Text(colorName),
                  ],
                ),
              );
            }).toList(),
            underline: const SizedBox(),
            icon: const Icon(Icons.filter_list, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? _buildShimmerList()
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchPersons,
              style: ElevatedButton.styleFrom(
                backgroundColor: Config.themeColor,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _filteredPersons.isEmpty
          ? const Center(child: Text('No persons available.'))
          : ListView.builder(
        itemCount: _filteredPersons.length,
        itemBuilder: (context, index) {
          final person = _filteredPersons[index];
          print("COLOR: ${person.name}: ${person.cardColor}");
          return Card(
            color: person.cardColor,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: person.photoUrl != null
                    ? NetworkImage(person.photoUrl!)
                    : null,
                child: person.photoUrl == null
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
                backgroundColor: Colors.grey[200],
              ),
              title: Text(
                person.name ?? 'N/A',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.tel ?? 'N/A'),
                  // const SizedBox(height: 1),
                  Text(
                    'Last Seen: ${person.lastAppointment}',
                    style: TextStyle(fontSize: 13),
                  ),
                  Text(
                    'Speciality: ${person.specialityName?.trim() ?? 'N/A'}',
                    style: TextStyle(fontSize: 13),
                  ),
                  Text(
                    'Location: ${person.location ?? 'N/A'}',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
              onTap: () {
                  Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PersonDetailsPage(person: person),
                   ),
                  );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/addPerson').then((value) {
            if (value == true) {
              _fetchPersons();
            }
          });
        },
        backgroundColor: Config.themeColor,
        tooltip: 'Add New Person',
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.white),
            title: Container(
              height: 16,
              color: Colors.white,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  color: Colors.white,
                ),
                const SizedBox(height: 4),
                Container(
                  height: 10,
                  color: Colors.white,
                ),
                const SizedBox(height: 4),
                Container(
                  height: 10,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}