import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class ImageProcessingService {
  static const String _replicateApiKey = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
  static const String _baseUrl = 'https://api.replicate.com/v1';
  static const String _hdrModel =
      'nightmareai/real-esrgan:42fed1c4974146d4d2414e2be2c5277c7fcf05fcc3a73abf41610695738c1d7b';
  static const String _depthModel =
      'cjwbw/midas:a6ba5798f04f80d3b314de0f0a62277f21ab3503c60c84d4817de83c5edfdae0';
  static const String _denoiseModel =
      'jingyunliang/swinir:660d922d33153019e8c263a3bba265de882e7f4f70396546b6c9c8f9d47a021a';
  static Future<String?> processImage(
    String imagePath, {
    required bool hdrEnabled,
    required bool portraitEnabled,
    required bool denoiseEnabled,
  }) async {
    try {
      debugPrint('🚀 PixelVision Processing...');
      debugPrint(
        'HDR: $hdrEnabled | Portrait: $portraitEnabled | Denoise: $denoiseEnabled',
      );

      String? result = imagePath;
      if (hdrEnabled) {
        debugPrint('📸 Applying HDR (Real-ESRGAN)...');
        result = await _applyHDR(result!);
        if (result != null) {
          debugPrint('HDR complete!');
        } else {
          debugPrint('HDR failed, using original');
          result = imagePath;
        }
      }

      if (denoiseEnabled && result != null) {
        debugPrint('🔧 Applying Denoising (SwinIR)...');
        final denoisedPath = await _applyDenoise(result);
        if (denoisedPath != null) {
          result = denoisedPath;
          debugPrint('Denoising complete!');
        } else {
          debugPrint('Denoise failed, keeping current');
        }
      }

      if (portraitEnabled && result != null) {
        debugPrint('Applying Portrait Blur (Midas)...');
        final portraitPath = await _applyPortraitBlur(result);
        if (portraitPath != null) {
          result = portraitPath;
          debugPrint('Portrait blur complete!');
        } else {
          debugPrint('Portrait failed, keeping current');
        }
      }

      debugPrint('Processing complete!');
      return result ?? imagePath;
    } catch (e) {
      debugPrint('Processing error: $e');
      return _fallback(imagePath);
    }
  }

  static Future<String?> _applyHDR(String imagePath) async {
    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse('$_baseUrl/predictions'),
        headers: {
          'Authorization': 'Token $_replicateApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'version': _hdrModel,
          'input': {
            'image': 'data:image/jpeg;base64,$base64Image',
            'scale': 2, // 2x upscaling
            'face_enhance': true,
          },
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'succeeded' && data['output'] != null) {
          return await _download(data['output'], 'hdr');
        }
        return await _poll(data['id'], 'hdr');
      }
      return null;
    } catch (e) {
      debugPrint('HDR error: $e');
      return null;
    }
  }

  static Future<String?> _applyDenoise(String imagePath) async {
    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse('$_baseUrl/predictions'),
        headers: {
          'Authorization': 'Token $_replicateApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'version': _denoiseModel,
          'input': {
            'image': 'data:image/jpeg;base64,$base64Image',
            'task_type': 'Real-World Image Super-Resolution-Medium',
            // Defaulting 'noise' and 'jpeg' by omitting them
          },
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return await _poll(data['id'], 'denoise');
      }
      return null;
    } catch (e) {
      debugPrint('Denoise error: $e');
      return null;
    }
  }

  static Future<String?> _applyPortraitBlur(String imagePath) async {
    try {
      // First, get depth map
      final imageBytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse('$_baseUrl/predictions'),
        headers: {
          'Authorization': 'Token $_replicateApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'version': _depthModel,
          'input': {
            'image': 'data:image/jpeg;base64,$base64Image',
            'model_type': 'dpt_beit_large_512',
          },
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final depthMapUrl = await _poll(data['id'], 'depth');

        if (depthMapUrl != null) {
          return await _applyBlurWithDepth(imagePath, depthMapUrl);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Portrait error: $e');
      return null;
    }
  }

  static Future<String?> _applyBlurWithDepth(
    String originalPath,
    String depthMapPath,
  ) async {
    try {
      final imageBytes = await File(originalPath).readAsBytes();
      final base64Image = base64Encode(imageBytes);

      const portraitBlurModel =
          'lucataco/portrait-blur:8c7c8e6e7e17c09e1dfe1c798e4c3f4e5f6a3b2d1e0c9b8a7e6d5c4b3a2f1e0d';

      final response = await http.post(
        Uri.parse('$_baseUrl/predictions'),
        headers: {
          'Authorization': 'Token $_replicateApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'version': portraitBlurModel,
          'input': {
            'image': 'data:image/jpeg;base64,$base64Image',
            'blur_strength': 0.7,
            'depth_map': depthMapPath,
          },
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return await _poll(data['id'], 'portrait_blur');
      }

      return originalPath;
    } catch (e) {
      debugPrint('Blur application error: $e');
      return originalPath;
    }
  }

  static Future<String?> _poll(String predictionId, String type) async {
    const maxAttempts = 60;
    const pollInterval = Duration(seconds: 2);

    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(pollInterval);

      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/predictions/$predictionId'),
          headers: {'Authorization': 'Token $_replicateApiKey'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final status = data['status'];

          if (i % 5 == 0) debugPrint('⏳ $type processing... (${i * 2}s)');

          if (status == 'succeeded') {
            final output = data['output'];
            String? url;

            if (output is String) {
              url = output;
            } else if (output is List && output.isNotEmpty) {
              url = output[0];
            } else if (output is Map) {
              url = output['url'] ?? output['image'];
            }

            if (url != null) return await _download(url, type);
            debugPrint('No output URL');
            return null;
          } else if (status == 'failed') {
            debugPrint('$type failed: ${data['error']}');
            return null;
          }
        }
      } catch (e) {
        debugPrint('Poll error: $e');
      }
    }
    return null;
  }

  static Future<String?> _download(String url, String type) async {
    try {
      debugPrint('⬇️ Downloading $type...');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path = '${dir.path}/${type}_$timestamp.jpg';

        await File(path).writeAsBytes(response.bodyBytes);
        debugPrint('✅ Saved: $type');
        return path;
      }
      return null;
    } catch (e) {
      debugPrint('Download error: $e');
      return null;
    }
  }

  static Future<String?> _fallback(String imagePath) async {
    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/fallback_$timestamp.jpg';
      await File(imagePath).copy(path);
      return path;
    } catch (e) {
      return null;
    }
  }

  static bool isApiKeyConfigured() {
    return _replicateApiKey.startsWith('r8_') &&
        _replicateApiKey != 'YOUR_REPLICATE_API_TOKEN_HERE';
  }

  static Future<bool> testConnection() async {
    if (!isApiKeyConfigured()) return false;

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/models'),
            headers: {'Authorization': 'Token $_replicateApiKey'},
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Map<String, dynamic> getApiInfo() {
    return {
      'service': 'Replicate',
      'models': {
        'HDR': 'Real-ESRGAN (WORKING ✅)',
        'Portrait': 'Midas (LOW COST ✅)',
        'Denoise': 'SwinIR (UPDATED ✅)',
      },
      'status': isApiKeyConfigured() ? 'Ready ✅' : 'Not configured',
      'cost_per_image': '~\$0.01-0.02',
    };
  }

  static String getEstimatedCost({
    required bool hdrEnabled,
    required bool portraitEnabled,
    required bool denoiseEnabled,
  }) {
    double cost = 0.0;
    if (hdrEnabled) cost += 0.005;
    if (portraitEnabled) cost += 0.0002;
    if (denoiseEnabled) cost += 0.014;
    return '\$${cost.toStringAsFixed(4)}';
  }
}
