import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final bool hdrEnabled;
  final bool portraitEnabled;
  final bool saveRaw;
  final bool denoiseEnabled;

  const SettingsScreen({
    super.key,
    required this.hdrEnabled,
    required this.portraitEnabled,
    required this.saveRaw,
    required this.denoiseEnabled,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _hdrEnabled;
  late bool _portraitEnabled;
  late bool _saveRaw;
  late bool _denoiseEnabled;

  @override
  void initState() {
    super.initState();
    _hdrEnabled = widget.hdrEnabled;
    _portraitEnabled = widget.portraitEnabled;
    _saveRaw = widget.saveRaw;
    _denoiseEnabled = widget.denoiseEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, {
              'hdr': _hdrEnabled,
              'portrait': _portraitEnabled,
              'saveRaw': _saveRaw,
              'denoise': _denoiseEnabled,
            });
          },
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          _buildSectionHeader('AI Processing Features'),
          _buildSettingCard(
            icon: Icons.hdr_on,
            iconColor: Colors.amber,
            title: 'HDR Enhancement',
            subtitle: 'Apply High Dynamic Range processing (Real-ESRGAN)',
            value: _hdrEnabled,
            onChanged: (value) => setState(() => _hdrEnabled = value),
          ),

          _buildSettingCard(
            icon: Icons.portrait,
            iconColor: Colors.blue,
            title: 'Portrait Blur',
            subtitle: 'DSLR-like bokeh effect (Depth-Anything V2)',
            value: _portraitEnabled,
            onChanged: (value) => setState(() => _portraitEnabled = value),
          ),

          _buildSettingCard(
            icon: Icons.grain,
            iconColor: Colors.purple,
            title: 'Denoising',
            subtitle: 'Remove noise and artifacts (SwinIR)',
            value: _denoiseEnabled,
            onChanged: (value) => setState(() => _denoiseEnabled = value),
          ),

          const SizedBox(height: 20),
          _buildSectionHeader('Storage Settings'),
          _buildSettingCard(
            icon: Icons.save,
            iconColor: Colors.green,
            title: 'Save Raw Images',
            subtitle: 'Save original unprocessed images separately',
            value: _saveRaw,
            onChanged: (value) => setState(() => _saveRaw = value),
          ),

          const SizedBox(height: 20),

          // Info Section
          _buildSectionHeader('Processing Information'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF16213E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF6C63FF)),
                      SizedBox(width: 12),
                      Text(
                        'AI Models Used',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildModelInfo(
                    'HDR Enhancement',
                    'Real-ESRGAN',
                    '2x upscaling, face enhancement, ~5-8 seconds',
                  ),
                  const Divider(height: 24, color: Colors.grey),
                  _buildModelInfo(
                    'Portrait Blur',
                    'Depth-Anything V2',
                    'Depth-aware blur, natural bokeh, ~6-10 seconds',
                  ),
                  const Divider(height: 24, color: Colors.grey),
                  _buildModelInfo(
                    'Denoising',
                    'SwinIR',
                    'Noise & artifact removal, ~4-6 seconds',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '• Internet connection required\n'
                    '• Processing time: 5-20 seconds\n'
                    '• Cost: ~\$0.008-0.012 per image\n'
                    '• Free tier: 5 credits (~400-600 images)',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF16213E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.camera_alt, color: Color(0xFF6C63FF)),
                      SizedBox(width: 12),
                      Text(
                        'PixelVision',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text('Version 1.0.0', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Text(
                    'Developed by:\n'
                    'Muhammad Zubair (CIIT/SP23-BSE-006/WAH)\n'
                    'Muhammad Hamza (CIIT/SP23-BSE-021/WAH)\n'
                    'Muntaha Wani (CIIT/SP23-BSE-032/WAH)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF16213E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF6C63FF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelInfo(String feature, String model, String details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF6C63FF),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              feature,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Model: $model',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 2),
              Text(
                details,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
