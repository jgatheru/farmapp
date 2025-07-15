import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import '../models/appointments.dart';

class AddAppointmentPage extends StatefulWidget {
  final Appointment? appointment;

  const AddAppointmentPage({super.key, this.appointment});

  @override
  State<AddAppointmentPage> createState() => _AddAppointmentPageState();
}

class _AddAppointmentPageState extends State<AddAppointmentPage> {
  final _formKey = GlobalKey<FormState>();
  String? _entityType = 'facility'; // Default to facility
  Facility? _selectedFacility;
  Person? _selectedPerson;
  DateTime? _appointmentDate;
  TimeOfDay? _appointmentTime;
  final TextEditingController _entityController = TextEditingController();
  List<Facility> _facilities = [];
  List<Person> _persons = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.appointment != null) {
      _entityType = widget.appointment!.facility != null ? 'facility' : 'person';
      _selectedFacility = widget.appointment!.facility;
      _selectedPerson = widget.appointment!.person;
      _entityController.text = widget.appointment!.facility?.name ?? widget.appointment!.person?.name ?? '';
      _appointmentDate = widget.appointment!.appointmentDate != null
          ? DateTime.tryParse(widget.appointment!.appointmentDate!)
          : null;
      _appointmentTime = widget.appointment!.appointmentTime != null
          ? TimeOfDay.fromDateTime(DateTime.parse('1970-01-01 ${widget.appointment!.appointmentTime}'))
          : null;
    }
    _fetchEntities();
  }

  Future<void> _fetchEntities() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchEntityList(
        endpoint: '${Config.sisiUrl}/facilitys/getFacilitys.php',
        listSetter: (list) => _facilities = list.cast<Facility>(),
        fromJson: Facility.fromJson,
      ),
      _fetchEntityList(
        endpoint: '${Config.sisiUrl}/persons/getPersons.php',
        listSetter: (list) => _persons = list.cast<Person>(),
        fromJson: Person.fromJson,
      ),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchEntityList({
    required String endpoint,
    required void Function(List<dynamic>) listSetter,
    required dynamic Function(Map<String, dynamic>) fromJson,
  }) async {
    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${sessionProvider.currentUser?.token}',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> jsonList = responseData['data'];
          setState(() {
            listSetter(jsonList.map((json) => fromJson(json as Map<String, dynamic>)).toList());
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to load data from $endpoint';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error fetching data: $e';
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _appointmentDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _appointmentDate) {
      setState(() {
        _appointmentDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _appointmentTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _appointmentTime) {
      setState(() {
        _appointmentTime = picked;
      });
    }
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;

      final body = {
        'type': _entityType == 'facility' ? 'physical' : 'remote',
        'facilityid': _selectedFacility?.id.toString(),
        'personid': _selectedPerson?.id.toString(),
        'appointmentdate': _appointmentDate != null
            ? DateFormat('yyyy-MM-dd').format(_appointmentDate!)
            : null,
        'appointmenttime': _appointmentTime != null
            ? _appointmentTime!.format(context)
            : null,
        'status': '0',
      };

      final isEdit = widget.appointment != null;
      final response = await http.post(
        Uri.parse(isEdit
            ? '${Config.sisiUrl}/appointments/${widget.appointment!.id}'
            : '${Config.sisiUrl}/appointments/create.php'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to ${isEdit ? 'update' : 'add'} appointment: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error ${widget.appointment != null ? 'updating' : 'adding'} appointment: $e';
      });
    }
  }

  @override
  void dispose() {
    _entityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appointment != null ? 'Edit Appointment' : 'Add Appointment'),
        backgroundColor: Config.backgroundColor ?? Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Facility'),
                      value: 'facility',
                      groupValue: _entityType,
                      onChanged: (value) {
                        setState(() {
                          _entityType = value;
                          _selectedFacility = null;
                          _selectedPerson = null;
                          _entityController.clear();
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Person'),
                      value: 'person',
                      groupValue: _entityType,
                      onChanged: (value) {
                        setState(() {
                          _entityType = value;
                          _selectedFacility = null;
                          _selectedPerson = null;
                          _entityController.clear();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final query = textEditingValue.text.toLowerCase();
                  if (_entityType == 'facility') {
                    return _facilities
                        .where((facility) => facility.name.toLowerCase().contains(query))
                        .map((facility) => facility.name)
                        .toList();
                  } else {
                    return _persons
                        .where((person) => person.name.toLowerCase().contains(query))
                        .map((person) => person.name)
                        .toList();
                  }
                },
                onSelected: (String selection) {
                  if (_entityType == 'facility') {
                    _selectedFacility = _facilities.firstWhere((f) => f.name == selection);
                    _selectedPerson = null;
                  } else {
                    _selectedPerson = _persons.firstWhere((p) => p.name == selection);
                    _selectedFacility = null;
                  }
                  _entityController.text = selection;
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  _entityController.text = controller.text;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: _entityType == 'facility' ? 'Facility' : 'Person',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(
                        _entityType == 'facility' ? Icons.business : Icons.person,
                        color: Config.themeColor,
                      ),
                    ),
                    validator: (value) => value!.isEmpty
                        ? '${_entityType == 'facility' ? 'Facility' : 'Person'} is required'
                        : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Appointment Date',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today, color: Config.themeColor),
                ),
                controller: TextEditingController(
                  text: _appointmentDate != null
                      ? DateFormat('yyyy-MM-dd').format(_appointmentDate!)
                      : '',
                ),
                onTap: () => _selectDate(context),
                validator: (value) => _appointmentDate == null ? 'Date is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Appointment Time',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time, color: Config.themeColor),
                ),
                controller: TextEditingController(
                  text: _appointmentTime != null ? _appointmentTime!.format(context) : '',
                ),
                onTap: () => _selectTime(context),
                validator: (value) => _appointmentTime == null ? 'Time is required' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveAppointment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Config.themeColor,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(widget.appointment != null ? 'Update Appointment' : 'Add Appointment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Placeholder for AppointmentDetailsPage (extend as needed)
class AppointmentDetailsPage extends StatelessWidget {
  final Appointment appointment;

  const AppointmentDetailsPage({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
        backgroundColor: Config.backgroundColor ?? Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name: ${appointment.facility?.name ?? appointment.person?.name ?? "Unknown"}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Date: ${appointment.appointmentDate ?? "N/A"}'),
            Text('Type: ${appointment.type ?? "N/A"}'),
            Text('Location: ${appointment.location ?? "N/A"}'),
            Text('Action: ${appointment.action ?? "N/A"}'),
            Text('Reaction: ${appointment.reaction ?? "N/A"}'),
            Text('Rating: ${appointment.ratingId != null ? ["Firm", "Commitment", "No"][appointment.ratingId! - 1] : "N/A"}'),
            Text('Follow-up: ${appointment.followup ?? "N/A"}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductSelectionPage(appointment: appointment),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Config.themeColor,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Proceed'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductSelectionPage extends StatefulWidget {
  final Appointment appointment;

  const ProductSelectionPage({super.key, required this.appointment});

  @override
  State<ProductSelectionPage> createState() => _ProductSelectionPageState();
}

class _ProductSelectionPageState extends State<ProductSelectionPage> {
  List<Product> _products = [];
  List<int> _selectedProductIds = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('${Config.sisiUrl}/products/getProducts.php'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${sessionProvider.currentUser?.token}',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          setState(() {
            _products = (responseData['data'] as List<dynamic>)
                .map((json) => Product.fromJson(json as Map<String, dynamic>))
                .toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to load products';
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
        _errorMessage = 'Error fetching products: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Products'),
        backgroundColor: Config.backgroundColor ?? Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return CheckboxListTile(
                  title: Text(product.name),
                  value: _selectedProductIds.contains(product.id),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedProductIds.add(product.id);
                      } else {
                        _selectedProductIds.remove(product.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UpdateAppointmentPage(
                      appointment: widget.appointment,
                      selectedProductIds: _selectedProductIds,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Config.themeColor,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Proceed to Update'),
            ),
          ),
        ],
      ),
    );
  }
}

class UpdateAppointmentPage extends StatefulWidget {
  final Appointment appointment;
  final List<int> selectedProductIds;

  const UpdateAppointmentPage({
    super.key,
    required this.appointment,
    required this.selectedProductIds,
  });

  @override
  State<UpdateAppointmentPage> createState() => _UpdateAppointmentPageState();
}

class _UpdateAppointmentPageState extends State<UpdateAppointmentPage> {
  final _formKey = GlobalKey<FormState>();
  String? _locationType = 'physical';
  final TextEditingController _actionController = TextEditingController();
  final TextEditingController _reactionController = TextEditingController();
  final TextEditingController _followupController = TextEditingController();
  String? _rating = 'Firm';
  bool _isLoading = false;
  String? _errorMessage;
  String? _latitude;
  String? _longitude;

  @override
  void initState() {
    super.initState();
    _actionController.text = widget.appointment.action ?? '';
    _reactionController.text = widget.appointment.reaction ?? '';
    _followupController.text = widget.appointment.followup ?? '';
    _rating = widget.appointment.ratingId != null
        ? ['Firm', 'Commitment', 'No'][widget.appointment.ratingId! - 1]
        : 'Firm';
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _errorMessage = 'Location services are disabled. Please enable them.';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMessage = 'Location permissions are denied.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _errorMessage = 'Location permissions are permanently denied.';
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latitude = position.latitude.toString();
        _longitude = position.longitude.toString();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting location: $e';
      });
    }
  }

  Future<void> _updateAppointment() async {
    if (!_formKey.currentState!.validate() || _latitude == null || _longitude == null) {
      setState(() {
        _errorMessage = _latitude == null || _longitude == null
            ? 'Location not available. Please enable location services.'
            : 'Please fill all required fields';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;

      final body = {
        'action': _actionController.text,
        'reaction': _reactionController.text,
        'ratingid': {'Firm': 1, 'Commitment': 2, 'No': 3}[_rating],
        'followup': _followupController.text,
        'location': _locationType,
        'latitude': _latitude,
        'longitude': _longitude,
        'products': widget.selectedProductIds,
      };

      final response = await http.post(
        Uri.parse('${Config.sisiUrl}/appointments/${widget.appointment.id}/update.php'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.pop(context, true);
        Navigator.pop(context, true);
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to update appointment: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error updating appointment: $e';
      });
    }
  }

  @override
  void dispose() {
    _actionController.dispose();
    _reactionController.dispose();
    _followupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Appointment'),
        backgroundColor: Config.backgroundColor ?? Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Physical'),
                      value: 'physical',
                      groupValue: _locationType,
                      onChanged: (value) => setState(() => _locationType = value),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Remote'),
                      value: 'remote',
                      groupValue: _locationType,
                      onChanged: (value) => setState(() => _locationType = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _actionController,
                decoration: InputDecoration(
                  labelText: 'Action',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description, color: Config.themeColor),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reactionController,
                decoration: InputDecoration(
                  labelText: 'Reaction',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.comment, color: Config.themeColor),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _rating,
                decoration: InputDecoration(
                  labelText: 'Rating',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.star, color: Config.themeColor),
                ),
                items: ['Firm', 'Commitment', 'No']
                    .map((rating) => DropdownMenuItem(value: rating, child: Text(rating)))
                    .toList(),
                onChanged: (value) => setState(() => _rating = value),
                validator: (value) => value == null ? 'Rating is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _followupController,
                decoration: InputDecoration(
                  labelText: 'Follow-up',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.follow_the_signs, color: Config.themeColor),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateAppointment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Config.themeColor,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Update Appointment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}