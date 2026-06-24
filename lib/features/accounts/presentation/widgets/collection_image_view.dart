

import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nizan_crm/core/utils/image_download_service.dart';
import 'package:share_plus/share_plus.dart';

class CollectionImageViewerDialog extends StatefulWidget {
  final String url;
  final bool autoShare;
  final bool autoDownload;

  const CollectionImageViewerDialog({super.key, 
    required this.url,
    this.autoShare = false,
    this.autoDownload = false,
  });

  @override
  State<CollectionImageViewerDialog> createState() =>
      _CollectionImageViewerDialogState();
}

class _CollectionImageViewerDialogState
    extends State<CollectionImageViewerDialog> {
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoShare) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _share());
    } else if (widget.autoDownload) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _download());
    }
  }

  Future<Uint8List?> _fetchBytes() async {
    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data!);
      }
    } catch (_) {}
    return null;
  }

  String _fileName() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'collection_screenshot_$ts.jpg';
  }

  Future<void> _download() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final bytes = await _fetchBytes();
      if (bytes == null) throw Exception('Could not load image');
      await downloadImage(
        bytes,
        _fileName(),
        subject: 'Download Image',
        text: 'Collection Screenshot',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _share() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final bytes = await _fetchBytes();
      if (bytes == null) throw Exception('Could not load image');
      final xf = XFile.fromData(bytes, mimeType: 'image/jpeg', name: _fileName());
      await Share.shareXFiles([xf], text: 'Collection Screenshot');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.black.withValues(alpha: 0.7)),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _CIVButton(icon: Icons.close, onTap: () => Navigator.pop(context)),
                    const Spacer(),
                    const Text(
                      'Collection Screenshot',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    _CIVButton(
                      icon: Icons.share_rounded,
                      onTap: _isBusy ? null : _share,
                    ),
                    const SizedBox(width: 8),
                    _isBusy
                        ? Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(10),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : _CIVButton(
                            icon: Icons.download_rounded,
                            onTap: _download,
                          ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: InteractiveViewer(
                    panEnabled: true,
                    scaleEnabled: true,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        widget.url,
                        fit: BoxFit.contain,
                        loadingBuilder: (ctx, child, prog) {
                          if (prog == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        },
                        errorBuilder: (ctx, _, _) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}



class _CIVButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CIVButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: onTap == null ? 0.1 : 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Icon(
            icon,
            color: onTap == null ? Colors.white38 : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
