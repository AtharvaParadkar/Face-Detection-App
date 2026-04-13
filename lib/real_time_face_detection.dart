import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'main.dart';

class RealTimeFaceDetection extends StatefulWidget {
  const RealTimeFaceDetection({super.key});

  @override
  State<RealTimeFaceDetection> createState() => _RealTimeFaceDetectionState();
}

class _RealTimeFaceDetectionState extends State<RealTimeFaceDetection>
    with TickerProviderStateMixin {
  dynamic controller;
  bool isBusy = false;
  dynamic faceDetector;
  late Size size;
  late List<Face> faces;
  late CameraDescription description = cameras[1];
  CameraLensDirection camDirec = CameraLensDirection.front;

  // Animations
  late AnimationController _ringPulseController;
  late AnimationController _faceDetectedController;
  late AnimationController _scanLineController;
  late Animation<double> _ringPulse;
  late Animation<double> _faceDetectedScale;
  late Animation<double> _faceDetectedOpacity;
  late Animation<double> _scanLine;

  bool _faceDetected = false;

  @override
  void initState() {
    super.initState();

    _ringPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _faceDetectedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _ringPulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _ringPulseController, curve: Curves.easeInOut),
    );

    _faceDetectedScale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _faceDetectedController, curve: Curves.easeOut),
    );

    _faceDetectedOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _faceDetectedController, curve: Curves.easeOut),
    );

    _scanLine = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.linear),
    );

    initializeCamera();
  }

  @override
  void dispose() {
    _ringPulseController.dispose();
    _faceDetectedController.dispose();
    _scanLineController.dispose();
    controller?.dispose();
    faceDetector.close();
    super.dispose();
  }

  Future<void> initializeCamera() async {
    final options = FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
    );
    faceDetector = FaceDetector(options: options);

    controller = CameraController(
      description,
      ResolutionPreset.high,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    await controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      controller.startImageStream(
        (image) => {
          if (!isBusy) {isBusy = true, img = image, doFaceDetectionOnFrame()},
        },
      );
    });
  }

  dynamic _scanResults;
  CameraImage? img;

  Future<void> doFaceDetectionOnFrame() async {
    if (img == null) {
      setState(() {
        isBusy = false;
      });
      return;
    }
    var frameImg = getInputImage();
    if (frameImg != null) {
      List<Face> faces = await faceDetector.processImage(frameImg);
      debugPrint("!!!!!! faces == ${faces.length}");

      final bool nowFaceDetected = faces.isNotEmpty;
      if (nowFaceDetected != _faceDetected) {
        _faceDetected = nowFaceDetected;
        if (nowFaceDetected) {
          _faceDetectedController.forward();
        } else {
          _faceDetectedController.reverse();
        }
      }

      setState(() {
        _scanResults = faces;
        isBusy = false;
      });
    } else {
      isBusy = false;
    }
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? getInputImage() {
    final camera = cameras[1];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    // get image format
    InputImageFormat? format;
    if (Platform.isAndroid) format = InputImageFormat.nv21;
    if (Platform.isIOS) format = InputImageFormat.bgra8888;
    if (format == null) return null;

    // accumulate all planes
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

  Widget buildResult() {
    if (_scanResults == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final Size imageSize = Size(
      controller.value.previewSize!.height,
      controller.value.previewSize!.width,
    );
    CustomPainter painter = FaceDetectorPainter(
      imageSize,
      _scanResults,
      camDirec,
    );
    return CustomPaint(painter: painter);
  }

  void _toggleCameraDirection() async {
    if (camDirec == CameraLensDirection.back) {
      camDirec = CameraLensDirection.front;
      description = cameras[1];
    } else {
      camDirec = CameraLensDirection.back;
      description = cameras[0];
    }
    await controller.stopImageStream();
    setState(() {
      controller;
    });

    initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Real-Time Detection"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/tech_bg.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Face detected status chip
              AnimatedBuilder(
                animation: _faceDetectedController,
                builder: (context, _) {
                  return FadeTransition(
                    opacity: _faceDetectedOpacity,
                    child: ScaleTransition(
                      scale: _faceDetectedScale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.greenAccent, width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.face, color: Colors.greenAccent, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Face Detected',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Camera container with pulsing ring
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: Listenable.merge(
                          [_ringPulseController, _faceDetectedController]),
                      builder: (context, child) {
                        final glowColor = _faceDetected
                            ? Colors.greenAccent
                            : const Color(0xFF6C63FF);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer glow ring
                            Transform.scale(
                              scale: _ringPulse.value * 1.07,
                              child: Container(
                                width: size.width - 16,
                                height: size.width - 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: glowColor.withOpacity(0.2),
                                    width: 8,
                                  ),
                                ),
                              ),
                            ),
                            // Mid ring
                            Transform.scale(
                              scale: _ringPulse.value * 1.035,
                              child: Container(
                                width: size.width - 16,
                                height: size.width - 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: glowColor.withOpacity(0.35),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            // Camera circle
                            child!,
                          ],
                        );
                      },
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white38, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF6C63FF).withOpacity(0.25),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child:
                                (controller != null &&
                                        controller.value.isInitialized)
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          SizedBox.expand(
                                            child: FittedBox(
                                              fit: BoxFit.cover,
                                              child: SizedBox(
                                                width: controller
                                                    .value.previewSize!.height,
                                                height: controller
                                                    .value.previewSize!.width,
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    CameraPreview(controller),
                                                    buildResult(),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Scanning line overlay
                                          AnimatedBuilder(
                                            animation: _scanLine,
                                            builder: (context, _) {
                                              return CustomPaint(
                                                painter: _ScanLinePainter(
                                                    _scanLine.value),
                                              );
                                            },
                                          ),
                                        ],
                                      )
                                    : const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Flip Camera Button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AnimatedIconButton(
                    icon: Icons.flip_camera_ios,
                    label: 'Flip Camera',
                    onPressed: _toggleCameraDirection,
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// Scanning line effect painter
class _ScanLinePainter extends CustomPainter {
  final double progress;
  _ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.cyanAccent.withOpacity(0.5),
          Colors.transparent,
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, y - 8, size.width, 16))
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}

// Animated icon button with press scale
class _AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _AnimatedIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale =
        Tween<double>(begin: 1.0, end: 0.93).animate(CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(this.absoluteImageSize, this.faces, this.camDire2);

  final Size absoluteImageSize;
  final List<Face> faces;
  CameraLensDirection camDire2;

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    for (Face face in faces) {
      canvas.drawRect(
        Rect.fromLTRB(
          camDire2 == CameraLensDirection.front
              ? (absoluteImageSize.width - face.boundingBox.right) * scaleX
              : face.boundingBox.left * scaleX,
          face.boundingBox.top * scaleY,
          camDire2 == CameraLensDirection.front
              ? (absoluteImageSize.width - face.boundingBox.left) * scaleX
              : face.boundingBox.right * scaleX,
          face.boundingBox.bottom * scaleY,
        ),
        paint,
      );
    }

    Paint p2 = Paint();
    p2.color = Colors.green;
    p2.style = PaintingStyle.stroke;
    p2.strokeWidth = 5;

    for (Face face in faces) {
      Map<FaceContourType, FaceContour?> con = face.contours;
      List<Offset> offsetPoints = <Offset>[];
      con.forEach((key, value) {
        if (value != null) {
          List<Point<int>>? points = value.points;
          for (Point p in points) {
            Offset offset = Offset(
                camDire2 == CameraLensDirection.front
                    ? (absoluteImageSize.width - p.x.toDouble()) * scaleX
                    : p.x.toDouble() * scaleX,
                p.y.toDouble() * scaleY);
            offsetPoints.add(offset);
          }
          canvas.drawPoints(PointMode.points, offsetPoints, p2);
        }
      });
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.faces != faces;
  }
}
