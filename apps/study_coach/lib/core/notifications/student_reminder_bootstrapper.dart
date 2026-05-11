import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_providers.dart';
import 'student_reminder_providers.dart';

class StudentReminderBootstrapper extends ConsumerWidget {
  const StudentReminderBootstrapper({
    required this.child,
    super.key,
  });

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(currentAuthUserProvider, (previous, next) {
      final wasSignedIn = previous?.valueOrNull != null;
      final signedOut = next.hasValue && next.valueOrNull == null;
      if (wasSignedIn && signedOut) {
        unawaited(
          ref
              .read(studentNotificationServiceProvider)
              .clearScheduledStudentReminders(),
        );
      }
    });

    final user = ref.watch(currentAuthUserProvider).valueOrNull;
    if (user != null && user.emailVerified) {
      ref.watch(studentReminderSyncControllerProvider(user.uid));
    }

    return child ?? const SizedBox.shrink();
  }
}
