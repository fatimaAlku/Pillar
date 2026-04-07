class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.examDateIso,
    this.color = '',
  });

  final String id;
  final String name;
  final String examDateIso;
  final String color;
}
