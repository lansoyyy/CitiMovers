import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/ui_helpers.dart';
import '../../../services/auth_service.dart';
import '../../../services/wallet_service.dart';
import '../../../models/booking_model.dart';
import '../../models/rider_model.dart';

class RiderEarningsTab extends StatefulWidget {
  const RiderEarningsTab({super.key});

  @override
  State<RiderEarningsTab> createState() => _RiderEarningsTabState();
}

class _RiderEarningsTabState extends State<RiderEarningsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final WalletService _walletService = WalletService();

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _selectedPeriod = 'This Week';
  final List<String> _periods = [
    'Today',
    'This Week',
    'This Month',
    'All Time'
  ];

  // Data from Firebase
  double _totalEarnings = 0.0;
  double _todayEarnings = 0.0;
  double _walletBalance = 0.0; // Actual rider wallet balance
  int _totalDeliveries = 0;
  double _averageRating = 0.0;
  bool _isLoading = true;
  RiderModel? _riderData;

  // Earnings distribution constants
  static const double _operatorPercentage = 0.80;
  static const double _adminPercentage = 0.18;
  static const double _birPercentage = 0.02;

  // Chart data from Firebase
  List<double> _weeklyEarnings = [0, 0, 0, 0, 0, 0, 0];
  List<double> _monthlyEarnings = List.generate(12, (_) => 0.0);
  List<int> _weeklyDeliveries = [0, 0, 0, 0, 0, 0, 0];
  List<int> _monthlyDeliveries = List.generate(12, (_) => 0);

  // Recent transactions from Firebase
  List<Map<String, dynamic>> _recentTransactions = [];

  // Load wallet form controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();
  String _selectedPaymentMethod = 'gcash';
  String _selectedLoadMethod = 'gcash';
  bool _isProcessingTransaction = false;

  @override
  void initState() {
    super.initState();
    _loadEarningsData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.success,
                                AppColors.success.withValues(alpha: 0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'My Earnings',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontFamily: 'Bold',
                                  color: AppColors.white,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total Balance',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'Regular',
                                        color: AppColors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'P${_totalEarnings.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontFamily: 'Bold',
                                        color: AppColors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: _showLoadWalletDialog,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primaryBlue,
                                              foregroundColor: AppColors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.add_circle_outline,
                                                  size: 18,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Load Wallet',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontFamily: 'Bold',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Period Selector
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _periods.map((period) {
                                final isSelected = _selectedPeriod == period;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedPeriod = period;
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primaryRed
                                          : AppColors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      period,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'Bold',
                                        color: isSelected
                                            ? AppColors.white
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Stats Cards
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      icon: FontAwesomeIcons.truck,
                                      title: 'Deliveries',
                                      value: '$_totalDeliveries',
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _StatCard(
                                      icon: FontAwesomeIcons.star,
                                      title: 'Rating',
                                      value: _averageRating.toStringAsFixed(1),
                                      color: Colors.amber,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      icon: FontAwesomeIcons.pesoSign,
                                      title: 'Today',
                                      value:
                                          'P${_todayEarnings.toStringAsFixed(0)}',
                                      color: AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _StatCard(
                                      icon: FontAwesomeIcons.chartLine,
                                      title: 'Average',
                                      value:
                                          'P${(_totalEarnings / _totalDeliveries).toStringAsFixed(0)}',
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Earnings Distribution Card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryBlue,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Earnings Distribution',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontFamily: 'Bold',
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _DistributionRow(
                                  title: 'Operator (80%)',
                                  amount:
                                      'P${(_totalEarnings * _operatorPercentage).toStringAsFixed(2)}',
                                  color: AppColors.success,
                                  icon: Icons.account_balance,
                                ),
                                const SizedBox(height: 12),
                                _DistributionRow(
                                  title: 'Admin (18%)',
                                  amount:
                                      'P${(_totalEarnings * _adminPercentage).toStringAsFixed(2)}',
                                  color: AppColors.primaryBlue,
                                  icon: Icons.admin_panel_settings,
                                ),
                                const SizedBox(height: 12),
                                _DistributionRow(
                                  title: 'BIR (2%)',
                                  amount:
                                      'P${(_totalEarnings * _birPercentage).toStringAsFixed(2)}',
                                  color: AppColors.warning,
                                  icon: Icons.receipt_long,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Earnings Chart
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryRed,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Earnings Overview',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontFamily: 'Bold',
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                height: 200,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: _buildEarningsChart(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Performance Chart
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Delivery Performance',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontFamily: 'Bold',
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                height: 200,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: _buildPerformanceChart(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Earnings Distribution Chart
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.warning,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Earnings Distribution Breakdown',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontFamily: 'Bold',
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                height: 250,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: _buildDistributionChart(),
                              ),
                              const SizedBox(height: 16),
                              // Distribution Legend
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    _buildLegendItem(
                                        'Operator (80%)',
                                        AppColors.success,
                                        'P${(_totalEarnings * _operatorPercentage).toStringAsFixed(2)}'),
                                    const SizedBox(height: 8),
                                    _buildLegendItem(
                                        'Admin (18%)',
                                        AppColors.primaryBlue,
                                        'P${(_totalEarnings * _adminPercentage).toStringAsFixed(2)}'),
                                    const SizedBox(height: 8),
                                    _buildLegendItem(
                                        'BIR (2%)',
                                        AppColors.warning,
                                        'P${(_totalEarnings * _birPercentage).toStringAsFixed(2)}'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Recent Transactions
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryRed,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Recent Transactions',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontFamily: 'Bold',
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Show recent transactions from Firebase
                              if (_recentTransactions.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Text(
                                      'No transactions yet',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ..._recentTransactions.map((transaction) {
                                  final isPositive =
                                      transaction['type'] == 'earning' ||
                                          transaction['type'] == 'topup';
                                  final amount =
                                      (transaction['amount'] as num).toDouble();
                                  final createdAt = transaction['createdAt'];
                                  String dateStr = 'Unknown';

                                  final createdAtDate =
                                      _parseDateTime(createdAt);
                                  if (createdAtDate != null) {
                                    dateStr = DateFormat('MMM d, yyyy')
                                        .format(createdAtDate);
                                  }

                                  return _TransactionCard(
                                    title: _getTransactionTitle(
                                        transaction['type']),
                                    date: dateStr,
                                    amount: isPositive
                                        ? '+P${amount.toStringAsFixed(2)}'
                                        : '-P${amount.toStringAsFixed(2)}',
                                    isPositive: isPositive,
                                    onTap: () => _showTransactionDetails(
                                      _getTransactionTitle(transaction['type']),
                                      dateStr,
                                      isPositive
                                          ? '+P${amount.toStringAsFixed(2)}'
                                          : '-P${amount.toStringAsFixed(2)}',
                                      transaction['id'] ?? '',
                                      transaction['description'] ??
                                          'No description available',
                                      _formatStatus(
                                          transaction['status'] ?? 'completed'),
                                    ),
                                  );
                                }).toList(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
        ));
  }

  Future<void> _loadEarningsData() async {
    final riderId = _authService.currentUser?.userId;
    if (riderId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load rider data for rating and wallet balance
      final riderDoc = await _firestore.collection('riders').doc(riderId).get();
      double walletBalance = 0.0;
      if (riderDoc.exists) {
        final riderData = riderDoc.data()!;
        setState(() {
          _riderData = RiderModel.fromJson(riderData);
          _averageRating = _riderData?.rating ?? 0.0;
        });
        walletBalance = (riderData['walletBalance'] as num?)?.toDouble() ?? 0.0;
      }

      // Load completed bookings for earnings
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      final bookingsQuery = await _firestore
          .collection('bookings')
          .where('driverId', isEqualTo: riderId)
          .where('status', whereIn: ['completed', 'delivered'])
          .orderBy('createdAt', descending: true)
          .get();

      double totalEarnings = 0;
      double todayEarnings = 0;
      int totalDeliveries = 0;

      // Initialize chart data
      List<double> weeklyEarnings = [0, 0, 0, 0, 0, 0, 0];
      List<double> monthlyEarnings = List.generate(12, (_) => 0.0);
      List<int> weeklyDeliveries = [0, 0, 0, 0, 0, 0, 0];
      List<int> monthlyDeliveries = List.generate(12, (_) => 0);

      // Get start of week (Monday)
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      // Get start of month
      final startOfMonth = DateTime(now.year, now.month, 1);

      for (var doc in bookingsQuery.docs) {
        final booking = BookingModel.fromMap(doc.data());

        final baseFare = (booking.finalFare != null && booking.finalFare! > 0)
            ? booking.finalFare!
            : booking.estimatedFare;
        final loading = booking.loadingDemurrageFee ?? 0.0;
        final unloading = booking.unloadingDemurrageFee ?? 0.0;
        final earnings = baseFare + loading + unloading;

        totalEarnings += earnings;
        totalDeliveries++;

        // Check if today's earnings - fixed to check same day
        final bookingDate = booking.createdAt;
        if (bookingDate.isAfter(today) && bookingDate.isBefore(tomorrow)) {
          todayEarnings += earnings;
        }

        // Weekly data
        if (bookingDate.isAfter(startOfWeek)) {
          final dayIndex = bookingDate.weekday - 1; // 0 = Monday
          if (dayIndex >= 0 && dayIndex < 7) {
            weeklyEarnings[dayIndex] += earnings;
            weeklyDeliveries[dayIndex]++;
          }
        }

        // Monthly data - fixed to use all 12 months
        if (bookingDate.isAfter(startOfMonth)) {
          final monthIndex = bookingDate.month - 1; // 0 = January
          if (monthIndex >= 0 && monthIndex < 12) {
            monthlyEarnings[monthIndex] += earnings;
            monthlyDeliveries[monthIndex]++;
          }
        }
      }

      // Load recent transactions from wallet_transactions
      final transactionsQuery = await _firestore
          .collection('wallet_transactions')
          .where('userId', isEqualTo: riderId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> transactions = [];
      for (var doc in transactionsQuery.docs) {
        final data = doc.data();
        transactions.add({
          'id': doc.id,
          'type': data['type'] ?? 'unknown',
          'amount': data['amount'] ?? 0.0,
          'description': data['description'] ?? '',
          'createdAt': data['createdAt'],
          'status': data['status'] ?? 'completed',
          'previousBalance': data['previousBalance'] ?? 0.0,
          'newBalance': data['newBalance'] ?? 0.0,
        });
      }

      setState(() {
        _totalEarnings = totalEarnings;
        _todayEarnings = todayEarnings;
        _walletBalance = walletBalance;
        _totalDeliveries = totalDeliveries;
        _weeklyEarnings = weeklyEarnings;
        _monthlyEarnings = monthlyEarnings;
        _weeklyDeliveries = weeklyDeliveries;
        _monthlyDeliveries = monthlyDeliveries;
        _recentTransactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading earnings data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _loadEarningsData();
  }

  void _showTopUpDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: AppColors.success,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Top Up Wallet',
                      style: TextStyle(
                        fontSize: 20,
                        fontFamily: 'Bold',
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Current Balance
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.success.withValues(alpha: 0.1),
                      AppColors.success.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Balance',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Regular',
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'P${_totalEarnings.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontFamily: 'Bold',
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quick Amount Buttons
              const Text(
                'Quick Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _QuickAmountButton(
                    amount: '500',
                    onTap: () => _amountController.text = '500',
                  ),
                  const SizedBox(width: 12),
                  _QuickAmountButton(
                    amount: '1000',
                    onTap: () => _amountController.text = '1000',
                  ),
                  const SizedBox(width: 12),
                  _QuickAmountButton(
                    amount: '2000',
                    onTap: () => _amountController.text = '2000',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Amount Input
              const Text(
                'Enter Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount (P)',
                  prefixText: 'P ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),

              // Payment Methods
              const Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Bold',
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _PaymentMethodCard(
                icon: FontAwesomeIcons.g,
                title: 'GCash',
                subtitle: 'Fast and secure payment',
                isSelected: _selectedPaymentMethod == 'gcash',
                onTap: () => setState(() => _selectedPaymentMethod = 'gcash'),
              ),
              const SizedBox(height: 12),
              _PaymentMethodCard(
                icon: FontAwesomeIcons.creditCard,
                title: 'PayMaya',
                subtitle: 'Digital wallet payment',
                isSelected: _selectedPaymentMethod == 'paymaya',
                onTap: () => setState(() => _selectedPaymentMethod = 'paymaya'),
              ),
              const SizedBox(height: 12),
              _PaymentMethodCard(
                icon: FontAwesomeIcons.university,
                title: 'Bank Transfer',
                subtitle: 'Direct bank deposit',
                isSelected: _selectedPaymentMethod == 'bank',
                onTap: () => setState(() => _selectedPaymentMethod = 'bank'),
              ),
              const Spacer(),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessingTransaction
                          ? null
                          : () async {
                              if (_amountController.text.isNotEmpty) {
                                final amount =
                                    double.tryParse(_amountController.text);
                                if (amount != null && amount > 0) {
                                  setState(
                                      () => _isProcessingTransaction = true);

                                  final riderId =
                                      _authService.currentUser?.userId;
                                  if (riderId != null) {
                                    final success =
                                        await _walletService.topUpWallet(
                                      userId: riderId,
                                      amount: amount,
                                      description:
                                          'Top up wallet via ${_selectedPaymentMethod.toUpperCase()}',
                                      referenceId: _selectedPaymentMethod,
                                    );

                                    if (success) {
                                      Navigator.of(context).pop();
                                      UIHelpers.showSuccessToast(
                                          'Top-up of P${amount.toStringAsFixed(2)} successful');
                                      _amountController.clear();
                                      _refreshData();
                                    } else {
                                      UIHelpers.showErrorToast(
                                          'Top-up failed. Please try again.');
                                    }
                                  } else {
                                    UIHelpers.showErrorToast(
                                        'User not logged in');
                                  }

                                  setState(
                                      () => _isProcessingTransaction = false);
                                } else {
                                  UIHelpers.showErrorToast(
                                      'Please enter a valid amount');
                                }
                              } else {
                                UIHelpers.showErrorToast(
                                    'Please enter an amount');
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Proceed',
                        style: TextStyle(color: AppColors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoadWalletDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.send_to_mobile,
                        color: AppColors.primaryBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Load Wallet',
                        style: TextStyle(
                          fontSize: 20,
                          fontFamily: 'Bold',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Available Balance
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryBlue.withValues(alpha: 0.1),
                        AppColors.primaryBlue.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available Balance',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Regular',
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'P${_walletBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontFamily: 'Bold',
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Recipient Information
                const Text(
                  'Recipient Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Bold',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _recipientController,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number / Account Number',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColors.scaffoldBackground,
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // Amount Input
                const Text(
                  'Amount to Load',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Bold',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount (P)',
                    prefixText: 'P ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColors.scaffoldBackground,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),

                // Load Methods
                const Text(
                  'Load Method',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Bold',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _LoadMethodCard(
                  icon: FontAwesomeIcons.g,
                  title: 'GCash',
                  subtitle: 'Send to GCash number',
                  isSelected: _selectedLoadMethod == 'gcash',
                  onTap: () => setState(() => _selectedLoadMethod = 'gcash'),
                ),
                const SizedBox(height: 12),
                _LoadMethodCard(
                  icon: FontAwesomeIcons.creditCard,
                  title: 'PayMaya',
                  subtitle: 'Send to PayMaya account',
                  isSelected: _selectedLoadMethod == 'paymaya',
                  onTap: () => setState(() => _selectedLoadMethod = 'paymaya'),
                ),
                const SizedBox(height: 12),
                _LoadMethodCard(
                  icon: FontAwesomeIcons.creditCard,
                  title: 'Debit Card',
                  subtitle: 'Transfer to debit card',
                  isSelected: _selectedLoadMethod == 'debit',
                  onTap: () => setState(() => _selectedLoadMethod = 'debit'),
                ),
                const SizedBox(height: 12),
                _LoadMethodCard(
                  icon: FontAwesomeIcons.creditCard,
                  title: 'Credit Card',
                  subtitle: 'Transfer to credit card',
                  isSelected: _selectedLoadMethod == 'credit',
                  onTap: () => setState(() => _selectedLoadMethod = 'credit'),
                ),
                const SizedBox(height: 12),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessingTransaction
                            ? null
                            : () async {
                                if (_amountController.text.isNotEmpty &&
                                    _recipientController.text.isNotEmpty) {
                                  final amount =
                                      double.tryParse(_amountController.text);
                                  if (amount != null && amount > 0) {
                                    if (amount > _walletBalance) {
                                      UIHelpers.showErrorToast(
                                          'Insufficient balance');
                                      return;
                                    }

                                    setState(
                                        () => _isProcessingTransaction = true);

                                    final riderId =
                                        _authService.currentUser?.userId;
                                    if (riderId != null) {
                                      // Create withdrawal transaction
                                      final walletTransactionId = _firestore
                                          .collection('wallet_transactions')
                                          .doc()
                                          .id;
                                      final previousBalance = _walletBalance;
                                      final newBalance =
                                          _walletBalance - amount;

                                      try {
                                        await _firestore.runTransaction(
                                            (transaction) async {
                                          // Update rider wallet balance
                                          transaction.update(
                                            _firestore
                                                .collection('riders')
                                                .doc(riderId),
                                            {
                                              'walletBalance': newBalance,
                                              'updatedAt': DateTime.now()
                                                  .toIso8601String(),
                                            },
                                          );

                                          // Add withdrawal transaction record
                                          transaction.set(
                                            _firestore
                                                .collection(
                                                    'wallet_transactions')
                                                .doc(walletTransactionId),
                                            {
                                              'id': walletTransactionId,
                                              'userId': riderId,
                                              'type': 'withdrawal',
                                              'amount': amount,
                                              'previousBalance':
                                                  previousBalance,
                                              'newBalance': newBalance,
                                              'description':
                                                  'Withdrawal to ${_recipientController.text} via ${_selectedLoadMethod.toUpperCase()}',
                                              'referenceId':
                                                  _selectedLoadMethod,
                                              'recipient':
                                                  _recipientController.text,
                                              'status': 'pending',
                                              'createdAt':
                                                  FieldValue.serverTimestamp(),
                                            },
                                          );
                                        });

                                        Navigator.of(context).pop();
                                        UIHelpers.showSuccessToast(
                                            'Withdrawal of P${amount.toStringAsFixed(2)} submitted');
                                        _amountController.clear();
                                        _recipientController.clear();
                                        _refreshData();
                                      } catch (e) {
                                        UIHelpers.showErrorToast(
                                            'Withdrawal failed. Please try again.');
                                      }
                                    } else {
                                      UIHelpers.showErrorToast(
                                          'User not logged in');
                                    }

                                    setState(
                                        () => _isProcessingTransaction = false);
                                  } else {
                                    UIHelpers.showErrorToast(
                                        'Please enter a valid amount');
                                  }
                                } else {
                                  UIHelpers.showErrorToast(
                                      'Please fill all fields');
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Send Load',
                          style: TextStyle(color: AppColors.white),
                        ),
                      ),
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

  void _showTransactionDetails(String title, String date, String amount,
      String transactionId, String description, String status) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: AppColors.primaryRed,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Transaction Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontFamily: 'Bold',
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Transaction Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Transaction ID', transactionId),
                    _buildDetailRow('Date', date),
                    _buildDetailRow('Amount', amount),
                    _buildDetailRow('Status', _formatStatus(status)),
                    const SizedBox(height: 16),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Bold',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Handle multiline description with distribution details
                    ...description.split('\n\n').map((section) {
                      if (section.startsWith('Distribution:')) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Distribution:',
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'Bold',
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...section
                                .substring(13)
                                .split('\n')
                                .map((line) => Padding(
                                      padding: const EdgeInsets.only(
                                          left: 8, top: 2),
                                      child: Text(
                                        line.trim(),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontFamily: 'Regular',
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    )),
                            const SizedBox(height: 8),
                          ],
                        );
                      } else if (section.startsWith('Recipient:') ||
                          section.startsWith('Method:')) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...section.split('\n').map((line) => Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    line.trim(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Regular',
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                )),
                            const SizedBox(height: 8),
                          ],
                        );
                      } else {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            section,
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Regular',
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        UIHelpers.showInfoToast('Downloading receipt...');
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Download Receipt'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        UIHelpers.showInfoToast('Opening customer support...');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Contact Support'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Medium',
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Regular',
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTransactionTitle(String? type) {
    switch (type) {
      case 'earning':
        return 'Delivery Earnings';
      case 'load':
        return 'Load Wallet';
      case 'top_up':
        return 'Top Up';
      case 'withdrawal':
        return 'Withdrawal';
      case 'refund':
        return 'Refund';
      default:
        return 'Transaction';
    }
  }

  String _formatStatus(dynamic status) {
    if (status == null) return 'Unknown';
    final statusStr = status.toString().toLowerCase();
    switch (statusStr) {
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return statusStr[0].toUpperCase() + statusStr.substring(1);
    }
  }

  Widget _buildEarningsChart() {
    final isWeekly =
        _selectedPeriod == 'This Week' || _selectedPeriod == 'Today';
    final data = isWeekly ? _weeklyEarnings : _monthlyEarnings;
    final labels = isWeekly
        ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec'
          ];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 500,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.textSecondary.withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < labels.length) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      labels[index],
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Regular',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: 500,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    'P${value.toInt()}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: data.reduce((a, b) => a > b ? a : b) + 500,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
                data.length, (index) => FlSpot(index.toDouble(), data[index])),
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                AppColors.primaryRed,
                AppColors.primaryRed.withValues(alpha: 0.8),
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.white,
                  strokeWidth: 2,
                  strokeColor: AppColors.primaryRed,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryRed.withValues(alpha: 0.3),
                  AppColors.primaryRed.withValues(alpha: 0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionChart() {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 60,
        sections: [
          PieChartSectionData(
            color: AppColors.success,
            value: _operatorPercentage * 100,
            title: '${(_operatorPercentage * 100).toInt()}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 16,
              fontFamily: 'Bold',
              color: AppColors.white,
            ),
          ),
          PieChartSectionData(
            color: AppColors.primaryBlue,
            value: _adminPercentage * 100,
            title: '${(_adminPercentage * 100).toInt()}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 16,
              fontFamily: 'Bold',
              color: AppColors.white,
            ),
          ),
          PieChartSectionData(
            color: AppColors.warning,
            value: _birPercentage * 100,
            title: '${(_birPercentage * 100).toInt()}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 16,
              fontFamily: 'Bold',
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color, String amount) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Medium',
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'Bold',
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceChart() {
    final isWeekly =
        _selectedPeriod == 'This Week' || _selectedPeriod == 'Today';
    final deliveryData = isWeekly ? _weeklyDeliveries : _monthlyDeliveries;
    final labels = isWeekly
        ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec'
          ];

    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.textSecondary.withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < labels.length) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      labels[index],
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Regular',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: 2,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: deliveryData.reduce((a, b) => a > b ? a : b) + 2,
        barGroups: List.generate(
          deliveryData.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: deliveryData[index].toDouble(),
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue,
                    AppColors.primaryBlue.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  final String amount;
  final VoidCallback onTap;

  const _QuickAmountButton({
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primaryRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.primaryRed.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            'P$amount',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Bold',
              color: AppColors.primaryRed,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryRed.withValues(alpha: 0.1)
              : AppColors.scaffoldBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryRed
                : AppColors.textSecondary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryRed
                    : AppColors.textSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.white : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Bold',
                      color: isSelected
                          ? AppColors.primaryRed
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color:
                  isSelected ? AppColors.primaryRed : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Regular',
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontFamily: 'Bold',
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final String title;
  final String date;
  final String amount;
  final bool isPositive;
  final VoidCallback? onTap;

  const _TransactionCard({
    required this.title,
    required this.date,
    required this.amount,
    required this.isPositive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isPositive ? AppColors.success : AppColors.error)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                color: isPositive ? AppColors.success : AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontFamily: 'Bold',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amount,
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Bold',
                color: isPositive ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final IconData icon;

  const _DistributionRow({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Bold',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Bold',
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LoadMethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue.withValues(alpha: 0.1)
              : AppColors.scaffoldBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBlue
                : AppColors.textSecondary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryBlue
                    : AppColors.textSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.white : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Bold',
                      color: isSelected
                          ? AppColors.primaryBlue
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Regular',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color:
                  isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
