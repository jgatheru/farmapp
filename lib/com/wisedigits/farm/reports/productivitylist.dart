import 'dart:convert';
import 'package:farmapp/com/wisedigits/farm/reports/productivity.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  List<FarmReport> _records = [];
  bool _isLoading = false;
  bool _isLoadingChartData = false;
  String? _errorMessage;
  String? _chartErrorMessage;

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  final String _fetchRecordsEndpoint = '${Config.baseUrl}/reports/farm-productivity/data';
  // final String _fetchChartDataEndpoint = '${Config.baseUrl}/reports/farm-productivity/chart-data';
  final String _fetchChartDataEndpoint = 'http://213.136.81.123/farm/reports/chart.php';

  double _totalProduction = 0.0;
  double _totalConsumption = 0.0;
  double _totalProfit = 0.0;

  // Data for line charts, nested: Map<AnimalName, Map<DateTime, Value>>
  Map<String, Map<DateTime, double>> _chartDataProductionByAnimal = {};
  Map<String, Map<DateTime, double>> _chartDataConsumptionByAnimal = {};
  Map<String, Map<DateTime, double>> _chartDataRatioByAnimal = {};

  String _selectedPeriod = 'daily'; // Default aggregation period
  final List<String> _periods = ['daily', 'weekly', 'monthly', 'annually'];

  String _selectedVariable = 'production'; // Default variable for chart
  final List<String> _variables = ['production', 'consumption', 'productivity_ratio'];

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    _toDate = DateTime(_toDate.year, _toDate.month, _toDate.day);
    _fetchRecords();
    _fetchChartData();
  }

  // Helper to get the start of the week (Monday)
  DateTime _getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  Future<void> _fetchRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _totalProduction = 0.0;
      _totalConsumption = 0.0;
      _totalProfit = 0.0;
    });

    try {
      final Map<String, dynamic> filterData = {
        'from_date': DateFormat('yyyy-MM-dd').format(_fromDate),
        'to_date': DateFormat('yyyy-MM-dd').format(_toDate),
      };

      final Map<String, dynamic> requestBody = {'filter': filterData};

      String url = _fetchRecordsEndpoint;
      url += '?from_date=${DateFormat('yyyy-MM-dd').format(_fromDate)}';
      url += '&to_date=${DateFormat('yyyy-MM-dd').format(_toDate)}';

      print('Fetching records: $url');
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;

      if (authToken == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 100));

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> recordsData = responseData['data'] is List ? responseData['data'] : [];
        setState(() {
          _records = recordsData.map((json) => FarmReport.fromJson(json)).toList();
          _totalProduction = _records.fold(0.0, (sum, record) => sum + record.production);
          _totalConsumption = _records.fold(0.0, (sum, record) => sum + record.consumption);
          _totalProfit = _records.fold(0.0, (sum, record) => sum + record.profit);
        });
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not connect to server: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    }
  }

  Future<void> _fetchChartData() async {
    setState(() {
      _isLoadingChartData = true;
      _chartErrorMessage = null;
      if (_selectedVariable == 'production') {
        _chartDataProductionByAnimal.clear();
      } else if (_selectedVariable == 'consumption') {
        _chartDataConsumptionByAnimal.clear();
      } else {
        _chartDataRatioByAnimal.clear();
      }
    });

    try {
      final Map<String, dynamic> requestBody = {
        'from_date': DateFormat('yyyy-MM-dd').format(_fromDate),
        'to_date': DateFormat('yyyy-MM-dd').format(_toDate),
        'period': _selectedPeriod,
        'variable': _selectedVariable,
      };

      String url = _fetchChartDataEndpoint;
      url += '?from_date=${DateFormat('yyyy-MM-dd').format(_fromDate)}';
      url += '&to_date=${DateFormat('yyyy-MM-dd').format(_toDate)}';
      url += '&period=$_selectedPeriod';
      url += '&variable=$_selectedVariable';

      print('Fetching chart data: $url');
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;

      if (authToken == null) {
        throw Exception('User not authenticated');
      }

      print(url);
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isLoadingChartData = false;
      });

      print(response.body);
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] != true) {
          setState(() {
            _chartErrorMessage = responseData['message'] ?? 'Failed to load chart data';
          });
          return;
        }

        final Map<String, dynamic> chartData = responseData['data'] ?? {};
        Map<String, Map<DateTime, double>> targetChartData = {};

        chartData.forEach((animalName, dataList) {
          if (dataList is List) {
            targetChartData[animalName] = {};
            for (var item in dataList) {
              if (item is Map<String, dynamic> && item['date'] != null && item['value'] != null) {
                DateTime date = DateTime.parse(item['date']);
                // Adjust date based on period for consistency
                if (_selectedPeriod == 'daily') {
                  date = DateTime(date.year, date.month, date.day);
                } else if (_selectedPeriod == 'weekly') {
                  date = _getStartOfWeek(date);
                } else if (_selectedPeriod == 'monthly') {
                  date = DateTime(date.year, date.month, 1);
                } else {
                  date = DateTime(date.year, 1, 1);
                }
                targetChartData[animalName]![date] = (item['value'] as num).toDouble();
              }
            }
          }
        });

        setState(() {
          if (_selectedVariable == 'production') {
            _chartDataProductionByAnimal = targetChartData;
          } else if (_selectedVariable == 'consumption') {
            _chartDataConsumptionByAnimal = targetChartData;
          } else {
            _chartDataRatioByAnimal = targetChartData;
          }
        });
      } else {
        setState(() {
          _chartErrorMessage = 'Server error: ${response.statusCode}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_chartErrorMessage!)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingChartData = false;
        _chartErrorMessage = 'Could not connect to server: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_chartErrorMessage!)),
      );
    }
  }

  Future<void> _showFilterDialog() async {
    final Map<String, dynamic>? filters = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return ReportFilterDialog(
          initialFromDate: _fromDate,
          initialToDate: _toDate,
        );
      },
    );

    if (filters != null) {
      setState(() {
        _fromDate = filters['fromDate'];
        _toDate = filters['toDate'];
      });
      _fetchRecords();
      _fetchChartData();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which chart data to display based on _selectedVariable
    Map<String, Map<DateTime, double>> currentChartDataByAnimal;
    String chartTitle;
    Color defaultChartColor;

    switch (_selectedVariable) {
      case 'production':
        currentChartDataByAnimal = _chartDataProductionByAnimal;
        chartTitle = 'Production Over Time by Animal';
        defaultChartColor = Colors.green;
        break;
      case 'consumption':
        currentChartDataByAnimal = _chartDataConsumptionByAnimal;
        chartTitle = 'Consumption Over Time by Animal';
        defaultChartColor = Colors.orange;
        break;
      case 'productivity_ratio':
        currentChartDataByAnimal = _chartDataRatioByAnimal;
        chartTitle = 'Productivity Ratio Over Time by Animal (Production/Consumption)';
        defaultChartColor = Colors.blue;
        break;
      default:
        currentChartDataByAnimal = {};
        chartTitle = 'Select a variable';
        defaultChartColor = Colors.grey;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/home');
          },
        ),
        title: const Text('Farm Report'),
        backgroundColor: Config.themeColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Records',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading || _isLoadingChartData ? null : () {
              _fetchRecords();
              _fetchChartData();
            },
            tooltip: 'Refresh Records',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing records from ${DateFormat('yyyy-MM-dd').format(_fromDate)} '
                      'to ${DateFormat('yyyy-MM-dd').format(_toDate)}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                DropdownButton<String>(
                  value: _selectedPeriod,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedPeriod = newValue;
                      });
                      _fetchChartData();
                    }
                  },
                  items: _periods.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value.capitalize()),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Config.themeColor))
                : _errorMessage != null
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _fetchRecords,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
                : _records.isEmpty
                ? const Center(
              child: Text(
                'No report records found for the selected filters.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
                : SingleChildScrollView(
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16.0,
                      dataRowMinHeight: 38.0,
                      dataRowMaxHeight: 40.0,
                      headingRowColor: WidgetStateProperty.resolveWith(
                              (states) => Config.themeColor.withOpacity(0.1)),
                      columns: const <DataColumn>[
                        DataColumn(
                            label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Animal', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                          label: Text(
                            'Production',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.end,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Consumption',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.end,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Profit',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                      rows: [
                        ..._records.asMap().entries.map((entry) {
                          int index = entry.key;
                          FarmReport record = entry.value;
                          return DataRow(
                            cells: <DataCell>[
                              DataCell(Text((index + 1).toString())),
                              DataCell(Text(record.animal)),
                              DataCell(
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(record.production.toStringAsFixed(2)),
                                ),
                              ),
                              DataCell(
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(record.consumption.toStringAsFixed(2)),
                                ),
                              ),
                              DataCell(
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(record.profit.toStringAsFixed(2)),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                        DataRow(
                          color: WidgetStateProperty.resolveWith(
                                  (states) => Config.themeColor.withOpacity(0.05)),
                          cells: <DataCell>[
                            const DataCell(Text('')),
                            DataCell(Text('Total',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, color: Config.themeColor))),
                            DataCell(
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _totalProduction.toStringAsFixed(2),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, color: Config.themeColor),
                                ),
                              ),
                            ),
                            DataCell(
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _totalConsumption.toStringAsFixed(2),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, color: Config.themeColor),
                                ),
                              ),
                            ),
                            DataCell(
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _totalProfit.toStringAsFixed(2),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, color: Config.themeColor),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Chart Variable:',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        DropdownButton<String>(
                          value: _selectedVariable,
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedVariable = newValue;
                              });
                              _fetchChartData();
                            }
                          },
                          items: _variables.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value.replaceAll('_', ' ').capitalize()),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoadingChartData)
                    Center(child: CircularProgressIndicator(color: Config.themeColor))
                  else if (_chartErrorMessage != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _chartErrorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red, fontSize: 16),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _fetchChartData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (currentChartDataByAnimal.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chartTitle,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            LineChartWidget(
                              dataByAnimal: currentChartDataByAnimal,
                              title: chartTitle,
                              period: _selectedPeriod,
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReportFilterDialog extends StatefulWidget {
  final DateTime initialFromDate;
  final DateTime initialToDate;

  const ReportFilterDialog({
    super.key,
    required this.initialFromDate,
    required this.initialToDate,
  });

  @override
  State<ReportFilterDialog> createState() => _ReportFilterDialogState();
}

class _ReportFilterDialogState extends State<ReportFilterDialog> {
  late DateTime _selectedFromDate;
  late DateTime _selectedToDate;

  @override
  void initState() {
    super.initState();
    _selectedFromDate = widget.initialFromDate;
    _selectedToDate = widget.initialToDate;
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedFromDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedFromDate) {
      setState(() {
        _selectedFromDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedToDate,
      firstDate: _selectedFromDate,
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedToDate) {
      setState(() {
        _selectedToDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _applyFilters() {
    Navigator.pop(context, {
      'fromDate': _selectedFromDate,
      'toDate': _selectedToDate,
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedFromDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      _selectedToDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Report'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'From Date',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.calendar_today),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(_selectedFromDate),
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _selectFromDate(context),
                    child: const Text('Select'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'To Date',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.calendar_today),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(_selectedToDate),
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _selectToDate(context),
                    child: const Text('Select'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            _clearFilters();
            _applyFilters();
          },
          child: const Text('Clear Filters'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _applyFilters,
          child: const Text('Apply Filters'),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class LineChartWidget extends StatelessWidget {
  final Map<String, Map<DateTime, double>> dataByAnimal;
  final String title;
  final String period;

  const LineChartWidget({
    super.key,
    required this.dataByAnimal,
    required this.title,
    required this.period,
  });

  static const List<Color> _chartColors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.brown,
    Colors.indigo,
    Colors.cyan,
    Colors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    if (dataByAnimal.isEmpty) {
      return Center(child: Text('No $title data to display.'));
    }

    Set<DateTime> allDates = {};
    dataByAnimal.values.forEach((animalData) {
      allDates.addAll(animalData.keys);
    });
    final sortedAllDates = allDates.toList()..sort((a, b) => a.compareTo(b));

    double minX = 0;
    double maxX = (sortedAllDates.length > 0 ? sortedAllDates.length - 1 : 0).toDouble();

    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    dataByAnimal.values.forEach((animalData) {
      animalData.values.forEach((value) {
        if (value < minY) minY = value;
        if (value > maxY) maxY = value;
      });
    });

    if (minY == double.infinity) minY = 0;
    if (maxY == double.negativeInfinity) maxY = 10;

    minY = minY > 0 ? minY * 0.9 : minY * 1.1;
    maxY = maxY * 1.1;

    final List<LineChartBarData> lineBarsData = [];
    int colorIndex = 0;
    dataByAnimal.forEach((animalName, animalData) {
      final List<FlSpot> spots = [];
      for (int i = 0; i < sortedAllDates.length; i++) {
        final date = sortedAllDates[i];
        final value = animalData[date];
        if (value != null) {
          spots.add(FlSpot(i.toDouble(), value));
        }
      }

      if (spots.isNotEmpty) {
        lineBarsData.add(
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _chartColors[colorIndex % _chartColors.length],
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        );
        colorIndex++;
      }
    });

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.7,
          child: LineChart(
            LineChartData(
              lineBarsData: lineBarsData,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: (sortedAllDates.length / 5).ceilToDouble(),
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index >= 0 && index < sortedAllDates.length) {
                        DateTime date = sortedAllDates[index];
                        String formattedDate;
                        if (period == 'daily') {
                          formattedDate = DateFormat('MMM d').format(date);
                        } else if (period == 'weekly') {
                          formattedDate = DateFormat('MMM d').format(date);
                        } else if (period == 'monthly') {
                          formattedDate = DateFormat('MMM yyyy').format(date);
                        } else {
                          formattedDate = DateFormat('yyyy').format(date);
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 4,
                          child: Text(formattedDate, style: const TextStyle(fontSize: 10)),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                getDrawingHorizontalLine: (value) => const FlLine(color: Colors.grey, strokeWidth: 0.5),
                getDrawingVerticalLine: (value) => const FlLine(color: Colors.grey, strokeWidth: 0.5),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: const Color(0xff37434d), width: 1),
              ),
              minX: minX,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((LineBarSpot touchedSpot) {
                      final date = sortedAllDates[touchedSpot.x.toInt()];
                      String formattedDate;
                      if (period == 'daily') {
                        formattedDate = DateFormat('yyyy-MM-dd').format(date);
                      } else if (period == 'weekly') {
                        formattedDate = 'Week of ${DateFormat('MMM d, yyyy').format(date)}';
                      } else if (period == 'monthly') {
                        formattedDate = DateFormat('MMMM yyyy').format(date);
                      } else {
                        formattedDate = DateFormat('yyyy').format(date);
                      }
                      String animalName = dataByAnimal.keys.elementAt(touchedSpot.barIndex);
                      return LineTooltipItem(
                        '$animalName\n$formattedDate\n',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        children: [
                          TextSpan(
                            text: '${title}: ${touchedSpot.y.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: dataByAnimal.keys.map((animalName) {
              int idx = dataByAnimal.keys.toList().indexOf(animalName);
              Color animalColor = _chartColors[idx % _chartColors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    color: animalColor,
                  ),
                  const SizedBox(width: 4),
                  Text(animalName),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}