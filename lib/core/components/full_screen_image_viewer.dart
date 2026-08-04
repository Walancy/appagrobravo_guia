import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:agrobravo/core/tokens/app_colors.dart';
import 'package:agrobravo/core/constants/translations.dart';

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? tag;

  const FullScreenImageViewer({super.key, required this.imageUrl, this.tag});

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();

  /// Abre o visualizador em tela cheia com animação de fade.
  static void show(BuildContext context, String imageUrl, {String? tag}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullScreenImageViewer(imageUrl: imageUrl, tag: tag),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  bool _isSaving = false;

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.t('Permissão negada para salvar na galeria.', 'Gallery permission denied.')),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          setState(() => _isSaving = false);
          return;
        }
      }

      final response = await http.get(Uri.parse(widget.imageUrl));
      final dir = await getTemporaryDirectory();
      final ext = widget.imageUrl.contains('.png') ? 'png' : 'jpg';
      final file = File(
        '${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await file.writeAsBytes(response.bodyBytes);
      await Gal.putImage(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('Foto salva na galeria!', 'Photo saved to gallery!')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('Erro ao salvar a foto.', 'Error saving photo.')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: _saveToGallery,
                ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: widget.tag ?? widget.imageUrl,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: widget.imageUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.error, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
