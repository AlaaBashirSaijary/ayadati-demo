/// What could be read out of a patient's WhatsApp booking message. Every
/// field is optional — a free-text "بدي موعد بكرا الساعة ٥" yields only a day
/// and time, a message from the structured booking link yields everything.
/// The result is only ever a *suggestion* that pre-fills the booking form;
/// the doctor confirms or corrects it there.
class BookingRequest {
  const BookingRequest({
    this.name,
    this.phone,
    this.day,
    this.hour,
    this.minute,
    this.period,
    this.reason,
  });

  final String? name;

  /// Digits only, in local 09XXXXXXXX form when it's a Syrian mobile.
  final String? phone;
  final DateTime? day;
  final int? hour;
  final int? minute;

  /// "morning" / "evening" when the patient gave a part of the day instead of
  /// an exact time.
  final String? period;
  final String? reason;

  bool get isEmpty =>
      name == null &&
      phone == null &&
      day == null &&
      hour == null &&
      period == null &&
      reason == null;

  /// Exact time if given; otherwise a sensible start of the named period.
  ({int hour, int minute})? get time {
    if (hour != null) return (hour: hour!, minute: minute ?? 0);
    return switch (period) {
      'morning' => (hour: 10, minute: 0),
      'evening' => (hour: 17, minute: 0),
      _ => null,
    };
  }
}

/// Reads a booking request out of pasted WhatsApp text — no AI and no
/// network: a fixed "label: value" format (what the clinic's booking link
/// produces) is read exactly, and anything else falls back to recognizing
/// Syrian-dialect day/time phrases and a mobile number.
class BookingRequestParser {
  const BookingRequestParser._();

  static const _weekdays = {
    'الاثنين': DateTime.monday,
    'الاتنين': DateTime.monday,
    'الثلاثاء': DateTime.tuesday,
    'التلاتاء': DateTime.tuesday,
    'الاربعاء': DateTime.wednesday,
    'الخميس': DateTime.thursday,
    'الجمعة': DateTime.friday,
    'السبت': DateTime.saturday,
    'الاحد': DateTime.sunday,
  };

  static const _nameKeys = ['الاسم', 'اسم المريض', 'الاسم الكامل'];
  static const _phoneKeys = ['الهاتف', 'رقم الهاتف', 'الجوال', 'رقم الجوال'];
  static const _dayKeys = ['اليوم', 'التاريخ', 'يوم الحجز'];
  static const _timeKeys = ['الوقت', 'الفترة', 'الساعة'];
  static const _reasonKeys = ['السبب', 'سبب الزيارة', 'الشكوى'];

  static BookingRequest parse(String text, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final normalized = _normalize(text);
    // Values keep the sender's own spelling (a name must stay "فاطمة", not
    // "فاطمه"); only the keys and the keyword searches use normalized text.
    final fields = _labelledFields(_asciiDigits(text));

    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = fields[_normalizeKey(key)];
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    final dayText = pick(_dayKeys);
    final timeText = pick(_timeKeys);
    final normalizedDay = dayText == null ? null : _normalize(dayText);
    final normalizedTime = timeText == null ? null : _normalize(timeText);

    final phone = _findPhone(pick(_phoneKeys) ?? normalized);
    final day =
        _findDay(normalizedDay ?? normalized, today) ??
        (normalizedDay != null ? null : _findDay(normalized, today));
    final time = _findTime(normalizedTime ?? normalized);
    final period = _findPeriod(normalizedTime ?? normalized);

    return BookingRequest(
      name: pick(_nameKeys) ?? _freeTextName(text),
      phone: phone,
      day: day,
      hour: time?.hour,
      minute: time?.minute,
      period: time == null ? period : null,
      reason: pick(_reasonKeys),
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Unifies Arabic-Indic digits and the alef/ta-marbuta/ya spelling
  /// variants so one keyword list matches how people actually type.
  static String _normalize(String input) {
    final buffer = StringBuffer();
    for (final unit in input.runes) {
      if (unit >= 0x0660 && unit <= 0x0669) {
        buffer.writeCharCode(unit - 0x0660 + 0x30);
      } else if (unit >= 0x06F0 && unit <= 0x06F9) {
        buffer.writeCharCode(unit - 0x06F0 + 0x30);
      } else {
        buffer.writeCharCode(unit);
      }
    }
    return buffer
        .toString()
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp('[ً-ْـ]'), '');
  }

  static String _normalizeKey(String key) => _normalize(key).trim();

  static String _asciiDigits(String input) {
    final buffer = StringBuffer();
    for (final unit in input.runes) {
      if (unit >= 0x0660 && unit <= 0x0669) {
        buffer.writeCharCode(unit - 0x0660 + 0x30);
      } else if (unit >= 0x06F0 && unit <= 0x06F9) {
        buffer.writeCharCode(unit - 0x06F0 + 0x30);
      } else {
        buffer.writeCharCode(unit);
      }
    }
    return buffer.toString();
  }

  static Map<String, String> _labelledFields(String text) {
    final result = <String, String>{};
    for (final line in text.split('\n')) {
      final index = line.indexOf(RegExp('[:：]'));
      if (index <= 0) continue;
      final key = line.substring(0, index).replaceAll(RegExp(r'[*_•\-]'), '');
      final value = line.substring(index + 1).trim();
      if (value.isEmpty) continue;
      result[_normalizeKey(key)] = value;
    }
    return result;
  }

  static String? _findPhone(String text) {
    for (final match in RegExp(r'\+?[\d][\d\s\-]{7,15}\d').allMatches(text)) {
      var digits = match.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.startsWith('00963')) digits = digits.substring(5);
      if (digits.startsWith('963')) digits = digits.substring(3);
      if (digits.startsWith('0')) digits = digits.substring(1);
      if (digits.length == 9 && digits.startsWith('9')) return '0$digits';
    }
    return null;
  }

  static DateTime? _findDay(String text, DateTime today) {
    if (text.contains('بعد بكرا') ||
        text.contains('بعد بكره') ||
        text.contains('بعد غد')) {
      return today.add(const Duration(days: 2));
    }
    if (RegExp('بكر[اه]|غدا|باكر').hasMatch(text)) {
      return today.add(const Duration(days: 1));
    }
    if (text.contains('اليوم') || text.contains('الليله')) return today;

    final numeric = RegExp(
      r'(\d{1,2})\s*[/\-.]\s*(\d{1,2})(?:\s*[/\-.]\s*(\d{2,4}))?',
    ).firstMatch(text);
    if (numeric != null) {
      final d = int.parse(numeric.group(1)!);
      final m = int.parse(numeric.group(2)!);
      if (d >= 1 && d <= 31 && m >= 1 && m <= 12) {
        var year = today.year;
        final y = numeric.group(3);
        if (y != null) {
          year = int.parse(y);
          if (year < 100) year += 2000;
        }
        var candidate = DateTime(year, m, d);
        if (y == null && candidate.isBefore(today)) {
          candidate = DateTime(year + 1, m, d);
        }
        return candidate;
      }
    }

    for (final entry in _weekdays.entries) {
      if (text.contains(entry.key) ||
          text.contains(entry.key.replaceFirst('ال', ''))) {
        final delta = (entry.value - today.weekday) % 7;
        return today.add(Duration(days: delta));
      }
    }
    return null;
  }

  static ({int hour, int minute})? _findTime(String text) {
    final match =
        RegExp(
          r'(?:الساع[هة]|ساع[هة])\s*(\d{1,2})(?:[:.](\d{2}))?',
        ).firstMatch(text) ??
        RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(text);
    if (match == null) return null;

    var hour = int.parse(match.group(1)!);
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    if (hour > 23 || minute > 59) return null;

    final isEvening = RegExp(
      'مساء|مسا|عصر|بالليل|ليلا|بعد الظهر',
    ).hasMatch(text);
    final isMorning = RegExp('صباح|الصبح|صبحا').hasMatch(text);
    final isNoon = text.contains('ظهر');

    if (hour <= 12) {
      if (isEvening && hour < 12) {
        hour += 12;
      } else if (isNoon && hour < 6) {
        hour += 12;
      } else if (!isMorning && !isNoon && hour >= 1 && hour <= 6) {
        // A clinic doesn't see patients at 3 a.m.: a bare "الساعة 5" means
        // the afternoon.
        hour += 12;
      }
    }
    return (hour: hour, minute: minute);
  }

  static String? _findPeriod(String text) {
    if (RegExp('مسائي|مساء|عصر|بعد الظهر').hasMatch(text)) return 'evening';
    if (RegExp('صباحي|صباحا|الصبح|قبل الظهر').hasMatch(text)) return 'morning';
    return null;
  }

  /// "اسمي X" / "انا X" in a free-text message — up to four Arabic words.
  static String? _freeTextName(String original) {
    final match = RegExp(
      r'(?:اسمي|إسمي|أنا|انا)\s+((?:[ء-ي]+\s?){1,4})',
    ).firstMatch(original);
    final name = match?.group(1)?.trim();
    return (name == null || name.isEmpty) ? null : name;
  }
}
