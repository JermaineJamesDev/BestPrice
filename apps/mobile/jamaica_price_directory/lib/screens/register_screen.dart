import 'package:flutter/material.dart';

// Register Screen - Where new users create accounts
class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for input fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Password visibility toggles
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  
  // Loading state
  bool _isLoading = false;
  
  // Selected parish (Jamaica has 14 parishes)
  String? _selectedParish;
  
  // List of Jamaica's parishes (mock data)
  final List<String> _parishes = [
    'Kingston',
    'St. Andrew',
    'St. Thomas',
    'Portland',
    'St. Mary',
    'St. Ann',
    'Trelawny',
    'St. James',
    'Hanover',
    'Westmoreland',
    'St. Elizabeth',
    'Manchester',
    'Clarendon',
    'St. Catherine',
  ];
  
  // Mock registration function
  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      // Simulate network delay
      await Future.delayed(Duration(seconds: 2));
      
      // In a real app, you would send this data to your server
      print('Registration Data:');
      print('Name: ${_firstNameController.text} ${_lastNameController.text}');
      print('Email: ${_emailController.text}');
      print('Parish: $_selectedParish');
      
      // Mock successful registration
      _showSuccessDialog();
      
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Show success dialog
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Can't dismiss by tapping outside
      builder: (ctx) => AlertDialog(
        title: Text('Welcome!'),
        content: Text('Your account has been created successfully. You can now sign in.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              Navigator.pop(context); // Go back to login screen
            },
            child: Text('Sign In Now'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      
      appBar: AppBar(
        title: Text('Create Account'),
        centerTitle: true,
        elevation: 0,
      ),
      
      body: SafeArea(
        child: SingleChildScrollView( // Makes screen scrollable
          padding: EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome text
                Text(
                  'Join Us!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: 8),
                
                Text(
                  'Create your account to start saving money',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: 32),
                
                // First Name field
                TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words, // Capitalize first letter
                  decoration: InputDecoration(
                    labelText: 'First Name',
                    prefixIcon: Icon(Icons.person),
                    hintText: 'Enter your first name',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your first name';
                    }
                    return null;
                  },
                ),
                
                SizedBox(height: 16),
                
                // Last Name field
                TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Last Name',
                    prefixIcon: Icon(Icons.person),
                    hintText: 'Enter your last name',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your last name';
                    }
                    return null;
                  },
                ),
                
                SizedBox(height: 16),
                
                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email),
                    hintText: 'Enter your email',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                
                SizedBox(height: 16),
                
                // Parish dropdown
                DropdownButtonFormField<String>(
                  value: _selectedParish,
                  decoration: InputDecoration(
                    labelText: 'Parish',
                    prefixIcon: Icon(Icons.location_on),
                    hintText: 'Select your parish',
                  ),
                  items: _parishes.map((String parish) {
                    return DropdownMenuItem<String>(
                      value: parish,
                      child: Text(parish),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedParish = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your parish';
                    }
                    return null;
                  },
                ),
                
                SizedBox(height: 16),
                
                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    hintText: 'Create a password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                
                SizedBox(height: 16),
                
                // Confirm Password field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock),
                    hintText: 'Confirm your password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                
                SizedBox(height: 32),
                
                // Register button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Creating Account...'),
                          ],
                        )
                      : Text(
                          'Create Account',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                
                SizedBox(height: 24),
                
                // Terms and conditions text
                Text(
                  'By creating an account, you agree to our Terms of Service and Privacy Policy.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: 32),
                
                // Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account? '),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Go back to login
                      },
                      child: Text('Sign In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Clean up controllers
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}