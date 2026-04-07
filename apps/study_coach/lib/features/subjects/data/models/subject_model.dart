import '../../domain/entities/subject.dart';

class SubjectModel extends Subject {
  const SubjectModel({
    required super.id,
    required super.name,
    required super.examDateIso,
    super.color,
  });

  factory SubjectModel.fromMap(String id, Map<String, dynamic> map) {
    return SubjectModel(
      id: id,
      name: map['name'] as String? ?? '',
      examDateIso: map['examDate'] as String? ?? '',
      color: map['color'] as String? ?? '',
    );
  }
}
