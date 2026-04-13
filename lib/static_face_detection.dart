import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

class StaticFaceDetection extends StatefulWidget {
  const StaticFaceDetection({super.key});

  @override
  State<StaticFaceDetection> createState() => _StaticFaceDetectionState();
}

class _StaticFaceDetectionState extends State<StaticFaceDetection> {
  late ImagePicker imagePicker;
  File? image;
  String result = '';
  late FaceDetector faceDetector;
  dynamic img;
  List<Face> faces = [];
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    imagePicker = ImagePicker();
    final options = FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      enableContours: true,
      enableTracking: true,
      performanceMode: .fast,
    );
    faceDetector = FaceDetector(options: options);
  }

  @override
  void dispose() {
    faceDetector.close();
    super.dispose();
  }

  Future<void> _imageFromGallery() async {
    XFile? pickedImage = await imagePicker.pickImage(source: .gallery);
    if (pickedImage != null) {
      image = File(pickedImage.path);
      detectFace();
    }
  }

  Future<void> _imageFromCamera() async {
    XFile? clickedImage = await imagePicker.pickImage(source: .camera);
    if (clickedImage != null) {
      image = File(clickedImage.path);
      detectFace();
    }
  }

  Future<void> detectFace() async {
    setState(() {
      isProcessing = true;
      img = null;
      result = '';
    });

    final InputImage inputImage = .fromFile(image!);
    faces = await faceDetector.processImage(inputImage);

    String faceStatus = '';
    for (int i = 0; i < faces.length; i++) {
      Face f = faces[i];
      if (f.smilingProbability != null) {
        String status = f.smilingProbability! > 0.5 ? 'Smiling' : 'Serious';
        faceStatus += 'Face ${i + 1}: $status\n';
      }
    }

    await drawRectangleAroundFaces();

    setState(() {
      result = faceStatus.isEmpty ? 'No faces detected.' : faceStatus;
      isProcessing = false;
    });
  }

  Future<void> drawRectangleAroundFaces() async {
    final bytes = await image?.readAsBytes();
    if (bytes != null) {
      final uiImage = await decodeImageFromList(bytes);
      img = uiImage;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Static Detection'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: .infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/tech_bg.png"),
            fit: .cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Image container
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                width: .infinity,
                height: 450,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: isProcessing
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : (image != null && img != null)
                      ? FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: img!.width.toDouble(),
                            height: img!.height.toDouble(),
                            child: CustomPaint(
                              painter: FacePainter(
                                facesList: faces,
                                imageFile: img,
                              ),
                            ),
                          ),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                color: Colors.white54,
                                size: 60,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No Image Selected',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              // Action Buttons
              Row(
                mainAxisAlignment: .center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _imageFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
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
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed: _imageFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
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
              const Spacer(),
              // Results Display
              if (result.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: 40,
                  ),
                  padding: const EdgeInsets.all(16),
                  width: .infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    result.trim(),
                    textAlign: .center,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: .w500,
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

class FacePainter extends CustomPainter {
  final List<Face> facesList;
  final dynamic imageFile;

  FacePainter({required this.facesList, required this.imageFile});

  @override
  void paint(Canvas canvas, Size size) {
    if (imageFile != null) {
      canvas.drawImage(imageFile, .zero, Paint());
    }

    Paint p = Paint()
      ..color = Colors.red
      ..style = .stroke
      ..strokeWidth = 3;

    for (Face rectangle in facesList) {
      canvas.drawRect(rectangle.boundingBox, p);
    }

    Paint p2 = Paint()
      ..color = Colors.green
      ..style = .stroke
      ..strokeWidth = 3;

    Paint p3 = Paint()
      ..color = Colors.yellow
      ..style = .stroke
      ..strokeWidth = 1;

    for (Face face in facesList) {
      Map<FaceContourType, FaceContour?> con = face.contours;
      List<Offset> offsetPoints = <Offset>[];

      con.forEach((key, value) {
        if (value != null) {
          List<Point<int>>? points = value.points;
          for (Point p in points) {
            Offset offset = Offset(p.x.toDouble(), p.y.toDouble());
            offsetPoints.add(offset);
          }
          canvas.drawPoints(.points, offsetPoints, p2);
        }
      });

      final FaceLandmark? leftEar = face.landmarks[FaceLandmarkType.leftEar];
      if (leftEar != null) {
        final Point<int> leftEarPos = leftEar.position;
        canvas.drawRect(
          Rect.fromLTWH(
            leftEarPos.x.toDouble() - 5,
            leftEarPos.y.toDouble() - 5,
            10,
            10,
          ),
          p3,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
