enum AppLanguage { english, filipino }

/// English -> Filipino. Anything not listed here stays in English.
class Tr {
  static AppLanguage current = AppLanguage.english;

  static String t(String text) {
    if (current == AppLanguage.english || text.isEmpty) return text;
    final exact = _fil[text];
    if (exact != null) return exact;
    for (final rule in _rules) {
      final m = rule.pattern.firstMatch(text);
      if (m != null) return rule.build(m);
    }
    return text;
  }

  static const _monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];
  static const _monthsFil = [
    'Enero', 'Pebrero', 'Marso', 'Abril', 'Mayo', 'Hunyo', 'Hulyo',
    'Agosto', 'Setyembre', 'Oktubre', 'Nobyembre', 'Disyembre',
  ];

  /// Month names in the current language.
  static List<String> get months =>
      current == AppLanguage.filipino ? _monthsFil : _monthsEn;

  /// Sunday-first weekday letters in the current language.
  static List<String> get weekdays => current == AppLanguage.filipino
      ? const ['Li', 'Lu', 'Ma', 'Mi', 'Hu', 'Bi', 'Sa']
      : const ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  static String _statusOf(String s) => _fil[s] ?? s;

  static String _duration(String d) => d
      .replaceAll(' hr', ' oras')
      .replaceAll(' min', ' min')
      .replaceAll(' sec', ' seg');

  /// "Missing: A and B. Injured: C. Present: 28 of 30." / "All students are present."
  static String _summary(String s) {
    if (s == 'All students are present.') return _fil[s]!;
    final tail = RegExp(r'^(.*?)\.?\s*Present: (\d+) of (\d+)\.$').firstMatch(s);
    if (tail == null) return s;
    final groups = tail.group(1)!;
    final parts = groups.isEmpty
        ? <String>[]
        : groups.split('. ').map((g) {
            final i = g.indexOf(': ');
            if (i < 0) return g;
            final label = _statusOf(g.substring(0, i));
            final names = g.substring(i + 2).replaceAll(' and ', ' at ');
            return '$label: $names';
          }).toList();
    final present = 'Naririto: ${tail.group(2)} sa ${tail.group(3)}.';
    return [...parts.map((p) => p.endsWith('.') ? p : '$p.'), present].join(' ');
  }

  static String _extras(String s) {
    if (s == 'All persons accounted for.') return _fil[s]!;
    return s
        .replaceAllMapped(RegExp(r'Missing: (\d+)\.'), (m) => 'Nawawala: ${m[1]}.')
        .replaceAllMapped(RegExp(r'Injured: (\d+)\.'), (m) => 'Sugatan: ${m[1]}.');
  }

  static final List<_Rule> _rules = [
    _Rule(RegExp(r'^Events on (.+)$'), (m) => 'Mga event sa ${m[1]}'),
    _Rule(RegExp(r'^Events in (.+)$'), (m) => 'Mga event sa ${m[1]}'),
    _Rule(RegExp(r'^Could not save event: (.*)$'),
        (m) => 'Hindi na-save ang event: ${m[1]}'),
    _Rule(RegExp(r'^Grade (.+)$'), (m) => 'Baitang ${m[1]}'),
    _Rule(RegExp(r'^School year (.+)$'), (m) => 'Taong Panuruan ${m[1]}'),
    _Rule(RegExp(r'^(\d+)/(\d+) reports sent$'),
        (m) => '${m[1]}/${m[2]} ulat ang naipadala'),
    _Rule(RegExp(r'^(\d+)/(\d+) set$'), (m) => '${m[1]}/${m[2]} naitakda'),
    _Rule(RegExp(r'^DRILL IN PROGRESS  •  (.+?)  •  (.*)$'),
        (m) => 'ISINASAGAWA ANG DRILL  •  ${m[1]}  •  ${t(m[2]!)}'),
    _Rule(RegExp(r'^DRILL  •  (.+?)(  •  report sent)?$'),
        (m) => 'DRILL  •  ${m[1]}${m[2] != null ? '  •  naipadala ang ulat' : ''}'),
    _Rule(RegExp(r'^(Missing|Injured|Present|Absent) (\d+)$'),
        (m) => '${_statusOf(m[1]!)} ${m[2]}'),
    _Rule(RegExp(r'^Not set (\d+)$'), (m) => 'Hindi pa naitakda ${m[1]}'),
    _Rule(RegExp(r'^(\d+) students? not set$'),
        (m) => '${m[1]} estudyante ang hindi pa naitakda'),
    _Rule(RegExp(r'^Delete (.+)\?$'), (m) => 'Burahin ang ${m[1]}?'),
    _Rule(RegExp(r'^Copy (\d+) student\(s\) from your earlier (.+) attendance$'),
        (m) => 'Kopyahin ang ${m[1]} estudyante mula sa dati mong ${m[2]} attendance'),
    _Rule(RegExp(r'^Could not save name: (.*)$'),
        (m) => 'Hindi na-save ang pangalan: ${m[1]}'),
    _Rule(RegExp(r'^Could not update picture: (.*)$'),
        (m) => 'Hindi na-update ang larawan: ${m[1]}'),
    _Rule(RegExp(r'^Could not remove picture: (.*)$'),
        (m) => 'Hindi naalis ang larawan: ${m[1]}'),
    _Rule(RegExp(r'^Could not create attendance: (.*)$'),
        (m) => 'Hindi nagawa ang attendance: ${m[1]}'),
    _Rule(RegExp(r'^Auth Error: (.*)$'), (m) => 'Error sa pag-login: ${m[1]}'),
    _Rule(RegExp(r'^(.*?) Showing the evacuation map image instead\.$'),
        (m) => '${t(m[1]!)} Ipinapakita na lang ang larawan ng mapa ng paglikas.'),

    // ---- Timed Console lines ----
    _Rule(RegExp(r'^Timed Console ready\. School year (.+)\.$'),
        (m) => 'Handa na ang Timed Console. Taong Panuruan ${m[1]}.'),
    _Rule(RegExp(r'^Evacuation drill started\. Awaiting (\d+) attendance reports?\.$'),
        (m) => 'Nagsimula ang evacuation drill. Naghihintay ng ${m[1]} ulat ng attendance.'),
    _Rule(RegExp(r'^\[(.+?)\] Attendance completed at (.+?) \((.+)\)\. (.*)$'),
        (m) => '[${m[1]}] Natapos ang attendance sa ${m[2]} (${t(m[3]!)}). ${_summary(m[4]!)}'),
    _Rule(RegExp(r'^EVACUATION COMPLETE\. Total time: (.+?)\. (.*)$'),
        (m) => 'NATAPOS ANG EBAKUWASYON. Kabuuang oras: ${_duration(m[1]!)}. ${_extras(m[2]!)}'),
  ];

  static const Map<String, String> _fil = {
    // navigation + bars
    'Home': 'Tahanan',
    'Attendance': 'Attendance',
    'Console': 'Console',
    'Resources': 'Mga Resource',
    'Profile': 'Profile',
    'Menu': 'Menu',
    'Inbox': 'Inbox',
    'Settings': 'Mga Setting',
    'About': 'Tungkol',
    'Help': 'Tulong',
    'Log out': 'Mag-log out',
    'View profile': 'Tingnan ang profile',
    'Calendar': 'Kalendaryo',
    'Add event': 'Magdagdag ng event',
    'Edit event': 'I-edit ang event',
    'Event title': 'Pamagat ng event',
    'Enter a title': 'Maglagay ng pamagat',
    'Details (optional)': 'Mga detalye (opsyonal)',
    'Time (optional)': 'Oras (opsyonal)',
    'Clear time': 'Alisin ang oras',
    'Delete this event?': 'Burahin ang event na ito?',
    'No events on this day.': 'Walang event sa araw na ito.',
    'No events this month.': 'Walang event ngayong buwan.',
    'Upcoming events': 'Mga paparating na event',
    'Only teachers and admins can add or edit events.':
        'Mga guro at admin lamang ang maaaring magdagdag o mag-edit ng mga event.',
    'Registered since': 'Nakarehistro mula noong',
    'Messages': 'Mga Mensahe',
    'Timed Console': 'Timed Console',
    'Evacuation Map': 'Mapa ng Paglikas',
    'Emergency Contacts': 'Mga Contact sa Emergency',
    'Disaster Guidelines': 'Mga Alituntunin sa Sakuna',
    'Disaster Resources': 'Mga Resource sa Sakuna',
    'Attendance Records': 'Mga Tala ng Attendance',
    'Attendance Report': 'Ulat ng Attendance',
    'Attendance report': 'Ulat ng Attendance',
    'Evacuation drill': 'Evacuation drill',
    'Evacuation complete': 'Tapos na ang ebakuwasyon',
    'Access programmed terminal sessions and tools.':
        'Buksan ang mga naka-program na session at tool.',
    'Check your daily and historical attendance records.':
        'Tingnan ang araw-araw at nakaraang tala ng attendance.',
    'View emergency routes and safe zones.':
        'Tingnan ang mga ruta ng paglikas at ligtas na lugar.',
    'Checking your account, try again in a moment.':
        'Sinusuri ang iyong account, subukan muli maya-maya.',
    "Your account level doesn't have access to this.":
        'Walang access ang antas ng iyong account dito.',
    "Your account doesn't have access to this page.":
        'Walang access ang iyong account sa pahinang ito.',
    'Teachers and admins only': 'Para lamang sa mga guro at admin',
    'Back to home': 'Bumalik sa Home',

    // login / register
    'Login': 'Mag-login',
    'Sign Up': 'Mag-sign up',
    'Teacher Sign Up': 'Sign Up ng Guro',
    "Don't have an account? Sign up": 'Wala pang account? Mag-sign up',
    'Already have an account?': 'May account na?',
    'Already have an account? Sign in': 'May account na? Mag-sign in',
    'Email Address': 'Email Address',
    'Password': 'Password',
    'Confirm Password': 'Kumpirmahin ang Password',
    'Username': 'Username',
    'Required': 'Kinakailangan',
    'Passwords do not match': 'Hindi magkatugma ang mga password',
    '6 characters minimum': 'Hindi bababa sa 6 na karakter',
    '3-24 long with alphanumeric or underscore':
        '3-24 na karakter; letra, numero o underscore lamang',
    'OK': 'OK',
    'Request sent': 'Naipadala ang kahilingan',
    'Your teacher account has to be approved before you can use it. Sign in again once you have been approved.':
        'Kailangang aprubahan ang iyong account bilang guro bago mo ito magamit. Mag-sign in muli kapag naaprubahan ka na.',
    'Teacher accounts need approval before they can be used. You can sign in once you have been approved.':
        'Kailangan ng pag-apruba ang mga account ng guro bago magamit. Maaari kang mag-sign in kapag naaprubahan ka na.',
    'Are you registering as a teacher or a student?':
        'Magpaparehistro ka ba bilang guro o estudyante?',
    'Teacher': 'Guro',
    'Student': 'Estudyante',
    'A student account can view the evacuation map and manage its own profile.':
        'Maaaring tingnan ng account ng estudyante ang mapa ng paglikas at ayusin ang sariling profile.',
    'A teacher account can take attendance, run drills and use the chat. It has to be approved first.':
        'Maaaring mag-attendance, magpatakbo ng drill at gumamit ng chat ang account ng guro. Kailangan muna itong aprubahan.',
    'Waiting for approval': 'Naghihintay ng pag-apruba',
    'Request declined': 'Tinanggihan ang kahilingan',
    'Check again': 'Suriin muli',
    'Your teacher request was not approved. Please contact your administrator.':
        'Hindi naaprubahan ang iyong kahilingan bilang guro. Makipag-ugnayan sa iyong administrator.',
    'Your teacher account has to be approved before you can use the app. Check back once you have been approved.':
        'Kailangang aprubahan ang iyong account bilang guro bago mo magamit ang app. Bumalik muli kapag naaprubahan ka na.',

    // profile
    'Display name': 'Display name',
    'How your name appears': 'Paano lalabas ang iyong pangalan',
    'Save name': 'I-save ang pangalan',
    'Display name saved': 'Na-save ang display name',
    'Choose a new photo': 'Pumili ng bagong larawan',
    'Choose from gallery': 'Pumili mula sa gallery',
    'Take a photo': 'Kumuha ng larawan',
    'Remove photo': 'Alisin ang larawan',
    'Profile picture updated': 'Na-update ang larawan sa profile',
    'Profile picture removed': 'Naalis ang larawan sa profile',

    // inbox
    'Mark all as read': 'Markahan lahat bilang nabasa',
    'Clear inbox': 'Linisin ang inbox',
    'No notifications yet.\nNew chat messages and Timed Console reports will show up here.':
        'Wala pang abiso.\nDito lalabas ang mga bagong mensahe sa chat at ulat ng Timed Console.',
    'Someone': 'May nagpadala',

    // chat / rooms
    'Type a message': 'Mag-type ng mensahe',
    'Start your conversation now :': 'Simulan na ang usapan :',
    'Start a chat by tapping on available users':
        'Magsimula ng chat sa pamamagitan ng pag-tap sa isang user',
    'Loading...': 'Naglo-load...',
    'Room created': 'Nagawa ang room',

    // attendance
    'Add Attendance': 'Magdagdag ng Attendance',
    'Edit Attendance': 'I-edit ang Attendance',
    'Create': 'Gumawa',
    'Save': 'I-save',
    'Cancel': 'Kanselahin',
    'Delete': 'Burahin',
    'Add': 'Idagdag',
    'Refresh': 'I-refresh',
    'Timestamp': 'Oras at petsa',
    'Grade & Section': 'Baitang at Seksyon',
    'Emergency': 'Emergency',
    'Site': 'Lugar',
    'Status': 'Katayuan',
    'Sent': 'Naipadala',
    'No students': 'Walang estudyante',
    'No attendance yet.\nTap "Add Attendance" to create one.':
        'Wala pang attendance.\nI-tap ang "Magdagdag ng Attendance" para gumawa.',
    'Grade': 'Baitang',
    'Pick a grade': 'Pumili ng baitang',
    'Section (e.g. Polaris)': 'Seksyon (hal. Polaris)',
    'Enter the section': 'Ilagay ang seksyon',
    'Evacuation site': 'Lugar ng paglikas',
    'Enter the evacuation site': 'Ilagay ang lugar ng paglikas',
    'Type of emergency': 'Uri ng emergency',
    'Enter the type of emergency': 'Ilagay ang uri ng emergency',
    'Describe the emergency': 'Ilarawan ang emergency',
    'Attendance not found': 'Hindi nahanap ang attendance',
    'Add students first': 'Magdagdag muna ng mga estudyante',
    'All set. Report sent to the Timed Console.':
        'Handa na. Naipadala ang ulat sa Timed Console.',
    'Report sent to the Timed Console': 'Naipadala ang ulat sa Timed Console',
    'Sent to the Timed Console': 'Naipadala sa Timed Console',
    'Ready to send': 'Handa nang ipadala',
    'Send report': 'Ipadala ang ulat',
    'Resend report': 'Ipadala muli ang ulat',
    'Mark all present': 'Markahan lahat na present',
    'Edit details': 'I-edit ang detalye',
    'Edit name': 'I-edit ang pangalan',
    'Delete attendance': 'Burahin ang attendance',
    'This attendance and its students will be removed.':
        'Maaalis ang attendance na ito at ang mga estudyante nito.',
    'Name': 'Pangalan',
    'Student name': 'Pangalan ng estudyante',
    'Set status': 'Itakda ang katayuan',
    'No students yet. Add names above.':
        'Wala pang estudyante. Magdagdag ng pangalan sa itaas.',
    'Missing': 'Nawawala',
    'Injured': 'Sugatan',
    'Present': 'Naririto',
    'Absent': 'Wala',
    'Fire': 'Sunog',
    'Earthquake': 'Lindol',
    'Flood': 'Baha',
    'Typhoon': 'Bagyo',
    'Lockdown': 'Lockdown',
    'Other': 'Iba pa',

    // timed console
    'Start drill': 'Simulan ang drill',
    'Clear console': 'Linisin ang console',
    'No drill running': 'Walang drill na tumatakbo',
    'DRILL ACTIVE': 'GUMAGANA ANG DRILL',
    'EVACUATION COMPLETE': 'NATAPOS ANG EBAKUWASYON',
    'STANDBY': 'NAKA-STANDBY',
    '> waiting for reports...': '> naghihintay ng mga ulat...',
    'All students are present.': 'Lahat ng estudyante ay naririto.',
    'All persons accounted for.': 'Lahat ng tao ay nabilang.',
    'Evacuation drill cancelled.': 'Kinansela ang evacuation drill.',
    'Evacuation drill started. Awaiting attendance reports.':
        'Nagsimula ang evacuation drill. Naghihintay ng mga ulat ng attendance.',

    // evacuation map
    'View map image': 'Tingnan ang larawan ng mapa',
    'Try AR': 'Subukan ang AR',
    'Show Model': 'Ipakita ang Model',
    'Hide Model': 'Itago ang Model',
    'Reset': 'I-reset',
    "AR couldn't start on this device.": 'Hindi masimulan ang AR sa device na ito.',
    "AR isn't supported on this device.": 'Hindi sinusuportahan ang AR sa device na ito.',
    'AR took too long to start.': 'Natagalan ang pagsisimula ng AR.',
    "The AR model couldn't be loaded.": 'Hindi ma-load ang AR model.',
    'Switched to the map image.': 'Lumipat sa larawan ng mapa.',
    'Evacuation map image not found.\nAdd assets/images/evacuation_map.png':
        'Hindi nahanap ang larawan ng mapa ng paglikas.\nIdagdag ang assets/images/evacuation_map.png',
    'This is the Emergency Contacts Page': 'Ito ang pahina ng Mga Contact sa Emergency',
    'This is the Disaster Guidelines Page': 'Ito ang pahina ng Mga Alituntunin sa Sakuna',

    // settings / about / drawer
    'Theme': 'Tema',
    'Light': 'Maliwanag',
    'Dark': 'Madilim',
    'Language': 'Wika',
    'English': 'English',
    'Filipino': 'Filipino',
    'Appearance': 'Hitsura',
    'Choose how the app looks.': 'Piliin kung paano lalabas ang app.',
    'Choose the language of the app.': 'Piliin ang wika ng app.',
    'About ARISE': 'Tungkol sa ARISE',
    'What ARISE does': 'Ano ang ginagawa ng ARISE',
    'ARISE helps your school get ready for disasters and respond to them. Find evacuation routes, read safety guidelines, reach emergency contacts, and run evacuation drills with live attendance.':
        'Tinutulungan ng ARISE ang iyong paaralan na maghanda at tumugon sa mga sakuna. Hanapin ang mga ruta ng paglikas, basahin ang mga alituntunin sa kaligtasan, tawagan ang mga emergency contact, at magpatakbo ng evacuation drill na may live na attendance.',
    'Evacuation Map (AR)': 'Mapa ng Paglikas (AR)',
    'See the evacuation map in augmented reality, or as a picture if AR is not available on your device.':
        'Tingnan ang mapa ng paglikas sa augmented reality, o bilang larawan kung hindi available ang AR sa iyong device.',
    'Disaster Resources and Guidelines': 'Mga Resource at Alituntunin sa Sakuna',
    'Emergency contacts and what to do before, during and after a disaster.':
        'Mga emergency contact at kung ano ang gagawin bago, habang at pagkatapos ng sakuna.',
    'Attendance and Timed Console': 'Attendance at Timed Console',
    'Teachers record who is present, absent, missing or injured. Reports appear live in the Timed Console, which times the whole evacuation.':
        'Itinatala ng mga guro kung sino ang naririto, wala, nawawala o sugatan. Live na lumalabas ang mga ulat sa Timed Console, na nagtatala ng oras ng buong ebakuwasyon.',
    'Chat': 'Chat',
    'Teachers and admins can message each other inside the app.':
        'Maaaring magpadala ng mensahe sa isa\'t isa ang mga guro at admin sa loob ng app.',
    'Accounts and roles': 'Mga account at tungkulin',
    'Students, teachers and admins each see what they need. Teacher accounts are approved before they unlock.':
        'Nakikita ng mga estudyante, guro at admin ang kailangan nila. Inaaprubahan muna ang mga account ng guro bago ma-unlock.',

    // guide
    'Welcome': 'Maligayang pagdating',
    'How to use ARISE': 'Paano gamitin ang ARISE',
    'Skip': 'Laktawan',
    'Close': 'Isara',
    'Continue to Home': 'Magpatuloy sa Home',
    'ARISE': 'ARISE',
    'Your guide to disaster preparedness: evacuation map, emergency contacts, guidelines, and drill attendance.':
        'Gabay mo sa paghahanda sa sakuna: mapa ng paglikas, mga emergency contact, mga alituntunin, at attendance sa drill.',
    'Getting around': 'Paglilibot sa app',
    'Use the bar at the bottom to switch between Home, Attendance, Console and Resources.':
        'Gamitin ang bar sa ibaba para lumipat sa Home, Attendance, Console at Resources.',
    'Tap your picture at the top to open the menu: Inbox, Settings, About, Help and Log out.':
        'I-tap ang iyong larawan sa itaas para buksan ang menu: Inbox, Mga Setting, Tungkol, Tulong at Mag-log out.',
    'Tap your picture in the menu to open your profile, change your display name or picture.':
        'I-tap ang iyong larawan sa menu para buksan ang iyong profile at palitan ang display name o larawan.',
    'Evacuation Map controls': 'Mga kontrol ng Mapa ng Paglikas',
    'Drag to move the map.': 'I-drag para igalaw ang mapa.',
    'Pinch to zoom in and out.': 'I-pinch para mag-zoom in at out.',
    'Twist with two fingers to rotate.': 'I-ikot gamit ang dalawang daliri para paikutin.',
    'Show / Hide Model places or removes the map in your room.':
        'Inilalagay o inaalis ng Show / Hide Model ang mapa sa iyong silid.',
    'Reset puts the map back where it started.':
        'Ibinabalik ng Reset ang mapa sa orihinal nitong posisyon.',
    "If AR can't start on your device, a map image is shown instead. Use View map image to switch yourself, or Try AR to switch back.":
        'Kung hindi masimulan ang AR sa iyong device, larawan ng mapa ang ipapakita. Gamitin ang View map image para lumipat, o Try AR para bumalik.',
    'Taking attendance (teachers)': 'Pag-attendance (mga guro)',
    'Tap Add Attendance and fill in the date and time, grade, section, evacuation site and type of emergency.':
        'I-tap ang Add Attendance at ilagay ang petsa at oras, baitang, seksyon, lugar ng paglikas at uri ng emergency.',
    'Open the report and add your students. Their grade and section are filled in for you.':
        'Buksan ang ulat at idagdag ang iyong mga estudyante. Awtomatikong nakalagay ang kanilang baitang at seksyon.',
    'Set each student to Present, Absent, Missing or Injured.':
        'Itakda ang bawat estudyante bilang Naririto, Wala, Nawawala o Sugatan.',
    'When everyone is marked, tap Send to deliver the report to the Timed Console.':
        'Kapag may marka na ang lahat, i-tap ang Send para ipadala ang ulat sa Timed Console.',
    'Use the menu in the corner to mark everyone present, edit the details or delete the report.':
        'Gamitin ang menu sa sulok para markahan ang lahat na naririto, i-edit ang detalye o burahin ang ulat.',
    'Timed Console (teachers)': 'Timed Console (mga guro)',
    'Reports from every section appear here as they are sent.':
        'Dito lumalabas ang mga ulat ng bawat seksyon habang ipinapadala.',
    'Tap Start to begin a drill. The clock runs until every report has been sent.':
        'I-tap ang Start para simulan ang drill. Tatakbo ang orasan hanggang maipadala ang lahat ng ulat.',
    'When all sections are in, the console shows how long the evacuation took.':
        'Kapag kumpleto na ang lahat ng seksyon, ipapakita ng console kung gaano katagal ang ebakuwasyon.',
    'Tap Cancel to stop a drill that was started by mistake.':
        'I-tap ang Cancel para ihinto ang drill na nasimulan nang hindi sinasadya.',
    'Chat (teachers)': 'Chat (mga guro)',
    'Tap the chat button on Home to open a room and message other teachers.':
        'I-tap ang chat button sa Home para magbukas ng room at magpadala ng mensahe sa ibang guro.',
    'Accounts': 'Mga account',
    'Students can use the disaster resources and the evacuation map.':
        'Magagamit ng mga estudyante ang mga resource sa sakuna at ang mapa ng paglikas.',
    'Attendance, Timed Console and Chat are for teachers and admins.':
        'Ang Attendance, Timed Console at Chat ay para sa mga guro at admin.',
    "Teacher accounts must be approved before they unlock. You'll see a waiting screen until then.":
        'Kailangang aprubahan ang mga account ng guro bago ma-unlock. Makakakita ka ng waiting screen hanggang doon.',
  };
}

class _Rule {
  final RegExp pattern;
  final String Function(RegExpMatch) build;
  _Rule(this.pattern, this.build);
}
