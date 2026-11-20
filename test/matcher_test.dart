import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trasloco/src/matcher.dart';

List<SiteUrl> _load(String name) =>
    extractUrls(File('test/fixtures/$name').readAsStringSync()).map(SiteUrl.parse).toList();

void main() {
  group('lettura', () {
    test('sitemap XML, senza immagini', () {
      final urls = extractUrls(File('test/fixtures/vecchio-sitemap.xml').readAsStringSync());
      expect(urls, hasLength(22));
      expect(urls.any((u) => u.endsWith('.jpg')), isFalse);
    });

    test('un URL per riga, CSV e percorsi', () {
      const text = '"Address","Status Code"\n"https://sito.it/a/","200"\n/b/c\nnon un url\nhttps://sito.it/a/';
      expect(extractUrls(text), ['https://sito.it/a/', '/b/c']);
    });

    test('indice di sitemap', () {
      const xml = '<sitemapindex><sitemap><loc>https://s.it/page-sitemap.xml</loc></sitemap></sitemapindex>';
      expect(isSitemapIndex(xml), isTrue);
      expect(extractLocs(xml), ['https://s.it/page-sitemap.xml']);
    });

    test('normalizza i percorsi', () {
      expect(SiteUrl.parse('https://www.Sito.it/Camere/Doppia/').key, '/camere/doppia');
      expect(SiteUrl.parse('https://sito.it/servizi/index.html').key, '/servizi');
      expect(SiteUrl.parse('https://sito.it').key, '/');
      expect(SiteUrl.parse('https://sito.it/?page_id=212').query, 'page_id=212');
      expect(SiteUrl.parse('/caff%C3%A8/').key, '/caffè');
    });
  });

  group('abbinamento', () {
    final rows = matchSites(_load('vecchio-sitemap.xml'), _load('nuovo-sitemap.xml'));
    String? target(String oldPath) => rows.firstWhere((r) => r.from.pathWithQuery == oldPath).target;
    MatchStatus status(String oldPath) => rows.firstWhere((r) => r.from.pathWithQuery == oldPath).status;

    test('pagine con nomi diversi', () {
      expect(target('/le-camere/'), '/camere');
      expect(target('/le-camere/camera-matrimoniale-vista-valle/'), '/camere/matrimoniale-vista-valle');
      expect(target('/le-camere/suite-con-camino/'), '/camere/suite-camino');
      expect(target('/le-camere/appartamento-il-fienile/'), '/camere/appartamento-fienile');
      expect(target('/ristorante-cucina-umbra/'), '/ristorante');
      expect(target('/piscina-panoramica/'), '/piscina');
      expect(target('/offerte-speciali/'), '/offerte');
    });

    test('sinonimi', () {
      expect(target('/chi-siamo/'), '/la-storia');
      expect(target('/fotogallery/'), '/galleria');
      expect(target('/privacy-policy/'), '/privacy');
      expect(target('/come-raggiungerci/'), '/contatti');
    });

    test('la lingua resta la stessa', () {
      expect(target('/en/'), '/en');
      expect(target('/en/about-us/'), '/en/about');
      expect(target('/en/rooms/double-room-valley-view/'), '/en/rooms/double-room-valley-view');
      expect(target('/en/contact/'), '/en/contact');
    });

    test('articoli spostati nel blog', () {
      expect(target('/2021/09/vendemmia-al-casale/'), '/blog/vendemmia-al-casale');
    });

    test('ripiego: sezione madre o home', () {
      expect(status('/2019/05/sagra-della-lumaca-di-cantalupo/'), MatchStatus.none);
      expect(target('/2019/05/sagra-della-lumaca-di-cantalupo/'), '/');
      expect(target('/offerte-speciali/weekend-romantico-in-umbria/'), '/offerte');
      expect(target('/?page_id=212'), '/');
    });

    test('pagine invariate', () {
      expect(status('/contatti/'), MatchStatus.same);
      expect(status('/'), MatchStatus.same);
    });
  });

  group('esportazione', () {
    final rows = matchSites(_load('vecchio-sitemap.xml'), _load('nuovo-sitemap.xml'));

    test('niente invariate e niente redirect su sé stessi', () {
      final r = redirectsFrom(rows);
      expect(r.any((x) => x.path == '/contatti/'), isFalse);
      expect(r.any((x) => x.path == '/' && x.query.isEmpty), isFalse);
      expect(r.length, rows.where((x) => x.status != MatchStatus.same).length);
    });

    test('.htaccess', () {
      final out = exportRedirects(
        ExportFormat.htaccess,
        redirectsFrom(rows),
        oldHost: 'www.ilcasaledeigelsi.it',
        newOrigin: 'https://www.casaledeigelsi.it',
      );
      expect(out, contains('RewriteRule ^le-camere/?\$ /camere? [R=301,L,NC]'));
      expect(out, contains('RewriteCond %{QUERY_STRING} ^page_id=212\$'));
      expect(out, contains('RewriteCond %{HTTP_HOST} ^(www\\.)?ilcasaledeigelsi\\.it\$ [NC]'));
    });

    test('Next.js e Vercel', () {
      final r = [const Redirect('/servizi:vecchi/', '', '/servizi'), const Redirect('/', 'p=3', '/blog')];
      final next = exportRedirects(ExportFormat.nextjs, r);
      expect(next, contains(r"source: '/servizi\\:vecchi'"));
      expect(next, contains("has: [{ type: 'query', key: 'p', value: '3' }]"));
      final vercel = exportRedirects(ExportFormat.vercel, r);
      expect(vercel, contains(r'"source": "/servizi\\:vecchi"'));
    });

    test('Redirection, Nginx, Netlify', () {
      final r = [const Redirect('/a/', '', '/b'), const Redirect('/', 'page_id=2', '/c')];
      expect(exportRedirects(ExportFormat.redirection, r), '/a/,/b,0,301\n/?page_id=2,/c,0,301\n');
      expect(exportRedirects(ExportFormat.nginx, r), contains(r'rewrite ^/a/?$ /b permanent;'));
      expect(exportRedirects(ExportFormat.netlify, r), contains('/a/  /b  301'));
    });

    test('destinazioni assolute se cambia il dominio', () {
      final r = redirectsFrom(rows, newOrigin: 'https://www.casaledeigelsi.it');
      expect(r.first.target, startsWith('https://www.casaledeigelsi.it/'));
    });
  });
}
