import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras!.first,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        // ensure camera permission
        final status = await Permission.camera.status;
        if (!status.isGranted) {
          final req = await Permission.camera.request();
          if (!req.isGranted) return;
        }
        await _controller!.initialize();
      }
    } catch (e) {
      // ignore
    }

    if (mounted) setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture Image')),
      body: Center(
        child: _initialized && _controller != null && _controller!.value.isInitialized
            ? Stack(
                children: [
                  CameraPreview(_controller!),
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FloatingActionButton(
                          onPressed: _takePicture,
                          child: const Icon(Icons.camera_alt),
                        ),
                      ],
                    ),
                  )
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final XFile file = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.pop(context, file.path);
    } catch (e) {
      Navigator.pop(context);
    }
  }
}
