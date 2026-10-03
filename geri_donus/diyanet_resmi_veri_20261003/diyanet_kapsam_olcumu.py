# -*- coding: utf-8 -*-
"""Diyanet resmi vakit verisinin kapsam ve butunlugu olcer.

BU ARAÇ VERİ İNDİRMEZ. Yalnızca daha once indirilmis resmî dosyalari
denetler. Boylece olcum, verinin alindigi andan bagimsiz olarak
tekrarlanabilir.

Kullanim:
    python diyanet_kapsam_olcumu.py <katalog.json> [yerlesim_sayfasi.html ...]

Ornek:
    python diyanet_kapsam_olcumu.py turkiye_yerlesim_katalogu.json adana_9146.html

Katalog kaynagi (resmi):
    https://namazvakitleri.diyanet.gov.tr/assets/locations/TURKEY.json
Yerlesim sayfasi kaynagi (resmi):
    https://namazvakitleri.diyanet.gov.tr/tr-TR/<CityID>/<slug>

OLCULENLER
  * katalog: kayit sayisi, il sayisi, yinelenen CityID, yinelenen (il,yerlesim)
  * sayfa  : kac <table> var, her tabloda kac satir, hangi tarih araligi
  * sayfa  : tekrarlanan tarihler (aylik tablo haftalik tabloyla cakisiyor mu)
  * sayfa  : aralardaki bosluklar ve eksik ay listesi
"""
import sys
import io
import os
import re
import json
import html as htmllib
import datetime
import collections
import unicodedata

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

AYLAR = {'ocak': 1, 'subat': 2, 'mart': 3, 'nisan': 4, 'mayis': 5, 'haziran': 6,
         'temmuz': 7, 'agustos': 8, 'eylul': 9, 'ekim': 10, 'kasim': 11, 'aralik': 12}


def katla(s):
    """Turkce harfleri ASCII karsiliklarina indirger, kucuk harfe cevirir.

    'Kasım' -> 'kasim'. Noktasiz i ile noktali i ayrimi yapilirsa
    'Kasım' ve 'Kasim' ayni ay olur; boyle olmazsa sayfa satirlari
    'bilinmeyen ay adi' diye elenir ve eksik/tekrar olcumleri yanlis cikar.
    """
    s = unicodedata.normalize('NFC', s)
    for a, b in (('ı', 'i'), ('İ', 'i'), ('ş', 's'), ('Ş', 's'),
                 ('ğ', 'g'), ('Ğ', 'g'), ('ü', 'u'), ('Ü', 'u'),
                 ('ö', 'o'), ('Ö', 'o'), ('ç', 'c'), ('Ç', 'c')):
        s = s.replace(a, b)
    return s.lower().strip()


def duz(s):
    """HTML实体 + etiketler + bosluk temizligi."""
    s = htmllib.unescape(s)
    return re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', s)).strip()


def ay_basi(yil, ay):
    """Verilen yil/ay'in birinci gunu. ay 13 gibi degerlerde yil kayar."""
    return datetime.date(yil + (ay - 1) // 12, (ay - 1) % 12 + 1, 1)


def ay_gun_sayisi(yil, ay):
    """O ayin gercek gun sayisi (artı yil sirasinda da dogru)."""
    return (ay_basi(yil, ay + 1) - ay_basi(yil, ay)).days


def katalog_olcer(yol):
    print('=' * 72)
    print('KATALOG: %s' % os.path.basename(yol))
    # Resmi katalog UTF-8 BOM ile geliyor; utf-8-sig BOM'u soyup okur.
    kayitlar = json.load(open(yol, encoding='utf-8-sig'))
    iller = sorted({k['State'] for k in kayitlar})
    idler = [k['CityID'] for k in kayitlar]
    ciftler = [(k['State'], k['City']) for k in kayitlar]

    tekrar_id = [i for i, n in collections.Counter(idler).items() if n > 1]
    tekrar_cift = [c for c, n in collections.Counter(ciftler).items() if n > 1]

    print('  kayit sayisi        : %d' % len(kayitlar))
    print('  il (State) sayisi   : %d' % len(iller))
    print('  CityID araligi      : %d .. %d' % (min(idler), max(idler)))
    print('  YINELENEN CityID    : %d %s' % (len(tekrar_id), sorted(tekrar_id)[:10]))
    print('  YINELENEN (il,yer)  : %d %s' % (len(tekrar_cift), sorted(tekrar_cift)[:10]))
    print('  en buyuk 5 il       : %s'
          % ', '.join('%s(%d)' % (k, v) for k, v in
                      collections.Counter(k['State'] for k in kayitlar).most_common(5)))
    # Yerlesim kimligi adiyla degil, CityID ile tutulur.
    ornek = kayitlar[0]
    print('  ornek kayit         : State=%s City=%s CityID=%s'
          % (ornek['State'], ornek['City'], ornek['CityID']))
    print()
    return kayitlar


def sayfa_olcer(yol):
    print('=' * 72)
    print('YERLESIM SAYFASI: %s' % os.path.basename(yol))
    doc = open(yol, encoding='utf-8').read()
    tablolar = re.findall(r'(?s)<table.*?</table>', doc)
    print('  dosya boyutu        : %d bayt' % len(doc.encode('utf-8')))
    print('  <table> sayisi      : %d' % len(tablolar))

    hepsi, cozulemeyen = [], []
    for i, tablo in enumerate(tablolar):
        basliklar = [duz(x) for x in
                     re.findall(r'(?s)<th[^>]*>(.*?)</th>', tablo)]
        satirlar, hatalar = [], []
        for tr in re.findall(r'(?s)<tr[^>]*>(.*?)</tr>', tablo):
            td = [duz(x) for x in re.findall(r'(?s)<td[^>]*>(.*?)</td>', tr)]
            if len(td) < 8:
                continue
            m = re.match(r'^(\d{1,2})\s+(\S+)\s+(\d{4})', td[0])
            if not m:
                hatalar.append('TARIH: ' + td[0])
                continue
            mi = AYLAR.get(katla(m.group(2)))
            if not mi:
                hatalar.append('AY: ' + td[0])
                continue
            saatler = td[2:8]
            if not all(re.match(r'^\d{2}:\d{2}$', s) for s in saatler):
                hatalar.append('SAAT: ' + ','.join(saatler))
                continue
            satirlar.append((datetime.date(int(m.group(3)), mi, int(m.group(1))),
                             saatler, td[1]))
        cozulemeyen += hatalar
        hepsi += satirlar
        if not satirlar:
            continue
        tarihler = sorted({s for s, _, _ in satirlar})
        print('  --- tablo %d: %s' % (i + 1, ', '.join(basliklar[:3]) or '-'))
        print('      satir %3d | benzersiz %3d | %s .. %s'
              % (len(satirlar), len(tarihler), tarihler[0], tarihler[-1]))
        bosluk = [(tarihler[j - 1], tarihler[j]) for j in range(1, len(tarihler))
                  if (tarihler[j] - tarihler[j - 1]).days != 1]
        if bosluk:
            print('      BOSLUK: %s'
                  % ', '.join('%s->%s' % (a, b) for a, b in bosluk))

    if cozulemeyen:
        print('  !! COZULEMEYEN SATIR: %d  %s' % (len(cozulemeyen), cozulemeyen[:5]))

    print('  --- toplam ---')
    tarihler = sorted({s for s, _, _ in hepsi})
    sayim = collections.Counter(s for s, _, _ in hepsi)
    aralik = (tarihler[-1] - tarihler[0]).days + 1
    print('  <tr> toplam         : %d' % len(hepsi))
    print('  BENZERSIZ tarih     : %d' % len(tarihler))
    print('  ilk / son           : %s / %s' % (tarihler[0], tarihler[-1]))
    print('  TEKRAR eden tarih   : %d  %s'
          % (len([t for t, n in sayim.items() if n > 1]),
             [str(t) for t in sorted(t for t, n in sayim.items() if n > 1)][:8]))
    print('  aralik/eksik gun    : %d / %d' % (aralik, aralik - len(tarihler)))

    say = collections.Counter((d.year, d.month) for d in tarihler)
    yil, ay = tarihler[0].year, tarihler[0].month
    eksik = []
    while (yil, ay) <= (tarihler[-1].year, tarihler[-1].month):
        n = say.get((yil, ay), 0)
        bek = ay_gun_sayisi(yil, ay)
        if n != bek:
            eksik.append('%d-%02d %d/%d' % (yil, ay, n, bek))
        ay += 1
        if ay > 12:
            ay, yil = 1, yil + 1
    print('  eksik ay            : %s' % (', '.join(eksik) if eksik else 'yok'))

    veri = {s: (v, h) for s, v, h in hepsi}
    print('  ornek ilk satir     : %s  %s  (%s)'
          % (tarihler[0], ' '.join(veri[tarihler[0]][0]), veri[tarihler[0]][1]))
    print('  ornek son  satir    : %s  %s  (%s)'
          % (tarihler[-1], ' '.join(veri[tarihler[-1]][0]), veri[tarihler[-1]][1]))
    print()
    return hepsi


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    katalog_olcer(sys.argv[1])
    for sayfa in sys.argv[2:]:
        sayfa_olcer(sayfa)
    return 0


if __name__ == '__main__':
    sys.exit(main())