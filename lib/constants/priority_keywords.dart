/// Priority keyword mapping and category weights for the auto-priority engine.
/// These are the LOCAL fallback rules. Server-side rules in `/config/priorityRules`
/// take precedence when available.
///
/// IMPORTANT: These rules are NEVER exposed to end users.
class PriorityKeywords {
  PriorityKeywords._();

  // ─── Critical Keywords ───
  // If any of these words/phrases appear in the description,
  // the report is classified as CRITICAL and bypasses admin.
  static const List<String> criticalKeywords = [
    'trafficking',
    'cartel',
    'armed',
    'weapon',
    'gun',
    'firearm',
    'manufacturing lab',
    'lab',
    'minors',
    'children',
    'child',
    'school zone',
    'school',
    'college',
    'university',
    'smuggling',
    'international',
    'cross border',
    'kidnap',
    'murder',
    'death',
    'overdose',
    'mass distribution',
    'syndicate',
    'network',
    'organized crime',
    'hostel',
  ];

  // ─── High Keywords ───
  static const List<String> highKeywords = [
    'large quantity',
    'bulk',
    'wholesale',
    'gang',
    'group',
    'repeat offender',
    'distribution',
    'dealing',
    'dealer',
    'peddler',
    'supplier',
    'regular supply',
    'daily supply',
    'injection',
    'needle',
    'heroin',
    'cocaine',
    'methamphetamine',
    'meth',
    'fentanyl',
    'mdma',
    'ecstasy',
    'lsd',
  ];

  // ─── Medium Keywords ───
  static const List<String> mediumKeywords = [
    'suspicious',
    'unusual activity',
    'transaction',
    'exchange',
    'package',
    'marijuana',
    'cannabis',
    'ganja',
    'weed',
    'hash',
    'pills',
    'tablets',
    'powder',
    'substance',
    'smoking',
  ];

  // ─── Category Priority Weights ───
  // Higher weight = higher priority baseline
  static const Map<String, int> categoryWeights = {
    'trafficking': 4,     // auto-CRITICAL
    'manufacturing': 4,   // auto-CRITICAL
    'drug_sale': 3,       // HIGH baseline
    'drug_use': 2,        // MEDIUM baseline
    'possession': 1,      // LOW baseline
    'other': 1,           // LOW baseline
  };

  // ─── Categories that always bypass admin ───
  static const List<String> bypassCategories = [
    'trafficking',
    'manufacturing',
  ];

  /// Calculate priority from description text and category.
  /// Returns a priority string: 'critical', 'high', 'medium', 'low'.
  static String calculatePriority(String description, String category) {
    final lowerDesc = description.toLowerCase();
    int score = 0;

    // Check critical keywords
    for (final keyword in criticalKeywords) {
      if (lowerDesc.contains(keyword.toLowerCase())) {
        score = 4;
        break;
      }
    }

    // Check high keywords (only upgrade, never downgrade)
    if (score < 3) {
      for (final keyword in highKeywords) {
        if (lowerDesc.contains(keyword.toLowerCase())) {
          score = 3;
          break;
        }
      }
    }

    // Check medium keywords
    if (score < 2) {
      for (final keyword in mediumKeywords) {
        if (lowerDesc.contains(keyword.toLowerCase())) {
          score = 2;
          break;
        }
      }
    }

    // Apply category weight — take the max of keyword score and category weight
    final categoryWeight = categoryWeights[category] ?? 1;
    score = score > categoryWeight ? score : categoryWeight;

    // Map score to priority
    if (score >= 4) return 'critical';
    if (score >= 3) return 'high';
    if (score >= 2) return 'medium';
    return 'low';
  }

  /// Determine if a report should bypass admin and go directly to authority.
  static bool shouldBypassAdmin(String priority, String category) {
    return priority == 'critical' ||
        priority == 'high' ||
        bypassCategories.contains(category);
  }

  /// Extract matched keywords from the description for audit purposes.
  static List<String> extractKeywords(String description) {
    final lowerDesc = description.toLowerCase();
    final matched = <String>[];

    for (final keyword in [...criticalKeywords, ...highKeywords, ...mediumKeywords]) {
      if (lowerDesc.contains(keyword.toLowerCase())) {
        matched.add(keyword);
      }
    }

    return matched;
  }
}
