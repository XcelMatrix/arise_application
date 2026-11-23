import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/core/widgets/app_drawer.dart';
import 'package:arise_application/features/account/widgets/profile_menu_button.dart';
import 'package:arise_application/core/widgets/back_or_logo.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/resources/data/guideline_text.dart';

/// "How to use ARISE" - opened from Help in the side menu.
/// Everyone sees the features everyone has. A section about something only
/// teachers or admins can do is shown only to the people who can do it.
class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const GuidePage());
  }

  static const _blue = Color(0xFF3C6E87);

  @override
  Widget build(BuildContext context) {
    LangScope.of(context); // rebuild when the language changes
    final acc = context.watch<AccountCubit>().state;
    final staff = acc.canAccess(Feature.attendance) ||
        acc.canAccess(Feature.timedConsole);

    // (title, lines) in English and Filipino
    final everyone = <_Sec>[
      _Sec(Icons.navigation, 'Getting around', 'Paglilibot sa app', [
        _L('Use the bar at the bottom to switch between Home, Attendance, Console and Resources. Students only see the tabs they can use.',
            'Gamitin ang bar sa ibaba para lumipat sa Home, Attendance, Console at Resources. Ang mga estudyante ay nakikita lamang ang mga tab na magagamit nila.'),
        _L('Tap your picture at the top to open the side menu: Inbox, Messages, Settings, Calendar, About, Help and Log out. Tap the picture in the menu to open your profile.',
            'I-tap ang iyong larawan sa itaas para buksan ang side menu: Inbox, Messages, Settings, Calendar, About, Help at Log out. I-tap ang larawan sa menu para buksan ang iyong profile.'),
        _L('The back button at the top left (the ARISE logo on the main pages) takes you back.',
            'Ang back button sa itaas na kaliwa (ang logo ng ARISE sa mga pangunahing pahina) ay nagbabalik sa iyo.'),
      ]),
      _Sec(Icons.campaign, 'Home and announcements', 'Home at mga anunsyo', [
        _L('The top of Home shows the latest announcements from teachers and admins. Tap See all announcements to read the older ones.',
            'Sa itaas ng Home makikita ang mga pinakabagong anunsyo mula sa mga guro at admin. I-tap ang See all announcements para mabasa ang mga mas luma.'),
        _L('Below the announcements are shortcuts to Disaster Resources and, for teachers, Attendance and Console.',
            'Sa ibaba ng mga anunsyo ay ang mga shortcut papunta sa Disaster Resources at, para sa mga guro, Attendance at Console.'),
      ]),
      _Sec(Icons.menu_book, 'Guidelines', 'Mga Gabay', [
        _L('Open Resources, then Guidelines, to read what to do before, during and after each disaster, plus the Go Bag, Evacuation Procedure, Lockdown Procedure and First Aid Procedure.',
            'Buksan ang Resources, saka ang Guidelines, para mabasa ang gagawin bago, habang at matapos ang bawat sakuna, pati ang Go Bag, Evacuation Procedure, Lockdown Procedure at First Aid Procedure.'),
        _L('Guidelines are grouped in categories. Tap one to open it: the big icon, a description, then the steps with their icons.',
            'Nakapangkat ang mga gabay sa mga kategorya. I-tap ang isa para buksan: ang malaking icon, ang paglalarawan, at ang mga hakbang na may kani-kanilang icon.'),
        _L('The guidelines follow the language you pick in Settings (English or Filipino).',
            'Sumusunod ang mga gabay sa wikang pinili mo sa Settings (English o Filipino).'),
      ]),
      _Sec(Icons.view_in_ar, 'Evacuation Plan', 'Plano sa Paglikas', [
        _L('Evacuation Plan shows a button for each building. Tap a building to see its maps and its description.',
            'Ipinapakita ng Evacuation Plan ang isang button para sa bawat gusali. I-tap ang gusali para makita ang mga mapa at paglalarawan nito.'),
        _L('A building can have a 3D model (shown in augmented reality) and a 2D map image. Use the floor box to switch floors.',
            'Maaaring may 3D model (ipinapakita sa augmented reality) at 2D na larawan ng mapa ang isang gusali. Gamitin ang floor box para magpalit ng palapag.'),
        _L('3D model: drag to move it, pinch to zoom and twist with two fingers to rotate. Show Model places it in your room and Reset puts it back where it started.',
            '3D model: i-drag para igalaw, i-pinch para mag-zoom at i-twist gamit ang dalawang daliri para umikot. Inilalagay ito ng Show Model sa iyong kuwarto at ibinabalik ito ng Reset sa simula.'),
        _L('If AR cannot start on your phone, the map image is shown instead. Use View Map Image to switch yourself, or Try AR to switch back.',
            'Kung hindi makapagsimula ang AR sa iyong telepono, ang larawan ng mapa ang ipapakita. Gamitin ang View Map Image para magpalit, o Try AR para bumalik.'),
        _L('Pins on the map mark exits, assembly points, extinguishers and other important places.',
            'Ang mga pin sa mapa ay nagmamarka ng mga labasan, assembly point, fire extinguisher at iba pang mahahalagang lugar.'),
      ]),
      _Sec(Icons.contact_phone, 'Emergency Contacts', 'Mga Numero ng Emergency', [
        _L('Open Resources, then Emergency Contacts. Each contact shows its logo, name, short description and number.',
            'Buksan ang Resources, saka ang Emergency Contacts. Ipinapakita ng bawat contact ang logo, pangalan, maikling paglalarawan at numero nito.'),
        _L('Tap a contact to call it.',
            'I-tap ang contact para tawagan ito.'),
      ]),
      _Sec(Icons.warning_amber_rounded, 'When an emergency alert arrives', 'Kapag may dumating na emergency alert', [
        _L('An alert appears on the whole screen, with a siren. The message is shown in the language you picked in Settings.',
            'Lalabas ang alerto sa buong screen, kasama ang sirena. Ipinapakita ang mensahe sa wikang pinili mo sa Settings.'),
        _L('Tap I am safe so your teacher knows you are all right. If you do not answer, you may get a reminder.',
            'I-tap ang I am safe para malaman ng guro mo na ligtas ka. Kapag hindi ka sumagot, maaaring makatanggap ka ng paalala.'),
        _L('Alerts also reach you when the app is closed.',
            'Natatanggap mo rin ang mga alerto kahit nakasara ang app.'),
      ]),
      _Sec(Icons.mail_outline, 'Inbox and Calendar', 'Inbox at Calendar', [
        _L('The Inbox lists your notifications. Use the search bar to find one, and the three dots to mark all as read or clear the inbox.',
            'Nakalista sa Inbox ang iyong mga abiso. Gamitin ang search bar para maghanap, at ang tatlong tuldok para markahang nabasa na ang lahat o linisin ang inbox.'),
        _L('The Calendar shows events and drills. Tap a day to see what is planned.',
            'Ipinapakita ng Calendar ang mga kaganapan at drill. I-tap ang isang araw para makita ang nakaplano.'),
      ]),
      _Sec(Icons.settings, 'Settings and your profile', 'Settings at iyong profile', [
        _L('In Settings you can choose Device Theme, Light or Dark, the language, the text size, the colour strength and a 12 or 24-hour clock. Reset to default brings everything back.',
            'Sa Settings maaari mong piliin ang Device Theme, Light o Dark, ang wika, laki ng teksto, tindi ng kulay at 12 o 24-oras na orasan. Ibinabalik ng Reset to default ang lahat.'),
        _L('Open your profile from the side menu to change your display name or picture.',
            'Buksan ang iyong profile mula sa side menu para baguhin ang display name o larawan.'),
      ]),
    ];

    final teachers = <_Sec>[
      if (acc.canAccess(Feature.attendance))
        _Sec(Icons.assignment_turned_in, 'Taking attendance', 'Pagkuha ng attendance', [
          _L('Tap Add Attendance. Pick the date and time, the grade, the section, the evacuation site and the Type of Emergency.',
              'I-tap ang Add Attendance. Piliin ang petsa at oras, grade, section, evacuation site at Type of Emergency.'),
          _L('Open the report and add your students, then set each one to Present, Absent, Missing or Injured.',
              'Buksan ang ulat at idagdag ang iyong mga estudyante, saka itakda ang bawat isa bilang Present, Absent, Missing o Injured.'),
          _L('When everyone is marked, tap Send to deliver the report to the Console. Use the menu in the corner to mark everyone present, edit the details or delete the report.',
              'Kapag namarkahan na ang lahat, i-tap ang Send para ihatid ang ulat sa Console. Gamitin ang menu sa sulok para markahang present ang lahat, i-edit ang mga detalye o burahin ang ulat.'),
          _L('The class lists button beside Attendance Records opens your saved class lists. Create a list, or import students from a spreadsheet saved as CSV; each grade and section becomes its own list.',
              'Binubuksan ng class lists button sa tabi ng Attendance Records ang iyong mga naka-save na class list. Gumawa ng listahan, o mag-import ng mga estudyante mula sa spreadsheet na naka-save bilang CSV; ang bawat grade at section ay nagiging sariling listahan.'),
        ]),
      if (acc.canAccess(Feature.timedConsole))
        _Sec(Icons.terminal, 'Console and drills', 'Console at mga drill', [
          _L('Reports from every section appear in the Console as they are sent.',
              'Lumalabas sa Console ang mga ulat ng bawat section habang ipinapadala ang mga ito.'),
          _L('Tap Start to begin a drill. The clock runs until every report has been sent, then the Console shows how long the evacuation took. Tap Cancel to stop a drill started by mistake.',
              'I-tap ang Start para magsimula ng drill. Tatakbo ang orasan hanggang maipadala ang lahat ng ulat, saka ipapakita ng Console kung gaano katagal ang paglikas. I-tap ang Cancel para ihinto ang drill na nasimulan nang hindi sinasadya.'),
          _L('Use the Console, Activity and Alerts views to follow live reports, see what was done, and review emergency alerts. Incident History keeps past drills.',
              'Gamitin ang Console, Activity at Alerts para sundan ang mga live na ulat, makita ang mga ginawa, at suriin ang mga emergency alert. Iniingatan ng Incident History ang mga nakaraang drill.'),
        ]),
      if (acc.canAccess(Feature.attendance) || acc.canAccess(Feature.timedConsole))
        _Sec(Icons.summarize, 'Reports and drill assessment', 'Mga ulat at pagtatasa ng drill', [
          _L('Open Reports from the side menu. Choose Attendance or Drills, pick the period, then export as PDF or CSV.',
              'Buksan ang Reports mula sa side menu. Piliin ang Attendance o Drills, piliin ang panahon, saka i-export bilang PDF o CSV.'),
          _L('In the Drills tab, Drill assessment lets you rate each drill with a checklist (Yes, Partly, No) and add notes. The score and rating are saved and included in the exports.',
              'Sa tab na Drills, hinahayaan ka ng Drill assessment na tasahin ang bawat drill gamit ang checklist (Yes, Partly, No) at magdagdag ng mga tala. Naka-save ang marka at antas at kasama ang mga ito sa mga export.'),
        ]),
      if (acc.canAccess(Feature.emergencyAlert))
        _Sec(Icons.campaign, 'Sending an emergency alert', 'Pagpapadala ng emergency alert', [
          _L('Open Emergency Alert from the side menu. Pick the Type of Emergency, check the English message, and optionally write a Filipino message.',
              'Buksan ang Emergency Alert mula sa side menu. Piliin ang Type of Emergency, suriin ang mensahe sa English, at kung nais, sumulat ng mensahe sa Filipino.'),
          _L('People using the app in English see the English message; people using Filipino see the Filipino one (or the English one if you leave it empty).',
              'Ang mga gumagamit ng app sa English ay nakakakita ng mensahe sa English; ang mga gumagamit ng Filipino ay nakakakita ng mensahe sa Filipino (o ng English kung wala kang isinulat).'),
          _L('While an alert is active you can see who is safe, open the class headcount, send an all clear and remind people who have not answered.',
              'Habang aktibo ang alerto, makikita mo kung sino ang ligtas, mabubuksan ang class headcount, makapagpapadala ng all clear at makapagpapaalala sa mga hindi pa sumasagot.'),
        ]),
      if (acc.canAccess(Feature.chat))
        _Sec(Icons.forum, 'Messages', 'Mga mensahe', [
          _L('Open Messages from the side menu, tap a person who is available, and chat with other teachers and admins.',
              'Buksan ang Messages mula sa side menu, i-tap ang taong available, at makipag-chat sa ibang guro at admin.'),
        ]),
      if (acc.canAccess(Feature.announce))
        _Sec(Icons.edit_note, 'Posting announcements', 'Pag-post ng mga anunsyo', [
          _L('On Home, tap Post to write a new announcement. Use the menu on an announcement to edit or delete it.',
              'Sa Home, i-tap ang Post para sumulat ng bagong anunsyo. Gamitin ang menu ng anunsyo para i-edit o burahin ito.'),
        ]),
      if (acc.canAccess(Feature.calendarEdit))
        _Sec(Icons.event, 'Editing the calendar', 'Pag-edit ng calendar', [
          _L('In the Calendar you can add, edit and delete events.',
              'Sa Calendar maaari kang magdagdag, mag-edit at magbura ng mga kaganapan.'),
        ]),
      if (acc.canAccess(Feature.contentEdit))
        _Sec(Icons.edit, 'Editing the guidelines', 'Pag-edit ng mga gabay', [
          _L('On the Guidelines page you can add categories and guidelines, and edit or delete them from their menus.',
              'Sa pahina ng Guidelines maaari kang magdagdag ng mga kategorya at gabay, at i-edit o burahin ang mga ito mula sa kanilang menu.'),
          _L('Inside a guideline, use the edit and delete buttons beside the big icon, and the three dots on each step to edit, move, add or delete it. Icons can be built-in icons, text or your own picture.',
              'Sa loob ng gabay, gamitin ang edit at delete button sa tabi ng malaking icon, at ang tatlong tuldok sa bawat hakbang para i-edit, ilipat, dagdagan o burahin ito. Ang mga icon ay maaaring built-in na icon, teksto o sarili mong larawan.'),
        ]),
      if (acc.canAccess(Feature.mapEdit))
        _Sec(Icons.add_business, 'Editing the evacuation plan', 'Pag-edit ng plano sa paglikas', [
          _L('Tap Add Building to create a building with a picture, a name and a description. Use the menu on a building to edit or delete it.',
              'I-tap ang Add Building para gumawa ng gusali na may larawan, pangalan at paglalarawan. Gamitin ang menu ng gusali para i-edit o burahin ito.'),
          _L('Inside a building, upload a 3D model or a 2D image for each floor, give each floor a description, and place markers. Manage maps lets you rename floors, describe them and choose which one is shown first.',
              'Sa loob ng gusali, mag-upload ng 3D model o 2D na larawan para sa bawat palapag, bigyan ng paglalarawan ang bawat palapag, at maglagay ng mga marker. Hinahayaan ka ng Manage maps na palitan ang pangalan ng mga palapag, lagyan ng paglalarawan at piliin kung alin ang unang ipapakita.'),
        ]),
      if (acc.canAccess(Feature.contactsEdit))
        _Sec(Icons.contacts, 'Editing the emergency contacts', 'Pag-edit ng mga numero ng emergency', [
          _L('Tap Add contact to add a name, number, type, description and an optional logo. The type (Fire Station, School, Hospital or Police Station) sets the icon shown when there is no logo.',
              'I-tap ang Add contact para magdagdag ng pangalan, numero, uri, paglalarawan at opsyonal na logo. Ang uri (Fire Station, School, Hospital o Police Station) ang magtatakda ng icon kapag walang logo.'),
          _L('Use the menu on a contact to edit or delete it.',
              'Gamitin ang menu ng contact para i-edit o burahin ito.'),
        ]),
      if (acc.canAccess(Feature.teacherReview))
        _Sec(Icons.how_to_reg, 'Approving teachers', 'Pag-apruba ng mga guro', [
          _L('New teacher accounts wait for approval. Open the request in your Inbox and approve or reject it.',
              'Naghihintay ng pag-apruba ang mga bagong account ng guro. Buksan ang kahilingan sa iyong Inbox at aprubahan o tanggihan ito.'),
        ]),
      if (acc.rank >= 3)
        _Sec(Icons.admin_panel_settings, 'Admin tools', 'Mga tool ng admin', [
          _L('Admin tools (in the side menu) lists every account and lets you remove one, and lets you choose which role can use each feature.',
              'Inililista ng Admin tools (nasa side menu) ang bawat account at hinahayaan kang mag-alis ng isa, at piliin kung aling tungkulin ang puwedeng gumamit ng bawat feature.'),
          _L('Start a new school year moves students and class lists up one grade. You can also back up and restore the data, and delete old data.',
              'Inililipat ng Start a new school year ang mga estudyante at class list ng isang grade pataas. Maaari ka ring mag-backup at mag-restore ng data, at magbura ng lumang data.'),
        ]),
    ];

    Widget header(String en, String fil) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
          child: Row(children: [
            const Expanded(child: Divider(color: _blue, thickness: 2)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text.verbatim(pickLang(en, fil),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _blue,
                      fontFamily: 'Geist')),
            ),
            const Expanded(child: Divider(color: _blue, thickness: 2)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(
        leading: const BackOrLogo(),
        backgroundColor: _blue,
        title: const Text("How to use ARISE"),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
        actions: const [ProfileMenuButton()],
      ),
      endDrawer: const AppDrawer(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const _Intro(),
            const SizedBox(height: 16),
            header('For everyone', 'Para sa lahat'),
            for (final s in everyone) _Section(sec: s),
            if (teachers.isNotEmpty) ...[
              header(
                  acc.rank >= 3 && !staff
                      ? 'For admins'
                      : 'For teachers and admins',
                  acc.rank >= 3 && !staff
                      ? 'Para sa mga admin'
                      : 'Para sa mga guro at admin'),
              for (final s in teachers) _Section(sec: s),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _L {
  const _L(this.en, this.fil);
  final String en;
  final String fil;
}

class _Sec {
  const _Sec(this.icon, this.en, this.fil, this.lines);
  final IconData icon;
  final String en;
  final String fil;
  final List<_L> lines;
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          "ARISE",
          style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3C6E87),
              fontFamily: 'Geist'),
        ),
        const SizedBox(height: 6),
        Text.verbatim(
          pickLang(
              'Everything you can do in the app and how to do it. You only see the features your account can use.',
              'Lahat ng magagawa mo sa app at kung paano ito gawin. Nakikita mo lamang ang mga feature na magagamit ng iyong account.'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 14, color: Color(0xFF3C6E87), fontFamily: 'Geist'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.sec});

  final _Sec sec;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border.all(color: const Color(0xFF3C6E87).withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF3C6E87),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(sec.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.verbatim(
                  pickLang(sec.en, sec.fil),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3C6E87),
                      fontFamily: 'Geist'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in sec.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("•  ",
                      style: TextStyle(color: Color(0xFF3C6E87))),
                  Expanded(
                    child: Text.verbatim(
                      pickLang(line.en, line.fil),
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Color(0xFF3C6E87),
                          fontFamily: 'Geist'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
