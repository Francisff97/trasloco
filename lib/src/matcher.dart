/// Il cuore di Trasloco: legge gli elenchi di URL, abbina le pagine vecchie
/// a quelle nuove e scrive i redirect nei vari formati.
library;

// ---------------------------------------------------------------------------
// Elenchi di URL
// ---------------------------------------------------------------------------

final _locRe = RegExp(r'<loc>\s*(?:<!\[CDATA\[)?\s*(.*?)\s*(?:\]\]>)?\s*</loc>', caseSensitive: false, dotAll: true);

/// File che non sono pagine: nelle sitemap delle immagini o negli export dei crawler.
final _assetRe = RegExp(
  r'\.(jpe?g|png|gif|webp|avif|svg|ico|css|js|mjs|json|pdf|zip|mp4|webm|mov|mp3|woff2?|ttf|otf|eot|xml|txt)$',
  caseSensitive: false,
);

String decodeXmlEntities(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&#39;', "'");

/// Le `<loc>` di una sitemap (anche di un indice di sitemap).
List<String> extractLocs(String xml) =>
    _locRe.allMatches(xml).map((m) => decodeXmlEntities(m.group(1)!.trim())).toList();

bool isSitemapIndex(String xml) => xml.contains(RegExp(r'<sitemapindex', caseSensitive: false));

/// Trova gli URL in qualunque testo: sitemap XML, un URL per riga,
/// CSV (anche gli export di Screaming Frog) o percorsi che iniziano con "/".
List<String> extractUrls(String text) {
  final List<String> raw;
  if (text.contains(RegExp(r'<loc>', caseSensitive: false))) {
    raw = extractLocs(text);
  } else {
    raw = [];
    for (final line in text.split(RegExp(r'\r?\n'))) {
      for (final cell in line.split(RegExp(r'[,;\t]'))) {
        final v = cell.trim().replaceAll(RegExp(r'''^["']|["']$'''), '').trim();
        if (v.startsWith(RegExp(r'https?://', caseSensitive: false)) || (v.startsWith('/') && !v.startsWith('//'))) {
          raw.add(v);
          break;
        }
      }
    }
  }
  final seen = <String>{};
  final out = <String>[];
  for (final u in raw) {
    // Spazi, e i caratteri jolly delle regole di robots.txt (es. /wp-content/*), non sono pagine.
    if (u.isEmpty || u.contains(' ') || u.contains('*') || u.contains(r'$')) continue;
    final path = u.split('?').first;
    if (_assetRe.hasMatch(path)) continue;
    if (seen.add(u)) out.add(u);
  }
  return out;
}

// ---------------------------------------------------------------------------
// URL normalizzati
// ---------------------------------------------------------------------------

/// Un URL del sito, con la versione normalizzata per il confronto.
class SiteUrl {
  SiteUrl._(this.original, this.host, this.path, this.query, this.key);

  /// L'URL come l'ha scritto la sitemap.
  final String original;

  /// "www.sito.it", vuoto se era solo un percorso.
  final String host;

  /// Percorso così com'è, es. "/camere/doppia/".
  final String path;

  /// Query senza "?", es. "page_id=12". Vuota se non c'è.
  final String query;

  /// Percorso normalizzato: minuscolo, senza slash finale, senza index.html.
  final String key;

  static SiteUrl parse(String input) {
    var s = input.trim();
    var host = '';
    final m = RegExp(r'^https?://([^/?#]+)(.*)$', caseSensitive: false).firstMatch(s);
    if (m != null) {
      host = m.group(1)!.toLowerCase();
      s = m.group(2)!;
    }
    s = s.split('#').first;
    var path = s;
    var query = '';
    final q = s.indexOf('?');
    if (q >= 0) {
      path = s.substring(0, q);
      query = s.substring(q + 1);
    }
    if (path.isEmpty) path = '/';
    if (!path.startsWith('/')) path = '/$path';
    return SiteUrl._(input.trim(), host, path, query, normalizePath(path) + (query.isEmpty ? '' : '?$query'));
  }

  bool get isRoot => key == '/';

  /// Percorso con la query, come va scritto nei redirect.
  String get pathWithQuery => query.isEmpty ? path : '$path?$query';

  @override
  String toString() => original;
}

String _safeDecode(String s) {
  try {
    return Uri.decodeComponent(s);
  } catch (_) {
    return s;
  }
}

String normalizePath(String path) {
  var p = _safeDecode(path).toLowerCase().replaceAll(RegExp(r'/{2,}'), '/');
  p = p.replaceFirst(RegExp(r'/(index|default)\.(html?|php|aspx?)$'), '/');
  if (p.length > 1 && p.endsWith('/')) p = p.substring(0, p.length - 1);
  return p.isEmpty ? '/' : p;
}

// ---------------------------------------------------------------------------
// Parole
// ---------------------------------------------------------------------------

const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', //
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', //
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ñ': 'n', 'ç': 'c', 'ß': 'ss',
};

const _stopwords = {
  'il', 'lo', 'la', 'i', 'gli', 'le', 'un', 'uno', 'una', 'di', 'del', 'dello', 'della', 'dei', 'degli', 'delle', //
  'a', 'al', 'allo', 'alla', 'ai', 'agli', 'alle', 'da', 'dal', 'dalla', 'in', 'nel', 'nella', 'con', 'su', 'per', //
  'e', 'ed', 'o', 'the', 'an', 'of', 'and', 'or', 'to', 'for', 'on', 'at', 'our', 'nostro', 'nostra', 'nostri', //
  'html',
  'htm',
  'php',
  'asp',
  'aspx',
  'index',
  'page',
  'pagina',
  'pages',
  'pagine',
  'www',
  'it',
  'en',
  'de',
  'fr',
  'es',
};

/// Prefissi di lingua riconosciuti come primo pezzo del percorso.
const languages = {'it', 'en', 'de', 'fr', 'es', 'nl', 'pt', 'ru', 'zh', 'ja'};

/// Stesse pagine, nomi diversi: tutto finisce sulla stessa parola.
const _phrases = {
  'chi-siamo': 'about',
  'about-us': 'about',
  'la-nostra-storia': 'about',
  'storia': 'about',
  'story': 'about',
  'our-story': 'about',
  'structure': 'about',
  'struttura': 'about',
  'la-struttura': 'about',
  'contattaci': 'contatti',
  'contact-us': 'contatti',
  'dove-siamo': 'contatti',
  'come-raggiungerci': 'contatti',
  'contact': 'contatti',
  'contacts': 'contatti',
  'contatto': 'contatti',
  'rooms': 'camere',
  'room': 'camera',
  'gallery': 'galleria',
  'photos': 'galleria',
  'photo': 'galleria',
  'foto': 'galleria',
  'fotogallery': 'galleria',
  'booking': 'prenota',
  'book-now': 'prenota',
  'prenotazioni': 'prenota',
  'prenotazione': 'prenota',
  'services': 'servizi',
  'service': 'servizi',
  'servizio': 'servizi',
  'news': 'blog',
  'notizie': 'blog',
  'articoli': 'blog',
  'breakfast': 'colazione',
  'privacy-policy': 'privacy',
  'informativa-privacy': 'privacy',
  'cookie-policy': 'cookie',
  'informativa-cookie': 'cookie',
  'products': 'prodotti',
  'product': 'prodotto',
  'shop': 'negozio',
  'store': 'negozio',
  'offers': 'offerte',
  'offerta': 'offerte',
  'events': 'eventi',
  'evento': 'eventi',
  'homepage': 'home',
};

String _plain(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    b.write(_accents[ch] ?? ch);
  }
  return b.toString();
}

String _canonical(String segment) {
  var s = _plain(segment).replaceAll(RegExp(r'\.(html?|php|aspx?)$'), '');
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  return _phrases[s] ?? s;
}

/// Code che non cambiano la pagina: /articolo/feed, /articolo/amp, /blog/page/2.
const _tails = {'feed', 'rss', 'amp', 'embed', 'trackback', 'comments'};

/// I pezzi del percorso, già normalizzati: "/en/Rooms/Camera-Doppia.html" → [en, camere, camera-doppia]
List<String> segmentsOf(String key) {
  final path = key.split('?').first;
  final segs = path.split('/').where((p) => p.isNotEmpty).map(_canonical).where((p) => p.isNotEmpty).toList();
  while (segs.isNotEmpty) {
    if (_tails.contains(segs.last)) {
      segs.removeLast();
    } else if (segs.length >= 2 && RegExp(r'^\d+$').hasMatch(segs.last) && segs[segs.length - 2] == 'page') {
      segs.removeRange(segs.length - 2, segs.length);
    } else {
      break;
    }
  }
  return segs;
}

List<String> _words(String segment) =>
    segment.split('-').map((w) => _phrases[w] ?? w).where((w) => w.isNotEmpty && !_stopwords.contains(w)).toList();

Set<String> _trigrams(String s) {
  final t = '  $s ';
  return {for (var i = 0; i < t.length - 2; i++) t.substring(i, i + 3)};
}

double _dice(Set<String> a, Set<String> b) {
  if (a.isEmpty && b.isEmpty) return 0;
  final inter = a.intersection(b).length;
  return 2 * inter / (a.length + b.length);
}

/// Quello che serve per confrontare una pagina.
class _Profile {
  _Profile(SiteUrl url) {
    var segs = segmentsOf(url.key);
    if (segs.isNotEmpty && languages.contains(segs.first)) {
      lang = segs.first;
      segs = segs.sublist(1);
    }
    segments = segs;
    last = segs.isEmpty ? '' : segs.last;
    lastWords = _words(last).toSet();
    allWords = segs.expand(_words).toSet();
    // Le query tipo ?page_id=12 contano come parole.
    if (url.query.isNotEmpty) {
      for (final part in url.query.split('&')) {
        allWords.addAll(_words(_canonical(part.replaceAll('=', '-'))));
      }
    }
    trigrams = _trigrams(last);
    section = segs.length > 1 ? segs.first : '';
    hasQuery = url.query.isNotEmpty;
  }

  bool hasQuery = false;

  String lang = '';
  late final List<String> segments;
  late final String last;
  late final Set<String> lastWords;
  late final Set<String> allWords;
  late final Set<String> trigrams;
  late final String section;
}

/// Somiglianza tra due pagine, da 0 a 1.
double similarity(SiteUrl a, SiteUrl b) => _score(_Profile(a), _Profile(b));

double _score(_Profile a, _Profile b) {
  if (a.segments.isEmpty && b.segments.isEmpty) {
    // "/?page_id=12" non è la home: non sappiamo cos'era.
    if (a.hasQuery != b.hasQuery) return 0;
    return a.lang == b.lang ? 1 : 0.7;
  }
  if (a.segments.isEmpty || b.segments.isEmpty) return 0;
  if (a.last == b.last && a.last.isNotEmpty) {
    var s = 0.9 + (a.section == b.section ? 0.1 : 0);
    if (a.lang != b.lang) s -= 0.3;
    return s.clamp(0, 1);
  }
  var score =
      0.6 * _dice(a.lastWords, b.lastWords) +
      0.25 * _dice(a.allWords, b.allWords) +
      0.15 * _dice(a.trigrams, b.trigrams);
  if (a.section.isNotEmpty && a.section == b.section) score += 0.08;
  if (a.lang != b.lang) score -= 0.3;
  return score.clamp(0, 1);
}

// ---------------------------------------------------------------------------
// Abbinamento
// ---------------------------------------------------------------------------

enum MatchStatus { same, sure, check, none }

/// Cosa fare con le pagine vecchie senza una corrispondenza.
enum Fallback { parentOrHome, home, skip }

class Candidate {
  const Candidate(this.url, this.score);

  final SiteUrl url;
  final double score;
}

/// Una pagina del sito vecchio e dove andrà a finire.
class MatchRow {
  MatchRow({required this.from, required this.candidates, required this.status, this.target, this.isFallback = false});

  final SiteUrl from;
  final List<Candidate> candidates;
  MatchStatus status;

  /// Destinazione scelta: un percorso o un URL. null = nessun redirect.
  String? target;

  /// La destinazione è un ripiego (sezione madre o home), non una pagina simile.
  bool isFallback;

  /// Cambiata a mano: non va ricalcolata.
  bool edited = false;

  double get score => candidates.isEmpty ? 0 : candidates.first.score;
}

class MatchOptions {
  const MatchOptions({this.sure = 0.72, this.threshold = 0.4, this.fallback = Fallback.parentOrHome});

  /// Da qui in su l'abbinamento è sicuro.
  final double sure;

  /// Sotto questa soglia la pagina non ha una corrispondenza.
  final double threshold;
  final Fallback fallback;
}

/// Abbina ogni URL vecchio alla pagina nuova più simile.
List<MatchRow> matchSites(List<SiteUrl> oldUrls, List<SiteUrl> newUrls, {MatchOptions options = const MatchOptions()}) {
  final newProfiles = [for (final n in newUrls) (url: n, profile: _Profile(n))];
  final newKeys = {for (final n in newUrls) n.key: n};
  final rows = <MatchRow>[];

  for (final old in oldUrls) {
    final same = newKeys[old.key];
    if (same != null) {
      rows.add(
        MatchRow(from: old, candidates: [Candidate(same, 1)], status: MatchStatus.same, target: same.pathWithQuery),
      );
      continue;
    }
    final p = _Profile(old);
    final scored = [for (final n in newProfiles) Candidate(n.url, _score(p, n.profile))]
      ..sort((a, b) => b.score.compareTo(a.score));
    final top = scored.take(6).where((c) => c.score > 0).toList();
    rows.add(MatchRow(from: old, candidates: top, status: MatchStatus.none));
  }
  // Prima le pagine con una corrispondenza, poi i ripieghi: così una pagina
  // senza corrispondenza può seguire la sua sezione madre dove è andata.
  for (final r in rows) {
    applyOptions(r, newUrls, options, rows: rows, fallbacks: false);
  }
  for (final r in rows) {
    applyOptions(r, newUrls, options, rows: rows);
  }
  return rows;
}

/// Ricalcola stato e destinazione con le opzioni scelte (soglia e ripiego).
/// Con [rows] il ripiego può seguire la sezione madre del sito vecchio.
void applyOptions(
  MatchRow row,
  List<SiteUrl> newUrls,
  MatchOptions options, {
  List<MatchRow> rows = const [],
  bool fallbacks = true,
}) {
  if (row.edited || row.status == MatchStatus.same) return;
  final best = row.candidates.isEmpty ? null : row.candidates.first;
  if (best != null && best.score >= options.sure) {
    row
      ..status = MatchStatus.sure
      ..target = best.url.pathWithQuery
      ..isFallback = false;
  } else if (best != null && best.score >= options.threshold) {
    row
      ..status = MatchStatus.check
      ..target = best.url.pathWithQuery
      ..isFallback = false;
  } else {
    row
      ..status = MatchStatus.none
      ..isFallback = true;
    if (fallbacks) {
      row.target = fallbackFor(row.from, newUrls, options.fallback, rows: rows, threshold: options.threshold);
    }
  }
}

/// Ripiego: la sezione madre se esiste nel sito nuovo (o se è stata abbinata),
/// altrimenti la home.
String? fallbackFor(
  SiteUrl old,
  List<SiteUrl> newUrls,
  Fallback mode, {
  List<MatchRow> rows = const [],
  double threshold = 0.4,
}) {
  switch (mode) {
    case Fallback.skip:
      return null;
    case Fallback.home:
      return '/';
    case Fallback.parentOrHome:
      final keys = {for (final n in newUrls) n.key: n};
      final matched = {
        for (final r in rows)
          if (r.target != null && r.status != MatchStatus.none) r.from.key: r.target!,
      };
      var parts = old.key.split('?').first.split('/').where((s) => s.isNotEmpty).toList();
      while (parts.length > 1) {
        parts = parts.sublist(0, parts.length - 1);
        final key = '/${parts.join('/')}';
        final hit = keys[key];
        if (hit != null) return hit.path;
        final viaOld = matched[key];
        if (viaOld != null) return viaOld;
        // La sezione madre somiglia a una pagina nuova? (/en/rooms-list → /en/rooms)
        if (parts.length > 1 || !languages.contains(parts.first)) {
          final parent = SiteUrl.parse(key);
          Candidate? best;
          for (final n in newUrls) {
            final sc = similarity(parent, n);
            if (best == null || sc > best.score) best = Candidate(n, sc);
          }
          if (best != null && best.score >= threshold) return best.url.pathWithQuery;
        }
      }
      // La home della stessa lingua, se c'è.
      final lang = parts.isNotEmpty && languages.contains(parts.first) ? parts.first : '';
      if (lang.isNotEmpty && keys.containsKey('/$lang')) return keys['/$lang']!.path;
      return '/';
  }
}

// ---------------------------------------------------------------------------
// Esportazione
// ---------------------------------------------------------------------------

enum ExportFormat { htaccess, nginx, nextjs, vercel, netlify, redirection }

extension ExportFormatX on ExportFormat {
  String get label => switch (this) {
    ExportFormat.htaccess => '.htaccess',
    ExportFormat.nginx => 'Nginx',
    ExportFormat.nextjs => 'Next.js',
    ExportFormat.vercel => 'Vercel',
    ExportFormat.netlify => 'Netlify',
    ExportFormat.redirection => 'Redirection',
  };

  String get fileName => switch (this) {
    ExportFormat.htaccess => 'trasloco.htaccess',
    ExportFormat.nginx => 'trasloco-nginx.conf',
    ExportFormat.nextjs => 'trasloco-next.config.js',
    ExportFormat.vercel => 'trasloco-vercel.json',
    ExportFormat.netlify => 'trasloco-netlify_redirects',
    ExportFormat.redirection => 'trasloco-redirection.csv',
  };
}

/// Un redirect pronto: da percorso vecchio a destinazione.
class Redirect {
  const Redirect(this.path, this.query, this.target);

  final String path;
  final String query;
  final String target;
}

/// I redirect da scrivere: niente pagine invariate, niente redirect su sé stessi.
/// Se i domini sono diversi le destinazioni diventano assolute.
List<Redirect> redirectsFrom(List<MatchRow> rows, {String newOrigin = ''}) {
  final out = <Redirect>[];
  final seen = <String>{};
  for (final r in rows) {
    final t = r.target?.trim();
    if (t == null || t.isEmpty) continue;
    if (r.status == MatchStatus.same && !r.edited) continue;
    final targetKey = SiteUrl.parse(t).key;
    if (targetKey == r.from.key) continue;
    if (!seen.add(r.from.key)) continue;
    final absolute = t.startsWith(RegExp(r'https?://')) || newOrigin.isEmpty
        ? t
        : '$newOrigin${t.startsWith('/') ? t : '/$t'}';
    out.add(Redirect(r.from.path, r.from.query, absolute));
  }
  return out;
}

String _regexEscape(String s) => s.replaceAllMapped(RegExp(r'[.^$*+?()\[\]{}|\\]'), (m) => '\\${m[0]}');

String _header(String comment, {required String oldSite, required String newSite, required int count}) {
  final date = DateTime.now().toIso8601String().substring(0, 10);
  return [
    '$comment Redirect 301 generati con Trasloco — francescoferri.me',
    if (oldSite.isNotEmpty) '$comment Sito vecchio: $oldSite',
    if (newSite.isNotEmpty) '$comment Sito nuovo: $newSite',
    '$comment $count redirect · $date',
  ].join('\n');
}

/// Scrive i redirect nel formato scelto.
String exportRedirects(
  ExportFormat format,
  List<Redirect> redirects, {
  String oldSite = '',
  String newSite = '',
  String oldHost = '',
  String newOrigin = '',
}) {
  final b = StringBuffer();
  final n = redirects.length;
  switch (format) {
    case ExportFormat.htaccess:
      b
        ..writeln(_header('#', oldSite: oldSite, newSite: newSite, count: n))
        ..writeln('# Incolla in cima al .htaccess, prima delle regole di WordPress.')
        ..writeln()
        ..writeln('<IfModule mod_rewrite.c>')
        ..writeln('RewriteEngine On');
      for (final r in redirects) {
        final rule = r.path == '/' ? '^\$' : '^${_regexEscape(r.path.substring(1).replaceAll(RegExp(r'/$'), ''))}/?\$';
        final target = r.target.contains('?') ? r.target : '${r.target}?';
        if (r.query.isNotEmpty) b.writeln('RewriteCond %{QUERY_STRING} ^${_regexEscape(r.query)}\$');
        b.writeln('RewriteRule $rule $target [R=301,L,NC]');
      }
      if (oldHost.isNotEmpty && newOrigin.isNotEmpty) {
        final host = _regexEscape(oldHost.replaceFirst(RegExp(r'^www\.'), ''));
        b
          ..writeln()
          ..writeln('# Tutto il resto passa al dominio nuovo con lo stesso percorso.')
          ..writeln('RewriteCond %{HTTP_HOST} ^(www\\.)?$host\$ [NC]')
          ..writeln('RewriteRule ^(.*)\$ $newOrigin/\$1 [R=301,L]');
      }
      b.writeln('</IfModule>');
    case ExportFormat.nginx:
      b
        ..writeln(_header('#', oldSite: oldSite, newSite: newSite, count: n))
        ..writeln('# Dentro il blocco server { } del sito.')
        ..writeln();
      for (final r in redirects) {
        if (r.query.isNotEmpty) {
          b.writeln('if (\$request_uri = "${r.path}?${r.query}") { return 301 ${r.target}; }');
        } else {
          final p = r.path == '/' ? '/' : r.path.replaceAll(RegExp(r'/$'), '');
          b.writeln(
            p == '/'
                ? 'location = / { return 301 ${r.target}; }'
                : 'rewrite ^${_regexEscape(p)}/?\$ ${r.target} permanent;',
          );
        }
      }
    case ExportFormat.nextjs:
      b
        ..writeln(_header('//', oldSite: oldSite, newSite: newSite, count: n))
        ..writeln('// In next.config.js: async redirects() { return redirects; }')
        ..writeln()
        ..writeln('const redirects = [');
      for (final r in redirects) {
        b.write("  { source: '${_nextSource(r.path).replaceAll('\\', '\\\\').replaceAll("'", "\\'")}', ");
        if (r.query.isNotEmpty) b.write('has: [${_nextHas(r.query)}], ');
        b.writeln("destination: '${r.target.replaceAll("'", "\\'")}', permanent: true },");
      }
      b
        ..writeln('];')
        ..writeln()
        ..writeln('module.exports = redirects;');
    case ExportFormat.vercel:
      final items = redirects.map((r) {
        final has = r.query.isEmpty ? '' : ', "has": [${_nextHas(r.query, json: true)}]';
        return '    { "source": "${_json(_nextSource(r.path))}"$has, "destination": "${_json(r.target)}", "permanent": true }';
      });
      b
        ..writeln('{')
        ..writeln('  "redirects": [')
        ..writeln(items.join(',\n'))
        ..writeln('  ]')
        ..writeln('}');
    case ExportFormat.netlify:
      b
        ..writeln(_header('#', oldSite: oldSite, newSite: newSite, count: n))
        ..writeln();
      for (final r in redirects) {
        final q = r.query.isEmpty ? '' : '  ${r.query.split('&').join(' ')}';
        b.writeln('${r.path}$q  ${r.target}  301');
      }
    case ExportFormat.redirection:
      // Formato del plugin Redirection di WordPress: sorgente, destinazione, regex, codice.
      for (final r in redirects) {
        b.writeln([_csv(r.query.isEmpty ? r.path : '${r.path}?${r.query}'), _csv(r.target), '0', '301'].join(','));
      }
  }
  return b.toString();
}

String _json(String s) => s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

String _csv(String v) => v.contains(RegExp('[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;

/// In Next.js e Vercel i caratteri : ( ) * + ? hanno un significato: li proteggiamo.
String _nextSource(String path) {
  final p = path.length > 1 ? path.replaceAll(RegExp(r'/$'), '') : path;
  return p.replaceAllMapped(RegExp(r'[:()*+?{}]'), (m) => '\\${m[0]}');
}

String _nextHas(String query, {bool json = false}) {
  final parts = query.split('&').where((p) => p.isNotEmpty).map((p) {
    final i = p.indexOf('=');
    final k = i < 0 ? p : p.substring(0, i);
    final v = i < 0 ? '' : p.substring(i + 1);
    return json
        ? '{ "type": "query", "key": "${_json(k)}"${v.isEmpty ? '' : ', "value": "${_json(v)}"'} }'
        : "{ type: 'query', key: '$k'${v.isEmpty ? '' : ", value: '$v'"} }";
  });
  return parts.join(', ');
}

/// Resoconto per il cliente o per l'archivio: tutte le pagine e cosa è successo.
String exportReport(List<MatchRow> rows) {
  final b = StringBuffer()..writeln('vecchio,nuovo,stato,somiglianza');
  for (final r in rows) {
    final state = switch (r.status) {
      MatchStatus.same => 'invariata',
      MatchStatus.sure => 'sicura',
      MatchStatus.check => 'da controllare',
      MatchStatus.none => r.target == null ? 'nessun redirect' : 'ripiego',
    };
    b.writeln([_csv(r.from.original), _csv(r.target ?? ''), state, '${(r.score * 100).round()}%'].join(','));
  }
  return b.toString();
}
