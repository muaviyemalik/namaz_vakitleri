# -*- coding: utf-8 -*-
"""Diyanet resmi vakit sayfalarini indirir (hizli + surdurulebilir).

KULLANIM
    python tool/diyanet_verisi_indir.py [--hiz 1.2] [--sadece 9146,9206]
                                          [--cikti <dizin>] [--tekrar]

NEDEN BU KADAR KORUMALI
  * Sunucu WAF korumali. Hizi bilincli dusurur, her istek arasinda bekler.
    WAF'in engelledigi bir istekte HIZLANILMAZ; istek atlanir ve rapora yazilir.
  * Indirilen ham HTML onbellege yazilir. Ayni sayfa ikinci kez istenmez;
    boylece yeniden calistirmak sunucuya yuk bindirmez.
  * Her dosyanin SHA256'si gunluk guncellenir; sonradan butunluk denetlenebilir.
  * HTTP 500 veren CityID'ler (olumlu kayit) 2 denemeden sonra BIRAKILIR.
    Bunlar cogunlukla 1-2 kayittir; sunucuyu zorlamamak icin.

GIRIS  : resmi katalog (assets/veri/diyanet/katalog/TURKEY.json)
        https://namazvakitleri.diyanet.gov.tr/assets/locations/TURKEY.json
CIKTIS : <cikti>/ham/<CityID>.html  ve  <cikti>/indirme_gunlugu.json
"""
import argparse
import hashlib
import io
import json
import os
import random
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.request

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

KOK = 'https://namazvakitleri.diyanet.gov.tr'
KATALOG_URL = KOK + '/assets/locations/TURKEY.json'
UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) namaz-vakitleri-aktarim/1.0'


def katla(s):
    s = unicodedata.normalize('NFC', s)
    for a, b in (('ı', 'i'), ('İ', 'i'), ('ş', 's'), ('Ş', 's'), ('ğ', 'g'),
                 ('Ğ', 'g'), ('ü', 'u'), ('Ü', 'u'), ('ö', 'o'), ('Ö', 'o'),
                 ('ç', 'c'), ('Ç', 'c')):
        s = s.replace(a, b)
    return s.lower().strip()


def slugla(ad):
    """Yerlesim adindan URL slug'i. Sunucu slug'i yok sayiyor ama
    tutarli bir yol uretmek 500'e karsi bir yedek sagliyor."""
    s = unicodedata.normalize('NFKD', ad)
    s = ''.join(ch for ch in s if not unicodedata.combining(ch))
    s = s.replace('ı', 'i').replace('İ', 'i')
    s = re.sub(r'[^A-Za-z0-9]+', '-', s).strip('-').lower()
    return s or 'x'


def get(url, timeout=60):
    istek = urllib.request.Request(url, headers={
        'User-Agent': UA,
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'tr-TR,tr;q=0.9',
    })
    with urllib.request.urlopen(istek, timeout=timeout) as c:
        return c.getcode(), c.read()


def waf_mi(govde):
    return b'guvenlik kurallar' in govde or b'security rules' in govde.lower()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--hiz', type=float, default=1.2,
                    help='istekler arasi bekleme (saniye), varsayilan 1.2')
    ap.add_argument('--sadece', default='',
                    help='virgulle ayrilmis CityID listesi (deneme icin)')
    ap.add_argument('--cikti', default='veri/diyanet_ham')
    ap.add_argument('--tekrar', action='store_true',
                    help='onbellekteki dosyalari yeniden indir')
    args = ap.parse_args()

    katalog_yol = os.path.join('assets', 'veri', 'diyanet', 'katalog', 'TURKEY.json')
    if not os.path.exists(katalog_yol):
        print('katalog yok: %s' % katalog_yol)
        print('once indiriliyor...')
        os.makedirs(os.path.dirname(katalog_yol), exist_ok=True)
        kod, veri = get(KATALOG_URL)
        with open(katalog_yol, 'wb') as f:
            f.write(veri)
        print('  indirildi (%d bayt)' % len(veri))

    kayitlar = json.load(open(katalog_yol, encoding='utf-8-sig'))
    if args.sadece:
        istenen = {int(x) for x in args.sadece.split(',') if x.strip()}
        kayitlar = [k for k in kayitlar if int(k['CityID']) in istenen]

    ham = os.path.join(args.cikti, 'ham')
    os.makedirs(ham, exist_ok=True)
    gunluk_yol = os.path.join(args.cikti, 'indirme_gunlugu.json')
    gunluk = {}
    if os.path.exists(gunluk_yol) and not args.tekrar:
        gunluk = json.load(open(gunluk_yol, encoding='utf-8'))

    toplam = len(kayitlar)
    basari = atlanan = hata = 0
    baslangic = time.time()

    for i, k in enumerate(kayitlar, 1):
        cid = int(k['CityID'])
        hedef = os.path.join(ham, '%d.html' % cid)
        if os.path.exists(hedef) and not args.tekrar:
            basari += 1
            continue

        # Resmi katalogdaki ad her zaman dogru degil (olcum: 17909 katalogda
        # "USAK" ama sayfa "Ulubey"). Bu yuzden slug adaylari sirayla denenir.
        denendi = []
        kod = None
        govde = None
        for slug in ('%s-namaz-vakitleri' % slugla(k['City']),
                     '%s-icin-namaz-vakti' % slugla(k['City']),
                     'x'):
            url = '%s/tr-TR/%d/%s' % (KOK, cid, slug)
            denendi.append(url)
            try:
                kod, govde = get(url)
                if waf_mi(govde):
                    print('  [%d/%d] CityID=%d WAF ENGELLEDI - atlandi'
                          % (i, toplam, cid))
                    atlanan += 1
                    kod = None
                    break
                break
            except urllib.error.HTTPError as e:
                kod = e.code
                if e.code not in (500, 404):
                    print('  [%d/%d] CityID=%d HTTP %d'
                          % (i, toplam, cid, e.code))
                if e.code == 500:
                    # Olumlu/bozuk kayit: bir kez daha dene, sonra birak.
                    try:
                        time.sleep(args.hiz * 2)
                        kod2, govde2 = get(denendi[-1] if len(denendi) == 1
                                           else '%s/tr-TR/%d/x' % (KOK, cid))
                        if not waf_mi(govde2):
                            kod, govde = kod2, govde2
                            break
                    except Exception:
                        pass
                    print('  [%d/%d] CityID=%d (%s/%s) HTTP 500 - OLU KAYIT, birakildi'
                          % (i, toplam, cid, k['State'], k['City']))
                    gunluk[str(cid)] = {
                        'state': k['State'], 'city': k['City'],
                        'url': denendi[-1], 'hata': 'HTTP 500 (olu kayit)',
                        'indirildi': time.strftime('%Y-%m-%dT%H:%M:%S'),
                    }
                    hata += 1
                    kod = None
                    break
            except Exception as e:
                print('  [%d/%d] CityID=%d hata: %s' % (i, toplam, cid, e))
                hata += 1
                kod = None
                break

        if govde and kod == 200:
            with open(hedef, 'wb') as f:
                f.write(govde)
            gunluk[str(cid)] = {
                'state': k['State'], 'city': k['City'],
                'url': denendi[-1], 'bayt': len(govde),
                'sha256': hashlib.sha256(govde).hexdigest(),
                'indirildi': time.strftime('%Y-%m-%dT%H:%M:%S'),
            }
            basari += 1
        else:
            gunluk[str(cid)] = {
                'state': k['State'], 'city': k['City'],
                'url': denendi[-1] if denendi else None,
                'hata': gunluk.get(str(cid), {}).get('hata')
                        or ('HTTP %s' % (kod if kod is not None else 'bilinmiyor')),
                'indirildi': time.strftime('%Y-%m-%dT%H:%M:%S'),
            }

        if i % 20 == 0 or i == toplam:
            json.dump(gunluk, open(gunluk_yol, 'w', encoding='utf-8'),
                      ensure_ascii=False, indent=1, sort_keys=True)
            gecen = time.time() - baslangic
            kalan = (toplam - i) * args.hiz
            print('  %d/%d  basarili=%d atlandi=%d hata=%d  %.0fs gecti, ~%.0fdk kaldi'
                  % (i, toplam, basari, atlanan, hata, gecen, kalan / 60))

        time.sleep(args.hiz * random.uniform(0.85, 1.25))

    json.dump(gunluk, open(gunluk_yol, 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1, sort_keys=True)
    print('\nTAMAM  basarili=%d  WAF-atlandi=%d  hata/olu=%d  -> %s'
          % (basari, atlanan, hata, gunluk_yol))
    return 0


if __name__ == '__main__':
    sys.exit(main())