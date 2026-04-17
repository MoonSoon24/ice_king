class AppFormatters {
  AppFormatters._();

  static String currencyIdr(dynamic value) {
    final number = num.tryParse(value?.toString() ?? '');
    if (number == null) return '-';

    final isNegative = number < 0;
    final absValue = number.abs();
    final integerPart = absValue.truncate();
    final decimalPart = absValue - integerPart;

    final grouped = _groupThousands(integerPart);
    if (decimalPart == 0) {
      return '${isNegative ? '-' : ''}Rp $grouped';
    }

    final decimal = decimalPart
        .toStringAsFixed(2)
        .split('.')
        .last
        .replaceFirst(RegExp(r'0+$'), '');

    return '${isNegative ? '-' : ''}Rp $grouped,${decimal.isEmpty ? '00' : decimal}';
  }

  static String _groupThousands(int number) {
    final raw = number.toString();
    final chunks = <String>[];

    for (int i = raw.length; i > 0; i -= 3) {
      final start = (i - 3) < 0 ? 0 : i - 3;
      chunks.insert(0, raw.substring(start, i));
    }
    return chunks.join('.');
  }
}
