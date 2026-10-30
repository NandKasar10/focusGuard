import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/storage_service.dart';
import '../../core/api_client.dart';
import '../../services/window_detector_service.dart';
import 'video_record_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  final StorageService _storage = StorageService();
  final ApiClient _api = ApiClient();
  final WindowDetectorService _detector = WindowDetectorService();

  bool _usagePermissionGranted = false;
  bool _overlayPermissionGranted = false;
  bool _notificationPermissionGranted = true;
  bool _screenshotConsent = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNativePermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNativePermissions();
    }
  }

  Future<void> _checkNativePermissions() async {
    if (Platform.isAndroid) {
      final usage = await _detector.hasUsagePermission();
      final overlay = await _detector.hasOverlayPermission();
      if (mounted) {
        setState(() {
          _usagePermissionGranted = usage;
          _overlayPermissionGranted = overlay;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _usagePermissionGranted = true;
          _overlayPermissionGranted = true;
        });
      }
    }
  }

  Future<void> _proceed() async {
    // If on Android and Usage permission is not granted, warn the user
    if (Platform.isAndroid && !_usagePermissionGranted) {
      final allowProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Usage Access Needed ⚠️'),
          content: const Text(
            'Without Usage Access, FocusGuard cannot monitor apps like YouTube or Instagram.\n\nWould you like to grant it now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Skip for now'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop(false);
                _detector.openUsageSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      if (allowProceed != true) return;
    }

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
                // Header Privacy Guarantee
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
                  'Permissions Required for FocusGuard:',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // 1. Usage Monitoring
                _buildActionPermissionCard(
                  icon: Icons.timelapse_rounded,
                  title: Platform.isAndroid ? 'Usage Stats Access (Crucial)' : 'Active Window Detection',
                  description: Platform.isAndroid
                      ? 'Required to detect screen time on YouTube, Instagram, and Facebook.'
                      : 'Checks active window titles on Windows desktop to calculate your focus time.',
                  isGranted: _usagePermissionGranted,
                  onAction: () async {
                    if (Platform.isAndroid) {
                      await _detector.openUsageSettings();
                    } else {
                      setState(() => _usagePermissionGranted = !_usagePermissionGranted);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // 2. Draw over apps / Overlay
                _buildActionPermissionCard(
                  icon: Icons.picture_in_picture_rounded,
                  title: 'Draw Over Apps / Fullscreen Overlay',
                  description:
                      'Allows FocusGuard to pop up your personal motivational video immediately over distracting apps.',
                  isGranted: _overlayPermissionGranted,
                  onAction: () async {
                    if (Platform.isAndroid) {
                      await _detector.openOverlaySettings();
                    } else {
                      setState(() => _overlayPermissionGranted = !_overlayPermissionGranted);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // 3. Notifications
                _buildToggleCard(
                  icon: Icons.notifications_active_outlined,
                  title: 'Notifications & Study Reminders',
                  description:
                      'Sends scheduled study reminders (e.g. "40 min ho gaye, ab dekh sakta hai") and daily focus summaries.',
                  value: _notificationPermissionGranted,
                  onChanged: (val) => setState(() => _notificationPermissionGranted = val),
                ),
                const SizedBox(height: 12),

                // 4. AI Screenshot Consent
                _buildToggleCard(
                  icon: Icons.screenshot_monitor_rounded,
                  title: 'AI Screenshot Reality-Check (Optional)',
                  description:
                      'With your consent, FocusGuard captures the screen only at trigger time to give contextual advice in Hinglish. Never saved on server.',
                  value: _screenshotConsent,
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

  Widget _buildActionPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onAction,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isGranted ? Colors.green.shade300 : Colors.amber.shade400,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isGranted ? Colors.green.shade50 : Colors.amber.shade50,
              child: Icon(icon, color: isGranted ? Colors.green : Colors.amber.shade800),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      if (isGranted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Granted ✓', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                  const SizedBox(height: 8),
                  if (!isGranted)
                    OutlinedButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('Enable in Settings'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.amber.shade900,
                        side: BorderSide(color: Colors.amber.shade700),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
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
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
