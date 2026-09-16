const shelves = <String, String>{
  '': 'All stories',
  'reading': 'Reading',
  'planned': 'To read',
  'completed': 'Completed',
  'hold': 'On hold',
  'dropped': 'Dropped',
};

class Story {
  final Map<String, dynamic> json;
  const Story(this.json);
  int get id => json['id'] as int;
  String get url => json['url'] as String;
  String get title => (json['title'] as String? ?? '').isEmpty
      ? 'Untitled story'
      : json['title'] as String;
  String get author => json['author'] as String? ?? '';
  String get site => json['site'] == 'ao3' ? 'AO3' : 'FFN';
  String get status => json['status'] as String? ?? 'planned';
  int get chapter => json['chapter'] as int? ?? 0;
  int get rating => json['rating'] as int? ?? 0;
  String get notes => json['notes'] as String? ?? '';
  List<String> get tags => (json['tags'] as List? ?? []).cast<String>();
  Map<String, dynamic> get metadata =>
      (json['effective'] as Map<String, dynamic>?) ?? {};
  int get chapters => metadata['chapters'] as int? ?? 0;
  int get words => metadata['words'] as int? ?? 0;
  String get summary => metadata['summary'] as String? ?? '';
  List<String> get fandoms =>
      (metadata['fandoms'] as List? ?? []).cast<String>();
  bool get caughtUp => chapters > 0 && chapter >= chapters;
  double? get progress =>
      chapters > 0 ? (chapter / chapters).clamp(0, 1) : null;
  String get progressLabel =>
      'Chapter $chapter / ${chapters > 0 ? chapters : '—'}';
}
