import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

/// Displays a Firebase Storage image.
///
/// It first tries to fetch the bytes over a plain HTTP GET and paint them with
/// [Image.memory] — a native canvas image that appears immediately and
/// composites in the same layer as the surrounding buttons. If that fetch is
/// refused (some Storage responses don't allow the browser to hand the bytes
/// to the app), it falls back to a plain HTML `<img>` element, which is always
/// allowed to *display* a cross-origin image even when reading its bytes is not.
///
/// Background — the two approaches that don't work on their own:
///  * `Image.network` decodes through an `<img crossorigin="anonymous">` so it
///    can read pixels onto the canvas; Storage doesn't satisfy that stricter
///    check, so the photos came back blank.
///  * A bare `<img>` platform view displays fine but is a DOM overlay that lags
///    Flutter's canvas in a scrolling list — the "renders slowly" behaviour.
///
/// The byte path avoids both; the `<img>` fallback guarantees the photo still
/// shows in the rare case the byte fetch is blocked, so this is never worse
/// than the previous behaviour and is faster whenever the fetch succeeds.
class StorageImage extends StatefulWidget {
  final String url;
  final BoxFit fit;

  /// Whether a failed byte-fetch may fall back to an `<img>` platform view.
  ///
  /// Platform views (`HtmlElementView`) render blank inside a scrolling
  /// `ListView` on Flutter web — which is exactly what blanked the CNIC
  /// review cards. So callers that live inside a list pass `false`: on a
  /// fetch failure they show a small placeholder (and the full photo is still
  /// reachable via the preview dialog). The preview dialog itself is not in a
  /// list, so it leaves this `true` and can use the `<img>` fallback safely.
  final bool allowHtmlFallback;

  const StorageImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.allowHtmlFallback = true,
  });

  @override
  State<StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<StorageImage> {
  /// Bytes cached per URL for the session, so scrolling the list or re-opening
  /// the preview doesn't re-download the same photo.
  static final Map<String, Uint8List> _cache = {};

  Uint8List? _bytes;
  bool _fetchFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _bytes = null;
      _fetchFailed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final url = widget.url;
    final cached = _cache[url];
    if (cached != null) {
      _bytes = cached;
      return;
    }
    try {
      // Bounded so a stalled request can't leave the thumbnail spinning
      // forever — on timeout it falls through to the <img> fallback.
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      _cache[url] = resp.bodyBytes;
      if (mounted) setState(() => _bytes = resp.bodyBytes);
    } catch (_) {
      // Byte fetch blocked or slow — fall back to an <img> element, which can
      // still display the cross-origin image.
      if (mounted) setState(() => _fetchFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _HtmlImg(url: widget.url, fit: widget.fit),
      );
    }
    if (_fetchFailed) {
      // Inside a list we must NOT use a platform view (it renders blank and
      // can blank the whole card); show a placeholder instead. Elsewhere the
      // <img> fallback is fine.
      return widget.allowHtmlFallback
          ? _HtmlImg(url: widget.url, fit: widget.fit)
          : const Center(child: Icon(Icons.image_not_supported_outlined, color: Color(0xFFBCC9C5)));
    }
    return const Center(
      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

/// Cross-origin-safe `<img>` fallback used only when the byte fetch is refused.
class _HtmlImg extends StatelessWidget {
  final String url;
  final BoxFit fit;
  const _HtmlImg({required this.url, required this.fit});

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'img',
      onElementCreated: (Object element) {
        final img = element as web.HTMLImageElement;
        img.src = url;
        img.style
          ..width = '100%'
          ..height = '100%'
          ..objectFit = fit == BoxFit.contain ? 'contain' : 'cover'
          ..backgroundColor = '#E4E9E7';
        img.alt = 'Uploaded document';
      },
    );
  }
}
