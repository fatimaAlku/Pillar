import 'package:flutter/material.dart';

class AppStrings {
  AppStrings._(this._languageCode);

  final String _languageCode;

  static AppStrings of(BuildContext context) {
    return AppStrings._(Localizations.localeOf(context).languageCode);
  }

  bool get _isArabic => _languageCode == 'ar';

  String get navHome => _isArabic ? 'الرئيسية' : 'Home';
  String get navPlan => _isArabic ? 'الخطة' : 'Plan';
  String get navQuiz => _isArabic ? 'الاختبارات' : 'Quiz';
  String get navRoadmap => _isArabic ? 'المسار' : 'Roadmap';
  String get navProfile => _isArabic ? 'الملف الشخصي' : 'Profile';

  String get appTitle => 'Pillar';

  String get createAccount => _isArabic ? 'إنشاء حساب' : 'Create account';
  String get login => _isArabic ? 'تسجيل الدخول' : 'Login';
  String get email => _isArabic ? 'البريد الإلكتروني' : 'Email';
  String get username => _isArabic ? 'اسم المستخدم' : 'Username';
  String get usernameRequired =>
      _isArabic ? 'اسم المستخدم مطلوب' : 'Username is required';
  String get profileUserFallback => _isArabic ? 'مستخدم بيلار' : 'Pillar user';
  String get editProfile => _isArabic ? 'تعديل الملف الشخصي' : 'Edit profile';
  String get profilePhoto => _isArabic ? 'الصورة الشخصية' : 'Profile photo';
  String get changePhoto => _isArabic ? 'تغيير الصورة' : 'Change photo';
  String get removePhoto => _isArabic ? 'إزالة الصورة' : 'Remove photo';
  String get chooseAvatar => _isArabic ? 'اختر صورة رمزية' : 'Choose avatar';
  String get avatarMale => _isArabic ? 'ذكر' : 'Male';
  String get avatarFemale => _isArabic ? 'أنثى' : 'Female';
  String get saveChanges => _isArabic ? 'حفظ التغييرات' : 'Save changes';
  String get profileUpdated =>
      _isArabic ? 'تم تحديث الملف الشخصي.' : 'Profile updated.';
  String get profileUpdatedLocally => _isArabic
      ? 'تم حفظ الصورة على جهازك مؤقتًا. لتتم مزامنتها عبر الأجهزة، فعّل Firebase Storage.'
      : 'Photo saved locally on this device. Enable Firebase Storage to sync it across devices.';
  String get couldNotUpdateProfile =>
      _isArabic ? 'تعذّر تحديث الملف الشخصي.' : 'Could not update profile.';
  String get password => _isArabic ? 'كلمة المرور' : 'Password';
  String get emailRequired =>
      _isArabic ? 'البريد الإلكتروني مطلوب' : 'Email is required';
  String get enterValidEmail =>
      _isArabic ? 'أدخل بريدًا إلكترونيًا صحيحًا' : 'Enter a valid email';
  String get passwordRequired =>
      _isArabic ? 'كلمة المرور مطلوبة' : 'Password is required';
  String get minimumSixChars =>
      _isArabic ? '6 أحرف على الأقل' : 'Minimum 6 characters';
  String get signUp => _isArabic ? 'إنشاء حساب' : 'Sign up';
  String get chooseMajor => _isArabic ? 'اختر التخصص' : 'Choose major';
  String get majorOptional => _isArabic
      ? 'اختياري - يمكنك الاختيار لاحقًا'
      : 'Optional - you can choose later';
  String get skipForNow => _isArabic ? 'تخطي الآن' : 'Skip for now';
  String get majorRequiredMessage =>
      _isArabic ? 'يرجى اختيار التخصص.' : 'Please select your major.';
  String get alreadyHaveAccountLogin => _isArabic
      ? 'لديك حساب بالفعل؟ سجّل الدخول'
      : 'Already have an account? Login';
  String get needAccountSignUp =>
      _isArabic ? 'تحتاج حسابًا؟ أنشئ حسابًا' : 'Need an account? Sign up';

  String get focusToday => _isArabic ? 'تركيز اليوم' : 'Focus today';
  String get smallStepsConsistentProgress => _isArabic
      ? 'خطوات صغيرة وتقدم مستمر.'
      : 'Small steps, consistent progress.';
  String get quickActions => _isArabic ? 'إجراءات سريعة' : 'Quick actions';
  String get addTask => _isArabic ? 'إضافة مهمة' : 'Add Task';
  String get generateQuiz => _isArabic ? 'إنشاء اختبار' : 'Generate Quiz';
  String get uploadNotes => _isArabic ? 'رفع الملاحظات' : 'Upload Notes';
  String get smartStudyAssistant =>
      _isArabic ? 'مساعدك الذكي للدراسة' : 'Your smart study assistant';
  String get todaysProgress => _isArabic ? 'تقدم اليوم' : 'Today’s progress';
  String get todaysStudyPlan =>
      _isArabic ? 'خطة دراسة اليوم' : 'Today’s study plan';
  String get aiSuggestion =>
      _isArabic ? 'اقتراح الذكاء الاصطناعي' : 'AI suggestion';
  String get aiSuggestionBody => _isArabic
      ? 'سيعرض لك مساعدك نصائح مخصصة هنا بناءً على جدولك ونتائج اختباراتك.'
      : 'Your coach will surface personalized tips here based on your schedule and quiz results.';
  String percentComplete(int percent) =>
      _isArabic ? 'مكتمل $percent٪' : '$percent% complete';
  String completedTasks(int completed, int total) =>
      _isArabic ? '$completed من $total مهام' : '$completed of $total tasks';
  String minutesShort(int minutes) =>
      _isArabic ? '$minutes دقيقة' : '$minutes min';

  String get planDayNothingScheduled => _isArabic
      ? 'لا توجد جلسات مجدولة لهذا اليوم. اضغط «إضافة إلى الجدول» لإظهار المواضيع هنا.'
      : 'Nothing scheduled for this day yet. Tap Add to schedule to place topics on your calendar.';
  String get addSchedule => _isArabic ? 'إضافة إلى الجدول' : 'Add to schedule';
  String get addToScheduleSheetTitle =>
      _isArabic ? 'جدولة جلسة' : 'Schedule a session';
  String scheduleSessionForDay(String dayLabel) =>
      _isArabic ? 'التاريخ: $dayLabel' : 'Date: $dayLabel';
  String get topicForSession => _isArabic ? 'الموضوع' : 'Topic';
  String get sessionDuration =>
      _isArabic ? 'المدة (دقائق)' : 'Duration (minutes)';
  String get saveToSchedule => _isArabic ? 'حفظ في الجدول' : 'Save to schedule';
  String get sessionScheduledSuccess =>
      _isArabic ? 'تمت إضافة الجلسة إلى خطتك.' : 'Session added to your plan.';
  String get couldNotScheduleSession =>
      _isArabic ? 'تعذّر حفظ الجلسة.' : 'Could not save session.';
  String get saveToScheduleTimedOut => _isArabic
      ? 'انتهت مهلة الاتصال. تحقق من الشبكة وحاول مرة أخرى.'
      : 'Connection timed out. Check your network and try again.';
  String get addToScheduleFromCard =>
      _isArabic ? 'إضافة للجدول' : 'Add to schedule';
  String get editScheduledSessionTooltip =>
      _isArabic ? 'تعديل الجلسة' : 'Edit session';
  String get deleteScheduledSessionTooltip =>
      _isArabic ? 'حذف الجلسة' : 'Delete session';
  String get editSessionTitle => _isArabic ? 'تعديل الجلسة' : 'Edit session';
  String get deleteSessionTitle =>
      _isArabic ? 'حذف الجلسة؟' : 'Delete session?';
  String get deleteSessionConfirm => _isArabic
      ? 'سيتم إزالة هذه الجلسة من جدولك لهذا اليوم.'
      : 'This session will be removed from your schedule for this day.';
  String get deleteSessionAction => _isArabic ? 'حذف' : 'Delete';
  String get sessionUpdated =>
      _isArabic ? 'تم تحديث الجلسة.' : 'Session updated.';
  String get sessionDeleted =>
      _isArabic ? 'تم حذف الجلسة.' : 'Session deleted.';
  String get couldNotDeleteSession =>
      _isArabic ? 'تعذّر حذف الجلسة.' : 'Could not delete session.';
  String scheduleMeta(String subject, int durationMin) => _isArabic
      ? '$subject  •  $durationMin دقيقة'
      : '$subject  •  $durationMin min';
  String priorityBreakdown(
    String score,
    String deadline,
    String weakness,
    String difficulty,
    String recency,
  ) {
    return _isArabic
        ? 'الأولوية $score (ع:$deadline ض:$weakness ص:$difficulty ح:$recency)'
        : 'Priority $score (U:$deadline W:$weakness D:$difficulty R:$recency)';
  }

  String get generateQuizDescription => _isArabic
      ? 'استخدم ملاحظاتك لإنشاء اختبار بالذكاء الاصطناعي ثم راجع نقاط الضعف.'
      : 'Use your notes to generate an AI quiz, then review weak topics.';
  String get topicsCommaSeparated =>
      _isArabic ? 'المواضيع (مفصولة بفواصل)' : 'Topics (comma-separated)';
  String get topicsHint => _isArabic
      ? 'مثال: أشجار، رسوم بيانية، تجزئة'
      : 'e.g. Trees, Graphs, Hashing';
  String get notesRequired =>
      _isArabic ? 'الملاحظات (مطلوبة)' : 'Notes (required)';
  String get notesHint => _isArabic
      ? 'الصق أو ارفع ملاحظاتك ليقوم الذكاء الاصطناعي بإنشاء الأسئلة والإجابات'
      : 'Paste or upload notes so AI can generate quiz questions and answers';
  String get notesRequiredForQuiz => _isArabic
      ? 'يرجى إضافة الملاحظات قبل إنشاء الاختبار.'
      : 'Please add notes before generating the quiz.';
  String get uploadNotesFile =>
      _isArabic ? 'رفع ملف الملاحظات' : 'Upload notes file';
  String get importingNotes =>
      _isArabic ? 'جارٍ استيراد الملاحظات...' : 'Importing notes...';
  String get notesImported =>
      _isArabic ? 'تم استيراد الملاحظات.' : 'Notes imported.';
  String get unsupportedNotesFile => _isArabic
      ? 'نوع الملف غير مدعوم. استخدم TXT أو MD أو PDF أو DOCX.'
      : 'Unsupported file type. Use TXT, MD, PDF, or DOCX.';
  String get unreadableNotesFile => _isArabic
      ? 'تعذّر قراءة نص من الملف المحدد.'
      : 'Could not read text from the selected file.';
  String get couldNotImportNotes => _isArabic
      ? 'تعذّر استيراد ملف الملاحظات.'
      : 'Could not import notes file.';
  String get difficulty => _isArabic ? 'الصعوبة' : 'Difficulty';
  String get easy => _isArabic ? 'سهل' : 'Easy';
  String get medium => _isArabic ? 'متوسط' : 'Medium';
  String get hard => _isArabic ? 'صعب' : 'Hard';
  String get numberOfQuestions =>
      _isArabic ? 'عدد الأسئلة' : 'Number of questions';
  String get generating => _isArabic ? 'جارٍ الإنشاء...' : 'Generating...';
  String get startQuiz => _isArabic ? 'بدء الاختبار' : 'Start quiz';

  String get quiz => _isArabic ? 'الاختبار' : 'Quiz';
  String get noQuizLoaded => _isArabic
      ? 'لا يوجد اختبار بعد. أنشئ اختبارًا من تبويب الاختبارات.'
      : 'No quiz loaded yet. Generate one from the Quiz tab.';
  String get generatingQuizWithAi => _isArabic
      ? 'جارٍ إنشاء الاختبار بالذكاء الاصطناعي...'
      : 'Generating quiz with AI...';
  String get retryGeneration =>
      _isArabic ? 'إعادة المحاولة' : 'Retry generation';
  String questionCounter(int current, int total) =>
      _isArabic ? 'السؤال $current/$total' : 'Question $current/$total';
  String questionOf(int current, int total) =>
      _isArabic ? '$current من $total' : '$current of $total';
  String get back => _isArabic ? 'رجوع' : 'Back';
  String get submit => _isArabic ? 'إرسال' : 'Submit';
  String get next => _isArabic ? 'التالي' : 'Next';
  String get score => _isArabic ? 'النتيجة' : 'Score';
  String get retake => _isArabic ? 'إعادة الاختبار' : 'Retake';
  String get weakTopics => _isArabic ? 'المواضيع الضعيفة' : 'Weak topics';
  String get noWeakTopics => _isArabic
      ? 'لا توجد مواضيع ضعيفة - عمل رائع.'
      : 'No weak topics detected — great job.';
  String get review => _isArabic ? 'المراجعة' : 'Review';
  String incorrectCount(int count) =>
      _isArabic ? '$count إجابات خاطئة' : '$count incorrect';
  String yourAnswer(String answer) =>
      _isArabic ? 'إجابتك: $answer' : 'Your answer: $answer';
  String correctAnswer(String answer) =>
      _isArabic ? 'الإجابة الصحيحة: $answer' : 'Correct answer: $answer';
  String explanation(String text) =>
      _isArabic ? 'الشرح: $text' : 'Explanation: $text';
  String get unanswered => _isArabic ? 'بدون إجابة' : 'Unanswered';
  String get backToQuizzes => _isArabic ? 'رجوع' : 'Back';

  String majorRoadmap(String majorTitle) =>
      _isArabic ? 'خارطة طريق $majorTitle' : '$majorTitle Roadmap';
  String get priorityRoadmap =>
      _isArabic ? 'خارطة طريق الأولويات' : 'Priority roadmap';
  String focusSubjectsFirst(String majorTitle) => _isArabic
      ? 'ركّز على هذه المواد أولاً لبناء أساس قوي في $majorTitle.'
      : 'Focus these subjects first to build a strong foundation in $majorTitle.';
  String get successBlueprint => _isArabic ? 'خطة النجاح' : 'Success blueprint';
  String howToSucceedInMajor(String majorTitle) => _isArabic
      ? 'كيف تنجح في تخصص $majorTitle'
      : 'How to succeed in $majorTitle';
  String get roadmapPhases =>
      _isArabic ? 'مراحل التنفيذ المقترحة' : 'Suggested execution phases';
  String get keyResources =>
      _isArabic ? 'مصادر خارجية مفيدة' : 'Helpful external resources';
  String get projectIdeas =>
      _isArabic ? 'أفكار مشاريع وتطبيق' : 'Project and application ideas';
  String get openResource => _isArabic ? 'فتح المصدر' : 'Open resource';
  String get couldNotOpenResource => _isArabic
      ? 'تعذّر فتح الرابط حالياً.'
      : 'Could not open this link right now.';
  String get weeksShort => _isArabic ? 'أسابيع' : 'weeks';
  String get chooseMajorToTrackProgress => _isArabic
      ? 'اختر تخصصك لتفعيل تتبع التقدم.'
      : 'Choose your major to enable progress tracking.';
  String get setAsMyMajor => _isArabic ? 'تعيين كتخصصي' : 'Set as my major';
  String get majorSaved => _isArabic ? 'تم حفظ التخصص.' : 'Major saved.';
  String yourMajor(String majorTitle) =>
      _isArabic ? 'تخصصك: $majorTitle' : 'Your major: $majorTitle';

  String get appLanguage => _isArabic ? 'لغة التطبيق' : 'App language';
  String get modeSwitch => _isArabic ? 'تبديل الوضع' : 'Mode Switch';
  String get progress => _isArabic ? 'التقدم' : 'Progress';
  String get history => _isArabic ? 'السجل' : 'History';
  String get noQuizHistory =>
      _isArabic ? 'لا يوجد سجل اختبارات بعد.' : 'No quiz history yet.';
  String get couldNotLoadHistory =>
      _isArabic ? 'تعذّر تحميل السجل.' : 'Could not load history.';
  String get passwordChange =>
      _isArabic ? 'تغيير كلمة المرور' : 'Password change';
  String get passwordChangeDescription => _isArabic
      ? 'أدخل كلمة المرور الحالية ثم اختر كلمة مرور جديدة.'
      : 'Enter your current password and set a new password.';
  String get currentPassword =>
      _isArabic ? 'كلمة المرور الحالية' : 'Current password';
  String get currentPasswordRequired =>
      _isArabic ? 'كلمة المرور الحالية مطلوبة' : 'Current password is required';
  String get newPassword => _isArabic ? 'كلمة المرور الجديدة' : 'New password';
  String get newPasswordRequired =>
      _isArabic ? 'كلمة المرور الجديدة مطلوبة' : 'New password is required';
  String get confirmNewPassword =>
      _isArabic ? 'تأكيد كلمة المرور الجديدة' : 'Confirm new password';
  String get confirmNewPasswordRequired => _isArabic
      ? 'تأكيد كلمة المرور الجديدة مطلوب'
      : 'Please confirm your new password';
  String get newPasswordMustDiffer => _isArabic
      ? 'يجب أن تختلف كلمة المرور الجديدة عن الحالية'
      : 'New password must be different from current password';
  String get passwordsDoNotMatch =>
      _isArabic ? 'كلمتا المرور غير متطابقتين' : 'Passwords do not match';
  String get updatePassword =>
      _isArabic ? 'تحديث كلمة المرور' : 'Update password';
  String get passwordChangeSuccess =>
      _isArabic ? 'تم تحديث كلمة المرور.' : 'Password updated.';
  String get passwordChangeFailed => _isArabic
      ? 'تعذّر تحديث كلمة المرور. حاول مرة أخرى.'
      : 'Could not update password. Please try again.';
  String get passwordCurrentIncorrect => _isArabic
      ? 'كلمة المرور الحالية غير صحيحة.'
      : 'Current password is incorrect.';
  String get passwordWeak => _isArabic
      ? 'كلمة المرور الجديدة ضعيفة (6 أحرف على الأقل).'
      : 'New password is too weak (minimum 6 characters).';
  String get passwordTooManyRequests => _isArabic
      ? 'محاولات كثيرة جدًا. حاول لاحقًا.'
      : 'Too many attempts. Please try again later.';
  String get passwordRequiresRecentLogin => _isArabic
      ? 'انتهت صلاحية الجلسة. سجّل الدخول مرة أخرى ثم أعد المحاولة.'
      : 'Session expired. Please sign in again and retry.';
  String get privacyPolicy => _isArabic ? 'سياسة الخصوصية' : 'Privacy Policy';
  String get privacyPolicyIntro => _isArabic
      ? 'توضح هذه السياسة كيفية جمع بياناتك واستخدامها وحمايتها داخل تطبيق بيلار.'
      : 'This policy explains how your data is collected, used, and protected in Pillar.';
  String get privacyPolicyLastUpdated =>
      _isArabic ? 'آخر تحديث: 22 أبريل 2026' : 'Last updated: April 22, 2026';
  String get privacyPolicyDataWeCollectTitle =>
      _isArabic ? 'البيانات التي نجمعها' : 'Data we collect';
  String get privacyPolicyDataWeCollectBody => _isArabic
      ? 'قد نجمع بيانات الحساب مثل البريد الإلكتروني والاسم والصورة الشخصية، بالإضافة إلى بيانات الاستخدام مثل المواد الدراسية والخطط والاختبارات التي تنشئها داخل التطبيق.'
      : 'We may collect account data such as email, name, and profile photo, plus usage data like the subjects, plans, and quizzes you create in the app.';
  String get privacyPolicyHowWeUseDataTitle =>
      _isArabic ? 'كيف نستخدم البيانات' : 'How we use data';
  String get privacyPolicyHowWeUseDataBody => _isArabic
      ? 'نستخدم البيانات لتشغيل الميزات الأساسية، مزامنة تقدمك عبر الأجهزة، وتحسين التوصيات الدراسية وتجربة التطبيق.'
      : 'We use data to power core features, sync your progress across devices, and improve study recommendations and overall app experience.';
  String get privacyPolicyStorageSecurityTitle =>
      _isArabic ? 'التخزين والأمان' : 'Storage and security';
  String get privacyPolicyStorageSecurityBody => _isArabic
      ? 'يتم تخزين البيانات باستخدام خدمات سحابية آمنة، مع تطبيق ضوابط وصول لحماية حسابك. لا نبيع بياناتك الشخصية لأطراف خارجية.'
      : 'Data is stored using secure cloud services with access controls to protect your account. We do not sell your personal data to third parties.';
  String get privacyPolicyYourChoicesTitle =>
      _isArabic ? 'خياراتك' : 'Your choices';
  String get privacyPolicyYourChoicesBody => _isArabic
      ? 'يمكنك تحديث بيانات ملفك الشخصي أو حذف بعض المحتوى الذي تنشئه داخل التطبيق. باستخدام التطبيق، فإنك توافق على هذه السياسة وتحديثاتها.'
      : 'You can update your profile details and remove content you create in the app. By using Pillar, you agree to this policy and its updates.';
  String get privacyPolicyContactTitle => _isArabic ? 'التواصل' : 'Contact';
  String get privacyPolicyContactBody => _isArabic
      ? 'إذا كانت لديك أسئلة حول الخصوصية، تواصل معنا عبر دعم التطبيق داخل بيلار.'
      : 'If you have privacy questions, contact us through in-app support in Pillar.';
  String get about => _isArabic ? 'حول التطبيق' : 'About';
  String get aboutVersion => _isArabic ? 'الإصدار 1.0.0' : 'Version 1.0.0';
  String get aboutWhatIsPillarTitle =>
      _isArabic ? 'ما هو بيلار؟' : 'What is Pillar?';
  String get aboutWhatIsPillarBody => _isArabic
      ? 'بيلار هو رفيق دراسة ذكي يساعدك على تنظيم المواد، إنشاء خطط يومية، وتتبّع تقدمك بطريقة بسيطة.'
      : 'Pillar is a smart study companion that helps you organize courses, build daily plans, and track progress with clarity.';
  String get aboutMissionTitle => _isArabic ? 'رسالتنا' : 'Our mission';
  String get aboutMissionBody => _isArabic
      ? 'نهدف إلى جعل التعلّم أكثر تركيزًا واستمرارية عبر أدوات عملية تجمع بين التخطيط، الاختبار، والتوصيات الذكية.'
      : 'Our mission is to make learning more focused and consistent through practical tools that combine planning, quizzes, and smart recommendations.';
  String get aboutFeaturesTitle => _isArabic ? 'أهم الميزات' : 'Key features';
  String get aboutFeaturesBody => _isArabic
      ? '• خطة دراسة يومية قابلة للتعديل\n• اختبارات مولّدة بالذكاء الاصطناعي\n• تتبع المواد والمواضيع والتقدّم\n• تخصيص اللغة والمظهر والملف الشخصي'
      : '• Editable daily study planning\n• AI-generated quizzes\n• Subject, topic, and progress tracking\n• Profile, language, and theme personalization';
  String get logout => _isArabic ? 'تسجيل الخروج' : 'Log out';
  String get allRightsReserved => _isArabic
      ? '© 2026 بيلار. جميع الحقوق محفوظة.'
      : '© 2026 Pillar. All rights reserved.';
  String get light => _isArabic ? 'فاتح' : 'Light';
  String get dark => _isArabic ? 'داكن' : 'Dark';

  String get cancel => _isArabic ? 'إلغاء' : 'Cancel';
  String get ok => _isArabic ? 'موافق' : 'OK';
  String get save => _isArabic ? 'حفظ' : 'Save';
  String get myCourses => _isArabic ? 'موادي ومقرراتي' : 'My courses';
  String get addCourse => _isArabic ? 'إضافة مقرر' : 'Add course';
  String get courseName => _isArabic ? 'اسم المقرر' : 'Course name';
  String get examDateOptional =>
      _isArabic ? 'تاريخ الامتحان (اختياري)' : 'Exam date (optional)';
  String examDateLabel(String formatted) =>
      _isArabic ? 'الامتحان: $formatted' : 'Exam: $formatted';
  String get coursesEmptyHint => _isArabic
      ? 'لم تضف مقررات بعد. اضغط «إضافة مقرر» لإضافة مادة، ثم افتح المقرر لإضافة مواضيع.'
      : 'No courses yet. Tap “Add course” to create a subject, then open it to add topics.';
  String get courseNameRequired =>
      _isArabic ? 'يرجى إدخال اسم المقرر.' : 'Please enter a course name.';
  String get courseSaved => _isArabic ? 'تم حفظ المقرر.' : 'Course saved.';
  String get couldNotSaveCourse =>
      _isArabic ? 'تعذّر حفظ المقرر.' : 'Could not save course.';
  String get signInToManageCourses => _isArabic
      ? 'سجّل الدخول لإدارة مقرراتك ومواضيعك.'
      : 'Sign in to manage your courses and topics.';
  String get unnamedCourse => _isArabic ? 'مقرر بدون اسم' : 'Untitled course';
  String get addTopic => _isArabic ? 'إضافة موضوع' : 'Add topic';
  String get major => _isArabic ? 'التخصص' : 'Major';
  String get topicTitleLabel => _isArabic ? 'عنوان الموضوع' : 'Topic title';
  String get topicsEmptyHint => _isArabic
      ? 'لا توجد مواضيع بعد. اضغط «إضافة موضوع» لإضافة وحدة دراسية لهذا المقرر.'
      : 'No topics yet. Tap “Add topic” to add a study unit to this course.';
  String topicDifficultyShort(String value) =>
      _isArabic ? 'الصعوبة: $value' : 'Difficulty: $value';
  String get topicTitleRequired =>
      _isArabic ? 'يرجى إدخال عنوان الموضوع.' : 'Please enter a topic title.';
  String get topicSaved => _isArabic ? 'تم حفظ الموضوع.' : 'Topic saved.';
  String get couldNotSaveTopic =>
      _isArabic ? 'تعذّر حفظ الموضوع.' : 'Could not save topic.';
  String get progressOverview =>
      _isArabic ? 'نظرة على التقدم' : 'Progress overview';
  String get overallProgress => _isArabic ? 'التقدم العام' : 'Overall progress';
  String get roadmapProgress =>
      _isArabic ? 'تقدم خارطة الطريق' : 'Roadmap progress';
  String get sessionsProgress =>
      _isArabic ? 'تقدم الجلسات' : 'Sessions progress';
  String get quizAverage => _isArabic ? 'متوسط الاختبارات' : 'Quiz average';
  String get noWeakAreasYet =>
      _isArabic ? 'لا توجد نقاط ضعف حالياً.' : 'No weak areas yet.';

  String comingSoonFor(String label) {
    return _isArabic ? '$label - قريباً' : '$label - coming soon';
  }

  String get signInToSeeStudyPlan => _isArabic
      ? 'سجّل الدخول لمزامنة خطتك من السحابة.'
      : 'Sign in to sync your plan from the cloud.';
  String get noSessionsTodayHome => _isArabic
      ? 'لا توجد جلسات مجدولة لهذا اليوم. عندما يحتوي نشط خطة دراسة على جلسات لهذا التاريخ، ستظهر هنا.'
      : 'No sessions scheduled for today. When your active study plan includes sessions for this date, they will appear here.';
  String get studySessionUntitled => _isArabic ? 'جلسة دراسة' : 'Study session';
  String get couldNotUpdateSession =>
      _isArabic ? 'تعذّر تحديث الجلسة.' : 'Could not update session.';
  String get todaysProgressNoSessions =>
      _isArabic ? 'لا مهام مجدولة بعد' : 'No scheduled tasks yet';
  String get noSubjectsForPersonalizedPlan => _isArabic
      ? 'لا توجد مواد أو مواضيع بعد. أضفها من الملف الشخصي ← «موادي ومقرراتي».'
      : 'No subjects or topics yet. Add them from Profile → My courses.';
}
