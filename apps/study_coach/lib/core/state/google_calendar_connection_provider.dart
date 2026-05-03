import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Incremented after Google Calendar connect finishes (global OAuth handler) so
/// Profile (or other UI) can refresh status.
final googleCalendarConnectionBumpProvider = StateProvider<int>((ref) => 0);
