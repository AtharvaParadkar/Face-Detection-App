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

class _StaticFaceDetectionState extends State<StaticFaceDetection>
    with TickerProviderStateMixin {
  late ImagePicker imagePicker;
  File? image;
  String result = '';
  late FaceDetector faceDetector;
  dynamic img;
  List<Face> faces = [];
  bool isProcessing = false;

  // Animations
  late AnimationController _imageController;
  late AnimationController _resultController;
  late AnimationController _processingController;

  late Animation<double> _imageFade;
  late Animation<Offset> _imageSlide;
  late Animation<double> _resultSlide;
  late Animation<double> _resultFade;
  late Animation<double> _processingRotation;

  @override
  void initState() {
    super.initState();
    imagePicker = ImagePicker();
    final options = FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      enableContours: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    );
    faceDetector = FaceDetector(options: options);

    _imageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _processingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _imageFade = CurvedAnimation(
      parent: _imageController,
      curve: Curves.easeIn,
    );
    _imageSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _imageController, curve: Curves.easeOut));

    _resultFade = CurvedAnimation(
      parent: _resultController,
      curve: Curves.easeIn,
    );
    _resultSlide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _resultController, curve: Curves.easeOut),
    );

    _processingRotation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _processingController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _imageController.dispose();
    _resultController.dispose();
    _processingController.dispose();
    faceDetector.close();
    super.dispose();
  }

  Future<void> _imageFromGallery() async {
    XFile? pickedImage =
        await imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      image = File(pickedImage.path);
      detectFace();
    }
  }

  Future<void> _imageFromCamera() async {
    XFile? clickedImage =
        await imagePicker.pickImage(source: ImageSource.camera);
    if (clickedImage != null) {
      image = File(clickedImage.path);
      detectFace();
    }
  }

  Future<void> detectFace() async {
    _imageController.reset();
    _resultController.reset();
    setState(() {
      isProcessing = true;
      img = null;
      result = '';
    });

    final InputImage inputImage = InputImage.fromFile(image!);
    faces = await faceDetector.processImage(inputImage);

    String faceStatus = '';
    for (int i = 0; i < faces.length; i++) {
      Face f = faces[i];
      if (f.smilingProbability != null) {
        String status = f.smilingProbability! > 0.5 ? 'Smiling 😊' : 'Serious 😐';
        faceStatus += 'Face ${i + 1}: $status\n';
      }
    }

    await drawRectangleAroundFaces();

    setState(() {
      result = faceStatus.isEmpty ? 'No faces detected.' : faceStatus;
      isProcessing = false;
    });

    _imageController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _resultController.forward();
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
        title: const Text("Static Detection",style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.transparent,leading: InkWell(onTap: ()=>Navigator.pop(context),child: Icon(Icons.chevron_left,color: Colors.white,)),
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
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

              // Image container
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                width: double.infinity,
                height: 420,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: (image != null && !isProcessing)
                        ? const Color(0xFF6C63FF).withOpacity(0.6)
                        : Colors.white24,
                    width: (image != null && !isProcessing) ? 1.5 : 1,
                  ),
                  boxShadow: (image != null && !isProcessing)
                      ? [
                          BoxShadow(
                            color:
                                const Color(0xFF6C63FF).withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: isProcessing
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              RotationTransition(
                                turns: _processingRotation,
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: SweepGradient(
                                      colors: [
                                        Colors.transparent,
                                        const Color(0xFF6C63FF),
                                      ],
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.8),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Analyzing...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : (image != null && img != null)
                          ? FadeTransition(
                              opacity: _imageFade,
                              child: SlideTransition(
                                position: _imageSlide,
                                child: FittedBox(
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
                                ),
                              ),
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.9, end: 1.0),
                                    duration: const Duration(milliseconds: 1200),
                                    curve: Curves.easeInOut,
                                    builder: (_, v, child) =>
                                        Transform.scale(scale: v, child: child),
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withOpacity(0.08),
                                        border: Border.all(
                                            color: Colors.white24, width: 1),
                                      ),
                                      child: const Icon(
                                        Icons.add_a_photo,
                                        color: Colors.white54,
                                        size: 36,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No Image Selected',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Tap a button below to get started',
                                    style: TextStyle(
                                      color: Colors.white30,
                                      fontSize: 13,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AnimatedButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onPressed: _imageFromGallery,
                  ),
                  const SizedBox(width: 16),
                  _AnimatedButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onPressed: _imageFromCamera,
                  ),
                ],
              ),

              const Spacer(),

              // Results Display
              if (result.isNotEmpty)
                AnimatedBuilder(
                  animation: _resultController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _resultSlide.value),
                      child: FadeTransition(
                        opacity: _resultFade,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 40,
                    ),
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF6C63FF).withOpacity(0.4),
                          width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.15),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.analytics_outlined,
                                color: Color(0xFF6C63FF), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Detection Results',
                              style: TextStyle(
                                color: Color(0xFF6C63FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          result.trim(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            height: 1.6,
                          ),
                        ),
                      ],
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

class _AnimatedButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _AnimatedButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
              Icon(widget.icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
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
      canvas.drawImage(imageFile, Offset.zero, Paint());
    }

    Paint p = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (Face rectangle in facesList) {
      canvas.drawRect(rectangle.boundingBox, p);
    }

    Paint p2 = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    Paint p3 = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke
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
          canvas.drawPoints(PointMode.points, offsetPoints, p2);
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
