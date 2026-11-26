import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/features/marketing/presentation/media/gallery_prefs.dart';
import 'package:nizan_crm/features/marketing/presentation/media/media_link.dart';
import 'package:shared_preferences/shared_preferences.dart';

// How a pasted link becomes something the app can play, and the viewer's own autoplay choice.

void main() {
  group('Dropbox links', () {
    test('a new-style file link becomes a direct file link: raw=1, dl removed, the access key kept', () {
      final l = MediaLink.parse('https://www.dropbox.com/scl/fi/abc123/Bridal%20Reel.mp4?rlkey=KEY&st=xyz&dl=0');
      expect(l.isDropbox, isTrue);
      expect(l.isFolder, isFalse);
      expect(l.canPlayInline, isTrue);
      expect(l.fileName, 'Bridal Reel.mp4');
      final u = Uri.parse(l.playUrl!);
      expect(u.host, 'www.dropbox.com');
      expect(u.path, '/scl/fi/abc123/Bridal%20Reel.mp4');
      expect(u.queryParameters, {'rlkey': 'KEY', 'st': 'xyz', 'raw': '1'});
      expect(l.original, 'https://www.dropbox.com/scl/fi/abc123/Bridal%20Reel.mp4?rlkey=KEY&st=xyz&dl=0', reason: '"Open in Dropbox" opens what was pasted');
    });

    test('the team\'s real test link: every access parameter is kept (rlkey, st, e), dl goes, raw=1 is added', () {
      const pasted = 'https://www.dropbox.com/scl/fi/9w9u2i1doer7j9txn7wkn/Vodcast-2311-Scale-Microgrid-V1-q32iac7tvw.mp4?rlkey=in9l4l38menk9s83rbslfq5qp&st=ri5pwwhh&e=1&dl=0';
      final l = MediaLink.parse(pasted);
      expect(l.canPlayInline, isTrue);
      expect(l.fileName, 'Vodcast-2311-Scale-Microgrid-V1-q32iac7tvw.mp4');
      final u = Uri.parse(l.playUrl!);
      expect(u.path, '/scl/fi/9w9u2i1doer7j9txn7wkn/Vodcast-2311-Scale-Microgrid-V1-q32iac7tvw.mp4');
      expect(u.queryParameters, {'rlkey': 'in9l4l38menk9s83rbslfq5qp', 'st': 'ri5pwwhh', 'e': '1', 'raw': '1'});
      expect(l.original, pasted);
    });

    test('an old-style /s/ link, dl=1 and a link with no dl at all all end up as raw=1', () {
      for (final u in ['https://www.dropbox.com/s/abc/clip.mp4?dl=0', 'https://dropbox.com/s/abc/clip.mp4?dl=1', 'https://www.dropbox.com/s/abc/clip.mp4']) {
        final l = MediaLink.parse(u);
        expect(l.canPlayInline, isTrue, reason: u);
        expect(Uri.parse(l.playUrl!).queryParameters, {'raw': '1'}, reason: u);
      }
    });

    test('every playable extension is recognised, in any case; other files are not played inline', () {
      for (final ext in ['mp4', 'MP4', 'm4v', 'mov', 'webm', 'ogv']) {
        expect(MediaLink.parse('https://www.dropbox.com/s/a/clip.$ext?dl=0').canPlayInline, isTrue, reason: ext);
      }
      for (final name in ['photo.jpg', 'deck.pdf', 'footage.mkv', 'footage.avi', 'noextension']) {
        final l = MediaLink.parse('https://www.dropbox.com/s/a/$name?dl=0');
        expect(l.isDropbox, isTrue, reason: name);
        expect(l.canPlayInline, isFalse, reason: name);
        expect(l.playUrl, isNull, reason: name);
      }
    });

    test('folder links (old /sh/ and new /scl/fo/) are Dropbox links that cannot be played', () {
      for (final u in ['https://www.dropbox.com/sh/abc/folder?dl=0', 'https://www.dropbox.com/scl/fo/abc/folder?rlkey=K&dl=0', 'https://www.dropbox.com/scl/fo/abc/clip.mp4?rlkey=K']) {
        final l = MediaLink.parse(u);
        expect(l.isDropbox, isTrue, reason: u);
        expect(l.isFolder, isTrue, reason: u);
        expect(l.canPlayInline, isFalse, reason: u);
      }
    });

    test('a direct dropboxusercontent link is already playable as it is', () {
      final l = MediaLink.parse('https://dl.dropboxusercontent.com/s/abc/clip.mp4');
      expect(l.isDropbox, isTrue);
      expect(l.playUrl, 'https://dl.dropboxusercontent.com/s/abc/clip.mp4');
    });

    test('a host that only looks like Dropbox is not Dropbox', () {
      for (final u in ['https://notdropbox.com/s/a/clip.mp4', 'https://dropbox.com.evil.test/s/a/clip.mp4', 'https://evil.test/dropbox.com/s/a/clip.mp4']) {
        final l = MediaLink.parse(u);
        expect(l.isDropbox, isFalse, reason: u);
        expect(Uri.parse(l.playUrl ?? 'x:').queryParameters.containsKey('raw'), isFalse, reason: 'it is not rewritten');
      }
    });
  });

  group('other links', () {
    test('a direct video file on any host plays as it is; a page or an image does not', () {
      expect(MediaLink.parse('https://cdn.example.com/media/reel.webm').playUrl, 'https://cdn.example.com/media/reel.webm');
      expect(MediaLink.parse('https://drive.google.com/file/d/abc/view').canPlayInline, isFalse, reason: 'a Drive page is not a file');
      expect(MediaLink.parse('https://cdn.example.com/media/still.jpg').canPlayInline, isFalse);
    });

    test('anything that is not an http(s) link never throws and never plays', () {
      for (final u in [null, '', '   ', 'not a url', 'javascript:alert(1)', 'file:///etc/passwd', 'ftp://x/clip.mp4', 'https://']) {
        final l = MediaLink.parse(u);
        expect(l.canPlayInline, isFalse, reason: '$u');
        expect(l.isDropbox, isFalse, reason: '$u');
      }
      expect(MediaLink.parse('  https://www.dropbox.com/s/a/clip.mp4?dl=0  ').canPlayInline, isTrue, reason: 'surrounding spaces are ignored');
    });
  });

  group('Autoplay previews — each viewer\'s own choice', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('it is off until the viewer turns it on, and is remembered', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(galleryAutoplayProvider), isFalse);
      await c.read(galleryAutoplayProvider.notifier).set(true);
      expect(c.read(galleryAutoplayProvider), isTrue);
      expect((await SharedPreferences.getInstance()).getBool('marketing.gallery.autoplay'), isTrue);
      final next = ProviderContainer();
      addTearDown(next.dispose);
      expect(next.read(galleryAutoplayProvider), isFalse, reason: 'starts off, then...');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(next.read(galleryAutoplayProvider), isTrue, reason: '...loads what this viewer chose last time');
    });

    test('turning it off is remembered too; one viewer\'s choice does not leak into a fresh storage', () async {
      SharedPreferences.setMockInitialValues({'marketing.gallery.autoplay': true});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(galleryAutoplayProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.read(galleryAutoplayProvider), isTrue);
      await c.read(galleryAutoplayProvider.notifier).set(false);
      expect((await SharedPreferences.getInstance()).getBool('marketing.gallery.autoplay'), isFalse);
      SharedPreferences.setMockInitialValues({});
      final other = ProviderContainer();
      addTearDown(other.dispose);
      other.read(galleryAutoplayProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(other.read(galleryAutoplayProvider), isFalse);
    });
  });

  group('the second route (Dropbox\'s direct host)', () {
    test('a Dropbox share link also has a redirect-free form: same path, the key and the rest, no dl / raw', () {
      final l = MediaLink.parse('https://www.dropbox.com/scl/fi/abc/Bridal%20Reel.mp4?rlkey=KEY&st=S&e=1&dl=0');
      final alt = Uri.parse(l.altPlayUrl!);
      expect(alt.host, 'dl.dropboxusercontent.com');
      expect(alt.path, '/scl/fi/abc/Bridal%20Reel.mp4');
      expect(alt.queryParameters, {'rlkey': 'KEY', 'st': 'S', 'e': '1'});
      expect(l.playUrls, [l.playUrl, l.altPlayUrl], reason: 'the share link as a file first');
      expect(Uri.parse(l.playUrls.first).host, 'www.dropbox.com');
    });

    test('an old-style link and a link with no other parameters', () {
      final l = MediaLink.parse('https://www.dropbox.com/s/abc/clip.mp4?dl=0');
      expect(l.altPlayUrl, 'https://dl.dropboxusercontent.com/s/abc/clip.mp4');
    });

    test('a link that is already the direct host, another site, a folder or a non-video has a single route or none', () {
      expect(MediaLink.parse('https://dl.dropboxusercontent.com/s/abc/clip.mp4').playUrls, hasLength(1));
      expect(MediaLink.parse('https://cdn.example.com/media/reel.webm').playUrls, hasLength(1));
      expect(MediaLink.parse('https://www.dropbox.com/scl/fo/abc/Reels?rlkey=K&dl=0').playUrls, isEmpty);
      expect(MediaLink.parse('https://www.dropbox.com/s/a/Deck.pdf?dl=0').playUrls, isEmpty);
      expect(MediaLink.parse('not a link').playUrls, isEmpty);
    });
  });
}
