import 'package:flutter/material.dart';

// Budget Screen - Financial planning and budget management
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  // Mock financial data
  final double monthlyIncome = 65000.0;
  final double totalSpent = 42350.0;
  final double totalBudget = 58000.0;
  
  // Mock budget categories
  final List<Map<String, dynamic>> budgetCategories = [
    {
      'category': 'Groceries',
      'budgeted': 15000.0,
      'spent': 12400.0,
      'icon': Icons.shopping_cart,
      'color': Colors.green,
    },
    {
      'category': 'Transportation',
      'budgeted': 8000.0,
      'spent': 9200.0,
      'icon': Icons.directions_car,
      'color': Colors.blue,
    },
    {
      'category': 'Utilities',
      'budgeted': 12000.0,
      'spent': 11800.0,
      'icon': Icons.electrical_services,
      'color': Colors.orange,
    },
    {
      'category': 'Entertainment',
      'budgeted': 5000.0,
      'spent': 3200.0,
      'icon': Icons.movie,
      'color': Colors.purple,
    },
    {
      'category': 'Healthcare',
      'budgeted': 8000.0,
      'spent': 5750.0,
      'icon': Icons.medical_services,
      'color': Colors.red,
    },
  ];
  
  // Mock recent transactions
  final List<Map<String, dynamic>> recentTransactions = [
    {
      'description': 'Hi-Lo Supermarket',
      'category': 'Groceries',
      'amount': -1250.0,
      'date': 'Today',
      'icon': Icons.shopping_cart,
    },
    {
      'description': 'Gas Station',
      'category': 'Transportation',
      'amount': -2800.0,
      'date': 'Yesterday',
      'icon': Icons.local_gas_station,
    },
    {
      'description': 'JPS Electric Bill',
      'category': 'Utilities',
      'amount': -4200.0,
      'date': '2 days ago',
      'icon': Icons.electrical_services,
    },
    {
      'description': 'Movie Tickets',
      'category': 'Entertainment',
      'amount': -1500.0,
      'date': '3 days ago',
      'icon': Icons.movie,
    },
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      
      appBar: AppBar(
        title: Text('Budget Tracker'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Budget settings coming soon!')),
              );
            },
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Financial overview
            _buildFinancialOverview(),
            
            SizedBox(height: 24),
            
            // Budget categories
            _buildBudgetCategories(),
            
            SizedBox(height: 24),
            
            // Quick actions
            _buildQuickActions(),
            
            SizedBox(height: 24),
            
            // Recent transactions
            _buildRecentTransactions(),
          ],
        ),
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddExpenseDialog();
        },
        backgroundColor: Color(0xFF1E3A8A),
        tooltip: 'Add Expense',
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
  
  // Financial overview widget
  Widget _buildFinancialOverview() {
    double remainingBudget = totalBudget - totalSpent;
    double spentPercentage = (totalSpent / totalBudget) * 100;
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1E3A8A).withAlpha((0.3 * 255).round()),
            spreadRadius: 1,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha((0.9 * 255).round()),
            ),
          ),
          SizedBox(height: 16),
          
          // Income and spending
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Income',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.8 * 255).round()),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'J\$${monthlyIncome.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Spent',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.8 * 255).round()),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'J\$${totalSpent.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Budget Progress',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.9 * 255).round()),
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${spentPercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              LinearProgressIndicator(
                value: spentPercentage / 100,
                backgroundColor: Colors.white.withAlpha((0.3 * 255).round()),
                valueColor: AlwaysStoppedAnimation<Color>(
                  spentPercentage > 90 ? Colors.red : Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'J\$${remainingBudget.toStringAsFixed(0)} remaining',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.9 * 255).round()),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Budget categories section
  Widget _buildBudgetCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Budget Categories',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Detailed budget view coming soon!')),
                );
              },
              child: Text('View All'),
            ),
          ],
        ),
        SizedBox(height: 12),
        
        ...budgetCategories.map((category) {
          return _buildBudgetCategoryCard(category);
        }),
      ],
    );
  }
  
  // Individual budget category card
  Widget _buildBudgetCategoryCard(Map<String, dynamic> category) {
    double budgeted = category['budgeted'];
    double spent = category['spent'];
    double percentage = (spent / budgeted) * 100;
    bool isOverBudget = spent > budgeted;
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.1 * 255).round()),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: category['color'].withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  category['icon'],
                  color: category['color'],
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category['category'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'J\$${spent.toStringAsFixed(0)} of J\$${budgeted.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isOverBudget ? Colors.red : Colors.green,
                    ),
                  ),
                  if (isOverBudget)
                    Text(
                      'Over budget!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              isOverBudget ? Colors.red : category['color'],
            ),
          ),
        ],
      ),
    );
  }
  
  // Quick actions section
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                'Add Expense',
                Icons.add_circle,
                Colors.red,
                () => _showAddExpenseDialog(),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionButton(
                'Set Budget',
                Icons.account_balance_wallet,
                Colors.blue,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Budget setup coming soon!')),
                  );
                },
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionButton(
                'Reports',
                Icons.bar_chart,
                Colors.green,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Financial reports coming soon!')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Quick action button
  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha((0.2 * 255).round())),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha((0.1 * 255).round()),
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Recent transactions section
  Widget _buildRecentTransactions() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.1 * 255).round()),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Full transaction history coming soon!')),
                  );
                },
                child: Text('View All'),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          ...recentTransactions.map((transaction) {
            return Container(
              margin: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      transaction['icon'],
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction['description'],
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${transaction['category']} • ${transaction['date']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'J\$${transaction['amount'].abs().toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: transaction['amount'] < 0 ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  
  // Show add expense dialog
  void _showAddExpenseDialog() {
    final expenseController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = 'Groceries';
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Hi-Lo grocery shopping',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: expenseController,
              decoration: InputDecoration(
                labelText: 'Amount (JMD)',
                prefixText: 'J\$',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: InputDecoration(labelText: 'Category'),
              items: budgetCategories
                  .map<DropdownMenuItem<String>>((category) {
                // cast to String (or make sure your budgetCategories is List<Map<String, String>>)
                final cat = category['category'] as String;
                return DropdownMenuItem<String>(
                  value: cat,
                  child: Text(cat),
                );
              }).toList(),
              onChanged: (value) {
                selectedCategory = value!;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (expenseController.text.isNotEmpty && descriptionController.text.isNotEmpty) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Expense added successfully!')),
                );
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }
}