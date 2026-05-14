import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:developer' as developer;

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import '../models/appointments.dart';
import 'ProductSelection.dart';
import 'addAppointment.dart';

class AppointmentDetailsPage extends StatefulWidget {
  final Appointment appointment;
  final Appointment? lastAppointment; // Optional last appointment from AppointmentListPage

  const AppointmentDetailsPage({
    super.key,
    required this.appointment,
    this.lastAppointment,
  });

  @override
  State<AppointmentDetailsPage> createState() => _AppointmentDetailsPageState();
}

class _AppointmentDetailsPageState extends State<AppointmentDetailsPage> {
  Appointment? _fetchedAppointment;
  Appointment? _fetchedLastAppointment;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAppointmentDetails();
  }

  // Fetch appointment details using GET request with parameters from the passed appointment
  Future<void> _fetchAppointmentDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;
      final employeeid = sessionProvider.currentUser?.employeeid;

      // Construct query parameters using the passed appointment's fields
      final queryParameters = {
        'lastAppointment': "1",
        'appointmentId': widget.appointment.appointmentId.toString(),
        // Add additional parameters if available
        if (widget.appointment.facility?.id != null)
          'facilityId': widget.appointment.facility!.id.toString(),
        if (widget.appointment.person?.id != null)
          'personId': widget.appointment.person!.id.toString(),
        if (widget.appointment.appointmentDate != null)
          'appointmentDate': widget.appointment.appointmentDate!,
        'employeeid': employeeid,
      };

      final uri = Uri.parse('${Config.sisiUrl}/appointments/getAppointments.php?employeeid=$employeeid')
          .replace(queryParameters: queryParameters);

      developer.log('Fetching appointment with URL: $uri', name: 'AppointmentDetailsPage');

      final response = await http
          .get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      )
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Request timed out');
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic responseData = jsonDecode(response.body);
        developer.log('API Response: $responseData', name: 'AppointmentDetailsPage._fetchAppointmentDetails');

        List<dynamic> jsonList;
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true &&
            responseData['data'] != null) {
          jsonList = responseData['data'] as List<dynamic>;
        } else if (responseData is List) {
          jsonList = responseData;
        } else {
          throw FormatException('Invalid response format: $responseData');
        }

        if (jsonList.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No appointment data found';
          });
          return;
        }

        // Parse the current appointment
        final appointmentData = jsonList.firstWhere(
              (json) => json['appointmentId'] == widget.appointment.appointmentId,
          orElse: () => null,
        );

        if (appointmentData == null) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Appointment not found';
          });
          return;
        }

        final fetchedAppointment = Appointment.fromJson(appointmentData as Map<String, dynamic>);

        // Determine the last appointment for the same entity
        Appointment? fetchedLastAppointment;
        final entityKey = fetchedAppointment.facility?.name ?? fetchedAppointment.person?.name ?? '';
        if (entityKey.isNotEmpty) {
          final entityAppointments = jsonList
              .map((json) => Appointment.fromJson(json as Map<String, dynamic>))
              .where((appt) =>
          (appt.facility?.name ?? appt.person?.name ?? '') == entityKey &&
              appt.appointmentId != fetchedAppointment.appointmentId)
              .toList()
            ..sort((a, b) => DateTime.parse(b.appointmentDate ?? '1970-01-01')
                .compareTo(DateTime.parse(a.appointmentDate ?? '1970-01-01')));

          fetchedLastAppointment = entityAppointments.isNotEmpty ? entityAppointments.first : null;
        }

        setState(() {
          _fetchedAppointment = fetchedAppointment;
          _fetchedLastAppointment = fetchedLastAppointment ?? widget.lastAppointment;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      developer.log('Error in _fetchAppointmentDetails: $e', name: 'AppointmentDetailsPage');
      setState(() {
        _isLoading = false;
        _errorMessage = e is TimeoutException
            ? 'Network timeout. Please check your connection.'
            : 'Error fetching appointment details: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use fetched data if available, otherwise fallback to widget.appointment
    final displayAppointment = _fetchedAppointment ?? widget.appointment;
    final displayLastAppointment = _fetchedLastAppointment ?? widget.lastAppointment ?? widget.appointment;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
        backgroundColor: Config.backgroundColor ?? Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _fetchAppointmentDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Config.themeColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Name: ',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: displayAppointment.facility?.name ?? displayAppointment.person?.name ?? "Unknown",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Date: ',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: displayAppointment.appointmentDate ?? "N/A",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Type: ',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: displayAppointment.type ?? "N/A",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Location: ',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: displayAppointment.location ?? "N/A",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Action: ',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: displayAppointment.action ?? "N/A",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Reaction: ',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: displayAppointment.reaction ?? "N/A",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Rating: ',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: displayAppointment.ratingId != null ? ["Firm", "Commitment", "No"][displayAppointment.ratingId! - 1] : "N/A",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Follow-up: ',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: displayAppointment.followup ?? "N/A",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Products: ',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: displayAppointment.products ?? "N/A",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductSelectionPage(appointment: displayLastAppointment),
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
      ),
    );
  }
}