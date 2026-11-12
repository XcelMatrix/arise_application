import 'package:arise_application/translations/translation.dart';

/// English is the language the app is written in, so it has no words to
/// translate. It is always available and is the default.
const english = AppTranslation(
  code: 'en',
  englishName: 'English',
  nativeName: 'English',
  months: [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ],
  weekdays: ['S', 'M', 'T', 'W', 'T', 'F', 'S'],
);
