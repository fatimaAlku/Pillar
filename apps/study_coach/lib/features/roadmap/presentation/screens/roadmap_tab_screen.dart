import 'package:flutter/material.dart';

class RoadmapTabScreen extends StatelessWidget {
  const RoadmapTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.tertiaryContainer.withValues(alpha: 0.8),
                ],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.account_tree_rounded,
                  color: colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pick your major to open a focused roadmap with the most important subjects and topics.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Majors Roadmap',
          textAlign: TextAlign.center,
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _majors.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.2,
          ),
          itemBuilder: (context, index) {
            final major = _majors[index];
            return _MajorCard(major: major);
          },
        ),
      ],
    );
  }
}

class _MajorCard extends StatelessWidget {
  const _MajorCard({required this.major});

  final _RoadmapMajor major;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _MajorRoadmapScreen(major: major),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(major.icon, color: colorScheme.primary),
              ),
              const SizedBox(height: 10),
              Text(
                major.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  major.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MajorRoadmapScreen extends StatelessWidget {
  const _MajorRoadmapScreen({required this.major});

  final _RoadmapMajor major;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('${major.title} Roadmap')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.55),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Priority roadmap',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Focus these subjects first to build a strong foundation in ${major.title}.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...major.subjects.map(
            (subject) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SubjectTopicsCard(subject: subject),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectTopicsCard extends StatelessWidget {
  const _SubjectTopicsCard({required this.subject});

  final _RoadmapSubject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ...subject.topics.map(
              (topic) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        topic,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoadmapMajor {
  const _RoadmapMajor({
    required this.title,
    required this.description,
    required this.icon,
    required this.subjects,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<_RoadmapSubject> subjects;
}

class _RoadmapSubject {
  const _RoadmapSubject({
    required this.name,
    required this.topics,
  });

  final String name;
  final List<String> topics;
}

const _majors = [
  _RoadmapMajor(
    title: 'Computer Science',
    description: 'Software, algorithms, and systems thinking.',
    icon: Icons.computer_rounded,
    subjects: [
      _RoadmapSubject(
        name: 'Programming Foundations',
        topics: ['Data types and control flow', 'OOP principles', 'Debugging'],
      ),
      _RoadmapSubject(
        name: 'Data Structures & Algorithms',
        topics: [
          'Arrays, linked lists, trees',
          'Sorting and searching',
          'Big-O'
        ],
      ),
      _RoadmapSubject(
        name: 'Databases',
        topics: ['SQL basics', 'Database design', 'Indexing and optimization'],
      ),
      _RoadmapSubject(
        name: 'Software Engineering',
        topics: [
          'Git and version control',
          'Testing fundamentals',
          'API design'
        ],
      ),
    ],
  ),
  _RoadmapMajor(
    title: 'Information Technology',
    description: 'Infrastructure, support, and enterprise tools.',
    icon: Icons.dns_rounded,
    subjects: [
      _RoadmapSubject(
        name: 'Networking',
        topics: [
          'TCP/IP fundamentals',
          'Routing and switching',
          'Network security'
        ],
      ),
      _RoadmapSubject(
        name: 'System Administration',
        topics: [
          'Linux/Windows admin',
          'User and access management',
          'Backup plans'
        ],
      ),
      _RoadmapSubject(
        name: 'Cloud Basics',
        topics: [
          'Virtual machines',
          'Storage services',
          'Monitoring and logging'
        ],
      ),
    ],
  ),
  _RoadmapMajor(
    title: 'Business Administration',
    description: 'Management, strategy, and operations excellence.',
    icon: Icons.business_center_rounded,
    subjects: [
      _RoadmapSubject(
        name: 'Management',
        topics: ['Leadership styles', 'Team motivation', 'Decision making'],
      ),
      _RoadmapSubject(
        name: 'Finance',
        topics: ['Financial statements', 'Budgeting', 'Cost analysis'],
      ),
      _RoadmapSubject(
        name: 'Marketing',
        topics: [
          'Market research',
          'Brand strategy',
          'Digital marketing basics'
        ],
      ),
    ],
  ),
  _RoadmapMajor(
    title: 'Mechanical Engineering',
    description: 'Design, manufacturing, and physical systems.',
    icon: Icons.precision_manufacturing_rounded,
    subjects: [
      _RoadmapSubject(
        name: 'Engineering Mathematics',
        topics: ['Calculus', 'Differential equations', 'Numerical methods'],
      ),
      _RoadmapSubject(
        name: 'Mechanics',
        topics: ['Statics', 'Dynamics', 'Strength of materials'],
      ),
      _RoadmapSubject(
        name: 'Thermal Sciences',
        topics: ['Thermodynamics', 'Heat transfer', 'Fluid mechanics'],
      ),
    ],
  ),
  _RoadmapMajor(
    title: 'Medicine',
    description: 'Core sciences and clinical competency.',
    icon: Icons.local_hospital_rounded,
    subjects: [
      _RoadmapSubject(
        name: 'Basic Medical Sciences',
        topics: ['Anatomy', 'Physiology', 'Biochemistry'],
      ),
      _RoadmapSubject(
        name: 'Pathology & Pharmacology',
        topics: [
          'Disease mechanisms',
          'Drug classifications',
          'Clinical cases'
        ],
      ),
      _RoadmapSubject(
        name: 'Clinical Skills',
        topics: [
          'History taking',
          'Physical examination',
          'Diagnostic reasoning'
        ],
      ),
    ],
  ),
  _RoadmapMajor(
    title: 'Law',
    description: 'Legal reasoning and practical application.',
    icon: Icons.gavel_rounded,
    subjects: [
      _RoadmapSubject(
        name: 'Legal Foundations',
        topics: ['Constitutional law', 'Contract law', 'Criminal law'],
      ),
      _RoadmapSubject(
        name: 'Legal Skills',
        topics: ['Case analysis', 'Legal writing', 'Oral advocacy'],
      ),
      _RoadmapSubject(
        name: 'Procedures',
        topics: [
          'Civil procedure',
          'Evidence rules',
          'Ethics and professionalism'
        ],
      ),
    ],
  ),
  _RoadmapMajor(
    title: 'Civil Engineering',
    description: 'Infrastructure design, analysis, and construction.',
    icon: Icons.engineering_rounded,
    subjects: [
      _RoadmapSubject(
        name: 'Structural Analysis',
        topics: [
          'Load calculations',
          'Beam design',
          'Concrete and steel design'
        ],
      ),
      _RoadmapSubject(
        name: 'Geotechnical Engineering',
        topics: ['Soil mechanics', 'Foundation design', 'Site investigation'],
      ),
      _RoadmapSubject(
        name: 'Construction Management',
        topics: ['Project planning', 'Cost estimation', 'Quality and safety'],
      ),
    ],
  ),
  _RoadmapMajor(
    title: 'Electrical Engineering',
    description: 'Circuits, electronics, and power systems.',
    icon: Icons.electrical_services_rounded,
    subjects: [
      _RoadmapSubject(
        name: 'Circuit Theory',
        topics: [
          'Ohm and Kirchhoff laws',
          'AC/DC analysis',
          'Network theorems'
        ],
      ),
      _RoadmapSubject(
        name: 'Electronics',
        topics: [
          'Diodes and transistors',
          'Amplifiers',
          'Digital logic basics'
        ],
      ),
      _RoadmapSubject(
        name: 'Power Systems',
        topics: [
          'Generation basics',
          'Transmission and distribution',
          'Protection'
        ],
      ),
    ],
  ),
  _RoadmapMajor(
    title: 'Nursing',
    description: 'Patient care, safety, and clinical practice.',
    icon: Icons.medical_services_rounded,
    subjects: [
      _RoadmapSubject(
        name: 'Fundamentals of Nursing',
        topics: ['Patient assessment', 'Vital signs', 'Infection control'],
      ),
      _RoadmapSubject(
        name: 'Medical-Surgical Nursing',
        topics: [
          'Adult health conditions',
          'Care planning',
          'Medication safety'
        ],
      ),
      _RoadmapSubject(
        name: 'Community Health',
        topics: ['Health promotion', 'Preventive care', 'Family education'],
      ),
    ],
  ),
  _RoadmapMajor(
    title: 'Pharmacy',
    description: 'Medicines, therapeutics, and patient counseling.',
    icon: Icons.medication_rounded,
    subjects: [
      _RoadmapSubject(
        name: 'Pharmacology',
        topics: ['Drug mechanisms', 'Adverse effects', 'Drug interactions'],
      ),
      _RoadmapSubject(
        name: 'Pharmaceutics',
        topics: [
          'Dosage forms',
          'Drug delivery systems',
          'Stability and storage'
        ],
      ),
      _RoadmapSubject(
        name: 'Clinical Pharmacy',
        topics: [
          'Therapeutic guidelines',
          'Case-based decisions',
          'Counseling'
        ],
      ),
    ],
  ),
  _RoadmapMajor(
    title: 'Architecture',
    description: 'Design thinking, building systems, and urban context.',
    icon: Icons.architecture_rounded,
    subjects: [
      _RoadmapSubject(
        name: 'Design Studio',
        topics: [
          'Concept development',
          'Spatial planning',
          'Presentation boards'
        ],
      ),
      _RoadmapSubject(
        name: 'Building Technology',
        topics: [
          'Construction materials',
          'Structural systems',
          'Building codes'
        ],
      ),
      _RoadmapSubject(
        name: 'Urban & Environmental Studies',
        topics: [
          'Urban design basics',
          'Sustainability principles',
          'Site analysis'
        ],
      ),
    ],
  ),
  _RoadmapMajor(
    title: 'Psychology',
    description: 'Human behavior, cognition, and research methods.',
    icon: Icons.psychology_rounded,
    subjects: [
      _RoadmapSubject(
        name: 'Core Psychology',
        topics: [
          'Cognitive psychology',
          'Developmental psychology',
          'Social psychology'
        ],
      ),
      _RoadmapSubject(
        name: 'Research Methods',
        topics: [
          'Experimental design',
          'Data collection',
          'Ethical guidelines'
        ],
      ),
      _RoadmapSubject(
        name: 'Statistics for Psychology',
        topics: [
          'Descriptive statistics',
          'Hypothesis testing',
          'Interpretation'
        ],
      ),
    ],
  ),
  _RoadmapMajor(
    title: 'Economics',
    description: 'Markets, policy, and quantitative analysis.',
    icon: Icons.query_stats_rounded,
    subjects: [
      _RoadmapSubject(
        name: 'Microeconomics',
        topics: ['Supply and demand', 'Consumer theory', 'Market structures'],
      ),
      _RoadmapSubject(
        name: 'Macroeconomics',
        topics: ['GDP and inflation', 'Monetary policy', 'Fiscal policy'],
      ),
      _RoadmapSubject(
        name: 'Econometrics',
        topics: [
          'Regression analysis',
          'Model assumptions',
          'Forecasting basics'
        ],
      ),
    ],
  ),
  _RoadmapMajor(
    title: 'Graphic Design',
    description: 'Visual communication and digital design skills.',
    icon: Icons.palette_rounded,
    subjects: [
      _RoadmapSubject(
        name: 'Design Principles',
        topics: ['Typography', 'Color theory', 'Composition and layout'],
      ),
      _RoadmapSubject(
        name: 'Digital Tools',
        topics: ['Vector design', 'Photo editing', 'UI mockup basics'],
      ),
      _RoadmapSubject(
        name: 'Branding & Portfolio',
        topics: [
          'Identity systems',
          'Visual storytelling',
          'Portfolio development'
        ],
      ),
    ],
  ),
];
