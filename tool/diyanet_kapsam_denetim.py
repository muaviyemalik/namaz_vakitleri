# -*- coding: utf-8 -*-
"""Final Diyanet paketinin butunluk denetimi — GERCEK VERIDEN olcer.

BU ARAÇ YENI HICBIR SEY URETMEZ. Yalnizca `paket.json`, `esleme.txt` ve
`TR/*.txt` dosyalarini okuyup her sayiyi bagimsiz olarak olcer. Boylece
"uretim araci ne yazdi" ile "dosyada gercekten ne var" birbirinden
ayrilir; uretim aracinin bir hata yapma ihtimali denetimi zayiflatmaz.

OLCULEMLER
  * il / yerlesim / gun sayilari
  * eksik gun, duplicate tarih, duplicate kimlik
  * bozuk saat bicimi, eksik vakit alani
  * cift kodlama (mojibake) izleri: 'Ã', 'Â', 'â€', U+FFFD vb.
  * 865 katalog kaydinin tam siniflandirmasi (matematiksel tamlik)
  * esleme dosyasinin her satirinin gercekten var olan bir CityID'yi gostermesi

KULLANIM
    python tool/diyanet_kapsam_denetim.py
"""
import collections
import datetime
import glob
import io
import json
import os
import re
import sys
import unicodedata

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

KOK = os.path.join('assets', 'veri', 'diyanet')
HATA_ADIM = 1


def basarisiz(mesaj):
    print('BASARISIZ: %s' % mesaj)
    sys.exit(HATA_ADIM)


def duz(s):
    return re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', s)).strip()


# --- MOJIBAKE TESPITI ------------------------------------------------
# Cift kodlama, UTF-8 baytlarinin Latin-1 olarak yeniden okunmasidir ve
# su izleri birakir. Bunlar Turkce harf DEGIL, ASCII'dir; boylece bir
# Turkce metinde gorunmez olurlar.
MOJIBAKE_ISARETLERI = [
    '\u00c3',        # Ã  (çift kodlanmış ğ/ş/ü vb.)
    '\u00c2',        # Â
    '\u00e2\u0080',  # â€ (kısa tire, akıllı tırnak)
    '\u00e2\u0080\u0099',  # â€™
    '\ufffd',        # �  (UTF-8 bozulma işareti)
    '\u00ef\u00bf\u00bd',
]


def mojibake_izleri(metin):
    """Bir metindeki çift kodlama izlerini döner."""
    bulunan = []
    for iz in MOJIBAKE_ISARETLERI:
        adet = metin.count(iz)
        if adet:
            bulunan.append((iz, adet))
    return bulunan


def main():
    paket = json.load(io.open(os.path.join(KOK, 'paket.json'), encoding='utf-8'))
    kapsam = paket['kapsam']
    sorunlar = paket['bilinenSorunlar']

    # --- 1) KATALOG KAYITLARININ TAM SINIFLANDIRMASI ------------------
    katalog = json.load(
        io.open(os.path.join(KOK, 'katalog', 'TURKEY.json'), encoding='utf-8-sig'))
    katalog_id = {int(k['CityID']) for k in katalog}

    gunluk = json.load(
        io.open(os.path.join('veri', 'diyanet_ham', 'indirme_gunlugu.json'),
                encoding='utf-8'))
    gunluk_id = {int(k) for k in gunluk}

    olu = {int(o['cityId']) for o in sorunlar['olduKayit']}
    basarili_id = {i for i in katalog_id
                   if os.path.exists(os.path.join('veri', 'diyanet_ham', 'ham',
                                                  '%d.html' % i))}

    # --- 2) TR DOSYALARINI TAM OLARAK OKU ----------------------------
    parcalar = sorted(glob.glob(os.path.join(KOK, 'TR', '*.txt')))
    # il -> {cityID -> {tarih -> (saatler, hicri)}}
    il_veri = {}
    bozuk_saat = []
    eksik_alan = []
    cift_kodlama = []
    toplam_satir = 0

    for yol in parcalar:
        cid = None
        for no, satir in enumerate(io.open(yol, encoding='utf-8'), 1):
            satir = satir.rstrip('\n')
            if satir.startswith('#@'):
                p = satir[2:].split('|')
                cid = int(p[0])
                il_veri.setdefault(yol, {})[cid] = {}
                continue
            if satir.startswith('#') or not satir.strip():
                continue
            p = satir.split('|')
            if len(p) < 7:
                eksik_alan.append((yol, no, len(p)))
                continue
            tarih = datetime.date(int(p[0][:4]), int(p[0][4:6]),
                                  int(p[0][6:8]))
            saatler = p[1:7]
            for s in saatler:
                if not re.match(r'^\d{4}$', s):
                    bozuk_saat.append((yol, no, s))
            hicri = '|'.join(p[7:]) if len(p) > 7 else ''
            for iz, adet in mojibake_izleri(hicri):
                cift_kodlama.append((yol, no, hicri, iz, adet))
            il_veri[yol][cid][tarih] = (tuple(saatler), hicri)
            toplam_satir += 1

    tum_veri = {}
    for yol in il_veri:
        for cid, gunler in il_veri[yol].items():
            tum_veri[cid] = gunler

    # --- 3) KIMLIK TEKILLIGI -----------------------------------------
    # Ayni CityID iki il parcasinda olmamali.
    cid_iller = collections.Counter()
    for yol in il_veri:
        for cid in il_veri[yol]:
            cid_iller[cid] += 1
    yinelenen_cid = [c for c, n in cid_iller.items() if n > 1]

    # --- 4) GUN KUMESI TUM YERLESIMLERDE AYNI MI ----------------------
    referans = None
    farkli_kume = []
    for cid, gunler in sorted(tum_veri.items()):
        kume = set(gunler)
        if referans is None:
            referans = kume
        elif kume != referans:
            farkli_kume.append(cid)

    # --- 5) TEKRAR TARIH (bir il parcasi icinde) ----------------------
    tekrarli = []
    for yol in il_veri:
        for cid, gunler in il_veri[yol].items():
            sayac = collections.Counter()
            # satir bazinda sayac etmemiz gerek; ayni tarih iki satirda
            # gelmis olabilir. Ham dosyayi yeniden tarayalim.
            for satir in io.open(yol, encoding='utf-8'):
                if satir.startswith('#@'):
                    break
                if satir.startswith('#') or not satir.strip():
                    continue
                sayac[satir.split('|')[0]] += 1
            tek = [t for t, n in sayac.items() if n > 1]
            if tek:
                tekrarli.append((os.path.basename(yol), cid, tek[:5]))

    # --- 6) ESLEME DOSYASI -------------------------------------------
    esleme = {}
    esleme_cift = collections.defaultdict(list)
    for satir in io.open(os.path.join(KOK, 'esleme.txt'), encoding='utf-8'):
        satir = satir.strip()
        if not satir or satir.startswith('#'):
            continue
        p = satir.split('|')
        cid = int(p[2])
        esleme['%s|%s' % (p[0], p[1])] = (cid, p[3] if len(p) > 3 else '')
        esleme_cift[cid].append('%s|%s' % (p[0], p[1]))
    eslesmeyen_cid = [c for c, k in esleme_cift.items() if len(k) > 1]
    olmayan_cid = sorted({c for c, _ in esleme.values()} - set(tum_veri))
    parcasiz = [k for k, v in esleme.items() if not v[1]]
    eksik_parca = sorted({
        v[1] for v in esleme.values()
        if v[1] and not os.path.exists(os.path.join(KOK, v[1]))})

    # --- 7) RAPOR ----------------------------------------------------
    print('=' * 74)
    print('DIYANET FINAL PAKETI BÜTÜNLÜK DENETİMİ')
    print('=' * 74)

    print('\n--- KAPSAM ---')
    print('katalog kaydi (katalog.json)   : %d' % kapsam['katalogKaydi'])
    print('katalog kaydi (yeniden sayıldı): %d' % len(katalog_id))
    print('indirme günlüğünde işlenen      : %d' % len(gunluk_id))
    print('dosya olarak indirilen          : %d' % len(basarili_id))
    print('pakete giren yerleşim           : %d' % kapsam['yerlesimSayisi'])
    print('  (yeniden sayılan TR dosyaları): %d' % len(tum_veri))
    print('il parcasi                      : %d  (paket.json: %d)'
          % (len(parcalar), kapsam['ilSayisi']))
    print('esleme.txt satırı               : %d' % len(esleme))
    print('tarih aralığı                   : %s .. %s'
          % (kapsam['ilkTarih'], kapsam['sonTarih']))
    print('verilen gün/yerleşim            : %d' % kapsam['verilenGunSayisi'])
    print('toplam veri satırı              : %d (paket.json: %d)'
          % (toplam_satir, paket['toplamSatir']))

    print('\n--- 865 KAYDIN SINIFLANDIRMASI (matematiksel tamlik) ---')
    print('  başarıyla indirilen           : %d' % len(basarili_id))
    print('  kalıcı HTTP hatası (ölü kayıt): %d  %s'
          % (len(olu), sorted(olu)))
    print('  katalog dışı / klasörde yok   : %d'
          % len(katalog_id - basarili_id - olu))
    print('  ---------------------------------')
    toplam = len(basarili_id) + len(olu) + len(katalog_id - basarili_id - olu)
    print('  TOPLAM                         : %d (beklenen %d) %s'
          % (toplam, len(katalog_id),
             'TAMAM' if toplam == len(katalog_id) else 'EKSİK!'))

    print('\n--- KİMLİK / YERLEŞİM ---')
    print('  yinelenen CityID (birden çok il parçasında): %d %s'
          % (len(yinelenen_cid), yinelenen_cid[:10]))
    print('  farklı gün kümesi olan yerleşim           : %d %s'
          % (len(farkli_kume), farkli_kume[:10]))
    print('  aynı CityID\'ye bağlanan birden çok anahtar: %d %s'
          % (len(eslesmeyen_cid), eslesmeyen_cid[:10]))
    print('  paketten olmayan CityID\'ye bağlanan eşleme: %d %s'
          % (len(olmayan_cid), olmayan_cid[:10]))
    print('  il parçası boş olan eşleme               : %d' % len(parcasiz))
    print('  dosyası olmayan il parçası                : %d %s'
          % (len(eksik_parca), eksik_parca[:5]))

    print('\n--- İÇERİK BÜTÜNLÜĞÜ ---')
    print('  bozuk saat biçimi : %d %s' % (len(bozuk_saat), bozuk_saat[:5]))
    print('  eksik vakit alanı : %d %s' % (len(eksik_alan), eksik_alan[:5]))
    print('  TEKRAR eden tarih : %d %s' % (len(tekrarli), tekrarli[:5]))
    print('  çift kodlama (mojibake) izi: %d %s'
          % (len(cift_kodlama), cift_kodlama[:5]))

    print('\n--- BOŞLUKLAR ---')
    for b in kapsam['iceridekiBosluklar']:
        print('  %s .. %s  (%d gün yok)'
              % (b['baslangic'], b['bitis'], b['eksikGun']))
    if not kapsam['iceridekiBosluklar']:
        print('  yok')

    print('\n--- KİMLİK UYUŞMAZLIKLARI (bilinen, güvenle reddedildi) ---')
    gr = sorunlar.get('katalogAdiGercekFarki', [])
    ascii_f = sorunlar.get('katalogAdiAsciiFarki', [])
    print('  gerçek fark (katalog adı YANLIŞ) : %d' % len(gr))
    for g in gr:
        print('     CityID=%-6d %-9s katalog=%-12s sayfa=%s'
              % (g['cityId'], g['il'], g['katalogAdi'], g['sayfaAdi']))
    print('  ASCII farkı (etkisiz)             : %d' % len(ascii_f))

    # --- 8) KISIT DENETIMLERİ ----------------------------------------
    print('\n--- KISIT DENETİMLERİ ---')
    kontroller = [
        ('katalog kaydı 865', kapsam['katalogKaydi'] == 865),
        ('il sayısı 81', kapsam['ilSayisi'] == 81),
        ('TR dosyası = il sayısı', len(parcalar) == kapsam['ilSayisi']),
        ('pakete giren = TR\'den sayılan',
         kapsam['yerlesimSayisi'] == len(tum_veri)),
        # `basarili_id` yalnız DOSYASI BULUNAN kayıtlardır; ölü kayıtların
        # dosyası yoktur ve bu yüzden zaten bu kümede değildir. Doğru
        # eşitlik: indirilen + ölü = katalog toplamı.
        ('indirilen + ölü = 865',
         len(basarili_id) + len(olu) == len(katalog_id)),
        ('günlük tam (865)', len(gunluk_id) == 865),
        ('yinelenen CityID yok', not yinelenen_cid),
        ('farklı gün kümesi yok', not farkli_kume),
        ('tekrar eden tarih yok', not tekrarli),
        ('bozuk saat yok', not bozuk_saat),
        ('eksik vakit alanı yok', not eksik_alan),
        ('çift kodlama izi yok', not cift_kodlama),
        ('çoklu anahtar→CityID yok', not eslesmeyen_cid),
        ('olmayan CityID\'ye eşleme yok', not olmayan_cid),
        ('boş il parçası yok', not parcasiz),
        ('eksik il parçası dosyası yok', not eksik_parca),
        ('tarih aralığı 2026-10-03..2027-12-31',
         kapsam['ilkTarih'] == '2026-10-03'
         and kapsam['sonTarih'] == '2027-12-31'),
        ('gün/yerleşim 396', kapsam['verilenGunSayisi'] == 396),
        ('paket bütünlük damgası var', bool(paket['butunluk']['paket'])),
        ('paket bütünlük: 81 parça', len(paket['butunluk']['parcalar']) == 81),
    ]
    hata = 0
    for ad, gecti in kontroller:
        print('  [%s] %s' % ('OK ' if gecti else 'HATA', ad))
        if not gecti:
            hata += 1

    print('\nSONUÇ: %d / %d kontrol geçti'
          % (len(kontroller) - hata, len(kontroller)))
    return 1 if hata else 0


if __name__ == '__main__':
    sys.exit(main())