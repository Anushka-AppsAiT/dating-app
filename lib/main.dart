import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_v2/tflite_v2.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ImagePickerDemo(),
    );
  }
}

class ImagePickerDemo extends StatefulWidget {
  @override
  _ImagePickerDemoState createState() => _ImagePickerDemoState();
}

class _ImagePickerDemoState extends State<ImagePickerDemo> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  String result = "";
  String probability1 = "";
  String probability2 = "";

  @override
  void initState() {
    super.initState();
    loadModel().then((value) {
      setState(() {});
    });
  }

  Future<void> loadModel() async {
    try {
      await Tflite.loadModel(
        model: "assets/dating_model.tflite",
        labels: "assets/labels.txt",
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error loading model: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return; // User canceled the picker

      setState(() {
        _image = image;
      });

      detectImage(File(_image!.path));
    } catch (e) {
      if (kDebugMode) {
        print('Error picking image: $e');
      }
    }
  }

  Future<void> detectImage(File image) async {
    try {
      // Read the image and resize it
      img.Image? decodedImage = img.decodeImage(image.readAsBytesSync());
      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }

      img.Image resizedImage =
          img.copyResize(decodedImage, width: 180, height: 180);

      // Convert the resized image to Uint8List
      var resizedImageBytes = img.encodeJpg(resizedImage);
      if (resizedImageBytes is! Uint8List) {
        resizedImageBytes = Uint8List.fromList(resizedImageBytes);
      }

      // Save the resized image to a temporary file to pass to TFLite
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/resized_image.jpg');
      await tempFile.writeAsBytes(resizedImageBytes);

      var recognitions = await Tflite.runModelOnImage(
        path: tempFile.path,
        imageMean: 0.0,
        imageStd: 1.0,
        numResults: 2,
        threshold: -10.0, // Setting threshold to 0.0 to get all results
        asynch: true,
      );

      print(recognitions);
      setState(() {
        if (recognitions != null && recognitions.isNotEmpty) {
          result = recognitions[0]['label'].toString();
          double prediction0 = recognitions[0]['confidence'];
          double prediction1 = recognitions[1]['confidence'];

          // Determine the class based on the predictions
          if (result == 'Vulgar' && prediction1 < 0) {
            result = 'Vulgar';
          } else {
            result = 'Safe';
          }

          probability1 =
              'Probability Vulgar: ${prediction0.toStringAsFixed(2)}';
          probability2 = 'Probability Safe: ${prediction1.toStringAsFixed(2)}';
        } else {
          result = 'No result';
          probability1 = '';
          probability2 = '';
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error running model: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Classification'),
        backgroundColor: Colors.green.shade300,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(height: 20),
              if (_image != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Image.file(
                    File(_image!.path),
                    height: 200,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 200,
                  child: Center(child: Text('No image selected')),
                ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade500,
                  foregroundColor: Colors.white,
                ),
                onPressed: _pickImage,
                child: Text('Pick Image from Gallery'),
              ),
              SizedBox(height: 20),
              Text(
                'Prediction: $result',
                style: TextStyle(fontSize: 20),
              ),
              if (probability1.isNotEmpty && probability2.isNotEmpty) ...[
                SizedBox(height: 10),
                Text(
                  probability1,
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 5),
                Text(
                  probability2,
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
