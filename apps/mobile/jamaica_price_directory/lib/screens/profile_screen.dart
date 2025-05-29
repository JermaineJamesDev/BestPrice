import 'package:flutter/material.dart';

// Profile Screen - User account, settings, and preferences
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Mock user data
  final String userName = 'John Doe';
  final String userEmail = 'john.doe@example.com';
  final String userParish = 'Kingston';
  final String userPhone = '+1 876-555-0123';
  final String memberSince = 'January 2024';
  
  // Mock user stats
  final Map<String, dynamic> userStats = {
    'submissions': 156,
    'verified': 142,
    'points': 2840,
    'rank': 'Gold Contributor',
    'saved': 1250.0, // Money saved using the app
  };
  
  // Settings toggles
  bool notificationsEnabled = true;
  bool priceAlertsEnabled = true;
  bool darkModeEnabled = false;
  bool locationEnabled = true;
  
  // Handle logout
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign Out'),
        content: Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Navigate back to login and clear all previous screens
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            child: Text('Sign Out'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      
      appBar: AppBar(
        title: Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Edit profile coming soon!')),
              );
            },
            icon: Icon(Icons.edit),
          ),
        ],
      ),
      
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile header
            _buildProfileHeader(),
            
            SizedBox(height: 16),
            
            // User stats
            _buildUserStats(),
            
            SizedBox(height: 16),
            
            // Settings sections
            _buildAccountSection(),
            
            SizedBox(height: 16),
            
            _buildNotificationSettings(),
            
            SizedBox(height: 16),
            
            _buildAppSettings(),
            
            SizedBox(height: 16),
            
            _buildSupportSection(),
            
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  // Profile header section
  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Profile picture
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.person,
              size: 60,
              color: Color(0xFF1E3A8A),
            ),
          ),
          
          SizedBox(height: 16),
          
          // User name
          Text(
            userName,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          
          SizedBox(height: 4),
          
          // User rank
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              userStats['rank'],
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          SizedBox(height: 8),
          
          // Member since
          Text(
            'Member since $memberSince',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  // User stats section
  Widget _buildUserStats() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Impact',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '${userStats['submissions']}',
                  'Price\nSubmissions',
                  Icons.camera_alt,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  '${userStats['verified']}',
                  'Verified\nPrices',
                  Icons.verified,
                  Colors.green,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '${userStats['points']}',
                  'Points\nEarned',
                  Icons.stars,
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'J\$${userStats['saved'].toStringAsFixed(0)}',
                  'Money\nSaved',
                  Icons.savings,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Stat item widget
  Widget _buildStatItem(String value, String label, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  // Account section
  Widget _buildAccountSection() {
    return _buildSection(
      title: 'Account',
      icon: Icons.person,
      children: [
        _buildListTile(
          icon: Icons.email,
          title: 'Email',
          subtitle: userEmail,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Edit email coming soon!')),
            );
          },
        ),
        _buildListTile(
          icon: Icons.phone,
          title: 'Phone',
          subtitle: userPhone,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Edit phone coming soon!')),
            );
          },
        ),
        _buildListTile(
          icon: Icons.location_on,
          title: 'Parish',
          subtitle: userParish,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Change parish coming soon!')),
            );
          },
        ),
        _buildListTile(
          icon: Icons.lock,
          title: 'Change Password',
          subtitle: 'Update your password',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Change password coming soon!')),
            );
          },
        ),
      ],
    );
  }
  
  // Notification settings section
  Widget _buildNotificationSettings() {
    return _buildSection(
      title: 'Notifications',
      icon: Icons.notifications,
      children: [
        _buildSwitchTile(
          icon: Icons.notifications_active,
          title: 'Push Notifications',
          subtitle: 'Receive app notifications',
          value: notificationsEnabled,
          onChanged: (value) {
            setState(() {
              notificationsEnabled = value;
            });
          },
        ),
        _buildSwitchTile(
          icon: Icons.price_change,
          title: 'Price Alerts',
          subtitle: 'Get notified of price drops',
          value: priceAlertsEnabled,
          onChanged: (value) {
            setState(() {
              priceAlertsEnabled = value;
            });
          },
        ),
      ],
    );
  }
  
  // App settings section
  Widget _buildAppSettings() {
    return _buildSection(
      title: 'App Settings',
      icon: Icons.settings,
      children: [
        _buildSwitchTile(
          icon: Icons.dark_mode,
          title: 'Dark Mode',
          subtitle: 'Use dark theme',
          value: darkModeEnabled,
          onChanged: (value) {
            setState(() {
              darkModeEnabled = value;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Dark mode feature coming soon!')),
            );
          },
        ),
        _buildSwitchTile(
          icon: Icons.location_on,
          title: 'Location Services',
          subtitle: 'Allow location access',
          value: locationEnabled,
          onChanged: (value) {
            setState(() {
              locationEnabled = value;
            });
          },
        ),
        _buildListTile(
          icon: Icons.language,
          title: 'Language',
          subtitle: 'English',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Language settings coming soon!')),
            );
          },
        ),
      ],
    );
  }
  
  // Support section
  Widget _buildSupportSection() {
    return _buildSection(
      title: 'Support & Legal',
      icon: Icons.help,
      children: [
        _buildListTile(
          icon: Icons.help_outline,
          title: 'Help Center',
          subtitle: 'Get help and support',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Help center coming soon!')),
            );
          },
        ),
        _buildListTile(
          icon: Icons.feedback,
          title: 'Send Feedback',
          subtitle: 'Tell us what you think',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Feedback form coming soon!')),
            );
          },
        ),
        _buildListTile(
          icon: Icons.privacy_tip,
          title: 'Privacy Policy',
          subtitle: 'Read our privacy policy',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Privacy policy coming soon!')),
            );
          },
        ),
        _buildListTile(
          icon: Icons.description,
          title: 'Terms of Service',
          subtitle: 'Read our terms',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Terms of service coming soon!')),
            );
          },
        ),
        _buildListTile(
          icon: Icons.info,
          title: 'About',
          subtitle: 'App version 1.0.0',
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'Jamaica Price Directory',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2024 Jamaica Price Directory',
              children: [
                Text('Find the best prices across Jamaica'),
              ],
            );
          },
        ),
        _buildListTile(
          icon: Icons.logout,
          title: 'Sign Out',
          subtitle: 'Sign out of your account',
          onTap: _handleLogout,
          textColor: Colors.red,
        ),
      ],
    );
  }
  
  // Helper method to build sections
  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Color(0xFF1E3A8A), size: 24),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
  
  // Helper method to build list tiles
  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.grey[600]),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: textColor ?? Colors.grey[800],
        ),
      ),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
  
  // Helper method to build switch tiles
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.grey[600]),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: Color(0xFF1E3A8A),
    );
  }
}