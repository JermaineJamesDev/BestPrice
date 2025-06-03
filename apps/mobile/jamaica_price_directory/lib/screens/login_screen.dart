import 'package:flutter/material.dart';

// Login Screen - Where users sign in to the app
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Form key for validation - tells Flutter this is a form
  final _formKey = GlobalKey<FormState>();
  
  // Controllers to get text from input fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Track if password is visible or hidden
  bool _isPasswordVisible = false;
  
  // Track if we're currently logging in (for loading state)
  bool _isLoading = false;
  
  // Mock login function - in real app, this would call your API
  Future<void> _handleLogin() async {
    // Check if form is valid (all validation rules pass)
    if (_formKey.currentState!.validate()) {
      // Set loading state to true
      setState(() {
        _isLoading = true;
      });
      
      // Simulate network delay (like calling an API)
      await Future.delayed(Duration(seconds: 2));
      
      // Get the entered values
      String email = _emailController.text;
      String password = _passwordController.text;
      
      // Mock authentication - in real app, send to server
      if (email == 'user@example.com' && password == 'password123') {
        // Login successful - go to home screen
        // Before using `context` here, make sure we're still mounted:
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        // Login failed - show error message
        _showErrorDialog('Invalid email or password');
      }
      
      // Set loading state to false
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Show error message dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Login Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      
      // App bar at the top
      appBar: AppBar(
        title: Text('Sign In'),
        centerTitle: true,
        elevation: 0,
      ),
      
      // Main content - Now scrollable to handle keyboard
      body: SafeArea( // Keeps content away from status bar/notch
        child: SingleChildScrollView( // Makes screen scrollable when keyboard appears
          padding: EdgeInsets.all(24.0),
          child: Form( // Wrapper for form validation
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome text
                Text(
                  'Welcome Back!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: 8),
                
                Text(
                  'Sign in to find the best prices in Jamaica',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: 48),
                
                // Email input field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress, // Shows email keyboard
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email),
                    hintText: 'Enter your email',
                  ),
                  // Validation rules
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null; // null means validation passed
                  },
                ),
                
                SizedBox(height: 16),
                
                // Password input field
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible, // Hide/show password
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    hintText: 'Enter your password',
                    // Toggle password visibility button
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
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                
                SizedBox(height: 24),
                
                // Login button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin, // Disable when loading
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
                            Text('Signing In...'),
                          ],
                        )
                      : Text(
                          'Sign In',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                
                SizedBox(height: 16),
                
                // Forgot password link
                TextButton(
                  onPressed: () {
                    // TODO: Implement forgot password
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Forgot password feature coming soon!')),
                    );
                  },
                  child: Text('Forgot Password?'),
                ),
                
                SizedBox(height: 32),
                
                // Divider with "OR" text
                Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                
                SizedBox(height: 32),
                
                // Social login buttons (mock for now)
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Google sign in coming soon!')),
                    );
                  },
                  icon: Icon(Icons.g_mobiledata), // Placeholder for Google icon
                  label: Text('Continue with Google'),
                ),
                
                SizedBox(height: 16),
                
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Facebook sign in coming soon!')),
                    );
                  },
                  icon: Icon(Icons.facebook), 
                  label: Text('Continue with Facebook'),
                ),
                
                SizedBox(height: 48), // Fixed spacing instead of Spacer
                
                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? "),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: Text('Sign Up'),
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
  
  // Clean up controllers when screen is disposed
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}