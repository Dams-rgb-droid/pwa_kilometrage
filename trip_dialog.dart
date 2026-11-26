import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/trip.dart';
import '../services/odometer_ocr.dart';
import '../utils/format.dart';
import 'app_icon.dart';

enum TripDialogMode { start, finish, edit }

class TripDialogResult {
  const TripDialogResult({
    required this.startKm,
    required this.date,
    required this.category,
    this.endKm,
    this.delete = false,
  });

  /// Résultat « suppression » (après confirmation).
  TripDialogResult.deletion(Trip trip)
    : startKm = trip.startKm,
      date = trip.date,
      category = trip.category,
      endKm = trip.endKm,
      delete = true;

  final double startKm;
  final double? endKm;
  final DateTime date;
  final TripCategory category;
  final bool delete;
}

/// Dialogue unique pour : nouveau relevé, fin de relevé et modification
/// (kilométrage, date, type) d'un relevé existant.
class TripDialog extends StatefulWidget {
  const TripDialog({
    super.key,
    required this.mode,
    this.trip,
    this.suggestedStartKm,
    this.otherTrips = const [],
  });

  final TripDialogMode mode;

  /// Relevé modifié (mode edit) ou relevé en cours (mode finish).
  final Trip? trip;

  /// Kilométrage proposé pour un nouveau relevé.
  final double? suggestedStartKm;

  /// Les autres relevés, pour signaler une incohérence de kilométrage.
  final List<Trip> otherTrips;

  @override
  State<TripDialog> createState() => _TripDialogState();
}

class _TripDialogState extends State<TripDialog> {
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late TripCategory _category;
  late DateTime _date;
  String? _error;
  String? _info;
  bool _ocrBusy = false;

  bool get _isEdit => widget.mode == TripDialogMode.edit;
  bool get _showStart => widget.mode != TripDialogMode.finish;
  bool get _showEnd =>
      widget.mode == TripDialogMode.finish ||
      (_isEdit && (widget.trip?.isCompleted ?? false));

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;
    final now = DateTime.now();
    _category = trip?.category ?? TripCategory.professional;
    _date = _dateOnly(trip?.date ?? now);

    final startText = switch (widget.mode) {
      TripDialogMode.edit => formatKmInput(trip!.startKm),
      TripDialogMode.start =>
        widget.suggestedStartKm == null
            ? ''
            : formatKmInput(widget.suggestedStartKm!),
      TripDialogMode.finish => '',
    };
    final endText = _isEdit && trip?.endKm != null
        ? formatKmInput(trip!.endKm!)
        : '';
    _startController = TextEditingController(text: startText);
    _endController = TextEditingController(text: endText);
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String get _title => switch (widget.mode) {
    TripDialogMode.start => 'Nouveau relevé',
    TripDialogMode.finish => 'Terminer le relevé',
    TripDialogMode.edit => 'Modifier le relevé',
  };

  Future<void> _pickDate() async {
    final today = _dateOnly(DateTime.now());
    final first = DateTime(2000);
    var initial = _date;
    if (initial.isAfter(today)) initial = today;
    if (initial.isBefore(first)) initial = first;

    final picked = await showDatePicker(
      context: context,
      locale: const Locale('fr', 'FR'),
      initialDate: initial,
      firstDate: first,
      lastDate: today,
    );
    if (picked != null && mounted) {
      setState(() {
        _date = _dateOnly(picked);
        _error = null;
      });
    }
  }

  /// Dernier relevé terminé à la date choisie ou avant (hors relevé édité).
  Trip? _previousTrip() {
    Trip? best;
    for (final other in widget.otherTrips) {
      if (!other.isCompleted || other.endKm == null) continue;
      if (_dateOnly(other.date).isAfter(_date)) continue;
      if (best == null || !other.date.isBefore(best.date)) best = other;
    }
    return best;
  }

  String? get _warning {
    if (!_showStart) return null;
    final start = parseKm(_startController.text);
    final previous = _previousTrip();
    if (start == null || previous == null) return null;
    if (start < previous.endKm! - 0.001) {
      return 'Attention : le relevé précédent '
          '(${DateFormat('dd/MM/yyyy').format(previous.date)}) '
          'se termine à ${formatKm(previous.endKm!)} km.';
    }
    return null;
  }

  void _submit() {
    double startKm;
    if (_showStart) {
      final parsed = parseKm(_startController.text);
      if (parsed == null) {
        setState(() => _error = 'Saisissez un kilométrage de départ valide.');
        return;
      }
      startKm = parsed;
    } else {
      startKm = widget.trip!.startKm;
    }

    double? endKm;
    if (_showEnd) {
      endKm = parseKm(_endController.text);
      if (endKm == null) {
        setState(() => _error = 'Saisissez un kilométrage de fin valide.');
        return;
      }
      if (endKm < startKm) {
        setState(
          () => _error =
              'Le kilométrage de fin doit être supérieur ou égal au départ.',
        );
        return;
      }
    }

    Navigator.of(context).pop(
      TripDialogResult(
        startKm: startKm,
        endKm: endKm,
        date: _date,
        category: _category,
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce relevé ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(TripDialogResult.deletion(widget.trip!));
    }
  }

  Future<void> _scan(TextEditingController controller) async {
    // Le sélecteur photo doit suivre directement le toucher : aucun await avant.
    final picked = await pickOdometerPhoto();
    if (!picked || !mounted) return;
    setState(() {
      _ocrBusy = true;
      _error = null;
      _info = null;
    });
    final result = await recognizeOdometer();
    if (!mounted) return;
    setState(() {
      _ocrBusy = false;
      if (result.status == OcrStatus.ok) {
        controller.text = formatKmInput(result.km!);
        _info = 'Valeur lue sur la photo : ${formatKm(result.km!)} km. '
            'Vérifiez-la avant d’enregistrer.';
      } else if (result.status == OcrStatus.none) {
        _error = 'Aucun kilométrage détecté. Cadrez le compteur de plus près '
            'ou saisissez la valeur à la main.'
            '${result.message == null ? '' : '\n\nDétail technique : ${result.message}'}';
      } else {
        _error = 'Lecture de la photo impossible (${result.message}). '
            'Saisissez la valeur à la main.';
      }
    });
  }

  Widget _scanButton(TextEditingController controller) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _ocrBusy ? null : () => _scan(controller),
        icon: _ocrBusy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const AppIcon(AppIconName.camera, size: 18),
        label: Text(_ocrBusy ? 'Lecture en cours…' : 'Lire depuis une photo'),
      ),
    );
  }

  Widget _kmField({
    required TextEditingController controller,
    required String label,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]'))],
      textInputAction: TextInputAction.done,
      onChanged: (_) => setState(() {
        _error = null;
        _info = null;
      }),
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'km',
        hintText: 'Ex. 12500,5',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warning = _warning;

    return AlertDialog(
      scrollable: true,
      title: Text(_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.mode == TripDialogMode.start)
            const Text(
              'Le dernier kilométrage est proposé automatiquement. '
              'Vous pouvez le modifier.',
            ),
          if (widget.mode == TripDialogMode.finish)
            Text(
              'Départ : ${formatKm(widget.trip!.startKm)} km. '
              'Saisissez le kilométrage à l’arrivée.',
            ),
          if (_showStart) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const AppIcon(AppIconName.calendar, size: 20),
              label: Text(DateFormat('dd/MM/yyyy').format(_date)),
            ),
            const SizedBox(height: 12),
            _kmField(
              controller: _startController,
              label: 'Kilométrage de départ',
              autofocus: widget.mode == TripDialogMode.start,
            ),
            _scanButton(_startController),
          ],
          if (_showEnd) ...[
            const SizedBox(height: 12),
            _kmField(
              controller: _endController,
              label: 'Kilométrage de fin',
              autofocus: widget.mode == TripDialogMode.finish,
            ),
            _scanButton(_endController),
          ],
          if (_showStart) ...[
            const SizedBox(height: 14),
            Text('Type de déplacement', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: TripCategory.values
                  .map(
                    (category) => ChoiceChip(
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (warning != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppIcon(
                  AppIconName.warning,
                  size: 18,
                  color: Color(0xFFB26A00),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    warning,
                    style: const TextStyle(color: Color(0xFFB26A00)),
                  ),
                ),
              ],
            ),
          ],
          if (_info != null) ...[
            const SizedBox(height: 10),
            Text(_info!, style: TextStyle(color: theme.colorScheme.primary)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
      actions: [
        if (_isEdit)
          TextButton(
            onPressed: _confirmDelete,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Supprimer'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
  }
}
