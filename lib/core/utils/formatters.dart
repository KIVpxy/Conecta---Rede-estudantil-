import 'package:intl/intl.dart';

/// Formatadores pt-BR.
class Fmt {
  Fmt._();

  static final _thousands = NumberFormat('#,##0', 'pt_BR');

  /// 4850 -> "4.850"
  static String number(num value) => _thousands.format(value);

  /// "há 2 horas", "há 3 dias", "ontem"
  static String relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'agora mesmo';
    if (diff.inMinutes < 60) {
      return 'há ${diff.inMinutes} ${diff.inMinutes == 1 ? 'minuto' : 'minutos'}';
    }
    if (diff.inHours < 24) {
      return 'há ${diff.inHours} ${diff.inHours == 1 ? 'hora' : 'horas'}';
    }
    if (diff.inDays == 1) return 'ontem';
    if (diff.inDays < 30) {
      return 'há ${diff.inDays} dias';
    }
    if (diff.inDays < 365) {
      final months = diff.inDays ~/ 30;
      return 'há $months ${months == 1 ? 'mês' : 'meses'}';
    }
    final years = diff.inDays ~/ 365;
    return 'há $years ${years == 1 ? 'ano' : 'anos'}';
  }

  /// 9.1 -> "9,1"
  static String rating(double value) =>
      value.toStringAsFixed(1).replaceAll('.', ',');

  /// DateTime -> "12/03/2026"
  static String date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// 8.4 MB etc.
  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1).replaceAll('.', ',')} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }
}
