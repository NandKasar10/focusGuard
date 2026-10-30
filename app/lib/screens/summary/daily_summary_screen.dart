import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/summary_provider.dart';

class DailySummaryScreen extends StatefulWidget {
  const DailySummaryScreen({super.key});

  @override
  State<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SummaryProvider>(context, listen: false).loadDailySummary(date: _selectedDate);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      if (mounted) {
        Provider.of<SummaryProvider>(context, listen: false).loadDailySummary(date: picked);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaryProvider = Provider.of<SummaryProvider>(context);
    final summary = summaryProvider.summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Summary & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'Change Date',
            onPressed: _pickDate,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => summaryProvider.loadDailySummary(date: _selectedDate),
          ),
        ],
      ),
      body: summaryProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => summaryProvider.loadDailySummary(date: _selectedDate),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Date Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.edit_calendar, size: 16),
                              label: const Text('Select Date'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Summary Message Banner
                        if (summary != null)
                          Card(
                            color: Colors.indigo.shade50,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(18.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.indigo.shade100,
                                    child: const Icon(Icons.insights_rounded, color: Colors.indigo),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'FocusGuard End-of-Day Report',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          summary.summaryMessage,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // 4 Key Stats Grid
                        if (summary != null)
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Screen Time',
                                  value: '${summary.totalScreenTimeMinutes}m',
                                  subtitle: 'Distracting apps',
                                  icon: Icons.timer_outlined,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Compliance',
                                  value: '${summary.compliancePercentage.toStringAsFixed(0)}%',
                                  subtitle: '${summary.followedCount}/${summary.suggestionsCount} followed',
                                  icon: Icons.check_circle_outline,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Focus Streak',
                                  value: '${summary.focusStreakDays} Days',
                                  subtitle: 'Consistent control',
                                  icon: Icons.local_fire_department,
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),

                        // App Breakdown Section
                        if (summary != null && summary.appBreakdown.isNotEmpty) ...[
                          Text('Usage by App', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: summary.appBreakdown.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final item = summary.appBreakdown[i];
                                return ListTile(
                                  title: Text(item.appName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${item.sessionCount} sessions'),
                                  trailing: Text('${item.totalMinutes} minutes', style: const TextStyle(fontWeight: FontWeight.bold)),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Timeline of Interventions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Interventions Timeline',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${summary?.timeline.length ?? 0} events',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (summary == null || summary.timeline.isEmpty)
                          Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: const Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(Icons.thumb_up_alt_outlined, size: 48, color: Colors.green),
                                  SizedBox(height: 12),
                                  Text(
                                    'No distractions exceeded limits today! 🎉',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'You stayed within all set time boundaries.',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: summary.timeline.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final item = summary.timeline[i];
                              final timeStr = DateFormat('hh:mm a').format(item.timestamp.toLocal());
                              final isFollowed = item.actionTakenAfter == 'closed_app' ||
                                  (item.userReply?.toLowerCase().contains('study') ?? false);

                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: isFollowed ? Colors.green.shade200 : Colors.amber.shade200,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Time and App Row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.access_time_rounded, size: 16, color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(item.appName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isFollowed ? Colors.green.shade50 : Colors.amber.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isFollowed ? 'Followed ✓' : 'Snoozed/Ignored',
                                              style: TextStyle(
                                                color: isFollowed ? Colors.green.shade800 : Colors.amber.shade900,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // AI Guidance Text
                                      Text(
                                        '"${item.suggestionText}"',
                                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[850], fontSize: 13.5),
                                      ),
                                      const Divider(height: 20),

                                      // User Reply and Action Taken After
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'User replied: ${item.userReply ?? "Pending"}',
                                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                                          ),
                                          Text(
                                            'Action: ${item.actionTakenAfter.replaceAll('_', ' ')}',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
