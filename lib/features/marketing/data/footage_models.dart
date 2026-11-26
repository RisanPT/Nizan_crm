// Footage from works (backend controllers/workFootageController.js, /api/work-footage; rules in utils/workFootage.js).

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
String _s(dynamic v) => v?.toString() ?? '';
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => ((v as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
List<String> _strs(dynamic v) => ((v as List?) ?? const []).map(_s).where((x) => x.isNotEmpty).toList();

/// Where a work's footage stands, in words and colour keys: waiting (nothing in), new, in edit, edited.
String footageStateLabel(String s) => switch (s) { 'new' => 'Sent to Marketing', 'in_edit' => 'Being edited', 'edited' => 'Edited', _ => 'Waiting for footage' };

class FootageLink {
  const FootageLink({required this.id, required this.url, this.label = '', this.provider = 'dropbox', this.kind = 'folder', this.source = 'artist', this.addedByName = '', this.addedAt, this.mine = false, this.summary = ''});
  final String id, url, label, provider, kind, source, addedByName;

  /// A Dropbox folder read when it was handed in (the server's Dropbox app): "12 videos · 4.2 GB" — '' when not known.
  final String summary;

  /// A Dropbox folder: it opens in the app's folder view (what is inside, each video playing there).
  bool get isDropboxFolder => kind == 'folder' && provider == 'dropbox';
  final DateTime? addedAt;
  final bool mine;
  factory FootageLink.fromJson(Map<String, dynamic> j) => FootageLink(
        id: _s(j['id']),
        url: _s(j['url']),
        label: _s(j['label']),
        provider: _s(j['provider']).isEmpty ? 'dropbox' : _s(j['provider']),
        kind: _s(j['kind']).isEmpty ? 'folder' : _s(j['kind']),
        source: _s(j['source']).isEmpty ? 'artist' : _s(j['source']),
        addedByName: _s(j['addedByName']),
        addedAt: _dt(j['addedAt']),
        mine: j['mine'] == true,
        summary: _s(j['summary']),
      );

  String get title => label.isNotEmpty ? label : (kind == 'folder' ? (provider == 'drive' ? 'Drive folder' : 'Dropbox folder') : 'Video');
}

/// One work day's footage: the folder to use, where it stands, the links and (from Dropbox) the files and their size.
class FootageDay {
  const FootageDay({required this.day, this.folderName = '', this.state = 'waiting', this.due = false, this.links = const [], this.files = const [], this.size = '', this.uploadPage = '', this.editorName = ''});
  final String day, folderName, state, size, uploadPage, editorName;
  final bool due;
  final List<FootageLink> links;
  final List<({String name, int size})> files;
  factory FootageDay.fromJson(Map<String, dynamic> j) => FootageDay(
        day: _s(j['day']),
        folderName: _s(j['folderName']),
        state: _s(j['state']).isEmpty ? 'waiting' : _s(j['state']),
        due: j['due'] == true,
        links: _l(j['links']).map(FootageLink.fromJson).toList(),
        files: [for (final f in _l(j['files'])) (name: _s(f['name']), size: _i(f['size']))],
        size: _s(j['size']),
        uploadPage: _s(j['uploadPage']),
        editorName: _s(j['editorName']),
      );
}

/// A booking's footage, for the artist's work card (and Marketing).
class BookingFootage {
  const BookingFootage({required this.bookingId, this.bookingNumber = '', this.client = '', this.service = '', this.needsContent = false, this.shootTitle = '', this.dropboxEnabled = false, this.canAdd = false, this.isMarketing = false, this.days = const []});
  final String bookingId, bookingNumber, client, service, shootTitle;
  final bool needsContent, dropboxEnabled, canAdd, isMarketing;
  final List<FootageDay> days;
  factory BookingFootage.fromJson(Map<String, dynamic> j) => BookingFootage(
        bookingId: _s(j['bookingId']),
        bookingNumber: _s(j['bookingNumber']),
        client: _s(j['client']),
        service: _s(j['service']),
        needsContent: j['needsContent'] == true,
        shootTitle: _s(_m(j['shoot'])['title']),
        dropboxEnabled: _m(j['dropbox'])['enabled'] == true,
        canAdd: j['canAdd'] == true,
        isMarketing: j['isMarketing'] == true,
        days: _l(j['days']).map(FootageDay.fromJson).toList(),
      );
}

/// A work's footage in Marketing's inbox.
class FootageItem {
  const FootageItem({required this.id, this.bookingId = '', this.bookingNumber = '', this.client = '', this.service = '', this.day = '', this.folderName = '', this.status = 'new', this.links = const [], this.fileCount = 0, this.size = '', this.firstAt, this.editorName = '', this.uploaders = const []});
  final String id, bookingId, bookingNumber, client, service, day, folderName, status, size, editorName;
  final List<FootageLink> links;
  final int fileCount;
  final DateTime? firstAt;
  final List<String> uploaders;
  factory FootageItem.fromJson(Map<String, dynamic> j) => FootageItem(
        id: _s(j['id']),
        bookingId: _s(j['bookingId']),
        bookingNumber: _s(j['bookingNumber']),
        client: _s(j['client']),
        service: _s(j['service']),
        day: _s(j['day']),
        folderName: _s(j['folderName']),
        status: _s(j['status']).isEmpty ? 'new' : _s(j['status']),
        links: _l(j['links']).map(FootageLink.fromJson).toList(),
        fileCount: _i(j['fileCount']),
        size: _s(j['size']),
        firstAt: _dt(j['firstAt']),
        editorName: _s(j['editorName']),
        uploaders: _strs(j['uploaders']),
      );
}

/// A work owing footage: it needs content, its day has come, nothing is in.
class FootageWaiting {
  const FootageWaiting({required this.bookingId, this.bookingNumber = '', this.client = '', this.service = '', this.day = '', this.folderName = '', this.artists = const []});
  final String bookingId, bookingNumber, client, service, day, folderName;
  final List<String> artists;
  factory FootageWaiting.fromJson(Map<String, dynamic> j) => FootageWaiting(bookingId: _s(j['bookingId']), bookingNumber: _s(j['bookingNumber']), client: _s(j['client']), service: _s(j['service']), day: _s(j['day']), folderName: _s(j['folderName']), artists: _strs(j['artists']));
}

class FootageInbox {
  const FootageInbox({this.counts = const {}, this.items = const [], this.waiting = const [], this.dropboxEnabled = false});
  final Map<String, int> counts;
  final List<FootageItem> items;
  final List<FootageWaiting> waiting;
  final bool dropboxEnabled;
  factory FootageInbox.fromJson(Map<String, dynamic> j) => FootageInbox(
        counts: _m(j['counts']).map((k, v) => MapEntry(k, _i(v))),
        items: _l(j['items']).map(FootageItem.fromJson).toList(),
        waiting: _l(j['waiting']).map(FootageWaiting.fromJson).toList(),
        dropboxEnabled: _m(j['dropbox'])['enabled'] == true,
      );
}
