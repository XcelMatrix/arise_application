import 'package:arise_application/core/widgets/app_drawer.dart';
import 'package:arise_application/features/account/widgets/profile_menu_button.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/resources/data/guideline_text.dart';

/// About the app: what ARISE is and why it was made.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _blue = Color(0xFF3C6E87);

  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const AboutPage());
  }

  @override
  Widget build(BuildContext context) {
    LangScope.of(context); // rebuild when the language changes
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: _blue,
        title: const Text("About"),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
        actions: const [ProfileMenuButton()],
      ),
      endDrawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 64),
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Image.asset("assets/icons/icon_white.png"),
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              "ARISE",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: _blue,
                fontFamily: 'Geist',
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text.verbatim(
              pickLang(
                  'Be ready. Stay safe. Respond together.',
                  'Maging handa. Manatiling ligtas. Tumugon nang sama-sama.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: _blue,
                fontFamily: 'Geist',
              ),
            ),
          ),
          const SizedBox(height: 24),
          _Block(
            icon: Icons.info_outline,
            title: pickLang('What is ARISE?', 'Ano ang ARISE?'),
            body: pickLang(
                'ARISE is a disaster preparedness and emergency response app for school communities. It puts the information people need before, during and after a disaster in one place, on the phone they already carry, and it helps the school respond quickly when something happens.',
                'Ang ARISE ay isang app para sa paghahanda at pagtugon sa sakuna ng mga komunidad ng paaralan. Nasa iisang lugar ang impormasyong kailangan ng bawat isa bago, habang at matapos ang isang sakuna, sa telepono na dala na nila, at tinutulungan nito ang paaralan na tumugon agad kapag may nangyari.'),
          ),
          _Block(
            icon: Icons.lightbulb_outline,
            title: pickLang('Why was it created?', 'Bakit ito ginawa?'),
            body: pickLang(
                'Disasters such as typhoons, floods, earthquakes and fires can strike without much warning, and in a school every minute counts. Guidebooks and evacuation plans are often kept on paper, hard to find, and forgotten until they are needed. Headcounts during a drill or a real evacuation are done by hand, which is slow and easy to get wrong.\n\nARISE was created to close that gap: to make preparedness knowledge easy to reach for everyone, and to make the evacuation response faster, clearer and better organised.',
                'Ang mga sakuna tulad ng bagyo, baha, lindol at sunog ay maaaring dumating nang walang gaanong babala, at sa paaralan ay mahalaga ang bawat minuto. Madalas na nasa papel ang mga gabay at plano sa paglikas, mahirap hanapin, at nakakalimutan hanggang sa kailanganin. Mano-mano rin ang headcount sa drill o tunay na paglikas, kaya mabagal ito at madaling magkamali.\n\nGinawa ang ARISE para punan ang puwang na iyon: gawing madaling maabot ng lahat ang kaalaman sa paghahanda, at gawing mas mabilis, malinaw at maayos ang pagtugon sa paglikas.'),
          ),
          _Block(
            icon: Icons.flag_outlined,
            title: pickLang('Our Vision', 'Ang Aming Bisyon'),
            body: pickLang(
                '•  Help students, teachers and staff know what to do before, during and after a disaster.\n•  Make evacuation routes and emergency contacts easy to find.\n•  Replace paper headcounts with live attendance, so the school knows quickly who is safe and who is missing.\n•  Let the school warn everyone at once when an emergency happens.\n•  Keep a record of drills so each one can be reviewed and improved.',
                '•  Tulungan ang mga estudyante, guro at kawani na malaman ang gagawin bago, habang at matapos ang sakuna.\n•  Gawing madaling mahanap ang mga ruta ng paglikas at mga numero ng emergency.\n•  Palitan ng live na attendance ang papel na headcount, para mabilis malaman ng paaralan kung sino ang ligtas at sino ang nawawala.\n•  Payagan ang paaralan na balaan ang lahat nang sabay-sabay kapag may emergency.\n•  Magtago ng talaan ng mga drill para masuri at mapabuti ang bawat isa.'),
          ),
          _Block(
            icon: Icons.groups_outlined,
            title: pickLang('Our Mission', 'Ang Aming Misyon'),
            body: pickLang(
                'Students read the guidelines, see the evacuation plan, call emergency contacts and receive alerts. Teachers also take attendance, run drills, send alerts and write the school\'s announcements. Admins look after the accounts and the content of the app.',
                'Ang mga estudyante ay nagbabasa ng mga gabay, tumitingin sa plano sa paglikas, tumatawag sa mga numero ng emergency at tumatanggap ng mga alerto. Ang mga guro ay kumukuha rin ng attendance, nagsasagawa ng drill, nagpapadala ng alerto at sumusulat ng mga anunsyo ng paaralan. Ang mga admin ang nangangalaga sa mga account at nilalaman ng app.'),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text.verbatim(
              pickLang('In an emergency, always follow your school\'s instructions and call the emergency numbers.',
                  'Sa oras ng emergency, laging sundin ang mga tagubilin ng inyong paaralan at tumawag sa mga numero ng emergency.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: _blue, fontFamily: 'Geist'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

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
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.verbatim(
                  title,
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
          Text.verbatim(
            body,
            style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF3C6E87),
                fontFamily: 'Geist'),
          ),
        ],
      ),
    );
  }
}
