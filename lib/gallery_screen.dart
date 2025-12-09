import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AssetEntity> _processedImages = [];
  List<AssetEntity> _rawImages = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadImages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadImages() async {
    setState(() => _isLoading = true);
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission required')),
          );
        setState(() => _isLoading = false);
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );
      AssetPathEntity? processedAlbum, rawAlbum;
      for (var a in albums) {
        if (a.name.contains('PixelVision')) {
          if (a.name.contains('Processed')) processedAlbum = a;
          if (a.name.contains('Raw')) rawAlbum = a;
        }
      }

      _processedImages = (processedAlbum != null)
          ? await processedAlbum.getAssetListRange(start: 0, end: 1000)
          : [];
      _rawImages = (rawAlbum != null)
          ? await rawAlbum.getAssetListRange(start: 0, end: 1000)
          : [];

      _processedImages.sort(
        (a, b) => b.createDateTime.compareTo(a.createDateTime),
      );
      _rawImages.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
    } catch (e) {
      debugPrint('loadImages: $e');
    }
    setState(() => _isLoading = false);
  }

  void _toggleSelectionMode() => setState(() {
    _isSelectionMode = !_isSelectionMode;
    if (!_isSelectionMode) _selectedIds.clear();
  });

  void _toggleSelection(String id) => setState(
    () => _selectedIds.contains(id)
        ? _selectedIds.remove(id)
        : _selectedIds.add(id),
  );

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Delete Images'),
        content: Text('Delete ${_selectedIds.length} image(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final list = (_tabController.index == 0 ? _processedImages : _rawImages)
          .where((e) => _selectedIds.contains(e.id))
          .toList();
      for (final a in list) await PhotoManager.editor.deleteWithIds([a.id]);
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${list.length} deleted'),
          backgroundColor: const Color(0xFF16213E),
        ),
      );
      _loadImages();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedIds.length} selected')
            : const Text('Gallery'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: Navigator.of(context).pop,
              ),
        actions: [
          if (_isSelectionMode)
            if (_selectedIds.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _deleteSelected,
              )
            else
              IconButton(
                icon: const Icon(Icons.select_all),
                onPressed: _toggleSelectionMode,
                tooltip: 'Select',
              ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C63FF),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(
              icon: const Icon(Icons.auto_fix_high),
              text: 'Processed (${_processedImages.length})',
            ),
            Tab(
              icon: const Icon(Icons.camera),
              text: 'Raw (${_rawImages.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGrid(_processedImages, true),
                _buildGrid(_rawImages, false),
              ],
            ),
    );
  }

  Widget _buildGrid(List<AssetEntity> images, bool processed) {
    if (images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              processed ? Icons.auto_fix_off : Icons.photo_library_outlined,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              processed ? 'No processed images yet' : 'No raw images saved',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Capture photos to see them here',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadImages,
      child: GridView.builder(
        padding: EdgeInsets.zero, // <- FULL WIDTH
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1, // <- tiny gap
          mainAxisSpacing: 1,
          childAspectRatio: 1.0,
        ),
        itemCount: images.length,
        itemBuilder: (_, i) => _thumb(images[i], processed),
      ),
    );
  }

  Widget _thumb(AssetEntity a, bool processed) {
    final selected = _selectedIds.contains(a.id);
    return GestureDetector(
      onTap: () =>
          _isSelectionMode ? _toggleSelection(a.id) : _view(a, processed),
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelectionMode();
          _toggleSelection(a.id);
        }
      },
      child: Stack(
        children: [
          Hero(
            tag: a.id,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF6C63FF)
                      : (processed
                            ? const Color(0xFF6C63FF).withOpacity(.3)
                            : Colors.grey.withOpacity(.2)),
                  width: selected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image(
                  image: AssetEntityImageProvider(
                    a,
                    isOriginal: false,
                    thumbnailSize: const ThumbnailSize.square(300),
                  ),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
          if (_isSelectionMode)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? const Color(0xFF6C63FF) : Colors.black54,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          if (processed)
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_fix_high, size: 10, color: Colors.white),
                    SizedBox(width: 2),
                    Text(
                      'AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _view(AssetEntity a, bool processed) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ImageViewScreen(
        asset: a,
        isProcessed: processed,
        onDelete: _loadImages,
      ),
    ),
  );
}

class ImageViewScreen extends StatelessWidget {
  final AssetEntity asset;
  final bool isProcessed;
  final VoidCallback onDelete;

  const ImageViewScreen({
    super.key,
    required this.asset,
    required this.isProcessed,
    required this.onDelete,
  });

  Future<void> _share() async {
    final file = await asset.file;
    if (file != null)
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Shared from PixelVision');
  }

  Future<void> _delete(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to delete this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PhotoManager.editor.deleteWithIds([asset.id]);
      if (ctx.mounted) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Image deleted'),
            backgroundColor: Color(0xFF16213E),
          ),
        );
        onDelete();
      }
    } catch (e) {
      if (ctx.mounted)
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  void _info(BuildContext ctx) => showModalBottomSheet(
    context: ctx,
    backgroundColor: const Color(0xFF16213E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isProcessed ? Icons.auto_fix_high : Icons.info,
                color: const Color(0xFF6C63FF),
              ),
              const SizedBox(width: 12),
              Text(
                isProcessed ? 'AI Enhanced Image' : 'Original Image',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _row('Type', isProcessed ? 'AI Enhanced' : 'Original'),
          _row('Size', '${asset.width} × ${asset.height}'),
          _row(
            'Date',
            '${asset.createDateTime.day}/${asset.createDateTime.month}/${asset.createDateTime.year}  ${asset.createDateTime.hour}:${asset.createDateTime.minute.toString().padLeft(2, '0')}',
          ),
          if (isProcessed)
            _row('Processing', 'HDR Enhancement + Portrait Blur + Denoising'),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );

  Widget _row(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Expanded(
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(isProcessed ? 'AI Enhanced' : 'Original'),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _share),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _delete(context),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _info(context),
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: asset.id,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Image(
              image: AssetEntityImageProvider(asset, isOriginal: true),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
