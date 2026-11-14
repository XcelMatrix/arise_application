import 'package:arise_application/features/alerts/cubit/alert_cubit.dart';
import 'package:arise_application/features/console/cubit/audit_cubit.dart';
import 'package:arise_application/translations/translation.dart';

/// Turns an audit entry into text in the language picked in Settings.
/// Alerts are shown in that language too (the standard message is translated).
class AuditText {
  /// "Role changed to teacher" -> "Binago ang tungkulin sa Guro"
  static String action(AuditEntry e) => Tr.t(e.action);

  /// [alerts] are the rows of the emergency_alerts table (for the message
  /// in the reader's language).
  static String? detail(AuditEntry e, List<Map<String, dynamic>> alerts) {
    final d = e.detail;
    if (d == null || d.isEmpty) return null;

    if (e.category == 'alert' && e.refId != null) {
      for (final a in alerts) {
        if (a['id'] == e.refId) {
          return '${Tr.t('${a['kind']}')}: ${localizedAlertRow(a).replaceAll('\n', ' · ')}';
        }
      }
    }
    // "Fire: Fire reported. ..." (alert no longer in the list)
    if (e.category == 'alert') {
      final i = d.indexOf(': ');
      if (i > 0) return '${Tr.t(d.substring(0, i))}: ${Tr.t(d.substring(i + 2))}';
    }
    return Tr.t(d);
  }

  /// One line, used in exports.
  static String line(AuditEntry e, List<Map<String, dynamic>> alerts) {
    final d = detail(e, alerts);
    return d == null ? action(e) : '${action(e)}: $d';
  }
}
