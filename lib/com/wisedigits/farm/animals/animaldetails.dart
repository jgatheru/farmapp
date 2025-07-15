import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart'; // Import fl_chart
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import 'animals.dart'; // Contains Animal, FeedingRecord, HealthRecord, ProductionRecord models
import 'addAnimals.dart'; // Adjust path as per your project structure (ManageAnimalPage)

// Data model for the graph points (simplified)
class DailySummary {
  final DateTime date;
  final double production;
  final double consumption;

  DailySummary(this.date, this.production, this.consumption);
}

class AnimalDetailsPage extends StatefulWidget {
  final Animal animal;

  const AnimalDetailsPage({super.key, required this.animal});

  @override
  State<AnimalDetailsPage> createState() => _AnimalDetailsPageState();
}

class _AnimalDetailsPageState extends State<AnimalDetailsPage> {
  late Animal _currentAnimal; // To hold the animal data, potentially updated
  bool _isLoadingGraphData = false;
  String? _graphErrorMessage;

  // Data for the graph
  List<DailySummary> _dailyData = [];
  DateTime _graphStartDate = DateTime.now().subtract(const Duration(days: 6)); // Last 7 days
  DateTime _graphEndDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentAnimal = widget.animal; // Initialize with the passed animal
    _fetchGraphData(); // Fetch initial graph data
  }

  // Helper method for fetching aggregated feeding records (consumption)
  Future<List<FeedingRecord>> _fetchFeedingRecordsForAnimal(
      int animalId, DateTime fromDate, DateTime toDate) async {
    try {
      final String formattedFromDate = DateFormat('yyyy-MM-dd').format(fromDate);
      final String formattedToDate = DateFormat('yyyy-MM-dd').format(toDate);
      final url =
          '${Config.baseUrl}/feedingrecords/getFeedingRecords.php?farm_animal_id=$animalId&from_date=$formattedFromDate&to_date=$formattedToDate'; // Adjust endpoint as needed

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> recordsData = responseData['body'];
          return recordsData.map((json) => FeedingRecord.fromJson(json)).toList();
        } else {
          print('Failed to load feeding records: ${responseData['message']}');
          return [];
        }
      } else {
        print('Server error fetching feeding records: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching feeding records: $e');
      return [];
    }
  }

  // Helper method for fetching aggregated production records (production)
  Future<List<ProductionRecord>> _fetchProductionRecordsForAnimal(
      int animalId, DateTime fromDate, DateTime toDate) async {
    try {
      final String formattedFromDate = DateFormat('yyyy-MM-dd').format(fromDate);
      final String formattedToDate = DateFormat('yyyy-MM-dd').format(toDate);
      final url =
          '${Config.baseUrl}/milkproduction/getProductions.php?farm_animal_id=$animalId&from_date=$formattedFromDate&to_date=$formattedToDate'; // Adjust endpoint

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> recordsData = responseData['body'];
          return recordsData.map((json) => ProductionRecord.fromJson(json)).toList();
        } else {
          print('Failed to load production records: ${responseData['message']}');
          return [];
        }
      } else {
        print('Server error fetching production records: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching production records: $e');
      return [];
    }
  }

  Future<void> _fetchGraphData() async {
    setState(() {
      _isLoadingGraphData = true;
      _graphErrorMessage = null;
      _dailyData = []; // Clear previous data
    });

    try {
      // Fetch both feeding and production records for the last 7 days
      final List<FeedingRecord> feedingRecords = await _fetchFeedingRecordsForAnimal(
          _currentAnimal.animalId, _graphStartDate, _graphEndDate);
      final List<ProductionRecord> productionRecords = await _fetchProductionRecordsForAnimal(
          _currentAnimal.animalId, _graphStartDate, _graphEndDate);

      // Aggregate data by date
      Map<DateTime, double> dailyProduction = {};
      Map<DateTime, double> dailyConsumption = {};

      for (var record in productionRecords) {
        final dateKey = DateTime(record.date.year, record.date.month, record.date.day);
        dailyProduction[dateKey] = (dailyProduction[dateKey] ?? 0.0) + record.quantity;
      }

      for (var record in feedingRecords) {
        final dateKey = DateTime(record.date.year, record.date.month, record.date.day);
        dailyConsumption[dateKey] = (dailyConsumption[dateKey] ?? 0.0) + record.quantity;
      }

      // Populate _dailyData for the past 7 days
      List<DailySummary> newData = [];
      for (int i = 0; i < 7; i++) {
        final date = _graphStartDate.add(Duration(days: i));
        final dateKey = DateTime(date.year, date.month, date.day);
        newData.add(DailySummary(
          dateKey,
          dailyProduction[dateKey] ?? 0.0,
          dailyConsumption[dateKey] ?? 0.0,
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

  // Widget to display a specific metric
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
                    fontSize: 16, fontWeight: FontWeight.bold, color: color),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get current month and year for filtering
    final DateTime now = DateTime.now();
    final int currentMonth = now.month;
    final int currentYear = now.year;

    // Filter production records for the current month
    final List<ProductionRecord> currentMonthProductionRecords =
    _currentAnimal.productionRecords.where((record) {
      return record.date.month == currentMonth && record.date.year == currentYear;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentAnimal.tagNumber),
        backgroundColor: Config.backgroundColor, // Assuming Config.backgroundColor is defined
        foregroundColor: Colors.white,
        actions: [
          // Edit Button in the AppBar
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              // Navigate to ManageAnimalPage and await result
              final bool? updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ManageAnimalPage(animal: _currentAnimal),
                ),
              );

              // If updated is true, it means data was changed and we should refresh
              if (updated == true) {
                if (mounted) {
                  // Re-fetch the animal data to get the latest details
                  // This is a simplified re-fetch; in a real app, you might pass the updated animal back
                  // Or have a centralized data management solution.
                  await _fetchAnimalDataById(_currentAnimal.animalId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${_currentAnimal.tagNumber} details updated!')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No changes made to ${_currentAnimal.tagNumber}.')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                    backgroundImage: _currentAnimal.photoUrl != null && _currentAnimal.photoUrl!.isNotEmpty
                        ? NetworkImage(_currentAnimal.photoUrl!)
                        : null,
                    child: _currentAnimal.photoUrl == null || _currentAnimal.photoUrl!.isEmpty
                        ? Icon(Icons.pets, size: 60, color: Colors.grey[600])
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentAnimal.tagNumber,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Config.themeColor,
                    ),
                  ),
                  Text(
                    '${_currentAnimal.species} (${_currentAnimal.breed ?? 'N/A'})',
                    style: const TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: [
                      Chip(
                        avatar: Icon(
                          _currentAnimal.gender == 'Male' ? Icons.male : Icons.female,
                          color: _currentAnimal.gender == 'Male' ? Colors.blue : Colors.pink,
                        ),
                        label: Text(_currentAnimal.gender),
                      ),
                      Chip(
                        avatar: Icon(Icons.cake, color: Colors.brown),
                        label: Text(DateFormat('yyyy-MM-dd').format(_currentAnimal.birthDate)),
                      ),
                      Chip(
                        avatar: Icon(Icons.info_outline, color: _currentAnimal.status == 'active' ? Colors.green : Colors.red),
                        label: Text(_currentAnimal.status),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Key Metrics / Summary Cards
            Row(
              children: [
                _buildMetricCard(
                  'Weight',
                  '${_currentAnimal.weight} KG',
                  Icons.scale,
                  Colors.blue.shade700,
                ),
                _buildMetricCard(
                  'Avg. Prod.',
                  '${_currentAnimal.production.toStringAsFixed(1)} L/Day', // Adjust based on your 'production' field meaning
                  Icons.local_drink,
                  Colors.green.shade700,
                ),
                _buildMetricCard(
                  'Age',
                  _getAgeString(_currentAnimal.birthDate),
                  Icons.calendar_month,
                  Colors.orange.shade700,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Production vs Consumption Graph
            Text(
              'Daily Production vs. Consumption (Last 7 Days)',
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
                  height: 250, // Height for the graph
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
                      ? const Center(
                    child: Text('No graph data available.'),
                  )
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
                              // Show date labels for each day
                              final date = _graphStartDate.add(Duration(days: value.toInt()));
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: 8.0,
                                child: Text(DateFormat('dd/MM').format(date),
                                    style: const TextStyle(fontSize: 10)),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true, reservedSize: 40),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: const Color(0xff37434d), width: 1),
                      ),
                      minX: 0,
                      maxX: 6, // 7 days (0 to 6)
                      minY: 0,
                      maxY: _getMaxYValue(_dailyData), // Dynamic max Y
                      lineBarsData: [
                        // Production Line
                        LineChartBarData(
                          spots: _dailyData
                              .asMap()
                              .entries
                              .map((entry) => FlSpot(
                              entry.key.toDouble(), entry.value.production))
                              .toList(),
                          isCurved: true,
                          color: Colors.green,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(show: false),
                        ),
                        // Consumption Line
                        LineChartBarData(
                          spots: _dailyData
                              .asMap()
                              .entries
                              .map((entry) => FlSpot(
                              entry.key.toDouble(), entry.value.consumption))
                              .toList(),
                          isCurved: true,
                          color: Colors.red,
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
                    Text('ID: ${_currentAnimal.animalId}',
                        style: const TextStyle(fontSize: 16)),
                    Text('Tag: ${_currentAnimal.tagNumber}',
                        style: const TextStyle(fontSize: 16)),
                    Text('Species: ${_currentAnimal.species} (${_currentAnimal.breed ?? 'N/A'})',
                        style: const TextStyle(fontSize: 16)),
                    Text('Gender: ${_currentAnimal.gender}',
                        style: const TextStyle(fontSize: 16)),
                    Text('Weight: ${_currentAnimal.weight} KG',
                        style: const TextStyle(fontSize: 16)),
                    Text(
                        'Born: ${DateFormat('yyyy-MM-dd').format(_currentAnimal.birthDate)}',
                        style: const TextStyle(fontSize: 16)),
                    if (_currentAnimal.acquisitionDate != null)
                      Text(
                          'Acquired: ${DateFormat('yyyy-MM-dd').format(_currentAnimal.acquisitionDate!)}',
                          style: const TextStyle(fontSize: 16)),
                    if (_currentAnimal.acquisitionCost != null)
                      Text(
                          'Cost: \$${_currentAnimal.acquisitionCost!.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 16)),
                    Text('Status: ${_currentAnimal.status}',
                        style: const TextStyle(fontSize: 16)),
                    if (_currentAnimal.shadeId != null)
                      Text('Shade ID: ${_currentAnimal.shadeId}',
                          style: const TextStyle(fontSize: 16)),
                    Text(
                        'Added: ${_currentAnimal.createdAt.toLocal().toString().split(' ')[0]}',
                        style:
                        const TextStyle(fontSize: 16, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Expansion Tiles for records
            _buildRecordsExpansionTile(
              title: 'Feeding Records',
              records: _currentAnimal.feedingRecords,
              emptyMessage: 'No feeding records available.',
              itemBuilder: (record) => ListTile(
                title: Text('Feed: ${record.feedType}', style: const TextStyle(fontSize: 16)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quantity: ${record.quantity} KG', style: const TextStyle(fontSize: 14)),
                    Text('Date: ${DateFormat('yyyy-MM-dd').format(record.date)}', style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildRecordsExpansionTile(
              title: 'Health Records',
              records: _currentAnimal.healthRecords,
              emptyMessage: 'No health records available.',
              itemBuilder: (record) => ListTile(
                title: Text('Condition: ${record.condition}', style: const TextStyle(fontSize: 16)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Treatment: ${record.treatment}', style: const TextStyle(fontSize: 14)),
                    Text('Date: ${DateFormat('yyyy-MM-dd').format(record.date)}', style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Production Records for Current Month
            _buildRecordsExpansionTile(
              title: 'Production Records (${DateFormat('MMMM yyyy').format(now)})',
              records: currentMonthProductionRecords,
              emptyMessage: 'No production records for the current month.',
              itemBuilder: (record) => ListTile(
                title: Text('${record.productionType}: ${record.quantity} ${record.productionType == 'Milk' ? 'Liters' : (record.productionType == 'Eggs' ? 'Eggs' : 'Units')}',
                    style: const TextStyle(fontSize: 16)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date: ${DateFormat('yyyy-MM-dd').format(record.date)}', style: const TextStyle(fontSize: 14)),
                    if (record.notes != null && record.notes!.isNotEmpty)
                      Text('Notes: ${record.notes}', style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to determine age string
  String _getAgeString(DateTime birthDate) {
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;
    int days = now.day - birthDate.day;

    if (days < 0) {
      months--;
      days += DateTime(now.year, now.month, 0).day; // Days in previous month
    }
    if (months < 0) {
      years--;
      months += 12;
    }

    if (years > 0) {
      return '$years Yrs';
    } else if (months > 0) {
      return '$months Months';
    } else {
      return '$days Days';
    }
  }

  // Generic helper for building ExpansionTiles for records
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

  // Helper to get max Y value for the graph, adding some padding
  double _getMaxYValue(List<DailySummary> data) {
    if (data.isEmpty) return 10.0; // Default
    double maxProd = data.map((e) => e.production).reduce((a, b) => a > b ? a : b);
    double maxCons = data.map((e) => e.consumption).reduce((a, b) => a > b ? a : b);
    double overallMax = maxProd > maxCons ? maxProd : maxCons;
    return (overallMax * 1.2).ceilToDouble(); // 20% padding and ceil to nearest int
  }

  // Method to re-fetch animal data after an update
  Future<void> _fetchAnimalDataById(int animalId) async {

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    try {
      final url = '${Config.baseUrl}/animals/getAnimalById.php?animal_id=$animalId'; // Assuming you have this endpoint
      final response = await http.get(
          Uri.parse(url),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          setState(() {
            _currentAnimal = Animal.fromJson(responseData['data']);
          });
          _fetchGraphData(); // Also refresh graph data if animal details changed
        } else {
          print('Failed to re-fetch animal: ${responseData['message']}');
          // Optionally, show a snackbar or handle error
        }
      } else {
        print('Server error re-fetching animal: ${response.statusCode}');
      }
    } catch (e) {
      print('Error re-fetching animal data: $e');
    }
  }
}