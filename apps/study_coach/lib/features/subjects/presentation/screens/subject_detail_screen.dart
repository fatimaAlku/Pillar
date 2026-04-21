import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/state/app_providers.dart';
import '../../domain/entities/subject.dart';
import '../controllers/subject_topics_providers.dart';

class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({
    super.key,
    required this.uid,
    required this.subject,
  });

  final String uid;
  final Subject subject;

  Future<void> _showAddTopicDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final strings = AppStrings.of(context);
    final titleController = TextEditingController();
    var difficulty = 0.5;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setLocal) {
              return AlertDialog(
                title: Text(strings.addTopic),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: strings.topicTitleLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        strings.difficulty,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Slider(
                        value: difficulty,
                        min: 0,
                        max: 1,
                        divisions: 10,
                        label: difficulty.toStringAsFixed(1),
                        onChanged: (v) => setLocal(() => difficulty = v),
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
          SnackBar(content: Text(strings.topicTitleRequired)),
        );
        return;
      }
      await ref.read(subjectsRepositoryProvider).addTopic(
            uid: uid,
            subjectId: subject.id,
            title: title,
            difficultyEstimate: difficulty,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.topicSaved)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.couldNotSaveTopic)),
        );
      }
    } finally {
      titleController.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final title = subject.name.isEmpty ? strings.unnamedCourse : subject.name;
    final topicsAsync = ref.watch(
      subjectTopicsStreamProvider(SubjectTopicsKey(uid, subject.id)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTopicDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(strings.addTopic),
      ),
      body: topicsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (topics) {
          if (topics.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
              children: [
                Icon(
                  Icons.topic_outlined,
                  size: 52,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  strings.topicsEmptyHint,
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
            itemCount: topics.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final t = topics[i];
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
                    t.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    strings.topicDifficultyShort(
                      t.difficultyEstimate.toStringAsFixed(1),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
