import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late ImagePicker imagePicker;
  File? image;
  String result = '';

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    imagePicker = ImagePicker();
  }

  void _imageFromGallery() async {
    XFile? pickedImage = await imagePicker.pickImage(source: .gallery);
    if (pickedImage != null) {
      image = File(pickedImage.path);
      detectFace();
    }
  }

  void _imageFromCamera() async {
    XFile? clickedImage = await imagePicker.pickImage(source: .camera);
    if (clickedImage != null) {
      image = File(clickedImage.path);
      detectFace();
    }
  }

  detectFace() async{
    result='';
    setState(() {
      image;
    });
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
            SizedBox(height: 100),
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
                      child: Container(
                        margin: .only(top: 8),
                        child: image != null
                            ? Image.file(
                                image!,
                                width: 335,
                                height: 495,
                                fit: BoxFit.fill,
                              )
                            : Container(
                                width: 340,
                                height: 330,
                                color: Colors.black,
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 100,
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
                style:
                const TextStyle( fontSize: 36,color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
