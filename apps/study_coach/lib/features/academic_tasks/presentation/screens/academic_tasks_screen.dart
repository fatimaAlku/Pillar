import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_time_zone.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/state/app_providers.dart';
import '../../../subjects/domain/entities/subject.dart';
import '../../domain/entities/academic_task.dart';

class AcademicTasksScreen extends ConsumerWidget {
  const AcademicTasksScreen({super.key});

  DateTime? _parseDate(String iso) {
    if (iso.trim().isEmpty) return null;
    return DateTime.tryParse(iso);
  }

  String _toDateIso(DateTime date) {
    return DateTime(date.year, date.month, date.day).toIso8601String();
  }

  String _formatDueDate(
    BuildContext context,
    AppStrings strings,
    DateTime? dueDate,
  ) {
    if (dueDate == null) return strings.academicTaskDueDate;
    final dateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final today = appTodayDateOnly();
    final days = dateOnly.difference(today).inDays;
    final formatted = DateFormat.yMMMd(
      Localizations.localeOf(context).languageCode,
    ).format(dateOnly);
    if (days == 0) return strings.academicTaskDueToday(formatted);
    if (days == 1) return strings.academicTaskDueTomorrow(formatted);
    if (days > 1) return strings.academicTaskDueInDays(days, formatted);
    return strings.academicTaskOverdue(days.abs(), formatted);
  }

  IconData _iconForType(AcademicTaskType type) {
    switch (type) {
      case AcademicTaskType.homework:
        return Icons.assignment_outlined;
      case AcademicTaskType.project:
        return Icons.account_tree_outlined;
      case AcademicTaskType.quiz:
        return Icons.quiz_outlined;
      case AcademicTaskType.lab:
        return Icons.science_outlined;
      case AcademicTaskType.presentation:
        return Icons.co_present_outlined;
      case AcademicTaskType.reading:
        return Icons.menu_book_outlined;
      case AcademicTaskType.exam:
        return Icons.school_outlined;
      case AcademicTaskType.semesterDeadline:
        return Icons.event_outlined;
      case AcademicTaskType.other:
        return Icons.task_alt_outlined;
    }
  }

  Future<void> _showTaskDialog(
    BuildContext context,
    WidgetRef ref,
    String uid,
    List<Subject> subjects, {
    AcademicTask? task,
  }) async {
    final strings = AppStrings.of(context);
    final titleController = TextEditingController(text: task?.title ?? '');
    var type = task?.type ?? AcademicTaskType.homework;
    final initialSubjectId = task?.subjectId ?? '';
    var subjectId = subjects.any((subject) => subject.id == initialSubjectId)
        ? initialSubjectId
        : '';
    var dueDate = _parseDate(task?.dueDateIso ?? '') ?? appTodayDateOnly();

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setLocal) {
              final dueLabel = _formatDueDate(context, strings, dueDate);
              return AlertDialog(
                title: Text(
                  task == null
                      ? strings.addAcademicTask
                      : strings.editAcademicTask,
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: strings.academicTaskTitle,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<AcademicTaskType>(
                        initialValue: type,
                        decoration: InputDecoration(
                          labelText: strings.academicTaskType,
                          border: const OutlineInputBorder(),
                        ),
                        items: AcademicTaskType.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(
                                  strings.academicTaskTypeLabel(value.name),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setLocal(() => type = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: subjectId,
                        decoration: InputDecoration(
                          labelText: strings.academicTaskCourseOptional,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: '',
                            child: Text(strings.academicTaskNoCourse),
                          ),
                          ...subjects.map(
                            (subject) => DropdownMenuItem<String>(
                              value: subject.id,
                              child: Text(
                                subject.name.isEmpty
                                    ? strings.unnamedCourse
                                    : subject.name,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setLocal(() => subjectId = value ?? '');
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dueDate,
                            firstDate: appTodayDateOnly()
                                .subtract(const Duration(days: 365)),
                            lastDate: appTodayDateOnly()
                                .add(const Duration(days: 365 * 4)),
                          );
                          if (picked == null) return;
                          setLocal(() {
                            dueDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                            );
                          });
                        },
                        icon:
                            const Icon(Icons.calendar_today_outlined, size: 18),
                        label: Text(dueLabel),
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

      final title = titleController.text.trim();
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.academicTaskTitleRequired)),
        );
        return;
      }

      try {
        if (task == null) {
          await ref.read(academicTasksRepositoryProvider).createTask(
                uid: uid,
                title: title,
                type: type,
                dueDateIso: _toDateIso(dueDate),
                subjectId: subjectId,
              );
        } else {
          await ref.read(academicTasksRepositoryProvider).updateTask(
                uid: uid,
                taskId: task.id,
                title: title,
                type: type,
                dueDateIso: _toDateIso(dueDate),
                subjectId: subjectId,
              );
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                task == null
                    ? strings.academicTaskSaved
                    : strings.academicTaskUpdated,
              ),
            ),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                task == null
                    ? strings.couldNotSaveAcademicTask
                    : strings.couldNotUpdateAcademicTask,
              ),
            ),
          );
        }
      }
    } finally {
      titleController.dispose();
    }
  }

  Future<void> _toggleTask(
    BuildContext context,
    WidgetRef ref,
    String uid,
    AcademicTask task,
  ) async {
    final strings = AppStrings.of(context);
    try {
      await ref.read(academicTasksRepositoryProvider).setTaskCompleted(
            uid: uid,
            taskId: task.id,
            completed: !task.isCompleted,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              task.isCompleted
                  ? strings.academicTaskReopened
                  : strings.academicTaskCompleted,
            ),
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.couldNotToggleAcademicTask)),
      );
    }
  }

  Future<void> _deleteTask(
    BuildContext context,
    WidgetRef ref,
    String uid,
    AcademicTask task,
  ) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deleteAcademicTaskTitle),
        content: Text(strings.deleteAcademicTaskConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.deleteAcademicTask),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(academicTasksRepositoryProvider).deleteTask(
            uid: uid,
            taskId: task.id,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.academicTaskDeleted)),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.couldNotDeleteAcademicTask)),
      );
    }
  }

  List<AcademicTask> _sortedTasks(List<AcademicTask> tasks) {
    final sorted = [...tasks]..sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        final aDue = a.dueDate ?? DateTime(9999);
        final bDue = b.dueDate ?? DateTime(9999);
        return aDue.compareTo(bDue);
      });
    return sorted;
  }

  String _subtitle(
    BuildContext context,
    AppStrings strings,
    AcademicTask task,
    Map<String, Subject> subjectById,
  ) {
    final subject = subjectById[task.subjectId];
    final courseName = subject == null
        ? strings.academicTaskNoCourse
        : (subject.name.isEmpty ? strings.unnamedCourse : subject.name);
    return [
      strings.academicTaskTypeLabel(task.type.name),
      courseName,
      _formatDueDate(context, strings, task.dueDate),
    ].join(' • ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final authAsync = ref.watch(currentAuthUserProvider);

    return authAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(strings.academicTasks)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(strings.academicTasks)),
        body: Center(child: Text('$e')),
      ),
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: Text(strings.academicTasks)),
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
        final tasksAsync = ref.watch(academicTasksStreamProvider(user.uid));

        return Scaffold(
          appBar: AppBar(title: Text(strings.academicTasks)),
          floatingActionButton: subjectsAsync.maybeWhen(
            data: (subjects) => FloatingActionButton.extended(
              onPressed: () => _showTaskDialog(
                context,
                ref,
                user.uid,
                subjects,
              ),
              icon: const Icon(Icons.add),
              label: Text(strings.addAcademicTask),
            ),
            orElse: () => null,
          ),
          body: tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (tasks) {
              return subjectsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (subjects) {
                  if (tasks.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
                      children: [
                        Icon(
                          Icons.event_available_outlined,
                          size: 56,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          strings.academicTasksEmptyHint,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    );
                  }
                  final subjectById = {
                    for (final subject in subjects) subject.id: subject,
                  };
                  final sortedTasks = _sortedTasks(tasks);
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: sortedTasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final task = sortedTasks[index];
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
                          leading: Icon(
                            _iconForType(task.type),
                            color: theme.colorScheme.primary,
                          ),
                          trailing: SizedBox(
                            width: 96,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: task.isCompleted,
                                  onChanged: (_) => _toggleTask(
                                    context,
                                    ref,
                                    user.uid,
                                    task,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showTaskDialog(
                                        context,
                                        ref,
                                        user.uid,
                                        subjects,
                                        task: task,
                                      );
                                      return;
                                    }
                                    if (value == 'delete') {
                                      _deleteTask(
                                        context,
                                        ref,
                                        user.uid,
                                        task,
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Text(strings.editAcademicTask),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text(strings.deleteAcademicTask),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          title: Text(
                            task.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isCompleted
                                  ? theme.colorScheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            _subtitle(context, strings, task, subjectById),
                          ),
                          onTap: () => _showTaskDialog(
                            context,
                            ref,
                            user.uid,
                            subjects,
                            task: task,
                          ),
                        ),
                      );
                    },
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
