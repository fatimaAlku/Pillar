import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

class AppStrings {
  AppStrings._(this._languageCode);

  final String _languageCode;

  static AppStrings of(BuildContext context) {
    return AppStrings._(Localizations.localeOf(context).languageCode);
  }

  /// When [BuildContext] is unavailable (e.g. OAuth method channel callback).
  factory AppStrings.fromPlatformLocale() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return AppStrings._(code == 'ar' ? 'ar' : 'en');
  }

  /// Matches [AppLocaleController] / MaterialApp locale (not device locale).
  factory AppStrings.forLanguageCode(String languageCode) {
    return AppStrings._(languageCode == 'ar' ? 'ar' : 'en');
  }

  /// Matches [MaterialApp] / [appLocaleProvider] language (`ar` vs `en`).
  bool get isArabicLocale => _languageCode == 'ar';

  bool get _isArabic => _languageCode == 'ar';

  String get navHome => _isArabic ? 'الرئيسية' : 'Home';
  String get navPlan => _isArabic ? 'الخطة' : 'Plan';
  String get navQuiz => _isArabic ? 'الاختبارات' : 'Quiz';
  String get navRoadmap => _isArabic ? 'المسار' : 'Roadmap';
  String get navProfile => _isArabic ? 'الملف الشخصي' : 'Profile';

  String get appTitle => 'Pillar';

  String get createAccount => _isArabic ? 'إنشاء حساب' : 'Create account';
  String get login => _isArabic ? 'تسجيل الدخول' : 'Login';
  String get loginEmailNotRegistered => _isArabic
      ? 'لا يوجد حساب بهذا البريد. أنشئ حسابًا أولًا.'
      : "This email didn't sign up. Create an account first.";
  String get loginEmailOrPasswordIncorrect => _isArabic
      ? 'البريد أو كلمة المرور غير صحيحة.'
      : 'Email or password is incorrect.';
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
  String get studentPolytechnicEmailRequired => _isArabic
      ? 'استخدم بريدك الطلابي الذي ينتهي بـ @student.polytechnic.bh'
      : 'Use your student email ending with @student.polytechnic.bh';
  String get signUpPasswordMinEight =>
      _isArabic ? '8 أحرف على الأقل' : 'Minimum 8 characters';
  String get signUpPasswordNeedsSpecialChar => _isArabic
      ? 'يجب أن تتضمن كلمة المرور رمزًا خاصًا (مثل ! أو @ أو #)'
      : 'Password must include a special character (e.g. ! @ #)';
  String get signUp => _isArabic ? 'إنشاء حساب' : 'Sign up';
  String get signUpVerificationEmailSent => _isArabic
      ? 'تم إنشاء الحساب. سجّل الدخول، ثم أدخل رمز التحقق المُرسل إلى بريدك.'
      : 'Account created. Sign in, then enter the verification code sent to your email.';
  String get verifyEmailTitle =>
      _isArabic ? 'تحقّق من بريدك' : 'Verify your email';
  String verifyEmailBody(String address) => _isArabic
      ? 'أرسلنا رمزًا مكوّنًا من 6 أرقام إلى $address. أدخله أدناه.'
      : 'We sent a 6-digit code to $address. Enter it below.';
  String get verifyEmailNoAddressPlaceholder =>
      _isArabic ? 'عنوان بريدك' : 'your email address';
  String get verifyEmailOtpLabel =>
      _isArabic ? 'رمز التحقق' : 'Verification code';
  String get verifyEmailOtpHint => _isArabic ? '000000' : '000000';
  String get verifyEmailConfirmCode =>
      _isArabic ? 'تأكيد الرمز' : 'Verify code';
  String get verifyEmailCheckedInbox =>
      _isArabic ? 'تحديث من الخادم' : 'Reload from server';
  String get verifyEmailResend =>
      _isArabic ? 'إعادة إرسال الرمز' : 'Resend code';
  String get verifyEmailSignOut => _isArabic ? 'تسجيل الخروج' : 'Sign out';
  String get verifyEmailResent => _isArabic
      ? 'تم إرسال رمز جديد إلى بريدك.'
      : 'A new code was sent to your email.';
  String get verifyEmailOtpInvalidFormat => _isArabic
      ? 'أدخل الرمز المكوّن من 6 أرقام.'
      : 'Enter the 6-digit code from your email.';
  String get verifyEmailOtpWrongCode => _isArabic
      ? 'الرمز غير صحيح. حاول مرة أخرى.'
      : 'Incorrect code. Try again.';
  String get verifyEmailOtpExpiredOrMissing => _isArabic
      ? 'انتهت صلاحية الرمز أو لم يُطلب بعد. اطلب رمزًا جديدًا.'
      : 'That code expired or was not requested. Request a new code.';
  String get verifyEmailOtpRateLimited => _isArabic
      ? 'طلبات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.'
      : 'Too many requests. Wait a moment and try again.';
  String get verifyEmailServerNotConfigured => _isArabic
      ? 'التحقق بالبريد غير مهيأ على الخادم. اتصل بالدعم.'
      : 'Email verification is not configured on the server. Contact support.';
  String get verifyEmailUnauthenticated =>
      _isArabic ? 'يجب تسجيل الدخول أولًا.' : 'Please sign in first.';
  String get verifyEmailOtpGenericError => _isArabic
      ? 'تعذّر التحقق. حاول مرة أخرى.'
      : 'Verification failed. Please try again.';
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

  String get welcomeHello => _isArabic ? 'مرحبًا!' : 'Hello!';
  String get welcomeTitleLine1 => _isArabic ? 'أهلاً بك في' : 'Your';
  String get welcomeTitleHighlight =>
      _isArabic ? 'مساعدك الذكي للدراسة' : 'Smart study assistant';
  String get welcomeTitleLine3 => _isArabic
      ? 'لخططك واختباراتك ومقرراتك'
      : 'for plans, quizzes, and coursework';
  String get welcomeSubtitle => _isArabic
      ? 'احصل على دعم فوري لجدولك الدراسي، الاختبارات، والمساعدة الموجّهة حسب تخصصك.'
      : 'Get instant help with your schedule, quizzes, and major-aware coaching—all in one place.';
  String get welcomeGetStarted => _isArabic ? 'ابدأ الآن' : 'Get started';

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
  String get studyChatTitle =>
      _isArabic ? 'مساعد الدراسة للتخصص' : 'Major study assistant';
  String get studyChatInputHint =>
      _isArabic ? 'اكتب سؤالك الدراسي…' : 'Ask a study question';
  String get studyChatSend => _isArabic ? 'إرسال' : 'Send';
  String get studyChatClear => _isArabic ? 'مسح المحادثة' : 'Clear chat';
  String get studyChatEmptyState => _isArabic
      ? 'ابدأ بطرح سؤال عن مادة أو مفهوم في تخصصك.'
      : 'Ask about a topic or concept from your major to get started.';
  String get studyChatNoMajorTitle =>
      _isArabic ? 'حدّد تخصصك أولًا' : 'Choose your major first';
  String get studyChatNoMajorBody => _isArabic
      ? 'يقتصر هذا المساعد على الإجابة ضمن تخصصك. اختر التخصص من الملف الشخصي ثم عد هنا.'
      : 'This assistant only answers within your declared major. Set your major in your profile, then come back.';
  String get studyChatOpenProfile =>
      _isArabic ? 'فتح الملف الشخصي' : 'Open profile';
  String get studyChatMajorLabel => _isArabic ? 'التخصص' : 'Major';
  String get studyChatDisclaimer => _isArabic
      ? 'قد يخطئ الذكاء الاصطناعي؛ تحقق من مصادرك الأكاديمية.'
      : 'AI can make mistakes; verify with your course materials.';
  String get studyChatNoCourses => _isArabic
      ? 'أضف مقررًا واحدًا على الأقل من الملف الشخصي ← «موادي ومقرراتي» لاستخدام المساعد ضمن موادك.'
      : 'Add at least one course under Profile → My courses so the assistant stays scoped to your actual classes.';
  String get studyChatRefusalOffTopic => _isArabic
      ? 'يمكنني المساعدة فقط في أسئلة دراسية جامعية تتعلق بمقرراتك ومواضيعك أو بمهارات الدراسة في هذا الإطار. جرّب ذكر مقررًا أو موضوعًا من قائمتك.'
      : 'I can only help with university study questions tied to your courses and topics, or study skills in that context. Try naming a course or topic from your list.';
  String get studyChatRefusalBlocked => _isArabic
      ? 'لا يمكنني المتابعة مع هذا الطلب. ركّز على سؤال دراسي يتعلق بمقرراتك.'
      : 'I can’t continue with that request. Ask a study question related to your courses instead.';
  String get todaysProgress => _isArabic ? 'تقدم اليوم' : 'Today’s progress';
  String get todaysStudyPlan =>
      _isArabic ? 'خطة دراسة اليوم' : 'Today’s study plan';
  String get aiSuggestion =>
      _isArabic ? 'اقتراح الذكاء الاصطناعي' : 'AI suggestion';
  String get aiSuggestionBody => _isArabic
      ? 'سيعرض لك مساعدك نصائح مخصصة هنا بناءً على جدولك ونتائج اختباراتك.'
      : 'Your coach will surface personalized tips here based on your schedule and quiz results.';
  String get refreshRecommendations =>
      _isArabic ? 'تحديث التوصيات' : 'Refresh recommendations';
  String get recommendationsUpdated =>
      _isArabic ? 'تم تحديث التوصيات.' : 'Recommendations updated.';
  String get couldNotGenerateRecommendations => _isArabic
      ? 'تعذّر إنشاء التوصيات الآن.'
      : 'Could not generate recommendations right now.';
  String get justNow => _isArabic ? 'الآن' : 'Just now';
  String lastGeneratedAt(String label) =>
      _isArabic ? 'آخر إنشاء: $label' : 'Last generated: $label';
  String percentComplete(int percent) =>
      _isArabic ? 'مكتمل $percent٪' : '$percent% complete';
  String completedTasks(int completed, int total) =>
      _isArabic ? '$completed من $total مهام' : '$completed of $total tasks';
  String minutesShort(int minutes) =>
      _isArabic ? '$minutes دقيقة' : '$minutes min';
  String get startFocusSession => _isArabic ? 'بدء التركيز' : 'Start focus';
  String get startFocusSessionTooltip =>
      _isArabic ? 'بدء جلسة تركيز' : 'Start focus session';
  String get focusModeTitle => _isArabic ? 'وضع التركيز' : 'Focus mode';
  String focusModeSubtitle(int minutes) => _isArabic
      ? 'جلسة تركيز لمدة $minutes دقيقة'
      : '$minutes-minute focus session';
  String get focusSessionRunning =>
      _isArabic ? 'ركّز على هذه الجلسة الآن.' : 'Stay with this session.';
  String get focusSessionPaused => _isArabic ? 'متوقف مؤقتًا' : 'Paused';
  String get pauseFocusSession => _isArabic ? 'إيقاف مؤقت' : 'Pause';
  String get resumeFocusSession => _isArabic ? 'استئناف' : 'Resume';
  String get finishFocusSession =>
      _isArabic ? 'إنهاء وتحديدها كمكتملة' : 'Finish and mark complete';
  String get focusSessionCompleted =>
      _isArabic ? 'تم إكمال جلسة التركيز.' : 'Focus session completed.';

  String get planDayNothingScheduled => _isArabic
      ? 'لا توجد جلسات مجدولة لهذا اليوم. اضغط «إضافة إلى الجدول» لإظهار المواضيع هنا.'
      : 'Nothing scheduled for this day yet. Tap Add to schedule to place topics on your calendar.';
  String get addSchedule => _isArabic ? 'إضافة إلى الجدول' : 'Add to schedule';
  String get addToScheduleSheetTitle =>
      _isArabic ? 'جدولة جلسة' : 'Schedule a session';
  String scheduleSessionForDay(String dayLabel) =>
      _isArabic ? 'التاريخ: $dayLabel' : 'Date: $dayLabel';
  String get topicForSession => _isArabic ? 'الموضوع' : 'Topic';
  String get studyTime => _isArabic ? 'وقت الدراسة' : 'Study time';
  String get pickTime => _isArabic ? 'اختيار الوقت' : 'Pick time';
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

  String get quizLinkCourseRequiredTitle =>
      _isArabic ? 'المقرر والمواضيع (مطلوب)' : 'Course & topics (required)';
  String get quizLinkCourseRequiredHint => _isArabic
      ? 'اختر المقرر والمواضيع حتى يُربط الاختبار بالسجل وتظهر نقاط الضعف بوضوح.'
      : 'Pick your course and topics so each quiz is tied to your courses and weak areas are clear.';
  String get quizSelectCoursePlaceholder =>
      _isArabic ? 'اختر مقررًا' : 'Select a course';
  String get quizCourseRequired =>
      _isArabic ? 'يرجى اختيار مقرر.' : 'Please select a course.';
  String get quizTopicsPickAtLeastOne => _isArabic
      ? 'اختر موضوعًا واحدًا على الأقل لهذا المقرر.'
      : 'Select at least one topic for this course.';
  String get quizNoCoursesAddFirst => _isArabic
      ? 'أضف مقررًا من الملف الشخصي ← «موادي ومقرراتي» قبل إنشاء الاختبار.'
      : 'Add a course under Profile → My courses before generating a quiz.';
  String get quizEnterTopicsWhenCourseHasNone => _isArabic
      ? 'لا توجد مواضيع في هذا المقرر بعد. أضف مواضيع من «موادي ومقرراتي» أو اكتب المواضيع في الحقل أدناه.'
      : 'This course has no topics yet. Add topics in My courses, or enter topics in the field below.';
  String get quizTopicsFieldRequiredForCourse => _isArabic
      ? 'أدخل المواضيع في الحقل أدناه (المقرر لا يحتوي مواضيع بعد).'
      : 'Enter topics in the field below (this course has no topic list yet).';
  String get quizFillTopicsFromSelection => _isArabic
      ? 'نسخ المواضيع المحددة إلى الحقل'
      : 'Copy selected topics into field';
  String get quizLinkedScopeLabel => _isArabic ? 'نطاق الاختبار' : 'Quiz scope';
  String get quizHistoryCourseLink => _isArabic ? 'المقرر' : 'Course';
  String get quizHistoryTopicsLink =>
      _isArabic ? 'المواضيع المرتبطة' : 'Linked topics';

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
  String get quizQuestionStyle =>
      _isArabic ? 'أسلوب الأسئلة' : 'Question style';
  String get quizStyleBalanced => _isArabic ? 'متوازن' : 'Balanced';
  String get quizStyleDefinitions =>
      _isArabic ? 'تعريفات ومصطلحات' : 'Definitions & terms';
  String get quizStyleApplication =>
      _isArabic ? 'تطبيق وسيناريوهات' : 'Application & scenarios';
  String get quizStyleExam => _isArabic ? 'أسلوب امتحان' : 'Exam-style';
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

  String get quizReport => _isArabic ? 'تقرير الاختبار' : 'Quiz report';
  String get downloadQuizReport =>
      _isArabic ? 'تنزيل تقرير الاختبار' : 'Download quiz report';
  String get couldNotExportQuizReport => _isArabic
      ? 'تعذّر إنشاء تقرير الاختبار. حاول مرة أخرى.'
      : 'Could not generate the quiz report. Please try again.';

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
  String get googleCalendarSync =>
      _isArabic ? 'تقويم Google' : 'Google Calendar';
  String get googleConnected => _isArabic ? 'متصل' : 'Connected';
  String get googleNotConnected => _isArabic ? 'غير متصل' : 'Not connected';
  String get connectGoogleCalendar => _isArabic ? 'مزامنة' : 'Sync';
  String get disconnectGoogleCalendar => _isArabic ? 'فصل' : 'Disconnect';
  String get reconnectGoogleCalendar =>
      _isArabic ? 'إعادة ربط Google Calendar' : 'Reconnect Google Calendar';
  String get googleConnectedSuccess => _isArabic
      ? 'تم ربط Google Calendar بنجاح.'
      : 'Google Calendar connected successfully.';
  String get googleDisconnectedSuccess =>
      _isArabic ? 'تم فصل Google Calendar.' : 'Google Calendar disconnected.';
  String get googleConnectFailed => _isArabic
      ? 'تعذّر ربط Google Calendar. حاول مرة أخرى.'
      : 'Could not connect Google Calendar. Please try again.';
  String get googleDisconnectFailed => _isArabic
      ? 'تعذّر فصل Google Calendar.'
      : 'Could not disconnect Google Calendar.';
  String get googleMissingConfig => _isArabic
      ? 'إعدادات Google Calendar غير مكتملة في التطبيق.'
      : 'Google Calendar setup is missing in app configuration.';
  String get googleAuthorizationCancelled => _isArabic
      ? 'تم إلغاء تفويض Google Calendar.'
      : 'Google Calendar authorization was cancelled.';
  String get addCourse => _isArabic ? 'إضافة مقرر' : 'Add course';
  String get editCourse => _isArabic ? 'تعديل المقرر' : 'Edit course';
  String get deleteCourse => _isArabic ? 'حذف المقرر' : 'Delete course';
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
  String get courseUpdated =>
      _isArabic ? 'تم تحديث المقرر.' : 'Course updated.';
  String get courseDeleted => _isArabic ? 'تم حذف المقرر.' : 'Course deleted.';
  String get couldNotSaveCourse =>
      _isArabic ? 'تعذّر حفظ المقرر.' : 'Could not save course.';
  String get couldNotUpdateCourse =>
      _isArabic ? 'تعذّر تحديث المقرر.' : 'Could not update course.';
  String get couldNotDeleteCourse =>
      _isArabic ? 'تعذّر حذف المقرر.' : 'Could not delete course.';
  String get deleteCourseTitle => _isArabic ? 'حذف المقرر؟' : 'Delete course?';
  String get deleteCourseConfirm => _isArabic
      ? 'سيتم حذف هذا المقرر وجميع المواضيع التابعة له.'
      : 'This will delete the course and all its topics.';
  String get signInToManageCourses => _isArabic
      ? 'سجّل الدخول لإدارة مقرراتك ومواضيعك.'
      : 'Sign in to manage your courses and topics.';
  String get unnamedCourse => _isArabic ? 'مقرر بدون اسم' : 'Untitled course';
  String get academicTasks =>
      _isArabic ? 'المهام والمواعيد الدراسية' : 'Academic tasks & deadlines';
  String get academicTasksShort =>
      _isArabic ? 'المهام والمواعيد' : 'Tasks & deadlines';
  String get addAcademicTask =>
      _isArabic ? 'إضافة مهمة دراسية' : 'Add academic task';
  String get editAcademicTask =>
      _isArabic ? 'تعديل المهمة الدراسية' : 'Edit academic task';
  String get deleteAcademicTask => _isArabic ? 'حذف المهمة' : 'Delete task';
  String get deleteAcademicTaskTitle =>
      _isArabic ? 'حذف المهمة؟' : 'Delete task?';
  String get deleteAcademicTaskConfirm => _isArabic
      ? 'سيتم حذف هذه المهمة والموعد المرتبط بها.'
      : 'This will delete the task and its deadline.';
  String get academicTaskTitle => _isArabic ? 'عنوان المهمة' : 'Task title';
  String get academicTaskTitleRequired =>
      _isArabic ? 'يرجى إدخال عنوان المهمة.' : 'Please enter a task title.';
  String get academicTaskType => _isArabic ? 'نوع المهمة' : 'Task type';
  String get academicTaskCourseOptional =>
      _isArabic ? 'المقرر (اختياري)' : 'Course (optional)';
  String get academicTaskNoCourse =>
      _isArabic ? 'بدون مقرر محدد' : 'No specific course';
  String get academicTaskDueDate => _isArabic ? 'تاريخ التسليم' : 'Due date';
  String get academicTaskEstimatedMinutes =>
      _isArabic ? 'الوقت المتوقع بالدقائق' : 'Estimated minutes';
  String get academicTaskPriority => _isArabic ? 'الأولوية' : 'Priority';
  String get academicTaskNotesOptional =>
      _isArabic ? 'ملاحظات (اختياري)' : 'Notes (optional)';
  String get academicTasksEmptyHint => _isArabic
      ? 'أضف واجبات، مشاريع، قراءات، مختبرات، عروض، اختبارات قصيرة، أو مواعيد الفصل لتظهر هنا.'
      : 'Add homework, projects, readings, labs, presentations, quizzes, or semester deadlines to track everything in one place.';
  String get upcomingDeadlines =>
      _isArabic ? 'المواعيد القادمة' : 'Upcoming deadlines';
  String get noUpcomingDeadlines => _isArabic
      ? 'لا توجد مواعيد دراسية مفتوحة حالياً.'
      : 'No open academic deadlines right now.';
  String get viewAllDeadlines => _isArabic ? 'عرض' : 'View';
  String get academicTaskSaved => _isArabic ? 'تم حفظ المهمة.' : 'Task saved.';
  String get academicTaskUpdated =>
      _isArabic ? 'تم تحديث المهمة.' : 'Task updated.';
  String get academicTaskDeleted =>
      _isArabic ? 'تم حذف المهمة.' : 'Task deleted.';
  String get academicTaskCompleted =>
      _isArabic ? 'تم إكمال المهمة.' : 'Task completed.';
  String get academicTaskReopened =>
      _isArabic ? 'تمت إعادة فتح المهمة.' : 'Task reopened.';
  String get couldNotSaveAcademicTask =>
      _isArabic ? 'تعذّر حفظ المهمة.' : 'Could not save task.';
  String get couldNotUpdateAcademicTask =>
      _isArabic ? 'تعذّر تحديث المهمة.' : 'Could not update task.';
  String get couldNotDeleteAcademicTask =>
      _isArabic ? 'تعذّر حذف المهمة.' : 'Could not delete task.';
  String get couldNotToggleAcademicTask =>
      _isArabic ? 'تعذّر تحديث حالة المهمة.' : 'Could not update task status.';
  String academicTaskTypeLabel(String value) {
    switch (value) {
      case 'homework':
        return _isArabic ? 'واجب' : 'Homework';
      case 'project':
        return _isArabic ? 'مشروع' : 'Project';
      case 'quiz':
        return _isArabic ? 'اختبار قصير' : 'Quiz';
      case 'lab':
        return _isArabic ? 'مختبر' : 'Lab';
      case 'presentation':
        return _isArabic ? 'عرض تقديمي' : 'Presentation';
      case 'reading':
        return _isArabic ? 'قراءة' : 'Reading';
      case 'exam':
        return _isArabic ? 'امتحان' : 'Exam';
      case 'semesterDeadline':
        return _isArabic ? 'موعد فصلي' : 'Semester deadline';
      default:
        return _isArabic ? 'أخرى' : 'Other';
    }
  }

  String academicTaskPriorityLabel(String value) {
    switch (value) {
      case 'low':
        return _isArabic ? 'منخفضة' : 'Low';
      case 'high':
        return _isArabic ? 'عالية' : 'High';
      default:
        return _isArabic ? 'متوسطة' : 'Medium';
    }
  }

  String academicTaskDueToday(String formatted) =>
      _isArabic ? 'اليوم، $formatted' : 'Today, $formatted';
  String academicTaskDueTomorrow(String formatted) =>
      _isArabic ? 'غداً، $formatted' : 'Tomorrow, $formatted';
  String academicTaskDueInDays(int days, String formatted) =>
      _isArabic ? 'بعد $days أيام، $formatted' : 'In $days days, $formatted';
  String academicTaskOverdue(int days, String formatted) => _isArabic
      ? 'متأخرة $days أيام، $formatted'
      : '$days days overdue, $formatted';
  String get addTopic => _isArabic ? 'إضافة موضوع' : 'Add topic';
  String get editTopic => _isArabic ? 'تعديل الموضوع' : 'Edit topic';
  String get deleteTopic => _isArabic ? 'حذف الموضوع' : 'Delete topic';
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
  String get topicUpdated => _isArabic ? 'تم تحديث الموضوع.' : 'Topic updated.';
  String get topicDeleted => _isArabic ? 'تم حذف الموضوع.' : 'Topic deleted.';
  String get couldNotSaveTopic =>
      _isArabic ? 'تعذّر حفظ الموضوع.' : 'Could not save topic.';
  String get couldNotUpdateTopic =>
      _isArabic ? 'تعذّر تحديث الموضوع.' : 'Could not update topic.';
  String get couldNotDeleteTopic =>
      _isArabic ? 'تعذّر حذف الموضوع.' : 'Could not delete topic.';
  String get deleteTopicTitle => _isArabic ? 'حذف الموضوع؟' : 'Delete topic?';
  String get deleteTopicConfirm => _isArabic
      ? 'سيتم حذف هذا الموضوع من المقرر.'
      : 'This topic will be removed from the course.';
  String get clearExamDate => _isArabic ? 'إزالة التاريخ' : 'Clear date';
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
  String get progressLoadFailed => _isArabic
      ? 'تعذّر تحميل التقدم حالياً. تحقق من الاتصال وحاول مرة أخرى.'
      : 'Could not load progress right now. Check your connection and try again.';
  String get retry => _isArabic ? 'إعادة المحاولة' : 'Retry';

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

  String get dailyStudyBudgetTitle =>
      _isArabic ? 'الوقت اليومي للدراسة' : 'Daily study time';
  String get dailyStudyBudgetHint => _isArabic
      ? 'يستخدمه المخطط لتوزيع الجلسات المقترحة بحسب أولوية كل موضوع.'
      : 'Used by the planner to divide suggested sessions by topic priority.';
  String dailyStudyBudgetValue(int minutes) {
    if (minutes < 60) {
      return _isArabic ? '$minutes دقيقة' : '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (remainder == 0) {
      return _isArabic
          ? (hours == 1 ? 'ساعة واحدة' : '$hours ساعات')
          : (hours == 1 ? '1 hr' : '$hours hrs');
    }
    return _isArabic ? '$hours س $remainder د' : '${hours}h ${remainder}m';
  }

  String get planTodayMinutesLabel =>
      _isArabic ? 'وقت اليوم' : 'Today’s budget';
  String get planTomorrowMinutesLabel =>
      _isArabic ? 'وقت الغد' : 'Tomorrow’s budget';
  String get planUpcomingMinutesLabel =>
      _isArabic ? 'وقت اليوم المختار' : 'Day budget';
  String planMinutesAllocatedSummary(int allocated, int budget) => _isArabic
      ? 'تم توزيع $allocated من $budget دقيقة على أولوياتك.'
      : 'Allocated $allocated of $budget minutes across your priorities.';

  String get whyThisPlanChanged =>
      _isArabic ? 'لماذا تغيّرت الخطة' : 'Why this plan changed';
  String recommendationPlanChanged(String topic, String dayLabel) => _isArabic
      ? 'كان أداؤك منخفضًا في $topic، لذلك تعطي خطة $dayLabel أولوية أكبر له.'
      : 'You scored low on $topic, so $dayLabel’s plan now gives it more time.';
  String get planDayTodayInline => _isArabic ? 'اليوم' : 'today';
  String get planDayTomorrowInline => _isArabic ? 'الغد' : 'tomorrow';
  String get planDaySelectedInline =>
      _isArabic ? 'اليوم المحدد' : 'the selected day';
  String get planAdjustedReasonsHeader => _isArabic
      ? 'تكيّف المخطط بناءً على هذه الإشارات'
      : 'The planner adjusted from these signals';
  String adjustedTopicLine(String topic, String reason) =>
      _isArabic ? '• $topic: $reason' : '• $topic: $reason';
  String get reasonLowQuiz =>
      _isArabic ? 'أداء ضعيف في الاختبارات' : 'low quiz performance';
  String get reasonExamSoon => _isArabic ? 'امتحان قريب' : 'upcoming exam';
  String get reasonMissed => _isArabic ? 'جلسات فائتة' : 'missed sessions';
  String get reasonStale =>
      _isArabic ? 'لم تُدرَس منذ فترة' : 'long time since last study';
  String get reasonBaseline =>
      _isArabic ? 'تخصيص أساسي' : 'baseline personalization';

  String missedSessionsBadge(int count) => _isArabic
      ? (count == 1 ? 'جلسة فائتة' : '$count جلسات فائتة')
      : (count == 1 ? '1 missed session' : '$count missed sessions');
  String lastStudiedAgo(int daysAgo) {
    if (daysAgo <= 0) {
      return _isArabic ? 'دُرِس اليوم' : 'Studied today';
    }
    if (daysAgo == 1) {
      return _isArabic ? 'دُرِس أمس' : 'Studied yesterday';
    }
    return _isArabic
        ? 'آخر دراسة قبل $daysAgo أيام'
        : 'Last studied $daysAgo days ago';
  }

  String get planEmptyStudyBudget => _isArabic
      ? 'اضبط وقت الدراسة اليومي من الملف الشخصي لرؤية اقتراحات الخطة.'
      : 'Set a daily study time in your profile to see plan suggestions.';
}
