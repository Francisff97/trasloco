import 'dart:io';
import 'dart:isolate';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'brand.dart';
import 'loader.dart';
import 'matcher.dart';
import 'shell.dart';
import 'strings.dart';
import 'widgets.dart';

/// Abbina in un isolate separato. Fuori dalla classe, così l'isolate
/// riceve solo gli elenchi di URL e non lo stato dell'interfaccia.
Future<List<MatchRow>> _matchInBackground(List<SiteUrl> oldUrls, List<SiteUrl> newUrls, MatchOptions options) async {
  try {
    return await Isolate.run(() => matchSites(oldUrls, newUrls, options: options));
  } catch (_) {
    return matchSites(oldUrls, newUrls, options: options);
  }
}

/// Uno dei due siti: cosa è stato letto e da dove.
class _Side {
  final input = TextEditingController();
  LoadResult? result;
  bool loading = false;
  String status = '';
  String? error;

  List<SiteUrl> get urls => result?.urls.map(SiteUrl.parse).toList() ?? const [];

  void clear() {
    result = null;
    error = null;
    status = '';
  }
}

enum _Filter { all, check, none, sure, same }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final s = S.current;
  final _old = _Side();
  final _new = _Side();

  int _threshold = 40;
  Fallback _fallback = Fallback.parentOrHome;
  final _formats = <ExportFormat>{ExportFormat.htaccess, ExportFormat.redirection};
  bool _report = true;

  List<MatchRow>? _rows;
  _Filter _filter = _Filter.all;
  String? _exportedDir;
  int _exportedCount = 0;
  String? _copied;

  @override
  void dispose() {
    _old.input.dispose();
    _new.input.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Lettura
  // -------------------------------------------------------------------------

  String _errorText(Object e) => switch ('$e') {
    'no-sitemap' => s.errNoSitemap,
    'unreachable' => s.errUnreachable,
    'empty' => s.errEmpty,
    _ => s.errUnreachable,
  };

  Future<void> _load(_Side side, Future<LoadResult> Function() loader) async {
    setState(() {
      side.loading = true;
      side.error = null;
      side.status = '';
      _rows = null;
    });
    try {
      final r = await loader();
      if (!mounted) return;
      setState(() => side.result = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => side.error = _errorText(e));
    } finally {
      if (mounted) setState(() => side.loading = false);
    }
  }

  void _clearSide(_Side side) => setState(() {
    side.clear();
    _rows = null;
  });

  void _loadWeb(_Side side) {
    final text = side.input.text.trim();
    if (text.isEmpty) return;
    _load(side, () => loadFromWeb(text, onStatus: (st) => mounted ? setState(() => side.status = st) : null));
  }

  Future<void> _pickFile(_Side side) async {
    const group = XTypeGroup(label: 'Sitemap', extensions: ['xml', 'gz', 'txt', 'csv']);
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file != null) _load(side, () => loadFromFile(file.path));
  }

  Future<void> _paste(_Side side) async {
    final controller = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null && extractUrls(clip!.text!).isNotEmpty) controller.text = clip.text!;
    if (!mounted) return;
    final text = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => Dialog(
        backgroundColor: FD.surface,
        shape: const RoundedRectangleBorder(side: BorderSide(color: FD.line)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.pasteTitle.toUpperCase(), style: FD.displayStyle(36)),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: FD.line)),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      maxLines: null,
                      expands: true,
                      style: FD.monoStyle(size: 11.5, color: FD.text).copyWith(letterSpacing: 0.3, height: 1.6),
                      decoration: InputDecoration.collapsed(
                        hintText: s.pasteHint,
                        hintStyle: const TextStyle(fontSize: 13, color: FD.muted),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    FDButton(label: s.use, filled: true, onPressed: () => Navigator.of(context).pop(controller.text)),
                    const SizedBox(width: 12),
                    FDButton(label: s.cancel, onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (text != null && text.trim().isNotEmpty) _load(side, () async => loadFromText(text));
  }

  // -------------------------------------------------------------------------
  // Abbinamento ed esportazione
  // -------------------------------------------------------------------------

  MatchOptions get _options => MatchOptions(threshold: _threshold / 100, fallback: _fallback);

  bool get _canMatch => _old.result != null && _new.result != null && !_old.loading && !_new.loading;

  bool _matching = false;

  Future<void> _match() async {
    if (!_canMatch || _matching) return;
    setState(() => _matching = true);
    final oldUrls = _old.urls;
    final newUrls = _new.urls;
    final options = _options;
    // In un isolate a parte: con siti grandi i confronti sono tanti.
    final rows = await _matchInBackground(oldUrls, newUrls, options);
    if (!mounted) return;
    setState(() {
      _matching = false;
      _rows = rows;
      _filter = _Filter.all;
      _exportedDir = null;
    });
  }

  void _reapply() {
    final rows = _rows;
    if (rows == null) return;
    final newUrls = _new.urls;
    for (final r in rows) {
      applyOptions(r, newUrls, _options, rows: rows, fallbacks: false);
    }
    for (final r in rows) {
      applyOptions(r, newUrls, _options, rows: rows);
    }
  }

  String get _oldHost => _old.urls.firstWhere((u) => u.host.isNotEmpty, orElse: () => SiteUrl.parse('/')).host;

  String get _newOrigin {
    final n = _new.urls.firstWhere((u) => u.host.isNotEmpty, orElse: () => SiteUrl.parse('/'));
    final scheme = n.original.toLowerCase().startsWith('http://') ? 'http' : 'https';
    return n.host.isEmpty ? '' : '$scheme://${n.host}';
  }

  bool get _domainChange {
    final a = _oldHost.replaceFirst(RegExp(r'^www\.'), '');
    final b = _newOrigin.replaceFirst(RegExp(r'^https?://(www\.)?'), '');
    return a.isNotEmpty && b.isNotEmpty && a != b;
  }

  List<Redirect> get _redirects => redirectsFrom(_rows ?? const [], newOrigin: _domainChange ? _newOrigin : '');

  String _exportText(ExportFormat f) => exportRedirects(
    f,
    _redirects,
    oldSite: _old.result?.source ?? '',
    newSite: _new.result?.source ?? '',
    oldHost: _domainChange ? _oldHost : '',
    newOrigin: _domainChange ? _newOrigin : '',
  );

  Future<void> _export() async {
    final rows = _rows;
    if (rows == null) return;
    final dir = await getDirectoryPath(confirmButtonText: s.t('Salva qui', 'Save here'));
    if (dir == null) return;
    var count = 0;
    for (final f in ExportFormat.values.where(_formats.contains)) {
      await File(p.join(dir, f.fileName)).writeAsString(_exportText(f));
      count++;
    }
    if (_report) {
      await File(p.join(dir, 'trasloco-resoconto.csv')).writeAsString(exportReport(rows));
      count++;
    }
    if (!mounted) return;
    setState(() {
      _exportedDir = dir;
      _exportedCount = count;
    });
  }

  Future<void> _copy(ExportFormat f) async {
    await Clipboard.setData(ClipboardData(text: _exportText(f)));
    if (!mounted) return;
    setState(() => _copied = f.label);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = null);
    });
  }

  void _reset() => setState(() {
    _rows = null;
    _exportedDir = null;
  });

  void _mainAction() => _rows == null ? _match() : _export();

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): _mainAction,
          const SingleActivator(LogicalKeyboardKey.enter, control: true): _mainAction,
        },
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              TopBar(
                title: 'Trasloco',
                tagline: s.tagline,
                onAbout: () => showAboutApp(context, title: 'Trasloco', tagline: s.tagline, body: s.aboutBody),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: _rows == null ? _buildSources() : _buildResults(),
                      ),
                    ),
                    Container(width: 1, color: FD.lineSoft),
                    SizedBox(width: 360, child: _buildSettings()),
                  ],
                ),
              ),
              const Footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSources() {
    return Padding(
      key: const ValueKey('sources'),
      padding: const EdgeInsets.fromLTRB(48, 40, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('00 — ${s.start.toUpperCase()}', style: FD.monoStyle(size: 10, color: FD.accent)),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(s.heroTitle.toUpperCase(), style: FD.displayStyle(76)),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(s.heroHint, style: const TextStyle(fontSize: 15, height: 1.5, color: FD.muted)),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SourcePanel(number: '01', title: s.oldSite, side: _old, state: this),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _SourcePanel(number: '02', title: s.newSite, side: _new, state: this),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Iterable<MatchRow> _filtered(List<MatchRow> rows) => switch (_filter) {
    // Prima quelle da guardare: dubbie, senza corrispondenza, poi le altre.
    _Filter.all => [
      for (final st in [MatchStatus.check, MatchStatus.none, MatchStatus.sure, MatchStatus.same])
        ...rows.where((r) => r.status == st),
    ],
    _Filter.check => rows.where((r) => r.status == MatchStatus.check),
    _Filter.none => rows.where((r) => r.status == MatchStatus.none),
    _Filter.sure => rows.where((r) => r.status == MatchStatus.sure),
    _Filter.same => rows.where((r) => r.status == MatchStatus.same),
  };

  Widget _buildResults() {
    final rows = _rows!;
    int count(MatchStatus st) => rows.where((r) => r.status == st).length;
    final visible = _filtered(rows).toList();
    final newUrls = _new.urls;
    final firstFormat = ExportFormat.values.firstWhere(_formats.contains, orElse: () => ExportFormat.htaccess);

    return Column(
      key: const ValueKey('results'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 36, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('03 — ${s.t('ABBINAMENTI', 'MATCHES')}', style: FD.monoStyle(size: 10, color: FD.accent)),
                  const Spacer(),
                  FDTextLink(
                    label: _copied == null ? s.copy(firstFormat.label) : s.copied,
                    onTap: () => _copy(firstFormat),
                  ),
                  const SizedBox(width: 20),
                  FDTextLink(label: s.startOver, onTap: _reset),
                ],
              ),
              const SizedBox(height: 14),
              Text(s.pages(rows.length).toUpperCase(), style: FD.displayStyle(72)),
              const SizedBox(height: 6),
              Text(
                s.redirectsReady(_redirects.length).toUpperCase(),
                style: FD.monoStyle(size: 12, color: FD.accent, weight: FontWeight.w700),
              ),
              if (_domainChange) ...[
                const SizedBox(height: 8),
                Text(s.domainChange, style: const TextStyle(fontSize: 12.5, color: FD.muted)),
              ],
              if (_exportedDir != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(s.saved(_exportedCount).toUpperCase(), style: FD.monoStyle(size: 11, color: FD.text)),
                    const SizedBox(width: 16),
                    FDTextLink(label: s.openFolder, arrow: true, onTap: () => launchUrl(Uri.directory(_exportedDir!))),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FDChip(
                    label: '${s.all} ${rows.length}',
                    selected: _filter == _Filter.all,
                    onTap: () => setState(() => _filter = _Filter.all),
                  ),
                  FDChip(
                    label: '${s.statusCheck} ${count(MatchStatus.check)}',
                    selected: _filter == _Filter.check,
                    onTap: () => setState(() => _filter = _Filter.check),
                  ),
                  FDChip(
                    label: '${s.statusNone} ${count(MatchStatus.none)}',
                    selected: _filter == _Filter.none,
                    onTap: () => setState(() => _filter = _Filter.none),
                  ),
                  FDChip(
                    label: '${s.statusSure} ${count(MatchStatus.sure)}',
                    selected: _filter == _Filter.sure,
                    onTap: () => setState(() => _filter = _Filter.sure),
                  ),
                  FDChip(
                    label: '${s.statusSame} ${count(MatchStatus.same)}',
                    selected: _filter == _Filter.same,
                    onTap: () => setState(() => _filter = _Filter.same),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        Container(height: 1, color: FD.lineSoft),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(48, 0, 28, 24),
            itemCount: visible.length,
            itemBuilder: (context, i) => _MatchTile(
              key: ValueKey(visible[i].from.original),
              row: visible[i],
              newUrls: newUrls,
              onChanged: () => setState(() {}),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettings() {
    final hasRows = _rows != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
            children: [
              Text(s.settings.toUpperCase(), style: FD.displayStyle(28)),
              const SizedBox(height: 28),
              SectionLabel('01', s.threshold),
              Row(
                children: [
                  Text(s.threshold.toUpperCase(), style: FD.monoStyle(size: 10)),
                  const Spacer(),
                  Text(
                    '$_threshold%',
                    style: FD.monoStyle(size: 12, color: FD.text, weight: FontWeight.w700),
                  ),
                ],
              ),
              Slider(
                value: _threshold.toDouble(),
                min: 20,
                max: 70,
                divisions: 50,
                onChanged: (v) => setState(() {
                  _threshold = v.round();
                  _reapply();
                }),
              ),
              Text(s.thresholdHelp, style: const TextStyle(fontSize: 12, height: 1.4, color: FD.muted)),
              const SizedBox(height: 32),
              SectionLabel('02', s.noMatch),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in Fallback.values)
                    FDChip(
                      label: switch (f) {
                        Fallback.parentOrHome => s.fallbackParent,
                        Fallback.home => s.fallbackHome,
                        Fallback.skip => s.fallbackSkip,
                      },
                      selected: _fallback == f,
                      onTap: () => setState(() {
                        _fallback = f;
                        _reapply();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(s.fallbackHelp, style: const TextStyle(fontSize: 12, height: 1.4, color: FD.muted)),
              const SizedBox(height: 32),
              SectionLabel('03', s.formats),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in ExportFormat.values)
                    FDChip(
                      label: f.label,
                      selected: _formats.contains(f),
                      onTap: () => setState(() => _formats.contains(f) ? _formats.remove(f) : _formats.add(f)),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              SectionLabel('04', s.extras),
              FDToggle(label: s.report, value: _report, onChanged: (v) => setState(() => _report = v)),
              FDToggle(label: s.sameSkipped, value: true, onChanged: null),
            ],
          ),
        ),
        Container(height: 1, color: FD.lineSoft),
        Padding(
          padding: const EdgeInsets.all(20),
          child: FDButton(
            label: hasRows ? s.export : (_matching ? s.matching : (_canMatch ? s.match : s.loadBothFirst)),
            big: true,
            filled: true,
            icon: hasRows ? Icons.download : Icons.arrow_forward,
            onPressed: hasRows
                ? (_formats.isEmpty && !_report ? null : _export)
                : (_canMatch && !_matching ? _match : null),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _SourcePanel extends StatefulWidget {
  const _SourcePanel({required this.number, required this.title, required this.side, required this.state});

  final String number;
  final String title;
  final _Side side;
  final _HomePageState state;

  @override
  State<_SourcePanel> createState() => _SourcePanelState();
}

class _SourcePanelState extends State<_SourcePanel> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final side = widget.side;
    final home = widget.state;
    final result = side.result;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (d) {
        setState(() => _dragging = false);
        if (d.files.isNotEmpty) home._load(side, () => loadFromFile(d.files.first.path));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _dragging ? FD.accent.withValues(alpha: 0.06) : Colors.transparent,
          border: Border.all(color: _dragging ? FD.accent : FD.line, width: _dragging ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(widget.number, widget.title),
            Row(
              children: [
                Expanded(
                  child: FDField(
                    controller: side.input,
                    hint: s.urlHint,
                    enabled: !side.loading,
                    onSubmitted: (_) => home._loadWeb(side),
                  ),
                ),
                const SizedBox(width: 12),
                FDButton(label: s.read, onPressed: side.loading ? null : () => home._loadWeb(side)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                FDTextLink(label: '+ ${s.chooseFile}', onTap: () => home._pickFile(side)),
                const SizedBox(width: 18),
                FDTextLink(label: s.paste, onTap: () => home._paste(side)),
                const Spacer(),
                if (result != null) FDTextLink(label: s.clear, onTap: () => home._clearSide(side)),
              ],
            ),
            const SizedBox(height: 20),
            Container(height: 1, color: FD.lineSoft),
            const SizedBox(height: 18),
            Expanded(child: _body(s, side, result)),
          ],
        ),
      ),
    );
  }

  Widget _body(S s, _Side side, LoadResult? result) {
    if (side.loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LinearProgressIndicator(minHeight: 1, backgroundColor: FD.lineSoft, color: FD.accent),
          const SizedBox(height: 14),
          Text(s.reading(side.status).toUpperCase(), style: FD.monoStyle(size: 10, color: FD.accent)),
        ],
      );
    }
    if (side.error != null) {
      return Text(side.error!, style: const TextStyle(fontSize: 13, height: 1.5, color: FD.danger));
    }
    if (result == null) {
      return Text(
        _dragging ? s.dropActive : s.dropHere,
        style: TextStyle(fontSize: 13, height: 1.5, color: _dragging ? FD.accent : FD.muted),
      );
    }
    final urls = result.urls;
    const shown = 40;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.urls(urls.length).toUpperCase(), style: FD.displayStyle(40)),
        const SizedBox(height: 6),
        Text(
          [result.source, if (result.sitemaps > 1) s.sitemaps(result.sitemaps)].join(' · ').toUpperCase(),
          style: FD.monoStyle(size: 10),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0, 0.8, 1],
            ).createShader(r),
            blendMode: BlendMode.dstIn,
            child: ListView(
              children: [
                for (final u in urls.take(shown))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      SiteUrl.parse(u).pathWithQuery,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FD.monoStyle(size: 10.5, color: FD.text).copyWith(letterSpacing: 0.3),
                    ),
                  ),
                if (urls.length > shown)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(s.andMore(urls.length - shown), style: FD.monoStyle(size: 10)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MatchTile extends StatefulWidget {
  const _MatchTile({super.key, required this.row, required this.newUrls, required this.onChanged});

  final MatchRow row;
  final List<SiteUrl> newUrls;
  final VoidCallback onChanged;

  @override
  State<_MatchTile> createState() => _MatchTileState();
}

class _MatchTileState extends State<_MatchTile> {
  late final _controller = TextEditingController(text: widget.row.target ?? '');

  @override
  void didUpdateWidget(covariant _MatchTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final t = widget.row.target ?? '';
    if (!widget.row.edited && _controller.text != t) _controller.text = t;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _set(String? value) {
    final row = widget.row;
    row
      ..target = (value == null || value.trim().isEmpty) ? null : value.trim()
      ..edited = true
      ..isFallback = false;
    if (row.status != MatchStatus.same) row.status = MatchStatus.sure;
    _controller.text = row.target ?? '';
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final row = widget.row;
    final (label, color) = switch (row.status) {
      MatchStatus.same => (s.statusSame, FD.muted),
      MatchStatus.sure => (s.statusSure, FD.accent),
      MatchStatus.check => (s.statusCheck, const Color(0xFFF5B547)),
      MatchStatus.none => (s.statusNone, FD.danger),
    };
    final hint = row.target == null ? s.noRedirect : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FD.lineSoft)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 128,
            child: Row(
              children: [
                Container(width: 6, height: 6, color: color),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: FD.monoStyle(size: 9.5, color: color, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: Tooltip(
              message: row.from.original,
              child: Text(
                row.from.pathWithQuery,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FD.monoStyle(size: 11, color: FD.text).copyWith(letterSpacing: 0.3),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Icon(Icons.arrow_forward, size: 13, color: FD.muted),
          ),
          Expanded(
            flex: 5,
            child: TextField(
              controller: _controller,
              enabled: row.status != MatchStatus.same || row.edited,
              style: FD.monoStyle(size: 11, color: row.isFallback ? FD.muted : FD.text).copyWith(letterSpacing: 0.3),
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                hintStyle: FD.monoStyle(size: 10.5, color: FD.muted.withValues(alpha: 0.6)),
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                border: InputBorder.none,
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: FD.accent)),
                suffixText: row.isFallback && row.target != null ? s.fallbackLabel.toUpperCase() : null,
                suffixStyle: FD.monoStyle(size: 9, color: FD.muted),
              ),
              onSubmitted: _set,
              onTapOutside: (_) {
                if ((_controller.text.trim().isEmpty ? null : _controller.text.trim()) != row.target) {
                  _set(_controller.text);
                }
              },
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              row.status == MatchStatus.same ? '' : '${(row.score * 100).round()}%',
              textAlign: TextAlign.right,
              style: FD.monoStyle(size: 10.5, color: FD.muted),
            ),
          ),
          SizedBox(
            width: 36,
            child: PopupMenuButton<String?>(
              tooltip: s.candidates,
              color: FD.surfaceHigh,
              shape: const RoundedRectangleBorder(side: BorderSide(color: FD.line)),
              onSelected: _set,
              itemBuilder: (_) => [
                for (final c in row.candidates)
                  PopupMenuItem<String?>(
                    value: c.url.pathWithQuery,
                    child: Row(
                      children: [
                        SizedBox(width: 44, child: Text('${(c.score * 100).round()}%', style: FD.monoStyle(size: 10))),
                        Text(
                          c.url.pathWithQuery,
                          style: FD.monoStyle(size: 11, color: FD.text).copyWith(letterSpacing: 0.3),
                        ),
                      ],
                    ),
                  ),
                PopupMenuItem<String?>(
                  value: '/',
                  child: Text('/  (home)', style: FD.monoStyle(size: 11, color: FD.text)),
                ),
                PopupMenuItem<String?>(
                  value: '',
                  child: Text(s.noRedirect.toUpperCase(), style: FD.monoStyle(size: 10, color: FD.danger)),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.unfold_more, size: 15, color: FD.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
