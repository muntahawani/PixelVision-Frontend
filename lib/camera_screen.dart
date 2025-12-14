import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'settings_screen.dart';
import 'gallery_screen.dart';
import 'image_processing_service.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  int _selectedCameraIdx = 0;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 8.0;
  bool _isProcessing = false;
  bool _hdrEnabled = true;
  bool _portraitEnabled = true;
  bool _saveRaw = true;
  bool _denoiseEnabled = false; // NEW

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _loadSettings() async {
    // TODO: load from SharedPreferences if wanted
    setState(() {
      _hdrEnabled = true;
      _portraitEnabled = true;
      _saveRaw = true;
      _denoiseEnabled = false;
    });
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;
    _controller = CameraController(
      widget.cameras[_selectedCameraIdx],
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await _controller!.initialize();
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('initCamera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2) return;
    _selectedCameraIdx = (_selectedCameraIdx + 1) % widget.cameras.length;
    await _controller?.dispose();
    await _initializeCamera();
  }

  Future<void> _takePicture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing)
      return;
    setState(() => _isProcessing = true);
    try {
      final XFile image = await _controller!.takePicture();
      if (_saveRaw) await Gal.putImage(image.path, album: 'PixelVision Raw');

      if (mounted) _showProcessingDialog();

      final processedPath = await ImageProcessingService.processImage(
        image.path,
        hdrEnabled: _hdrEnabled,
        portraitEnabled: _portraitEnabled,
        denoiseEnabled: _denoiseEnabled,
      );

      if (mounted) Navigator.of(context).pop(); // close dialog

      if (processedPath != null) {
        await Gal.putImage(processedPath, album: 'PixelVision Processed');
        if (mounted) _showSuccess();
      } else {
        if (mounted) _showError('Processing failed. Raw image saved.');
      }
    } catch (e) {
      debugPrint('takePicture: $e');
      if (mounted) {
        Navigator.of(context).pop();
        _showError('Failed to capture image');
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showProcessingDialog() => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF6C63FF)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Processing Image',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Applying ${_hdrEnabled ? 'HDR' : ''}${_hdrEnabled && _portraitEnabled ? ' & ' : ''}${_portraitEnabled ? 'Portrait Blur' : ''}${_denoiseEnabled ? ' + Denoising' : ''}',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _showSuccess() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 10),
          Text('Images saved successfully!'),
        ],
      ),
      duration: Duration(seconds: 2),
      backgroundColor: Color(0xFF16213E),
    ),
  );

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(child: Text(msg)),
        ],
      ),
      duration: const Duration(seconds: 3),
      backgroundColor: const Color(0xFF16213E),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'PixelVision',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    hdrEnabled: _hdrEnabled,
                    portraitEnabled: _portraitEnabled,
                    saveRaw: _saveRaw,
                    denoiseEnabled: _denoiseEnabled,
                  ),
                ),
              );
              if (result != null) {
                setState(() {
                  _hdrEnabled = result['hdr'] ?? _hdrEnabled;
                  _portraitEnabled = result['portrait'] ?? _portraitEnabled;
                  _saveRaw = result['saveRaw'] ?? _saveRaw;
                  _denoiseEnabled = result['denoise'] ?? _denoiseEnabled;
                });
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller!)),
          Positioned(
            top: 100,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hdrEnabled) ...[
                    const Icon(Icons.hdr_on, size: 20, color: Colors.amber),
                    const SizedBox(width: 4),
                    const Text('HDR', style: TextStyle(fontSize: 12)),
                  ],
                  if (_hdrEnabled && _portraitEnabled) const SizedBox(width: 8),
                  if (_portraitEnabled) ...[
                    const Icon(Icons.portrait, size: 20, color: Colors.blue),
                    const SizedBox(width: 4),
                    const Text('Portrait', style: TextStyle(fontSize: 12)),
                  ],
                  if (_portraitEnabled && _denoiseEnabled)
                    const SizedBox(width: 8),
                  if (_denoiseEnabled) ...[
                    const Icon(Icons.grain, size: 20, color: Colors.purple),
                    const SizedBox(width: 4),
                    const Text('Denoise', style: TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Icon(Icons.zoom_out, size: 20),
                        Expanded(
                          child: Slider(
                            value: _currentZoom,
                            min: _minZoom,
                            max: _maxZoom,
                            activeColor: const Color(0xFF6C63FF),
                            onChanged: (v) {
                              setState(() => _currentZoom = v);
                              _controller?.setZoomLevel(v);
                            },
                          ),
                        ),
                        const Icon(Icons.zoom_in, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GalleryScreen(),
                          ),
                        ),
                        icon: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.photo_library),
                        ),
                      ),
                      GestureDetector(
                        onTap: _isProcessing ? null : _takePicture,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            color: _isProcessing
                                ? Colors.grey
                                : const Color(0xFF6C63FF),
                          ),
                          child: _isProcessing
                              ? const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  size: 40,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.cameras.length > 1
                            ? _switchCamera
                            : null,
                        icon: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.flip_camera_android),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
