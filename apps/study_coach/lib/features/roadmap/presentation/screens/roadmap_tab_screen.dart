import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/state/app_providers.dart';
import '../controllers/roadmap_progress_providers.dart';

class RoadmapTabScreen extends ConsumerWidget {
  const RoadmapTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
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

class _MajorRoadmapScreen extends ConsumerStatefulWidget {
  const _MajorRoadmapScreen({required this.major});

  final _RoadmapMajor major;

  @override
  ConsumerState<_MajorRoadmapScreen> createState() =>
      _MajorRoadmapScreenState();
}

class _MajorRoadmapScreenState extends ConsumerState<_MajorRoadmapScreen> {
  final Set<String> _completedChecklist = <String>{};

  String _phaseActionKey(int phaseIndex, int actionIndex) =>
      'phase:$phaseIndex:action:$actionIndex';

  String _subjectTopicKey(int subjectIndex, int topicIndex) =>
      'subject:$subjectIndex:topic:$topicIndex';

  bool _isCompleted({
    required Set<String> persistedKeys,
    required String key,
    required bool canPersist,
  }) {
    if (canPersist) return persistedKeys.contains(key);
    return _completedChecklist.contains(key);
  }

  Future<void> _toggleCompleted({
    required String key,
    required bool currentValue,
    required bool canPersist,
    required String uid,
    required int totalItemCount,
  }) async {
    if (!canPersist) {
      setState(() {
        if (currentValue) {
          _completedChecklist.remove(key);
        } else {
          _completedChecklist.add(key);
        }
      });
      return;
    }

    await ref.read(roadmapProgressRepositoryProvider).toggleItem(
          uid: uid,
          majorId: widget.major.id,
          itemKey: key,
          completed: !currentValue,
          totalItemCount: totalItemCount,
        );
  }

  Future<void> _openResource(BuildContext context, String url) async {
    final strings = AppStrings.of(context);
    final normalizedUrl =
        url.startsWith('http://') || url.startsWith('https://')
            ? url
            : 'https://$url';
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) {
      _showOpenResourceError(context, strings);
      return;
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!launched && context.mounted) {
        _showOpenResourceError(context, strings);
      }
    } on PlatformException {
      if (context.mounted) {
        _showOpenResourceError(context, strings);
      }
    } catch (_) {
      if (context.mounted) {
        _showOpenResourceError(context, strings);
      }
    }
  }

  Future<void> _showOpenResourceError(
    BuildContext context,
    AppStrings strings,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(strings.couldNotOpenResource),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authUser = ref.watch(currentAuthUserProvider).valueOrNull;
    final canPersist = authUser != null;
    final phases = _buildPhasesForMajor(widget.major.title, strings);
    final totalChecklistItems = phases.fold<int>(
          0,
          (sum, phase) => sum + phase.actions.length,
        ) +
        widget.major.subjects.fold<int>(
          0,
          (sum, subject) => sum + subject.topics.length,
        );
    final resources = _buildResourcesForMajor(widget.major.title);
    final projects = _buildProjectsForMajor(widget.major.title);
    final persistedKeys = authUser == null
        ? <String>{}
        : ref
                .watch(
                  roadmapCompletedItemsStreamProvider(
                    RoadmapProgressKey(
                        uid: authUser.uid, majorId: widget.major.id),
                  ),
                )
                .valueOrNull ??
            <String>{};

    return Scaffold(
      appBar: AppBar(title: Text(strings.majorRoadmap(widget.major.title))),
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
                    strings.successBlueprint,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.howToSucceedInMajor(widget.major.title),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.focusSubjectsFirst(widget.major.title),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            strings.roadmapPhases,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...phases.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RoadmapPhaseCard(
                    phase: entry.value,
                    phaseNumber: entry.key + 1,
                    isActionCompleted: (actionIndex) => _isCompleted(
                      persistedKeys: persistedKeys,
                      key: _phaseActionKey(entry.key, actionIndex),
                      canPersist: canPersist,
                    ),
                    onToggleAction: (actionIndex) async {
                      final key = _phaseActionKey(entry.key, actionIndex);
                      final current = _isCompleted(
                        persistedKeys: persistedKeys,
                        key: key,
                        canPersist: canPersist,
                      );
                      await _toggleCompleted(
                        key: key,
                        currentValue: current,
                        canPersist: canPersist,
                        uid: authUser?.uid ?? '',
                        totalItemCount: totalChecklistItems,
                      );
                    },
                  ),
                ),
              ),
          const SizedBox(height: 8),
          Text(
            strings.priorityRoadmap,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...widget.major.subjects.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SubjectTopicsCard(
                    subject: entry.value,
                    isTopicCompleted: (topicIndex) => _isCompleted(
                      persistedKeys: persistedKeys,
                      key: _subjectTopicKey(entry.key, topicIndex),
                      canPersist: canPersist,
                    ),
                    onToggleTopic: (topicIndex) async {
                      final key = _subjectTopicKey(entry.key, topicIndex);
                      final current = _isCompleted(
                        persistedKeys: persistedKeys,
                        key: key,
                        canPersist: canPersist,
                      );
                      await _toggleCompleted(
                        key: key,
                        currentValue: current,
                        canPersist: canPersist,
                        uid: authUser?.uid ?? '',
                        totalItemCount: totalChecklistItems,
                      );
                    },
                  ),
                ),
              ),
          const SizedBox(height: 8),
          Text(
            strings.keyResources,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.8),
              ),
            ),
            child: Column(
              children: resources
                  .map(
                    (resource) => ListTile(
                      leading: CircleAvatar(
                        radius: 15,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(
                          Icons.open_in_new_rounded,
                          size: 15,
                          color: colorScheme.primary,
                        ),
                      ),
                      title: Text(resource.label),
                      subtitle: Text(resource.url),
                      trailing: TextButton(
                        onPressed: () => _openResource(context, resource.url),
                        child: Text(strings.openResource),
                      ),
                      onTap: () => _openResource(context, resource.url),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            strings.projectIdeas,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.8),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: projects
                    .map(
                      (project) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.tips_and_updates_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                project,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadmapPhaseCard extends StatelessWidget {
  const _RoadmapPhaseCard({
    required this.phase,
    required this.phaseNumber,
    required this.isActionCompleted,
    required this.onToggleAction,
  });

  final _RoadmapPhase phase;
  final int phaseNumber;
  final bool Function(int actionIndex) isActionCompleted;
  final ValueChanged<int> onToggleAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    '$phaseNumber',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    phase.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  phase.timeframe,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...phase.actions.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onToggleAction(entry.key),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isActionCompleted(entry.key)
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SubjectTopicsCard extends StatelessWidget {
  const _SubjectTopicsCard({
    required this.subject,
    required this.isTopicCompleted,
    required this.onToggleTopic,
  });

  final _RoadmapSubject subject;
  final bool Function(int topicIndex) isTopicCompleted;
  final ValueChanged<int> onToggleTopic;

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
            ...subject.topics.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onToggleTopic(entry.key),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isTopicCompleted(entry.key)
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  String get id => _majorIdFromTitle(title);
}

class _RoadmapSubject {
  const _RoadmapSubject({
    required this.name,
    required this.topics,
  });

  final String name;
  final List<String> topics;
}

class _RoadmapPhase {
  const _RoadmapPhase({
    required this.title,
    required this.timeframe,
    required this.actions,
  });

  final String title;
  final String timeframe;
  final List<String> actions;
}

class _RoadmapResource {
  const _RoadmapResource({
    required this.label,
    required this.url,
  });

  final String label;
  final String url;
}

List<_RoadmapPhase> _buildPhasesForMajor(
    String majorTitle, AppStrings strings) {
  return [
    _RoadmapPhase(
      title: 'Build your foundation',
      timeframe: '1-4 ${strings.weeksShort}',
      actions: [
        'Review syllabus and map each subject to weekly goals.',
        'Choose one trusted source per subject to avoid overload.',
        'Set a fixed daily study block and weekly revision slot.',
      ],
    ),
    _RoadmapPhase(
      title: 'Practice deeply',
      timeframe: '5-8 ${strings.weeksShort}',
      actions: [
        'Solve practice sets and past papers for every core subject.',
        'Use active recall and spaced repetition for long-term memory.',
        'Summarize each week in 1 page to spot weak topics early.',
      ],
    ),
    _RoadmapPhase(
      title: 'Prove mastery',
      timeframe: '9-12 ${strings.weeksShort}',
      actions: [
        'Build one practical output that matches $majorTitle.',
        'Teach one concept to a peer every week to test understanding.',
        'Run mock exams under time constraints before final assessments.',
      ],
    ),
  ];
}

List<_RoadmapResource> _buildResourcesForMajor(String majorTitle) {
  final shared = [
    const _RoadmapResource(
      label: 'Coursera Learning Paths',
      url: 'https://www.coursera.org',
    ),
    const _RoadmapResource(
      label: 'Khan Academy',
      url: 'https://www.khanacademy.org',
    ),
    const _RoadmapResource(
      label: 'MIT OpenCourseWare',
      url: 'https://ocw.mit.edu',
    ),
  ];

  switch (majorTitle) {
    case 'Computer Science':
      return [
        const _RoadmapResource(
          label: 'Developer Roadmaps',
          url: 'https://roadmap.sh',
        ),
        const _RoadmapResource(
          label: 'CS50 by Harvard',
          url: 'https://cs50.harvard.edu/x',
        ),
        const _RoadmapResource(
          label: 'LeetCode Practice',
          url: 'https://leetcode.com',
        ),
        ...shared,
      ];
    case 'Information Technology':
      return [
        const _RoadmapResource(
          label: 'Cisco Networking Academy',
          url: 'https://www.netacad.com',
        ),
        const _RoadmapResource(
          label: 'Microsoft Learn',
          url: 'https://learn.microsoft.com',
        ),
        ...shared,
      ];
    case 'Medicine':
    case 'Nursing':
    case 'Pharmacy':
      return [
        const _RoadmapResource(
          label: 'World Health Organization Learning Hub',
          url: 'https://www.who.int/learning',
        ),
        const _RoadmapResource(
          label: 'PubMed',
          url: 'https://pubmed.ncbi.nlm.nih.gov',
        ),
        ...shared,
      ];
    case 'Law':
      return [
        const _RoadmapResource(
          label: 'Cornell Legal Information Institute',
          url: 'https://www.law.cornell.edu',
        ),
        const _RoadmapResource(
          label: 'Harvard Law Library Research Guides',
          url: 'https://guides.library.harvard.edu/law',
        ),
        ...shared,
      ];
    case 'Architecture':
    case 'Graphic Design':
      return [
        const _RoadmapResource(
          label: 'ArchDaily',
          url: 'https://www.archdaily.com',
        ),
        const _RoadmapResource(
          label: 'Behance',
          url: 'https://www.behance.net',
        ),
        ...shared,
      ];
    default:
      return shared;
  }
}

List<String> _buildProjectsForMajor(String majorTitle) {
  switch (majorTitle) {
    case 'Computer Science':
      return [
        'Build a full-stack app and deploy it publicly.',
        'Implement a data structures visualizer with tests.',
        'Contribute one pull request to an open-source project.',
      ];
    case 'Information Technology':
      return [
        'Design a secure small-office network diagram.',
        'Set up a Linux server with monitoring and backups.',
        'Document an incident-response checklist for common outages.',
      ];
    case 'Business Administration':
      return [
        'Create a business model canvas for a local startup idea.',
        'Run a simple market survey and present insights.',
        'Build a financial forecast sheet for one semester.',
      ];
    case 'Mechanical Engineering':
      return [
        'Model and simulate a mechanical component in CAD.',
        'Build a mini prototype and measure performance changes.',
        'Write a short technical report with design trade-offs.',
      ];
    case 'Medicine':
      return [
        'Prepare a clinical case presentation with differential diagnosis.',
        'Create flashcards for high-yield pharmacology facts.',
        'Run mock OSCE-style practice with peers weekly.',
      ];
    case 'Law':
      return [
        'Write a case brief for a landmark judgment.',
        'Draft a legal memo on a current policy issue.',
        'Practice oral argument for a mock hearing.',
      ];
    case 'Civil Engineering':
      return [
        'Draft a structural concept for a small public facility.',
        'Perform basic site and soil analysis for a case study.',
        'Build a project timeline with cost estimation basics.',
      ];
    case 'Electrical Engineering':
      return [
        'Build and test an amplifier or filter circuit.',
        'Simulate a power distribution scenario in software.',
        'Document lab results and error analysis clearly.',
      ];
    case 'Nursing':
      return [
        'Create a patient education plan for a chronic condition.',
        'Practice care-plan documentation from sample scenarios.',
        'Run medication safety checklists during simulation drills.',
      ];
    case 'Pharmacy':
      return [
        'Analyze a prescription for interactions and contraindications.',
        'Create a counseling script for a common medication class.',
        'Prepare a therapeutic comparison chart for similar drugs.',
      ];
    case 'Architecture':
      return [
        'Build a studio portfolio page for your best project.',
        'Develop a site analysis board with climate response.',
        'Produce a concept-to-detail design narrative.',
      ];
    case 'Psychology':
      return [
        'Design a small survey study and analyze findings.',
        'Write a literature review on one behavior topic.',
        'Present a poster summarizing methods and limitations.',
      ];
    case 'Economics':
      return [
        'Replicate one published econometrics analysis in a notebook.',
        'Track macro indicators and explain trends monthly.',
        'Build a policy brief with data-backed recommendations.',
      ];
    case 'Graphic Design':
      return [
        'Create a full brand identity kit for a mock client.',
        'Redesign a mobile app onboarding flow.',
        'Publish a portfolio case study with before/after rationale.',
      ];
    default:
      return [
        'Build one practical artifact related to your major.',
        'Collect feedback from a mentor and improve iteration 2.',
        'Present outcomes in a portfolio-ready format.',
      ];
  }
}

String _majorIdFromTitle(String title) {
  return title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
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
