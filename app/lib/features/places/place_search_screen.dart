import 'package:flutter/material.dart';

import '../../data/app_error.dart';
import '../../data/geocoding_repository.dart';
import '../../models/geo.dart';

/// Recherche d'une adresse, d'un lieu ou d'une ville dans le monde entier.
/// Renvoie le [Place] choisi via `Navigator.pop`.
///
/// La recherche part sur validation (pas à chaque frappe) : règle d'usage du service
/// OpenStreetMap utilisé côté serveur.
class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({
    super.key,
    required this.geocoding,
    required this.title,
    this.hintText = 'ex. Stade Jean-Bouin, Paris',
  });

  final GeocodingRepository geocoding;
  final String title;
  final String hintText;

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final _query = TextEditingController();
  bool _busy = false;
  String? _error;
  List<Place>? _results;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.length < 3) {
      setState(() => _error = 'Saisissez au moins 3 caractères.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await widget.geocoding.search(query);
      if (mounted) setState(() => _results = results);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _query,
                autofocus: true,
                enabled: !_busy,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: 'Adresse, lieu ou ville',
                  hintText: widget.hintText,
                  errorText: _error,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Rechercher',
                    onPressed: _busy ? null : _search,
                  ),
                ),
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: results == null
                  ? const SizedBox()
                  : results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aucun résultat. Essayez avec la ville ou une adresse plus complète.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) => ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(results[i].name),
                        subtitle: Text(results[i].label),
                        onTap: () => Navigator.of(context).pop(results[i]),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Données © les contributeurs OpenStreetMap',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
