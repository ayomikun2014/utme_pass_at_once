class VersionHelper {
  /// Compares two version strings.
  /// Returns:
  ///  1 if v1 > v2
  /// -1 if v1 < v2
  ///  0 if v1 == v2
  static int compare(String v1, String v2) {
    List<int> v1Parts = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> v2Parts = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    int maxLength = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;

    for (int i = 0; i < maxLength; i++) {
      int p1 = i < v1Parts.length ? v1Parts[i] : 0;
      int p2 = i < v2Parts.length ? v2Parts[i] : 0;

      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }

    return 0;
  }

  static bool isLessThan(String current, String target) {
    return compare(current, target) < 0;
  }
}
