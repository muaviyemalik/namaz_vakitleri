// lib/data/ozel_gunler.dart
//
// Özel gün içerikleri — uygulamanın desteklediği 25 dilin tamamı.
//
// Bu dosya arayüz çevirisi DEĞİLDİR. Başlık ("special_days") ve "Kapat"
// düğmesi `assets/i18n/ceviri/<3-harfli>.json` dosyalarından, aracın
// `easy_localization` ile gelir. Buradaki veri ise günlerin *içeriğidir*
// (isim, miladi/hicri tarih, açıklama) ve easy_localization'ın kapsamı
// dışındadır: o, JSON çeviri dosyalarını okur, Dart haritası okumaz.
//
// ANAHTAR DİLİ: ISO 639-1 (2 harf). Uygulamanın locale'i ISO 639-2/3
// (3 harfli) olduğu için (tur, eng, zho) çağıran taraf önce
// `icerikDilKodu()` ile 2 harfli karşılığa çevirir. Bkz. lib/utils/icerik_dili.dart.
//
// DİL LİSTESİ: 25 dilin tamamı burada. `assets/i18n/ceviri/` içindeki dosya
// adlarıyla birebir eşleşir; yeni bir çeviri dosyası eklenirse (örn. `hin.json`)
// buraya `hin` anahtarıyla bir blok eklenmelidir. Eksik dil yedeğe düşer
// (bkz. `ozelGunleriGetir` sonundaki `?? ozelGunler['en']`), yani eksik
// blok uygulamayı bozmaz, sadece içeriği İngilizce gösterir.
//
// NOT: `ikon` alanı dil bağımsızdır; her dilde aynı 9 ikon tekrarlanır.
// Sembol adları `ozelGunler_sayfasi.dart` içindeki `DiniGun._ikonBelirle`
// ile eşleşmelidir; oraya yeni bir ikon eklenirse bu dosyadaki 25 bloğun
// tamamında da karşılığı bulunmalıdır.
//
// YÖN: Arapça (ar), Farsça (fa) ve Türkmence (tk) sağdan sola yazılır.
// Yön katalogdan (`Dil.yon`) MaterialApp düzeyinde uygulandığı için bu
// dosyada ayrıca bir işlem gerekmez; ListTile ve Text hizalamayı kendileri
// çözer. Yine de açıklama metinleri o dillerde doğal cümle düzeninde yazılmıştır.
import '../utils/icerik_dili.dart';

class OzelGunler {
  static final Map<String, List<Map<String, String>>> ozelGunler = {
    // ---------------------------------------------------------------- AMHARİKÇE
    'am': [
      {
        "isim": "እስራ እና ምርጃ ሌሊት",
        "tarih": "15 ጃንዩዋሪ 2026",
        "hicriTarih": "26 ራጅብ 1447",
        "aciklama": "እርሱ ሁሉንም ለሰላም የሰደዩ መልካሽ በመስክ ከመዋጮና በመስክና ለዓል ጽዳና በላይ ወደ ሰማያ ተላልፏ የአንድን ድል ያለው እጅግ አስገርሚ ሌሊት ነው።",
        "ikon": "auto_awesome"
      },
      {
        "isim": "በራዓት ሌሊት",
        "tarih": "2 ፌብሩዋሪ 2026",
        "hicriTarih": "14 ሻዕባን 1447",
        "aciklama": "ከፍላ የሚጸዳ የመስረዝ ታሪን የእርሱ ሠላም ያለው ሌሊት ነው።",
        "ikon": "nightlight_round"
      },
      {
        "isim": "ረምዥን መጀመሪያ",
        "tarih": "19 ፌብሩዋሪ 2026",
        "hicriTarih": "1 ረምዥን 1447",
        "aciklama": "ውሻ የሚፈጸምበት የተበረጠው ወር ሲሆን፣ «የአስራ አንድ ወራት ንጉሥ» ተብሎ ይባሃል።",
        "ikon": "brightness_3"
      },
      {
        "isim": "ቀደር ሌሊት (ሌልጤል ቅደር)",
        "tarih": "16 ማርች 2026",
        "hicriTarih": "27 ረምዥን 1447",
        "aciklama": "ቅዱስ ቆርአን የወረደበት ሌሊት ሲሆን፣ ከሠራሽ ወራት በጣም ጥሩ ነው።",
        "ikon": "star"
      },
      {
        "isim": "ኢድአል ፊትር",
        "tarih": "20 ማርች 2026",
        "hicriTarih": "1 ሸዋላል 1447",
        "aciklama": "የረምዥን ውሻን ካጠናቀቁ በኋላ ሙስልሞች የሚሰጥታቸው የሰላም ቀናት ናቸው።",
        "ikon": "celebration"
      },
      {
        "isim": "ኢድአል አድሃ",
        "tarih": "27 ሜይ 2026",
        "hicriTarih": "10 ዘልጂጅ 1447",
        "aciklama": "በላም የሚፈጸምበት፣ እርዳታና ሙርታ ከፍተኛ ደረጃ የሚደርሱበት በእርሱ ነው።",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "የሂጅሪ ዓመት አጀም",
        "tarih": "16 ጁን 2026",
        "hicriTarih": "1 ሙሐረረም 1448",
        "aciklama": "የኢስላማዊ መቁጠሪያ የመጀመሪያ ቀን ሲሆን፣ የአባችንን ምርስ (ሐዘላው ላይ ሰላም) ሃይጣት ከሜክካ ወደ ሚዲና ካለው በመሠረት ነው።",
        "ikon": "event"
      },
      {
        "isim": "የአሹራ ቀን",
        "tarih": "25 ጁን 2026",
        "hicriTarih": "10 ሙሐረረም 1448",
        "aciklama": "በርክናና በማጋራት የሚታምን ቀን ሲሆን፣ በነቢያት በመንገድ ብዙ አስፈጣን መከለከሎች የሆኑበት ቀን ነው።",
        "ikon": "local_dining"
      },
      {
        "isim": "የሙምዊድ ሌሊት",
        "tarih": "24 ኦገስት 2026",
        "hicriTarih": "11 ራቢይኤል አውዋል 1448",
        "aciklama": "እርሱ ሁሉንም ዓለም ንጉሥ ሆነው የተላከበት የአባችንን ምርስ (ሐዘላው ላይ ሰላም) የወለደበት ሌሊት ነው።",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- ARAPÇA
    'ar': [
      {
        "isim": "ليلة الإسراء والمعراج",
        "tarih": "15 يناير 2026",
        "hicriTarih": "26 رجب 1447",
        "aciklama": "الليلة التي أُسرى فيها النبي محمد صلى الله عليه وسلم من المسجد الحرام إلى المسجد الأقصى، ثم عُرج به إلى السماوات.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "ليلة البراءة",
        "tarih": "2 فبراير 2026",
        "hicriTarih": "14 شعبان 1447",
        "aciklama": "ليلة المغفرة والرضا، تُطهَّر فيها قلوب المسلمين وتُقبل دعاؤهم.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "بداية شهر رمضان",
        "tarih": "19 فبراير 2026",
        "hicriTarih": "1 رمضان 1447",
        "aciklama": "شهر مبارك تُصام فيه الأيام، ويُسمّى أمّ الشهور.",
        "ikon": "brightness_3"
      },
      {
        "isim": "ليلة القدر",
        "tarih": "16 مارس 2026",
        "hicriTarih": "27 رمضان 1447",
        "aciklama": "الليلة التي نزل فيها القرآن الكريم، وهي خير من ألف شهر.",
        "ikon": "star"
      },
      {
        "isim": "عيد الفطر",
        "tarih": "20 مارس 2026",
        "hicriTarih": "1 شوال 1447",
        "aciklama": "أيام يشارك فيها المسلمون فرحهم بعد إتمام صيام رمضان.",
        "ikon": "celebration"
      },
      {
        "isim": "عيد الأضحى",
        "tarih": "27 مايو 2026",
        "hicriTarih": "10 ذو الحجة 1447",
        "aciklama": "العيد الذي تُ فيه الأضاحي، وتبلغ فيه التكافل والإحسان ذروته.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "رأس السنة الهجرية",
        "tarih": "16 يونيو 2026",
        "hicriTarih": "1 محرم 1448",
        "aciklama": "أول أيام التقويم الهجري، الذي يستند إلى هجرة النبي محمد صلى الله عليه وسلم من مكة إلى المدينة.",
        "ikon": "event"
      },
      {
        "isim": "يوم عاشوراء",
        "tarih": "25 يونيو 2026",
        "hicriTarih": "10 محرم 1448",
        "aciklama": "يوم بركة ومشاركة، وقعت في حياة الأنبياء فيه أحداث عظيمة كثيرة.",
        "ikon": "local_dining"
      },
      {
        "isim": "ليلة المولد النبوي",
        "tarih": "24 أغسطس 2026",
        "hicriTarih": "11 ربيع الأول 1448",
        "aciklama": "الليلة التي وُلد فيها النبي محمد صلى الله عليه وسلم، رحمةً للعالمين.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- BENGALCE
    'bn': [
      {
        "isim": "ইসরা মিরাজ রাত",
        "tarih": "১৫ জানুয়ারি ২০২৬",
        "hicriTarih": "২৬ রজব ১৪৪৭",
        "aciklama": "সেই অসাধারণ রাত, যে রাতে আমাদের নবী (সাল্লাল্লাহু আলাইহি ওয়া সাল্লাম) মসজিদুল হারাম থেকে মসজিদুল আকসায় এবং তারপর আসমানে উন্নীত হয়েছিলেন।",
        "ikon": "auto_awesome"
      },
      {
        "isim": "বরা আআতের রাত",
        "tarih": "২ ফেব্রুয়ারি ২০২৬",
        "hicriTarih": "১৪ শাবান ১৪৪৭",
        "aciklama": "পাপ থেকে পবিত্রতা, ক্ষমা, মাধ্যম এবং আল্লাহর রহমতের রাত।",
        "ikon": "nightlight_round"
      },
      {
        "isim": "রমজানের শুরু",
        "tarih": "১৯ ফেব্রুয়ারি ২০২৬",
        "hicriTarih": "১ রমজান ১৪৪৭",
        "aciklama": "সিয়াম সাধন করা পবিত্র মাস, যাকে ‘এগারো মাসের সুলতান’ বলা হয়।",
        "ikon": "brightness_3"
      },
      {
        "isim": "কদর রাত (লাইলাতুল কদর)",
        "tarih": "১৬ মার্চ ২০২৬",
        "hicriTarih": "২৭ রমজান ১৪৪৭",
        "aciklama": "যে রাতে পবিত্র কুরআন নাযিল হয়, যা হাজার মাসের চেয়ে উত্তম।",
        "ikon": "star"
      },
      {
        "isim": "ঈদুল ফিতর",
        "tarih": "২০ মার্চ ২০২৬",
        "hicriTarih": "১ শাওয়াল ১৪৪৭",
        "aciklama": "রমজানের সিয়াম পালন করার পর মুসলমানরা যেই দিনগুলিতে আনন্দ ভাগ করে নেন।",
        "ikon": "celebration"
      },
      {
        "isim": "ঈদুল আযহা",
        "tarih": "২৭ মে ২০২৬",
        "hicriTarih": "১০ জুলহাজ্জাহ ১৪৪৭",
        "aciklama": "যে উৎসবে কুরবানি করা হয় এবং পারস্পরিক সাহায্য ও দান চরমে পৌঁছায়।",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "হিজরি নববর্ষ",
        "tarih": "১৬ জুন ২০২৬",
        "hicriTarih": "১ মুহাররম ১৪৪৮",
        "aciklama": "হিজরি পঞ্জিকার প্রথম দিন, যা আমাদের নবীর (সাল্লাল্লাহু আলাইহি ওয়া সাল্লাম) মক্কা থেকে মদিনায় হিজরতের ভিত্তিতে গড়ে উঠেছে।",
        "ikon": "event"
      },
      {
        "isim": "আশুরার দিন",
        "tarih": "২৫ জুন ২০২৬",
        "hicriTarih": "১০ মুহাররম ১৪৪৮",
        "aciklama": "বরকত ও ভাগাভাগির দিন, যেদিন নবীদের জীবনে অনেক গুরুত্বপূর্ণ ঘটনা ঘটেছিল।",
        "ikon": "local_dining"
      },
      {
        "isim": "মওলিদের রাত",
        "tarih": "২৪ আগস্ট ২০২৬",
        "hicriTarih": "১১ রবিউল আউয়াল ১৪৪৮",
        "aciklama": "সেই রাত, যে রাতে সকল বিশ্বের জন্য রহমত হিসেবে পাঠানো আমাদের নবী (সাল্লাল্লাহু আলাইহি ওয়া সাল্লাম) জন্মগ্রহণ করেন।",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- ALMANCA
    'de': [
      {
        "isim": "Nacht der Himmelfahrt (Isra und Mi'raj)",
        "tarih": "15. Januar 2026",
        "hicriTarih": "26. Rajab 1447",
        "aciklama": "Die wundersame Nacht, in der unser Prophet (Friede sei mit ihm) von der Kaaba-Moschee zur Al-Aqsa-Moschee und dann in die Himmel aufstieg.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "Beraat-Nacht",
        "tarih": "2. Februar 2026",
        "hicriTarih": "14. Scha'ban 1447",
        "aciklama": "Die Nacht der Vergebung, in der die Gläubigen von ihren Sünden gereinigt werden und ihre Gebete angenommen werden.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "Beginn des Ramadans",
        "tarih": "19. Februar 2026",
        "hicriTarih": "1. Ramadan 1447",
        "aciklama": "Der gesegnete Monat, in dem das Fasten vollzogen wird, auch „König der elf Monate“ genannt.",
        "ikon": "brightness_3"
      },
      {
        "isim": "Nacht der Bestimmung (Lailat al-Qadr)",
        "tarih": "16. März 2026",
        "hicriTarih": "27. Ramadan 1447",
        "aciklama": "Die Nacht, in der der Heilige Qur'an geoffenbart wurde, besser als tausend Monate.",
        "ikon": "star"
      },
      {
        "isim": "Eid al-Fitr (Fastenbrechensfest)",
        "tarih": "20. März 2026",
        "hicriTarih": "1. Schauwal 1447",
        "aciklama": "Die Tage, an denen die Muslime nach dem Fasten ihre Freude miteinander teilen.",
        "ikon": "celebration"
      },
      {
        "isim": "Eid al-Adha (Opferfest)",
        "tarih": "27. Mai 2026",
        "hicriTarih": "10. Dhu al-Hiddscha 1447",
        "aciklama": "Das Fest, an dem das Opfer vollzogen wird und Solidarität sowie Nächstenliebe ihren Höhepunkt erreichen.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "Islamisches Neujahr",
        "tarih": "16. Juni 2026",
        "hicriTarih": "1. Muharram 1448",
        "aciklama": "Der erste Tag des islamischen Kalenders, der auf der Hidschra unseres Propheten (Friede sei mit ihm) von Mekka nach Medina beruht.",
        "ikon": "event"
      },
      {
        "isim": "Tag von Aschura",
        "tarih": "25. Juni 2026",
        "hicriTarih": "10. Muharram 1448",
        "aciklama": "Ein Tag des Segens und der Gemeinschaft, an dem viele bedeutende Ereignisse im Leben der Propheten geschahen.",
        "ikon": "local_dining"
      },
      {
        "isim": "Nacht des Mawlid (Geburt des Propheten)",
        "tarih": "24. August 2026",
        "hicriTarih": "11. Rabi' al-Awwal 1448",
        "aciklama": "Die Nacht, in der unser Prophet (Friede sei mit ihm), als Barmherzigkeit für alle Welten gesandt, geboren wurde.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- İNGİLİZCE
    'en': [
      {
        "isim": "Miraj Night",
        "tarih": "15 January 2026",
        "hicriTarih": "26 Rajab 1447",
        "aciklama": "The miraculous night on which our Prophet (peace be upon him) ascended from Al-Masjid Al-Haram to Al-Masjid Al-Aqsa, and then to the heavens.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "Baraat Night",
        "tarih": "2 February 2026",
        "hicriTarih": "14 Sha'ban 1447",
        "aciklama": "The night of purification from sins, forgiveness, intercession, and divine mercy.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "Beginning of Ramadan",
        "tarih": "19 February 2026",
        "hicriTarih": "1 Ramadan 1447",
        "aciklama": "The blessed month in which fasting is observed, known as the sultan of the eleven months.",
        "ikon": "brightness_3"
      },
      {
        "isim": "Night of Power (Laylat al-Qadr)",
        "tarih": "16 March 2026",
        "hicriTarih": "27 Ramadan 1447",
        "aciklama": "The night on which the Holy Qur’an was revealed, better than a thousand months.",
        "ikon": "star"
      },
      {
        "isim": "Eid al-Fitr",
        "tarih": "20 March 2026",
        "hicriTarih": "1 Shawwal 1447",
        "aciklama": "The days when Muslims share joy after completing the fast of Ramadan.",
        "ikon": "celebration"
      },
      {
        "isim": "Eid al-Adha",
        "tarih": "27 May 2026",
        "hicriTarih": "10 Dhu al-Hijjah 1447",
        "aciklama": "The festival during which the sacrifice is performed, and solidarity and charity reach their peak.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "Hijri New Year",
        "tarih": "16 June 2026",
        "hicriTarih": "1 Muharram 1448",
        "aciklama": "The first day of the Hijri calendar, based on our Prophet’s (peace be upon him) migration from Mecca to Medina.",
        "ikon": "event"
      },
      {
        "isim": "Day of Ashura",
        "tarih": "25 June 2026",
        "hicriTarih": "10 Muharram 1448",
        "aciklama": "A day of blessing and sharing, on which many significant events occurred in the lives of the prophets.",
        "ikon": "local_dining"
      },
      {
        "isim": "Mawlid Night",
        "tarih": "24 August 2026",
        "hicriTarih": "11 Rabi' al-Awwal 1448",
        "aciklama": "The night when our Prophet (peace be upon him), sent as a mercy to all worlds, was born.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- FARSAÇA
    'fa': [
      {
        "isim": "شب اسراء و معراج",
        "tarih": "۱۵ ژانویه ۲۰۲۶",
        "hicriTarih": "۲۶ رجب ۱۴۴۷",
        "aciklama": "شبی که پیامبر اکرم (ص) از مسجدالحرام به مسجدالاقصی و سپس به آسمان رفت.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "شب برائت",
        "tarih": "۲ فوریه ۲۰۲۶",
        "hicriTarih": "۱۴ شعبان ۱۴۴۷",
        "aciklama": "شب پاک‌بخشی از گناهان، آمرزش، شفاعت و رحمت الهی.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "آغاز رمضان",
        "tarih": "۱۹ فوریه ۲۰۲۶",
        "hicriTarih": "۱ رمضان ۱۴۴۷",
        "aciklama": "ماه مبارکی که روزه در آن ادا می‌شود و «سلطان یازده ماه» نامیده شده است.",
        "ikon": "brightness_3"
      },
      {
        "isim": "شب قدر",
        "tarih": "۱۶ مارس ۲۰۲۶",
        "hicriTarih": "۲۷ رمضان ۱۴۴۷",
        "aciklama": "شبی که قرآن کریم نازل شد، بهتر از هزار ماه.",
        "ikon": "star"
      },
      {
        "isim": "عید فطر",
        "tarih": "۲۰ مارس ۲۰۲۶",
        "hicriTarih": "۱ شوال ۱۴۴۷",
        "aciklama": "روزهایی که مسلمانان پس از به پایان رساندن روزه رمضان، شادی خود را با هم در میان می‌گذارند.",
        "ikon": "celebration"
      },
      {
        "isim": "عید قربان (عیدضحی)",
        "tarih": "۲۷ مه ۲۰۲۶",
        "hicriTarih": "۱۰ ذی‌الحجه ۱۴۴۷",
        "aciklama": "عیدی که در آن قربانی ادا می‌شود و همدلی و نیکوکاری به اوج خود می‌رسد.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "سال نو هجری",
        "tarih": "۱۶ ژوئن ۲۰۲۶",
        "hicriTarih": "۱ محرم ۱۴۴۸",
        "aciklama": "نخستین روز تقویم هجری که بر هجرت پیامبر اکرم (ص) از مکه به مدینه استوار است.",
        "ikon": "event"
      },
      {
        "isim": "روز عاشورا",
        "tarih": "۲۵ ژوئن ۲۰۲۶",
        "hicriTarih": "۱۰ محرم ۱۴۴۸",
        "aciklama": "روزی از برکت و هم‌بستگی که در زندگی پیامبران رویدادهای مهم فراوانی رخ داده است.",
        "ikon": "local_dining"
      },
      {
        "isim": "شب میلاد",
        "tarih": "۲۴ اوت ۲۰۲۶",
        "hicriTarih": "۱۱ ربیع‌الاول ۱۴۴۸",
        "aciklama": "شبی که پیامبر اکرم (ص)، رحمت برای جهانیان، متولد شد.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- FRANSIZCA
    'fr': [
      {
        "isim": "Nuit de l'Isra et du Mi'raj",
        "tarih": "15 janvier 2026",
        "hicriTarih": "26 Rajab 1447",
        "aciklama": "La nuit prodigieuse durant laquelle notre Prophète (paix sur lui) est monté de la mosquée Al-Haram à la mosquée Al-Aqsa, puis au ciel.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "Nuit du pardon (Laylat al-Bara'a)",
        "tarih": "2 février 2026",
        "hicriTarih": "14 Chaabane 1447",
        "aciklama": "La nuit de la purification des péchés, du pardon, de l'intercession et de la miséricorde divine.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "Début du Ramadan",
        "tarih": "19 février 2026",
        "hicriTarih": "1er Ramadan 1447",
        "aciklama": "Le mois béni où le jeûne est observé, surnommé le sultan des onze mois.",
        "ikon": "brightness_3"
      },
      {
        "isim": "Nuit du Destin (Laylat al-Qadr)",
        "tarih": "16 mars 2026",
        "hicriTarih": "27 Ramadan 1447",
        "aciklama": "La nuit où le Saint Coran a été révélé, meilleure que mille mois.",
        "ikon": "star"
      },
      {
        "isim": "Aïd el-Fitr",
        "tarih": "20 mars 2026",
        "hicriTarih": "1er Chaoual 1447",
        "aciklama": "Les jours où les musulmans partagent leur joie après avoir accompli le jeûne du Ramadan.",
        "ikon": "celebration"
      },
      {
        "isim": "Aïd el-Adha",
        "tarih": "27 mai 2026",
        "hicriTarih": "10 Dhu al-Hidja 1447",
        "aciklama": "La fête au cours de laquelle le sacrifice est accompli et où la solidarité et la charité atteignent leur apogée.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "Nouvel An islamique",
        "tarih": "16 juin 2026",
        "hicriTarih": "1er Mouharram 1448",
        "aciklama": "Le premier jour du calendrier islamique, fondé sur l'hégire de notre Prophète (paix sur lui) de La Mecque à Médine.",
        "ikon": "event"
      },
      {
        "isim": "Jour de l'Achoura",
        "tarih": "25 juin 2026",
        "hicriTarih": "10 Mouharram 1448",
        "aciklama": "Un jour de bénédiction et de partage, où de nombreux événements importants ont eu lieu dans la vie des prophètes.",
        "ikon": "local_dining"
      },
      {
        "isim": "Nuit du Mawlid (Nativité du Prophète)",
        "tarih": "24 août 2026",
        "hicriTarih": "11 Rabi' al-Awwal 1448",
        "aciklama": "La nuit de la naissance de notre Prophète (paix sur lui), envoyé comme miséricorde pour tous les mondes.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- ENDONEZCE
    'id': [
      {
        "isim": "Malam Isra dan Mi'raj",
        "tarih": "15 Januari 2026",
        "hicriTarih": "26 Rajab 1447",
        "aciklama": "Malam ajaib ketika Nabi kita (semoga keselamatan baginya) naik dari Masjid Al-Haram ke Masjid Al-Aqsa, lalu ke langit.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "Malam Nuzul Al-Bara'ah",
        "tarih": "2 Februari 2026",
        "hicriTarih": "14 Sya'ban 1447",
        "aciklama": "Malam yang membersihkan dosa serta menjadi waktu ampunan, syafaat, dan rahmat Allah.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "Awal Ramadan",
        "tarih": "19 Februari 2026",
        "hicriTarih": "1 Ramadan 1447",
        "aciklama": "Bulan suci tempat menjalankan puasa, yang dijuluki sultan sebelas bulan.",
        "ikon": "brightness_3"
      },
      {
        "isim": "Malam Lailatul Qadr",
        "tarih": "16 Maret 2026",
        "hicriTarih": "27 Ramadan 1447",
        "aciklama": "Malam turunnya Al-Qur'an, lebih baik dari seribu bulan.",
        "ikon": "star"
      },
      {
        "isim": "Idulfitri",
        "tarih": "20 Maret 2026",
        "hicriTarih": "1 Syawal 1447",
        "aciklama": "Hari-hari umat Islam berbagi kegembiraan setelah menunaikan puasa Ramadan.",
        "ikon": "celebration"
      },
      {
        "isim": "Idul Adha",
        "tarih": "27 Mei 2026",
        "hicriTarih": "10 Dzulhijjah 1447",
        "aciklama": "Hari raya saat kurban disembelih, di mana gotong royong dan filantropi mencapai puncaknya.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "Tahun Baru Islam",
        "tarih": "16 Juni 2026",
        "hicriTarih": "1 Muharram 1448",
        "aciklama": "Hari pertama kalender Islam, yang berdasar pada hijrah Nabi kita (semoga keselamatan baginya) dari Makkah ke Madinah.",
        "ikon": "event"
      },
      {
        "isim": "Hari Asyura",
        "tarih": "25 Juni 2026",
        "hicriTarih": "10 Muharram 1448",
        "aciklama": "Hari keberkahan dan kebersamaan, ketika banyak peristiwa penting terjadi dalam kehidupan para nabi.",
        "ikon": "local_dining"
      },
      {
        "isim": "Malam Maulid Nabi",
        "tarih": "24 Agustus 2026",
        "hicriTarih": "11 Rabiul Awal 1448",
        "aciklama": "Malam ketika Nabi kita (semoga damai عنه), yang diutus sebagai rahmat bagi seluruh alam, dilahirkan.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- İTALYANCA
    'it': [
      {
        "isim": "Notte dell'Isra e del Mi'raj",
        "tarih": "15 gennaio 2026",
        "hicriTarih": "26 Rajab 1447",
        "aciklama": "La notte prodigiosa in cui il nostro Profeta (pace a lui) salì dalla Moschea Al-Haram alla Moschea Al-Aqsa e poi ai cieli.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "Notte del Perdono (Laylat al-Bara'a)",
        "tarih": "2 febbraio 2026",
        "hicriTarih": "14 Sha'ban 1447",
        "aciklama": "La notte della purificazione dai peccati, del perdono, dell'intercessione e della misericordia divina.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "Inizio del Ramadan",
        "tarih": "19 febbraio 2026",
        "hicriTarih": "1 Ramadan 1447",
        "aciklama": "Il mese benedetto in cui si osserva il digiuno, chiamato il sultano degli undici mesi.",
        "ikon": "brightness_3"
      },
      {
        "isim": "Notte del Destino (Laylat al-Qadr)",
        "tarih": "16 marzo 2026",
        "hicriTarih": "27 Ramadan 1447",
        "aciklama": "La notte in cui fu rivelato il Sacro Corano, migliore di mille mesi.",
        "ikon": "star"
      },
      {
        "isim": "Eid al-Fitr",
        "tarih": "20 marzo 2026",
        "hicriTarih": "1 Shawwal 1447",
        "aciklama": "I giorni in cui i muscolmani condividono la gioia dopo aver completato il digiuno del Ramadan.",
        "ikon": "celebration"
      },
      {
        "isim": "Eid al-Adha",
        "tarih": "27 maggio 2026",
        "hicriTarih": "10 Dhu al-Hijjah 1447",
        "aciklama": "La festa durante la quale viene compiuto il sacrificio e in cui la solidarietà e la carità raggiungono il loro apice.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "Capodanno islamico",
        "tarih": "16 giugno 2026",
        "hicriTarih": "1 Muharram 1448",
        "aciklama": "Il primo giorno del calendario islamico, basato sull'egira del nostro Profeta (pace a lui) da La Mecca a Medina.",
        "ikon": "event"
      },
      {
        "isim": "Giorno di Ashura",
        "tarih": "25 giugno 2026",
        "hicriTarih": "10 Muharram 1448",
        "aciklama": "Un giorno di benedizione e condivisione, in cui si verificarono molti eventi importanti nella vita dei profeti.",
        "ikon": "local_dining"
      },
      {
        "isim": "Notte del Mawlid (Natività del Profeta)",
        "tarih": "24 agosto 2026",
        "hicriTarih": "11 Rabi' al-Awwal 1448",
        "aciklama": "La notte in cui nacque il nostro Profeta (pace a lui), inviato come misericordia per tutti i mondi.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- JAPONCA
    'ja': [
      {
        "isim": "イスラー・ミーラジュの夜",
        "tarih": "2026年1月15日",
        "hicriTarih": "1447年 ラジャブ 26日",
        "aciklama": "先知ムハンマド（至高の平安を）は、マスジド・アル＝ハラームからマスジド・アル＝アクサへ、そして天空へと昇られた、奇跡の夜です。",
        "ikon": "auto_awesome"
      },
      {
        "isim": "バラートの夜",
        "tarih": "2026年2月2日",
        "hicriTarih": "1447年 シャーバン 14日",
        "aciklama": "罪からの清め、許し、執り次ぎ、神の慈悲に満ちた夜です。",
        "ikon": "nightlight_round"
      },
      {
        "isim": "ラマダン開始",
        "tarih": "2026年2月19日",
        "hicriTarih": "1447年 ラマダン 1日",
        "aciklama": "断食が行なわれる聖なる月であり、「十一か月の王」と呼ばれています。",
        "ikon": "brightness_3"
      },
      {
        "isim": "カドールの夜（啓示の夜）",
        "tarih": "2026年3月16日",
        "hicriTarih": "1447年 ラマダン 27日",
        "aciklama": "『クーラン』が啓示された夜であり、千の月よりも尊い夜です。",
        "ikon": "star"
      },
      {
        "isim": "イード・アル＝フィトル",
        "tarih": "2026年3月20日",
        "hicriTarih": "1447年 シャウワル 1日",
        "aciklama": "ラマダンの断食を終えたムスーリムが、喜びを分かち合う日です。",
        "ikon": "celebration"
      },
      {
        "isim": "イード・アル＝アダハ",
        "tarih": "2026年5月27日",
        "hicriTarih": "1447年 ズー・アル＝ヒッジャ 10日",
        "aciklama": "生贄が執り行われるお祭りであり、連帯と博愛がその頂点に達する日です。",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "ヒジュラ暦の新年",
        "tarih": "2026年6月16日",
        "hicriTarih": "1448年 ムハーラム 1日",
        "aciklama": "先知ムハンマド（至高の平安を）のメッカからメディナへの聖遷を基盤とする、ヒジュラ暦の最初の日です。",
        "ikon": "event"
      },
      {
        "isim": "アシュラの日",
        "tarih": "2026年6月25日",
        "hicriTarih": "1448年 ムハーラム 10日",
        "aciklama": "祝福と分かち合いの日であり、先知たちの生涯で多くの重要な出来事が起こった日です。",
        "ikon": "local_dining"
      },
      {
        "isim": "マウリードの夜",
        "tarih": "2026年8月24日",
        "hicriTarih": "1448年 ラビー・アル＝アウワル 11日",
        "aciklama": "全世界への慈悲として遣わされた先知ムハンマド（至高の平安を）が生まれた夜です。",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- KOREECE
    'ko': [
      {
        "isim": "이스라·미라주의 밤",
        "tarih": "2026년 1월 15일",
        "hicriTarih": "1447년 라자브 26일",
        "aciklama": "예언자(평화가 그분에게)를 하자마사드에서 알악사 마스지드에 이르고 다시 하늘로 오신 기이한 밤입니다.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "바라아트의 밤",
        "tarih": "2026년 2월 2일",
        "hicriTarih": "1447년 샤바안 14일",
        "aciklama": "죄를 씻는 용서의 밤으로, 사유의 기도들이 받아들여지는 시간입니다.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "라마단 시작",
        "tarih": "2026년 2월 19일",
        "hicriTarih": "1447년 라마단 1일",
        "aciklama": "단식을 올바르게 지켜내는 성스러운 달로, '열한 달의 왕'이라 불립니다.",
        "ikon": "brightness_3"
      },
      {
        "isim": "까드르의 밤 (레일라툴 카드르)",
        "tarih": "2026년 3월 16일",
        "hicriTarih": "1447년 라마단 27일",
        "aciklama": "성스러운 꾸란이 내려온 밤으로, 천 달보다 더 위대한 밤입니다.",
        "ikon": "star"
      },
      {
        "isim": "이드 알 피트르",
        "tarih": "2026년 3월 20일",
        "hicriTarih": "1447년 샤우왈 1일",
        "aciklama": "라마단의 단식을 마친 무슬림들이 기쁨을 나누는 날입니다.",
        "ikon": "celebration"
      },
      {
        "isim": "이드 알 아다",
        "tarih": "2026년 5월 27일",
        "hicriTarih": "1447년 주르히자 10일",
        "aciklama": "희생이 이루어지고 연대와 자선이 정점에 이르는 거대한 축제입니다.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "이슬람력 설날",
        "tarih": "2026년 6월 16일",
        "hicriTarih": "1448년 무하람 1일",
        "aciklama": "예언자(평화가 그분에게)의 맥카에서 메디나로 이주한 일을 근거로 삼는 이슬람력의 첫날입니다.",
        "ikon": "event"
      },
      {
        "isim": "아슈라의 날",
        "tarih": "2026년 6월 25일",
        "hicriTarih": "1448년 무하람 10일",
        "aciklama": "복과 나눔이 담긴 날로, 선지자들의 일생에서 중요 사건이 많이 일어난 날입니다.",
        "ikon": "local_dining"
      },
      {
        "isim": "마울리드의 밤",
        "tarih": "2026년 8월 24일",
        "hicriTarih": "1448년 라비우 알아왈 11일",
        "aciklama": "온 세상에게 자비로 보내진 예언자(평화가 그분에게)가 태어난 밤입니다.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- BURMECE
    'my': [
      {
        "isim": "အစ္စရာမိဂုတ် ည",
        "tarih": "၂၀၂၆ ဇန်နဝါရီ ၁၅",
        "hicriTarih": "၁၄၄၇ ရကံဘ ၂၆",
        "aciklama": "မိမိတို့၏ နိုင်ငံသား (သက်သာချမ်းသနား) မဟာလာရိတ်မျိုးကြီး မစ္စီဒ်မှ အလ်ဆာမျိုးကြီး မစ္စီဒ်သို့ လျက်လျှော်သွားပြီး ထို့နောက် မိုးလောက်သို့ တက်ဆွေသွားသည့် ထင်ရှားလှသော ညမှာ ဖြစ်ပါသည်။",
        "ikon": "auto_awesome"
      },
      {
        "isim": "ဘရာအတ် ည",
        "tarih": "၂၀၂၆ ဖေဖော်ဝါရီ ၂",
        "hicriTarih": "၁၄၄၇ ရှပ်ဘန် ၁၄",
        "aciklama": "မူလများအပေါ် အပါစိုးမှုများကို စင်ရှင်းရှင်းဖြစ်စေသည့်၊ ချမ်းမြေ့ခွင့်ပြုခြင်း၊ ကုသိုလ်တော်ပေးခြင်းနှင့် အဘုရးအကြီး၏ ကျွန်ုပ်တို့ဆိုင်သော သနားသမတ်များ ထင်ရှားစွာ ပေါ်နေသည့် ညတစ်ညမှာ ဖြစ်ပါသည်။",
        "ikon": "nightlight_round"
      },
      {
        "isim": "ရမ်ဇန် စတင်ခြင်း",
        "tarih": "၂၀၂၆ ဖေဖော်ဝါရီ ၁၉",
        "hicriTarih": "၁၄၄၇ ရမ်ဇန် ၁",
        "aciklama": "ဆောင်ရွက်ပဝပတ် ကျင့်ဝက်ရေး ပြုအပ်ရမည့် အကြံသူကောင်း လဖြစ်ပြီး 'လေးလေးလ၏ မင်းမင်း' ဟူ၍ ခေါ်ဝေါ်ကြသည်။",
        "ikon": "brightness_3"
      },
      {
        "isim": "ကဒေါ် ည",
        "tarih": "၂၀၂၆ မတ်နေ ၁၆",
        "hicriTarih": "၁၄၄၇ ရမ်ဇန် ၂၇",
        "aciklama": "မော်ဒောက်ရွတ်တော်များ လွင့်လာခဲ့သည့် ညဖြစ်ပြီး လေးထောင်ခန့်သော လထက်မှာ ထက်မြက်နေပါသည်။",
        "ikon": "star"
      },
      {
        "isim": "အိထ်အလ်ဖိတ်",
        "tarih": "၂၀၂၆ မတ်နေ ၂၀",
        "hicriTarih": "၁၄၄၇ ရှဝေလ ၁",
        "aciklama": "ရမ်ဇန်လ၏ ဆောင်ရွက်ပဝပတ်ကို ပြီးဆုံးအောင် ဆောင်ရွက်ပဝပတ်ကြီး မူလများက ဝမ်းမြော်မှုများကို အချင်းချင်း ဝေမှတ်ယူကြသည့် ရက်များဖြစ်သည်။",
        "ikon": "celebration"
      },
      {
        "isim": "အိထ်အလ်အဓါ",
        "tarih": "၂၀၂၆ မေ ၂၇",
        "hicriTarih": "၁၄၄၇ ဇူလိဟုဂ် ၁၀",
        "aciklama": "အဓိက ဆောင်ရွက်ပဝပတ် အလုပ်များ လုပ်ဆောင်ရာလုပ်ငန်းနှင့် ပူးပေါ်မှု အထက်ဆုံးသော ရာဇဝင်တမ်းဖြစ်သည်။",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "ဟိဂရီနှစ်ဆန်း ၁",
        "tarih": "၂၀၂၆ ဇွန် ၁၆",
        "hicriTarih": "၁၄၄၈ မူဟာရမ ၁",
        "aciklama": "ဟိဂရီခရစ်နှစ်၏ ပထမဆုံးနေ့ဖြစ်ပြီး မိမိတို့၏ နိုင်ငံသား (သက်သာချမ်းသနား) သည် မက္ကရာမှ မဒေါ်နိုင်းသို့ ပြေးနေသည့်အတွက် ဖြစ်ပါသည်။",
        "ikon": "event"
      },
      {
        "isim": "အရှင်းနေရာ",
        "tarih": "၂၀၂၆ ဇွန် ၂၅",
        "hicriTarih": "၁၄၄၈ မူဟာရမ ၁၀",
        "aciklama": "ကောင်းချီးမှုနှင့် မျှဝေမှုပါရှိသော နေ့တစ်ခုဖြစ်ပြီး နိုင်ငံသားများ၏ ဘဝတွင် အရေးကြီးသော အဖြစ်အပျဂ်များ ဖြစ်ပွားခဲ့သည်။",
        "ikon": "local_dining"
      },
      {
        "isim": "မော်လစ် ည",
        "tarih": "၂၀၂၆ ဩဂုတ် ၂၄",
        "hicriTarih": "၁၄၄၈ ရဘစ်အောက် ၁၁",
        "aciklama": "ကမ္ဘာလောကကို သနားမှုအဖြစ်ရေး ကုသိုလ်ရည်ရွယ်၍ စေလွှတ်ခဲ့သော မိမိတို့၏ နိုင်ငံသား (သက်သာချမ်းသနား) မွေဖွားခဲ့သည့် ညဖြစ်သည်။",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- NEPALCE
    'ne': [
      {
        "isim": "इसरा मिराज रात",
        "tarih": "2026 जनवरी 15",
        "hicriTarih": "1447 रजब 26",
        "aciklama": "त्यो अद्भुत रात, जुन रात हाम्रो नबी (तिनीलाई शान्ति होस्) मस्जिद अल-हरमबाट अल-अक्सा मस्जिद तथा त्यसपछि आकाशमा गए।",
        "ikon": "auto_awesome"
      },
      {
        "isim": "बरा अत रात",
        "tarih": "2026 फेब्रुअरी 2",
        "hicriTarih": "1447 शाबान 14",
        "aciklama": "पापबाट शुद्ध हुने, क्षमा, सिफारिस र दिव्य दयाको रात।",
        "ikon": "nightlight_round"
      },
      {
        "isim": "रमजान सुरु",
        "tarih": "2026 फेब्रुअरी 19",
        "hicriTarih": "1447 रमजान 1",
        "aciklama": "रोजा राख्ने पवित्र महिना, जसलाई 'ग्यारो महिनाको राजा' भनिन्छ।",
        "ikon": "brightness_3"
      },
      {
        "isim": "कादिर रात (लैलतुल कद्र)",
        "tarih": "2026 मार्च 16",
        "hicriTarih": "1447 रमजान 27",
        "aciklama": "पवित्र कुरआन अवतर भएको रात, जुन हजार महिनाभन्दा उत्कृष्ट छ।",
        "ikon": "star"
      },
      {
        "isim": "ईद उल फित्र",
        "tarih": "2026 मार्च 20",
        "hicriTarih": "1447 शौवाल 1",
        "aciklama": "रमजानको रोजा पूरा गरी मुस्लिमहरूले खुसी साझा गर्ने दिनहरू।",
        "ikon": "celebration"
      },
      {
        "isim": "ईद उल अध्हा",
        "tarih": "2026 मे 27",
        "hicriTarih": "1447 जुलिहिज्ज 10",
        "aciklama": "कुर्बानी गरिने, एकजना हुनु र भनी लागि चरममा पुग्ने बलिदानको पर्व।",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "हिज्री नयाँ वर्ष",
        "tarih": "2026 जुन 16",
        "hicriTarih": "1448 मुहार्रम 1",
        "aciklama": "हिज्री पात्राको पहिलो दिन, जुन हाम्रो नबी (तिनीलाई शान्ति होस्) को मक्काबाट मदिनाको हिज्रतमा आधारित छ।",
        "ikon": "event"
      },
      {
        "isim": "आशुराको दिन",
        "tarih": "2026 जुन 25",
        "hicriTarih": "1448 मुहार्रम 10",
        "aciklama": "आशीर्वाद र बाँडफाँटको दिन, जुन नबीहरूको जीवनमा धेरै महत्त्वपूर्ण घटनाहरू भएका थिए।",
        "ikon": "local_dining"
      },
      {
        "isim": "मौलिद रात",
        "tarih": "2026 अगस्ट 24",
        "hicriTarih": "1448 रबिउल अव्वल 11",
        "aciklama": "त्यो रात जब सबै संसारका लागि दया पठाइएका हाम्रो नबी (तिनीलाई शान्ति होस्) जन्म भए।",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- LEHÇE
    'pl': [
      {
        "isim": "Noc Isra i Mi'raj",
        "tarih": "15 stycznia 2026",
        "hicriTarih": "26 Radżab 1447",
        "aciklama": "Cudowna noc, w której nasz Prorok (pokój jemu) wzniósł się z Meczki Al-Haram do Meczki Al-Aksa, a następnie do niebios.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "Noc Przebłagania (Lajlat al-Bara'a)",
        "tarih": "2 lutego 2026",
        "hicriTarih": "14 Szaban 1447",
        "aciklama": "Noc oczyszczenia z grzechów, przebłagania, wstawiennictwa i miłosierdzia Bożego.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "Początek Ramadanu",
        "tarih": "19 lutego 2026",
        "hicriTarih": "1 Ramadan 1447",
        "aciklama": "Błogosławiony miesiąc, w którym praktykuje się post, zwany sułtanem jedenastu miesięcy.",
        "ikon": "brightness_3"
      },
      {
        "isim": "Noc Przesądzenia (Lajlat al-Kadr)",
        "tarih": "16 marca 2026",
        "hicriTarih": "27 Ramadan 1447",
        "aciklama": "Noc, w której zeszło Święte Quran, lepsza niż tysiąc miesięcy.",
        "ikon": "star"
      },
      {
        "isim": "Eid al-Fitr",
        "tarih": "20 marca 2026",
        "hicriTarih": "1 Szawwal 1447",
        "aciklama": "Dni, w których muzułmańce dzielą się radością po zakończeniu postu Ramadana.",
        "ikon": "celebration"
      },
      {
        "isim": "Eid al-Adha",
        "tarih": "27 maja 2026",
        "hicriTarih": "10 Zulhidżdża 1447",
        "aciklama": "Święto, podczas którego składana jest ofiara, a solidarność i miłosierdzie sięgają szczytu.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "Nowy Rok Islamski",
        "tarih": "16 czerwca 2026",
        "hicriTarih": "1 Muharram 1448",
        "aciklama": "Pierwszy dzień kalendarza islamskiego, opartego na hidżrze naszego Proroka (pokój jemu) z Mekki do Medyny.",
        "ikon": "event"
      },
      {
        "isim": "Dzień Aszury",
        "tarih": "25 czerwca 2026",
        "hicriTarih": "10 Muharram 1448",
        "aciklama": "Dzień błogosławieństwa i wspólnoty, w którym miało miejsce wiele ważnych wydarzeń w życiu proroków.",
        "ikon": "local_dining"
      },
      {
        "isim": "Noc Mawlid (Narodziny Proroka)",
        "tarih": "24 sierpnia 2026",
        "hicriTarih": "11 Rabi' al-Awwal 1448",
        "aciklama": "Noc, w której urodził się nasz Prorok (pokój jemu), zesłany jako miłosierdzie dla wszystkich światów.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- PORTEKİZCE
    'pt': [
      {
        "isim": "Noite da Isra e Mi'raj",
        "tarih": "15 de janeiro de 2026",
        "hicriTarih": "26 de Rajab de 1447",
        "aciklama": "A noite prodigiosa em que o nosso Profeta (que a paz esteja sobre ele) subiu da Mesquita Al-Haram para a Mesquita Al-Aqsa e depois aos céus.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "Noite do Perdão (Laylat al-Bara'a)",
        "tarih": "2 de fevereiro de 2026",
        "hicriTarih": "14 de Sha'ban de 1447",
        "aciklama": "A noite da purificação dos pecados, do perdão, da intercessão e da misericórdia divina.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "Início do Ramadão",
        "tarih": "19 de fevereiro de 2026",
        "hicriTarih": "1 de Ramadão de 1447",
        "aciklama": "O mês abençoado em que se observa o jejum, chamado o sultão dos onze meses.",
        "ikon": "brightness_3"
      },
      {
        "isim": "Noite do Destino (Laylat al-Qadr)",
        "tarih": "16 de março de 2026",
        "hicriTarih": "27 de Ramadão de 1447",
        "aciklama": "A noite em que o Sagrado Alcorão foi revelado, melhor que mil meses.",
        "ikon": "star"
      },
      {
        "isim": "Eid al-Fitr",
        "tarih": "20 de março de 2026",
        "hicriTarih": "1 de Shawwal de 1447",
        "aciklama": "Os dias em que os muçulmanos partilham a alegria após concluírem o jejum do Ramadão.",
        "ikon": "celebration"
      },
      {
        "isim": "Eid al-Adha",
        "tarih": "27 de maio de 2026",
        "hicriTarih": "10 de Dhu al-Hijjah de 1447",
        "aciklama": "O festival durante o qual o sacrifício é realizado e em que a solidariedade e a caridade atingem o seu auge.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "Ano Novo Islâmico",
        "tarih": "16 de junho de 2026",
        "hicriTarih": "1 de Muharram de 1448",
        "aciklama": "O primeiro dia do calendário islâmico, baseado na hégira do nosso Profeta (que a paz esteja sobre ele) de Meca para Medina.",
        "ikon": "event"
      },
      {
        "isim": "Dia de Ashura",
        "tarih": "25 de junho de 2026",
        "hicriTarih": "10 de Muharram de 1448",
        "aciklama": "Um dia de bênção e de partilha, no qual aconteceram muitos eventos importantes na vida dos profetas.",
        "ikon": "local_dining"
      },
      {
        "isim": "Noite do Mawlid (Natal do Profeta)",
        "tarih": "24 de agosto de 2026",
        "hicriTarih": "11 de Rabi' al-Awwal de 1448",
        "aciklama": "A noite em que o nosso Profeta (que a paz esteja sobre ele), enviado como misericórdia para todos os mundos, nasceu.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- RUMENCE
    'ro': [
      {
        "isim": "Noaptea Isra și Mi'raj",
        "tarih": "15 ianuarie 2026",
        "hicriTarih": "26 Rajab 1447",
        "aciklama": "Noaptea minunată în care Profetul nostru (pacea lui) s-a ridicat de la Masjid Al-Haram la Masjid Al-Aqsa, apoi la ceruri.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "Noaptea Iertării (Laylat al-Bara'a)",
        "tarih": "2 februarie 2026",
        "hicriTarih": "14 Sha'ban 1447",
        "aciklama": "Noaptea purificării de păcate, a iertării, a mijlocirii și a milei divine.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "Începutul Ramazanului",
        "tarih": "19 februarie 2026",
        "hicriTarih": "1 Ramadan 1447",
        "aciklama": "Luna binecuvântată în care se ține postul, numită suveranul celor unsprezece luni.",
        "ikon": "brightness_3"
      },
      {
        "isim": "Noaptea Destinului (Laylat al-Qadr)",
        "tarih": "16 martie 2026",
        "hicriTarih": "27 Ramadan 1447",
        "aciklama": "Noaptea în care a fost revelat Sfântul Coran, mai bună decât o mie de luni.",
        "ikon": "star"
      },
      {
        "isim": "Eid al-Fitr",
        "tarih": "20 martie 2026",
        "hicriTarih": "1 Shawwal 1447",
        "aciklama": "Zilele în care mușlimanii își împart bucuria după încheierea postului din Ramazan.",
        "ikon": "celebration"
      },
      {
        "isim": "Eid al-Adha",
        "tarih": "27 mai 2026",
        "hicriTarih": "10 Dhu al-Hijjah 1447",
        "aciklama": "Sărbătoarea în care se îndeplinește sacrificiul, iar solidaritatea și milostenia ating apogeul.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "Anul Nou Islamic",
        "tarih": "16 iunie 2026",
        "hicriTarih": "1 Muharram 1448",
        "aciklama": "Prima zi a calendarului islamic, întemeiat pe hijra Profetului nostru (pacea lui) din Mecca la Medina.",
        "ikon": "event"
      },
      {
        "isim": "Ziua Ashoura",
        "tarih": "25 iunie 2026",
        "hicriTarih": "10 Muharram 1448",
        "aciklama": "O zi de binecuvântare și comuniune, în care s-au petrecut multe evenimente importante în viața profeților.",
        "ikon": "local_dining"
      },
      {
        "isim": "Noaptea Mawlid (Nașterea Profetului)",
        "tarih": "24 august 2026",
        "hicriTarih": "11 Rabi' al-Awwal 1448",
        "aciklama": "Noaptea în care s-a născut Profetul nostru (pacea lui), trimis ca milă pentru toate lumile.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- RUSÇA
    'ru': [
      {
        "isim": "Ночь Вознесения (Исра и Ми'раж)",
        "tarih": "15 января 2026",
        "hicriTarih": "26 Раджаб 1447",
        "aciklama": "Чудотворная ночь, в которой наш Пророк (мир ему) вознесся от мечети Аль-Харам к мечети Аль-Акса, а затем на небеса.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "Ночь прощения (Лейлат аль-Бараа)",
        "tarih": "2 февраля 2026",
        "hicriTarih": "14 Шаабан 1447",
        "aciklama": "Ночь очищения от грехов, прощения, заступничества и милости Аллаха.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "Начало Рамадана",
        "tarih": "19 февраля 2026",
        "hicriTarih": "1 Рамадан 1447",
        "aciklama": "Благословенный месяц, в котором соблюдается пост, прозванный султаном одиннадцати месяцев.",
        "ikon": "brightness_3"
      },
      {
        "isim": "Ночь предопределения (Лейлятуль-Кадр)",
        "tarih": "16 марта 2026",
        "hicriTarih": "27 Рамадан 1447",
        "aciklama": "Ночь, в которую был ниспущен Священный Коран, лучше тысячи месяцев.",
        "ikon": "star"
      },
      {
        "isim": "Ид аль-Фитр",
        "tarih": "20 марта 2026",
        "hicriTarih": "1 Шауваль 1447",
        "aciklama": "Дни, когда мусульмане делятся радостью после завершения поста Рамадана.",
        "ikon": "celebration"
      },
      {
        "isim": "Ид аль-Адха",
        "tarih": "27 мая 2026",
        "hicriTarih": "10 Зу аль-Хидджа 1447",
        "aciklama": "Праздник, во время которого приносится жертвоприношение, а солидарность и милосердие достигают высшей точки.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "Мусульманский Новый год",
        "tarih": "16 июня 2026",
        "hicriTarih": "1 Мухаррам 1448",
        "aciklama": "Первый день мусульманского календаря, основанного на переселении нашего Пророка (мир ему) из Мекки в Медину.",
        "ikon": "event"
      },
      {
        "isim": "День Ашура",
        "tarih": "25 июня 2026",
        "hicriTarih": "10 Мухаррам 1448",
        "aciklama": "День благословения и щедрости, в жизни пророков которого произошло много значимых событий.",
        "ikon": "local_dining"
      },
      {
        "isim": "Ночь Мавлида (день рождения Пророка)",
        "tarih": "24 августа 2026",
        "hicriTarih": "11 Раби' аль-авваль 1448",
        "aciklama": "Ночь, в которую родился наш Пророк (мир ему), посланный милостью для всех миров.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- İSPANYOLCA
    'es': [
      {
        "isim": "Noche de Isra y Mi'raj",
        "tarih": "15 de enero de 2026",
        "hicriTarih": "26 de Rajab de 1447",
        "aciklama": "La noche prodigiosa en la que nuestro Profeta (paz sea con él) ascendió desde la mezquita Al-Haram a la mezquita Al-Aqsa y luego a los cielos.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "Noche del Perdón (Laylat al-Bara'a)",
        "tarih": "2 de febrero de 2026",
        "hicriTarih": "14 de Sha'ban de 1447",
        "aciklama": "La noche de la purificación de los pecados, el perdón, la intercesión y la misericordia divina.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "Inicio del Ramadán",
        "tarih": "19 de febrero de 2026",
        "hicriTarih": "1 de Ramadán de 1447",
        "aciklama": "El mes bendito en el que se observa el ayuno, denominado el sultán de los once meses.",
        "ikon": "brightness_3"
      },
      {
        "isim": "Noche del Destino (Laylat al-Qadr)",
        "tarih": "16 de marzo de 2026",
        "hicriTarih": "27 de Ramadán de 1447",
        "aciklama": "La noche en la que se reveló el Sagrado Corán, mejor que mil meses.",
        "ikon": "star"
      },
      {
        "isim": "Eid al-Fitr",
        "tarih": "20 de marzo de 2026",
        "hicriTarih": "1 de Shawwal de 1447",
        "aciklama": "Los días en que los musulmanes comparten su alegría tras completar el ayuno de Ramadán.",
        "ikon": "celebration"
      },
      {
        "isim": "Eid al-Adha",
        "tarih": "27 de mayo de 2026",
        "hicriTarih": "10 de Dhu al-Hiyya de 1447",
        "aciklama": "La fiesta durante la cual se realiza el sacrificio y en la que la solidaridad y la caridad alcanzan su punto álgido.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "Año Nuevo islámico",
        "tarih": "16 de junio de 2026",
        "hicriTarih": "1 de Muharram de 1448",
        "aciklama": "El primer día del calendario islámico, basado en la hégira de nuestro Profeta (paz sea con él) de La Meca a Medina.",
        "ikon": "event"
      },
      {
        "isim": "Día de Ashura",
        "tarih": "25 de junio de 2026",
        "hicriTarih": "10 de Muharram de 1448",
        "aciklama": "Un día de bendición y de compartir, en el que ocurrieron muchos hechos importantes en la vida de los profetas.",
        "ikon": "local_dining"
      },
      {
        "isim": "Noche del Mawlid (Natividad del Profeta)",
        "tarih": "24 de agosto de 2026",
        "hicriTarih": "11 de Rabi' al-Awwal de 1448",
        "aciklama": "La noche en que nació nuestro Profeta (paz sea con él), enviado como misericordia para todos los mundos.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- TAMILÇE
    'ta': [
      {
        "isim": "இஸ்ரா மீராஜ் இரவு",
        "tarih": "15 ஜனவரி 2026",
        "hicriTarih": "26 ரஜப் 1447",
        "aciklama": "எங்கள் நபி (அவருக்கு அமுதம்) அல்-ஹரம் மஸ்ஜிதிலிருந்து அல்-அக்ஸா மஸ்ஜிதுக்கும், பின்னர் வானங்களுக்கும் ஏறிய அற்புத இரவு.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "பராஅத் இரவு",
        "tarih": "2 பிப்ரவரி 2026",
        "hicriTarih": "14 ஷபான் 1447",
        "aciklama": "பாவங்களிலிருந்து தூய்மை, மன்னிப்பு, பரிந்து செலுதல் மற்றும் அல்லாஹ்வின் அருள் நிறைந்த இரவு.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "ரமலான் தொடக்கம்",
        "tarih": "19 பிப்ரவரி 2026",
        "hicriTarih": "1 ரமலான் 1447",
        "aciklama": "நோன்பு நிறைவேற்றப்படும் புனித மாதம், 'பதினொரு மாதங்களின் சுல்தான்' எனப்படும்.",
        "ikon": "brightness_3"
      },
      {
        "isim": "கதிர் இரவு (லைலதுல் கதிர்)",
        "tarih": "16 மார்ச் 2026",
        "hicriTarih": "27 ரமலான் 1447",
        "aciklama": "புனித குர்ஆன் இறங்கிய இரவு, ஆயிரம் மாதங்களை விடச் சிறந்தது.",
        "ikon": "star"
      },
      {
        "isim": "ஈதுல் பித்ர்",
        "tarih": "20 மார்ச் 2026",
        "hicriTarih": "1 ஷவ்வல் 1447",
        "aciklama": "ரமலான் நோன்பை முடித்த பின் முஸ்லிம்கள் மகிழ்ச்சியைப் பகிர்ந்துகொள்ளும் நாட்கள்.",
        "ikon": "celebration"
      },
      {
        "isim": "ஈதுல் அதா",
        "tarih": "27 மே 2026",
        "hicriTarih": "10 துல்ஹிஜ்ஜா 1447",
        "aciklama": "குர்பானி செய்யப்படும், ஒற்றுமைவும் பண்பும் உச்சத்தை அடையும் பண்டிகை நாள்.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "இஸ்லாமியப் புத்தாண்டு",
        "tarih": "16 ஜூன் 2026",
        "hicriTarih": "1 முஹரம் 1448",
        "aciklama": "எங்கள் நபியின் (அவருக்கு அமுதம்) மக்காவிலிருந்து மதீனாவிற்கான ஹிஜ்ரத்தை அடிப்படையாகக் கொண்ட இஸ்லாமிய நாட்காட்டியின் முதல் நாள்.",
        "ikon": "event"
      },
      {
        "isim": "ஆஷூரா நாள்",
        "tarih": "25 ஜூன் 2026",
        "hicriTarih": "10 முஹரம் 1448",
        "aciklama": "ஆசீர்வதும் பகிர்வும் நிறைந்த நாள், நபிகளின் வாழ்வில் பல முக்கிய நிகழ்வுகள் நடைபெறிய நாள்.",
        "ikon": "local_dining"
      },
      {
        "isim": "மவ்லித் இரவு",
        "tarih": "24 ஆகஸ்ட் 2026",
        "hicriTarih": "11 ரபி உல் அவ்வல் 1448",
        "aciklama": "அனைத்துலகிற்கும் இரங்காக அனுப்பப்பட்ட எங்கள் நபி (அவருக்கு அமுதம்) பிறந்த இரவு.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- TAYCA
    'th': [
      {
        "isim": "คืนเมี๊ยะราจ (อิสรอและมิเราะจ)",
        "tarih": "15 มกราคม 2026",
        "hicriTarih": "26 รายบู 1447",
        "aciklama": "คืนแห่งความมหัศจรรย์ที่ท่านนบี (ขอความสงบารมแก่ท่าน) เสด็จขึ้นจากมัสยิดอัลฮะร่ามไปยังมัสยิดอัล-อักซา แล้วขึ้นสู่สวรรค์",
        "ikon": "auto_awesome"
      },
      {
        "isim": "คืนบะราอัต (เลย์ลัตอัลบะราอะฮ์)",
        "tarih": "2 กุมภาพันธ์ 2026",
        "hicriTarih": "14 ชะอบบัน 1447",
        "aciklama": "คืนแห่งการชำระล้างบาป การให้อภัย การขอสงวน และความเมตตาของอัลลอฮ์",
        "ikon": "nightlight_round"
      },
      {
        "isim": "เริ่มต้นเดือนรอมฎีน",
        "tarih": "19 กุมภาพันธ์ 2026",
        "hicriTarih": "1 รอมฎีน 1447",
        "aciklama": "เดือนมงคลที่มีการถือศีลอด ซึ่งได้รับการขนานนามว่า “กษัตริย์แห่งสิบเอ็ดเดือน”",
        "ikon": "brightness_3"
      },
      {
        "isim": "คืนอัลกัดริ (เลย์ลัตอัลกัดริ)",
        "tarih": "16 มีนาคม 2026",
        "hicriTarih": "27 รอมฎีน 1447",
        "aciklama": "คืนแห่งการประทานอัลกุรอาน ซึ่งดีกว่าหนึ่งพันเดือน",
        "ikon": "star"
      },
      {
        "isim": "อีดิลฟิตริ",
        "tarih": "20 มีนาคม 2026",
        "hicriTarih": "1 ชาวัล 1447",
        "aciklama": "วันที่มุสลิมร่วมเป็นความสุขหลังการถือศีลอดในเดือนรอมฎีน",
        "ikon": "celebration"
      },
      {
        "isim": "อีดิลอัฎฮา",
        "tarih": "27 พฤษภาคม 2026",
        "hicriTarih": "10 ซุลอัญฮิจย์ 1447",
        "aciklama": "วันเฉลิมฉลองที่มีการประพันธ์สัตว์ และความสามัคคีกับการกุศลจะได้สูงสุด",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "ปีใหม่อิสลาม",
        "tarih": "16 มิถุนายน 2026",
        "hicriTarih": "1 มุฮาร์รอม 1448",
        "aciklama": "วันแรกของปฏิทินอิสลาม ซึ่งอ้างอิงการอพยพของท่านนบี (ขอความสงบารมแก่ท่าน) จากมะกระไร่สู่มะดีน",
        "ikon": "event"
      },
      {
        "isim": "วันอาชูรอ",
        "tarih": "25 มิถุนายน 2026",
        "hicriTarih": "10 มุฮาร์รอม 1448",
        "aciklama": "วันแห่งพรและการแบ่งปัน ซึ่งมีเหตุการณ์สำคัญมากมายเกิดขึ้นในชีวิตของบรรดานบี",
        "ikon": "local_dining"
      },
      {
        "isim": "คืนเมาลิด",
        "tarih": "24 สิงหาคม 2026",
        "hicriTarih": "11 รบีอุลอัววอล 1448",
        "aciklama": "คืนแห่งการกำเนิดของท่านนบี (ขอความสงบารมแก่ท่าน) ผู้ถูกส่งมาเป็นความเมตตาต่อโลก",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- TÜRKMENCE
    'tk': [
      {
        "isim": "Meraj baýy",
        "tarih": "15 ýanwar 2026",
        "hicriTarih": "26 Regeb 1447",
        "aciklama": "Möhümminiň (s.a.w.) Mäşheräi Harämdan Mäşheräi Aksä geçip, soňra asmana göterilen gijesi.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "Beraat gijesi",
        "tarih": "2 fevral 2026",
        "hicriTarih": "14 Şa'ban 1447",
        "aciklama": "Günahlardan arassynlanýan, baýş edilýän, şefaat we rahmet gijesi.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "Ramazanyň başlangyçy",
        "tarih": "19 fevral 2026",
        "hicriTarih": "1 Ramazan 1447",
        "aciklama": "Oraç ibadetiniň ýerine ýetirilýän, ýarym aýyň şahy diýlip atlandyrylan mubärek aý.",
        "ikon": "brightness_3"
      },
      {
        "isim": "Kadir gijesi",
        "tarih": "16 mart 2026",
        "hicriTarih": "27 Ramazan 1447",
        "aciklama": "Kuran-ý Kerimiň inen ýeri, mün aýdan has gowud ýa-da has gymmatly bolan gijäniň biri.",
        "ikon": "star"
      },
      {
        "isim": "Oruç baýramy",
        "tarih": "20 mart 2026",
        "hicriTarih": "1 Şewwal 1447",
        "aciklama": "Mysolmanlaryň ýeňilijini bölüşýän günleri.",
        "ikon": "celebration"
      },
      {
        "isim": "Gurban baýramy",
        "tarih": "27 maý 2026",
        "hicriTarih": "10 Zü'l-hicce 1447",
        "aciklama": "Gurban edýän, yardymlaşma we baglanyşyk ýokarlanýan baýram.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "Hijri ýylbaşy",
        "tarih": "16 iýun 2026",
        "hicriTarih": "1 Muharrem 1448",
        "aciklama": "Möhümminiň (s.a.w.) Mekke'den Medine'ye gitmegine esaslanan hijri takwimiň ilkinji güni.",
        "ikon": "event"
      },
      {
        "isim": "Aşüre güni",
        "tarih": "25 iýun 2026",
        "hicriTarih": "10 Muharrem 1448",
        "aciklama": "Päygamberleriň durmuşynda köp möhüm hadysalaryň bolup geçen, bereket we paýlaşyk güni.",
        "ikon": "local_dining"
      },
      {
        "isim": "Mäwlid gijesi",
        "tarih": "24 avgust 2026",
        "hicriTarih": "11 Rebiýüwelwel 1448",
        "aciklama": "Möhümminiň (s.a.w.) äleme rahmet hökmünde däl edilen tebigy bilen dünýä gelen gijesi.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- TÜRKÇE
    'tr': [
      {
        "isim": "Miraç Kandili",
        "tarih": "15 Ocak 2026",
        "hicriTarih": "26 Recep 1447",
        "aciklama": "Peygamber Efendimiz'in (s.a.v) Mescid-i Haram'dan Mescid-i Aksa'ya, oradan da göğe yükseldiği mucizevi gecedir.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "Berat Kandili",
        "tarih": "2 Şubat 2026",
        "hicriTarih": "14 Şaban 1447",
        "aciklama": "Günahlardan arınma, af, şefaat ve mağfiret gecesidir.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "Ramazan Başlangıcı",
        "tarih": "19 Şubat 2026",
        "hicriTarih": "1 Ramazan 1447",
        "aciklama": "On bir ayın sultanı, oruç ibadetinin yerine getirildiği mübarek aydır.",
        "ikon": "brightness_3"
      },
      {
        "isim": "Kadir Gecesi",
        "tarih": "16 Mart 2026",
        "hicriTarih": "27 Ramazan 1447",
        "aciklama": "Kur'an-ı Kerim'in indirildiği, bin aydan daha hayırlı olan gecedir.",
        "ikon": "star"
      },
      {
        "isim": "Ramazan Bayramı",
        "tarih": "20 Mart 2026",
        "hicriTarih": "1 Şevval 1447",
        "aciklama": "Oruç ibadetinin ardından Müslümanların sevincini paylaştığı günlerdir.",
        "ikon": "celebration"
      },
      {
        "isim": "Kurban Bayramı",
        "tarih": "27 Mayıs 2026",
        "hicriTarih": "10 Zilhicce 1447",
        "aciklama": "Yardımlaşma ve dayanışmanın zirveye çıktığı, kurban ibadetinin yerine getirildiği bayramdır.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "Hicri Yılbaşı",
        "tarih": "16 Haziran 2026",
        "hicriTarih": "1 Muharrem 1448",
        "aciklama": "Peygamber Efendimiz'in (s.a.v) Mekke'den Medine'ye hicretini esas alan Hicri takvimin ilk günüdür.",
        "ikon": "event"
      },
      {
        "isim": "Aşure Günü",
        "tarih": "25 Haziran 2026",
        "hicriTarih": "10 Muharrem 1448",
        "aciklama": "Peygamberlerin hayatında birçok önemli hadisenin gerçekleştiği, bereket ve paylaşma günüdür.",
        "ikon": "local_dining"
      },
      {
        "isim": "Mevlid Kandili",
        "tarih": "24 Ağustos 2026",
        "hicriTarih": "11 Rebiülevvel 1448",
        "aciklama": "Alemlere rahmet olarak gönderilen Peygamber Efendimiz'in (s.a.v) dünyaya teşrif ettiği gecedir.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- UKRAYNACA
    'uk': [
      {
        "isim": "Нічь Вознесення (Ісра і Мір'ядж)",
        "tarih": "15 січня 2026",
        "hicriTarih": "26 Раджаб 1447",
        "aciklama": "Чудотворна ніч, у якій наш Пророк (мир йому) вознісся від мечеті Аль-Харам до мечеті Аль-Акса, а потім на небеса.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "Ніч прощення (Лейлат аль-Бараа)",
        "tarih": "2 лютого 2026",
        "hicriTarih": "14 Шаабан 1447",
        "aciklama": "Ніч очищення від гріхів, прощення, заступництва та милості Аллаха.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "Початок Рамадану",
        "tarih": "19 лютого 2026",
        "hicriTarih": "1 Рамадан 1447",
        "aciklama": "Благословенний місяць, у якому дотримується піст, прозваний султаном одинадцяти місяців.",
        "ikon": "brightness_3"
      },
      {
        "isim": "Ніч передвизначення (Лейлятуль-Кадр)",
        "tarih": "16 березня 2026",
        "hicriTarih": "27 Рамадан 1447",
        "aciklama": "Ніч, у яку було нислано Святий Коран, краща за тисячу місяців.",
        "ikon": "star"
      },
      {
        "isim": "Ід аль-Фітр",
        "tarih": "20 березня 2026",
        "hicriTarih": "1 Шауваль 1447",
        "aciklama": "Дні, коли мусульмани діляться радістю після завершення посту Рамадану.",
        "ikon": "celebration"
      },
      {
        "isim": "Ід аль-Адха",
        "tarih": "27 травня 2026",
        "hicriTarih": "10 Зу аль-Хідджа 1447",
        "aciklama": "Свято, під час якого приносять жертвоприношення, а солідарність і милосердя досягають найвищої точки.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "Мусульманський Новий рік",
        "tarih": "16 червня 2026",
        "hicriTarih": "1 Мухаррам 1448",
        "aciklama": "Перший день мусульманського календаря, заснованого на переселенні нашого Пророка (мир йому) з Мекки до Медини.",
        "ikon": "event"
      },
      {
        "isim": "День Ашура",
        "tarih": "25 червня 2026",
        "hicriTarih": "10 Мухаррам 1448",
        "aciklama": "День благословення і щедрості, у житті пророків якого відбулося чимало важливих подій.",
        "ikon": "local_dining"
      },
      {
        "isim": "Ніч Мавліда (народження Пророка)",
        "tarih": "24 серпня 2026",
        "hicriTarih": "11 Рабі' аль-авваль 1448",
        "aciklama": "Ніч, у яку народився наш Пророк (мир йому), посланий милосердям для всіх світів.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- VİETNAMCA
    'vi': [
      {
        "isim": "Đêm Isra và Mi'raj",
        "tarih": "15 tháng 1 năm 2026",
        "hicriTarih": "26 Rajab 1447",
        "aciklama": "Đêm kỳ diệu mà vị Prophet của chúng ta (cầu xin bình an cho Ngài) đã thăng lên từ đền Al-Haram đến đền Al-Aqsa, rồi lên các tầng trời.",
        "ikon": "auto_awesome"
      },
      {
        "isim": "Đêm Đầu tháng Đại tha (Laylat al-Bara'a)",
        "tarih": "2 tháng 2 năm 2026",
        "hicriTarih": "14 Sha'ban 1447",
        "aciklama": "Đêm thanh tẩy tội lỗi, xin tha thứ, cầu giúp đỡ và lòng thương yêu của Đức Chúa.",
        "ikon": "nightlight_round"
      },
      {
        "isim": "Bắt đầu tháng Ramadan",
        "tarih": "19 tháng 2 năm 2026",
        "hicriTarih": "1 Ramadan 1447",
        "aciklama": "Tháng thánh để thực hành chay từ, được gọi là vua của mười một tháng.",
        "ikon": "brightness_3"
      },
      {
        "isim": "Đêm Định Mệnh (Laylat al-Qadr)",
        "tarih": "16 tháng 3 năm 2026",
        "hicriTarih": "27 Ramadan 1447",
        "aciklama": "Đêm Kinh Qur'an được ban xuống, tốt hơn cả nghìn tháng.",
        "ikon": "star"
      },
      {
        "isim": "Lễ Eid al-Fitr",
        "tarih": "20 tháng 3 năm 2026",
        "hicriTarih": "1 Shawwal 1447",
        "aciklama": "Những ngày người Hồi giáo cùng vui chung sau khi hoàn thành việc chay từ trong tháng Ramadan.",
        "ikon": "celebration"
      },
      {
        "isim": "Lễ Eid al-Adha",
        "tarih": "27 tháng 5 năm 2026",
        "hicriTarih": "10 Dhu al-Hijjah 1447",
        "aciklama": "Ngày lễ trong đó có sự hiến tế, và tinh thần đoàn kết, bác ác đạt đến đỉnh điểm.",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "Năm Mới Hồi giáo",
        "tarih": "16 tháng 6 năm 2026",
        "hicriTarih": "1 Muharram 1448",
        "aciklama": "Ngày đầu tiên của lịch Hồi giáo, dựa trên cuộc sưu di của vị Prophet (cầu xin bình an cho Ngài) từ Mecca đến Medina.",
        "ikon": "event"
      },
      {
        "isim": "Ngày Ashura",
        "tarih": "25 tháng 6 năm 2026",
        "hicriTarih": "10 Muharram 1448",
        "aciklama": "Ngày của phúc lành và sẻ chia, khi nhiều sự kiện quan trọng đã xảy ra trong cuộc đời của các vị Prophet.",
        "ikon": "local_dining"
      },
      {
        "isim": "Đêm Mawlid",
        "tarih": "24 tháng 8 năm 2026",
        "hicriTarih": "11 Rabi' al-Awwal 1448",
        "aciklama": "Đêm vị Prophet (cầu xin bình an cho Ngài), được phái đi như lòng thương yêu cho toàn vũ trụ, ra đời.",
        "ikon": "menu_book"
      }
    ],
    // ---------------------------------------------------------------- ÇİNCE
    'zh': [
      {
        "isim": "登霄夜 (Al-Isra wal-Mi'raj)",
        "tarih": "2026年1月15日",
        "hicriTarih": "1447年 7月26日",
        "aciklama": "这是先知穆罕默德（愿主福安之）从禁寺夜行至远寺，并由此升天的神奇之夜。",
        "ikon": "auto_awesome"
      },
      {
        "isim": "赦罪夜 (Laylat al-Bara'ah)",
        "tarih": "2026年2月2日",
        "hicriTarih": "1447年 8月14日",
        "aciklama": "这是悔罪、宽恕、代求与蒙受赦宥的夜晚。",
        "ikon": "nightlight_round"
      },
      {
        "isim": "斋月开始 (Ramadan)",
        "tarih": "2026年2月19日",
        "hicriTarih": "1447年 9月1日",
        "aciklama": "被称为“十一月之王”的尊贵月份，穆斯林在此履行封斋的功修。",
        "ikon": "brightness_3"
      },
      {
        "isim": "高贵之夜 (Laylat al-Qadr)",
        "tarih": "2026年3月16日",
        "hicriTarih": "1447年 9月27日",
        "aciklama": "这是《古兰经》降示之夜，比一千个月更为尊贵。",
        "ikon": "star"
      },
      {
        "isim": "开斋节 (Eid al-Fitr)",
        "tarih": "2026年3月20日",
        "hicriTarih": "1447年 10月1日",
        "aciklama": "封斋结束后，穆斯林彼此分享喜悦与祝福的节日。",
        "ikon": "celebration"
      },
      {
        "isim": "古尔邦节 (Eid al-Adha)",
        "tarih": "2026年5月27日",
        "hicriTarih": "1447年 12月10日",
        "aciklama": "这是互助与团结达到高峰，并履行献牲功修的盛大节日。",
        "ikon": "volunteer_activism"
      },
      {
        "isim": "伊斯兰新年 (Hijri New Year)",
        "tarih": "2026年6月16日",
        "hicriTarih": "1448年 1月1日",
        "aciklama": "以先知穆罕默德（愿主福安之）从麦加迁徙至麦地那为起点的伊斯兰历新年第一天。",
        "ikon": "event"
      },
      {
        "isim": "阿舒拉日 (Ashura)",
        "tarih": "2026年6月25日",
        "hicriTarih": "1448年 1月10日",
        "aciklama": "这是在众先知生平中发生诸多重要事件的日子，也是充满祝福与分享的一天。",
        "ikon": "local_dining"
      },
      {
        "isim": "圣纪夜 (Mawlid an-Nabi)",
        "tarih": "2026年8月24日",
        "hicriTarih": "1448年 3月11日",
        "aciklama": "这是作为慈悯被派遣给全世界的先知穆罕默德（愿主福安之）诞生的夜晚。",
        "ikon": "menu_book"
      }
    ]
  };

  /// [dilKodu] için özel günleri döner.
  ///
  /// Gelen kod 3 harfliyse (uygulama locale'i: `tur`, `eng`, `zho`) önce
  /// ISO 639-1'e çevrilir; ardından 2 harfli içerik anahtarıyla eşlenir
  /// (`tur` → `tr`). Ayrıntı: `lib/utils/icerik_dili.dart`.
  ///
  /// Uygulamanın desteklediği 25 dilin tamamı [ozelGunler] içinde
  /// tanımlıdır, yani normal akışta [ozelGunler]['en'] yedeğine düşülmez.
  /// Yedek, ileride yeni bir çeviri dosyası eklenip buraya karşılığı
  /// unutulduğunda içeriğin boş kalmaması için tutulur.
  static List<Map<String, String>> ozelGunleriGetir(String dilKodu) {
    return ozelGunler[icerikDilKodu(dilKodu)] ?? ozelGunler['en']!;
  }
}
