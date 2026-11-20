import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'matcher.dart';

/// Il risultato di una lettura: gli URL e da dove arrivano.
class LoadResult {
  const LoadResult({required this.urls, required this.source, this.sitemaps = 0});

  final List<String> urls;

  /// Cosa è stato letto: un indirizzo o il nome di un file.
  final String source;

  /// Quante sitemap sono state lette (con gli indici possono essere tante).
  final int sitemaps;
}

class LoadException implements Exception {
  LoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _userAgent = 'Trasloco/1.0 (+https://www.francescoferri.me)';

/// Scarica un indirizzo e restituisce il testo. Gestisce anche le sitemap .gz.
Future<String?> fetchText(HttpClient client, Uri uri) async {
  try {
    final req = await client.getUrl(uri).timeout(const Duration(seconds: 15));
    req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    req.headers.set(HttpHeaders.acceptHeader, 'application/xml,text/xml,text/plain,*/*');
    final res = await req.close().timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      await res.drain<void>();
      return null;
    }
    final bytes = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b)).timeout(const Duration(seconds: 40));
    final raw = bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b ? gzip.decode(bytes) : bytes;
    return utf8.decode(raw, allowMalformed: true);
  } catch (_) {
    return null;
  }
}

/// "sito.it", "https://sito.it/" o l'indirizzo esatto di una sitemap.
Uri normalizeInput(String input) {
  var s = input.trim();
  if (!s.startsWith(RegExp(r'https?://', caseSensitive: false))) s = 'https://$s';
  return Uri.parse(s);
}

/// Trova e legge le sitemap di un sito. Segue gli indici di sitemap
/// (WordPress, Yoast, Rank Math) e il file robots.txt.
Future<LoadResult> loadFromWeb(String input, {void Function(String)? onStatus, int maxSitemaps = 200}) async {
  final start = normalizeInput(input);
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12)
    ..autoUncompress = true;
  try {
    final origin = '${start.scheme}://${start.authority}';
    final queue = <Uri>[];
    final isHomeOnly = start.path.isEmpty || start.path == '/';

    Future<void> discover() async {
      onStatus?.call('robots.txt');
      final robots = await fetchText(client, Uri.parse('$origin/robots.txt'));
      if (robots != null) {
        for (final m in RegExp(r'^\s*sitemap:\s*(\S+)', caseSensitive: false, multiLine: true).allMatches(robots)) {
          queue.add(Uri.parse(m.group(1)!));
        }
      }
      if (queue.isEmpty) {
        for (final path in ['/sitemap_index.xml', '/sitemap.xml', '/wp-sitemap.xml', '/sitemap-index.xml']) {
          onStatus?.call(path);
          final text = await fetchText(client, Uri.parse('$origin$path'));
          if (text != null && text.contains(RegExp('<(urlset|sitemapindex)', caseSensitive: false))) {
            queue.add(Uri.parse('$origin$path'));
            break;
          }
        }
      }
      if (queue.isEmpty) throw LoadException('no-sitemap');
    }

    if (isHomeOnly) {
      await discover();
    } else {
      queue.add(start);
    }

    final urls = <String>[];
    final seen = <String>{};
    var read = 0;
    while (queue.isNotEmpty && read < maxSitemaps) {
      final uri = queue.removeAt(0);
      if (!seen.add(uri.toString())) continue;
      onStatus?.call(uri.path.isEmpty ? uri.host : uri.path);
      final text = await fetchText(client, uri);
      if (text == null) {
        if (read == 0 && queue.isEmpty) throw LoadException('unreachable');
        continue;
      }
      // Una pagina HTML al posto della sitemap: cerchiamo la sitemap del sito.
      if (text.contains(RegExp(r'<html', caseSensitive: false)) &&
          !text.contains(RegExp(r'<loc>', caseSensitive: false))) {
        if (uri == start && read == 0) await discover();
        continue;
      }
      read++;
      if (isSitemapIndex(text)) {
        queue.addAll(extractLocs(text).map(Uri.parse));
      } else {
        urls.addAll(extractUrls(text));
      }
    }
    if (urls.isEmpty) throw LoadException('empty');
    return LoadResult(urls: {...urls}.toList(), source: start.host, sitemaps: read);
  } finally {
    client.close(force: true);
  }
}

/// Legge un file trascinato: sitemap .xml (anche .gz), .txt o .csv.
Future<LoadResult> loadFromFile(String path) async {
  final bytes = await File(path).readAsBytes();
  final raw = bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b ? gzip.decode(bytes) : bytes;
  final urls = extractUrls(utf8.decode(raw, allowMalformed: true));
  if (urls.isEmpty) throw LoadException('empty');
  return LoadResult(urls: urls, source: path.split(Platform.pathSeparator).last, sitemaps: 1);
}

/// Legge un elenco incollato a mano.
LoadResult loadFromText(String text) {
  final urls = extractUrls(text);
  if (urls.isEmpty) throw LoadException('empty');
  return LoadResult(urls: urls, source: 'elenco');
}
