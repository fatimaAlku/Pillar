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

  String get adaptiveScheduleBlurb => _isArabic
      ? 'جدول تكيفي مخصص بناءً على أدائك في الاختبارات ومدى قرب الامتحانات.'
      : 'Adaptive schedule personalized from your quiz performance and exam urgency.';
  String get schedulingEditorComingSoon =>
      _isArabic ? 'محرر الجدولة قريباً' : 'Scheduling editor coming soon';
  String get addSchedule => _isArabic ? 'إضافة جدول' : 'Add schedule';
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

  String personalizedPlanFooter(int totalMin, String explanation) => _isArabic
      ? 'تم التخصيص حسب قرب الامتحان، وضعف الاختبارات، وصعوبة المادة، والحداثة. '
          'تعاد جدولة الجلسات الفائتة. المجموع $totalMin دقيقة اليوم.\n$explanation'
      : 'Personalized from exam urgency, weak quiz topics, subject difficulty, and recency. '
          'Missed sessions are redistributed. Allocated $totalMin minutes today.\n$explanation';

  String get quizzesIntro => _isArabic
      ? 'أنشئ اختبارات بالذكاء الاصطناعي واستهدف نقاط الضعف أسرع.'
      : 'Build AI-powered quizzes and target weak topics faster.';
  String get generateQuizTitle => _isArabic ? 'إنشاء اختبار' : 'Generate Quiz';
  String get generateQuizDescription => _isArabic
      ? 'استخدم المواضيع و/أو الملاحظات لإنشاء اختبار ثم راجع نقاط الضعف.'
      : 'Use topics and/or notes to generate a quiz, then review weak topics.';
  String get topicsCommaSeparated =>
      _isArabic ? 'المواضيع (مفصولة بفواصل)' : 'Topics (comma-separated)';
  String get topicsHint => _isArabic
      ? 'مثال: أشجار، رسوم بيانية، تجزئة'
      : 'e.g. Trees, Graphs, Hashing';
  String get notesOptional =>
      _isArabic ? 'الملاحظات (اختياري)' : 'Notes (optional)';
  String get notesHint => _isArabic
      ? 'الصق الملاحظات لتوفير سياق إنشاء الاختبار'
      : 'Paste notes for quiz generation context';
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
  String get backToQuizzes =>
      _isArabic ? 'العودة للاختبارات' : 'Back to quizzes';

  String get roadmapIntro => _isArabic
      ? 'اختر تخصصك لفتح خارطة طريق مركزة تضم أهم المواد والمواضيع.'
      : 'Pick your major to open a focused roadmap with the most important subjects and topics.';
  String majorRoadmap(String majorTitle) =>
      _isArabic ? 'خارطة طريق $majorTitle' : '$majorTitle Roadmap';
  String get priorityRoadmap =>
      _isArabic ? 'خارطة طريق الأولويات' : 'Priority roadmap';
  String focusSubjectsFirst(String majorTitle) => _isArabic
      ? 'ركّز على هذه المواد أولاً لبناء أساس قوي في $majorTitle.'
      : 'Focus these subjects first to build a strong foundation in $majorTitle.';

  String get appLanguage => _isArabic ? 'لغة التطبيق' : 'App language';
  String get modeSwitch => _isArabic ? 'تبديل الوضع' : 'Mode Switch';
  String get progress => _isArabic ? 'التقدم' : 'Progress';
  String get passwordChange =>
      _isArabic ? 'تغيير كلمة المرور' : 'Password change';
  String get privacyPolicy => _isArabic ? 'سياسة الخصوصية' : 'Privacy Policy';
  String get about => _isArabic ? 'حول التطبيق' : 'About';
  String get logout => _isArabic ? 'تسجيل الخروج' : 'Log out';
  String get allRightsReserved => _isArabic
      ? '© 2026 بيلار. جميع الحقوق محفوظة.'
      : '© 2026 Pillar. All rights reserved.';
  String get light => _isArabic ? 'فاتح' : 'Light';
  String get dark => _isArabic ? 'داكن' : 'Dark';

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
      ? 'لا توجد مواد أو مواضيع بعد. أضف موادك ومواضيعك من لوحة الإدارة أو التطبيق عندما يتوفر ذلك.'
      : 'No subjects or topics yet. Add your courses and topics (when available in the app) to see a personalized schedule.';
}
