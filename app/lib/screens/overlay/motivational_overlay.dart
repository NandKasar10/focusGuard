import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/suggestion_model.dart';

class MotivationalOverlay extends StatefulWidget {
  final String appName;
  final String? videoPath;
  final SuggestionModel suggestion;
  final int dailyMinutes;
  final Future<void> Function(String reply) onReplySelected;

  const MotivationalOverlay({
    super.key,
    required this.appName,
    required this.videoPath,
    required this.suggestion,
    required this.dailyMinutes,
    required this.onReplySelected,
  });

  @override
  State<MotivationalOverlay> createState() => _MotivationalOverlayState();
}

class _MotivationalOverlayState extends State<MotivationalOverlay> {
  VideoPlayerController? _videoController;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (widget.videoPath != null && File(widget.videoPath!).existsSync()) {
      _videoController = VideoPlayerController.file(File(widget.videoPath!));
      try {
        await _videoController!.initialize();
        _videoController!.setLooping(true);
        _videoController!.play();
        setState(() {});
      } catch (e) {
        debugPrint('Overlay video error: $e');
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _handleAction(String reply) async {
    setState(() => _isResponding = true);
    await widget.onReplySelected(reply);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent accidental back button dismissing
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: SafeArea(
          child: Stack(
            children: [
              // 1. Background / Center Video Player
              Center(
                child: _videoController != null && _videoController!.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      )
                    : Container(
                        padding: const EdgeInsets.all(32),
                        margin: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 2),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.alarm_on_rounded, size: 72, color: Colors.amber),
                            const SizedBox(height: 16),
                            Text(
                              'Time Limit Reached on ${widget.appName}!',
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You have spent ${widget.dailyMinutes} minutes on ${widget.appName} today.',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
              ),

              // 2. Top Banner: Intervention Title
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.amber, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'FocusGuard Intervention • ${widget.appName} (${widget.dailyMinutes}m)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Bottom Card: AI Hinglish Guidance & Action Buttons
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 580),
                    child: Card(
                      color: const Color(0xFF1E1E2E).withValues(alpha: 0.95),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.indigo.shade400, width: 1.5),
                      ),
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // AI Guidance Header & Hinglish Nudge
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.purple.shade900,
                                  child: const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Text(
                                            'AI Study Buddy',
                                            style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          SizedBox(width: 6),
                                          Text('• Reality Check', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        widget.suggestion.suggestionText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // 3 Action Buttons (as specified in prompt)
                            if (_isResponding)
                              const Center(child: CircularProgressIndicator())
                            else
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: [
                                  // Button 1: "Okay, I'll study"
                                  ElevatedButton.icon(
                                    onPressed: () => _handleAction("Okay, I'll study"),
                                    icon: const Icon(Icons.check_circle_outline, size: 18),
                                    label: const Text("Okay, I'll study"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),

                                  // Button 2: "Snooze 10 min"
                                  OutlinedButton.icon(
                                    onPressed: () => _handleAction("Snooze 10 min"),
                                    icon: const Icon(Icons.snooze_rounded, size: 18),
                                    label: const Text("Snooze 10 min"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.amberAccent,
                                      side: const BorderSide(color: Colors.amberAccent),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),

                                  // Button 3: "Ignore"
                                  TextButton(
                                    onPressed: () => _handleAction("Ignore"),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white60,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                    child: const Text("Ignore"),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
