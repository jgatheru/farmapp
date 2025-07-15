import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';

class MilkProductionSummaryPage extends StatefulWidget {
  const MilkProductionSummaryPage({super.key});

  @override
  State<MilkProductionSummaryPage> createState() => _MilkProductionSummaryPageState();
}

class _MilkProductionSummaryPageState extends State<MilkProductionSummaryPage> {
  List<Map<String, dynamic>> _chartData = [];
  bool _isLoading = false;
  String? _errorMessage;

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  String _selectedPeriod = 'monthly'; // Default period
  final List<String> _periods = ['daily', 'weekly', 'monthly', 'quarterly', 'annually'];

  // final String _fetchEndpoint = '${Config.baseUrl}/reports/farm-productivity/summary';
  final String _fetchEndpoint = 'http://213.136.81.123/farm/reports/summary.php';

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    _toDate = DateTime(_toDate.year, _toDate.month, _toDate.day);
    _fetchChartData();
  }

  Future<void> _fetchChartData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _chartData = [];
    });

    try {
      final Map<String, dynamic> requestBody = {
        'from_date': DateFormat('yyyy-MM-dd').format(_fromDate),
        'to_date': DateFormat('yyyy-MM-dd').format(_toDate),
        'period': _selectedPeriod,
      };

      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;

      if (authToken == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse(_fetchEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      print(response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] != true) {
          setState(() {
            _errorMessage = responseData['message'] ?? 'Failed to load chart data';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessage!)),
          );
          return;
        }

        final List<dynamic> data = responseData['data'] ?? [];
        setState(() {
          _chartData = data.cast<Map<String, dynamic>>();
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
      _fetchChartData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/home');
          },
        ),
        title: const Text('Milk Production Summary'),
        backgroundColor: Config.themeColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Dates',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchChartData,
            tooltip: 'Refresh Data',
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
                  'From ${DateFormat('yyyy-MM-dd').format(_fromDate)} '
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
                      onPressed: _fetchChartData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
                : _chartData.isEmpty
                ? const Center(
              child: Text(
                'No data found for the selected filters.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
                : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Milk Production Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: BarChartWidget(
                      data: _chartData,
                      period: _selectedPeriod,
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

class BarChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String period;

  const BarChartWidget({
    super.key,
    required this.data,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data to display.'));
    }

    // Convert data to FlSpot for bar chart
    final List<BarChartGroupData> barGroups = [];
    double maxY = 0;
    for (int i = 0; i < data.length; i++) {
      final value = (data[i]['value'] as num).toDouble();
      if (value > maxY) maxY = value;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              color: Config.themeColor,
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    // Add padding to Y-axis
    maxY = maxY * 1.1;

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (data.length / 5).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.length) {
                  final date = DateTime.parse(data[index]['date']);
                  String formattedDate;
                  switch (period) {
                    case 'daily':
                      formattedDate = DateFormat('MMM d').format(date);
                      break;
                    case 'weekly':
                      formattedDate = DateFormat('MMM d').format(date);
                      break;
                    case 'monthly':
                      formattedDate = DateFormat('MMM yyyy').format(date);
                      break;
                    case 'quarterly':
                      formattedDate = 'Q${(date.month / 3).ceil()} ${date.year}';
                      break;
                    case 'annually':
                      formattedDate = DateFormat('yyyy').format(date);
                      break;
                    default:
                      formattedDate = '';
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
        minY: 0,
        maxY: maxY > 0 ? maxY : 10,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final date = DateTime.parse(data[groupIndex]['date']);
              String formattedDate;
              switch (period) {
                case 'daily':
                  formattedDate = DateFormat('yyyy-MM-dd').format(date);
                  break;
                case 'weekly':
                  formattedDate = 'Week of ${DateFormat('MMM d, yyyy').format(date)}';
                  break;
                case 'monthly':
                  formattedDate = DateFormat('MMMM yyyy').format(date);
                  break;
                case 'quarterly':
                  formattedDate = 'Q${(date.month / 3).ceil()} ${date.year}';
                  break;
                case 'annually':
                  formattedDate = DateFormat('yyyy').format(date);
                  break;
                default:
                  formattedDate = '';
              }
              return BarTooltipItem(
                '$formattedDate\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                children: [
                  TextSpan(
                    text: 'Production: ${rod.toY.toStringAsFixed(2)} L',
                    style: const TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}