import 'package:flutter/material.dart';

import '../../data/app_error.dart';
import '../../data/geocoding_repository.dart';
import '../../data/location_service.dart';
import '../../data/match_repository.dart';
import '../../models/geo.dart';
import '../../models/match.dart';
import '../places/place_search_screen.dart';
import 'match_list_screen.dart';

enum _Period {
  all('Toutes les dates', null),
  week('7 prochains jours', Duration(days: 7)),
  month('30 prochains jours', Duration(days: 30));

  const _Period(this.label, this.span);

  final String label;
  final Duration? span;
}

/// Matchs autour d'un point (position du téléphone ou lieu recherché),
/// filtrés par distance au terrain. Le point n'est conservé qu'en mémoire.
class NearbyMatchesView extends StatefulWidget {
  const NearbyMatchesView({
    super.key,
    required this.matches,
    required this.geocoding,
    required this.location,
    required this.refreshToken,
    required this.onTap,
  });

  final MatchRepository matches;
  final GeocodingRepository geocoding;
  final LocationService location;

  /// Une nouvelle valeur relance la recherche en cours.
  final int refreshToken;
  final ValueChanged<String> onTap;

  @override
  State<NearbyMatchesView> createState() => _NearbyMatchesViewState();
}

class _NearbyMatchesViewState extends State<NearbyMatchesView>
    with AutomaticKeepAliveClientMixin {
  GeoPoint? _center;
  String? _centerLabel;
  int _radiusKm = MatchSearch.defaultRadiusKm;
  bool _availableOnly = false;
  SkillLevel? _skill;
  _Period _period = _Period.all;

  List<Match> _results = const [];
  MatchSearch? _lastPage;
  bool _hasMore = false;
  bool _loading = false;
  bool _locating = false;
  String? _error;
  bool _offline = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(NearbyMatchesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken && _center != null) {
      _search();
    }
  }

  MatchSearch _criteria() => MatchSearch(
    center: _center!,
    radiusKm: _radiusKm,
    availableOnly: _availableOnly,
    skillLevel: _skill,
    startsBefore: _period.span == null
        ? null
        : DateTime.now().add(_period.span!),
  );

  Future<void> _search({bool nextPage = false}) async {
    final search = nextPage ? _lastPage!.nextPage() : _criteria();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.matches.searchMatches(search);
      if (!mounted) return;
      setState(() {
        _results = nextPage ? [..._results, ...page] : page;
        _lastPage = search;
        _hasMore = page.length == search.limit;
      });
    } on AppError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _offline = e.isOffline;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useMyPosition() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final point = await widget.location.currentPosition();
      if (!mounted) return;
      _center = point;
      _centerLabel = 'Autour de ma position';
      await _search();
    } on AppError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _offline = e.isOffline;
        });
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _choosePlace() async {
    final place = await Navigator.of(context).push<Place>(
      MaterialPageRoute(
        builder: (_) => PlaceSearchScreen(
          geocoding: widget.geocoding,
          title: 'Rechercher autour de…',
          hintText: 'ex. Lyon, Casablanca, Montréal',
        ),
      ),
    );
    if (place == null || !mounted) return;
    _center = place.point;
    _centerLabel = 'Autour de ${place.name}';
    await _search();
  }

  void _setFilter(VoidCallback change) {
    setState(change);
    if (_center != null) _search();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final busy = _loading || _locating;

    final header = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(
          _centerLabel ?? 'Où voulez-vous jouer ?',
          style: theme.textTheme.titleMedium,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: busy ? null : _useMyPosition,
              icon: const Icon(Icons.my_location),
              label: const Text('Autour de moi'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : _choosePlace,
              icon: const Icon(Icons.search),
              label: const Text('Choisir une ville ou une adresse'),
            ),
          ],
        ),
      ),
      if (_center != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _FilterMenu<int>(
                label: 'Rayon $_radiusKm km',
                value: _radiusKm,
                enabled: !busy,
                options: [
                  for (final km in MatchSearch.radiusChoicesKm)
                    (km, 'Rayon $km km'),
                ],
                onSelected: (v) => _setFilter(() => _radiusKm = v),
              ),
              _FilterMenu<_Period>(
                label: _period.label,
                value: _period,
                enabled: !busy,
                options: [for (final p in _Period.values) (p, p.label)],
                onSelected: (v) => _setFilter(() => _period = v),
              ),
              // « Tous niveaux » dans le menu = aucun filtre de niveau.
              _FilterMenu<SkillLevel>(
                label: _skill?.label ?? 'Tous les niveaux',
                value: _skill ?? SkillLevel.all,
                enabled: !busy,
                options: [
                  for (final l in SkillLevel.values)
                    (l, l == SkillLevel.all ? 'Tous les niveaux' : l.label),
                ],
                onSelected: (v) =>
                    _setFilter(() => _skill = v == SkillLevel.all ? null : v),
              ),
              FilterChip(
                label: const Text('Places disponibles'),
                selected: _availableOnly,
                onSelected: busy
                    ? null
                    : (v) => _setFilter(() => _availableOnly = v),
              ),
            ],
          ),
        ),
      if (busy)
        const LinearProgressIndicator(semanticsLabel: 'Recherche en cours'),
      if (_error != null)
        // Annoncé immédiatement par les lecteurs d'écran.
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    _offline ? Icons.cloud_off : Icons.error_outline,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 8),
    ];

    final (IconData, String)? empty = _center == null
        ? (
            Icons.travel_explore,
            'Utilisez votre position ou choisissez une ville pour voir les matchs proches.',
          )
        : !_loading && _error == null && _results.isEmpty
        ? (
            Icons.sports_soccer,
            'Aucun match dans un rayon de $_radiusKm km.\n'
                'Élargissez le rayon ou créez le premier !',
          )
        : null;

    return RefreshIndicator(
      onRefresh: () async {
        if (_center != null) await _search();
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          ...header,
          if (empty != null)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      empty.$1,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(empty.$2, textAlign: TextAlign.center),
                ],
              ),
            ),
          for (final match in _results)
            MatchTile(
              match: match,
              onTap: widget.onTap,
              distanceKm: _center!.distanceKmTo(match.location),
            ),
          if (_hasMore && !_loading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: () => _search(nextPage: true),
                child: const Text('Afficher plus de matchs'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Filtre compact affichant sa valeur ; ouvre un menu de choix.
/// Le libellé passe à la ligne si le texte du téléphone est très agrandi.
class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
    required this.enabled,
  });

  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<T>(
      enabled: enabled,
      initialValue: value,
      tooltip: 'Modifier le filtre',
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final (option, text) in options)
          CheckedPopupMenuItem(
            value: option,
            checked: option == value,
            child: Text(text),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label)),
            const ExcludeSemantics(child: Icon(Icons.arrow_drop_down)),
          ],
        ),
      ),
    );
  }
}
