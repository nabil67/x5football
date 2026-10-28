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
      if (mounted) setState(() => _error = e.message);
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
      if (mounted) setState(() => _error = e.message);
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
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<int>(
                value: _radiusKm,
                items: [
                  for (final km in MatchSearch.radiusChoicesKm)
                    DropdownMenuItem(value: km, child: Text('Rayon $km km')),
                ],
                onChanged: busy
                    ? null
                    : (v) => _setFilter(() => _radiusKm = v!),
              ),
              DropdownButton<_Period>(
                value: _period,
                items: [
                  for (final p in _Period.values)
                    DropdownMenuItem(value: p, child: Text(p.label)),
                ],
                onChanged: busy ? null : (v) => _setFilter(() => _period = v!),
              ),
              DropdownButton<SkillLevel?>(
                value: _skill,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Tous les niveaux'),
                  ),
                  for (final l in SkillLevel.values.where(
                    (l) => l != SkillLevel.all,
                  ))
                    DropdownMenuItem(value: l, child: Text(l.label)),
                ],
                onChanged: busy ? null : (v) => _setFilter(() => _skill = v),
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
      if (busy) const LinearProgressIndicator(),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: TextStyle(color: theme.colorScheme.error),
            semanticsLabel: 'Erreur : $_error',
          ),
        ),
      const Divider(height: 1),
    ];

    final Widget? emptyMessage = _center == null
        ? const Text(
            'Utilisez votre position ou choisissez une ville pour voir les matchs proches.',
            textAlign: TextAlign.center,
          )
        : !_loading && _error == null && _results.isEmpty
        ? Text(
            'Aucun match dans un rayon de $_radiusKm km.\n'
            'Élargissez le rayon ou créez le premier !',
            textAlign: TextAlign.center,
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
          if (emptyMessage != null)
            Padding(padding: const EdgeInsets.all(32), child: emptyMessage),
          for (final match in _results) ...[
            MatchTile(
              match: match,
              onTap: widget.onTap,
              distanceKm: _center!.distanceKmTo(match.location),
            ),
            const Divider(height: 1),
          ],
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
