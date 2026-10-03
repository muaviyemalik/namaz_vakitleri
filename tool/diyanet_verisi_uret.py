# -*- coding: utf-8 -*-
"""Diyanet resmi vakit sayfalarindan uygulama veri paketini uretir.

GIRIS
  veri/diyanet_ham/ham/<CityID>.html        (tool/diyanet_verisi_indir.py)
  veri/diyanet_ham/indirme_gunlugu.json
  assets/veri/diyanet/katalog/TURKEY.json    (resmi katalog)
  assets/veri/sehirler/TR.txt                (uygulamanin mevcut sehir listesi)

CIKTIS
  assets/veri/diyanet/paket.json        kaynak + edinme tarihi + kapsam + butunluk
  assets/veri/diyanet/esleme.txt        normalize(il)|normalize(ad)|CityID
  assets/veri/diyanet/TR/<il>.txt       il basina veri parcasi (tembel yuklenir)

NEDEN IL BAZINDA PARCA
  Uygulama 15 MB'yi acilista bellege yuklemez. Kullanici tek bir ildeki
  bir yerlesimi secer; yalnizca o ilin parcasi okunur. Ortalama ~190 KB,
  en kalabalik il (Konya, 32 yerlesim) ~570 KB.

YERLESIM ESLESTIRMESI
  Resmi veride KOOORDINAT YOKTUR; yalnizca (il, ad, CityID) vardir. Bu yuzden
  uygulamanin (ad, il) kaydi ile resmi CityID arasindaki bag KURULURKEN
  (calisma aninda, bu araçta) adi ve il bilgisi kullanilir. Ama:
    * eslesme KESIN anahtarla (normalize edilmis il+ad) yapilir, benzerlik
      skoruyla degil;
    * birden fazla aday varsa ESLESME YOK sayilir (Uşak/USAK 17909 olgusu:
      katalog "USAK" diyor, sayfa "Ulubey" diyor);
    * hicbir ilceye, kaydi bulunamadigi icin il merkezinin vakitleri
      KOPYALANMAZ.
  Uygulama calisirken yalnizca CityID kullanir; adla eslestirme yoktur.

KULLANIM
    python tool/diyanet_verisi_uret.py
"""
import hashlib
import io
import json
import os
import re
import sys
import collections
import datetime
import unicodedata
import html as htmllib

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

KOK = 'assets/veri/diyanet'
HAM = os.path.join('veri', 'diyanet_ham', 'ham')
GUNLUK = os.path.join('veri', 'diyanet_ham', 'indirme_gunlugu.json')
KATALOG = os.path.join(KOK, 'katalog', 'TURKEY.json')
SEHIRLER = os.path.join('assets', 'veri', 'sehirler', 'TR.txt')
SURUM = 'diyanet-2026-10-03.1'

AYLAR = {'ocak': 1, 'subat': 2, 'mart': 3, 'nisan': 4, 'mayis': 5, 'haziran': 6,
         'temmuz': 7, 'agustos': 8, 'eylul': 9, 'ekim': 10, 'kasim': 11, 'aralik': 12}


def katla(s):
    s = unicodedata.normalize('NFC', s)
    for a, b in (('ı', 'i'), ('İ', 'i'), ('ş', 's'), ('Ş', 's'), ('ğ', 'g'),
                 ('Ğ', 'g'), ('ü', 'u'), ('Ü', 'u'), ('ö', 'o'), ('Ö', 'o'),
                 ('ç', 'c'), ('Ç', 'c')):
        s = s.replace(a, b)
    return s.lower().strip()


def duz(s):
    return re.sub(r'\s+', ' ', htmllib.unescape(re.sub(r'<[^>]+>', ' ', s))).strip()


def slugla(s):
    s = unicodedata.normalize('NFKD', s).replace('ı', 'i').replace('İ', 'i')
    s = ''.join(c for c in s if not unicodedata.combining(c))
    s = re.sub(r'[^A-Za-z0-9]+', '-', s).strip('-').lower()
    return s or 'x'


def sayfa_adi(doc):
    """Sayfanin KENDI bildirdigi yerlesim adi. Resmi katalogdaki `City`
    alani guvenilir DEGIL (olcum: CityID 17909 katalogda 'USAK', sayfada
    'Ulubey'). Bu yuzden sayfa kendi adini yazar."""
    m = re.search(r'(?i)<meta[^>]*property="og:title"[^>]*content="([^"]*)"', doc)
    if m:
        m2 = re.match(r'^(.*?)\s+Namaz Vakitleri\s*\|', duz(m.group(1)))
        if m2 and m2.group(1).strip():
            return m2.group(1).strip()
    m = re.search(r'(?is)<h1[^>]*>(.*?)</h1>', doc)
    if m:
        m2 = re.match(r'^(.*?)\s+Namaz Vakitleri$', duz(m.group(1)))
        if m2 and m2.group(1).strip():
            return m2.group(1).strip()
    return None


def satirlari_coz(doc):
    """Sayfadaki tum vakit satirlarini {tarih: (saatler, hicri)} yapar."""
    veri = {}
    cakisma = 0
    bozuk = []
    for tr in re.findall(r'(?s)<tr[^>]*>(.*?)</tr>', doc):
        td = [duz(x) for x in re.findall(r'(?s)<td[^>]*>(.*?)</td>', tr)]
        if len(td) < 8:
            continue
        m = re.match(r'^(\d{1,2})\s+(\S+)\s+(\d{4})', td[0])
        if not m:
            continue
        mi = AYLAR.get(katla(m.group(2)))
        if not mi:
            continue
        saatler = td[2:8]
        if not all(re.match(r'^\d{2}:\d{2}$', s) for s in saatler):
            bozuk.append(td[0])
            continue
        gun = datetime.date(int(m.group(3)), mi, int(m.group(1)))
        kayit = (tuple(s.replace(':', '') for s in saatler), td[1])
        if gun in veri:
            cakisma += 1
            # Ayni tarih iki farkli vakit veriyorsa veri bozuktur; ilkini tut.
            if veri[gun] != kayit:
                bozuk.append('%s (cakisma, farkli)' % gun)
        veri[gun] = kayit
    return veri, cakisma, bozuk


def main():
    gunluk = json.load(open(GUNLUK, encoding='utf-8'))
    katalog = json.load(open(KATALOG, encoding='utf-8-sig'))
    kat_by_id = {int(k['CityID']): k for k in katalog}

    os.makedirs(os.path.join(KOK, 'TR'), exist_ok=True)

    # -- 1) SAYFALARI COZ ------------------------------------------------
    yerlesim = {}          # cityID -> bilgi
    aralik = None
    sorunlar = []
    olu_kayit = []
    for cid, g in sorted(gunluk.items()):
        cid = int(cid)
        yol = os.path.join(HAM, '%d.html' % cid)
        if not os.path.exists(yol):
            # Gunlukte kayitli ama dosya yok: ya olumlu kayit (HTTP 500)
            # ya da indirme bitmemis. Ikisi karistirilmaz.
            if g.get('hata'):
                olu_kayit.append({'cityId': cid, 'il': g.get('state'),
                                  'katalogAdi': g.get('city'),
                                  'sebep': g['hata']})
            else:
                sorunlar.append('CityID=%d gunlukte hata yok ama sayfa dosyasi '
                                'yok (indirme yarim kalmis olabilir)' % cid)
            continue
        ham = open(yol, 'rb').read()
        if hashlib.sha256(ham).hexdigest() != g.get('sha256'):
            sorunlar.append('CityID=%d SHA256 uyusmuyor (dosya bozulmus olabilir)' % cid)
            continue
        doc = ham.decode('utf-8', 'replace')
        veri, cakisma, bozuk = satirlari_coz(doc)
        ad = sayfa_adi(doc)
        if not veri:
            sorunlar.append('CityID=%d sayfasinda vakit satiri cozulemedi' % cid)
            continue
        if ad is None:
            sorunlar.append('CityID=%d sayfasi kendi adini bildirmiyor' % cid)
            continue
        il = kat_by_id[cid]['State'] if cid in kat_by_id else '?'
        ar = (min(veri), max(veri))
        if aralik is None:
            aralik = ar
        elif aralik != ar:
            sorunlar.append('CityID=%d tarih araligi farkli: %s..%s (beklenen %s..%s)'
                            % (cid, ar[0], ar[1], aralik[0], aralik[1]))
        if bozuk:
            sorunlar.append('CityID=%d %d satir bozuk: %s' % (cid, len(bozuk), bozuk[:3]))
        yerlesim[cid] = {
            'il': il,
            'ilAd': kat_by_id[cid]['State'] if cid in kat_by_id else '',
            'katalogAd': kat_by_id[cid]['City'] if cid in kat_by_id else '',
            'ad': ad,
            'veri': veri,
            'cakisma': cakisma,
        }

    if not yerlesim:
        print('HICBIR sayfa cozulemedi. Once indiriciyi calistir.')
        return 1

    # -- 2) KATALOG <-> SAYFA ADI DENETIMI -------------------------------
    #
    # Uc tur ayrim ONEMLIDIR:
    #   * ASCII FARKI: katalog "CEVINE" gibi ASCII yaziyor, sayfa "Cevine"
    #     diye Turkce yaziyor. `katla()` ikisini de ayni indirger; esleme
    #     ETKILENMEZ. Zararsiz.
    #   * YAZIM FARKI: ayni yerlesim, farkli yazim. Olcumdeki ornek:
    #     katalog "YAYLADAG", sayfa "Yayladagi" — ayni ilce. Esleme
    #     ETKILENMEZ ama kayit altina alinir.
    #   * GERCEK FARKI: katalog ile saypa FARKLI yerlesimleri gosteriyor.
    #     Final olcumde uc tur:
    #       9381  katalog "ACIPAYAM" -> sayfa "Gunes"   (katalog YANLIŞ)
    #       9515  katalog "HATAY"   -> sayfa "Arsuz"   (katalog YANLIŞ;
    #                                Hatay merkez baska bir CityID'de)
    #       17909 katalog "USAK"    -> sayfa "Ulubey"  (katalog YANLIŞ)
    #     Bu durumda katalog adi guvenilmez ve KULLANILMAZ.
    def ascii_katla(s):
        t = unicodedata.normalize('NFKD', s).replace('ı', 'i').replace('İ', 'i')
        t = ''.join(c for c in t if not unicodedata.combining(c))
        return re.sub(r'[^A-Za-z0-9]+', '', t).lower()

    ad_uyusmazlik, gercek_fark = [], []
    for cid, b in sorted(yerlesim.items()):
        if katla(b['katalogAd']) == katla(b['ad']):
            continue
        kayit = {'cityId': cid, 'il': b['ilAd'],
                 'katalogAdi': b['katalogAd'], 'sayfaAdi': b['ad']}
        k = ascii_katla(katla(b['katalogAd']))
        s = ascii_katla(katla(b['ad']))
        if ascii_katla(b['katalogAd']) == ascii_katla(b['ad']) or k == s:
            # ASCII ya da yazim farki: ayni yerlesim, etkisiz.
            ad_uyusmazlik.append(kayit)
        else:
            gercek_fark.append(kayit)

    # -- 3) IL BAZINDA GRUPLA -------------------------------------------
    iller = collections.defaultdict(list)
    for cid, b in yerlesim.items():
        iller[b['il']].append(cid)

    # -- 4) PARCALARI YAZ -------------------------------------------------
    # Once eski parcasi sil: yarim bir calistirmadan kalan, artik uretilmeyen
    # il parcalari pakette kalmasin (aksi halde paket kendi icinde
    # tutarsiz olur: manifestte olmayan ama diskte olan dosya).
    tr_klasor = os.path.join(KOK, 'TR')
    istenen = set('%s.txt' % slugla(il) for il in iller)
    for dosya in os.listdir(tr_klasor):
        if dosya.endswith('.txt') and dosya not in istenen:
            os.remove(os.path.join(tr_klasor, dosya))
            print('  eski parca silindi: TR/%s' % dosya)

    parca_ozet = {}
    toplam_gun = 0
    for il, cidler in sorted(iller.items()):
        cidler.sort()
        parca = os.path.join(KOK, 'TR', '%s.txt' % slugla(il))
        satirlar = ['# diyanet | surum=%s | il=%s | yerlesim=%d | %s..%s'
                    % (SURUM, il, len(cidler),
                       min(min(yerlesim[c]['veri']) for c in cidler),
                       max(max(yerlesim[c]['veri']) for c in cidler))]
        for cid in cidler:
            b = yerlesim[cid]
            satirlar.append('#@%d|%s|%s|%d'
                            % (cid, b['ad'], b['il'], len(b['veri'])))
            for gun in sorted(b['veri']):
                saatler, hicri = b['veri'][gun]
                satirlar.append('%s|%s|%s'
                                % (gun.strftime('%Y%m%d'), '|'.join(saatler), hicri))
                toplam_gun += 1
        icerik = '\n'.join(satirlar) + '\n'
        open(parca, 'w', encoding='utf-8', newline='\n').write(icerik)
        parca_ozet[il] = {
            'dosya': 'TR/%s.txt' % slugla(il),
            'yerlesim': len(cidler),
            'gun': sum(len(yerlesim[c]['veri']) for c in cidler),
            'bayt': len(icerik.encode('utf-8')),
            'sha256': hashlib.sha256(icerik.encode('utf-8')).hexdigest(),
        }

    # -- 5) ESLESTIRME: uygulama kaydi -> resmi CityID -------------------
    # Anahtar normalize(il)|normalize(ad). Coklu aday varsa ESLESME YOK.
    resmi_aday = collections.defaultdict(list)
    for cid, b in yerlesim.items():
        resmi_aday['%s|%s' % (katla(b['il']), katla(b['ad']))].append(cid)

    esleme, eslesmeyen = [], []
    for satir in open(SEHIRLER, encoding='utf-8').read().splitlines():
        if not satir.strip():
            continue
        p = satir.split('|')
        if len(p) < 4:
            continue
        ad, il = p[2].strip(), p[3].strip()
        anahtar = '%s|%s' % (katla(il), katla(ad))
        adaylar = resmi_aday.get(anahtar, [])
        if len(adaylar) == 1:
            cid = adaylar[0]
            # Parca dosya adi DA buraya yazilir. Boylece Dart tarafinda slug
            # kuralini ikinci kez uygulamak gerekmez ve iki dilin kurali
            # ayrisip sessizce "veri yok" duruma dusme riski olmaz.
            parca = 'TR/%s.txt' % slugla(yerlesim[cid]['il'])
            esleme.append((anahtar, cid, parca))
        else:
            eslesmeyen.append({
                'il': il, 'ad': ad,
                'sebep': 'bulunamadi' if not adaylar else 'belirsiz (%d aday: %s)'
                         % (len(adaylar), ','.join(map(str, adaylar))),
            })

    esleme_yol = os.path.join(KOK, 'esleme.txt')
    with open(esleme_yol, 'w', encoding='utf-8', newline='\n') as f:
        f.write('# diyanet | surum=%s | eslesme=%d | katalog kaydi=%d | '
                'eslesmeyen=%d\n' % (SURUM, len(esleme), len(yerlesim), len(eslesmeyen)))
        for anahtar, cid, parca in sorted(esleme):
            f.write('%s|%d|%s\n' % (anahtar, cid, parca))

    # -- 6) PAKET MANIFESTI ---------------------------------------------
    ilk = min(min(b['veri']) for b in yerlesim.values())
    son = max(max(b['veri']) for b in yerlesim.values())
    butunluk = hashlib.sha256(
        ''.join(parca_ozet[i]['sha256'] for i in sorted(parca_ozet)).encode()
    ).hexdigest()

    paket = {
        'surum': SURUM,
        'kaynak': {
            'kurum': 'T.C. Diyanet Isleri Baskanligi',
            'siteAdi': 'Diyanet Namaz Vakitleri',
            'katalogUrl':
                'https://namazvakitleri.diyanet.gov.tr/assets/locations/TURKEY.json',
            'sayfaUrlKalibi':
                'https://namazvakitleri.diyanet.gov.tr/tr-TR/{cityId}/{slug}',
            'not': 'Sayfa `og:description` metni bu vakitlerin Diyanet resmi '
                   'hesaplamalarina dayandigini belirtir.',
        },
        'edinmeTarihi': datetime.date.today().isoformat(),
        'kapsam': {
            'ilkTarih': ilk.isoformat(),
            'sonTarih': son.isoformat(),
            'gunSayisi': (son - ilk).days + 1,
            'verilenGunSayisi': len(next(iter(yerlesim.values()))['veri']),
            'iceridekiBosluklar': bosluklar(next(iter(yerlesim.values()))['veri']),
            'ilSayisi': len(parca_ozet),
            'yerlesimSayisi': len(yerlesim),
            'katalogKaydi': len(kat_by_id),
            'veriSizmayanKayit': len(kat_by_id) - len(yerlesim),
        },
        'butunluk': {
            'yontem': 'sha256',
            'paket': butunluk,
            'parcalar': parca_ozet,
        },
        'eslestirme': {
            'dosya': 'esleme.txt',
            'eslesen': len(esleme),
            'eslesmeyen': len(eslesmeyen),
            'kural': 'normalize(il)|normalize(ad) kesin eslesme; coklu aday '
                     'veya aday yoksa eslesme YOK. Il merkezi verisi hicbir '
                     'ilceye kopyalanmaz.',
        },
        'bilinenSorunlar': {
            'katalogAdiAsciiFarki': ad_uyusmazlik,
            'katalogAdiGercekFarki': gercek_fark,
            'veriCozulemeyen': sorunlar,
            'olduKayit': olu_kayit,
        },
        'toplamSatir': toplam_gun,
    }
    open(os.path.join(KOK, 'paket.json'), 'w', encoding='utf-8').write(
        json.dumps(paket, ensure_ascii=False, indent=2))

    # -- 7) RAPOR --------------------------------------------------------
    print('=' * 70)
    print('DIYANET RESMI VERI PAKETI  surum=%s' % SURUM)
    print('=' * 70)
    print('katalog kaydi        : %d' % len(kat_by_id))
    print('veri alinan yerlesim: %d' % len(yerlesim))
    print('VERI ALAMAYAN (olu)  : %d' % len(olu_kayit))
    if sorunlar:
        print('COZULEMEYEN / yarim  : %d' % len(sorunlar))
    print('il parcasi           : %d' % len(parca_ozet))
    print('tarih araligi        : %s .. %s  (%d gun)'
          % (ilk, son, (son - ilk).days + 1))
    print('parca toplam boyutu  : %d bayt (%.1f MB)'
          % (sum(p['bayt'] for p in parca_ozet.values()),
             sum(p['bayt'] for p in parca_ozet.values()) / 1048576.0))
    print('esleme.txt           : %d eslesen / %d eslesmeyen'
          % (len(esleme), len(eslesmeyen)))
    print('toplam veri satiri   : %d' % toplam_gun)
    print('paket butunluk (sha) : %s' % butunluk[:32])
    if gercek_fark:
        print('\n!! KATALOG ADI GERCEKTEN FARKLI (katalog adi kullanilmaz, '
              'sayfa adi kullanilir) -- %d:' % len(gercek_fark))
        for a in gercek_fark:
            print('   CityID=%-6d %-9s katalog=%-12s sayfa=%s'
                  % (a['cityId'], a['il'], a['katalogAdi'], a['sayfaAdi']))
    if ad_uyusmazlik:
        print('\n   (ayrica %d kayitta katalog ASCII yaziyor, sayfa Turkce; '
              'esleme ETKILENMIYOR)' % len(ad_uyusmazlik))
    if sorunlar:
        print('\n!! SORUNLAR (%d):' % len(sorunlar))
        for s in sorunlar[:20]:
            print('   %s' % s)
    if olu_kayit:
        print('\n!! OLUMLU KAYIT - veri alamayan, DIYANET ETIKETI VERILMEZ (%d):'
              % len(olu_kayit))
        for o in olu_kayit:
            print('   CityID=%-6d %-9s katalog=%-12s %s'
                  % (o['cityId'], o['il'], o['katalogAdi'], o['sebep']))
    if eslesmeyen:
        y = collections.Counter(e['sebep'].split('(')[0] for e in eslesmeyen)
        print('\neslesmeyen kayitlar (%d): %s' % (len(eslesmeyen), dict(y)))
        for e in eslesmeyen[:12]:
            print('   %s / %s  -> %s' % (e['il'], e['ad'], e['sebep']))
    return 0


def bosluklar(veri):
    """Tarihler arasindaki BOSLUK araliklarini dondurur.

    DIKKAT: aralik EKSIK gunleri kapsar. Ardisik iki satir 2026-11-02 ve
    2027-01-01 ise, eksik olan 2026-11-03..2026-12-31'dir. `baslangic`
    bir sonraki güne, `bitis` bir sonraki satirdaki güne esittir; boylece
    `baslangic <= g < bitis` YALNIZCA eksik gunleri kapsar. (onceki surum
    `baslangic = onceki satir` idi ve veri olan gunu de bosluk sayiyordu.)
    """
    u = sorted(veri)
    out = []
    for i in range(1, len(u)):
        if (u[i] - u[i - 1]).days != 1:
            out.append({'baslangic': (u[i - 1] + datetime.timedelta(days=1)).isoformat(),
                        'bitis': u[i].isoformat(),
                        'eksikGun': (u[i] - u[i - 1]).days - 1})
    return out


if __name__ == '__main__':
    sys.exit(main())