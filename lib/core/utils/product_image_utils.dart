typedef ProductImageUrlBuilder = String Function(String normalizedPath);

List<String> normalizeProductImages(
  dynamic raw, {
  required ProductImageUrlBuilder toPublicUrl,
}) {
  if (raw is! List) return const [];

  return raw
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .map((value) {
        if (value.startsWith('http://') || value.startsWith('https://')) {
          return value;
        }
        final normalized = value.startsWith('/') ? value.substring(1) : value;
        return toPublicUrl(normalized);
      })
      .toList();
}
