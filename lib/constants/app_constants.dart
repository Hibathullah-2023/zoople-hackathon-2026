/// Nizhal App — Global Constants
class AppConstants {
  AppConstants._();

  // ─── App Info ───
  static const String appName = 'Nizhal';
  static const String appTagline = 'Shadow Against Drugs';
  static const String appVersion = '1.0.0';

  // ─── Report ID Format ───
  static const String reportIdPrefix = 'NZ';
  static const int reportIdLength = 5; // NZ-YYMMDD-XXXXX

  // ─── Anonymous ID Format ───
  static const String anonymousIdPrefix = 'NX';

  // ─── Limits ───
  static const int maxPhotosPerReport = 5;
  static const int maxDescriptionLength = 2000;
  static const int fakeReportThreshold = 3; // auto-suspend after 3 fake marks
  static const int maxPhotoSizeBytes = 5 * 1024 * 1024; // 5 MB per photo

  // ─── Aadhaar Hashing ───
  static const int pbkdf2Iterations = 100000;
  static const int saltLength = 32;
  static const int hashLength = 64;

  // ─── Report Statuses ───
  static const String statusSubmitted = 'submitted';
  static const String statusUnderReview = 'under_review';
  static const String statusAssigned = 'assigned';
  static const String statusInProgress = 'in_progress';
  static const String statusResolved = 'resolved';
  static const String statusClosed = 'closed';
  static const String statusFake = 'fake';

  static const List<String> statusPipeline = [
    statusSubmitted,
    statusUnderReview,
    statusAssigned,
    statusInProgress,
    statusResolved,
    statusClosed,
  ];

  // ─── Priorities ───
  static const String priorityCritical = 'critical';
  static const String priorityHigh = 'high';
  static const String priorityMedium = 'medium';
  static const String priorityLow = 'low';

  static const List<String> priorities = [
    priorityCritical,
    priorityHigh,
    priorityMedium,
    priorityLow,
  ];

  // ─── Categories ───
  static const String categoryTrafficking = 'trafficking';
  static const String categoryManufacturing = 'manufacturing';
  static const String categoryDrugSale = 'drug_sale';
  static const String categoryDrugUse = 'drug_use';
  static const String categoryPossession = 'possession';
  static const String categoryOther = 'other';

  static const Map<String, String> categoryLabels = {
    categoryTrafficking: 'Drug Trafficking',
    categoryManufacturing: 'Manufacturing / Lab',
    categoryDrugSale: 'Drug Sale / Distribution',
    categoryDrugUse: 'Drug Use',
    categoryPossession: 'Possession',
    categoryOther: 'Other',
  };

  static const List<String> categories = [
    categoryTrafficking,
    categoryManufacturing,
    categoryDrugSale,
    categoryDrugUse,
    categoryPossession,
    categoryOther,
  ];

  // ─── User Roles ───
  static const String roleUser = 'user';
  static const String roleAuthority = 'authority';
  static const String roleAdmin = 'admin';

  // ─── User Status ───
  static const String userActive = 'active';
  static const String userSuspended = 'suspended';
  static const String userBlocked = 'blocked';

  // ─── Firestore Collections ───
  static const String usersCollection = 'users';
  static const String reportsCollection = 'reports';
  static const String reportIdentitySubcollection = 'identity';
  static const String reportMediaSubcollection = 'media';
  static const String reportStatusLogSubcollection = 'statusLog';
  static const String authoritiesCollection = 'authorities';
  static const String aggregatesCollection = 'aggregates';
  static const String configCollection = 'config';
  static const String fcmTokensSubcollection = 'fcmTokens';

  // ─── Config Documents ───
  static const String priorityRulesDoc = 'priorityRules';
  static const String categoriesDoc = 'categories';
  static const String appSettingsDoc = 'appSettings';

  // ─── Storage Paths ───
  static const String reportMediaStoragePath = 'report_media';
}
