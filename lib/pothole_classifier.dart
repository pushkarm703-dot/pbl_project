import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class PotholeClassifier {
  Interpreter? _interpreter;
  bool _isLoaded = false;

  // Load model
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/pothole_detector.tflite',
      );
      _isLoaded = true;
      print("✅ Model loaded");
    } catch (e) {
      print("❌ Error loading model: $e");
    }
  }

  // Classify image
  Future<Map<String, dynamic>> classifyImage(String imagePath) async {
    if (!_isLoaded) {
      await loadModel();
    }

    try {
      // Load image
      File imageFile = File(imagePath);
      img.Image? image = img.decodeImage(await imageFile.readAsBytes());

      if (image == null) {
        throw Exception("Invalid image");
      }

      // Resize to 224x224
      img.Image resized = img.copyResize(
        image,
        width: 224,
        height: 224,
      );

      // Convert to input tensor [1, 224, 224, 3]
      var input = List.generate(
        1,
            (batch) => List.generate(
          224,
              (y) => List.generate(
            224,
                (x) {
              final pixel = resized.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      // Output tensor
      var output = List.generate(1, (_) => List.filled(1, 0.0));

      // Run inference
      _interpreter!.run(input, output);

      double score = output[0][0];

      // Decision
      bool isPothole = score > 0.5;
      double confidence = isPothole ? score : (1 - score);

      return {
        "isPothole": isPothole,
        "confidence": confidence * 100,
        "label": isPothole ? "Pothole" : "Clean Road"
      };
    } catch (e) {
      return {
        "isPothole": false,
        "confidence": 0,
        "label": "Error"
      };
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}