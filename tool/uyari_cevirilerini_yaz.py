# tool/bildirim_uyari_cevirileri.py
# tool/uyari_cevirilerini_yaz.py
#
# Bildirim sonucu uyarilarinin 25 dil metnini yazar.
#
# NEDEN SCRIPT? Anahtar kumesi 25 dosyada BIREBIR ayni olmak zorundadir
# (`ceviriler_test.dart`). Elle 25 dosyaya eklemek anahtar tutarsizligi
# riski tasir. Bu script metni JSON yapısına dokunmadan, ilgili anahtar
# satirinin YANINA yeni satirlar ekleyerek yazar; dosya siralamasi ve
# girinti korunur.
#
# KURALLAR (testler bunlari olcer):
#   * Uc durum AYRI anahtar: kurulum hatasi, iptal hatasi, yaklasik mod.
#   * Metinler TESLIM GARANTISI VERMEZ: "gelir/gelecek/garanti" gibi
#     vaat ifadeleri kullanilmaz. Cihaz kisitlari (Doze, pil optimizasyonu)
#     bildirimi geciktirebilir, kurulamadiginda hic gelmez.
import json
import io
import os

CEVIRI = os.path.join(os.path.dirname(__file__), '..', 'assets', 'i18n',
                      'ceviri')

# Anahtar -> 25 dil metni.
# exact_alarm_yok once 18 dilde ham anahtar olarak duruyordu; hepsi yazildi.
METINLER = {
    'exact_alarm_yok': {
        'tur': 'Tam zamanlı alarm izni yok — bildirimler yaklaşık zamanlı '
               'gösterilebilir',
        'tuk': 'Takyk alarm rugsat berilmedik — habarlar takmynan wagtlarda '
               'görkezilip bilner',
        'eng': 'No exact alarm permission — notifications may be shown at '
               'approximate times',
        'deu': 'Keine Berechtigung für exakte Alarme — Benachrichtigungen '
               'können zu ungefähren Zeiten angezeigt werden',
        'fra': 'Pas d’autorisation d’alarme exacte — les notifications '
               'peuvent être affichées à des heures approximatives',
        'spa': 'Sin permiso para alarmas exactas — las notificaciones '
               'pueden mostrarse a horas aproximadas',
        'ita': 'Nessun permesso per allarmi esatti — le notifiche possono '
               'essere mostrate a orari approssimativi',
        'por': 'Sem permissão para alarmes exatos — as notificações podem '
               'ser exibidas em horários aproximados',
        'ron': 'Fără permisiune pentru alarme exacte — notificările pot '
               'fi afișate la ore aproximative',
        'pol': 'Brak uprawnień do dokładnych alarmów — powiadomienia mogą '
               'być wyświetlane w przybliżonym czasie',
        'rus': 'Нет разрешения на точные будильники — уведомления могут '
               'показываться примерно в нужное время',
        'ukr': 'Немає дозволу на точні будильники — сповіщення можуть '
               'показуватися приблизно',
        'ara': 'لا يوجد إذن منبه دقيق — قد تظهر الإشعارات في وقت تقريبي',
        'fas': 'اجازه هشدار دقیق وجود ندارد — هشدارها ممکن است در زمان '
               'تقریبی نمایش داده شوند',
        'ind': 'Tidak ada izin alarm tepat — notifikasi dapat ditampilkan '
               'pada waktu yang kurang tepat',
        'ben': 'সুনির্দিষ্ট অ্যালার্মের অনুমতি নেই — বিজ্ঞপ্তি আনুমানিক '
               'সময়ে দেখানো যেতে পারে',
        'tam': 'சரியான அலாரம் அனுமதி இல்லை — அறிவிப்புகள் தோராயமான '
               'நேரத்தில் காட்டப்படலாம்',
        'tha': 'ไม่มีสิทธิ์ตั้งเตือนแบบเวลาแน่นอน — การแจ้งเตือนอาจแสดงตาม'
               'เวลาโดยประมาณ',
        'vie': 'Không có quyền báo thức chính xác — thông báo có thể '
               'hiển thị vào thời điểm xấp xỉ',
        'zho': '没有精确闹钟权限 — 通知可能在接近的时间显示',
        'jpn': '正確なアラームの権限がありません — 通知はおおよその時刻に表示'
               'される場合があります',
        'kor': '정확한 알람 권한이 없습니다 — 알림은 대략적인 시간에 표시'
               '될 수 있습니다',
        'mya': 'အတိအကျ နှုန်းချင်း ခွင့်ပြုချက် မရှိပါ — အကြောင်းကြားချက်များကို '
               'ခန့်မှန်းချိန်တွင် ပြသနိုင်ပါမည်',
        'nep': 'सटीक अलारमको अनुमति छैन — सूचनाहरू अनुमानित समयमा देखिन '
               'सक्छन्',
        'amh': 'የትክክል ሰዓት ፍቃድ የለም — ማሳወቂያዎች በተጠበቀ ጊዜ ማሳያ ሊሆኑ ይችላሉ',
    },
    'bildirim_kurulamadi': {
        'tur': 'Bazı vakit bildirimleri kurulamadı',
        'tuk': 'Käbir namaz wagt habarlary döredilmedi',
        'eng': 'Some prayer time notifications could not be set up',
        'deu': 'Einige Benachrichtigungen für Gebetszeiten konnten nicht '
               'eingerichtet werden',
        'fra': 'Certaines notifications d’heures de prière n’ont pas pu être '
               'configurées',
        'spa': 'No se pudieron configurar algunas notificaciones de horarios '
               'de oración',
        'ita': 'Non è stato possibile configurare alcune notifiche degli '
               'orari di preghiera',
        'por': 'Não foi possível configurar algumas notificações dos '
               'horários de oração',
        'ron': 'Unele notificări pentru orele rugăciunii nu au putut fi '
               'configurate',
        'pol': 'Nie udało się skonfigurować niektórych powiadomień o porach '
               'modlitwy',
        'rus': 'Не удалось настроить некоторые уведомления о времени намаза',
        'ukr': 'Не вдалося налаштувати деякі сповіщення про час молитви',
        'ara': 'تعذّر إعداد بعض إشعارات مواقيت الصلاة',
        'fas': 'برخی اعلان‌های اوقات نماز تنظیم نشدند',
        'ind': 'Beberapa notifikasi waktu salat tidak dapat disiapkan',
        'ben': 'কিছু নামাজের সময়ের বিজ্ঞপ্তি তৈরি করা যায়নি',
        'tam': 'சில தொழுகை நேர அறிவிப்புகளை அமைக்க முடியவில்லை',
        'tha': 'ไม่สามารถตั้งค่าการแจ้งเตือนเวลาสลัตบางรายการได้',
        'vie': 'Không thể thiết lập một số thông báo giờ cầu đạo',
        'zho': '无法设置部分礼拜时间通知',
        'jpn': '一部の礼拝時刻の通知を設定できませんでした',
        'kor': '일부 기도 시간 알림을 설정하지 못했습니다',
        'mya': 'အချိန်ဝတ်ပြောင်း အကြောင်းကြားချက်အချို့ကို မသတ်မှတ်နိုင်ခဲ့ပါ',
        'nep': 'केही नमाज समय सूचनाहरू सेट गर्न सकिएन',
        'amh': 'የተመረጡ የሰዓት ሰሪያዎች ማዋቀር አልተቻለም',
    },
    'bildirim_iptal_edilemedi': {
        'tur': 'Eski bir vakit bildirimi silinemedi',
        'tuk': 'Köne namaz wagt habary aýrylmaýar',
        'eng': 'An old prayer time notification could not be removed',
        'deu': 'Eine alte Benachrichtigung für Gebetszeiten konnte nicht '
               'entfernt werden',
        'fra': 'Une ancienne notification d’heures de prière n’a pas pu être '
               'supprimée',
        'spa': 'No se pudo eliminar una notificación antigua de horarios de '
               'oración',
        'ita': 'Non è stato possibile rimuovere una vecchia notifica degli '
               'orari di preghiera',
        'por': 'Não foi possível remover uma notificação antiga dos horários '
               'de oração',
        'ron': 'O notificare veche pentru orele rugăciunii nu a putut fi '
               'eliminată',
        'pol': 'Nie udało się usunąć starego powiadomienia o porze modlitwy',
        'rus': 'Не удалось удалить старое уведомление о времени намаза',
        'ukr': 'Не вдалося видалити старе сповіщення про час молитви',
        'ara': 'تعذّرت إزالة إشعار قديم لمواقيت الصلاة',
        'fas': 'یک اعلان قدیمی اوقات نماز حذف نشد',
        'ind': 'Notifikasi waktu salat lama tidak dapat dihapus',
        'ben': 'পুরোনো একটি নামাজের সময়ের বিজ্ঞপ্তি মুছা যায়নি',
        'tam': 'பழைய தொழுகை நேர அறிவிப்பை நீக்க முடியவில்லை',
        'tha': 'ไม่สามารถลบการแจ้งเตือนเวลาสลัตเก่าได้',
        'vie': 'Không thể xóa một thông báo giờ cầu đạo cũ',
        'zho': '无法删除旧的礼拜时间通知',
        'jpn': '古い礼拝時刻の通知を削除できませんでした',
        'kor': '이전 기도 시간 알림을 삭제하지 못했습니다',
        'mya': 'အချိန်ဝတ်ပြောင်းအချိန်ဟောင်း အကြောင်းကြားချက်ကို မဖျက်နိုင်ခဲ့ပါ',
        'nep': 'पुरानो नमाज समय सूचना हटाउन सकिएन',
        'amh': 'የቀድሞ የሰዓት ሰሪያ ማስወገድ አልተቻለም',
    },
}


def yaz(dil, anahtar, metin, dosya_yolu):
    """`anahtar` satırının yanına `metin` satırını ekler (yoksa ekler)."""
    with io.open(dosya_yolu, 'r', encoding='utf-8') as f:
        satirlar = f.read().split('\n')

    yeni_satir = '  "%s": %s,' % (anahtar, json.dumps(metin, ensure_ascii=False))
    # Anahtar zaten varsa degerini guncelle.
    for i, s in enumerate(satirlar):
        if '"%s":' % anahtar in s:
            # satir sonundaki virgulu koru
            satir = '  "%s": %s,' % (anahtar, json.dumps(metin,
                                                        ensure_ascii=False))
            # Kapanis satirinda degilse virgul zaten var; yine de biz yaziyoruz.
            satirlar[i] = satir
            return satirlar, False

    # Yok: `exact_alarm_yok` satirinin hemen ardina ekle (yoksa en sona).
    for i, s in enumerate(satirlar):
        if '"exact_alarm_yok":' in s:
            satirlar.insert(i + 1, yeni_satir)
            return satirlar, True

    return None, False


def main():
    for dil, metinler in METINLER['exact_alarm_yok'].items():
        yol = os.path.normpath(os.path.join(CEVIRI, '%s.json' % dil))
        if not os.path.exists(yol):
            print('ATLANDI (dosya yok): %s' % dil)
            continue
        for anahtar in ('exact_alarm_yok', 'bildirim_kurulamadi',
                        'bildirim_iptal_edilemedi'):
            metin = METINLER[anahtar][dil]
            satirlar, eklendi = yaz(dil, anahtar, metin, yol)
            if satirlar is None:
                print('HATA: %s icin yer bulunamadi' % dil)
                continue
            with io.open(yol, 'w', encoding='utf-8', newline='\n') as f:
                f.write('\n'.join(satirlar))
            print('%-4s %-28s %s' % (dil, anahtar,
                                     'eklendi' if eklendi else 'guncellendi'))


if __name__ == '__main__':
    main()