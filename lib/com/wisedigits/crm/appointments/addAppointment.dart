import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import '../models/appointments.dart';
import '../models/rating.dart'; // Import the Rating model

class AddAppointmentPage extends StatefulWidget {
  final Appointment? appointment;

  const AddAppointmentPage({super.key, this.appointment});

  @override
  State<AddAppointmentPage> createState() => _AddAppointmentPageState();
}

class _AddAppointmentPageState extends State<AddAppointmentPage> {
  final _formKey = GlobalKey<FormState>();
  String? _entityType = 'person';
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

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final employeeid = sessionProvider.currentUser?.employeeid;

    await Future.wait([
      _fetchEntityList(
        endpoint: '${Config.sisiUrl}/facilitys/getFacilitys.php?employeeid=$employeeid',
        listSetter: (list) => _facilities = list.cast<Facility>(),
        fromJson: Facility.fromJson,
      ),
      _fetchEntityList(
        endpoint: '${Config.sisiUrl}/persons/getPersons.php?employeeid=$employeeid',
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
      final employeeid = sessionProvider.currentUser?.employeeid;
      final userid = sessionProvider.currentUser?.userid;

      final body = {
        'type': _entityType == 'facility' ? 'physical' : 'remote',
        'facilityid': _selectedFacility?.id.toString(),
        'personid': _selectedPerson?.id.toString(),
        'employeeid': employeeid,
        'action': 'Add',
        'appointmentdate': _appointmentDate != null
            ? DateFormat('yyyy-MM-dd').format(_appointmentDate!)
            : null,
        'appointmenttime': _appointmentTime != null
            ? _appointmentTime!.format(context)
            : null,
        'status': '0',
        'userid': userid,
      };

      final isEdit = widget.appointment != null;
      final response = await http.post(
        Uri.parse(isEdit
            ? '${Config.sisiUrl}/appointments/create.php?id=${widget.appointment!.id}'
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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

class UpdateAppointmentPage extends StatefulWidget {
  final Appointment appointment;
  final List<Product> selectedProductIds;

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
  final ScrollController _scrollActionController = ScrollController();
  final ScrollController _scrollReactionController = ScrollController();
  final ScrollController _scrollFollowupController = ScrollController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _facilityNameController = TextEditingController();
  final TextEditingController _followupController = TextEditingController();
  String? _rating;
  bool _isLoading = true;
  String? _errorMessage;
  String? _latitude;
  String? _longitude;
  List<Rating> _ratings = [];

  @override
  void initState() {
    super.initState();
    _actionController.text = widget.appointment.action ?? '';
    _reactionController.text = widget.appointment.reaction ?? '';
    _locationController.text = widget.appointment.location ?? 'Fetching landmark...';
    _facilityNameController.text = widget.appointment.facility?.name ?? '';
    _followupController.text = widget.appointment.followup ?? '';
    _fetchRatings();
    _checkLocationPermission();
  }

  Future<void> _fetchRatings() async {
    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('${Config.sisiUrl}/ratings/getRatings.php'),
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
            _ratings = jsonList.map((json) => Rating.fromJson(json as Map<String, dynamic>)).toList();
            if (widget.appointment.ratingId != null) {
              final selectedRating = _ratings.firstWhere(
                    (rating) => rating.id == widget.appointment.ratingId,
                orElse: () => _ratings.isNotEmpty ? _ratings[0] : Rating(id: 0, name: 'Unknown'),
              );
              _rating = selectedRating.name;
            } else if (_ratings.isNotEmpty) {
              _rating = _ratings[0].name;
            }
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to load ratings';
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
        _errorMessage = 'Error fetching ratings: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkLocationPermission() async {
    const Duration retryInterval = Duration(seconds: 5); // Time between retries
    int attempt = 0;

    while (mounted) {
      attempt++;
      print('Location retry attempt #$attempt at ${DateTime.now()}'); // Debug log

      try {
        // Add timeout to prevent Geolocator from hanging
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Location service check timed out'),
        );
        if (!serviceEnabled) {
          setState(() {
            _errorMessage = 'Location services are disabled. Retrying in $retryInterval... (Attempt #$attempt)';
            _locationController.text = widget.appointment.location ?? 'Location unavailable';
            _isLoading = false;
          });
          await Future.delayed(retryInterval);
          continue; // Retry after delay
        }

        LocationPermission permission = await Geolocator.checkPermission().timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('Permission check timed out'),
        );
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission().timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('Permission request timed out'),
          );
          if (permission == LocationPermission.denied) {
            setState(() {
              _errorMessage = 'Location permissions are denied. Retrying in $retryInterval... (Attempt #$attempt)';
              _locationController.text = widget.appointment.location ?? 'Location unavailable';
              _isLoading = false;
            });
            await Future.delayed(retryInterval);
            continue; // Retry after delay
          }
        }

        if (permission == LocationPermission.deniedForever) {
          setState(() {
            _errorMessage = 'Location permissions are permanently denied.';
            _locationController.text = widget.appointment.location ?? 'Location unavailable';
            _isLoading = false;
          });
          print('Permanently denied, stopping retries'); // Debug log
          return; // Exit if permissions are permanently denied
        }

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Location fetch timed out'),
        );
        setState(() {
          _latitude = position.latitude.toString();
          _longitude = position.longitude.toString();
          _isLoading = false; // Stop loading once location is found
          _errorMessage = null; // Clear error message on success
        });
        print('Location fetched: (${position.latitude}, ${position.longitude})'); // Debug log

        await _fetchLandmark(position.latitude, position.longitude);
        print('Landmark fetched successfully'); // Debug log
        return; // Exit the loop if location is successfully fetched
      } catch (e) {
        if (!mounted) {
          print('Widget not mounted, stopping retries'); // Debug log
          return;
        }
        setState(() {
          _errorMessage = 'Error getting location: $e. Retrying in $retryInterval... (Attempt #$attempt)';
          _locationController.text = widget.appointment.location ?? 'Error fetching landmark';
          _isLoading = false;
        });
        print('Error in attempt #$attempt: $e'); // Debug log
        await Future.delayed(retryInterval);
      }
    }
    print('Widget disposed, stopping retries'); // Debug log
  }

  Future<void> _fetchLandmark(double latitude, double longitude) async {
    final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1';

    print(url);
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'MyFlutterApp/1.0 (mugogatheru@gmail.com)', // Replace with your app name and contact email
        },
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] == null && data['display_name'] != null) {
          final address = data['display_name'] as String?;
          setState(() {
            _locationController.text = address ?? widget.appointment.location ?? 'Unknown landmark';
          });
        } else {
          setState(() {
            _errorMessage = 'Nominatim error: ${data['error'] ?? 'No address found'}';
            _locationController.text = widget.appointment.location ?? 'Unable to fetch landmark';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Nominatim request failed: HTTP ${response.statusCode}';
          _locationController.text = widget.appointment.location ?? 'Error fetching landmark';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error fetching landmark: $e';
        _locationController.text = widget.appointment.location ?? 'Error fetching landmark';
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
      final userId = sessionProvider.currentUser?.userid;

      final selectedRating = _ratings.firstWhere(
            (rating) => rating.name == _rating,
        orElse: () => Rating(id: 0, name: 'Unknown'),
      );

      final body = {
        'action': _actionController.text,
        'id': widget.appointment.id,
        'reaction': _reactionController.text,
        'followup': _followupController.text,
        'ratingid': selectedRating.id.toString(),
        'landmark': _locationController.text,
        'facilityname': _facilityNameController.text,
        'type': _locationType,
        'latitude': _latitude,
        'longitude': _longitude,
        'products': widget.selectedProductIds.map((product) => product.id).toList(),
        'actionButton': 'Update',
        'userid': userId,
      };

      String url = '${Config.sisiUrl}/appointments/create.php?id=${widget.appointment.id}';
      print(url);

      final response = await http.post(
        Uri.parse(url),
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
    _locationController.dispose();
    _facilityNameController.dispose();
    _followupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProductNames = widget.selectedProductIds.map((product) => product.name).toList();

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
          child: ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
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
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: RawScrollbar(
                  controller: _scrollActionController, // Attach the ScrollController
                  thumbColor: Config.themeColor ?? Colors.blue,
                  radius: const Radius.circular(8),
                  thickness: 8, // Thicker scrollbar
                  thumbVisibility: true, // Always show scrollbar when content overflows
                  child: SingleChildScrollView(
                    controller: _scrollActionController, // Attach the same ScrollController to SingleChildScrollView
                    child: TextFormField(
                      controller: _actionController,
                      decoration: InputDecoration(
                        labelText: 'Action',
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description, color: Config.themeColor ?? Colors.blue),
                      ),
                      maxLines: null,
                      minLines: 3,
                      keyboardType: TextInputType.multiline,
                      scrollPhysics: const AlwaysScrollableScrollPhysics(),
                      validator: (value) => value == null || value.isEmpty ? 'Action is required' : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _rating,
                decoration: InputDecoration(
                  labelText: 'Rating',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.star, color: Config.themeColor ?? Colors.blue),
                ),
                items: _ratings
                    .map((rating) => DropdownMenuItem(
                  value: rating.name,
                  child: Text(rating.name),
                ))
                    .toList(),
                onChanged: (value) => setState(() => _rating = value),
                validator: (value) => value == null ? 'Rating is required' : null,
                hint: _ratings.isEmpty ? const Text('Loading ratings...') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _facilityNameController,
                decoration: InputDecoration(
                  labelText: 'Facility Name',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business, color: Config.themeColor ?? Colors.blue),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: RawScrollbar(
                  controller: _scrollReactionController, // Attach the ScrollController
                  thumbColor: Config.themeColor ?? Colors.blue,
                  radius: const Radius.circular(8),
                  thickness: 8, // Thicker scrollbar
                  thumbVisibility: true, // Always show scrollbar when content overflows
                  child: SingleChildScrollView(
                    controller: _scrollReactionController, // Attach the same ScrollController to SingleChildScrollView
                    child: TextFormField(
                      controller: _reactionController,
                      decoration: InputDecoration(
                        labelText: 'Reaction',
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(Icons.comment, color: Config.themeColor ?? Colors.blue),
                      ),
                      maxLines: null,
                      minLines: 3,
                      keyboardType: TextInputType.multiline,
                      scrollPhysics: const AlwaysScrollableScrollPhysics(),
                      validator: (value) => value == null || value.isEmpty ? 'Reaction is required' : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: RawScrollbar(
                  controller: _scrollFollowupController, // Attach the ScrollController
                  thumbColor: Config.themeColor ?? Colors.blue,
                  radius: const Radius.circular(8),
                  thickness: 8, // Thicker scrollbar
                  thumbVisibility: true, // Always show scrollbar when content overflows
                  child: SingleChildScrollView(
                    controller: _scrollFollowupController, // Attach the same ScrollController to SingleChildScrollView
                    child: TextFormField(
                      controller: _followupController,
                      decoration: InputDecoration(
                        labelText: 'Follow-up',
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(Icons.follow_the_signs, color: Config.themeColor ?? Colors.blue),
                      ),
                      maxLines: null,
                      minLines: 3,
                      keyboardType: TextInputType.multiline,
                      scrollPhysics: const AlwaysScrollableScrollPhysics(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                selectedProductNames.isNotEmpty
                    ? 'Selected Products: ${selectedProductNames.join(', ')}'
                    : 'No products selected',
                style: TextStyle(
                  color: selectedProductNames.isNotEmpty ? Colors.black : Colors.red,
                  fontSize: 16,
                  fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.place, color: Config.themeColor ?? Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nearest Landmark',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _locationController.text.isNotEmpty
                                ? _locationController.text
                                : widget.appointment.location ?? 'Unknown landmark',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: _locationController.text.isNotEmpty ? Colors.black : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateAppointment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Config.themeColor ?? Colors.blue,
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