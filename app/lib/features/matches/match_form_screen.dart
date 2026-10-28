import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_error.dart';
import '../../data/match_repository.dart';
import '../../models/match.dart';
import '../../ui/formatters.dart';

/// Création (initial == null) ou modification d'un match.
/// En cas de succès, renvoie l'id du match via `Navigator.pop`.
class MatchFormScreen extends StatefulWidget {
  const MatchFormScreen({
    super.key,
    required this.matches,
    this.initial,
    this.now,
  });

  final MatchRepository matches;
  final Match? initial;

  /// Horloge injectable pour les tests.
  final DateTime Function()? now;

  @override
  State<MatchFormScreen> createState() => _MatchFormScreenState();
}

class _MatchFormScreenState extends State<MatchFormScreen> {
  static const _durations = [60, 75, 90, 105, 120, 150, 180];
  static const minStartDelay = Duration(minutes: 15);

  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );
  late final _capacity = TextEditingController(
    text:
        '${widget.initial?.capacity ?? MatchFormat.fiveASide.suggestedCapacity}',
  );
  late final _locationName = TextEditingController(
    text: widget.initial?.locationName,
  );
  late final _latitude = TextEditingController(
    text: widget.initial?.latitude?.toString(),
  );
  late final _longitude = TextEditingController(
    text: widget.initial?.longitude?.toString(),
  );
  late final _totalCost = TextEditingController(
    text: _costText(widget.initial?.estimatedTotalCost),
  );
  late final _costPerPlayer = TextEditingController(
    text: _costText(widget.initial?.estimatedCostPerPlayer),
  );

  late DateTime? _startsAt = widget.initial?.startsAt;
  late int _duration = widget.initial?.durationMinutes ?? 90;
  late MatchFormat _format = widget.initial?.format ?? MatchFormat.fiveASide;
  late SkillLevel _skill = widget.initial?.skillLevel ?? SkillLevel.all;
  late LocationMode _locationMode =
      widget.initial?.locationMode ?? LocationMode.toDefine;
  late bool _capacityEdited = widget.initial != null;

  bool _busy = false;
  String? _error;
  String? _startError;

  bool get _isEdit => widget.initial != null;
  DateTime _now() => widget.now?.call() ?? DateTime.now();

  static String _costText(double? cost) =>
      cost == null ? '' : cost.toStringAsFixed(2).replaceAll('.', ',');

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _capacity,
      _locationName,
      _latitude,
      _longitude,
      _totalCost,
      _costPerPlayer,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = _now();
    final initial = _startsAt ?? now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt ?? DateTime(0, 1, 1, 18)),
    );
    if (time == null) return;
    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _startError = null;
    });
  }

  void _selectFormat(MatchFormat format) {
    setState(() {
      _format = format;
      if (!_capacityEdited) _capacity.text = '${format.suggestedCapacity}';
    });
  }

  static double? _parseDecimal(String text) {
    final value = text.trim().replaceAll(',', '.');
    return value.isEmpty ? null : double.tryParse(value);
  }

  String? _validateStart() {
    if (_startsAt == null) return 'Choisissez la date et l\'heure du match.';
    final unchanged = _isEdit && _startsAt == widget.initial!.startsAt;
    if (!unchanged && _startsAt!.isBefore(_now().add(minStartDelay))) {
      return 'Le match doit commencer dans au moins 15 minutes.';
    }
    return null;
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState!.validate();
    setState(() => _startError = _validateStart());
    if (!formValid || _startError != null) return;

    final input = MatchInput(
      title: _title.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      startsAt: _startsAt!,
      durationMinutes: _duration,
      capacity: int.parse(_capacity.text.trim()),
      format: _format,
      skillLevel: _skill,
      locationMode: _locationMode,
      locationName: _locationName.text.trim().isEmpty
          ? null
          : _locationName.text.trim(),
      latitude: _parseDecimal(_latitude.text),
      longitude: _parseDecimal(_longitude.text),
      estimatedTotalCost: _parseDecimal(_totalCost.text),
      estimatedCostPerPlayer: _parseDecimal(_costPerPlayer.text),
    );

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = _isEdit
          ? await widget.matches
                .updateMatch(widget.initial!.id, input)
                .then((_) => widget.initial!.id)
          : await widget.matches.createMatch(input);
      if (mounted) Navigator.of(context).pop(id);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decimal = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))];
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier le match' : 'Nouveau match'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Titre'),
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v?.trim().length ?? 0) < 3
                    ? 'Au moins 3 caractères.'
                    : null,
              ),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Description (facultatif)',
                ),
                maxLength: 1000,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(
                  _startsAt == null
                      ? 'Date et heure de début'
                      : formatMatchDate(_startsAt!),
                ),
                subtitle: _startError == null
                    ? null
                    : Text(
                        _startError!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                trailing: const Icon(Icons.edit_calendar),
                onTap: _busy ? null : _pickStart,
              ),
              DropdownButtonFormField<int>(
                initialValue: _duration,
                decoration: const InputDecoration(labelText: 'Durée'),
                items: [
                  for (final d in {..._durations, _duration}.toList()..sort())
                    DropdownMenuItem(value: d, child: Text(formatDuration(d))),
                ],
                onChanged: _busy ? null : (v) => setState(() => _duration = v!),
              ),
              const SizedBox(height: 16),
              Text('Format', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<MatchFormat>(
                segments: [
                  for (final f in MatchFormat.values)
                    ButtonSegment(
                      value: f,
                      label: Text(f.code),
                      tooltip: f.label,
                    ),
                ],
                selected: {_format},
                onSelectionChanged: _busy
                    ? null
                    : (s) => _selectFormat(s.single),
              ),
              TextFormField(
                controller: _capacity,
                decoration: const InputDecoration(
                  labelText: 'Nombre total de joueurs',
                  helperText: 'Vous compris. Minimum 4.',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => _capacityEdited = true,
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 4) return 'Minimum 4 joueurs.';
                  if (n > 50) return 'Maximum 50 joueurs.';
                  if (_isEdit && n < widget.initial!.participantCount) {
                    return '${widget.initial!.participantCount} personnes sont déjà inscrites.';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<SkillLevel>(
                initialValue: _skill,
                decoration: const InputDecoration(labelText: 'Niveau'),
                items: [
                  for (final l in SkillLevel.values)
                    DropdownMenuItem(value: l, child: Text(l.label)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _skill = v!),
              ),
              const SizedBox(height: 16),
              Text('Lieu', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<LocationMode>(
                segments: const [
                  ButtonSegment(
                    value: LocationMode.toDefine,
                    label: Text('À définir ensemble'),
                  ),
                  ButtonSegment(
                    value: LocationMode.fixed,
                    label: Text('Terrain précis'),
                  ),
                ],
                selected: {_locationMode},
                onSelectionChanged: _busy
                    ? null
                    : (s) => setState(() => _locationMode = s.single),
              ),
              TextFormField(
                controller: _locationName,
                decoration: InputDecoration(
                  labelText: _locationMode == LocationMode.fixed
                      ? 'Nom du terrain'
                      : 'Secteur approximatif (facultatif)',
                  hintText: _locationMode == LocationMode.fixed
                      ? 'ex. City stade des Rives'
                      : 'ex. Centre-ville',
                ),
                maxLength: 120,
                validator: (v) {
                  final length = v?.trim().length ?? 0;
                  if (_locationMode == LocationMode.fixed && length == 0) {
                    return 'Indiquez le nom du terrain.';
                  }
                  if (length == 1) return 'Au moins 2 caractères.';
                  return null;
                },
              ),
              if (_locationMode == LocationMode.fixed) ...[
                // Provisoire : remplacé par la recherche d'adresse / la carte (étape 4).
                Text(
                  'Position GPS du terrain (saisie provisoire)',
                  style: theme.textTheme.bodySmall,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitude,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        inputFormatters: decimal,
                        validator: (v) => _validateCoordinate(v, 90),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _longitude,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        inputFormatters: decimal,
                        validator: (v) => _validateCoordinate(v, 180),
                      ),
                    ),
                  ],
                ),
              ] else
                Text(
                  'Le match sera affiché « Lieu à confirmer », sans position sur la carte.',
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: 16),
              Text(
                'Coût estimé (facultatif, aucun paiement dans l\'application)',
                style: theme.textTheme.labelLarge,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _totalCost,
                      decoration: const InputDecoration(
                        labelText: 'Total terrain (€)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: decimal,
                      validator: _validateCost,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costPerPlayer,
                      decoration: const InputDecoration(
                        labelText: 'Par joueur (€)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: decimal,
                      validator: _validateCost,
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                  semanticsLabel: 'Erreur : $_error',
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_isEdit ? 'Enregistrer' : 'Créer le match'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateCoordinate(String? value, double limit) {
    final n = _parseDecimal(value ?? '');
    if (n == null) return 'Obligatoire.';
    if (n.abs() > limit) return 'Invalide.';
    return null;
  }

  String? _validateCost(String? value) {
    if ((value ?? '').trim().isEmpty) return null;
    final n = _parseDecimal(value!);
    if (n == null || n < 0) return 'Montant invalide.';
    return null;
  }
}
