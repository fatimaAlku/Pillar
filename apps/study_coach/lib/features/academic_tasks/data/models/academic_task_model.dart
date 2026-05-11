import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/academic_task.dart';

class AcademicTaskModel extends AcademicTask {
  const AcademicTaskModel({
    required super.id,
    required super.title,
    required super.type,
    required super.dueDateIso,
    super.subjectId,
    super.estimatedMinutes,
    super.priority,
    super.status,
    super.notes,
    super.createdAtIso,
    super.updatedAtIso,
    super.completedAtIso,
  });

  factory AcademicTaskModel.fromMap(String id, Map<String, dynamic> map) {
    return AcademicTaskModel(
      id: id,
      title: (map['title'] as String?)?.trim() ?? '',
      type: _enumFromName(
        map['type'],
        AcademicTaskType.values,
        AcademicTaskType.other,
      ),
      subjectId: (map['subjectId'] as String?)?.trim() ?? '',
      dueDateIso: _dateString(map['dueDate']),
      estimatedMinutes:
          _intValue(map['estimatedMinutes'], fallback: 60).clamp(0, 24 * 60),
      priority: _enumFromName(
        map['priority'],
        AcademicTaskPriority.values,
        AcademicTaskPriority.medium,
      ),
      status: _enumFromName(
        map['status'],
        AcademicTaskStatus.values,
        AcademicTaskStatus.open,
      ),
      notes: (map['notes'] as String?)?.trim() ?? '',
      createdAtIso: _dateString(map['createdAt']),
      updatedAtIso: _dateString(map['updatedAt']),
      completedAtIso: _dateString(map['completedAt']),
    );
  }
}

T _enumFromName<T extends Enum>(Object? value, List<T> values, T fallback) {
  final raw = value is String ? value : '';
  for (final option in values) {
    if (option.name == raw) return option;
  }
  return fallback;
}

String _dateString(Object? value) {
  if (value is String) return value;
  if (value is Timestamp) return value.toDate().toIso8601String();
  return '';
}

int _intValue(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return fallback;
}
