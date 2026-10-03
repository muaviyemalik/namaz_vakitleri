# -*- coding: utf-8 -*-
"""Sayfanin kendi ilk bildirdigi yerlesim adini cikarir.

NEDEN GEREKLI?
Resmi katalog `City` alani guvenilir DEGIL. Olcumde goruldu:
  katalog : USAK / USAK / CityID 17909
  sayfa  : "Ulubey icin gunluk namaz vakitleri ..."
Yani katalog 17909'u "Usak" diye yaziyor, sayfa ise ULUBEY vakitlerini
veriyor. Yani tek guvenilir kimlik CityID'nin kendisidir; ad degil.

Bu arac, indirilmis sayfalardan sayfanin kendi adini (og:description /
og:title / h1) cikarip katalogdaki adla karsilastirir.
"""
import sys
import io
import os
import re
import html as htmllib

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')


def duz(s):
    return re.sub(r'\s+', ' ', htmllib.unescape(re.sub(r'<[^>]+>', ' ', s))).strip()


def sayfa_adi(yol):
    doc = open(yol, encoding='utf-8').read()
    aday = []
    m = re.search(r'(?i)<meta[^>]*property="og:description"[^>]*content="([^"]*)"', doc)
    if m:
        m2 = re.match(r'^(.*?)\s+icin\s+günlük namaz vakitleri', duz(m.group(1)))
        if m2:
            aday.append(('og:description', m2.group(1)))
    m = re.search(r'(?i)<meta[^>]*property="og:title"[^>]*content="([^"]*)"', doc)
    if m:
        m2 = re.match(r'^(.*?)\s+Namaz Vakitleri\s*\|', duz(m.group(1)))
        if m2:
            aday.append(('og:title', m2.group(1)))
    m = re.search(r'(?is)<h1[^>]*>(.*?)</h1>', doc)
    if m:
        aday.append(('h1', duz(m.group(1))))
    return aday


if __name__ == '__main__':
    for yol in sys.argv[1:]:
        print('--- %s' % os.path.basename(yol))
        for kaynak, ad in sayfa_adi(yol):
            print('    %-16s %s' % (kaynak, ad))