import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';

// Model class for a single Facility
class Facility {
  final int? id;
  final String? name;
  final int? regionid;
  final int? subregionid;
  final String? location;
  final String? longitude;
  final String? latitude;
  final String? address;
  final String? email;
  final String? tel;
  final int? facilitytypeid;
  final String? keyaccounts;
  final int? matrixid;
  final int? employeeid;
  final int? agentid;
  final int? customerid;
  final String? remarks;
  final int? status;
  final String? ipaddress;
  final int? createdby;
  final DateTime? createdon;
  final int? lasteditedby;
  final DateTime? lasteditedon;
  final String? category;
  final String? regionName;
  final String? subregionName;
  final List<String>? displayFields;
  final Color? cardColor;

  Facility({
    this.id,
    this.name,
    this.regionid,
    this.subregionid,
    this.location,
    this.longitude,
    this.latitude,
    this.address,
    this.email,
    this.tel,
    this.facilitytypeid,
    this.keyaccounts,
    this.matrixid,
    this.employeeid,
    this.agentid,
    this.customerid,
    this.remarks,
    this.status,
    this.ipaddress,
    this.createdby,
    this.createdon,
    this.lasteditedby,
    this.lasteditedon,
    this.category,
    this.regionName,
    this.subregionName,
    this.displayFields,
    this.cardColor,
  });

  factory Facility.fromJson(Map<String, dynamic> json) {
    Color? parseColor(String? hexColor) {
      if (hexColor == null || hexColor.isEmpty) return null;
      try {
        final hex = hexColor.replaceFirst('#', '');
        final intColor = int.parse(hex, radix: 16);
        return Color(hex.length == 6 ? (0xFF000000 | intColor) : intColor);
      } catch (e) {
        return null;
      }
    }

    return Facility(
      id: json['id'] is num ? (json['id'] as num).toInt() : null,
      name: json['name'] as String? ?? 'N/A',
      regionid: json['regionid'] is num ? (json['regionid'] as num).toInt() : null,
      subregionid: json['subregionid'] is num ? (json['subregionid'] as num).toInt() : null,
      location: json['location'] as String? ?? 'N/A',
      longitude: json['longitude'] as String? ?? 'N/A',
      latitude: json['latitude'] as String? ?? 'N/A',
      address: json['address'] as String? ?? 'N/A',
      email: json['email'] as String? ?? 'N/A',
      tel: json['tel'] as String? ?? 'N/A',
      facilitytypeid: json['facilitytypeid'] is num ? (json['facilitytypeid'] as num).toInt() : 2,
      keyaccounts: json['keyaccounts'] as String? ?? 'N/A',
      matrixid: json['matrixid'] is num ? (json['matrixid'] as num).toInt() : null,
      employeeid: json['employeeid'] is num ? (json['employeeid'] as num).toInt() : null,
      agentid: json['agentid'] is num ? (json['agentid'] as num).toInt() : null,
      customerid: json['customerid'] is num ? (json['customerid'] as num).toInt() : null,
      remarks: json['remarks'] as String? ?? 'N/A',
      status: json['status'] is num ? (json['status'] as num).toInt() : 0,
      ipaddress: json['ipaddress'] as String? ?? 'N/A',
      createdby: json['createdby'] is num ? (json['createdby'] as num).toInt() : null,
      createdon: DateTime.tryParse(json['createdon'] as String? ?? '') ?? DateTime.now(),
      lasteditedby: json['lasteditedby'] is num ? (json['lasteditedby'] as num).toInt() : null,
      lasteditedon: DateTime.tryParse(json['lasteditedon'] as String? ?? '') ?? DateTime.now(),
      category: json['category'] as String? ?? 'A',
      regionName: json['region_name'] as String? ?? 'N/A',
      subregionName: json['subregion_name'] as String? ?? 'N/A',
      displayFields: json['displayFields'] != null
          ? List<String>.from(json['displayFields'] as List)
          : null,
      cardColor: parseColor(json['cardColor'] as String?),
    );
  }

  get photoUrl => null;

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
      'regionName': _buildDetailChip(
        label: 'Region',
        value: regionName ?? 'N/A',
        icon: Icons.location_on,
      ),
      'subregionName': _buildDetailChip(
        label: 'Subregion',
        value: subregionName ?? 'N/A',
        icon: Icons.location_city,
      ),
      'category': _buildDetailChip(
        label: 'Category',
        value: category ?? 'N/A',
        icon: Icons.category,
      ),
      'createdon': Text(
        'Created: ${createdon?.toLocal().toString().split(' ')[0] ?? 'N/A'}',
        style: const TextStyle(fontSize: 14, color: Colors.grey),
      ),
    };

    final fieldsToRender = displayFields ??
        [
          'name',
          'email',
          'tel',
          'regionName',
          'subregionName',
          'category',
          'createdon',
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

class FacilityListPage extends StatefulWidget {
  const FacilityListPage({super.key});

  @override
  State<FacilityListPage> createState() => _FacilityListPageState();
}

class _FacilityListPageState extends State<FacilityListPage> {
  List<Facility> _facilities = [];
  List<Facility> _filteredFacilities = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchFacilities();
    _searchController.addListener(_filterFacilities);
  }

  Future<void> _fetchFacilities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;

      final response = await http.get(
        Uri.parse('${Config.sisiUrl}/facilitys/getFacilitys.php'),
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
            _facilities = (responseData['data'] as List<dynamic>)
                .map((json) => Facility.fromJson(json))
                .toList();
            _filteredFacilities = _facilities;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = responseData['message'] ?? 'Failed to fetch facilities';
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
        _errorMessage = 'Error fetching facilities: $e';
      });
    }
  }

  void _filterFacilities() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFacilities = _facilities.where((facility) {
        final name = facility.name?.toLowerCase() ?? '';
        final email = facility.email?.toLowerCase() ?? '';
        final tel = facility.tel?.toLowerCase() ?? '';
        final regionName = facility.regionName?.toLowerCase() ?? '';
        final subregionName = facility.subregionName?.toLowerCase() ?? '';
        final category = facility.category?.toLowerCase() ?? '';
        return name.contains(query) ||
            email.contains(query) ||
            tel.contains(query) ||
            regionName.contains(query) ||
            subregionName.contains(query) ||
            category.contains(query);
      }).toList();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredFacilities = _facilities;
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
            hintText: 'Search by name, email, phone, region, subregion, or category...',
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
                _filterFacilities();
              },
            )
                : null,
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (value) => _filterFacilities(),
        )
            : const Text('Facilities'),
        backgroundColor: Config.backgroundColor ?? Colors.blueGrey,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Cancel' : 'Search',
            onPressed: _toggleSearch,
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
              onPressed: _fetchFacilities,
              style: ElevatedButton.styleFrom(
                backgroundColor: Config.themeColor,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _filteredFacilities.isEmpty
          ? const Center(child: Text('No facilities available.'))
          : ListView.builder(
        itemCount: _filteredFacilities.length,
        itemBuilder: (context, index) {
          final facility = _filteredFacilities[index];
          return Card(
            color: facility.cardColor ?? Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: facility.photoUrl != null
                    ? NetworkImage(facility.photoUrl!)
                    : null,
                child: facility.photoUrl == null
                    ? const Icon(Icons.business, color: Colors.grey)
                    : null,
                backgroundColor: Colors.grey[200],
              ),
              title: Text(
                facility.name ?? 'N/A',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(facility.email ?? 'N/A'),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/facility-details',
                  arguments: facility,
                ).then((value) {
                  if (value == true) {
                    _fetchFacilities();
                  }
                });
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/addFacility').then((value) {
            if (value == true) {
              _fetchFacilities();
            }
          });
        },
        backgroundColor: Config.themeColor,
        tooltip: 'Add New Facility',
        child: const Icon(Icons.add_business),
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
            subtitle: Container(
              height: 12,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}