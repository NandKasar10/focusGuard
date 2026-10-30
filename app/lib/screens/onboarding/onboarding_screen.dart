import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/storage_service.dart';
import '../../core/api_client.dart';
import 'video_record_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final StorageService _storage = StorageService();
  final ApiClient _api = ApiClient();

  bool _usagePermissionGranted = true;
  bool _overlayPermissionGranted = true;
  bool _notificationPermissionGranted = true;
  bool _screenshotConsent = true;

  Future<void> _proceed() async {
    // Save consent preference locally
    await _storage.setScreenshotConsent(_screenshotConsent);

    // Sync consent preference with backend
    try {
      await _api.put('/settings', body: {'screenshot_consent': _screenshotConsent});
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const VideoRecordScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions & Privacy'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Card(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Icon(Icons.verified_user_outlined, size: 48, color: theme.colorScheme.primary),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Privacy is Guaranteed 🔒',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• Motivational videos stay 100% on this device.\n• Screenshots are analyzed in-memory and deleted immediately.\n• You can revoke consent or wipe all data anytime.',
                                style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Why FocusGuard Needs Permissions:',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // 1. Usage Monitoring
                _buildPermissionCard(
                  icon: Icons.timelapse_rounded,
                  title: Platform.isAndroid ? 'Usage Stats Access' : 'Active Window Detection',
                  description: Platform.isAndroid
                      ? 'Required to detect when apps like YouTube, Instagram, and Facebook are opened.'
                      : 'Checks active window titles on Windows desktop to calculate your focus time.',
                  granted: _usagePermissionGranted,
                  onChanged: (val) => setState(() => _usagePermissionGranted = val),
                ),
                const SizedBox(height: 12),

                // 2. Draw over apps / Overlay
                _buildPermissionCard(
                  icon: Icons.picture_in_picture_rounded,
                  title: 'Draw Over Apps / Fullscreen Overlay',
                  description:
                      'Allows FocusGuard to pop up your personal motivational video immediately when your set limit is reached.',
                  granted: _overlayPermissionGranted,
                  onChanged: (val) => setState(() => _overlayPermissionGranted = val),
                ),
                const SizedBox(height: 12),

                // 3. Notifications
                _buildPermissionCard(
                  icon: Icons.notifications_active_outlined,
                  title: 'Notifications & Study Reminders',
                  description:
                      'Sends scheduled study reminders (e.g. "40 min ho gaye, ab dekh sakta hai") and daily focus summaries.',
                  granted: _notificationPermissionGranted,
                  onChanged: (val) => setState(() => _notificationPermissionGranted = val),
                ),
                const SizedBox(height: 12),

                // 4. AI Screenshot Consent
                _buildPermissionCard(
                  icon: Icons.screenshot_monitor_rounded,
                  title: 'AI Screenshot Reality-Check (Optional)',
                  description:
                      'With your consent, FocusGuard captures the screen only at trigger time to give contextual advice in Hinglish. Never saved on server.',
                  granted: _screenshotConsent,
                  isConsent: true,
                  onChanged: (val) => setState(() => _screenshotConsent = val),
                ),
                const SizedBox(height: 32),

                // Continue Button
                ElevatedButton.icon(
                  onPressed: _proceed,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Next: Record Your Motivational Video', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool granted,
    required ValueChanged<bool> onChanged,
    bool isConsent = false,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isConsent ? Colors.purple.shade50 : Colors.blue.shade50,
              child: Icon(icon, color: isConsent ? Colors.purple : Colors.blue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            Switch(
              value: granted,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

