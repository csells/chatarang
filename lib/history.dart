import 'package:dartantic_ai/dartantic_ai.dart';

class HistoryEntry {
  HistoryEntry({required this.message, required this.modelName});
  final Message message;
  final String modelName;
}
