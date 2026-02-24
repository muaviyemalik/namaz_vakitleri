class OzelGunler {
  static final Map<String, List<Map<String, String>>> ozelGunler = {
    'tr':[
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
    'en' : [
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
]
  };
    static List<Map<String, String>> ozelGunleriGetir(String dilKodu) {
    return ozelGunler[dilKodu] ?? ozelGunler['en']!; 
    }
  }