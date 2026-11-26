import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAutoplayKey = 'marketing.gallery.autoplay';

/// "Autoplay previews" in the Gallery — each viewer's OWN choice, remembered on this device, off until they turn it on. When on, a video
/// opens playing, muted (a browser only lets a video start by itself when it is muted); the viewer can unmute or pause.
class GalleryAutoplay extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_kAutoplayKey);
      if (saved != null && ref.mounted) state = saved;
    } catch (_) {
      // storage unavailable (a private window): the choice just does not persist
    }
  }

  Future<void> set(bool on) async {
    state = on;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAutoplayKey, on);
    } catch (_) {}
  }
}

final galleryAutoplayProvider = NotifierProvider<GalleryAutoplay, bool>(GalleryAutoplay.new);
