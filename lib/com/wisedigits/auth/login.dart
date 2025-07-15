// login_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import the http package
import 'dart:convert'; // For encoding/decoding JSON

import 'package:provider/provider.dart';

import '../../../config.dart';
import 'SessionProvider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isAgent = true;
  bool _isLoading = false; // New state variable for loading indicator

  // Replace with your actual PHP endpoint URL
  final String _phpEndpoint = '${Config.baseUrl}/auth/token?with-user=1';

  Future<void> _login() async {
    // Basic validation: check if both username and password fields are filled
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorDialog('Please fill all fields');
      return;
    }

    setState(() {
      _isLoading = true; // Show loading indicator
    });

    print(_phpEndpoint);
    try {
      final response = await http.post(
        Uri.parse(_phpEndpoint),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'username': _usernameController.text,
          'password': _passwordController.text
        }),
      );

      setState(() {
        _isLoading = false; // Hide loading indicator
      });


      if (response.statusCode == 200) {

        final Map<String, dynamic> responseData = jsonDecode(response.body);

        //print('DEBUG: API Response: $responseData');

        // if (responseData['success'] == true) {

          //set retrieved values to session here
          final userData = responseData['user'];

          // Set user data in SessionProvider
          await Provider.of<SessionProvider>(context, listen: false).login(
            username: userData['username'] ?? '',
            fullName: userData['name'] ?? '',
            isAgent: userData['isAgent'] == 1 || userData['isAgent'] == true,
            userid: userData['userid']?.toString() ?? '',
            employeeid: userData['employeeid']?.toString() ?? '',
            token: responseData['access_token'] ?? '',
            avatar: userData['avatar'],
            email: userData['email'] ?? '',
            levelid: userData['levelid']?.toString() ?? '',
          );

          Navigator.pushReplacementNamed(context, '/home');

        // } else {
        //   _showErrorDialog(responseData['message'] ?? 'Login failed. Please try again.');
        // }
      } else {
        // Handle non-200 status codes (e.g., 404, 500)
        _showErrorDialog('Server error: ${response.statusCode}. Please try again later. $_phpEndpoint');
      }
    } catch (e) {
      setState(() {
        _isLoading = false; // Hide loading indicator on error
      });
      _showErrorDialog('Network error: Could not connect to the server. Please check your internet connection.');
      print('Error during login: $e'); // For debugging
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Displaying a cow icon from assets
            // Make sure you have 'assets/cow_icon.png' in your project and declared in pubspec.yaml
            Image.asset(
              'assets/logo.png',
              height: 200,
              // Fallback for when the image is not found
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.pets, // A generic pet icon as a fallback
                  size: 100,
                  color: Colors.grey,
                );
              },
            ),
            const SizedBox(height: 20), // Spacer
            // Username input field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0), // Added const
              child: TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'), // Added const
              ),
            ),
            // Password input field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0), // Added const
              child: TextField(
                controller: _passwordController,
                decoration: const InputDecoration( // Added const
                  labelText: 'Password',
                  suffixIcon: Icon(Icons.visibility), // Eye icon for visibility toggle (not implemented)
                ),
                obscureText: true, // Hides password characters
              ),
            ),
            // Radio buttons for selecting user type (Agent/Employee)

            const SizedBox(height: 20), // Spacer
            // Login button
            ElevatedButton(
              onPressed: _isLoading ? null : _login, // Disable button while loading
              style: ElevatedButton.styleFrom(
                backgroundColor: Config.backgroundColor, // Custom button color
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15), // Added const
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white) // Show loading indicator
                  : const Text(
                              'Login',
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              ), // Added const
            ),
          ],
        ),
      ),
    );
  }
}
