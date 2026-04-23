class MajorCatalogEntry {
  const MajorCatalogEntry({
    required this.id,
    required this.title,
  });

  final String id;
  final String title;
}

const majorCatalog = <MajorCatalogEntry>[
  MajorCatalogEntry(id: 'computer_science', title: 'Computer Science'),
  MajorCatalogEntry(
      id: 'information_technology', title: 'Information Technology'),
  MajorCatalogEntry(
      id: 'business_administration', title: 'Business Administration'),
  MajorCatalogEntry(
      id: 'mechanical_engineering', title: 'Mechanical Engineering'),
  MajorCatalogEntry(id: 'medicine', title: 'Medicine'),
  MajorCatalogEntry(id: 'law', title: 'Law'),
  MajorCatalogEntry(id: 'civil_engineering', title: 'Civil Engineering'),
  MajorCatalogEntry(
      id: 'electrical_engineering', title: 'Electrical Engineering'),
  MajorCatalogEntry(id: 'nursing', title: 'Nursing'),
  MajorCatalogEntry(id: 'pharmacy', title: 'Pharmacy'),
  MajorCatalogEntry(id: 'architecture', title: 'Architecture'),
  MajorCatalogEntry(id: 'psychology', title: 'Psychology'),
  MajorCatalogEntry(id: 'economics', title: 'Economics'),
  MajorCatalogEntry(id: 'graphic_design', title: 'Graphic Design'),
];

String majorTitleFromId(String? majorId) {
  if (majorId == null || majorId.isEmpty) return '';
  for (final major in majorCatalog) {
    if (major.id == majorId) return major.title;
  }
  return majorId;
}
