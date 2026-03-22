import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'camera_capture_page.dart';
import 'yolo_service.dart';
import 'detection_preview.dart';
import 'firebase_service.dart';
import 'model/issue_model.dart';
import 'user_service.dart';
import 'app_theme.dart';

class ReportIssuePage extends StatefulWidget {
  const ReportIssuePage({super.key});

  @override
  State<ReportIssuePage> createState() => _ReportIssuePageState();
}

class _ReportIssuePageState extends State<ReportIssuePage> {
  final yolo = YoloService();
  final firebase = FirebaseService();
  String output = "No detection yet";
  bool _isLoading = false;
  Position? _currentPosition;
  String? _detectedImagePath;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final ok = await _ensurePermissions();
    if (!ok) return;
    await yolo.loadModel();
    await _getCurrentLocation();
  }

  Future<bool> _ensurePermissions() async {
    final cam = await Permission.camera.status;
    final loc = await Permission.locationWhenInUse.status;

    final req = <Permission>[];
    if (!cam.isGranted) req.add(Permission.camera);
    if (!loc.isGranted) req.add(Permission.locationWhenInUse);

    if (req.isEmpty) return true;

    await req.request();
    // check results
    for (final p in req) {
      if (!await p.isGranted) return false;
    }
    return true;
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  /// Unified report flow: pick image → caption → YOLO → preview (if detections) → upload → create issue.
  Future<void> _reportIssue() async {
    if (_currentPosition == null) {
      _showSnackBar("Please wait for location...");
      return;
    }

    if (!await Permission.camera.isGranted) {
      final res = await Permission.camera.request();
      if (!res.isGranted) {
        _showSnackBar('Camera permission is required');
        return;
      }
    }

    // 1) Choose camera or gallery
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _isLoading = true;
      output = "Detecting...";
    });

    try {
      if (_currentPosition == null) await _getCurrentLocation();

      // 2) Run YOLO detection first
      Map<String, dynamic> yoloResult = {};
      try {
        yoloResult = await yolo.detectFromFile(picked.path);
      } catch (e) {
        if (mounted) _showSnackBar('AI detection skipped: $e');
      }

      final detections = yoloResult['detections'] as List<Map<String, dynamic>>? ?? [];
      bool confirmed = true;

      // 3) If detections found, show preview with boxes and require user confirm
      if (detections.isNotEmpty) {
        final popResult = await Navigator.push<dynamic>(
          context,
          MaterialPageRoute(
            builder: (_) => DetectionPreview(imagePath: picked.path, detections: detections),
          ),
        );
        confirmed = popResult == true || (popResult is Map && popResult['confirmed'] == true);
        if (!confirmed) {
          setState(() {
            output = "Reporting cancelled.";
            _isLoading = false;
          });
          return;
        }
      } else {
        setState(() => output = "No AI detections. Posting as generic issue.");
      }

      // 4) Optional caption/description AFTER AI detection
      final descCtrl = TextEditingController();
      final description = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(detections.isNotEmpty ? 'Add a description for detected issue (optional)' : 'Add a description (optional)'),
          content: TextField(
            controller: descCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: detections.isNotEmpty ? 'Describe the detected issue or leave blank...' : 'Describe the issue or leave blank...',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, descCtrl.text.trim()),
              child: const Text('Post Issue'),
            ),
          ],
        ),
      );
      if (description == null) {
        setState(() {
          output = "Reporting cancelled.";
          _isLoading = false;
        });
        return;
      }

      // 5) Upload original image (for home feed)
      setState(() => output = "Uploading image...");
      final imageUrl = await firebase.uploadImage(File(picked.path));
      if (imageUrl == null || imageUrl.isEmpty) {
        setState(() {
          output = "Failed to upload image. Please try again.";
          _isLoading = false;
        });
        return;
      }

      // 6) Create detected/annotated image for admin (only when YOLO found detections)
      String? detectedImageUrl;
      if (detections.isNotEmpty) {
        try {
          final annotatedPath = await _createAnnotatedImage(picked.path, detections);
          if (annotatedPath != null) {
            detectedImageUrl = await firebase.uploadImage(File(annotatedPath));
            try { await File(annotatedPath).delete(); } catch (_) {}
          }
        } catch (e) {
          if (mounted) _showSnackBar('Could not create detected image: $e');
        }
      }

      // 7) Create issue
      final className = (yoloResult['class'] ?? 'Campus').toString();
      final severity = (yoloResult['severity'] ?? 'Medium').toString();
      final confidence = (yoloResult['confidence'] is num)
          ? (yoloResult['confidence'] as num).toDouble()
          : double.tryParse('${yoloResult["confidence"]}') ?? 0.0;

      final issue = Issue(
        title: description.isNotEmpty ? description : 'Post',
        className: className,
        severity: severity,
        confidence: confidence,
        latitude: _currentPosition?.latitude ?? 0.0,
        longitude: _currentPosition?.longitude ?? 0.0,
        status: "Pending",
        imageUrl: imageUrl,
        detectedImageUrl: detectedImageUrl,
        reportedAt: DateTime.now(),
        reportedBy: (UserService.username?.isNotEmpty == true)
            ? UserService.username
            : UserService.userId,
      );
      firebase.addIssue(issue);
      _descriptionController.text = description;

      setState(() {
        output = detections.isNotEmpty ? "${issue.className} issue detected!" : "Issue posted.";
        _detectedImagePath = picked.path;
      });

      _showSuccessDialog(issue);
    } catch (e) {
      setState(() => output = "Error: $e");
      _showSnackBar("Failed to report: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> detectAndSave() async {
    if (_currentPosition == null) {
      _showSnackBar("Please wait for location...");
      return;
    }
    // ensure camera permission before opening camera
    if (!await Permission.camera.isGranted) {
      final res = await Permission.camera.request();
      if (!res.isGranted) {
        _showSnackBar('Camera permission is required');
        return;
      }
    }

    // open camera to capture an image
    final imagePath = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const CameraCapturePage()),
    );

    if (imagePath == null || imagePath.isEmpty) return;

    setState(() {
      _isLoading = true;
      output = "Detecting...";
    });

    try {
      final result = await yolo.detectFromFile(imagePath);

      if (result.isEmpty) {
        setState(() {
          output = "No issues detected. Please try again.";
          _isLoading = false;
        });
        return;
      }

      // show preview with boxes and ask user to confirm before reporting
      final detections = result['detections'] as List<Map<String, dynamic>>? ?? [];
      final popResult = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(builder: (_) => DetectionPreview(imagePath: imagePath, detections: detections)),
      );
      final confirmed = popResult == true || (popResult is Map && popResult['confirmed'] == true);

      if (!confirmed) {
        setState(() {
          output = "Reporting cancelled.";
          _isLoading = false;
        });
        return;
      }

      // Upload image to Firebase Storage
      setState(() {
        output = "Uploading image...";
      });
      final imageFile = File(imagePath);
      final imageUrl = await firebase.uploadImage(imageFile);
      
      if (imageUrl == null) {
        setState(() {
          output = "Failed to upload image. Please try again.";
          _isLoading = false;
        });
        return;
      }

      final issue = Issue(
        title: "Campus Issue Detected",
        className: result["class"] ?? "Unknown",
        severity: result["severity"] ?? "Medium",
        confidence: (result["confidence"] ?? 0.0) is num
            ? (result["confidence"] as num).toDouble()
            : double.tryParse('${result["confidence"]}') ?? 0.0,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        status: "Pending",
        imageUrl: imageUrl,
        reportedBy: UserService.userId,
      );

      firebase.addIssue(issue);

      setState(() {
        output = "${issue.className} issue detected!";
        _detectedImagePath = imagePath;
      });

      _showSuccessDialog(issue);
    } catch (e) {
      setState(() {
        output = "Error: $e";
      });
      _showSnackBar("Detection failed. Please try again.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitManualReport() async {
    if (_currentPosition == null) {
      _showSnackBar("Please wait for location...");
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      _showSnackBar("Please enter a description for the issue");
      return;
    }

    if (_detectedImagePath == null || _detectedImagePath!.isEmpty) {
      _showSnackBar("No image captured. Please capture an image first.");
      return;
    }

    setState(() {
      _isLoading = true;
      output = "Submitting report...";
    });

    try {
      // Upload image to Firebase Storage
      setState(() {
        output = "Uploading image...";
      });
      final imageFile = File(_detectedImagePath!);
      final imageUrl = await firebase.uploadImage(imageFile);
      
      if (imageUrl == null) {
        setState(() {
          output = "Failed to upload image. Please try again.";
          _isLoading = false;
        });
        return;
      }

      final issue = Issue(
        title: "Campus Issue Reported",
        className: _descriptionController.text.trim(),
        severity: "Medium", // Default severity for manual reports
        confidence: 0.0, // No AI confidence for manual reports
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        status: "Pending",
        imageUrl: imageUrl,
        reportedBy: UserService.userId,
      );

      firebase.addIssue(issue);

      setState(() {
        output = "Issue reported successfully!";
        _descriptionController.clear();
      });

      _showSuccessDialog(issue);
    } catch (e) {
      setState(() {
        output = "Error: $e";
      });
      _showSnackBar("Failed to submit report. Please try again.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Creates an annotated image with YOLO detection boxes and returns the temp file path.
  Future<String?> _createAnnotatedImage(String imagePath, List<Map<String, dynamic>> detections) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final w = decoded.width;
      final h = decoded.height;
      final red = img.ColorRgba8(255, 0, 0, 255);

      for (final d in detections) {
        final box = d['box'];
        if (box is! List || box.length < 4) continue;
        double x1 = (box[0] is num) ? (box[0] as num).toDouble() : double.tryParse('${box[0]}') ?? 0;
        double y1 = (box[1] is num) ? (box[1] as num).toDouble() : double.tryParse('${box[1]}') ?? 0;
        double x2 = (box[2] is num) ? (box[2] as num).toDouble() : double.tryParse('${box[2]}') ?? 0;
        double y2 = (box[3] is num) ? (box[3] as num).toDouble() : double.tryParse('${box[3]}') ?? 0;
        x1 = x1.clamp(0.0, w.toDouble());
        y1 = y1.clamp(0.0, h.toDouble());
        x2 = x2.clamp(0.0, w.toDouble());
        y2 = y2.clamp(0.0, h.toDouble());
        if (x2 <= x1 || y2 <= y1) continue;
        img.drawRect(decoded, x1: x1.toInt(), y1: y1.toInt(), x2: x2.toInt(), y2: y2.toInt(), color: red, thickness: 3);
      }

      final png = img.encodePng(decoded);
      final dir = await getTemporaryDirectory();
      final out = File('${dir.path}/detected_${DateTime.now().millisecondsSinceEpoch}.png');
      await out.writeAsBytes(png);
      return out.path;
    } catch (e) {
      print('_createAnnotatedImage error: $e');
      return null;
    }
  }

  void _showSuccessDialog(Issue issue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green[400]),
            const SizedBox(width: 12),
            const Text("Issue Reported!"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${issue.className} issue has been successfully reported.",
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[100]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Location captured successfully",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to home
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.aquaBlue,
            ),
            child: const Text("View All Issues"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? colorScheme.surface,
        foregroundColor: theme.appBarTheme.foregroundColor ?? colorScheme.onSurface,
        elevation: 1,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SpotIt AI',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.appBarTheme.foregroundColor ?? Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Report Issue',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      color: (theme.appBarTheme.foregroundColor ?? Colors.white).withOpacity(0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _getCurrentLocation(),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _currentPosition == null 
                    ? Colors.grey[100] 
                    : Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.location_on_outlined,
                color: _currentPosition == null 
                    ? Colors.grey 
                    : Colors.green[600],
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(context),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Text(
                'Report Campus Issue',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use AI to detect and report campus maintenance issues',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Instructions Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          'How it works',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInstructionStep(
                      number: 1,
                      title: 'Position Camera',
                      description: 'Point your camera at the campus issue',
                    ),
                    _buildInstructionStep(
                      number: 2,
                      title: 'AI Detection',
                      description: 'Our AI will analyze and classify the issue',
                    ),
                    _buildInstructionStep(
                      number: 3,
                      title: 'Auto-Report',
                      description: 'Issue is automatically reported with location',
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Detection Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    // Camera Preview/Placeholder
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
                      ),
                      child: _detectedImagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: (File(_detectedImagePath!).existsSync())
                                  ? Image.file(
                                      File(_detectedImagePath!),
                                      fit: BoxFit.cover,
                                    )
                                  : Image.asset(
                                      _detectedImagePath!,
                                      fit: BoxFit.cover,
                                    ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt_rounded,
                                  size: 60,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Camera Preview',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Location Status
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _currentPosition == null 
                            ? Colors.orange[50] 
                            : Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _currentPosition == null 
                              ? Colors.orange[100]! 
                              : Colors.green[100]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _currentPosition == null 
                                ? Icons.location_off_rounded 
                                : Icons.location_on_rounded,
                            color: _currentPosition == null 
                                ? Colors.orange[600] 
                                : Colors.green[600],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentPosition == null 
                                      ? 'Waiting for location...' 
                                      : 'Location Ready',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _currentPosition == null 
                                        ? Colors.orange[700] 
                                        : Colors.green[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentPosition == null
                                      ? 'Please enable location services'
                                      : 'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _currentPosition == null 
                                        ? Colors.orange[600] 
                                        : Colors.green[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_currentPosition == null)
                            ElevatedButton(
                              onPressed: _getCurrentLocation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: const Text('Retry'),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    const SizedBox(height: 24),
                    
                    // Single Report Issue Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _reportIssue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.aquaBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded, size: 22),
                                  SizedBox(width: 12),
                                  Text(
                                    "Report Issue",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Detection Result
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.getGrey(context, 50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.getGrey(context, 200)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.analytics_outlined,
                                color: Colors.blue[600],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'AI Detection Result',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.charcoal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Center(
                              child: Text(
                                output,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: output.contains("detected")
                                      ? Colors.green[600]
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          if (output.contains("|"))
                            const SizedBox(height: 12),
                          if (output.contains("|"))
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: output.split(" | ").map((part) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.blue[100]!),
                                  ),
                                  child: Text(
                                    part,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // View Reports Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/reports-display');
                  },
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('View All Report Images'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.aquaBlue,
                    side: BorderSide(color: AppColors.aquaBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Info Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.getGrey(context, 50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security_rounded, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "All reports are automatically logged and forwarded to campus maintenance",
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep({
    required int number,
    required String title,
    required String description,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Drawer(
      backgroundColor: theme.drawerTheme.backgroundColor ?? colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer Header
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.aquaBlue, AppColors.skyBlue],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Report Issue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI-Powered Detection',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Menu Items
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                _buildDrawerItem(
                  icon: Icons.home_rounded,
                  title: 'Dashboard',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.report_problem_rounded,
                  title: 'Report Issue',
                  isSelected: true,
                  onTap: () {},
                ),
                _buildDrawerItem(
                  icon: Icons.history_rounded,
                  title: 'Report History',
                  onTap: () {},
                ),
                _buildDrawerItem(
                  icon: Icons.map_rounded,
                  title: 'Campus Map',
                  onTap: () {},
                ),
                _buildDrawerItem(
                  icon: Icons.help_center_rounded,
                  title: 'Help & Guidelines',
                  onTap: () {},
                ),
                
                Divider(color: colorScheme.outline.withOpacity(0.5), height: 24),
                
                _buildDrawerItem(
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/settings');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  color: Colors.red,
                  onTap: () async {
                    Navigator.pop(context);
                    await UserService.clear();
                    if (context.mounted) Navigator.pushReplacementNamed(context, '/');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    Color? color,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconColor = color ?? colorScheme.onSurfaceVariant;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.aquaBlue.withOpacity(0.1) : colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected ? AppColors.aquaBlue : iconColor,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppColors.aquaBlue : colorScheme.onSurface,
        ),
      ),
      trailing: isSelected
          ? Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.aquaBlue,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}