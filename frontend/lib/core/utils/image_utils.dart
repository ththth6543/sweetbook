class ImageUtils {
  static String getProxyUrl(String originalUrl) {
    if (originalUrl.isEmpty) return "";
    return 'http://localhost:8000/api/v1/books/proxy-image?url=${Uri.encodeComponent(originalUrl)}';
  }
}
