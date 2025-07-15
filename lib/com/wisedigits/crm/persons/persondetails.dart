import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import 'addPersons.dart';
import 'persons.dart';

class TaskSummary {
  final DateTime date;
  final int taskCount;

  TaskSummary(this.date, this.taskCount);
}

class PersonDetailsPage extends StatefulWidget {
  final Person person;

  const PersonDetailsPage({super.key, required this.person});

  @override
  State<PersonDetailsPage> createState() => _PersonDetailsPageState();
}

class _PersonDetailsPageState extends State<PersonDetailsPage> {
  late Person _currentPerson;
  bool _isLoading = false;
  bool _isLoadingGraphData = false;
  String? _errorMessage;
  String? _graphErrorMessage;

  List<TaskSummary> _dailyData = [];
  DateTime _graphStartDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _graphEndDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentPerson = widget.person;
    _fetchGraphData();
  }

  Future<List<TaskRecord>> _fetchTaskRecordsForPerson(
      int personId, DateTime fromDate, DateTime toDate) async {
    try {
      final String formattedFromDate = DateFormat('yyyy-MM-dd').format(fromDate);
      final String formattedToDate = DateFormat('yyyy-MM-dd').format(toDate);
      final url =
          '${Config.baseUrl}/modules/persons/tasks?person_id=$personId&from_date=$formattedFromDate&to_date=$formattedToDate';

      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> recordsData = responseData['body'] ?? responseData['data'];
          return recordsData.map((json) => TaskRecord.fromJson(json)).toList();
        } else {
          print('Failed to load task records: ${responseData['message']}');
          return [];
        }
      } else {
        print('Server error fetching task records: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching task records: $e');
      return [];
    }
  }

  Future<void> _fetchGraphData() async {
    setState(() {
      _isLoadingGraphData = true;
      _graphErrorMessage = null;
      _dailyData = [];
    });

    try {
      final List<TaskRecord> taskRecords = await _fetchTaskRecordsForPerson(
          _currentPerson.id!, _graphStartDate, _graphEndDate);

      Map<DateTime, int> dailyTaskCount = {};
      for (var record in taskRecords) {
        final dateKey = DateTime(record.date.year, record.date.month, record.date.day);
        dailyTaskCount[dateKey] = (dailyTaskCount[dateKey] ?? 0) + 1;
      }

      List<TaskSummary> newData = [];
      for (int i = 0; i < 7; i++) {
        final date = _graphStartDate.add(Duration(days: i));
        final dateKey = DateTime(date.year, date.month, date.day);
        newData.add(TaskSummary(
          dateKey,
          dailyTaskCount[dateKey] ?? 0,
        ));
      }

      setState(() {
        _dailyData = newData;
        _isLoadingGraphData = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGraphData = false;
          _graphErrorMessage = 'Failed to load graph data: $e';
        });
      }
      print('Error fetching graph data: $e');
    }
  }

  Future<void> _fetchPersonDataById(int personId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;

      if (authToken == null) {
        throw Exception('User not authenticated');
      }

      final url = '${Config.baseUrl}/modules/persons/$personId';
      final response = await http.get(
        Uri.parse(url),
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
            _currentPerson = Person.fromJson(responseData['data']);
            _isLoading = false;
          });
          _fetchGraphData();
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = responseData['message'] ?? 'Failed to fetch person data';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessage!)),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Server error fetching person: ${response.statusCode}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching person data: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    }
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordsExpansionTile<T>({
    required String title,
    required List<T> records,
    required String emptyMessage,
    required Widget Function(T) itemBuilder,
  }) {
    return ExpansionTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Config.themeColor,
        ),
      ),
      children: records.isEmpty
          ? [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(emptyMessage,
              style: const TextStyle(fontSize: 16, color: Colors.grey)),
        )
      ]
          : records.map((record) => itemBuilder(record)).toList(),
    );
  }

  double _getMaxYValue(List<TaskSummary> data) {
    if (data.isEmpty) return 10.0;
    int maxTasks = data.map((e) => e.taskCount).reduce((a, b) => a > b ? a : b);
    return (maxTasks * 1.2).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPerson.name ?? 'No Name'),
        backgroundColor: Config.backgroundColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final bool? updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddPersonPage(person: _currentPerson),
                ),
              );

              if (updated == true && mounted) {
                await _fetchPersonDataById(_currentPerson.id!);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${_currentPerson.name} details updated!')),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No changes made to ${_currentPerson.name}.')),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Config.themeColor))
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _fetchPersonDataById(_currentPerson.id!),
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar and Basic Info
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _currentPerson.photoUrl != null &&
                        _currentPerson.photoUrl!.isNotEmpty
                        ? NetworkImage(_currentPerson.photoUrl!)
                        : null,
                    child: _currentPerson.photoUrl == null ||
                        _currentPerson.photoUrl!.isEmpty
                        ? Icon(Icons.person, size: 60, color: Colors.grey[600])
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentPerson.name ?? 'No Name',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Config.themeColor,
                    ),
                  ),
                  Text(
                    _currentPerson.email ?? 'N/A',
                    style: const TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: [
                      Chip(
                        avatar: Icon(Icons.phone, color: Colors.blue),
                        label: Text(_currentPerson.tel ?? 'N/A'),
                      ),
                      Chip(
                        avatar: Icon(Icons.work, color: Colors.green),
                        label: Text(_currentPerson.positionid?.toString() ?? 'N/A'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Key Metrics
            Row(
              children: [
                _buildMetricCard(
                  'ID',
                  _currentPerson.id?.toString() ?? 'N/A',
                  Icons.perm_identity,
                  Colors.blue.shade700,
                ),
                _buildMetricCard(
                  'Email',
                  _currentPerson.email != null ? 'Available' : 'N/A',
                  Icons.email,
                  Colors.green.shade700,
                ),
                _buildMetricCard(
                  'Tasks',
                  _currentPerson.taskRecords.length.toString(),
                  Icons.task,
                  Colors.orange.shade700,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Task Activity Graph
            Text(
              'Task Activity (Last 7 Days)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Config.themeColor,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  height: 250,
                  child: _isLoadingGraphData
                      ? Center(child: CircularProgressIndicator(color: Config.themeColor))
                      : _graphErrorMessage != null
                      ? Center(
                    child: Text(
                      _graphErrorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  )
                      : _dailyData.isEmpty
                      ? const Center(child: Text('No task data available.'))
                      : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final date = _graphStartDate
                                  .add(Duration(days: value.toInt()));
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: 8.0,
                                child: Text(
                                  DateFormat('dd/MM').format(date),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(
                          color: const Color(0xff37434d),
                          width: 1,
                        ),
                      ),
                      minX: 0,
                      maxX: 6,
                      minY: 0,
                      maxY: _getMaxYValue(_dailyData),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _dailyData
                              .asMap()
                              .entries
                              .map((entry) => FlSpot(
                            entry.key.toDouble(),
                            entry.value.taskCount.toDouble(),
                          ))
                              .toList(),
                          isCurved: true,
                          color: Colors.blue,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Biodata
            Text(
              'Biodata',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Config.themeColor,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2.0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: ${_currentPerson.id ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16)),
                    Text('Name: ${_currentPerson.name ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16)),
                    Text('Title ID: ${_currentPerson.titleid ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16)),
                    Text('Position ID: ${_currentPerson.positionid ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16)),
                    Text('Cadre ID: ${_currentPerson.cadreid ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16)),
                    Text('Speciality ID: ${_currentPerson.specialityid ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16)),
                    Text('Classe ID: ${_currentPerson.classeid ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16)),
                    Text('Email: ${_currentPerson.email ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16)),
                    Text('Phone: ${_currentPerson.tel ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16)),
                    Text('Region ID: ${_currentPerson.regionid ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16)),
                    Text('Subregion ID: ${_currentPerson.subregionid ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16)),
                    Text('Location: ${_currentPerson.location ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16)),
                    Text('Category ID: ${_currentPerson.categoryid ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16)),
                    Text(
                      'Added: ${_currentPerson.createdAt?.toLocal().toString().split(' ')[0] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Task Records
            _buildRecordsExpansionTile(
              title: 'Task Records',
              records: _currentPerson.taskRecords,
              emptyMessage: 'No task records available.',
              itemBuilder: (record) => ListTile(
                title: Text('Task: ${record?.taskType}',
                    style: const TextStyle(fontSize: 16)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Date: ${DateFormat('yyyy-MM-dd').format(record.date)}',
                        style: const TextStyle(fontSize: 14)),
                    if (record.notes != null && record.notes!.isNotEmpty)
                      Text('Notes: ${record.notes}',
                          style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}