import 'dart:io';

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

class _RealTimeFaceDetectionState extends State<RealTimeFaceDetection> {
  dynamic controller;
  bool isBusy = false;
  dynamic faceDetector;
  late Size size;
  late List<Face> faces;
  late CameraDescription description = cameras[1];
  CameraLensDirection camDirec = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    initializeCamera();
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

  @override
  void dispose() {
    controller?.dispose();
    faceDetector.close();
    super.dispose();
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
              // Camera container
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: ClipOval(
                          child:
                              (controller != null && controller.value.isInitialized)
                              ? SizedBox.expand(
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: controller.value.previewSize!.height,
                                      height: controller.value.previewSize!.width,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          CameraPreview(controller),
                                          buildResult(),
                                        ],
                                      ),
                                    ),
                                  ),
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
              const SizedBox(height: 20),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _toggleCameraDirection,
                    icon: const Icon(Icons.flip_camera_ios),
                    label: const Text('Flip Camera'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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

    // Paint p2 = Paint();
    // p2.color = Colors.green;
    // p2.style = PaintingStyle.stroke;
    // p2.strokeWidth = 5;
    //
    // for (Face face in faces) {
    //   Map<FaceContourType, FaceContour?> con = face.contours;
    //   List<Offset> offsetPoints = <Offset>[];
    //   con.forEach((key, value) {
    //     if(value != null) {
    //       List<Point<int>>? points = value.points;
    //       for (Point p in points) {
    //         Offset offset = Offset(camDire2 == CameraLensDirection.front
    //             ? (absoluteImageSize.width - p.x.toDouble()) * scaleX
    //             : p.x.toDouble() * scaleX
    //             , p.y.toDouble()*scaleY);
    //         offsetPoints.add(offset);
    //       }
    //       canvas.drawPoints(PointMode.points, offsetPoints, p2);
    //     }
    //   });
    //
    // }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.faces != faces;
  }
}
