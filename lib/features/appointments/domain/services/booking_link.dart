/// The clinic's public booking link — a static page (docs/book.html on the
/// project's GitHub Pages site) that needs no server: everything it needs
/// travels in the link itself, and the patient's choices come back to the
/// doctor as a WhatsApp message in the fixed format BookingRequestParser
/// reads exactly.
class BookingLink {
  const BookingLink._();

  static const baseUrl =
      'https://alaabashirsaijary.github.io/ayadati-site/book.html';

  /// [days] uses DateTime weekday numbers (Monday=1 … Sunday=7); the page
  /// receives them as JavaScript day numbers (Sunday=0 … Saturday=6).
  static String build({
    required String clinicName,
    required String whatsappNumber,
    required Set<int> days,
    required int fromHour,
    required int toHour,
  }) {
    final jsDays = (days.map((d) => d % 7).toList()..sort()).join(',');
    final uri = Uri.parse(baseUrl).replace(
      queryParameters: {
        'c': clinicName.trim(),
        'w': whatsappNumber,
        'd': jsDays,
        'f': '$fromHour',
        't': '$toHour',
      },
    );
    return uri.toString();
  }
}
