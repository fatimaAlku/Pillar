import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/state/app_providers.dart';
import 'subject_detail_screen.dart';

class SubjectsManageScreen extends ConsumerWidget {
  const SubjectsManageScreen({super.key});

  Future<void> _showAddSubjectDialog(
    BuildContext context,
    WidgetRef ref,
    String uid,
  ) async {
    final strings = AppStrings.of(context);
    final nameController = TextEditingController();
    DateTime? examDate;
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setLocal) {
              final locale = Localizations.localeOf(context).languageCode;
              String examLabel() {
                if (examDate == null) return strings.examDateOptional;
                return DateFormat.yMMMd(locale).format(examDate!);
              }

              return AlertDialog(
                title: Text(strings.addCourse),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: strings.courseName,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: examDate ?? DateTime.now(),
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 365)),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 4)),
                          );
                          if (picked != null) {
                            setLocal(() => examDate = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                ));
                          }
                        },
                        icon:
                            const Icon(Icons.calendar_today_outlined, size: 18),
                        label: Text(examLabel()),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(strings.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(strings.save),
                  ),
                ],
              );
            },
          );
        },
      );

      if (saved != true || !context.mounted) return;
      final name = nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.courseNameRequired)),
        );
        return;
      }
      final examIso = examDate == null
          ? ''
          : DateTime(
              examDate!.year,
              examDate!.month,
              examDate!.day,
            ).toIso8601String();
      try {
        await ref.read(subjectsRepositoryProvider).createSubject(
              uid: uid,
              name: name,
              examDateIso: examIso,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.courseSaved)),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.couldNotSaveCourse)),
          );
        }
      }
    } finally {
      nameController.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final authAsync = ref.watch(currentAuthUserProvider);

    return authAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(strings.myCourses)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(strings.myCourses)),
        body: Center(child: Text('$e')),
      ),
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: Text(strings.myCourses)),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                strings.signInToManageCourses,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          );
        }

        final subjectsAsync = ref.watch(subjectsStreamProvider(user.uid));

        return Scaffold(
          appBar: AppBar(
            title: Text(strings.myCourses),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddSubjectDialog(context, ref, user.uid),
            icon: const Icon(Icons.add),
            label: Text(strings.addCourse),
          ),
          body: subjectsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (subjects) {
              if (subjects.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 56,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings.coursesEmptyHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: subjects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final s = subjects[i];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.8),
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        s.name.isEmpty ? strings.unnamedCourse : s.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: () {
                        if (s.examDateIso.isEmpty) return null;
                        final parsed = DateTime.tryParse(s.examDateIso);
                        if (parsed == null) return null;
                        final locale =
                            Localizations.localeOf(context).languageCode;
                        return Text(
                          strings.examDateLabel(
                            DateFormat.yMMMd(locale).format(parsed),
                          ),
                        );
                      }(),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => SubjectDetailScreen(
                              uid: user.uid,
                              subject: s,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
