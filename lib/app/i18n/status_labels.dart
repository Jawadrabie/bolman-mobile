import 'locales/ar.dart';
import 'locales/en.dart';

String translateStatus(String value, String locale) {
  final key = 'status.$value';
  final map = locale == 'en' ? enMessages : arMessages;
  return map[key] ?? value;
}
