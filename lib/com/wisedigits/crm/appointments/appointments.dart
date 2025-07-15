import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:developer' as developer;

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import '../models/appointments.dart';
import 'addAppointment.dart';

// Constants for better maintainability
const String _appointmentsEndpoint = '${Config.sisiUrl}/appointments/getAppointments.php';
const Duration _requestTimeout = Duration(seconds: 15);
const Duration _searchDebounceDuration = Duration(milliseconds: 300);

class AppointmentListPage extends StatefulWidget {
  const AppointmentListPage({super.key});

  @override
  State<AppointmentListPage> createState() => _AppointmentListPageState();
}

class _AppointmentListPageState extends State<AppointmentListPage> {
  List<Appointment> _appointments = [];
  List<Appointment> _filteredAppointments = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSearching = false;
  bool _isRetrying = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
    _searchController.addListener(_debouncedFilterAppointments);
  }

  // Fetch appointments and compute metrics
  Future<void> _fetchAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;

      final response = await http
          .get(
        Uri.parse(_appointmentsEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      )
          .timeout(_requestTimeout, onTimeout: () {
        throw TimeoutException('Request timed out');
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic responseData = jsonDecode(response.body);
        developer.log('API Response: $responseData', name: 'AppointmentListPage._fetchAppointments');

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
            _appointments = [];
            _filteredAppointments = [];
            _isLoading = false;
            _errorMessage = 'No appointments available';
          });
          return;
        }

        // Compute metrics
        final now = DateTime.now();
        final currentMonth = now.month;
        final currentYear = now.year;
        final currentQuarter = (currentMonth - 1) ~/ 3 + 1;

        final appointments = jsonList.map((json) {
          try {
            return Appointment.fromJson(json as Map<String, dynamic>);
          } catch (e) {
            developer.log('Error parsing appointment: $e, JSON: $json', name: 'AppointmentListPage._fetchAppointments');
            return null;
          }
        }).where((appt) => appt != null && appt.id != 0).cast<Appointment>().toList();

        if (appointments.isEmpty) {
          setState(() {
            _appointments = [];
            _filteredAppointments = [];
            _isLoading = false;
            _errorMessage = 'No valid appointments found after parsing';
          });
          return;
        }

        final Map<String, List<Appointment>> groupedByEntity = {};
        for (var appt in appointments) {
          final key = appt.facility?.name ?? appt.person?.name ?? '';
          if (key.isNotEmpty) {
            groupedByEntity.putIfAbsent(key, () => []).add(appt);
          }
        }

        for (var appt in appointments) {
          final key = appt.facility?.name ?? appt.person?.name ?? '';
          if (key.isNotEmpty) {
            final entityAppointments = groupedByEntity[key]!;
            final pastAppointments = entityAppointments
                .where((a) => a.id != appt.id)
                .toList()
              ..sort((a, b) => DateTime.parse(b.appointmentDate ?? '1970-01-01')
                  .compareTo(DateTime.parse(a.appointmentDate ?? '1970-01-01')));
            final lastSeen = pastAppointments.isNotEmpty
                ? pastAppointments.first.appointmentDate
                : null;
            final lastSeenBy = pastAppointments.isNotEmpty
                ? pastAppointments.first.employee?.name
                : null;
            final timesThisMonth = entityAppointments
                .where((a) {
              final date = DateTime.tryParse(a.appointmentDate ?? '');
              return date != null &&
                  date.month == currentMonth &&
                  date.year == currentYear;
            })
                .length;
            final timesThisQuarter = entityAppointments
                .where((a) {
              final date = DateTime.tryParse(a.appointmentDate ?? '');
              return date != null &&
                  date.year == currentYear &&
                  ((date.month - 1) ~/ 3 + 1) == currentQuarter;
            })
                .length;
            final timesThisYear = entityAppointments
                .where((a) {
              final date = DateTime.tryParse(a.appointmentDate ?? '');
              return date != null && date.year == currentYear;
            })
                .length;

            appt = Appointment(
              id: appt.id,
              appointmentId: appt.appointmentId,
              type: appt.type,
              facility: appt.facility,
              person: appt.person,
              personScheduleId: appt.personScheduleId,
              employee: appt.employee,
              agentId: appt.agentId,
              appointmentDate: appt.appointmentDate,
              appointmentTime: appt.appointmentTime,
              action: appt.action,
              reaction: appt.reaction,
              ratingId: appt.ratingId,
              followup: appt.followup,
              locale: appt.locale,
              location: appt.location,
              longitude: appt.longitude,
              latitude: appt.latitude,
              status: appt.status,
              rescheduled: appt.rescheduled,
              remarks: appt.remarks,
              ipAddress: appt.ipAddress,
              createdBy: appt.createdBy,
              createdOn: appt.createdOn,
              lastEditedBy: appt.lastEditedBy,
              lastEditedOn: appt.lastEditedOn,
              missingTitle: appt.missingTitle,
              missingContent: appt.missingContent,
              app: appt.app,
              currentLocation: appt.currentLocation,
              lastSeenDate: lastSeen ?? appt.lastSeenDate,
              lastSeenBy: lastSeenBy ?? appt.lastSeenBy,
              timesSeenThisMonth: timesThisMonth,
              timesSeenThisQuarter: timesThisQuarter,
              timesSeenThisYear: timesThisYear,
              color: appt.color,
            );
          }
        }

        setState(() {
          _appointments = appointments;
          _filteredAppointments = _appointments;
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
      developer.log('Error in _fetchAppointments: $e', name: 'AppointmentListPage');
      setState(() {
        _isLoading = false;
        _errorMessage = e is TimeoutException
            ? 'Network timeout. Please check your connection.'
            : 'Error fetching appointments: $e';
      });
    }
  }

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return Colors.grey[50]!; // Default fallback
    }
    try {
      // Handle named colors
      const colorMap = {
        'red': Colors.red,
        'green': Colors.green,
        'blue': Colors.blue,
        'grey': Colors.grey,
        'black': Colors.black,
        'white': Colors.white,
      };
      if (colorMap.containsKey(colorString.toLowerCase())) {
        return colorMap[colorString.toLowerCase()]! ?? Colors.grey[50]!;
      }
      // Handle hex colors (e.g., "#FF0000")
      if (colorString.startsWith('#')) {
        final hex = colorString.replaceFirst('#', '');
        final intValue = int.parse(hex, radix: 16);
        return Color(intValue + 0xFF000000); // Add alpha channel
      }
      return Colors.grey[50]!; // Fallback for invalid colors
    } catch (e) {
      developer.log('Error parsing color: $colorString, $e', name: 'AppointmentListPage._parseColor');
      return Colors.grey[50]!; // Fallback on error
    }
  }

  // Debounced search
  void _debouncedFilterAppointments() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(_searchDebounceDuration, _filterAppointments);
  }

  // Filter appointments by multiple fields
  void _filterAppointments() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAppointments = _appointments.where((appt) {
        final facilityName = appt.facility?.name.toLowerCase() ?? '';
        final personName = appt.person?.name.toLowerCase() ?? '';
        final date = appt.appointmentDate?.toLowerCase() ?? '';
        final type = appt.type?.toLowerCase() ?? '';
        final location = appt.location?.toLowerCase() ?? '';
        final lastSeenDate = appt.lastSeenDate?.toLowerCase() ?? '';
        final lastSeenBy = appt.lastSeenBy?.toLowerCase() ?? '';
        final timesSeenMonth = appt.timesSeenThisMonth.toString();
        final timesSeenQuarter = appt.timesSeenThisQuarter.toString();
        final timesSeenYear = appt.timesSeenThisYear.toString();
        return facilityName.contains(query) ||
            personName.contains(query) ||
            date.contains(query) ||
            type.contains(query) ||
            location.contains(query) ||
            lastSeenDate.contains(query) ||
            lastSeenBy.contains(query) ||
            timesSeenMonth.contains(query) ||
            timesSeenQuarter.contains(query) ||
            timesSeenYear.contains(query);
      }).toList();
    });
  }

  // Toggle search bar
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredAppointments = _appointments;
      }
    });
  }

  // --- Extracted Widgets ---

  Widget _buildAppBarTitle() {
    return _isSearching
        ? Semantics(
      label: 'Search appointments',
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search by facility, person, date, type, etc...',
          border: InputBorder.none,
          hintStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Config.backgroundColor?.withOpacity(0.1) ?? Colors.grey[800]!.withOpacity(0.1),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          suffixIcon: _searchController.text.isNotEmpty
              ? Semantics(
            label: 'Clear search',
            child: IconButton(
              icon: const Icon(Icons.clear, color: Colors.white70),
              onPressed: () => _searchController.clear(),
            ),
          )
              : null,
        ),
        style: const TextStyle(color: Colors.white),
        textInputAction: TextInputAction.search,
      ),
    )
        : const Text('Appointments');
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            label: 'Error icon',
            child: Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: 'Error message',
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            label: 'Retry button',
            child: ElevatedButton.icon(
              onPressed: _isRetrying
                  ? null
                  : () async {
                setState(() => _isRetrying = true);
                await _fetchAppointments();
                setState(() => _isRetrying = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Config.themeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _isRetrying
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            label: 'No appointments icon',
            child: Icon(Icons.event_note, size: 80, color: Colors.grey[400]),
          ),
          const SizedBox(height: 20),
          const Text(
            'No appointments found.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          const Text(
            'Looks like there are no scheduled visits yet.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Semantics(
            label: 'Schedule new appointment button',
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddAppointmentPage()),
                ).then((value) {
                  if (value == true) _fetchAppointments();
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Schedule New Appointment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Config.themeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentListItem(BuildContext context, Appointment appointment) {
    final color = appointment.type == 'physical' ? Colors.green[50] : Colors.blue[50];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 4,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AppointmentDetailsPage(appointment: appointment),
            ),
          ).then((value) {
            if (value == true) _fetchAppointments();
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Align(
              //   alignment: Alignment.topRight,
              //   child: Chip(
              //     label: Text(
              //       appointment.type?.toUpperCase() ?? 'UNKNOWN',
              //       style: TextStyle(
              //         color: appointment.type == 'physical'
              //             ? Colors.green[800]
              //             : Colors.blue[800],
              //         fontWeight: FontWeight.bold,
              //       ),
              //     ),
              //     backgroundColor: appointment.type == 'physical'
              //         ? Colors.green[100]
              //         : Colors.blue[100],
              //     materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              //   ),
              // ),
              const SizedBox(height: 8),
              Semantics(
                label: 'Appointment name: ${appointment.facility?.name ?? appointment.person?.name ?? "Unknown"}',
                child: Text(
                  appointment.facility?.name ?? appointment.person?.name ?? 'Unknown Appointment',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _parseColor(appointment.color),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    appointment.appointmentDate ?? 'N/A',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    appointment.appointmentTime ?? 'N/A',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              if (appointment.location?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.place, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          appointment.location!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (appointment.lastSeenDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Last Seen: ${appointment.lastSeenDate}',
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (appointment.lastSeenBy != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Last Seen By: ${appointment.lastSeenBy}',
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.repeat, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Times Seen: ${appointment.timesSeenThisMonth} (Month), ${appointment.timesSeenThisQuarter} (Quarter), ${appointment.timesSeenThisYear} (Year)',
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      width: 80,
                      height: 24,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(width: 18, height: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Container(width: 100, height: 16, color: Colors.white),
                      const SizedBox(width: 16),
                      Container(width: 18, height: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Container(width: 80, height: 16, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(width: 18, height: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Container(width: 150, height: 16, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(width: 18, height: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Container(width: 120, height: 16, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(width: 18, height: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Container(width: 200, height: 16, color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_debouncedFilterAppointments);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        backgroundColor: Config.backgroundColor ?? Colors.blueGrey,
        foregroundColor: Colors.white,
        leading: Semantics(
          label: 'Back to home screen',
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            tooltip: 'Home',
          ),
        ),
        actions: [
          Semantics(
            label: _isSearching ? 'Cancel search' : 'Search appointments',
            child: IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: _toggleSearch,
              tooltip: _isSearching ? 'Cancel' : 'Search',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAppointments,
        child: _isLoading
            ? _buildShimmerList()
            : _errorMessage != null
            ? _buildErrorState()
            : _filteredAppointments.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
          itemCount: _filteredAppointments.length,
          itemBuilder: (context, index) {
            final appointment = _filteredAppointments[index];
            return _buildAppointmentListItem(context, appointment);
          },
        ),
      ),
      floatingActionButton: Semantics(
        label: 'Add new appointment',
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddAppointmentPage()),
            ).then((value) {
              if (value == true) _fetchAppointments();
            });
          },
          backgroundColor: Config.themeColor,
          tooltip: 'Schedule New Appointment',
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}