import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/usage_provider.dart';
import '../auth/login_screen.dart';
import '../onboarding/video_record_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();
  final ApiClient _api = ApiClient();

  late TextEditingController _goalsCtrl;
  late TextEditingController _limitCtrl;
  bool _screenshotConsent = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _goalsCtrl = TextEditingController(text: _storage.getStudyGoals());
    final usage = Provider.of<UsageProvider>(context, listen: false);
    _limitCtrl = TextEditingController(text: usage.combinedDailyLimitMinutes.toString());
    _screenshotConsent = _storage.getScreenshotConsent();
  }

  @override
  void dispose() {
    _goalsCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final usage = Provider.of<UsageProvider>(context, listen: false);

    final newLimit = int.tryParse(_limitCtrl.text) ?? 60;
    await usage.updateCombinedLimit(newLimit);
    await _storage.setStudyGoals(_goalsCtrl.text.trim());
    await _storage.setScreenshotConsent(_screenshotConsent);

    try {
      await _api.put(
        '/settings',
        body: {
          'study_goals': _goalsCtrl.text.trim(),
          'screenshot_consent': _screenshotConsent,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Local settings saved (Backend sync error: $e)')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _wipeUserData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Telemetry & Data?'),
        content: const Text(
          'This will permanently delete all your usage logs, AI suggestions, and reminders from the server. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _api.delete('/settings/data');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data successfully deleted from server!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Privacy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Daily Combined Limit
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Combined Daily Distraction Limit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text('Total maximum distracting time across all tracked apps per day.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _limitCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Minutes per day',
                            suffixText: 'minutes',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Study Goals
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your Study / Productivity Goals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text('The AI uses this to give you personalized and relatable Hinglish nudges.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _goalsCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Goals & Targets',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Privacy & Screenshot Consent
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Privacy & AI Vision Consent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Capture Screen at Trigger Time'),
                          subtitle: const Text('Analyzed in-memory for contextual advice. Never stored on disk or server.'),
                          value: _screenshotConsent,
                          onChanged: (val) => setState(() => _screenshotConsent = val),
                        ),
                        const Divider(height: 24),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.videocam_outlined, color: Colors.deepPurple),
                          title: const Text('Motivational Video'),
                          subtitle: const Text('Stored strictly in private local device storage'),
                          trailing: TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const VideoRecordScreen(isReRecording: true)),
                              );
                            },
                            child: const Text('Re-record'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Save Settings Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 28),

                // Danger / Privacy Zone
                Card(
                  color: Colors.red.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Privacy Control & Data Deletion', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                        const SizedBox(height: 6),
                        Text(
                          'You have full control of your data. You can delete all logs from the server at any time.',
                          style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _wipeUserData,
                          icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                          label: const Text('Wipe All My Data From Server', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Logout
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await auth.logout();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Log Out', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
