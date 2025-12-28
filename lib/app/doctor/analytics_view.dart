import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/doctor/doctor_service.dart';
import '../../core/supabase/supabase_config.dart';
import 'package:intl/intl.dart';

// Providers for analytics data
final analyticsStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final doctor = await ref.watch(doctorProfileProvider.future);
  if (doctor == null) return {};

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final monthStart = DateTime(now.year, now.month, 1);

  // Daily stats
  final dailyAppointments = await SupabaseConfig.client
      .from('appointments')
      .select('id')
      .eq('doctor_id', doctor.id)
      .gte('appointment_date', today.toIso8601String())
      .lt('appointment_date', today.add(const Duration(days: 1)).toIso8601String());

  final dailyBills = await SupabaseConfig.client
      .from('bills')
      .select('total_amount')
      .eq('doctor_id', doctor.id)
      .gte('created_at', today.toIso8601String());

  // Weekly stats
  final weeklyAppointments = await SupabaseConfig.client
      .from('appointments')
      .select('id')
      .eq('doctor_id', doctor.id)
      .gte('appointment_date', weekStart.toIso8601String());

  final weeklyBills = await SupabaseConfig.client
      .from('bills')
      .select('total_amount')
      .eq('doctor_id', doctor.id)
      .gte('created_at', weekStart.toIso8601String());

  // Monthly stats
  final monthlyAppointments = await SupabaseConfig.client
      .from('appointments')
      .select('id')
      .eq('doctor_id', doctor.id)
      .gte('appointment_date', monthStart.toIso8601String());

  final monthlyBills = await SupabaseConfig.client
      .from('bills')
      .select('total_amount')
      .eq('doctor_id', doctor.id)
      .gte('created_at', monthStart.toIso8601String());

  // Total patients
  final totalPatients = await SupabaseConfig.client
      .from('patient_assignments')
      .select('id')
      .eq('doctor_id', doctor.id);

  double calculateRevenue(List<dynamic> bills) {
    return bills.fold(0.0, (sum, bill) => sum + (bill['total_amount'] as num).toDouble());
  }

  return {
    'daily': {
      'appointments': dailyAppointments.length,
      'revenue': calculateRevenue(dailyBills),
    },
    'weekly': {
      'appointments': weeklyAppointments.length,
      'revenue': calculateRevenue(weeklyBills),
    },
    'monthly': {
      'appointments': monthlyAppointments.length,
      'revenue': calculateRevenue(monthlyBills),
    },
    'totalPatients': totalPatients.length,
  };
});

// Provider for chart data (last 7 days)
final revenueChartDataProvider = FutureProvider.autoDispose<List<ChartData>>((ref) async {
  final doctor = await ref.watch(doctorProfileProvider.future);
  if (doctor == null) return [];

  final now = DateTime.now();
  final List<ChartData> chartData = [];

  for (int i = 6; i >= 0; i--) {
    final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
    final nextDay = day.add(const Duration(days: 1));

    final bills = await SupabaseConfig.client
        .from('bills')
        .select('total_amount')
        .eq('doctor_id', doctor.id)
        .gte('created_at', day.toIso8601String())
        .lt('created_at', nextDay.toIso8601String());

    final revenue = bills.fold(0.0, (sum, bill) => sum + (bill['total_amount'] as num).toDouble());
    chartData.add(ChartData(DateFormat('E').format(day), revenue));
  }

  return chartData;
});

class ChartData {
  final String label;
  final double value;

  ChartData(this.label, this.value);
}

class AnalyticsView extends ConsumerStatefulWidget {
  const AnalyticsView({super.key});

  @override
  ConsumerState<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends ConsumerState<AnalyticsView> {
  String _selectedPeriod = 'Daily';

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(analyticsStatsProvider);
    final chartDataAsync = ref.watch(revenueChartDataProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Period Selector
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Daily', label: Text('Daily')),
                ButtonSegment(value: 'Weekly', label: Text('Weekly')),
                ButtonSegment(value: 'Monthly', label: Text('Monthly')),
              ],
              selected: {_selectedPeriod},
              onSelectionChanged: (Set<String> selected) {
                setState(() {
                  _selectedPeriod = selected.first;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Stats Cards
        statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (stats) {
            final periodKey = _selectedPeriod.toLowerCase();
            final periodStats = stats[periodKey] ?? {'appointments': 0, 'revenue': 0.0};
            
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: '$_selectedPeriod Appointments',
                        value: '${periodStats['appointments']}',
                        icon: Icons.calendar_month_rounded,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: '$_selectedPeriod Revenue',
                        value: '\$${(periodStats['revenue'] as double).toStringAsFixed(2)}',
                        icon: Icons.attach_money_rounded,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStatCard(
                  context,
                  title: 'Total Patients',
                  value: '${stats['totalPatients']}',
                  icon: Icons.people_rounded,
                  color: Colors.purple,
                  isWide: true,
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        // Revenue Chart
        Text(
          'Revenue Trend (Last 7 Days)',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        chartDataAsync.when(
          loading: () => const Card(
            child: SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stack) => Card(
            child: SizedBox(
              height: 250,
              child: Center(child: Text('Error loading chart: $error')),
            ),
          ),
          data: (chartData) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildBarChart(chartData, theme),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Quick Insights
        Text(
          'Quick Insights',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        statsAsync.when(
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
          data: (stats) {
            final weekly = stats['weekly'] ?? {};
            final monthly = stats['monthly'] ?? {};
            
            return Column(
              children: [
                _buildInsightCard(
                  context,
                  icon: Icons.trending_up_rounded,
                  title: 'Average Daily Revenue',
                  value: '\$${((monthly['revenue'] ?? 0.0) / 30).toStringAsFixed(2)}',
                  subtitle: 'Based on monthly data',
                ),
                const SizedBox(height: 8),
                _buildInsightCard(
                  context,
                  icon: Icons.event_available_rounded,
                  title: 'Appointments This Week',
                  value: '${weekly['appointments'] ?? 0}',
                  subtitle: 'Total scheduled',
                ),
                const SizedBox(height: 8),
                _buildInsightCard(
                  context,
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Monthly Revenue',
                  value: '\$${(monthly['revenue'] ?? 0.0).toStringAsFixed(2)}',
                  subtitle: 'Current month total',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isWide = false,
  }) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (isWide) const SizedBox(width: 12),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List<ChartData> data, ThemeData theme) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(child: Text('No data available')),
      );
    }

    final maxValue = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    
    return SizedBox(
      height: 250,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: data.map((item) {
                final height = maxValue > 0 ? (item.value / maxValue) * 200 : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (item.value > 0)
                          Text(
                            '\$${item.value.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        const SizedBox(height: 4),
                        Container(
                          height: height.clamp(20.0, 200.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.primaryContainer,
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: data.map((item) {
              return Expanded(
                child: Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
