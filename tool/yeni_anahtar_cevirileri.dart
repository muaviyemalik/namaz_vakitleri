// tool/yeni_anahtar_cevirileri.dart
//
// Yeni anahtarların Arapça / Farsça / Almanca / Endonezce çevirileri.
//
// NEDEN AYRI DOSYA?
//
// `tool/yeni_anahtarlari_ekle.dart` anahtar kümesini tanımlar ve 25 dile
// yazar. Bu dosya o anahtarların insan tarafından gözden geçirilmiş
// çevirilerini tutar.
//
// DÜRÜSTLÜK NOTU — LÜTFEN OKU
//
// Bu çeviriler AI ÜRETİMİDİR ve YEREL DİL GÖZÜYLE DENETLENMEMİŞTİR.
// Malik'in kararı gereği özellikle bu diller insan kontrolünden geçmelidir:
//
//   • Arapça  (ara)  — RTL, dini terimler (imsak, asr, kıble)
//   • Farsça  (fas)  — RTL, Arapça ile paylaşılan terimler
//   • Almanca (deu)  — uzun kelimeler, dar ekran taşması
//   • Endonezce (ind) — «salat» = namaz, «imsak» = fajr
//
// `test/ceviriler_test.dart` yalnız anahtar VARLIĞINI ve boş metin
// olmadığını doğrular; çevirinin DOĞRU olduğunu doğrulayamaz. Bu dosya
// yayın öncesi yerel dil kontrolünden geçene kadar "AI tarafından
// üretilmiş, doğrulanmamış" olarak işaretlidir.
library;

/// Dil kodu -> (anahtar -> çeviri).
const Map<String, Map<String, String>> dilCevirileri = <String, Map<String, String>>{
  // ---------------------------------------------------------------------
  // ARAPÇA (RTL)
  // ---------------------------------------------------------------------
  'ara': <String, String>{
    'asr_method': 'طريقة حساب العصر',
    'high_latency': 'إعداد خطوط العرض العالية',
    'sunrise_notification': 'إشعار شروق الشمس',
    'sunrise_notification_desc': 'إشعار معلومات شروق الشمس (ليس وقت صلاة)',
    'data_source_live': 'بيانات مباشرة',
    'data_source_cache': 'من الذاكرة المؤقتة',
    'data_source_unknown': 'لا توجد معلومات تحديث',
    'data_updated_now': 'تم التحديث منذ لحظات',
    'data_updated_minutes': 'تم التحديث قبل {} دقيقة',
    'data_updated_hours': 'تم التحديث قبل {} ساعة',
    'data_updated_days': 'تم التحديث قبل {} يوم',
    'method_auto_with_result': 'طريقة Aladhan التلقائية: {}',
    'high_latency_setting': 'إعداد خطوط العرض العالية: {}',
    'exact_alarm_yok': 'لا يوجد إذن منبه دقيق — تصلك الإشعارات تقريبًا',
    'notif_sunrise_title': 'شروق الشمس',
    'notif_sunrise_body': 'شروق الشمس (ليس وقت صلاة)',
    'notif_channel_sunrise_name': 'معلومات شروق الشمس',
    'no_city_data_action':
        'لا توجد قائمة مدن لـ {}. حدّد موقعك عبر GPS أو اختر مدينة.',
    'reject_http': 'خطأ في الخادم (مشكلة في الشبكة أو واجهة API)',
    'reject_logic': 'أعاد الخادم استجابة غير صالحة',
    'reject_empty': 'لم تصل بيانات من الخادم',
    'reject_date_broken': 'التاريخ في الاستجابة غير صالح',
    'reject_month_mismatch': 'الاستجابة ليست للشهر المطلوب',
    'reject_coords_mismatch': 'الاستجابة تخص موقعًا مختلفًا',
    'reject_tz_missing': 'لا توجد منطقة زمنية في الاستجابة',
    'reject_tz_unknown': 'المنطقة الزمنية في الاستجابة غير معروفة',
    'reject_method_mismatch': 'طريقة الاستجابة لا تطابق الطريقة المختارة',
    'reject_field_missing': 'تنقص الاستجابة بعض أوقات الصلاة',
    'reject_time_format': 'صيغة الوقت في الاستجابة غير صالحة',
    'reject_time_range': 'تحتوي الاستجابة على قيمة وقت غير صالحة',
    'reject_zero_time': 'تحتوي الاستجابة على منتصف الليل (00:00)',
    'reject_day_missing': 'اليوم المطلوب غير موجود في الاستجابة',
  },

  // ---------------------------------------------------------------------
  // FARSÇA (RTL)
  // ---------------------------------------------------------------------
  'fas': <String, String>{
    'asr_method': 'روش محاسبه عصر',
    'high_latency': 'تنظیم عرض جغرافیایی بالا',
    'sunrise_notification': 'اعلان طلوع خورشید',
    'sunrise_notification_desc': 'اعلان اطلاعات طلوع خورشید (وقت نماز نیست)',
    'data_source_live': 'داده زنده',
    'data_source_cache': 'از حافظه موقت',
    'data_source_unknown': 'اطلاعات به‌روزرسانی موجود نیست',
    'data_updated_now': 'همین الان به‌روزرسانی شد',
    'data_updated_minutes': '{} دقیقه پیش به‌روزرسانی شد',
    'data_updated_hours': '{} ساعت پیش به‌روزرسانی شد',
    'data_updated_days': '{} روز پیش به‌روزرسانی شد',
    'method_auto_with_result': 'روش خودکار Aladhan: {}',
    'high_latency_setting': 'تنظیم عرض جغرافیایی بالا: {}',
    'exact_alarm_yok':
        'اجازه هشدار دقیق وجود ندارد — هشدارها تقریبی ارسال می‌شوند',
    'notif_sunrise_title': 'طلوع خورشید',
    'notif_sunrise_body': 'طلوع خورشید (وقت نماز نیست)',
    'notif_channel_sunrise_name': 'اطلاعات طلوع خورشید',
    'no_city_data_action':
        'برای {} فهرست شهری وجود ندارد. موقعیت خود را با GPS پیدا کنید یا شهری انتخاب کنید.',
    'reject_http': 'خطای سرور (مشکل شبکه یا API)',
    'reject_logic': 'سرور پاسخ نامعتبر برگرداند',
    'reject_empty': 'داده‌ای از سرور دریافت نشد',
    'reject_date_broken': 'تاریخ پاسخ نامعتبر است',
    'reject_month_mismatch': 'پاسخ مربوط به ماه درخواستی نیست',
    'reject_coords_mismatch': 'پاسخ متعلق به مکان دیگری است',
    'reject_tz_missing': 'پاسخ منطقه زمانی ندارد',
    'reject_tz_unknown': 'منطقه زمانی پاسخ شناخته نمی‌شود',
    'reject_method_mismatch': 'روش پاسخ با روش انتخاب‌شده مطابقت ندارد',
    'reject_field_missing': 'پاسخ برخی اوقات نماز را ندارد',
    'reject_time_format': 'قالب زمان در پاسخ نامعتبر است',
    'reject_time_range': 'پاسخ شامل مقدار زمان نامعتبر است',
    'reject_zero_time': 'پاسخ شامل نیمه‌شب (00:00) است',
    'reject_day_missing': 'روز درخواستی در پاسخ یافت نشد',
  },

  // ---------------------------------------------------------------------
  // ALMANCA
  // ---------------------------------------------------------------------
  'deu': <String, String>{
    'asr_method': 'Berechnungsmethode für Asr',
    'high_latency': 'Einstellung für hohe Breitengrade',
    'sunrise_notification': 'Sonnenaufgang-Benachrichtigung',
    'sunrise_notification_desc': 'Sonnenaufgang-Info (keine Gebetszeit)',
    'data_source_live': 'Live-Daten',
    'data_source_cache': 'Aus dem Cache',
    'data_source_unknown': 'Keine Aktualisierungsinfo',
    'data_updated_now': 'gerade eben aktualisiert',
    'data_updated_minutes': 'vor {} Min. aktualisiert',
    'data_updated_hours': 'vor {} Std. aktualisiert',
    'data_updated_days': 'vor {} Tagen aktualisiert',
    'method_auto_with_result': 'Automatische Aladhan-Methode: {}',
    'high_latency_setting': 'Einstellung für hohe Breitengrade: {}',
    'exact_alarm_yok':
        'Keine Berechtigung für exakte Alarme — Benachrichtigungen kommen ungefähr',
    'notif_sunrise_title': 'Sonnenaufgang',
    'notif_sunrise_body': 'Sonnenaufgang (keine Gebetszeit)',
    'notif_channel_sunrise_name': 'Sonnenaufgang-Info',
    'no_city_data_action':
        'Keine Städteliste für {}. Standort per GPS ermitteln oder Stadt wählen.',
    'reject_http': 'Serverfehler (Netzwerk- oder API-Problem)',
    'reject_logic': 'Server hat eine ungültige Antwort geliefert',
    'reject_empty': 'Keine Daten vom Server erhalten',
    'reject_date_broken': 'Datum in der Antwort ist ungültig',
    'reject_month_mismatch': 'Antwort gehört nicht zum angeforderten Monat',
    'reject_coords_mismatch': 'Antwort gehört zu einem anderen Ort',
    'reject_tz_missing': 'Antwort enthält keine Zeitzone',
    'reject_tz_unknown': 'Zeitzone in der Antwort ist unbekannt',
    'reject_method_mismatch':
        'Methode der Antwort passt nicht zur gewählten Methode',
    'reject_field_missing': 'Antwort enthält nicht alle Gebetszeiten',
    'reject_time_format': 'Zeitformat in der Antwort ist ungültig',
    'reject_time_range': 'Antwort enthält einen ungültigen Zeitwert',
    'reject_zero_time': 'Antwort enthält Mitternacht (00:00)',
    'reject_day_missing': 'Angefragter Tag in der Antwort nicht gefunden',
  },

  // ---------------------------------------------------------------------
  // ENDONEZCE
  //
  // Not: Endonezcede «salat» namaz, «imsak» imsak/fajr saatidir.
  // ---------------------------------------------------------------------
  'ind': <String, String>{
    'asr_method': 'Metode perhitungan Asr',
    'high_latency': 'Pengaturan lintang tinggi',
    'sunrise_notification': 'Notifikasi matahari terbit',
    'sunrise_notification_desc':
        'Notifikasi informasi matahari terbit (bukan waktu salat)',
    'data_source_live': 'Data langsung',
    'data_source_cache': 'Dari cache',
    'data_source_unknown': 'Tidak ada info pembaruan',
    'data_updated_now': 'baru saja diperbarui',
    'data_updated_minutes': 'diperbarui {} menit lalu',
    'data_updated_hours': 'diperbarui {} jam lalu',
    'data_updated_days': 'diperbarui {} hari lalu',
    'method_auto_with_result': 'Metode otomatis Aladhan: {}',
    'high_latency_setting': 'Pengaturan lintang tinggi: {}',
    'exact_alarm_yok':
        'Tidak ada izin alarm tepat — notifikasi datang kurang tepat',
    'notif_sunrise_title': 'Matahari terbit',
    'notif_sunrise_body': 'Matahari terbit (bukan waktu salat)',
    'notif_channel_sunrise_name': 'Info matahari terbit',
    'no_city_data_action':
        'Tidak ada daftar kota untuk {}. Temukan lokasi via GPS atau pilih kota.',
    'reject_http': 'Kesalahan server (masalah jaringan atau API)',
    'reject_logic': 'Server mengembalikan respons tidak valid',
    'reject_empty': 'Tidak ada data dari server',
    'reject_date_broken': 'Tanggal dalam respons tidak valid',
    'reject_month_mismatch': 'Respons bukan untuk bulan yang diminta',
    'reject_coords_mismatch': 'Respons milik lokasi lain',
    'reject_tz_missing': 'Respons tidak memiliki zona waktu',
    'reject_tz_unknown': 'Zona waktu dalam respons tidak dikenali',
    'reject_method_mismatch':
        'Metode respons tidak cocok dengan metode yang dipilih',
    'reject_field_missing': 'Respons tidak memuat beberapa waktu salat',
    'reject_time_format': 'Format waktu dalam respons tidak valid',
    'reject_time_range': 'Respons memuat nilai waktu tidak valid',
    'reject_zero_time': 'Respons memuat tengah malam (00:00)',
    'reject_day_missing': 'Hari yang diminta tidak ditemukan dalam respons',
  },
};
