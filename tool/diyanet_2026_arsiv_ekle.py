"""2026 arşivini doğrular, mevcut resmî satırları koruyarak eksikleri ekler.

Kullanım: python tool/diyanet_2026_arsiv_ekle.py /path/prayer-times.2026.json
Arşiv Diyanet'in sunucusu değildir. Kaynak zinciri ve örtüşme kontrolü
manifestte tutulur; eşleşme bütün yılın birincil kaynaktan doğrulandığı anlamına gelmez.
"""
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1] / 'assets/veri/diyanet'
URL = ('https://github.com/karademirmustafa/ezanvakti-imsakiyem-api/'
       'releases/download/v1.0.0/prayer-times.2026.json')
FIELDS = ('imsak', 'gunes', 'ogle', 'ikindi', 'aksam', 'yatsi')
VERSION = 'diyanet-2026-10-04.1'


def check(ok, message):
    if not ok:
        raise ValueError(message)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('archive', type=Path)
    args = ap.parse_args()
    raw = args.archive.read_bytes()
    archive = json.loads(raw)
    check(archive['meta']['year'] == 2026, 'Arşiv yılı 2026 değil')
    manifest = json.loads((ROOT / 'paket.json').read_text())
    chunks = {}
    ids = set()
    for province, info in manifest['butunluk']['parcalar'].items():
        content = (ROOT / info['dosya']).read_bytes()
        check(hashlib.sha256(content).hexdigest() == info['sha256'], 'Parça hash hatası')
        places = []
        current = None
        for line in content.decode().splitlines()[1:]:
            if line.startswith('#@'):
                p = line[2:].split('|')
                cid = int(p[0])
                check(cid not in ids, 'Tekrarlanan CityID')
                ids.add(cid)
                current = {'id': cid, 'name': p[1], 'province': p[2], 'days': {}}
                places.append(current)
            elif line and not line.startswith('#'):
                p = line.split('|')
                check(p[0] not in current['days'], 'Tekrarlanan tarih')
                current['days'][p[0]] = p[1:]
        chunks[province] = (info['dosya'], places)
    yearly = {cid: {} for cid in ids}
    for row in archive['data']:
        cid = int(row['district_id'])
        if cid not in ids:
            continue
        date = dt.date.fromisoformat(row['date'][:10])
        check(date.year == 2026, 'Yanlış yıl')
        key = date.strftime('%Y%m%d')
        check(key not in yearly[cid], f'Tekrarlı kayıt {cid}/{key}')
        times = [row['times'][f] for f in FIELDS]
        check(all(re.fullmatch(r'(?:[01]\d|2[0-3]):[0-5]\d', t) for t in times), 'Bozuk vakit')
        check(times == sorted(times) and len(set(times)) == 6, 'Vakit sırası hatalı')
        check(row['meta']['source'] == 'Diyanet İşleri Başkanlığı', 'Kaynak etiketi farklı')
        hijri = row['hijri_date']['full_date']
        check(hijri and not any(c in hijri for c in '\n\r|'), 'Hicri metin hatalı')
        yearly[cid][key] = [t.replace(':', '') for t in times] + [hijri]
    expected = {(dt.date(2026, 1, 1) + dt.timedelta(days=i)).strftime('%Y%m%d') for i in range(365)}
    overlap = added = 0
    for _, places in chunks.values():
        for place in places:
            cid, days = place['id'], place['days']
            check(set(yearly[cid]) == expected, f'2026 kapsamı eksik {cid}')
            for date, values in yearly[cid].items():
                if date in days:
                    check(days[date][:6] == values[:6], f'Resmî vakit uyuşmazlığı {cid}/{date}')
                    overlap += 1
                else:
                    days[date] = values
                    added += 1
    # Tüm kontroller tamamlanmadan hiçbir çıktı yazılmaz.
    full = {(dt.date(2026, 1, 1) + dt.timedelta(days=i)).strftime('%Y%m%d') for i in range(730)}
    outputs = {}
    for province, (file, places) in chunks.items():
        lines = [f'# diyanet | surum={VERSION} | il={province} | yerlesim={len(places)} | 2026-01-01..2027-12-31']
        for place in places:
            days = place['days']
            check(set(days) == full, f'2026–2027 kesintisiz değil {place["id"]}')
            lines.append(f'#@{place["id"]}|{place["name"]}|{place["province"]}|{len(days)}')
            lines.extend('|'.join([day] + days[day]) for day in sorted(days))
        content = ('\n'.join(lines) + '\n').encode()
        outputs[file] = content
        manifest['butunluk']['parcalar'][province].update(
            gun=sum(len(p['days']) for p in places), bayt=len(content), sha256=hashlib.sha256(content).hexdigest())
    manifest['surum'] = VERSION
    manifest['edinmeTarihi'] = '2026-10-04'
    manifest['kapsam'].update(ilkTarih='2026-01-01', gunSayisi=730, verilenGunSayisi=730, iceridekiBosluklar=[])
    manifest['toplamSatir'] = 730 * len(ids)
    manifest['butunluk']['paket'] = hashlib.sha256(''.join(
        manifest['butunluk']['parcalar'][p]['sha256'] for p in sorted(chunks)).encode()).hexdigest()
    manifest['kaynak']['arsiv2026'] = {
        'url': URL, 'araci': 'karademirmustafa/ezanvakti-imsakiyem-api',
        'sha256': hashlib.sha256(raw).hexdigest(), 'meta': archive['meta'],
        'dogrulama': {'ortusenGun': overlap, 'uyusmayanVakit': 0, 'eklenenGun': added,
                     'yerlesim': len(ids), 'gunYerlesim': 365},
        'not': '2026 eksikleri Diyanet verisi olarak yayımlanmış üçüncü taraf arşivinden alındı. '
               'Örtüşen altı vakit mevcut birincil kaynak paketiyle birebir doğrulandı; '
               'eksik tarihler bu oturumda Diyanet sunucusundan bağımsız doğrulanamadı. '
               'Mevcut satırlar ve yerleşim kimlikleri korundu. Yeniden dağıtım izni ayrı açık iştir.'}
    for file, content in outputs.items():
        (ROOT / file).write_bytes(content)
    mapping = ROOT / 'esleme.txt'
    text = mapping.read_text()
    text = re.sub(r'surum=[^ |\n]+', 'surum=' + VERSION, text, count=1)
    mapping.write_text(text)
    (ROOT / 'paket.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'yerlesim': len(ids), 'ortusenGun': overlap, 'eklenenGun': added,
                      'toplamSatir': manifest['toplamSatir'], 'kapsam': '2026-01-01..2027-12-31'}, ensure_ascii=False))


if __name__ == '__main__':
    main()
