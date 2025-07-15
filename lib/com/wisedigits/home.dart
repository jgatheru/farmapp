import 'package:farmapp/com/wisedigits/statistics.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:animate_do/animate_do.dart';

import '../../../config.dart';
import 'auth/SessionProvider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<StatisticItem> _statisticItems = [];
  bool _isLoading = true;
  String? _error;

  final String menuApiEndpoint = '${Config.baseUrl}/statistics';
  // final String menuApiEndpoint = '${Config.sisiUrl}/statistics.php';

  @override
  void initState() {
    super.initState();
    _fetchStatisticItems();
  }

  Future<void> _fetchStatisticItems() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Please log in to view statistics.';
        });
      }
      debugPrint('Authentication Error: Token is null.');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(menuApiEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        debugPrint('API Response Body: ${response.body}');
        final List<dynamic> responseData = json.decode(response.body);
        final List<StatisticItem> fetchedItems = responseData.map((jsonItem) {
          try {
            return StatisticItem.fromJson(jsonItem as Map<String, dynamic>);
          } catch (e) {
            debugPrint('Error parsing StatisticItem: $e, Data: $jsonItem');
            rethrow;
          }
        }).toList();

        if (mounted) {
          setState(() {
            _statisticItems = fetchedItems;
            _isLoading = false;
          });
        }
      } else {
        debugPrint('API Error: Status ${response.statusCode}, Body: ${response.body}');
        if (mounted) {
          setState(() {
            _error = 'Server error: Status ${response.statusCode}.';
            _isLoading = false;
          });
        }
      }
    } on http.ClientException catch (e) {
      debugPrint('HTTP Client Error: $e');
      if (mounted) {
        setState(() {
          _error = 'Network error: Check your connection.';
          _isLoading = false;
        });
      }
    } on Exception catch (e) {
      debugPrint('General Fetch Error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to fetch data: ${e.toString()}.';
          _isLoading = false;
        });
      }
    }
  }

  void _onStatisticItemTap(StatisticItem item) {
    if (item.route.isNotEmpty) {
      Navigator.pushNamed(context, item.route);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No action for ${item.title}')),
      );
    }
  }

  void _onDrawerMenuItemTap(String route, String title) {
    Navigator.pop(context);
    if (route.isNotEmpty) {
      Navigator.pushNamed(context, route);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No route defined for $title')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = Provider.of<SessionProvider>(context);
    final String displayFullName = sessionProvider.currentUser?.fullName ?? 'Guest';
    final String displayUserType = sessionProvider.currentUser?.isAgent == true ? 'Agent' : 'Employee';
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wonnie Farm'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Config.themeColor ?? Colors.teal,
                Config.backgroundColor ?? Colors.blueGrey,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Config.themeColor ?? Colors.teal,
                    Config.backgroundColor ?? Colors.blueGrey,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: FadeInDown(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 50, color: Config.themeColor ?? Colors.teal),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayFullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      displayUserType,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ExpansionTile(
              leading: Icon(Icons.agriculture_sharp, color: Config.themeColor ?? Colors.teal),
              title: const Text('Herd Management', style: TextStyle(fontWeight: FontWeight.w600)),
              children: [
                _buildDrawerItem(
                  icon: Icons.pets,
                  title: 'Categories',
                  route: '/viewAnimalCategories',
                ),
                _buildDrawerItem(
                  icon: Icons.pets,
                  title: 'Animals',
                  route: '/viewAnimals',
                ),
                _buildDrawerItem(
                  icon: Icons.shelves,
                  title: 'Shades',
                  route: '/viewShades',
                ),
              ],
            ),
            ExpansionTile(
              leading: Icon(Icons.agriculture, color: Config.themeColor ?? Colors.teal),
              title: const Text('Herd Production', style: TextStyle(fontWeight: FontWeight.w600)),
              children: [
                _buildDrawerItem(
                  icon: Icons.local_drink,
                  title: 'Milk Production',
                  route: '/viewProduction',
                ),
                _buildDrawerItem(
                  icon: Icons.local_shipping,
                  title: 'Milk Deliveries',
                  route: '/viewDeliveries',
                ),
              ],
            ),
            ExpansionTile(
              leading: Icon(Icons.grass, color: Config.themeColor ?? Colors.teal),
              title: const Text('Herd Feeding', style: TextStyle(fontWeight: FontWeight.w600)),
              children: [
                _buildDrawerItem(
                  icon: Icons.calendar_today,
                  title: 'Feeding Plans',
                  route: '/viewFeedingPlans',
                ),
                _buildDrawerItem(
                  icon: Icons.restaurant,
                  title: 'Feeding Records',
                  route: '/viewFeeding',
                ),
              ],
            ),
            ExpansionTile(
              leading: Icon(Icons.health_and_safety, color: Config.themeColor ?? Colors.teal),
              title: const Text('Health Management', style: TextStyle(fontWeight: FontWeight.w600)),
              children: [
                _buildDrawerItem(
                  icon: Icons.medical_services,
                  title: 'Health Records',
                  route: '/viewHealthRecords',
                ),
              ],
            ),
            ExpansionTile(
              leading: Icon(Icons.account_balance, color: Config.themeColor ?? Colors.teal),
              title: const Text('Finance', style: TextStyle(fontWeight: FontWeight.w600)),
              children: [
                _buildDrawerItem(
                  icon: Icons.money_off,
                  title: 'Expenses',
                  route: '/viewPersons',
                ),
                _buildDrawerItem(
                  icon: Icons.attach_money,
                  title: 'Sales',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Navigating to Sales')),
                  ),
                ),
              ],
            ),
            ExpansionTile(
              leading: Icon(Icons.bar_chart, color: Config.themeColor ?? Colors.teal),
              title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.w600)),
              children: [
                _buildDrawerItem(
                  icon: Icons.show_chart,
                  title: 'Productivity Report',
                  route: '/productivityReport'
                ),
                _buildDrawerItem(
                  icon: Icons.pie_chart,
                  title: 'Summary Report',
                  route: '/summary'
                ),
                _buildDrawerItem(
                  icon: Icons.receipt_long,
                  title: 'Financial Report',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Navigating to Financial Report')),
                  ),
                ),
              ],
            ),
            // const Divider(),
            // _buildDrawerItem(
            //   icon: Icons.person,
            //   title: 'Doctors',
            //   route: '/viewPersons',
            // ),
            // _buildDrawerItem(
            //   icon: Icons.person,
            //   title: 'Facility',
            //   route: '/viewFacilitys',
            // ),
            // _buildDrawerItem(
            //   icon: Icons.person,
            //   title: 'Appointments',
            //   route: '/viewAppointments',
            // ),
            // ExpansionTile(
            //   leading: Icon(Icons.bar_chart, color: Config.themeColor ?? Colors.teal),
            //   title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.w600)),
            //   children: [
            //     _buildDrawerItem(
            //       icon: Icons.show_chart,
            //       title: 'Appointment Report',
            //       route: '/viewAppointmentReport',
            //     ),
            //     _buildDrawerItem(
            //       icon: Icons.pie_chart,
            //       title: 'Appointment Speciality Report',
            //       route: '/viewAppointmentReportBySpeciality',
            //     ),
            //     _buildDrawerItem(
            //       icon: Icons.receipt_long,
            //       title: 'Financial Report',
            //       onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            //         const SnackBar(content: Text('Navigating to Financial Report')),
            //       ),
            //     ),
            //   ],
            // ),
            const Divider(),
            _buildDrawerItem(
              icon: Icons.logout,
              title: 'Logout',
              route: '/login',
              onTap: () {
                Navigator.pop(context);
                sessionProvider.logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStatisticItems,
        color: Config.themeColor ?? Colors.teal,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Config.themeColor?.withOpacity(0.9) ?? Colors.teal.withOpacity(0.9),
                      Config.backgroundColor?.withOpacity(0.8) ?? Colors.blueGrey.withOpacity(0.8),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                width: double.infinity,
                child: FadeInDown(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Welcome, $displayFullName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        displayUserType,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Statistics Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _isLoading
                    ? FadeIn(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Config.themeColor ?? Colors.teal,
                    ),
                  ),
                )
                    : _error != null
                    ? FadeInUp(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.red.withOpacity(0.8),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _fetchStatisticItems,
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Config.themeColor ?? Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                )
                    : _statisticItems.isEmpty
                    ? FadeInUp(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 50,
                        color: Colors.grey.withOpacity(0.7),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No statistics available.\nCheck your backend configuration or data.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
                    : LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = screenWidth > 800 ? 4 : screenWidth > 600 ? 3 : 2;
                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: screenWidth > 600 ? 1.2 : 1.1,
                      ),
                      padding: const EdgeInsets.only(bottom: 32),
                      itemCount: _statisticItems.length,
                      itemBuilder: (context, index) {
                        final item = _statisticItems[index];
                        return FadeInUp(
                          delay: Duration(milliseconds: 100 * index),
                          child: StatisticCard(
                            title: item.title,
                            value: item.value,
                            icon: item.iconData,
                            onTap: () => _onStatisticItemTap(item),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    String? route,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          onTap: onTap ?? () {
            Navigator.pop(context);
            if (route != null && route.isNotEmpty) {
              _onDrawerMenuItemTap(route, title);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('No route defined for $title')),
              );
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: ListTile(
            leading: Icon(icon, color: Config.themeColor ?? Colors.teal, size: 28),
            title: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
        ),
      ),
    );
  }
}

class StatisticCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const StatisticCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  _StatisticCardState createState() => _StatisticCardState();
}

class _StatisticCardState extends State<StatisticCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          _controller.forward().then((_) => _controller.reverse());
          widget.onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      (Config.themeColor ?? Colors.teal).withOpacity(0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      size: 28,
                      color: Config.themeColor ?? Colors.teal,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Config.backgroundColor ?? Colors.blueGrey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}