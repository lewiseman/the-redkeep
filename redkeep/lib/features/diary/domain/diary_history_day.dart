export 'diary_document.dart';
import 'diary_document.dart';

class DiaryHistoryDay {
  const DiaryHistoryDay(this.dateString, this.items, {this.dayTitle});
  final String dateString;
  final List<DiaryEntry> items;
  final String? dayTitle;
  bool get isDeleted => false;
  Iterable<DiaryEntry> get visibleItems =>
      items.where((e) => e.deletedAt == null && !e.text.isEmpty);
}

extension DiaryHistoryItem on DiaryEntry {
  String get itemUuid => id;
  String get content =>
      text.title.isEmpty ? text.body : '${text.title}\n\n${text.body}';
  bool get isDeleted => deletedAt != null;
}
