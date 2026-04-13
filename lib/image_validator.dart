
import 'image_validator.dart';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class ValidationResult {
  final bool isValid;
  final double confidence;
  final String category;

  ValidationResult({
    required this.isValid,
    required this.confidence,
    required this.category,
  });
}

class ImageValidator {
  Interpreter? _interpreter;
  bool _loaded = false;

  // Load model
  Future<void> _loadModel() async {
    if (_loaded) return;

    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/pothole_detector.tflite',
      );
      _loaded = true;
    } catch (e) {
      print("❌ Model load error: $e");
    }
  }

  // Main validation function
  Future<ValidationResult> validateImage(String imagePath) async {
    await _loadModel();

    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        return ValidationResult(
          isValid: false,
          confidence: 0,
          category: "Invalid Image",
        );
      }

      // Resize
      final resized = img.copyResize(image, width: 224, height: 224);

      // Convert to input tensor
      var input = List.generate(
        1,
            (_) => List.generate(
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

      var output = List.generate(1, (_) => List.filled(1, 0.0));

      _interpreter!.run(input, output);

      double score = output[0][0];

      bool isPothole = score > 0.5;

      return ValidationResult(
        isValid: isPothole,
        confidence: score * 100,
        category: isPothole ? "Pothole" : "Normal Road",
      );
    } catch (e) {
      return ValidationResult(
        isValid: false,
        confidence: 0,
        category: "Error",
      );
    }
  }
}