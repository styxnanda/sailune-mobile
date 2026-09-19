import 'package:sailune_mobile/data/library.dart';

Map<String, dynamic> sample({int id = 1}) => {
  'id': id,
  'url': 'https://www.fanfiction.net/s/$id/1',
  'site': 'ffn',
  'title': id == 1 ? 'The quiet between the stars' : 'A map of little things',
  'author': id == 1 ? 'paperlanterns' : 'thelastlighthouse',
  'status': 'reading',
  'chapter': id == 1 ? 7 : 3,
  'rating': id == 1 ? 5 : 0,
  'notes': 'A story to return to.',
  'tags': <String>['Comfort read'],
  'effective': {
    'chapters': 24,
    'words': 48200,
    'fandoms': ['Original Work'],
    'summary': 'Some journeys begin with a letter. Others begin with a place to call home.',
  },
};

class FakeLibrary implements Library {
  bool onboarded = true;
  @override
  Future<bool> loadOnboarding() async => onboarded;
  @override
  Future<void> completeOnboarding() async {
    onboarded = true;
  }

  final sessions = <String, bool>{'ao3': false, 'ffn': false};
  final sessionConnections = <String>[];
  @override
  Future<Map<String, bool>> websiteSessions() async => Map.of(sessions);
  @override
  Future<void> connectWebsite(String site, {required bool consent}) async {
    if (!consent) throw Exception('Consent required');
    sessionConnections.add(site);
    sessions[site] = true;
  }

  @override
  Future<void> clearWebsiteSessions({required bool consent}) async {
    if (!consent) throw Exception('Consent required');
    sessions.updateAll((_, _) => false);
  }

  List<Map<String, dynamic>> rows;
  bool failSave = false, failList = false;
  final requests = <Map<String, dynamic>>[];
  final links = <String>[];
  String theme = 'light';
  FakeLibrary({List<Map<String, dynamic>>? rows})
    : rows = rows ?? [sample(), sample(id: 2)];
  @override
  Future<dynamic> call(
    Map<String, dynamic> request, {
    String? requestId,
  }) async {
    requests.add(request);
    switch (request['op']) {
      case 'list':
        if (failList) throw Exception('Library unavailable');
        final f = request['filter'] as Map;
        final filtered = rows
            .where(
              (r) =>
                  ((f['Status'] as String? ?? '').isEmpty ||
                      r['status'] == f['Status']) &&
                  (r['title'] as String).toLowerCase().contains(
                    (f['Query'] as String? ?? '').toLowerCase(),
                  ),
            )
            .toList();
        return filtered
            .skip(f['Offset'] as int? ?? 0)
            .take(f['Limit'] as int? ?? 40)
            .toList();
      case 'get':
        return rows.firstWhere((r) => r['id'] == request['id']);
      case 'update':
        if (failSave) throw Exception('Could not save. Please try again.');
        final i = rows.indexWhere((r) => r['id'] == request['id']);
        rows[i] = {
          ...rows[i],
          for (final e in (request['patch'] as Map).entries)
            (e.key as String).toLowerCase(): e.value,
        };
        return rows[i];
      case 'add':
        if (failSave) throw Exception('Could not save. Please try again.');
        final row = {
          ...sample(id: rows.length + 1),
          ...request['bookmark'] as Map<String, dynamic>,
        };
        rows.add(row);
        return row;
      case 'delete':
        rows.removeWhere((r) => r['id'] == request['id']);
        return true;
      case 'open':
        return rows.firstWhere((r) => r['id'] == request['id'])['url'];
      case 'resume':
        return 'https://www.fanfiction.net/s/${request['id']}/8';
      default:
        throw UnsupportedError('${request['op']}');
    }
  }

  @override
  Future<void> cancel(String requestId) async {}

  @override
  Future<void> openLink(String url) async {
    links.add(url);
  }

  @override
  Future<String?> pickBackup() async => null;
  @override
  Future<bool> saveBackup(String snapshot) async => false;
  @override
  Future<String> loadTheme() async => theme;
  @override
  Future<void> saveTheme(String value) async {
    theme = value;
  }
}
