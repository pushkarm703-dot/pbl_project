part of 'main.dart';

/// Simple ML-based image validator for road hazard detection
/// Uses rule-based approach with image analysis
class ImageValidator {
  /// Validates if image contains a road hazard
  Future<ValidationResult> validateImage(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        return ValidationResult(
          isValid: false,
          confidence: 0.0,
          detectedObject: 'Invalid image format',
          category: 'Error',
        );
      }

      // Run multiple checks
      final brightnessScore = _checkBrightness(image);
      final colorScore = _checkRoadColors(image);
      final textureScore = _checkTexture(image);
      final compositionScore = _checkComposition(image);
      final edgeScore = _checkEdges(image);

      // More detailed scoring
      print('DEBUG Scores:');
      print('  Brightness: ${brightnessScore.toStringAsFixed(2)}');
      print('  Colors: ${colorScore.toStringAsFixed(2)}');
      print('  Texture: ${textureScore.toStringAsFixed(2)}');
      print('  Composition: ${compositionScore.toStringAsFixed(2)}');
      print('  Edges: ${edgeScore.toStringAsFixed(2)}');

      // STRICTER calculation - all checks must pass reasonably well
      // Changed weights to be more strict
      final totalScore = (brightnessScore * 0.20) +
          (colorScore * 0.40) +      // Road colors are most important
          (textureScore * 0.20) +
          (compositionScore * 0.10) +
          (edgeScore * 0.10);        // Edge detection for damage

      // Apply penalty if any score is too low
      double confidence = (totalScore * 100).clamp(0.0, 100.0);

      // STRICT PENALTIES - if any critical check fails badly, reduce confidence
      if (colorScore < 0.3) {
        confidence *= 0.6; // Not enough road-like colors
        print('  Penalty: Low road colors');
      }
      if (brightnessScore < 0.2) {
        confidence *= 0.5; // Too dark or bright
        print('  Penalty: Bad brightness');
      }
      if (textureScore < 0.2) {
        confidence *= 0.7; // Too smooth (not damaged)
        print('  Penalty: Too smooth');
      }

      confidence = confidence.clamp(0.0, 100.0);
      print('  Final Confidence: ${confidence.toStringAsFixed(1)}%');

      // STRICTER threshold - need 65% to be valid (was 55%)
      final isValid = confidence >= 65;

      String category = 'Unknown';
      String detectedObject = 'Unclear';

      if (isValid) {
        // More specific categorization
        if (colorScore > 0.7 && textureScore > 0.6 && edgeScore > 0.5) {
          category = 'Pothole/Damaged Road';
          detectedObject = 'Road surface damage detected';
        } else if (colorScore > 0.6 && brightnessScore > 0.6) {
          category = 'Road Hazard';
          detectedObject = 'Possible road issue';
        } else {
          category = 'Road Area';
          detectedObject = 'Road infrastructure detected';
        }
      } else {
        // Better detection of what it actually is
        if (colorScore < 0.3) {
          detectedObject = 'Not a road surface (wrong colors)';
        } else if (textureScore < 0.3) {
          detectedObject = 'Too smooth to be damaged road';
        } else if (brightnessScore < 0.3) {
          detectedObject = 'Image too dark or bright';
        } else {
          detectedObject = 'Not a clear road hazard (${_guessObject(image)})';
        }
      }

      return ValidationResult(
        isValid: isValid,
        confidence: confidence,
        detectedObject: detectedObject,
        category: category,
      );
    } catch (e) {
      print('Error validating image: $e');
      return ValidationResult(
        isValid: false,
        confidence: 0.0,
        detectedObject: 'Validation error',
        category: 'Error',
      );
    }
  }

  /// Check if image has appropriate brightness (outdoor photo) - STRICTER
  double _checkBrightness(img.Image image) {
    double totalBrightness = 0;
    int sampleCount = 0;
    int darkPixels = 0;
    int brightPixels = 0;

    // Sample pixels (every 10th pixel for speed)
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        final brightness = (pixel.r + pixel.g + pixel.b) / 3;
        totalBrightness += brightness;
        sampleCount++;

        if (brightness < 40) darkPixels++;
        if (brightness > 200) brightPixels++;
      }
    }

    final avgBrightness = totalBrightness / sampleCount;
    final darkRatio = darkPixels / sampleCount;
    final brightRatio = brightPixels / sampleCount;

    print('    Avg brightness: ${avgBrightness.toStringAsFixed(1)} (dark: ${darkRatio.toStringAsFixed(2)}, bright: ${brightRatio.toStringAsFixed(2)})');

    // Too many dark or bright pixels = bad
    if (darkRatio > 0.5 || brightRatio > 0.5) {
      return 0.2; // Too much extreme pixels
    }

    // Ideal brightness for outdoor road photos: 80-160
    if (avgBrightness >= 80 && avgBrightness <= 160) {
      return 1.0;
    } else if (avgBrightness >= 60 && avgBrightness <= 180) {
      return 0.7;
    } else if (avgBrightness >= 40 && avgBrightness <= 200) {
      return 0.4;
    } else {
      return 0.1;
    }
  }

  /// Check if image has road-like colors (gray, black, brown) - STRICTER
  double _checkRoadColors(img.Image image) {
    int roadColorPixels = 0;
    int totalSamples = 0;
    int veryRoadLikePixels = 0; // Extra strict check

    // Sample pixels
    for (int y = 0; y < image.height; y += 8) {
      for (int x = 0; x < image.width; x += 8) {
        final pixel = image.getPixel(x, y);
        totalSamples++;

        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;

        // STRICT gray/black check (asphalt)
        final colorDiff = (r - g).abs() + (g - b).abs() + (r - b).abs();
        final avgColor = (r + g + b) / 3;

        // Very strict gray (all channels similar, medium brightness)
        final isStrictGray = colorDiff < 20 &&
            avgColor > 40 &&
            avgColor < 130;

        // Loose gray (for counting)
        final isGray = colorDiff < 30 &&
            avgColor > 30 &&
            avgColor < 150;

        // Check for brown colors (dirt roads) - STRICTER
        final isBrown = r > g + 10 &&
            r > b + 10 &&
            g > b - 10 &&
            r < 160 &&
            avgColor > 50 &&
            avgColor < 130;

        if (isStrictGray) {
          veryRoadLikePixels++;
          roadColorPixels++;
        } else if (isGray || isBrown) {
          roadColorPixels++;
        }
      }
    }

    final ratio = roadColorPixels / totalSamples;
    final strictRatio = veryRoadLikePixels / totalSamples;

    print('    Road color ratio: ${ratio.toStringAsFixed(2)} (strict: ${strictRatio.toStringAsFixed(2)})');

    // Need at least 15% very strict road colors AND 30% loose road colors
    if (strictRatio >= 0.15 && ratio >= 0.30) {
      return 1.0;
    } else if (strictRatio >= 0.10 && ratio >= 0.25) {
      return 0.7;
    } else if (ratio >= 0.20) {
      return 0.4;
    } else {
      return 0.1;
    }
  }

  /// Check texture variation (roads have irregular texture from damage)
  double _checkTexture(img.Image image) {
    List<double> variations = [];

    // Analyze 9 regions
    final regionWidth = image.width ~/ 3;
    final regionHeight = image.height ~/ 3;

    for (int ry = 0; ry < 3; ry++) {
      for (int rx = 0; rx < 3; rx++) {
        double regionVariation = _calculateRegionVariation(
          image,
          rx * regionWidth,
          ry * regionHeight,
          regionWidth,
          regionHeight,
        );
        variations.add(regionVariation);
      }
    }

    // Calculate average variation
    final avgVariation =
        variations.reduce((a, b) => a + b) / variations.length;

    // Road hazards typically have moderate texture variation
    if (avgVariation >= 15 && avgVariation <= 60) {
      return 1.0;
    } else if (avgVariation >= 10 && avgVariation <= 80) {
      return 0.6;
    } else {
      return 0.3;
    }
  }

  double _calculateRegionVariation(
      img.Image image, int startX, int startY, int width, int height) {
    List<double> brightness = [];

    final endX = (startX + width).clamp(0, image.width);
    final endY = (startY + height).clamp(0, image.height);

    for (int y = startY; y < endY; y += 5) {
      for (int x = startX; x < endX; x += 5) {
        final pixel = image.getPixel(x, y);
        brightness.add((pixel.r + pixel.g + pixel.b) / 3);
      }
    }

    if (brightness.isEmpty) return 0;

    final mean = brightness.reduce((a, b) => a + b) / brightness.length;
    final variance = brightness
        .map((b) => (b - mean) * (b - mean))
        .reduce((a, b) => a + b) /
        brightness.length;

    return variance;
  }

  /// Check for edges and irregular patterns (damaged roads have more edges)
  double _checkEdges(img.Image image) {
    int edgePixels = 0;
    int totalSamples = 0;

    // Simple edge detection using brightness differences
    for (int y = 1; y < image.height - 1; y += 8) {
      for (int x = 1; x < image.width - 1; x += 8) {
        totalSamples++;

        final center = image.getPixel(x, y);
        final centerBrightness = (center.r + center.g + center.b) / 3;

        // Check neighboring pixels
        final right = image.getPixel(x + 1, y);
        final bottom = image.getPixel(x, y + 1);

        final rightBrightness = (right.r + right.g + right.b) / 3;
        final bottomBrightness = (bottom.r + bottom.g + bottom.b) / 3;

        // If there's a significant difference, it's an edge
        final horizontalDiff = (centerBrightness - rightBrightness).abs();
        final verticalDiff = (centerBrightness - bottomBrightness).abs();

        if (horizontalDiff > 20 || verticalDiff > 20) {
          edgePixels++;
        }
      }
    }

    final edgeRatio = edgePixels / totalSamples;

    print('    Edge ratio: ${edgeRatio.toStringAsFixed(2)}');

    // Damaged roads have moderate edge density
    if (edgeRatio >= 0.20 && edgeRatio <= 0.60) {
      return 1.0;
    } else if (edgeRatio >= 0.15 && edgeRatio <= 0.70) {
      return 0.6;
    } else {
      return 0.3;
    }
  }

  /// Check composition (outdoor photos have sky or ground perspective)
  double _checkComposition(img.Image image) {
    // Check if image is taken from typical road perspective
    // Top part might be lighter (sky or distant road)
    // Bottom part might be darker (near ground)

    double topBrightness = 0;
    double bottomBrightness = 0;
    int topCount = 0;
    int bottomCount = 0;

    final midHeight = image.height ~/ 2;

    // Sample top half
    for (int y = 0; y < midHeight; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        topBrightness += (pixel.r + pixel.g + pixel.b) / 3;
        topCount++;
      }
    }

    // Sample bottom half
    for (int y = midHeight; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        bottomBrightness += (pixel.r + pixel.g + pixel.b) / 3;
        bottomCount++;
      }
    }

    final topAvg = topBrightness / topCount;
    final bottomAvg = bottomBrightness / bottomCount;

    // Typical outdoor road photos have some brightness difference
    final difference = (topAvg - bottomAvg).abs();

    if (difference >= 10 && difference <= 80) {
      return 1.0;
    } else if (difference < 100) {
      return 0.7;
    } else {
      return 0.4;
    }
  }

  /// Guess what the object might be if not a road hazard
  String _guessObject(img.Image image) {
    final avgBrightness = _getAverageBrightness(image);
    final colorfulness = _getColorfulness(image);

    if (avgBrightness > 200) {
      return 'Very bright/washed out image';
    } else if (avgBrightness < 30) {
      return 'Very dark image';
    } else if (colorfulness > 80) {
      return 'Colorful object (not a road)';
    } else {
      return 'Indoor or unrelated object';
    }
  }

  double _getAverageBrightness(img.Image image) {
    double total = 0;
    int count = 0;

    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        total += (pixel.r + pixel.g + pixel.b) / 3;
        count++;
      }
    }

    return total / count;
  }

  double _getColorfulness(img.Image image) {
    double totalSaturation = 0;
    int count = 0;

    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        final maxChannel = [pixel.r, pixel.g, pixel.b].reduce((a, b) => a > b ? a : b);
        final minChannel = [pixel.r, pixel.g, pixel.b].reduce((a, b) => a < b ? a : b);
        totalSaturation += maxChannel - minChannel;
        count++;
      }
    }

    return totalSaturation / count;
  }
}

/// Result of image validation
class ValidationResult {
  final bool isValid;
  final double confidence;
  final String detectedObject;
  final String category;

  ValidationResult({
    required this.isValid,
    required this.confidence,
    required this.detectedObject,
    required this.category,
  });

  bool get isHighConfidence => confidence >= 70;
  bool get isLowConfidence => confidence < 50;
  bool get needsReview => confidence >= 50 && confidence < 70;

  @override
  String toString() {
    return 'ValidationResult(isValid: $isValid, confidence: ${confidence.toStringAsFixed(1)}%, '
        'object: $detectedObject, category: $category)';
  }
}