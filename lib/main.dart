import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'home_page.dart';

late List<CameraDescription> cameras;

Future<void> main () async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(FaceDetection());
}

class FaceDetection extends StatelessWidget {
  const FaceDetection({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: .dark,
      home: HomePage(),
    );
  }
}
