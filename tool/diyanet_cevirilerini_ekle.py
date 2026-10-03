# -*- coding: utf-8 -*-
"""Yeni Diyanet ceviri anahtarlarini 25 ceviri dosyasina ekler.

NEDEN AYRI DOSYA?
`test/ceviriler_test.dart` her dosyanin anahtar kumesinin `tur.json` ile
BIREBIR ayni olmasini zorunlu kiliyor. Yeni anahtarlar once `tur.json`'a,
sonra diger 24 dile yazilir. Mevcut `tool/yeni_anahtarlari_ekle.dart`
dosyasina dokunulmaz; bu is yalniz Diyanet ozelligine aittir.

CALISTIRMA:
    python tool/diyanet_cevirilerini_ekle.py

UYARI: Bu dosya Turkce metinleri Turkce disi 23 dile de yazar. Ceviriler
INSAN GOZUYLE denetlenmelidir; ozellikle Arapca/Farsca (RTL) ve CJK
dilleri icin bu denetim yapilmadan yayina gidilmemelidir.
"""
import collections
import io
import json
import os

CEVIRI = os.path.join('assets', 'i18n', 'ceviri')
DOSYALAR = [
    'amh', 'ara', 'ben', 'deu', 'eng', 'fas', 'fra', 'ind', 'ita', 'jpn',
    'kor', 'mya', 'nep', 'pol', 'por', 'ron', 'rus', 'spa', 'tam', 'tha',
    'tuk', 'tur', 'ukr', 'vie', 'zho',
]

# Anahtar -> {dil: metin}
YENI = {
    'license_diyanet': {
        'tur': 'Resmî Diyanet Vakit Verisi (Türkiye)',
        'eng': 'Official Diyanet Prayer Times (Turkey)',
        'deu': 'Amtliche Diyanet-Gebetszeiten (Türkei)',
        'fra': 'Horaires officiels Diyanet (Turquie)',
        'spa': 'Horarios oficiales de Diyanet (Turquía)',
        'ita': 'Orari ufficiali Diyanet (Turchia)',
        'por': 'Horários oficiais Diyanet (Turquia)',
        'ron': 'Programele oficiale Diyanet (Turcia)',
        'pol': 'Oficjalne godziny Diyanet (Turcja)',
        'rus': 'Официальное расписание Дийанет (Турция)',
        'ukr': 'Офіційний розклад Діанет (Туреччина)',
        'ara': 'مواقيت الصلاة الرسمية لديانة (تركيا)',
        'fas': 'اوقات نماز رسمی دیانت (ترکیه)',
        'ind': 'Jadwal resmi Diyanet (Turki)',
        'zho': '迪亚奈特官方礼拜时间（土耳其）',
        'jpn': 'ディアネット公式礼拝時間（トルコ）',
        'kor': '디야넷 공식 예배 시간 (터키)',
        'mya': 'ဒီယန့် အမှန်တကယ် ဝတ်ဆင်းအချိန် (တူရကီး)',
        'nep': 'आधिकारिक डायनेट नमाजको समय (टर्की)',
        'tha': 'เวลาละหมายอย่างเป็นทางการของดียาเนต (ตุรกี)',
        'amh': 'የዲያኔት ኦፊሴላዊ የሰላም ሰዓት (ቱርክያ)',
        'ben': 'দায়ানেটের সরকারি নামাজের সময়সূচি (তুরস্ক)',
        'tam': 'டயனெட் அரசு நமசா நேரம் (துருக்கி)',
        'vie': 'Lịch nam chính thức của Diyanet (Thổ Nhĩ Kỳ)',
    },
    'license_diyanet_terms': {
        'tur': 'Diyanet İşleri Başkanlığı\'nın resmî sitesinden alınmıştır. '
               'Bu veri kamuya açıktır. Yeniden dağıtım koşulları için '
               'Diyanet ile iletişime geçilmelidir.',
        'eng': 'Taken from the official website of the Presidency of '
               'Religious Affairs (Diyanet). This data is publicly '
               'accessible. Please contact Diyanet regarding redistribution '
               'terms.',
        'deu': 'Aus der offiziellen Website der Diyanet entnommen. Diese '
               'Daten sind öffentlich zugänglich. Für Weiterverteilungsbedingungen '
               'wenden Sie sich bitte an Diyanet.',
        'fra': 'Issu du site officiel de la Présidence des Affaires '
               'Religieuses (Diyanet). Ces données sont publiques. Veuillez '
               'contacter Diyanet pour les conditions de redistribution.',
        'spa': 'Obtenido del sitio oficial de la Presidencia de Asuntos '
               'Religiosos (Diyanet). Estos datos son de acceso público. '
               'Contacte con Diyanet para las condiciones de redistribución.',
        'ita': 'Tratto dal sito ufficiale della Presidenza per gli Affari '
               'Religiosi (Diyanet). I dati sono pubblicamente accessibili. '
               'Contattare Diyanet per le condizioni di ridistribuzione.',
        'por': 'Obtido do site oficial da Presidência dos Assuntos Religiosos '
               '(Diyanet). Estes dados são de acesso público. Contacte o '
               'Diyanet sobre condições de redistribuição.',
        'ron': 'Obținut de pe site-ul oficial al Președinției pentru Afaceri '
               'Religioase (Diyanet). Datele sunt publice. Contactați Diyanet '
               'pentru condițiile de redistribuire.',
        'pol': 'Pobrane z oficjalnej strony Diyanet (Prezydium Spraw '
               'Religijnych). Dane są publiczne. W sprawie warunków '
               'redystrybucji skontaktuj się z Diyanet.',
        'rus': 'Получено с официального сайта Управления по делам религий '
               '(Дийанет). Данные находятся в свободном доступе. По условиям '
               'распространения обращайтесь в Дийанет.',
        'ukr': 'Отримано з офіційного сайту Управління справами релігій '
               '(Діанет). Дані у вільному доступі. Щодо умов поширення '
               'звертайтеся до Діанет.',
        'ara': 'مأخوذ من الموقع الرسمي لرأس Matters الدين (ديانت). هذه البيانات '
               'متاحة للعامة. يرجى الاتصال بديانة بشأن شروط إعادة النشر.',
        'fas': 'از وب‌سایت رسمی اداره امور دیانی (دیانت) دریافت شده است. این '
               'داده‌ها عمومی است. برای شرایط بازتوزیع با دیانت تماس بگیرید.',
        'ind': 'Diambil dari situs resmi Kantor Urusan Agama (Diyanet). Data '
               'ini dapat diakses publik. Hubungi Diyanet untuk ketentuan '
               'distribusi ulang.',
        'zho': '取自宗教事务局（Diyanet）官方网站。此数据为公开数据。关于再分发条款，'
               '请联系 Diyanet。',
        'jpn': 'ディアネット（宗教事务厅）公式サイトから取得。このデータは公开データです。'
               '再配布の条件についてはディアネットへお問い合わせください。',
        'kor': '디아네트(종교 refreshed affairs) 공식 사이트에서 가져왔습니다. 이 데이터는 '
               '공개 데이터입니다. 재배포 조건은 디아네트에 문의하십시오.',
        'mya': 'ဒီယန့် (ဘာရထာဝန်ကိုင်မှုဝန်ကြီး) နှင့် တရားဝင်ကိုယ်စာမျက်နှာမှ ရယူထားသည်။ ဤအချက်အလက်များကို ပြင်းထန်စွာ ဖတ်နိုင်သည်။ '
               'ထပ်ဖြန့်ခြင့်စည်းမျဉ်း အတွက် ဒီယန့်ကို ဆက်သွယ်ပါ။',
        'nep': 'धार्मिक कार्य विभाग (डायानेट) को आधिकारिक वेबसाइटबाट लिइएको हो। '
               'यो डाटा सार्वजनिक छ। पुनर्वितरणका सर्तहरूका लागि डायानेटलाई सम्पर्क गर्नुहोस्।',
        'tha': 'ได้จากเว็บไซต์ทางการของสำนักงานกิจการศาสนา (ดียาเนต) ข้อมูลนี้เป็นข้อมูลสาธารณะ '
               'กรุณาติดต่อดียาเนตเกี่ยวกับเงื่อนไขการเผยแพร่ต่อ',
        'amh': 'ከዲያኔት የመንግሥት ድረ-ገብ ተወስዷል። ይህ መረጃ ለሁሉ ክፍት ነው። እንደላስተዋቀር የማስተላለፍ ድንጋጌ ለመረጃ እባክዎ ዲያኔትን ያግኙ።',
        'ben': 'ধর্মীয় বিষয়ক দপ্তর (ডায়ানেট)-এর অফিসিয়াল ওয়েবসাইট থেকে নেওয়া। '
               'এই তথ্য সর্বজনীন। পুনঃবিতরণের শর্ত জানতে ডায়ানেটের সঙ্গে যোগাযোগ করুন।',
        'tam': 'இராச்சல் விசேகங்கள் திணைக்கறிசு (டயனெட்) அரசு இணையதளத்திலிருந்து '
               'பெறப்பட்டது. இந்தத் தரவு பொதுவானது. மீள் விநியோக விதிகளுக்கு டயனெட்டை '
               'தொடர்பு கொள்ளவும்.',
        'vie': 'Lấy từ trang web chính thức của Diyanet (Cơ quan Tôn giáo). Dữ liệu này '
               'được công khai. Vui lòng liên hệ Diyanet về điều khoản phân phối lại.',
    },
}

# Ceviri dosyalari 3 HARFLI ISO 639-2/3 kodu kullanir (`tur.json` ↔ `tur`),
# Ayarlar'da `Locale('tur')` olusturulur. DIKKAT: ISO 639-1 `tr` DEGILDIR.
KAYNAK_DIL = 'tur'

# Her anahtar icin eksik dillere Turkce metin yazilir ve BOS BIRAKILMAZ:
# ceviriler_test.dart anahtar kumesinin tam esitligini zorunlu kiliyor.
VARSAYILAN = 'tur'


def yukle(yol):
    if not os.path.exists(yol):
        return {}
    return json.load(io.open(yol, encoding='utf-8'))


def yaz(yol, veri):
    with io.open(yol, 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(veri, ensure_ascii=False, indent=2, sort_keys=True))
        f.write('\n')


def main():
    # tur.json referans: her dosya tur.json ile ayni anahtar kumesine sahip olmali
    tur = yukle(os.path.join(CEVIRI, 'tur.json'))
    for anahtar in YENI:
        # Ceviri dosyalari 3 HARFLI ISO kod kullanir: `tur`, `eng` ...
        tur[anahtar] = YENI[anahtar][KAYNAK_DIL]
    yaz(os.path.join(CEVIRI, 'tur.json'), tur)
    print('tur.json: %d anahtar (%d eklendi)'
          % (len(tur), len(YENI)))

    for kod in DOSYALAR:
        if kod == 'tur':
            continue
        yol = os.path.join(CEVIRI, '%s.json' % kod)
        veri = yukle(yol)
        if not veri:
            print('  %s.json ATLANDI (dosya yok)' % kod)
            continue
        eklendi = 0
        for anahtar, metinler in YENI.items():
            if anahtar not in veri:
                veri[anahtar] = metinler.get(kod) or metinler[VARSAYILAN]
                eklendi += 1
        yaz(yol, veri)
        print('  %s.json: %d anahtar (%d eklendi)' % (kod, len(veri), eklendi))

    print('\nTamam. Eksik diller Turkce metne dusuruldu; '
          'insan gozuyle denetim gerekir.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())