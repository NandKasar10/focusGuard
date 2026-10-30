import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/api_client.dart';
import '../../core/storage_service.dart';
import '../home/dashboard_screen.dart';

class VideoRecordScreen extends StatefulWidget {
  final bool isReRecording;
  const VideoRecordScreen({super.key, this.isReRecording = false});

  @override
  State<VideoRecordScreen> createState() => _VideoRecordScreenState();
}

class _VideoRecordScreenState extends State<VideoRecordScreen> {
  final StorageService _storage = StorageService();
  final ApiClient _api = ApiClient();
  final ImagePicker _picker = ImagePicker();

  String? _selectedVideoPath;
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _checkExistingVideo();
  }

  void _checkExistingVideo() {
    final existingPath = _storage.getLocalVideoPath();
    if (existingPath != null && File(existingPath).existsSync()) {
      _selectedVideoPath = existingPath;
      _initializePlayer(existingPath);
    }
  }

  Future<void> _initializePlayer(String path) async {
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(File(path));
    try {
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.play();
      setState(() {});
    } catch (e) {
      debugPrint('Video player init error: $e');
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  /// Pick video from files or gallery
  Future<void> _pickVideoFromGallery() async {
    setState(() => _isLoading = true);
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        const typeGroup = XTypeGroup(
          label: 'videos',
          extensions: ['mp4', 'mov', 'avi', 'mkv', 'webm'],
        );
        final file = await openFile(acceptedTypeGroups: [typeGroup]);
        if (file != null) {
          await _saveAndSetVideo(file.path);
        }
      } else {
        final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
        if (video != null) {
          await _saveAndSetVideo(video.path);
        }
      }
    } catch (e) {
      setState(() => _statusMessage = 'Could not select video: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Record video from camera (mobile)
  Future<void> _recordVideoFromCamera() async {
    setState(() => _isLoading = true);
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 2),
      );
      if (video != null) {
        await _saveAndSetVideo(video.path);
      }
    } catch (e) {
      setState(() => _statusMessage = 'Camera not available: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Copies the video strictly into app-private storage
  Future<void> _saveAndSetVideo(String sourcePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final ext = p.extension(sourcePath).isEmpty ? '.mp4' : p.extension(sourcePath);
    final targetPath = p.join(docsDir.path, 'focusguard_motivational_video$ext');

    // Copy to private local storage
    final srcFile = File(sourcePath);
    if (srcFile.existsSync()) {
      await srcFile.copy(targetPath);
      _selectedVideoPath = targetPath;
      await _storage.saveLocalVideoPath(targetPath);
      await _initializePlayer(targetPath);
      setState(() {
        _statusMessage = 'Motivational video saved securely on this device!';
      });
    }
  }

  /// Creates a mock test video file for desktop simulation when no video is on hand
  Future<void> _createSampleVideo() async {
    setState(() => _isLoading = true);
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final targetPath = p.join(docsDir.path, 'focusguard_sample_motivation.mp4');

      // Minimal valid MP4 container bytes for instant local testing
      final file = File(targetPath);
      if (!file.existsSync()) {
        await file.writeAsBytes([
          0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70,
          0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00,
          0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32,
        ]);
      }

      _selectedVideoPath = targetPath;
      await _storage.saveLocalVideoPath(targetPath);
      setState(() {
        _statusMessage = 'Sample motivational video created!';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Error creating sample video: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _finishSetup() async {
    if (_selectedVideoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record, upload, or create a motivational video first!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Sync only metadata flag with backend (NEVER the video file)
    try {
      await _api.put('/settings', body: {'has_video': true});
    } catch (_) {}

    await _storage.setOnboardingCompleted(true);

    if (mounted) {
      if (widget.isReRecording) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isReRecording ? 'Change Motivational Video' : 'Record Motivational Video'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Instructions Card
                Card(
                  color: Colors.amber.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.videocam_rounded, color: Colors.amber, size: 40),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'A Message from Your Focused Self 🎯',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Record a 15-30 second video telling yourself why your target matters, reminding yourself to close distractions. This video plays fullscreen whenever your limit triggers.',
                                style: TextStyle(color: Colors.brown.shade800, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Video Preview Area
                Container(
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _videoController != null && _videoController!.value.isInitialized
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                            Positioned(
                              bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.play_circle_fill, color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text('Auto-play Preview Active', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.video_library_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                _selectedVideoPath != null
                                    ? 'Video file loaded: ${p.basename(_selectedVideoPath!)}'
                                    : 'No video recorded or selected yet',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 20),

                if (_statusMessage != null) ...[
                  Text(
                    _statusMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                ],

                // Action Buttons for Video
                Row(
                  children: [
                    if (!Platform.isWindows) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _recordVideoFromCamera,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Record with Camera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _pickVideoFromGallery,
                        icon: const Icon(Icons.file_upload_outlined),
                        label: const Text('Choose Video File'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Quick sample generator button for instant testing
                TextButton.icon(
                  onPressed: _isLoading ? null : _createSampleVideo,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Use Instant Sample Video (For Quick Testing)'),
                ),
                const SizedBox(height: 24),

                // Finish / Save Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _finishSetup,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(
                          widget.isReRecording ? 'Save Changes' : 'Complete Setup & Go to Dashboard',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
