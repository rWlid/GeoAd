class AppStrings {
  const AppStrings._();

  static const String appName = 'Geo-Ad';

  static const String tabMap = 'الخريطة';
  static const String tabMyAds = 'إعلاناتي';
  static const String tabAccount = 'حسابي';
  static const String tabStore = 'متجري';

  static const String startLoading = 'حسابك يحمل…';
  static const String startErrorTitle = 'حدث خطأ أثناء تحميل بيانات حسابك';
  static const String retry = 'إعادة المحاولة';
  static const String useAnotherNumber = 'استخدام رقم آخر';

  static const String loginTitle = 'تسجيل الدخول';
  static const String phoneHeading = 'أدخل رقم جوالك';
  static const String phoneBody = 'سجل دخولك برقم جوالك، بدون كلمة مرور.';
  static const String phoneLabel = 'رقم الجوال';
  static const String phoneHint = '05XXXXXXXX';
  static const String continueButton = 'متابعة';

  static const String codeTitle = 'رمز التحقق';
  static const String codeHeading = 'أدخل رمز التحقق للرقم';
  static const String changeNumber = 'تغيير الرقم';
  static const String codeLabel = 'رمز التحقق';
  static const String signInButton = 'دخول';

  static const String nameTitle = 'إكمال التسجيل';
  static const String nameHeading = 'ما اسمك؟';
  static const String nameBody =
      'يظهر اسمك للمشترين في إعلاناتك، إلا في حساب المتجر فيظهر اسم النشاط التجاري.';
  static const String nameLabel = 'الاسم';
  static const String accountTypeLabel = 'نوع الحساب';
  static const String accountTypeIndividual = 'فرد';
  static const String accountTypeStore = 'متجر';
  static const String accountTypeHint = 'لا يمكنك تغيير نوع الحساب لاحقا';
  static const String errorAccountTypeRequired = 'اختر نوع الحساب';
  static const String saveButton = 'حفظ';

  static const String accountLoading = 'بياناتك تحمل الان…';
  static const String accountErrorTitle = 'حدث خطأ أثناء تحميل بياناتك';
  static const String logoutButton = 'تسجيل الخروج';
  static const String logoutConfirmTitle = 'متأكد من تسجيل الخروج؟';
  static const String logoutConfirmBody =
      'ستحتاج إلى رقم جوالك لتسجيل الدخول مرة أخرى.';
  static const String logoutConfirmAction = 'خروج';
  static const String cancel = 'إلغاء';

  static const String businessNameLabel = 'اسم النشاط';
  static const String businessLogoLabel = 'الشعار (اختياري)';
  static const String businessNoLogo = 'بدون شعار';
  static const String businessPickLogo = 'اختيار شعار';
  static const String businessChangeLogo = 'تغيير الشعار';
  static const String businessRemoveLogo = 'إزالة الشعار';
  static const String businessLogoPreparing = 'جار تجهيز الشعار…';
  static const String errorInvalidBusinessName =
      'اسم النشاط يجب أن يكون من حرفين إلى 50 حرف';
  static const String errorLogoTooLarge =
      'حجم الشعار أكبر من 5 ميجابايت، اختر صورة أصغر';
  static const String errorLogoUnreadable =
      'حاول اختيار صورة أخرى، لم نتمكن من قراءة الصورة التي اخترتها';

  static const String mapLoading = 'جار تحميل الإعلانات القريبة…';
  static const String mapErrorTitle = 'تعذر تحميل الإعلانات القريبة';
  static const String mapEmpty = 'لا توجد إعلانات قريبة حاليًا';

  static const String searchRadius = 'نطاق البحث';

  static const String kilometers = 'كم';

  static const String locationLocating = 'يتم تحديد موقعك…';
  static const String locationDeniedTitle = 'لم تسمح بالوصول إلى موقعك';
  static const String locationTapHint =
      'اضغط على الخريطة لتحديد نقطة تبحث حولها.';
  static const String locationAllow = 'السماح بالوصول للموقع';
  static const String locationDeniedForeverTitle = 'إذن الموقع مرفوض';
  static const String locationDeniedForeverBody =
      'اسمح بالوصول إلى موقعك من إعدادات التطبيق، أو اضغط على الخريطة لتحديد نقطة تبحث حولها.';
  static const String locationOpenSettings = 'فتح الإعدادات';
  static const String locationServicesOffTitle = 'خدمة الموقع متوقفة';
  static const String locationServicesOffBody =
      'شغل خدمة الموقع في جهازك، أو اضغط على الخريطة لتحديد نقطة تبحث حولها.';
  static const String locationTurnOn = 'تشغيل الموقع';
  static const String locationManualCenter =
      'تبحث حول النقطة التي اخترتها. اضغط على الخريطة لتغييرها.';
  static const String errorLocationUnavailable =
      'تعذر تحديد موقعك، حاول مرة أخرى';

  static const String errorNoConnection = 'لا يوجد اتصال بالإنترنت';
  static const String errorPermissionDenied =
      'ليست لديك صلاحية لتنفيذ هذا الإجراء';
  static const String errorValidation =
      'بعض البيانات غير صحيحة، راجعها وحاول مرة أخرى';
  static const String errorInvalidPhone = 'أدخل رقم جوال سعودي صحيح يبدأ بـ 05';
  static const String errorInvalidCode = 'أدخل رمز التحقق المكون من 4 أرقام';
  static const String errorInvalidName =
      'الاسم يجب أن يكون من حرفان إلى 40 حرف';
  static const String errorUnknown = 'حدث خطأ غير متوقع، حاول مرة أخرى';

  static const String missingEnvTitle = 'إعدادات التشغيل ناقصة';
  static const String missingEnvBody =
      'العنوان والمفتاح العام لـSupabase لم نجدها.\nتأكد من وجود ملف .env في مجلد المشروع، ثم أعد تشغيل التطبيق.';
  static const String startupFailedTitle = 'تعذر تشغيل التطبيق';
  static const String startupFailedBody =
      'تأكد من اتصالك بالإنترنت ثم أعد تشغيل التطبيق.';

  static const String runWithEnvCommand = '';
}
