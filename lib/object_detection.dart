import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:path_provider/path_provider.dart';

import 'main.dart';

/// ML Kit model only has 5 broad categories
// Fashion goods
// Food and drink
// Home goods
// Places
// Plants

// Distinct neon accent colors per detected object slot
const List<Color> _boxColors = [
  Color(0xFF00E5FF), // cyan
  Color(0xFF69FF47), // green
  Color(0xFFFF4081), // pink
  Color(0xFFFFD740), // amber
  Color(0xFFE040FB), // purple
];

class ObjectDetection extends StatefulWidget {
  const ObjectDetection({super.key});

  @override
  State<ObjectDetection> createState() => _ObjectDetectionState();
}

class _ObjectDetectionState extends State<ObjectDetection>
    with TickerProviderStateMixin {
  dynamic controller;
  bool isBusy = false;
  dynamic objectDetector;
  late Size size;
  CameraImage? img;
  List<DetectedObject> _scanResults = [];
  String? _detectionError; // shown on-screen so errors are never silent

  // Animations
  late AnimationController _scanLineController;
  late Animation<double> _scanLine;

  @override
  void initState() {
    super.initState();

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _scanLine = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.linear),
    );

    initializeCamera();
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    controller?.dispose();
    objectDetector?.close();
    super.dispose();
  }

  // ── Copy TFLite model from assets → local storage (ML Kit needs a file path)
  Future<String> _getModelPath(String assetPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final modelFile = File('${dir.path}/$assetPath');
    if (!await modelFile.exists()) {
      await modelFile.parent.create(recursive: true);
      final byteData = await rootBundle.load(assetPath);
      await modelFile.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );
      debugPrint('Model copied to ${modelFile.path}');
    }
    return modelFile.path;
  }

  Future<void> initializeCamera() async {
    // ── OLD: generic base model (only 5 broad categories) ────────────────────
    // final options = ObjectDetectorOptions(
    //   mode: DetectionMode.stream,
    //   classifyObjects: true,
    //   multipleObjects: true,
    // );
    // objectDetector = ObjectDetector(options: options);
    // ─────────────────────────────────────────────────────────────────────────

    // ── NEW: custom EfficientDet Lite 0 model (90 COCO classes) ─────────────
    // In google_mlkit_object_detection 0.15.x the correct class is
    // LocalObjectDetectorOptions — it takes modelPath directly; there is no
    // separate LocalModel or CustomObjectDetectorOptions in this version.
    final modelPath = await _getModelPath(
      'assets/ml/object_labeler.tflite',
    );
    final options = LocalObjectDetectorOptions(
      mode: DetectionMode.stream,
      // object_labeler.tflite is from googlesamples/mlkit — guaranteed
      // compatible with LocalObjectDetectorOptions.
      modelPath: modelPath,
      classifyObjects: true,
      multipleObjects: true,
      maximumLabelsPerObject: 3,
      confidenceThreshold: 0.4,
    );
    objectDetector = ObjectDetector(options: options);
    // ─────────────────────────────────────────────────────────────────────────

    controller = CameraController(
      cameras[0],
      ResolutionPreset.medium, // medium keeps the pipeline fast
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await controller.initialize();
    if (!mounted) return;

    setState(() {});

    controller.startImageStream((image) {
      if (!isBusy) {
        isBusy = true;
        img = image;
        doObjectDetectionOnFrame();
      }
    });
  }

  Future<void> doObjectDetectionOnFrame() async {
    final frameImg = getInputImage();
    if (frameImg == null) {
      isBusy = false;
      return;
    }

    try {
      final List<DetectedObject> objects = await objectDetector.processImage(
        frameImg,
      );

      for (final DetectedObject obj in objects) {
        for (final Label label in obj.labels) {
          debugPrint(
            '!!!!!!### ${label.text}  conf=${label.confidence.toStringAsFixed(2)}',
          );
        }
      }

      if (mounted) {
        setState(() {
          _scanResults = objects;
          isBusy = false;
        });
      }
    } catch (e) {
      debugPrint('!!!!! Detection error: $e');
      if (mounted) {
        setState(() {
          _detectionError = e.toString();
          isBusy = false;
        });
      } else {
        isBusy = false;
      }
    }
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? getInputImage() {
    if (img == null) return null;
    final camera = cameras[0];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var comp = _orientations[controller!.value.deviceOrientation];
      if (comp == null) return null;
      comp = camera.lensDirection == CameraLensDirection.front
          ? (sensorOrientation + comp) % 360
          : (sensorOrientation - comp + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(comp);
    }
    if (rotation == null) return null;

    InputImageFormat? format;
    if (Platform.isAndroid) format = InputImageFormat.nv21;
    if (Platform.isIOS) format = InputImageFormat.bgra8888;
    if (format == null) return null;

    if (img!.planes.isEmpty) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane p in img!.planes) {
      allBytes.putUint8List(p.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(img!.width.toDouble(), img!.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: img!.planes.first.bytesPerRow,
      ),
    );
  }

  // ── Draw bounding boxes via CustomPainter ────────────────────────────────
  Widget buildResult() {
    if (_scanResults.isEmpty ||
        controller == null ||
        !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final imageSize = Size(
      controller.value.previewSize!.height,
      controller.value.previewSize!.width,
    );
    return CustomPaint(painter: ObjectDetectorPainter(imageSize, _scanResults));
  }

  @override
  Widget build(BuildContext context) {
    size = MediaQuery.of(context).size;
    final bool initialized =
        controller != null && controller.value.isInitialized;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.chevron_left, color: Colors.white),
        ),
        title: const Text(
          'Object Detection',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen camera preview
          if (initialized)
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            )
          else
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00E5FF)),
                  SizedBox(height: 16),
                  Text(
                    'Loading model…',
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),

          // Bounding box overlays
          if (initialized) Positioned.fill(child: buildResult()),

          // Animated cyan scan line
          if (initialized)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _scanLine,
                builder: (context, _) =>
                    CustomPaint(painter: _ScanLinePainter(_scanLine.value)),
              ),
            ),

          // Error overlay — visible when model fails so nothing is silent
          if (_detectionError != null)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚠ Detection error',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_detectionError!,
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Object count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.center_focus_strong,
                          color: Color(0xFF00E5FF),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_scanResults.length} object${_scanResults.length == 1 ? '' : 's'} detected',
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Detected label chips
                  if (_scanResults.isNotEmpty)
                    Flexible(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 6,
                        runSpacing: 4,
                        children: _scanResults
                            .take(5)
                            .toList()
                            .asMap()
                            .entries
                            .map((entry) {
                              final idx = entry.key;
                              final obj = entry.value;
                              final color = _boxColors[idx % _boxColors.length];
                              final topLabel = obj.labels.isNotEmpty
                                  ? obj.labels.first.text
                                  : 'Object';
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  topLabel,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            })
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bounding box + label painter ─────────────────────────────────────────────

class ObjectDetectorPainter extends CustomPainter {
  ObjectDetectorPainter(this.absoluteImageSize, this.objects);

  final Size absoluteImageSize;
  final List<DetectedObject> objects;

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    for (int i = 0; i < objects.length; i++) {
      final obj = objects[i];
      final color = _boxColors[i % _boxColors.length];

      final rect = Rect.fromLTRB(
        obj.boundingBox.left * scaleX,
        obj.boundingBox.top * scaleY,
        obj.boundingBox.right * scaleX,
        obj.boundingBox.bottom * scaleY,
      );

      // Subtle tinted fill
      canvas.drawRect(rect, Paint()..color = color.withOpacity(0.08));

      // Corner brackets (cleaner than a full rectangle)
      _drawCornerBrackets(canvas, rect, color);

      // Label chip above the box
      if (obj.labels.isNotEmpty) {
        final label = obj.labels.first;
        final text =
            '${label.text}  ${(label.confidence * 100).toStringAsFixed(0)}%';
        _drawLabel(canvas, text, rect, color, size);
      }
    }
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const len = 18.0;

    void corner(Offset tl, Offset h, Offset v) {
      canvas.drawLine(tl, tl + h, paint);
      canvas.drawLine(tl, tl + v, paint);
    }

    corner(rect.topLeft, const Offset(len, 0), const Offset(0, len));
    corner(rect.topRight, const Offset(-len, 0), const Offset(0, len));
    corner(rect.bottomLeft, const Offset(len, 0), const Offset(0, -len));
    corner(rect.bottomRight, const Offset(-len, 0), const Offset(0, -len));
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Rect boxRect,
    Color color,
    Size canvasSize,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    )..layout();

    const padH = 6.0, padV = 3.0;
    final bgW = tp.width + padH * 2;
    final bgH = tp.height + padV * 2;

    // Prefer above the box; fall back inside the top edge
    double labelY = boxRect.top - bgH - 4;
    if (labelY < 0) labelY = boxRect.top + 4;

    // Clamp to right edge
    double labelX = boxRect.left;
    if (labelX + bgW > canvasSize.width) labelX = canvasSize.width - bgW - 4;

    final bgRect = Rect.fromLTWH(labelX, labelY, bgW, bgH);

    // Dark background pill
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
      Paint()..color = Colors.black.withValues(alpha: 0.75),
    );
    // Colored left-edge accent stripe
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(labelX, labelY, 3, bgH),
        const Radius.circular(2),
      ),
      Paint()..color = color,
    );

    tp.paint(canvas, Offset(labelX + padH, labelY + padV));
  }

  @override
  bool shouldRepaint(ObjectDetectorPainter oldDelegate) =>
      oldDelegate.absoluteImageSize != absoluteImageSize ||
      oldDelegate.objects != objects;
}

// ── Scan-line painter ─────────────────────────────────────────────────────────

class _ScanLinePainter extends CustomPainter {
  final double progress;
  _ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.transparent, Color(0x8000E5FF), Colors.transparent],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, y - 8, size.width, 16))
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}
