import 'dart:io';
import 'dart:math';

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
  dynamic faceDetector;
  dynamic img;
  late List<Face> faces;

  @override
  void initState() {
    // TODO: implement initState
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
    // TODO: implement dispose
    super.dispose();
    faceDetector.close();
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
      img = null;
      result = '';
    });
    InputImage inputImage = InputImage.fromFile(image!);
    faces = await faceDetector.processImage(inputImage);
    debugPrint("!!!!! ${faces.length}");

    for (int i = 0; i < faces.length; i++) {
      Face f = faces[i];
      if (f.smilingProbability != null) {
        String status = f.smilingProbability! > 0.5 ? 'Smiling' : 'Serious';
        result += '$status ';
      }
    }

    setState(() {
      image;
      result;
    });
    drawRectangleAroundFaces();
  }

  Future<void> drawRectangleAroundFaces() async {
    final bytes = await image?.readAsBytes();
    if (bytes != null) {
      final uiImage = await decodeImageFromList(bytes);
      setState(() {
        img = uiImage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/bg.jpg"),
            fit: .cover,
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 50),
            Container(
              margin: .only(top: 100),
              child: Stack(
                children: [
                  Center(
                    child: ElevatedButton(
                      onPressed: _imageFromGallery,
                      onLongPress: _imageFromCamera,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child:
                          // Container(
                          //   margin: .only(top: 8),
                          //   child: image != null
                          //       ? Image.file(
                          //           image!,
                          //           width: 335,
                          //           height: 495,
                          //           fit: BoxFit.fill,
                          //         )
                          //       : Container(
                          //           width: 340,
                          //           height: 330,
                          //           color: Colors.black,
                          //           child: const Icon(
                          //             Icons.camera_alt,
                          //             color: Colors.white,
                          //             size: 100,
                          //           ),
                          //         ),
                          // ),
                          Container(
                            width: 335,
                            height: 450,
                            margin: const EdgeInsets.only(top: 45),
                            child: (image != null && img != null)
                                ? Center(
                                    child: FittedBox(
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
                                  )
                                : Container(
                                    color: Colors.black,
                                    width: 340,
                                    height: 330,
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 20),
              child: Text(
                result,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 36, color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  List<Face> facesList;
  dynamic imageFile;

  FacePainter({required this.facesList, @required this.imageFile});

  @override
  void paint(Canvas canvas, Size size) {
    if (imageFile != null) {
      canvas.drawImage(imageFile, Offset.zero, Paint());
    }
    Paint p = Paint();
    p.color = Colors.red;
    p.style = .stroke;
    p.strokeWidth = 2;

    for (Face rectangle in facesList) {
      canvas.drawRect(rectangle.boundingBox, p);
    }

    Paint p2 = Paint();
    p2.color = Colors.green;
    p2.style = .stroke;
    p2.strokeWidth = 3;

    Paint p3 = Paint();
    p3.color = Colors.yellow;
    p3.style = .stroke;
    p3.strokeWidth = 1;

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

      // If landmark detection was enabled with FaceDetectorOptions (mouth, ears,
      // eyes, cheeks, and nose available):
      final FaceLandmark leftEar = face.landmarks[FaceLandmarkType.leftEar]!;
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
