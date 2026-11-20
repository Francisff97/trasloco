import 'dart:ui';

/// Testi dell'app. Italiano di default, inglese se il sistema è in un'altra lingua.
class S {
  S._(this.it);

  final bool it;

  static final S current = S._(
    PlatformDispatcher.instance.locale.languageCode == 'it' || PlatformDispatcher.instance.locale.languageCode.isEmpty,
  );

  String t(String itText, String enText) => it ? itText : enText;

  String get tagline => t('I redirect 301 per il sito nuovo', '301 redirects for the new site');
  String get start => t('Inizia', 'Start');
  String get heroTitle => t('Due sitemap,\nzero 404', 'Two sitemaps,\nzero 404s');
  String get heroHint => t(
    'Leggo le pagine del sito vecchio e di quello nuovo, le abbino per somiglianza e ti preparo i redirect. '
        'Tu controlli solo quelle dubbie.',
    'I read the pages of the old and the new site, match them by similarity and write the redirects. '
        'You only check the doubtful ones.',
  );

  String get oldSite => t('Sito vecchio', 'Old site');
  String get newSite => t('Sito nuovo', 'New site');
  String get urlHint => t('sito.it o indirizzo della sitemap', 'site.com or sitemap address');
  String get read => t('Leggi', 'Read');
  String get chooseFile => t('Scegli file', 'Choose file');
  String get paste => t('Incolla elenco', 'Paste list');
  String get clear => t('Svuota', 'Clear');
  String get dropHere => t(
    'Oppure trascina qui la sitemap .xml, un .txt con un URL per riga o il CSV di Screaming Frog.',
    'Or drop the .xml sitemap, a .txt with one URL per line or a Screaming Frog CSV.',
  );
  String get dropActive => t('Lascia pure', 'Drop it');
  String reading(String what) => t('Leggo $what…', 'Reading $what…');
  String urls(int n) => n == 1 ? t('1 pagina', '1 page') : t('$n pagine', '$n pages');
  String sitemaps(int n) => n == 1 ? t('1 sitemap', '1 sitemap') : t('$n sitemap', '$n sitemaps');
  String andMore(int n) => t('e altre $n', 'and $n more');
  String get errNoSitemap => t(
    'Non trovo la sitemap. Scrivi l\'indirizzo esatto, es. sito.it/sitemap.xml.',
    'Sitemap not found. Type its exact address, e.g. site.com/sitemap.xml.',
  );
  String get errUnreachable =>
      t('Il sito non risponde o la sitemap non esiste.', 'The site does not respond or the sitemap does not exist.');
  String get errEmpty => t('Qui dentro non trovo URL.', 'No URLs found in here.');
  String get pasteTitle => t('Incolla gli URL', 'Paste the URLs');
  String get pasteHint => t('Un URL o un percorso per riga', 'One URL or path per line');
  String get use => t('Usa questi', 'Use these');
  String get cancel => t('Annulla', 'Cancel');

  String get settings => t('Impostazioni', 'Settings');
  String get threshold => t('Somiglianza minima', 'Minimum similarity');
  String get thresholdHelp => t(
    'Sotto questa soglia una pagina non ha una corrispondenza e passa al ripiego.',
    'Below this threshold a page has no match and goes to the fallback.',
  );
  String get noMatch => t('Pagine senza corrispondenza', 'Pages without a match');
  String get fallbackParent => t('Sezione o home', 'Section or home');
  String get fallbackHome => t('Home', 'Home');
  String get fallbackSkip => t('Nessun redirect', 'No redirect');
  String get fallbackHelp => t(
    'Sezione: /blog/articolo-vecchio va su /blog se esiste ancora, altrimenti in home.',
    'Section: /blog/old-post goes to /blog if it still exists, otherwise home.',
  );
  String get formats => t('Formati', 'Formats');
  String get extras => t('Extra', 'Extras');
  String get report => t('Resoconto CSV di tutte le pagine', 'CSV report of every page');
  String get sameSkipped => t('Le pagine invariate non servono', 'Unchanged pages are skipped');

  String get match => t('Abbina le pagine', 'Match the pages');
  String get matching => t('Abbino…', 'Matching…');
  String get loadBothFirst => t('Prima leggi i due siti', 'Load both sites first');
  String get export => t('Esporta i redirect', 'Export redirects');

  String pages(int n) => n == 1 ? t('1 pagina', '1 page') : t('$n pagine', '$n pages');
  String get all => t('Tutte', 'All');
  String get statusSame => t('Invariata', 'Unchanged');
  String get statusSure => t('Sicura', 'Sure');
  String get statusCheck => t('Da controllare', 'To check');
  String get statusNone => t('Senza', 'None');
  String get fallbackLabel => t('ripiego', 'fallback');
  String get noRedirect => t('nessun redirect', 'no redirect');
  String get candidates => t('Altre pagine simili', 'Other similar pages');
  String get startOver => t('Nuovo trasloco', 'New move');
  String copy(String what) => t('Copia $what', 'Copy $what');
  String get copied => t('Copiato', 'Copied');
  String redirectsReady(int n) =>
      n == 1 ? t('1 redirect pronto', '1 redirect ready') : t('$n redirect pronti', '$n redirects ready');
  String saved(int n) => n == 1 ? t('1 file salvato', '1 file saved') : t('$n file salvati', '$n files saved');
  String get openFolder => t('Apri cartella', 'Open folder');
  String get domainChange => t(
    'I domini sono diversi: aggiungo la regola che porta tutto il resto sul dominio nuovo.',
    'The domains differ: a catch-all rule sends everything else to the new domain.',
  );

  String get madeBy => t('Fatta da Francesco Ferri', 'Made by Francesco Ferri');
  String get madeBySub => t('Designer e sviluppatore web', 'Web designer & developer');
  String get free => t(
    'Gratis. Nessun account. Le sitemap le legge il tuo computer, senza passare da altri server.',
    'Free. No account. Your computer reads the sitemaps directly, no third-party servers.',
  );
  String get about => t('Info', 'About');
  String get aboutBody => t(
    'Trasloco legge le sitemap del sito vecchio e di quello nuovo, abbina le pagine per somiglianza '
        '(anche tra italiano e inglese, anche con ?page_id) e scrive i redirect 301 per .htaccess, Nginx, '
        'Next.js, Vercel, Netlify e il plugin Redirection di WordPress.',
    'Trasloco reads the sitemaps of the old and the new site, matches pages by similarity '
        '(even across Italian and English, even with ?page_id) and writes 301 redirects for .htaccess, Nginx, '
        'Next.js, Vercel, Netlify and the WordPress Redirection plugin.',
  );
  String get close => t('Chiudi', 'Close');
  String get writeMe => t('Scrivimi', 'Write to me');
}
