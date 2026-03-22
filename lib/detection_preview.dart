import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'app_theme.dart';

class DetectionPreview extends StatefulWidget {
  final String imagePath;
  final List<Map<String, dynamic>> detections;

  const DetectionPreview({super.key, required this.imagePath, required this.detections});

  @override
  State<DetectionPreview> createState() => _DetectionPreviewState();
}

class _DetectionPreviewState extends State<DetectionPreview> {
  ui.Image? _image;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final data = await File(widget.imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    setState(() {
      _image = frame.image;
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection Preview'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: _image == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, box) {
              final imgW = _image!.width.toDouble();
              final imgH = _image!.height.toDouble();
              final dispW = box.maxWidth;
              final dispH = dispW * (imgH / imgW);
              final scaleX = dispW / imgW;
              final scaleY = dispH / imgH;
              final hasDetections = widget.detections.isNotEmpty;

              return SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      width: dispW,
                      height: dispH,
                      child: Stack(children: [
                        Image.file(File(widget.imagePath), width: dispW, height: dispH, fit: BoxFit.fill),
                        for (var d in widget.detections)
                          Positioned(
                            left: (d['box'][0] as double) * scaleX,
                            top: (d['box'][1] as double) * scaleY,
                            width: ((d['box'][2] as double) - (d['box'][0] as double)) * scaleX,
                            height: ((d['box'][3] as double) - (d['box'][1] as double)) * scaleY,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.redAccent, width: 2),
                              ),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Container(
                                  color: Colors.redAccent.withOpacity(0.8),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text(
                                    '${d['label']} ${(d['score'] * 100).toStringAsFixed(0)}% ',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    if (!hasDetections) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'No issues detected. Please describe the problem:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                hintText: 'Enter description of the issue...',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              maxLines: 3,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (!hasDetections && _descriptionController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a description')),
                                  );
                                  return;
                                }
                                Navigator.pop(context, {
                                  'confirmed': true,
                                  'description': hasDetections ? null : _descriptionController.text.trim(),
                                  'detections': hasDetections ? widget.detections : null,
                                });
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.aquaBlue),
                              child: Text(hasDetections ? 'Confirm & Report' : 'Submit Report'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
    );
  }
}
