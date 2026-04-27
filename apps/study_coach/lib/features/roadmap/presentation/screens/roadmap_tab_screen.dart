import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/state/app_providers.dart';
import '../controllers/roadmap_progress_providers.dart';

class RoadmapTabScreen extends ConsumerStatefulWidget {
  const RoadmapTabScreen({super.key});

  @override
  ConsumerState<RoadmapTabScreen> createState() => _RoadmapTabScreenState();
}

enum _RoadmapScope { all, yours }

class _RoadmapTabScreenState extends ConsumerState<RoadmapTabScreen> {
  _RoadmapScope _scope = _RoadmapScope.all;

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(currentAuthUserProvider).valueOrNull;
    final userProfile = authUser == null
        ? null
        : ref.watch(userProfileStreamProvider(authUser.uid)).valueOrNull;
    final userMajorId = userProfile?.majorId;
    final showingYourRoadmap = _scope == _RoadmapScope.yours;
    final majors = showingYourRoadmap
        ? _majors.where((major) => major.id == userMajorId).toList()
        : _majors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E1F4),
            borderRadius: BorderRadius.circular(18),
          ),
          child: SegmentedButton<_RoadmapScope>(
            style: SegmentedButton.styleFrom(
              backgroundColor: Colors.white,
              selectedBackgroundColor: Theme.of(context).colorScheme.primary,
              selectedForegroundColor: Colors.white,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            segments: [
              ButtonSegment<_RoadmapScope>(
                value: _RoadmapScope.all,
                label: Text(_roadmapText(context, 'All Roadmaps')),
              ),
              ButtonSegment<_RoadmapScope>(
                value: _RoadmapScope.yours,
                label: Text(_roadmapText(context, 'Your RoadMap')),
              ),
            ],
            selected: {_scope},
            onSelectionChanged: (selection) {
              setState(() {
                _scope = selection.first;
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        if (majors.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                authUser == null
                    ? _roadmapText(context, 'Sign in to see your roadmap.')
                    : _roadmapText(
                        context, 'Set your major in profile to see your roadmap.'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: majors.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.2,
          ),
          itemBuilder: (context, index) {
            final major = majors[index];
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
                _roadmapText(context, major.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  _roadmapText(context, major.description),
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
    final localizedPhases = phases
        .map(
          (phase) => _RoadmapPhase(
            yearLabel: _roadmapText(context, phase.yearLabel),
            title: _roadmapText(context, phase.title),
            timeframe: _roadmapText(context, phase.timeframe),
            actions:
                phase.actions.map((action) => _roadmapText(context, action)).toList(),
          ),
        )
        .toList(growable: false);
    final totalChecklistItems = phases.fold<int>(
          0,
          (sum, phase) => sum + phase.actions.length,
        ) +
        widget.major.subjects.fold<int>(
          0,
          (sum, subject) => sum + subject.topics.length,
        );
    final resources = _buildResourcesForMajor(widget.major.title);
    final localizedResources = resources
        .map(
          (resource) => _RoadmapResource(
            label: _roadmapText(context, resource.label),
            url: resource.url,
          ),
        )
        .toList(growable: false);
    final projects = _buildProjectsForMajor(widget.major.title);
    final localizedProjects =
        projects.map((project) => _roadmapText(context, project)).toList(growable: false);
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
      appBar: AppBar(
        title: Text(strings.majorRoadmap(_roadmapText(context, widget.major.title))),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            strings.roadmapPhases,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...localizedPhases.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.key == 0 ||
                          localizedPhases[entry.key - 1].yearLabel !=
                              entry.value.yearLabel) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            entry.value.yearLabel,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                      _RoadmapPhaseCard(
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
                    ],
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
                    subject: _RoadmapSubject(
                      name: _roadmapText(context, entry.value.name),
                      topics: entry.value.topics
                          .map((topic) => _roadmapText(context, topic))
                          .toList(growable: false),
                    ),
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
              children: localizedResources
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
                      title: Text(
                        resource.label,
                        style: theme.textTheme.bodySmall,
                      ),
                      subtitle: Text(
                        resource.url,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
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
                children: localizedProjects
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

bool _isArabicRoadmap(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';

String _roadmapText(BuildContext context, String englishText) {
  if (!_isArabicRoadmap(context)) return englishText;
  final normalized = _normalizeRoadmapKey(englishText);
  final direct = _roadmapArabicMap[englishText] ?? _roadmapArabicMap[normalized];
  if (direct != null) return direct;
  return _translateDynamicRoadmapSentence(englishText, normalized);
}

String _translateDynamicRoadmapSentence(String englishText, String normalizedKey) {
  final majorArabicEntries = _majorTitleTranslations.entries.toList(growable: false);
  var text = englishText;
  for (final entry in majorArabicEntries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  final normalizedText = _normalizeRoadmapKey(text);

  if (normalizedText.startsWith(
      'Take core intermediate subjects and connect them to ')) {
    final major = normalizedText
        .replaceFirst('Take core intermediate subjects and connect them to ', '')
        .replaceAll('.', '');
    return 'ادرس المقررات المتوسطة الأساسية واربطها بمجال $major.';
  }
  if (normalizedText.startsWith('Use advanced tools and references relevant to ')) {
    final major = normalizedText
        .replaceFirst('Use advanced tools and references relevant to ', '')
        .replaceAll('.', '');
    return 'استخدم أدوات ومراجع متقدمة مرتبطة بمجال $major.';
  }

  return _defaultRoadmapArabicActions[englishText] ??
      _defaultRoadmapArabicActions[normalizedKey] ??
      _defaultRoadmapArabicActions[normalizedText] ??
      text;
}

String _normalizeRoadmapKey(String value) {
  return value
      .trim()
      .replaceFirst(RegExp(r'^[\.\-\u2022\u2023\u25E6\u2043\u2219]+\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

const Map<String, String> _roadmapArabicMap = {
  'All Roadmaps': 'كل المسارات',
  'Your RoadMap': 'مسارك الدراسي',
  'Sign in to see your roadmap.': 'سجّل الدخول لعرض مسارك الدراسي.',
  'Set your major in profile to see your roadmap.':
      'حدّد تخصصك في الملف الشخصي لعرض مسارك الدراسي.',
  'Computer Science': 'علوم الحاسب',
  'Information Technology': 'تقنية المعلومات',
  'Business Administration': 'إدارة الأعمال',
  'Mechanical Engineering': 'الهندسة الميكانيكية',
  'Medicine': 'الطب',
  'Law': 'القانون',
  'Civil Engineering': 'الهندسة المدنية',
  'Electrical Engineering': 'الهندسة الكهربائية',
  'Nursing': 'التمريض',
  'Pharmacy': 'الصيدلة',
  'Architecture': 'الهندسة المعمارية',
  'Psychology': 'علم النفس',
  'Economics': 'الاقتصاد',
  'Graphic Design': 'التصميم الجرافيكي',
  'Software, algorithms, and systems thinking.': 'البرمجيات والخوارزميات وتفكير الأنظمة.',
  'Infrastructure, support, and enterprise tools.': 'البنية التحتية والدعم وأدوات المؤسسات.',
  'Management, strategy, and operations excellence.': 'الإدارة والاستراتيجية وتميّز العمليات.',
  'Design, manufacturing, and physical systems.': 'التصميم والتصنيع والأنظمة الفيزيائية.',
  'Core sciences and clinical competency.': 'العلوم الأساسية والكفاءة السريرية.',
  'Legal reasoning and practical application.': 'الاستدلال القانوني والتطبيق العملي.',
  'Infrastructure design, analysis, and construction.': 'تصميم البنية التحتية وتحليلها وتنفيذها.',
  'Circuits, electronics, and power systems.': 'الدوائر والإلكترونيات وأنظمة الطاقة.',
  'Patient care, safety, and clinical practice.': 'رعاية المرضى والسلامة والممارسة السريرية.',
  'Medicines, therapeutics, and patient counseling.': 'الأدوية والعلاجات والإرشاد الدوائي.',
  'Design thinking, building systems, and urban context.':
      'التفكير التصميمي وأنظمة البناء والسياق الحضري.',
  'Human behavior, cognition, and research methods.':
      'السلوك البشري والإدراك ومناهج البحث.',
  'Markets, policy, and quantitative analysis.': 'الأسواق والسياسات والتحليل الكمي.',
  'Visual communication and digital design skills.':
      'التواصل البصري ومهارات التصميم الرقمي.',
  'Year 1': 'السنة الأولى',
  'Year 2': 'السنة الثانية',
  'Year 3': 'السنة الثالثة',
  'Year 4': 'السنة الرابعة',
  'Semester 1': 'الفصل 1',
  'Semester 2': 'الفصل 2',
  'Semester 3': 'الفصل 3',
  'Semester 4': 'الفصل 4',
  'Semester 5': 'الفصل 5',
  'Semester 6': 'الفصل 6',
  'Semester 7': 'الفصل 7',
  'Semester 8': 'الفصل 8',
  'Semester 1: Orientation & Core Basics': 'الفصل 1: التهيئة والأساسيات',
  'Semester 2: Foundation Completion': 'الفصل 2: استكمال الأساسيات',
  'Semester 3: Intermediate Knowledge': 'الفصل 3: المعارف المتوسطة',
  'Semester 4: Applied Practice': 'الفصل 4: التطبيق العملي',
  'Semester 5: Advanced Core': 'الفصل 5: التخصص المتقدم',
  'Semester 6: Professional Preparation': 'الفصل 6: التأهيل المهني',
  'Semester 7: Capstone & Industry Readiness': 'الفصل 7: مشروع التخرج والاستعداد لسوق العمل',
  'Semester 8: Graduation & Transition': 'الفصل 8: التخرج والانتقال المهني',
  'Coursera Learning Paths': 'مسارات Coursera التعليمية',
  'Khan Academy': 'أكاديمية خان',
  'MIT OpenCourseWare': 'مقررات MIT المفتوحة',
  'Developer Roadmaps': 'خرائط طريق المطورين',
  'CS50 by Harvard': 'دورة CS50 من هارفارد',
  'LeetCode Practice': 'تمارين LeetCode',
  'Cisco Networking Academy': 'أكاديمية سيسكو للشبكات',
  'Microsoft Learn': 'مايكروسوفت ليرن',
  'World Health Organization Learning Hub': 'مركز تعلم منظمة الصحة العالمية',
  'Cornell Legal Information Institute': 'معهد كورنيل للمعلومات القانونية',
  'Harvard Law Library Research Guides': 'أدلة أبحاث مكتبة هارفارد للقانون',
  'Programming Foundations': 'أساسيات البرمجة',
  'Data Structures & Algorithms': 'هياكل البيانات والخوارزميات',
  'Databases': 'قواعد البيانات',
  'Software Engineering': 'هندسة البرمجيات',
  'Data types and control flow': 'أنواع البيانات وتدفق التحكم',
  'OOP principles': 'مبادئ البرمجة كائنية التوجه',
  'Debugging': 'تصحيح الأخطاء',
  'Arrays, linked lists, trees': 'المصفوفات والقوائم المرتبطة والأشجار',
  'Sorting and searching': 'الفرز والبحث',
  'Big-O': 'تعقيد Big-O',
  'SQL basics': 'أساسيات SQL',
  'Database design': 'تصميم قواعد البيانات',
  'Indexing and optimization': 'الفهرسة والتحسين',
  'Git and version control': 'Git وإدارة الإصدارات',
  'Testing fundamentals': 'أساسيات الاختبار',
  'API design': 'تصميم واجهات API',
  'Networking': 'الشبكات',
  'TCP/IP fundamentals': 'أساسيات TCP/IP',
  'Routing and switching': 'التوجيه والتحويل',
  'Network security': 'أمن الشبكات',
  'System Administration': 'إدارة الأنظمة',
  'Linux/Windows admin': 'إدارة لينكس/ويندوز',
  'User and access management': 'إدارة المستخدمين والصلاحيات',
  'Backup plans': 'خطط النسخ الاحتياطي',
  'Cloud Basics': 'أساسيات السحابة',
  'Virtual machines': 'الآلات الافتراضية',
  'Storage services': 'خدمات التخزين',
  'Monitoring and logging': 'المراقبة وتسجيل السجلات',
  'Management': 'الإدارة',
  'Leadership styles': 'أنماط القيادة',
  'Team motivation': 'تحفيز الفريق',
  'Decision making': 'اتخاذ القرار',
  'Finance': 'المالية',
  'Financial statements': 'القوائم المالية',
  'Budgeting': 'إعداد الميزانية',
  'Cost analysis': 'تحليل التكاليف',
  'Marketing': 'التسويق',
  'Market research': 'أبحاث السوق',
  'Brand strategy': 'استراتيجية العلامة التجارية',
  'Digital marketing basics': 'أساسيات التسويق الرقمي',
  'Engineering Mathematics': 'الرياضيات الهندسية',
  'Calculus': 'التفاضل والتكامل',
  'Differential equations': 'المعادلات التفاضلية',
  'Numerical methods': 'الطرق العددية',
  'Mechanics': 'الميكانيكا',
  'Statics': 'الاستاتيكا',
  'Dynamics': 'الديناميكا',
  'Strength of materials': 'مقاومة المواد',
  'Thermal Sciences': 'العلوم الحرارية',
  'Thermodynamics': 'الديناميكا الحرارية',
  'Heat transfer': 'انتقال الحرارة',
  'Fluid mechanics': 'ميكانيكا الموائع',
  'Basic Medical Sciences': 'العلوم الطبية الأساسية',
  'Anatomy': 'التشريح',
  'Physiology': 'وظائف الأعضاء',
  'Biochemistry': 'الكيمياء الحيوية',
  'Pathology & Pharmacology': 'علم الأمراض وعلم الأدوية',
  'Disease mechanisms': 'آليات المرض',
  'Drug classifications': 'تصنيفات الأدوية',
  'Clinical cases': 'حالات سريرية',
  'Clinical Skills': 'المهارات السريرية',
  'History taking': 'أخذ التاريخ المرضي',
  'Physical examination': 'الفحص السريري',
  'Diagnostic reasoning': 'الاستدلال التشخيصي',
  'Legal Foundations': 'الأسس القانونية',
  'Constitutional law': 'القانون الدستوري',
  'Contract law': 'قانون العقود',
  'Criminal law': 'القانون الجنائي',
  'Legal Skills': 'المهارات القانونية',
  'Case analysis': 'تحليل القضايا',
  'Legal writing': 'الكتابة القانونية',
  'Oral advocacy': 'المرافعة الشفوية',
  'Procedures': 'الإجراءات',
  'Civil procedure': 'أصول المرافعات المدنية',
  'Evidence rules': 'قواعد الإثبات',
  'Ethics and professionalism': 'الأخلاقيات والاحترافية',
  'Structural Analysis': 'التحليل الإنشائي',
  'Load calculations': 'حساب الأحمال',
  'Beam design': 'تصميم الجسور',
  'Concrete and steel design': 'تصميم الخرسانة والفولاذ',
  'Geotechnical Engineering': 'الهندسة الجيوتقنية',
  'Soil mechanics': 'ميكانيكا التربة',
  'Foundation design': 'تصميم الأساسات',
  'Site investigation': 'استكشاف الموقع',
  'Construction Management': 'إدارة التشييد',
  'Project planning': 'تخطيط المشاريع',
  'Cost estimation': 'تقدير التكاليف',
  'Quality and safety': 'الجودة والسلامة',
  'Circuit Theory': 'نظرية الدوائر',
  'Ohm and Kirchhoff laws': 'قوانين أوم وكيرشوف',
  'AC/DC analysis': 'تحليل التيار المتردد/المستمر',
  'Network theorems': 'نظريات الشبكات',
  'Electronics': 'الإلكترونيات',
  'Diodes and transistors': 'الثنائيات والترانزستورات',
  'Amplifiers': 'المضخمات',
  'Digital logic basics': 'أساسيات المنطق الرقمي',
  'Power Systems': 'أنظمة القدرة',
  'Generation basics': 'أساسيات التوليد',
  'Transmission and distribution': 'النقل والتوزيع',
  'Protection': 'الحماية',
  'Fundamentals of Nursing': 'أساسيات التمريض',
  'Patient assessment': 'تقييم المريض',
  'Vital signs': 'العلامات الحيوية',
  'Infection control': 'مكافحة العدوى',
  'Medical-Surgical Nursing': 'تمريض الباطنة والجراحة',
  'Adult health conditions': 'الحالات الصحية للبالغين',
  'Care planning': 'تخطيط الرعاية',
  'Medication safety': 'سلامة الأدوية',
  'Community Health': 'الصحة المجتمعية',
  'Health promotion': 'تعزيز الصحة',
  'Preventive care': 'الرعاية الوقائية',
  'Family education': 'تثقيف الأسرة',
  'Pharmacology': 'علم الأدوية',
  'Drug mechanisms': 'آليات عمل الأدوية',
  'Adverse effects': 'الآثار الجانبية',
  'Drug interactions': 'التداخلات الدوائية',
  'Pharmaceutics': 'الصيدلانيات',
  'Dosage forms': 'الأشكال الدوائية',
  'Drug delivery systems': 'أنظمة توصيل الدواء',
  'Stability and storage': 'الثبات والتخزين',
  'Clinical Pharmacy': 'الصيدلة السريرية',
  'Therapeutic guidelines': 'الإرشادات العلاجية',
  'Case-based decisions': 'قرارات مبنية على الحالات',
  'Counseling': 'الإرشاد الدوائي',
  'Design Studio': 'استوديو التصميم',
  'Concept development': 'تطوير المفهوم',
  'Spatial planning': 'التخطيط الفراغي',
  'Presentation boards': 'لوحات العرض',
  'Building Technology': 'تقنيات البناء',
  'Construction materials': 'مواد البناء',
  'Structural systems': 'الأنظمة الإنشائية',
  'Building codes': 'أكواد البناء',
  'Urban & Environmental Studies': 'الدراسات الحضرية والبيئية',
  'Urban design basics': 'أساسيات التصميم الحضري',
  'Sustainability principles': 'مبادئ الاستدامة',
  'Site analysis': 'تحليل الموقع',
  'Core Psychology': 'علم النفس الأساسي',
  'Cognitive psychology': 'علم النفس المعرفي',
  'Developmental psychology': 'علم النفس النمائي',
  'Social psychology': 'علم النفس الاجتماعي',
  'Research Methods': 'مناهج البحث',
  'Experimental design': 'التصميم التجريبي',
  'Data collection': 'جمع البيانات',
  'Ethical guidelines': 'الإرشادات الأخلاقية',
  'Statistics for Psychology': 'الإحصاء لعلم النفس',
  'Descriptive statistics': 'الإحصاء الوصفي',
  'Hypothesis testing': 'اختبار الفرضيات',
  'Interpretation': 'تفسير النتائج',
  'Microeconomics': 'الاقتصاد الجزئي',
  'Supply and demand': 'العرض والطلب',
  'Consumer theory': 'نظرية المستهلك',
  'Market structures': 'هياكل السوق',
  'Macroeconomics': 'الاقتصاد الكلي',
  'GDP and inflation': 'الناتج المحلي والتضخم',
  'Monetary policy': 'السياسة النقدية',
  'Fiscal policy': 'السياسة المالية',
  'Econometrics': 'الاقتصاد القياسي',
  'Regression analysis': 'تحليل الانحدار',
  'Model assumptions': 'افتراضات النموذج',
  'Forecasting basics': 'أساسيات التنبؤ',
  'Design Principles': 'مبادئ التصميم',
  'Typography': 'الطباعة',
  'Color theory': 'نظرية الألوان',
  'Composition and layout': 'التكوين والتخطيط',
  'Digital Tools': 'الأدوات الرقمية',
  'Vector design': 'التصميم المتجهي',
  'Photo editing': 'تحرير الصور',
  'UI mockup basics': 'أساسيات نماذج واجهات المستخدم',
  'Branding & Portfolio': 'الهوية البصرية وملف الأعمال',
  'Identity systems': 'أنظمة الهوية',
  'Visual storytelling': 'السرد البصري',
  'Portfolio development': 'تطوير ملف الأعمال',
};

const Map<String, String> _majorTitleTranslations = {
  'Computer Science': 'علوم الحاسب',
  'Information Technology': 'تقنية المعلومات',
  'Business Administration': 'إدارة الأعمال',
  'Mechanical Engineering': 'الهندسة الميكانيكية',
  'Medicine': 'الطب',
  'Law': 'القانون',
  'Civil Engineering': 'الهندسة المدنية',
  'Electrical Engineering': 'الهندسة الكهربائية',
  'Nursing': 'التمريض',
  'Pharmacy': 'الصيدلة',
  'Architecture': 'الهندسة المعمارية',
  'Psychology': 'علم النفس',
  'Economics': 'الاقتصاد',
  'Graphic Design': 'التصميم الجرافيكي',
};

const Map<String, String> _defaultRoadmapArabicActions = {
  'Build a full-stack app and deploy it publicly.':
      'ابنِ تطبيقًا متكاملًا (Full-Stack) وانشره للعامة.',
  'Implement a data structures visualizer with tests.':
      'نفّذ أداة مرئية لهياكل البيانات مع اختبارات.',
  'Contribute one pull request to an open-source project.':
      'ساهم بطلب دمج واحد في مشروع مفتوح المصدر.',
  'Design a secure small-office network diagram.':
      'صمّم مخطط شبكة آمنة لمكتب صغير.',
  'Set up a Linux server with monitoring and backups.':
      'أعِد خادم لينكس مع المراقبة والنسخ الاحتياطي.',
  'Document an incident-response checklist for common outages.':
      'وثّق قائمة تحقق للاستجابة للحوادث الشائعة.',
  'Create a business model canvas for a local startup idea.':
      'أنشئ نموذج عمل تجاري لفكرة شركة ناشئة محلية.',
  'Run a simple market survey and present insights.':
      'نفّذ استطلاع سوق بسيطًا واعرض النتائج.',
  'Build a financial forecast sheet for one semester.':
      'أنشئ جدول توقعات مالية لفصل دراسي واحد.',
  'Model and simulate a mechanical component in CAD.':
      'نمذج وحاكِ مكوّنًا ميكانيكيًا باستخدام CAD.',
  'Build a mini prototype and measure performance changes.':
      'ابنِ نموذجًا أوليًا صغيرًا وقِس تغيّرات الأداء.',
  'Write a short technical report with design trade-offs.':
      'اكتب تقريرًا فنيًا قصيرًا يوضح مفاضلات التصميم.',
  'Prepare a clinical case presentation with differential diagnosis.':
      'حضّر عرض حالة سريرية مع التشخيص التفريقي.',
  'Create flashcards for high-yield pharmacology facts.':
      'أنشئ بطاقات مراجعة لحقائق دوائية عالية الأهمية.',
  'Run mock OSCE-style practice with peers weekly.':
      'نفّذ تدريبًا أسبوعيًا بنمط OSCE مع الزملاء.',
  'Write a case brief for a landmark judgment.':
      'اكتب ملخص قضية لحكم قضائي بارز.',
  'Draft a legal memo on a current policy issue.':
      'صِغ مذكرة قانونية حول قضية سياسات معاصرة.',
  'Practice oral argument for a mock hearing.':
      'تدرّب على المرافعة الشفوية لجلسة صورية.',
  'Draft a structural concept for a small public facility.':
      'صِغ تصورًا إنشائيًا لمرفق عام صغير.',
  'Perform basic site and soil analysis for a case study.':
      'أجرِ تحليلًا أساسيًا للموقع والتربة لدراسة حالة.',
  'Build a project timeline with cost estimation basics.':
      'ابنِ جدولًا زمنيًا للمشروع مع أساسيات تقدير التكلفة.',
  'Build and test an amplifier or filter circuit.':
      'ابنِ واختبر دائرة مضخم أو مرشح.',
  'Simulate a power distribution scenario in software.':
      'حاكِ سيناريو توزيع طاقة باستخدام البرمجيات.',
  'Document lab results and error analysis clearly.':
      'وثّق نتائج المختبر وتحليل الأخطاء بوضوح.',
  'Create a patient education plan for a chronic condition.':
      'أنشئ خطة تثقيف للمريض لحالة مزمنة.',
  'Practice care-plan documentation from sample scenarios.':
      'تدرّب على توثيق خطط الرعاية من سيناريوهات نموذجية.',
  'Run medication safety checklists during simulation drills.':
      'نفّذ قوائم تحقق سلامة الأدوية أثناء تدريبات المحاكاة.',
  'Analyze a prescription for interactions and contraindications.':
      'حلّل وصفة دوائية للتداخلات وموانع الاستعمال.',
  'Create a counseling script for a common medication class.':
      'أنشئ نصًا إرشاديًا لفئة دوائية شائعة.',
  'Prepare a therapeutic comparison chart for similar drugs.':
      'حضّر جدول مقارنة علاجية لأدوية متشابهة.',
  'Build a studio portfolio page for your best project.':
      'أنشئ صفحة ملف أعمال لأفضل مشروع لديك.',
  'Develop a site analysis board with climate response.':
      'طوّر لوحة تحليل موقع تتضمن الاستجابة المناخية.',
  'Produce a concept-to-detail design narrative.':
      'قدّم سردًا تصميميًا من الفكرة حتى التفاصيل.',
  'Design a small survey study and analyze findings.':
      'صمّم دراسة مسحية صغيرة وحلّل نتائجها.',
  'Write a literature review on one behavior topic.':
      'اكتب مراجعة أدبية حول موضوع سلوكي واحد.',
  'Present a poster summarizing methods and limitations.':
      'قدّم ملصقًا يلخص المنهجية والقيود.',
  'Replicate one published econometrics analysis in a notebook.':
      'أعد تنفيذ تحليل اقتصاد قياسي منشور داخل دفتر عملي.',
  'Track macro indicators and explain trends monthly.':
      'تابع المؤشرات الكلية واشرح الاتجاهات شهريًا.',
  'Build a policy brief with data-backed recommendations.':
      'أعِد موجز سياسات بتوصيات مدعومة بالبيانات.',
  'Create a full brand identity kit for a mock client.':
      'أنشئ حزمة هوية بصرية كاملة لعميل افتراضي.',
  'Redesign a mobile app onboarding flow.':
      'أعد تصميم تدفق التهيئة الأولية لتطبيق جوال.',
  'Publish a portfolio case study with before/after rationale.':
      'انشر دراسة حالة في ملف الأعمال مع تبرير قبل/بعد.',
  'Build one practical artifact related to your major.':
      'ابنِ منتجًا عمليًا واحدًا مرتبطًا بتخصصك.',
  'Collect feedback from a mentor and improve iteration 2.':
      'اجمع ملاحظات من مرشد وطوّر النسخة الثانية.',
  'Present outcomes in a portfolio-ready format.':
      'اعرض النتائج بصيغة جاهزة لملف الأعمال.',
  'Start programming fundamentals with Python or Java.':
      'ابدأ بأساسيات البرمجة باستخدام بايثون أو جافا.',
  'Build weekly practice in logic, math, and problem solving.':
      'خصّص تدريبًا أسبوعيًا للمنطق والرياضيات وحل المشكلات.',
  'Set up Git and document your learning notes.':
      'قم بإعداد Git ووثّق ملاحظات تعلمك.',
  'Study data structures basics and algorithmic thinking.':
      'ادرس أساسيات هياكل البيانات والتفكير الخوارزمي.',
  'Practice SQL and database modeling in small tasks.':
      'تدرّب على SQL ونمذجة قواعد البيانات في مهام صغيرة.',
  'Complete a mini console app with version control.':
      'أنجز تطبيقًا بسيطًا عبر سطر الأوامر مع التحكم بالإصدارات.',
  'Learn OOP deeply and write reusable, tested code.':
      'تعمّق في البرمجة كائنية التوجه واكتب كودًا قابلًا لإعادة الاستخدام ومختبرًا.',
  'Build web fundamentals: HTTP, APIs, and frontend basics.':
      'ابنِ أساسيات الويب: HTTP وواجهات API وأساسيات الواجهة الأمامية.',
  'Solve timed coding challenges each week.':
      'حلّ تحديات برمجية موقّتة كل أسبوع.',
  'Create a full CRUD web app with authentication.':
      'أنشئ تطبيق ويب CRUD متكاملًا مع المصادقة.',
  'Apply testing and debugging workflows in projects.':
      'طبّق أساليب الاختبار وتصحيح الأخطاء في المشاريع.',
  'Collaborate on a team repo using branches and PR flow.':
      'تعاون في مستودع جماعي باستخدام الفروع وتدفق طلبات الدمج.',
  'Choose a path: mobile, web, data, or systems.':
      'اختر مسارًا: تطبيقات الجوال أو الويب أو البيانات أو الأنظمة.',
  'Study operating systems and networking concepts.':
      'ادرس مفاهيم أنظمة التشغيل والشبكات.',
  'Build one larger app with clean architecture principles.':
      'ابنِ تطبيقًا أكبر باستخدام مبادئ الهندسة النظيفة.',
  'Design scalable backend patterns and API contracts.':
      'صمّم أنماط خلفية قابلة للتوسع وعقود API واضحة.',
  'Prepare interview-style algorithm practice consistently.':
      'داوم على تدريب الخوارزميات بأسلوب مقابلات التوظيف.',
  'Ship one portfolio project with deployment and docs.':
      'أنهِ مشروعًا لملف الأعمال مع النشر والتوثيق.',
  'Define and build your capstone with measurable milestones.':
      'حدّد ونفّذ مشروع التخرج بمعالم قابلة للقياس.',
  'Integrate security, performance, and observability basics.':
      'ادمج أساسيات الأمان والأداء وقابلية المراقبة.',
  'Present technical decisions with trade-off reasoning.':
      'اعرض القرارات التقنية مع توضيح المفاضلات.',
  'Finalize capstone and publish a polished portfolio.':
      'أنهِ مشروع التخرج وانشر ملف أعمال احترافيًا.',
  'Revise core CS topics for interviews and exams.':
      'راجع مواضيع علوم الحاسب الأساسية للمقابلات والاختبارات.',
  'Prepare for internships/jobs with CV and mock interviews.':
      'استعد للتدريب والوظائف عبر السيرة الذاتية والمقابلات التجريبية.',
  'Build core knowledge in computer hardware and OS basics.':
      'ابنِ معرفة أساسية بعتاد الحاسوب ومبادئ أنظمة التشغيل.',
  'Learn networking fundamentals and IP addressing.':
      'تعلّم أساسيات الشبكات وعنونة IP.',
  'Develop structured troubleshooting habits.':
      'طوّر عادات منهجية لحل المشكلات التقنية.',
  'Practice Linux and Windows administration workflows.':
      'تدرّب على إجراءات إدارة لينكس وويندوز.',
  'Set up users, permissions, and basic system policies.':
      'أعدّ المستخدمين والصلاحيات وسياسات النظام الأساسية.',
  'Document support tickets and incident notes clearly.':
      'وثّق تذاكر الدعم وملاحظات الحوادث بوضوح.',
  'Study routing, switching, and VLAN implementation basics.':
      'ادرس أساسيات التوجيه والتحويل وتنفيذ VLAN.',
  'Apply cybersecurity hygiene: patching, backups, and MFA.':
      'طبّق ممارسات الأمن السيبراني الأساسية: التحديثات والنسخ الاحتياطي والمصادقة متعددة العوامل.',
  'Practice helpdesk scenarios with SLA awareness.':
      'تدرّب على سيناريوهات مكتب الدعم مع فهم اتفاقيات مستوى الخدمة.',
  'Build a small office network simulation end-to-end.':
      'ابنِ محاكاة متكاملة لشبكة مكتب صغير.',
  'Configure monitoring, alerts, and log collection.':
      'اضبط المراقبة والتنبيهات وجمع السجلات.',
  'Run disaster recovery drills for common failures.':
      'نفّذ تدريبات التعافي من الكوارث للأعطال الشائعة.',
  'Learn cloud services: compute, storage, and IAM.':
      'تعلّم خدمات السحابة: الحوسبة والتخزين وإدارة الهوية والصلاحيات.',
  'Automate repetitive admin tasks with scripting.':
      'أتمت المهام الإدارية المتكررة باستخدام السكربتات.',
  'Harden services using baseline security checklists.':
      'عزّز الخدمات باستخدام قوائم التحقق الأمنية الأساسية.',
  'Prepare for entry certifications and practical labs.':
      'استعد للشهادات التأسيسية والمختبرات العملية.',
  'Support multi-service environments with change control.':
      'ادعم بيئات متعددة الخدمات مع ضبط إدارة التغيير.',
  'Build a portfolio of diagrams, runbooks, and case logs.':
      'ابنِ ملف أعمال يضم مخططات وأدلة تشغيل وسجلات حالات.',
  'Lead an infrastructure improvement capstone project.':
      'قد مشروع تخرج لتحسين البنية التحتية.',
  'Evaluate reliability, cost, and security trade-offs.':
      'قيّم المفاضلات بين الاعتمادية والتكلفة والأمان.',
  'Present architecture and incident response plans.':
      'اعرض خطط المعمارية والاستجابة للحوادث.',
  'Finalize capstone and transition documents.':
      'أنهِ مشروع التخرج ووثائق التسليم والانتقال.',
  'Review networking, systems, and cloud priorities.':
      'راجع أولويات الشبكات والأنظمة والسحابة.',
  'Prepare for SOC, support, or sysadmin interviews.':
      'استعد لمقابلات مركز العمليات الأمنية أو الدعم أو إدارة الأنظمة.',
  'Master anatomy, physiology, and medical terminology.':
      'أتقن التشريح ووظائف الأعضاء والمصطلحات الطبية.',
  'Use spaced repetition for high-yield foundational facts.':
      'استخدم التكرار المتباعد لحفظ الحقائق الأساسية عالية الأهمية.',
  'Build discipline with daily concept review blocks.':
      'ابنِ الانضباط عبر جلسات يومية لمراجعة المفاهيم.',
  'Strengthen biochemistry, histology, and pathology basics.':
      'عزّز أساسيات الكيمياء الحيوية وعلم الأنسجة وعلم الأمراض.',
  'Practice short clinical reasoning from simple cases.':
      'تدرّب على الاستدلال السريري القصير من حالات بسيطة.',
  'Develop concise, exam-ready summary sheets.':
      'أعد ملخصات مختصرة وجاهزة للاختبارات.',
  'Study organ-system pathology with pharmacology links.':
      'ادرس أمراض أجهزة الجسم مع الربط بعلم الأدوية.',
  'Practice case-based discussion with peers weekly.':
      'تدرّب أسبوعيًا على مناقشات مبنية على الحالات مع الزملاء.',
  'Improve differential diagnosis reasoning structure.':
      'حسّن منهجية التفكير في التشخيص التفريقي.',
  'Begin structured clinical skills and patient communication.':
      'ابدأ تنمية المهارات السريرية المنظمة والتواصل مع المرضى.',
  'Perform history-taking and focused exams in simulations.':
      'أجرِ أخذ التاريخ المرضي والفحوصات المركزة في المحاكاة.',
  'Track weak systems and close knowledge gaps early.':
      'تابع الأجهزة الضعيفة وأغلق فجوات المعرفة مبكرًا.',
  'Rotate through core disciplines and log learning outcomes.':
      'تدرّب في التخصصات الأساسية وسجّل مخرجات التعلم.',
  'Correlate lab findings with diagnostic hypotheses.':
      'اربط نتائج المختبر بفرضيات التشخيص.',
  'Practice OSCE stations under timed conditions.':
      'تدرّب على محطات OSCE ضمن وقت محدد.',
  'Deepen emergency, internal medicine, and surgery readiness.':
      'عمّق الاستعداد للطوارئ والباطنة والجراحة.',
  'Apply evidence-based medicine using guideline resources.':
      'طبّق الطب المبني على الدليل باستخدام المراجع الإرشادية.',
  'Write clear clinical notes and management plans.':
      'اكتب ملاحظات سريرية وخطط علاج واضحة.',
  'Lead advanced case presentations with rationale.':
      'قدّم عروض حالات متقدمة مع التبرير العلمي.',
  'Prepare licensing-style question practice consistently.':
      'داوم على التدريب على أسئلة نمط الاختبارات المهنية.',
  'Refine communication, ethics, and teamwork behaviors.':
      'طوّر مهارات التواصل والأخلاقيات والعمل الجماعي.',
  'Consolidate all systems with final integrated revision.':
      'وحّد مراجعة جميع الأجهزة بمراجعة نهائية متكاملة.',
  'Complete clinical portfolio and competency records.':
      'أكمل ملفك السريري وسجلات الكفاءات.',
  'Prepare internship transition with practical protocols.':
      'استعد للامتياز عبر بروتوكولات عملية واضحة.',
  'Build legal reading habits and case briefing basics.':
      'ابنِ عادات قراءة قانونية وأساسيات تلخيص القضايا.',
  'Study constitutional and contract law foundations.':
      'ادرس أساسيات القانون الدستوري وقانون العقود.',
  'Practice legal writing structure and citation style.':
      'تدرّب على هيكلة الكتابة القانونية وأسلوب الاستشهاد.',
  'Expand to criminal and tort law core principles.':
      'وسّع دراستك إلى المبادئ الأساسية للقانون الجنائي وقانون المسؤولية التقصيرية.',
  'Develop issue-spotting through weekly hypotheticals.':
      'طوّر مهارة تحديد الإشكالات القانونية عبر مسائل افتراضية أسبوعية.',
  'Start oral argument drills in small study groups.':
      'ابدأ تمارين المرافعة الشفوية ضمن مجموعات دراسة صغيرة.',
  'Study civil procedure and evidence frameworks deeply.':
      'ادرس أصول المرافعات المدنية وقواعد الإثبات بعمق.',
  'Write short legal memos using precedent analysis.':
      'اكتب مذكرات قانونية قصيرة باستخدام تحليل السوابق.',
  'Improve statute interpretation and argument clarity.':
      'حسّن تفسير النصوص القانونية ووضوح الحجج.',
  'Practice moot court style submissions and rebuttals.':
      'تدرّب على مذكرات ومرافعات المحاكم الصورية والردود.',
  'Build research speed across legal databases.':
      'ارفع سرعة البحث في قواعد البيانات القانونية.',
  'Track doctrine gaps and revise using past assessments.':
      'تابع فجوات المبادئ القانونية وراجع باستخدام تقييمات سابقة.',
  'Choose focus tracks such as corporate, public, or criminal.':
      'اختر مسارات تركيز مثل القانون التجاري أو العام أو الجنائي.',
  'Draft longer opinion pieces with legal authority support.':
      'اكتب آراء قانونية مطوّلة مدعومة بالمرجعيات.',
  'Strengthen ethics and professional responsibility practice.':
      'عزّز الممارسة الأخلاقية والمسؤولية المهنية.',
  'Handle clinic or internship tasks with supervision.':
      'أنجز مهام العيادة القانونية أو التدريب تحت إشراف.',
  'Prepare practical drafting: contracts, pleadings, and notices.':
      'استعد للصياغة العملية: العقود واللوائح والإشعارات.',
  'Present legal strategy with clear risk assessment.':
      'اعرض الاستراتيجية القانونية مع تقييم واضح للمخاطر.',
  'Develop capstone-level legal research or policy project.':
      'طوّر مشروع بحث قانوني أو سياسات بمستوى مشروع تخرج.',
  'Integrate comparative law and real-case reasoning.':
      'ادمج القانون المقارن والاستدلال من القضايا الواقعية.',
  'Refine advocacy style for hearings and interviews.':
      'صقل أسلوب المرافعة للجلسات والمقابلات.',
  'Finalize legal portfolio with briefs and writing samples.':
      'أنهِ ملفك القانوني بمذكرات ونماذج كتابية.',
  'Review core doctrines and procedural rules comprehensively.':
      'راجع المبادئ الأساسية والقواعد الإجرائية بشكل شامل.',
  'Prepare bar-track or trainee application readiness.':
      'استعد لمسار التأهيل المهني أو طلبات التدريب القانوني.',
  'Review your study plan and map core courses to weekly milestones.':
      'راجع خطة دراستك واربط المقررات الأساسية بأهداف أسبوعية واضحة.',
  'Build study habits: active recall, short notes, and weekly revision.':
      'ابنِ عادات دراسة فعّالة: الاسترجاع النشط، ملاحظات مختصرة، ومراجعة أسبوعية.',
  'Strengthen communication, math, and digital literacy foundations.':
      'عزّز أساسيات التواصل والرياضيات والمهارات الرقمية.',
  'Deepen understanding of introductory courses with regular practice.':
      'عمّق فهم المقررات التمهيدية من خلال التدريب المنتظم.',
  'Start solving timed assignments and past exams every week.':
      'ابدأ بحل واجبات واختبارات سابقة بوقت محدد كل أسبوع.',
  'Create a gap list and close weak areas before Year 2.':
      'أنشئ قائمة بالفجوات المعرفية وعالج نقاط الضعف قبل السنة الثانية.',
  'Use project-based learning to apply theories in practical tasks.':
      'استخدم التعلم القائم على المشاريع لتطبيق النظريات في مهام عملية.',
  'Start building a portfolio folder for reports and assignments.':
      'ابدأ ببناء ملف أعمال يجمع التقارير والواجبات.',
  'Complete one team task to improve collaboration and planning.':
      'أنجز مهمة جماعية واحدة لتحسين التعاون والتخطيط.',
  'Practice presentations and defend your ideas with clear evidence.':
      'تدرّب على العروض وادعم أفكارك بأدلة واضحة.',
  'Track performance trends and improve consistency before Year 3.':
      'تابع اتجاهات الأداء وحسّن الاستمرارية قبل السنة الثالثة.',
  'Focus on advanced subjects and higher-level problem solving.':
      'ركّز على المواد المتقدمة وحل المشكلات بمستوى أعلى.',
  'Follow one specialization direction aligned with career interests.':
      'اتبع مسار تخصص يتوافق مع اهتماماتك المهنية.',
  'Take feedback from instructors and refine your academic approach.':
      'استفد من ملاحظات المدرسين وطوّر منهجك الأكاديمي.',
  'Work on major projects with realistic requirements and deadlines.':
      'اعمل على مشاريع رئيسية بمتطلبات ومواعيد نهائية واقعية.',
  'Improve professional skills: writing, documentation, and teamwork.':
      'طوّر المهارات المهنية: الكتابة، التوثيق، والعمل الجماعي.',
  'Prepare internship-ready CV, portfolio, and interview basics.':
      'جهّز سيرة ذاتية وملف أعمال مناسبين للتدريب، مع أساسيات المقابلات.',
  'Start capstone planning and define measurable project outcomes.':
      'ابدأ التخطيط لمشروع التخرج وحدد نتائج قابلة للقياس.',
  'Build professional network through mentors, events, and communities.':
      'ابنِ شبكة مهنية عبر المرشدين والفعاليات والمجتمعات.',
  'Complete final project delivery with strong documentation.':
      'أكمل تسليم المشروع النهائي مع توثيق قوي.',
  'Review all priority topics and close remaining knowledge gaps.':
      'راجع جميع المواضيع ذات الأولوية وأغلق الفجوات المعرفية المتبقية.',
  'Finalize job or postgraduate plan with a clear 6-month roadmap.':
      'أنهِ خطة العمل أو الدراسات العليا مع خارطة طريق واضحة لستة أشهر.',
};

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
    required this.yearLabel,
    required this.title,
    required this.timeframe,
    required this.actions,
  });

  final String yearLabel;
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
  List<_RoadmapPhase> buildSemesters({
    required List<String> s1,
    required List<String> s2,
    required List<String> s3,
    required List<String> s4,
    required List<String> s5,
    required List<String> s6,
    required List<String> s7,
    required List<String> s8,
  }) {
    return [
      _RoadmapPhase(
        yearLabel: 'Year 1',
        title: 'Semester 1: Orientation & Core Basics',
        timeframe: 'Semester 1',
        actions: s1,
      ),
      _RoadmapPhase(
        yearLabel: 'Year 1',
        title: 'Semester 2: Foundation Completion',
        timeframe: 'Semester 2',
        actions: s2,
      ),
      _RoadmapPhase(
        yearLabel: 'Year 2',
        title: 'Semester 3: Intermediate Knowledge',
        timeframe: 'Semester 3',
        actions: s3,
      ),
      _RoadmapPhase(
        yearLabel: 'Year 2',
        title: 'Semester 4: Applied Practice',
        timeframe: 'Semester 4',
        actions: s4,
      ),
      _RoadmapPhase(
        yearLabel: 'Year 3',
        title: 'Semester 5: Advanced Core',
        timeframe: 'Semester 5',
        actions: s5,
      ),
      _RoadmapPhase(
        yearLabel: 'Year 3',
        title: 'Semester 6: Professional Preparation',
        timeframe: 'Semester 6',
        actions: s6,
      ),
      _RoadmapPhase(
        yearLabel: 'Year 4',
        title: 'Semester 7: Capstone & Industry Readiness',
        timeframe: 'Semester 7',
        actions: s7,
      ),
      _RoadmapPhase(
        yearLabel: 'Year 4',
        title: 'Semester 8: Graduation & Transition',
        timeframe: 'Semester 8',
        actions: s8,
      ),
    ];
  }

  switch (majorTitle) {
    case 'Computer Science':
      return buildSemesters(
        s1: [
          'Start programming fundamentals with Python or Java.',
          'Build weekly practice in logic, math, and problem solving.',
          'Set up Git and document your learning notes.',
        ],
        s2: [
          'Study data structures basics and algorithmic thinking.',
          'Practice SQL and database modeling in small tasks.',
          'Complete a mini console app with version control.',
        ],
        s3: [
          'Learn OOP deeply and write reusable, tested code.',
          'Build web fundamentals: HTTP, APIs, and frontend basics.',
          'Solve timed coding challenges each week.',
        ],
        s4: [
          'Create a full CRUD web app with authentication.',
          'Apply testing and debugging workflows in projects.',
          'Collaborate on a team repo using branches and PR flow.',
        ],
        s5: [
          'Choose a path: mobile, web, data, or systems.',
          'Study operating systems and networking concepts.',
          'Build one larger app with clean architecture principles.',
        ],
        s6: [
          'Design scalable backend patterns and API contracts.',
          'Prepare interview-style algorithm practice consistently.',
          'Ship one portfolio project with deployment and docs.',
        ],
        s7: [
          'Define and build your capstone with measurable milestones.',
          'Integrate security, performance, and observability basics.',
          'Present technical decisions with trade-off reasoning.',
        ],
        s8: [
          'Finalize capstone and publish a polished portfolio.',
          'Revise core CS topics for interviews and exams.',
          'Prepare for internships/jobs with CV and mock interviews.',
        ],
      );
    case 'Information Technology':
      return buildSemesters(
        s1: [
          'Build core knowledge in computer hardware and OS basics.',
          'Learn networking fundamentals and IP addressing.',
          'Develop structured troubleshooting habits.',
        ],
        s2: [
          'Practice Linux and Windows administration workflows.',
          'Set up users, permissions, and basic system policies.',
          'Document support tickets and incident notes clearly.',
        ],
        s3: [
          'Study routing, switching, and VLAN implementation basics.',
          'Apply cybersecurity hygiene: patching, backups, and MFA.',
          'Practice helpdesk scenarios with SLA awareness.',
        ],
        s4: [
          'Build a small office network simulation end-to-end.',
          'Configure monitoring, alerts, and log collection.',
          'Run disaster recovery drills for common failures.',
        ],
        s5: [
          'Learn cloud services: compute, storage, and IAM.',
          'Automate repetitive admin tasks with scripting.',
          'Harden services using baseline security checklists.',
        ],
        s6: [
          'Prepare for entry certifications and practical labs.',
          'Support multi-service environments with change control.',
          'Build a portfolio of diagrams, runbooks, and case logs.',
        ],
        s7: [
          'Lead an infrastructure improvement capstone project.',
          'Evaluate reliability, cost, and security trade-offs.',
          'Present architecture and incident response plans.',
        ],
        s8: [
          'Finalize capstone and transition documents.',
          'Review networking, systems, and cloud priorities.',
          'Prepare for SOC, support, or sysadmin interviews.',
        ],
      );
    case 'Medicine':
      return buildSemesters(
        s1: [
          'Master anatomy, physiology, and medical terminology.',
          'Use spaced repetition for high-yield foundational facts.',
          'Build discipline with daily concept review blocks.',
        ],
        s2: [
          'Strengthen biochemistry, histology, and pathology basics.',
          'Practice short clinical reasoning from simple cases.',
          'Develop concise, exam-ready summary sheets.',
        ],
        s3: [
          'Study organ-system pathology with pharmacology links.',
          'Practice case-based discussion with peers weekly.',
          'Improve differential diagnosis reasoning structure.',
        ],
        s4: [
          'Begin structured clinical skills and patient communication.',
          'Perform history-taking and focused exams in simulations.',
          'Track weak systems and close knowledge gaps early.',
        ],
        s5: [
          'Rotate through core disciplines and log learning outcomes.',
          'Correlate lab findings with diagnostic hypotheses.',
          'Practice OSCE stations under timed conditions.',
        ],
        s6: [
          'Deepen emergency, internal medicine, and surgery readiness.',
          'Apply evidence-based medicine using guideline resources.',
          'Write clear clinical notes and management plans.',
        ],
        s7: [
          'Lead advanced case presentations with rationale.',
          'Prepare licensing-style question practice consistently.',
          'Refine communication, ethics, and teamwork behaviors.',
        ],
        s8: [
          'Consolidate all systems with final integrated revision.',
          'Complete clinical portfolio and competency records.',
          'Prepare internship transition with practical protocols.',
        ],
      );
    case 'Law':
      return buildSemesters(
        s1: [
          'Build legal reading habits and case briefing basics.',
          'Study constitutional and contract law foundations.',
          'Practice legal writing structure and citation style.',
        ],
        s2: [
          'Expand to criminal and tort law core principles.',
          'Develop issue-spotting through weekly hypotheticals.',
          'Start oral argument drills in small study groups.',
        ],
        s3: [
          'Study civil procedure and evidence frameworks deeply.',
          'Write short legal memos using precedent analysis.',
          'Improve statute interpretation and argument clarity.',
        ],
        s4: [
          'Practice moot court style submissions and rebuttals.',
          'Build research speed across legal databases.',
          'Track doctrine gaps and revise using past assessments.',
        ],
        s5: [
          'Choose focus tracks such as corporate, public, or criminal.',
          'Draft longer opinion pieces with legal authority support.',
          'Strengthen ethics and professional responsibility practice.',
        ],
        s6: [
          'Handle clinic or internship tasks with supervision.',
          'Prepare practical drafting: contracts, pleadings, and notices.',
          'Present legal strategy with clear risk assessment.',
        ],
        s7: [
          'Develop capstone-level legal research or policy project.',
          'Integrate comparative law and real-case reasoning.',
          'Refine advocacy style for hearings and interviews.',
        ],
        s8: [
          'Finalize legal portfolio with briefs and writing samples.',
          'Review core doctrines and procedural rules comprehensively.',
          'Prepare bar-track or trainee application readiness.',
        ],
      );
    default:
      return buildSemesters(
        s1: [
          'Review your study plan and map core courses to weekly milestones.',
          'Build study habits: active recall, short notes, and weekly revision.',
          'Strengthen communication, math, and digital literacy foundations.',
        ],
        s2: [
          'Deepen understanding of introductory courses with regular practice.',
          'Start solving timed assignments and past exams every week.',
          'Create a gap list and close weak areas before Year 2.',
        ],
        s3: [
          'Take core intermediate subjects and connect them to $majorTitle.',
          'Use project-based learning to apply theories in practical tasks.',
          'Start building a portfolio folder for reports and assignments.',
        ],
        s4: [
          'Complete one team task to improve collaboration and planning.',
          'Practice presentations and defend your ideas with clear evidence.',
          'Track performance trends and improve consistency before Year 3.',
        ],
        s5: [
          'Focus on advanced subjects and higher-level problem solving.',
          'Follow one specialization direction aligned with career interests.',
          'Take feedback from instructors and refine your academic approach.',
        ],
        s6: [
          'Work on major projects with realistic requirements and deadlines.',
          'Improve professional skills: writing, documentation, and teamwork.',
          'Prepare internship-ready CV, portfolio, and interview basics.',
        ],
        s7: [
          'Start capstone planning and define measurable project outcomes.',
          'Use advanced tools and references relevant to $majorTitle.',
          'Build professional network through mentors, events, and communities.',
        ],
        s8: [
          'Complete final project delivery with strong documentation.',
          'Review all priority topics and close remaining knowledge gaps.',
          'Finalize job or postgraduate plan with a clear 6-month roadmap.',
        ],
      );
  }
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
