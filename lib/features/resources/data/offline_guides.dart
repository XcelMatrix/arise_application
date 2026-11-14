import 'package:flutter/material.dart';
import 'package:arise_application/translations/translation.dart';

/// Emergency guides that ship inside the app, so they open with no signal,
/// even on a phone that has never been online. (The school's own editable
/// guidelines are saved on the phone the last time it was online.)
///
/// Every text has an English and a Filipino version. To add another
/// language, add its code (for example 'es') next to 'en' and 'fil'; a
/// language without text falls back to English.
class Say {
  const Say(this.by);
  final Map<String, String> by;

  String get text => by[Tr.current.code] ?? by['en'] ?? '';
}

class SaySteps {
  const SaySteps(this.by);
  final Map<String, List<String>> by;

  List<String> get steps => by[Tr.current.code] ?? by['en'] ?? const [];
}

class GuideSection {
  const GuideSection(this.heading, this.steps);
  final Say heading;
  final SaySteps steps;
}

class OfflineGuide {
  const OfflineGuide({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.summary,
    required this.sections,
    this.callNote,
  });

  final String id;
  final IconData icon;
  final Color color;
  final Say title;
  final Say summary;
  final List<GuideSection> sections;

  /// shown in a red box at the top ("Call 911 ...")
  final Say? callNote;
}

const offlineGuides = <OfflineGuide>[
  // ------------------------------------------------------------ evacuation
  OfflineGuide(
    id: 'evacuation',
    icon: Icons.directions_run,
    color: Color(0xFFE65100),
    title: Say({'en': 'Evacuation steps', 'fil': 'Mga hakbang sa paglikas'}),
    summary: Say({
      'en': 'What to do when the alarm sounds or you are told to evacuate.',
      'fil': 'Ang gagawin kapag tumunog ang alarma o inutusang lumikas.',
    }),
    sections: [
      GuideSection(
        Say({'en': 'When the alarm sounds', 'fil': 'Kapag tumunog ang alarma'}),
        SaySteps({
          'en': [
            'Stay calm. Stop what you are doing and listen to your teacher.',
            'Leave your bags and belongings behind unless your teacher says otherwise.',
            'Line up quickly and quietly. Help classmates who need assistance.',
          ],
          'fil': [
            'Manatiling kalmado. Itigil ang ginagawa at making sa iyong guro.',
            'Iwan ang mga bag at gamit maliban kung iba ang sabihin ng guro.',
            'Mabilis at tahimik na pumila. Tulungan ang mga kaklaseng nangangailangan ng tulong.',
          ],
        }),
      ),
      GuideSection(
        Say({'en': 'On the way out', 'fil': 'Sa paglabas'}),
        SaySteps({
          'en': [
            'Use the nearest safe exit and the route shown on the Evacuation Map.',
            'Walk, do not run. Do not push. Keep to the right on stairs.',
            'Do not use elevators.',
            'If there is smoke, stay low and cover your nose and mouth with cloth.',
            'Before opening a door, feel it with the back of your hand. If it is hot, do not open it and use another way out.',
            'Do not go back inside for any reason.',
          ],
          'fil': [
            'Gamitin ang pinakamalapit na ligtas na labasan at ang ruta sa Mapa ng Paglikas.',
            'Maglakad, huwag tumakbo. Huwag magtulakan. Sa hagdan, manatili sa kanan.',
            'Huwag gumamit ng elevator.',
            'Kung may usok, yumuko nang mababa at takpan ang ilong at bibig ng tela.',
            'Bago magbukas ng pinto, damhin muna ito ng likod ng kamay. Kung mainit, huwag buksan at humanap ng ibang daan.',
            'Huwag nang bumalik sa loob para sa anumang dahilan.',
          ],
        }),
      ),
      GuideSection(
        Say({'en': 'At the evacuation site', 'fil': 'Sa evacuation site'}),
        SaySteps({
          'en': [
            'Go to your class\'s evacuation site and stay with your class.',
            'Wait for your teacher to take attendance. Tell your teacher right away if someone is missing or hurt.',
            'Stay in the open, away from buildings, trees, wires and glass.',
            'Do not leave the site until officials say it is safe.',
          ],
          'fil': [
            'Pumunta sa evacuation site ng inyong klase at manatili kasama ang klase.',
            'Hintayin ang guro na magtala ng attendance. Sabihin agad sa guro kung may nawawala o nasaktan.',
            'Manatili sa bukas na lugar, malayo sa mga gusali, puno, kable at salamin.',
            'Huwag umalis sa site hangga\'t hindi sinasabi ng mga opisyal na ligtas na.',
          ],
        }),
      ),
    ],
  ),

  // ------------------------------------------------------------- first aid
  OfflineGuide(
    id: 'first_aid',
    icon: Icons.medical_services,
    color: Color(0xFFC62828),
    title: Say({'en': 'First aid', 'fil': 'Pangunang lunas'}),
    summary: Say({
      'en': 'Basic first aid until trained help arrives.',
      'fil': 'Pangunahing lunas habang hinihintay ang sinanay na tulong.',
    }),
    callNote: Say({
      'en': 'For serious injuries, trouble breathing, or someone who is unconscious, call for help first: 911 (or the school nurse and principal on the Emergency Contacts page).',
      'fil': 'Para sa malulubhang sugat, hirap sa paghinga, o taong walang malay, tumawag muna ng tulong: 911 (o ang nars at punong-guro sa pahina ng Emergency Contacts).',
    }),
    sections: [
      GuideSection(
        Say({'en': 'Bleeding', 'fil': 'Pagdurugo'}),
        SaySteps({
          'en': [
            'Press firmly on the wound with a clean cloth or gauze.',
            'Keep pressing. If blood soaks through, add more cloth on top; do not remove the first one.',
            'If it is an arm or leg, raise it above the heart if there is no suspected broken bone.',
            'Get help for deep wounds or bleeding that does not stop.',
          ],
          'fil': [
            'Diinan nang mahigpit ang sugat gamit ang malinis na tela o gasa.',
            'Ituloy ang pagdiin. Kung tumagos ang dugo, dagdagan ng tela sa ibabaw; huwag tanggalin ang una.',
            'Kung braso o binti, itaas ito nang mas mataas sa puso kung hindi pinaghihinalaang bali.',
            'Humingi ng tulong kung malalim ang sugat o hindi tumitigil ang pagdurugo.',
          ],
        }),
      ),
      GuideSection(
        Say({'en': 'Burns', 'fil': 'Paso'}),
        SaySteps({
          'en': [
            'Cool the burn under cool running water for at least 10 minutes.',
            'Remove rings or tight items near the burn before it swells.',
            'Do not use ice, butter, toothpaste or oil. Do not pop blisters.',
            'Cover loosely with a clean, non-fluffy cloth.',
            'Get medical help for large burns, or burns on the face, hands or genitals.',
          ],
          'fil': [
            'Palamigin ang paso sa malamig na umaagos na tubig nang hindi bababa sa 10 minuto.',
            'Tanggalin ang singsing o masisikip na bagay malapit sa paso bago ito mamaga.',
            'Huwag gumamit ng yelo, mantikilya, toothpaste o mantika. Huwag pumutok ng paltos.',
            'Takpan nang maluwag ng malinis na telang walang himulmol.',
            'Humingi ng tulong medikal para sa malalaking paso, o paso sa mukha, kamay o ari.',
          ],
        }),
      ),
      GuideSection(
        Say({'en': 'Fainting', 'fil': 'Pagkahilo at pagkawala ng malay'}),
        SaySteps({
          'en': [
            'Lay the person on their back and raise their legs about 30 cm.',
            'Loosen tight clothing and give them fresh air.',
            'Check that they are breathing. If they are not responding or not breathing normally, call for help and start CPR if you are trained.',
            'When they wake up, let them rest. Do not give food or drink until they are fully alert.',
          ],
          'fil': [
            'Ihiga ang tao nang nakatihaya at itaas ang mga binti nang mga 30 cm.',
            'Luwagan ang masisikip na damit at bigyan ng sariwang hangin.',
            'Tiyaking humihinga siya. Kung hindi siya tumutugon o hindi normal ang paghinga, tumawag ng tulong at magsimula ng CPR kung sinanay ka.',
            'Kapag nagising, hayaang magpahinga. Huwag pakainin o painumin hangga\'t hindi lubos na gising.',
          ],
        }),
      ),
      GuideSection(
        Say({'en': 'Choking', 'fil': 'Nabulunan'}),
        SaySteps({
          'en': [
            'If the person can cough, speak or breathe, encourage them to keep coughing.',
            'If they cannot breathe, cough or speak, call for help.',
            'Give up to 5 firm back blows between the shoulder blades.',
            'Then give up to 5 abdominal thrusts: stand behind, wrap your arms around the waist, and pull sharply inward and upward above the belly button.',
            'Alternate 5 back blows and 5 thrusts until the object comes out or the person becomes unresponsive. Then start CPR if you are trained.',
            'Infants and very young children: get trained help right away.',
          ],
          'fil': [
            'Kung nakaka-ubo, nakapagsasalita o nakahihinga pa ang tao, himukin siyang ituloy ang pag-ubo.',
            'Kung hindi siya makahinga, makaubo o makapagsalita, tumawag ng tulong.',
            'Magbigay ng hanggang 5 matitibay na palo sa likod, sa pagitan ng mga talim ng balikat.',
            'Pagkatapos, magbigay ng hanggang 5 abdominal thrust: tumayo sa likod, yakapin ang baywang, at hilahin nang mabilis papasok at pataas sa itaas ng pusod.',
            'Salitan ang 5 palo sa likod at 5 thrust hanggang lumabas ang bagay o mawalan ng malay ang tao. Saka magsimula ng CPR kung sinanay ka.',
            'Sanggol at napakabatang bata: humingi agad ng tulong mula sa sinanay.',
          ],
        }),
      ),
      GuideSection(
        Say({'en': 'Sprain or broken bone', 'fil': 'Pilay o bali'}),
        SaySteps({
          'en': [
            'Keep the person still. Do not try to straighten the injured part.',
            'Support the injured part in the position you found it (a sling or folded cloth helps).',
            'Place a cold pack wrapped in cloth on it for 15 to 20 minutes.',
            'Get medical help. Call for help if there is heavy bleeding, bone showing, or a neck, back or head injury; do not move the person.',
          ],
          'fil': [
            'Panatilihing hindi gumagalaw ang tao. Huwag subukang ituwid ang napinsalang bahagi.',
            'Alalayan ang napinsalang bahagi sa posisyong nadatnan (makatutulong ang sling o nakatuping tela).',
            'Maglagay ng cold pack na nakabalot sa tela nang 15 hanggang 20 minuto.',
            'Humingi ng tulong medikal. Tumawag ng saklolo kung malakas ang dugo, may nakalabas na buto, o may pinsala sa leeg, likod o ulo; huwag igalaw ang tao.',
          ],
        }),
      ),
      GuideSection(
        Say({
          'en': 'Not breathing (CPR, if trained)',
          'fil': 'Hindi humihinga (CPR, kung sinanay)',
        }),
        SaySteps({
          'en': [
            'Shout for help and send someone to call 911 and get an AED if there is one.',
            'Place the heel of your hand on the center of the chest and push hard and fast, about 5 cm deep, at 100 to 120 pushes a minute.',
            'Let the chest rise fully between pushes.',
            'If you are trained, give 2 rescue breaths after every 30 pushes. If not, keep pushing without stopping.',
            'Continue until help arrives or the person starts breathing.',
          ],
          'fil': [
            'Sumigaw ng saklolo at utusan ang iba na tumawag sa 911 at kumuha ng AED kung mayroon.',
            'Ilagay ang palad sa gitna ng dibdib at diinan nang malakas at mabilis, mga 5 cm ang lalim, 100 hanggang 120 diin kada minuto.',
            'Hayaang tumaas nang buo ang dibdib sa pagitan ng bawat diin.',
            'Kung sinanay ka, magbigay ng 2 rescue breath pagkatapos ng bawat 30 diin. Kung hindi, ituloy ang pagdiin nang walang tigil.',
            'Ituloy hanggang dumating ang tulong o magsimulang huminga ang tao.',
          ],
        }),
      ),
    ],
  ),

  // -------------------------------------------------------------- lockdown
  OfflineGuide(
    id: 'lockdown',
    icon: Icons.lock,
    color: Color(0xFF283593),
    title: Say({'en': 'Lockdown procedure', 'fil': 'Pamamaraan sa lockdown'}),
    summary: Say({
      'en': 'What to do when there is a threat inside or near the school.',
      'fil': 'Ang gagawin kapag may banta sa loob o malapit sa paaralan.',
    }),
    sections: [
      GuideSection(
        Say({'en': 'Right away', 'fil': 'Agad-agad'}),
        SaySteps({
          'en': [
            'Get everyone into the nearest room. Students in the hallway go to the closest classroom.',
            'Lock or barricade the door. Turn off the lights.',
            'Close curtains and blinds if you can do so safely.',
            'Move away from doors and windows, out of sight.',
          ],
          'fil': [
            'Papasukin ang lahat sa pinakamalapit na silid. Ang mga estudyante sa pasilyo ay pupunta sa pinakamalapit na silid-aralan.',
            'I-lock o harangan ang pinto. Patayin ang ilaw.',
            'Isara ang kurtina kung ligtas itong gawin.',
            'Lumayo sa mga pinto at bintana, at huwag magpakita sa labas.',
          ],
        }),
      ),
      GuideSection(
        Say({'en': 'While locked down', 'fil': 'Habang naka-lockdown'}),
        SaySteps({
          'en': [
            'Stay quiet and keep low. Silence your phone, including vibration.',
            'Do not open the door for anyone until officials give the all-clear.',
            'Teachers take attendance quietly and note anyone missing or hurt.',
            'Use the app only for official alerts and to report emergencies. Do not post or share rumors.',
            'Follow the instructions of school officials and responders.',
          ],
          'fil': [
            'Manatiling tahimik at nakayuko. I-silent ang telepono, pati ang vibration.',
            'Huwag magbukas ng pinto para kaninuman hangga\'t hindi nagbibigay ng all-clear ang mga opisyal.',
            'Tahimik na magtatala ng attendance ang mga guro at itatala ang sinumang nawawala o nasaktan.',
            'Gamitin ang app para lamang sa opisyal na alerto at pag-uulat ng emergency. Huwag magpakalat ng tsismis.',
            'Sundin ang mga tagubilin ng mga opisyal ng paaralan at mga rumesponde.',
          ],
        }),
      ),
      GuideSection(
        Say({'en': 'When it ends', 'fil': 'Kapag natapos na'}),
        SaySteps({
          'en': [
            'Stay put until you receive the all-clear from school officials.',
            'If you are told to leave, walk calmly with your hands visible and follow instructions.',
            'Go to the assigned meeting area and wait for attendance.',
          ],
          'fil': [
            'Manatili hanggang makatanggap ng all-clear mula sa mga opisyal ng paaralan.',
            'Kung inutusang lumabas, mahinahong maglakad na nakikita ang mga kamay at sundin ang mga tagubilin.',
            'Pumunta sa itinakdang pulungan at hintayin ang attendance.',
          ],
        }),
      ),
    ],
  ),
];
