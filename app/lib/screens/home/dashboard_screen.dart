import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/usage_provider.dart';
import '../onboarding/video_record_screen.dart';
import '../settings/settings_screen.dart';
import '../summary/daily_summary_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UsageProvider>(context, listen: false).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final usage = Provider.of<UsageProvider>(context);

    final totalUsageMinutes = usage.trackedApps.fold<int>(
      0,
      (sum, item) => sum + item.currentUsageTodayMinutes,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: Colors.indigoAccent),
            const SizedBox(width: 8),
            const Text('FocusGuard'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, color: Colors.green, size: 8),
                  SizedBox(width: 4),
                  Text('Active', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_rounded),
            tooltip: 'Daily Summary',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DailySummaryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings & Privacy',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => usage.refreshUsageStats(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Greeting & Motivation Card
                  Card(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Namaste, ${auth.user?.name ?? _storage.getUserName() ?? 'Focuser'}! 👋',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.local_fire_department_rounded, color: Colors.deepOrange, size: 16),
                                    SizedBox(width: 4),
                                    Text('Focus Streak: 3 Days', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Goal: "${_storage.getStudyGoals()}"',
                            style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: usage.combinedDailyLimitMinutes > 0
                                ? (totalUsageMinutes / usage.combinedDailyLimitMinutes).clamp(0.0, 1.0)
                                : 0.0,
                            backgroundColor: Colors.grey.shade200,
                            color: totalUsageMinutes > usage.combinedDailyLimitMinutes ? Colors.red : theme.colorScheme.primary,
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Distracting Time: $totalUsageMinutes min', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Daily Limit: ${usage.combinedDailyLimitMinutes} min', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Motivational Video Status
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.deepPurple,
                        child: Icon(Icons.play_arrow_rounded, color: Colors.white),
                      ),
                      title: const Text('My Motivational Video', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        _storage.hasLocalVideo()
                            ? 'Ready • Plays automatically on limit reached'
                            : 'No video recorded yet',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: TextButton.icon(
                        icon: const Icon(Icons.videocam_outlined, size: 16),
                        label: const Text('Re-record'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const VideoRecordScreen(isReRecording: true)),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tracked Apps Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tracked Distracting Apps',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add App'),
                        onPressed: () => _showAddAppDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Tracked Apps List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: usage.trackedApps.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final app = usage.trackedApps[index];
                      final progress = app.dailyLimitMinutes > 0
                          ? (app.currentUsageTodayMinutes / app.dailyLimitMinutes).clamp(0.0, 1.0)
                          : 0.0;

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: _getAppColor(app.appName).withOpacity(0.15),
                                    child: Icon(_getAppIcon(app.appName), color: _getAppColor(app.appName), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(app.appName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        Text('Rule: ${app.packageOrProcess}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${app.currentUsageTodayMinutes} / ${app.dailyLimitMinutes}m',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: app.currentUsageTodayMinutes >= app.dailyLimitMinutes ? Colors.red : Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.grey[100],
                                  color: progress >= 1.0 ? Colors.redAccent : Colors.indigo,
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // --- DEBUG SIMULATION TOOLBAR ---
                  Card(
                    color: Colors.blueGrey.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.blueGrey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.bug_report_rounded, color: Colors.blueGrey, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Debug & Demo Simulator',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Simulate usage or trigger the limit immediately without waiting 60 minutes.',
                            style: TextStyle(color: Colors.black87, fontSize: 12),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  usage.simulateAddUsage(appName: 'YouTube', minutes: 15);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Added +15 min to YouTube')),
                                  );
                                },
                                icon: const Icon(Icons.add_circle_outline, size: 16),
                                label: const Text('+15m YouTube'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  usage.simulateAddUsage(appName: 'Instagram', minutes: 30);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Added +30 min to Instagram')),
                                  );
                                },
                                icon: const Icon(Icons.add_circle_outline, size: 16),
                                label: const Text('+30m Instagram'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  usage.simulateAddUsage(
                                    appName: 'YouTube',
                                    minutes: 60,
                                    triggerNow: true,
                                  );
                                },
                                icon: const Icon(Icons.flash_on_rounded, size: 18),
                                label: const Text('🔥 Trigger Limit Overlay Now!'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepOrange,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getAppColor(String name) {
    switch (name.toLowerCase()) {
      case 'youtube':
        return Colors.red;
      case 'instagram':
        return Colors.purple;
      case 'facebook':
        return Colors.blue;
      default:
        return Colors.teal;
    }
  }

  IconData _getAppIcon(String name) {
    switch (name.toLowerCase()) {
      case 'youtube':
        return Icons.play_circle_filled;
      case 'instagram':
        return Icons.camera_alt;
      case 'facebook':
        return Icons.facebook;
      default:
        return Icons.apps;
    }
  }

  void _showAddAppDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final patternCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '45');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Tracked App'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'App Name (e.g. Netflix, Reddit)')),
            TextField(controller: patternCtrl, decoration: const InputDecoration(labelText: 'Window Pattern (e.g. *Reddit*)')),
            TextField(controller: limitCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Daily Limit (minutes)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                Provider.of<UsageProvider>(context, listen: false).addTrackedApp(
                  appName: nameCtrl.text.trim(),
                  pattern: patternCtrl.text.isEmpty ? '*${nameCtrl.text.trim()}*' : patternCtrl.text.trim(),
                  process: nameCtrl.text.trim().toLowerCase(),
                  dailyLimitMinutes: int.tryParse(limitCtrl.text) ?? 60,
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

