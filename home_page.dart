import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/trip.dart';
import '../models/trip_period.dart';
import '../services/backup_service.dart';
import '../services/export_service.dart';
import '../services/file_delivery.dart';
import '../services/storage_service.dart';
import '../utils/format.dart';
import '../widgets/app_icon.dart';
import '../widgets/trip_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final StorageService _storageService = StorageService();
  final ExportService _exportService = ExportService();
  final BackupService _backupService = BackupService();
  List<Trip> _allTrips = [];
  Trip? _activeTrip;
  TripPeriod _selectedPeriod = TripPeriod.month;
  DateTime _periodAnchor = DateTime.now();
  bool _isLoading = true;
  bool _reminderDismissed = false;
  String? _notice;

  TripPeriodRange get _periodRange =>
      TripPeriodRange.forDate(_selectedPeriod, _periodAnchor);

  List<Trip> get _periodTrips {
    final trips = _allTrips
        .where((trip) => _periodRange.contains(trip.date))
        .toList();
    trips.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.startKm.compareTo(a.startKm);
    });
    return trips;
  }

  double get _professionalKm => _totalFor(TripCategory.professional);
  double get _privateKm => _totalFor(TripCategory.privateUse);

  double _totalFor(TripCategory category) {
    return _periodTrips
        .where(
          (trip) =>
              trip.category == category &&
              trip.isCompleted &&
              trip.endKm != null,
        )
        .fold(0, (total, trip) => total + trip.distanceKm);
  }

  /// Dernier kilométrage d'arrivée connu (relevé terminé le plus récent).
  double? get _previousOdometerKm {
    Trip? latest;
    for (final trip in _allTrips) {
      if (!trip.isCompleted || trip.endKm == null) continue;
      if (latest == null) {
        latest = trip;
        continue;
      }
      final byDate = trip.date.compareTo(latest.date);
      if (byDate > 0 || (byDate == 0 && trip.endKm! >= latest.endKm!)) {
        latest = trip;
      }
    }
    return latest?.endKm;
  }

  bool get _shouldShowReminder {
    if (_reminderDismissed || _activeTrip != null) return false;
    final now = DateTime.now();
    final hasTodayEntry = _allTrips.any(
      (trip) =>
          trip.date.year == now.year &&
          trip.date.month == now.month &&
          trip.date.day == now.day,
    );
    return !hasTodayEntry;
  }

  String get _periodTitle {
    final range = _periodRange;
    switch (_selectedPeriod) {
      case TripPeriod.week:
        final lastDay = DateTime(
          range.end.year,
          range.end.month,
          range.end.day - 1,
        );
        return 'Semaine du ${DateFormat('dd/MM').format(range.start)} '
            'au ${DateFormat('dd/MM/yyyy').format(lastDay)}';
      case TripPeriod.month:
        const monthNames = [
          'janvier',
          'février',
          'mars',
          'avril',
          'mai',
          'juin',
          'juillet',
          'août',
          'septembre',
          'octobre',
          'novembre',
          'décembre',
        ];
        return '${monthNames[_periodAnchor.month - 1]} ${_periodAnchor.year}';
      case TripPeriod.year:
        return '${_periodAnchor.year}';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    var trips = <Trip>[];
    String? notice;
    try {
      final result = await _storageService.loadTrips();
      trips = [...result.trips]; // copie modifiable (la liste vide d'origine est constante)
      if (result.unreadable) {
        notice =
            'Les données enregistrées sont illisibles et n’ont pas pu être '
            'chargées. Une copie de sécurité a été conservée.';
      } else if (result.skipped > 0) {
        notice =
            '${result.skipped} relevé(s) illisible(s) ont été ignorés. '
            'Une copie de sécurité a été conservée.';
      }
    } catch (error) {
      notice = 'Impossible de lire les données enregistrées : $error';
    }
    if (!mounted) return;

    setState(() {
      _allTrips = trips;
      _refreshActiveTrip();
      _notice = notice;
      _isLoading = false;
    });
  }

  void _refreshActiveTrip() {
    _activeTrip = _allTrips.where((trip) => !trip.isCompleted).firstOrNull;
  }

  Future<void> _persist() async {
    try {
      await _storageService.saveTrips(_allTrips);
    } catch (error) {
      _showMessage('Impossible d’enregistrer les données : $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _startNewTrip(TripDialogResult result) async {
    final newTrip = Trip(
      id: const Uuid().v4(),
      date: result.date,
      startKm: result.startKm,
      category: result.category,
    );

    setState(() {
      _allTrips.add(newTrip);
      _refreshActiveTrip();
      _periodAnchor = result.date;
    });
    await _persist();
  }

  Future<void> _endActiveTrip(double endKm) async {
    final trip = _activeTrip;
    if (trip == null) return;
    await _replaceTrip(trip.copyWith(endKm: endKm, isCompleted: true));
  }

  Future<void> _replaceTrip(Trip updated) async {
    setState(() {
      final index = _allTrips.indexWhere((trip) => trip.id == updated.id);
      if (index >= 0) _allTrips[index] = updated;
      _refreshActiveTrip();
    });
    await _persist();
  }

  Future<void> _deleteTrip(Trip trip) async {
    setState(() {
      _allTrips.removeWhere((candidate) => candidate.id == trip.id);
      _refreshActiveTrip();
    });
    await _persist();
    _showMessage('Relevé supprimé.');
  }

  void _changePeriod(TripPeriod period) {
    setState(() => _selectedPeriod = period);
  }

  void _movePeriod(int offset) {
    setState(() {
      switch (_selectedPeriod) {
        case TripPeriod.week:
          _periodAnchor = DateTime(
            _periodAnchor.year,
            _periodAnchor.month,
            _periodAnchor.day + 7 * offset,
          );
        case TripPeriod.month:
          _periodAnchor = DateTime(
            _periodAnchor.year,
            _periodAnchor.month + offset,
          );
        case TripPeriod.year:
          _periodAnchor = DateTime(_periodAnchor.year + offset);
      }
    });
  }

  Future<TripDialogResult?> _askTrip({
    required TripDialogMode mode,
    Trip? trip,
  }) {
    return showDialog<TripDialogResult>(
      context: context,
      builder: (_) => TripDialog(
        mode: mode,
        trip: trip,
        suggestedStartKm: _previousOdometerKm,
        otherTrips: _allTrips.where((other) => other.id != trip?.id).toList(),
      ),
    );
  }

  Future<void> _newTrip() async {
    final result = await _askTrip(mode: TripDialogMode.start);
    if (result == null || !mounted) return;
    await _startNewTrip(result);
  }

  Future<void> _finishTrip() async {
    final trip = _activeTrip;
    if (trip == null) return;
    final result = await _askTrip(mode: TripDialogMode.finish, trip: trip);
    if (result == null || result.endKm == null || !mounted) return;
    await _endActiveTrip(result.endKm!);
  }

  Future<void> _editTrip(Trip trip) async {
    final result = await _askTrip(mode: TripDialogMode.edit, trip: trip);
    if (result == null || !mounted) return;
    if (result.delete) {
      await _deleteTrip(trip);
      return;
    }
    await _replaceTrip(
      trip.copyWith(
        date: result.date,
        startKm: result.startKm,
        endKm: result.endKm,
        category: result.category,
      ),
    );
    _showMessage('Relevé modifié.');
  }

  Future<void> _exportCsv() async {
    try {
      final result = await _exportService.saveCsv(_allTrips);
      if (result == DeliveryResult.cancelled) return;
      _showMessage(
        result == DeliveryResult.shared
            ? 'Export CSV prêt.'
            : 'Export CSV téléchargé.',
      );
    } catch (error) {
      _showMessage('Échec de l’export CSV : $error');
    }
  }

  Future<void> _exportPdf() async {
    try {
      final result = await _exportService.savePdf(
        trips: _periodTrips,
        periodLabel: _periodTitle,
      );
      if (result == DeliveryResult.cancelled) return;
      _showMessage(
        result == DeliveryResult.shared
            ? 'Rapport PDF prêt.'
            : 'Rapport PDF téléchargé.',
      );
    } catch (error) {
      _showMessage('Échec de l’export PDF : $error');
    }
  }

  Future<void> _backup() async {
    try {
      final result = await _backupService.saveBackup(_allTrips);
      if (result == DeliveryResult.cancelled) return;
      _showMessage(
        result == DeliveryResult.shared
            ? 'Sauvegarde prête.'
            : 'Sauvegarde téléchargée.',
      );
    } catch (error) {
      _showMessage('Échec de la sauvegarde : $error');
    }
  }

  Future<void> _restore() async {
    // Le sélecteur doit être ouvert directement depuis le geste de l'utilisateur.
    final text = await pickTextFile();
    if (text == null || !mounted) return;

    final BackupContent backup;
    try {
      backup = _backupService.parseBackup(text);
    } on FormatException catch (error) {
      _showMessage(error.message);
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurer la sauvegarde'),
        content: Text(
          '${backup.trips.length} relevé(s) trouvé(s)'
          '${backup.skipped > 0 ? ' (${backup.skipped} illisible(s) ignoré(s))' : ''}.\n\n'
          'Fusionner ajoute les relevés absents de cet appareil.\n'
          'Remplacer efface les ${_allTrips.length} relevé(s) actuel(s).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'merge'),
            child: const Text('Fusionner'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'replace'),
            child: const Text('Remplacer'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    final merged = choice == 'merge' ? [..._allTrips] : <Trip>[];
    final knownIds = merged.map((trip) => trip.id).toSet();
    var hasActive = merged.any((trip) => !trip.isCompleted);
    var added = 0;
    for (final trip in backup.trips) {
      if (knownIds.contains(trip.id)) continue;
      // Un seul relevé en cours à la fois.
      if (!trip.isCompleted) {
        if (hasActive) continue;
        hasActive = true;
      }
      knownIds.add(trip.id);
      merged.add(trip);
      added++;
    }

    setState(() {
      _allTrips = merged;
      _refreshActiveTrip();
      _notice = null;
    });
    await _persist();
    _showMessage(
      choice == 'merge'
          ? '$added relevé(s) ajouté(s).'
          : 'Sauvegarde restaurée : $added relevé(s).',
    );
  }

  String _formatKm(double value) => '${formatKm(value)} km';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleTrips = _periodTrips;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kilométrage',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Exporter tout en CSV',
            onPressed: _allTrips.isEmpty ? null : _exportCsv,
            icon: const AppIcon(AppIconName.download),
          ),
          IconButton(
            tooltip: 'Exporter la période en PDF',
            onPressed: visibleTrips.isEmpty ? null : _exportPdf,
            icon: const AppIcon(AppIconName.pdf),
          ),
          PopupMenuButton<String>(
            tooltip: 'Sauvegarde',
            icon: const AppIcon(AppIconName.more),
            onSelected: (value) {
              if (value == 'backup') _backup();
              if (value == 'restore') _restore();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'backup',
                enabled: _allTrips.isNotEmpty,
                child: const Text('Sauvegarder (fichier JSON)'),
              ),
              const PopupMenuItem(
                value: 'restore',
                child: Text('Restaurer une sauvegarde'),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'Votre suivi, en un coup d’œil',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Classez vos déplacements et gardez vos kilomètres à jour.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_notice != null) ...[
                  const SizedBox(height: 16),
                  _buildNotice(theme),
                ],
                if (_shouldShowReminder) ...[
                  const SizedBox(height: 16),
                  _buildDailyReminder(theme),
                ],
                const SizedBox(height: 16),
                _buildActiveTripCard(theme),
                const SizedBox(height: 20),
                Text(
                  'Totaux · $_periodTitle',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Professionnel',
                        value: _formatKm(_professionalKm),
                        icon: AppIconName.work,
                        color: const Color(0xFF3157C8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Privé',
                        value: _formatKm(_privateKm),
                        icon: AppIconName.home,
                        color: const Color(0xFF16836B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildPeriodSelector(theme),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Historique',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${visibleTrips.length} relevé${visibleTrips.length > 1 ? 's' : ''}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (visibleTrips.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Touchez un relevé pour le modifier ou le supprimer.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (visibleTrips.isEmpty)
                  _buildPeriodEmptyState(theme)
                else
                  ...visibleTrips.map(_buildTripCard),
              ],
            ),
    );
  }

  Widget _buildPeriodSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SegmentedButton<TripPeriod>(
            showSelectedIcon: false,
            segments: TripPeriod.values
                .map(
                  (period) => ButtonSegment<TripPeriod>(
                    value: period,
                    label: Text(period.label),
                  ),
                )
                .toList(),
            selected: {_selectedPeriod},
            onSelectionChanged: (selection) => _changePeriod(selection.first),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Période précédente',
                onPressed: () => _movePeriod(-1),
                icon: const AppIcon(AppIconName.chevronLeft),
              ),
              Expanded(
                child: Text(
                  _periodTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Période suivante',
                onPressed: () => _movePeriod(1),
                icon: const AppIcon(AppIconName.chevronRight),
              ),
            ],
          ),
          if (!_periodRange.contains(DateTime.now()))
            TextButton(
              onPressed: () => setState(() => _periodAnchor = DateTime.now()),
              child: const Text('Revenir à aujourd’hui'),
            ),
        ],
      ),
    );
  }

  Widget _buildNotice(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          AppIcon(
            AppIconName.warning,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _notice!,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          IconButton(
            tooltip: 'Masquer',
            onPressed: () => setState(() => _notice = null),
            icon: AppIcon(
              AppIconName.close,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyReminder(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AppIcon(
                AppIconName.notification,
                size: 24,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pensez à saisir le kilométrage du jour.',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Masquer le rappel',
                onPressed: () => setState(() => _reminderDismissed = true),
                icon: AppIcon(
                  AppIconName.close,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _newTrip,
              icon: const AppIcon(AppIconName.add, size: 18),
              label: const Text('Saisir maintenant'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTripCard(ThemeData theme) {
    final isActive = _activeTrip != null;
    final accent = isActive ? const Color(0xFFCB7A18) : const Color(0xFF16836B);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: accent.withValues(alpha: 0.12),
                foregroundColor: accent,
                child: AppIcon(isActive ? AppIconName.car : AppIconName.check),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive ? 'Déplacement en cours' : 'Prêt à démarrer',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isActive
                          ? '${_activeTrip!.category.label} · départ ${_formatKm(_activeTrip!.startKm)}'
                          : 'Commencez un relevé de kilométrage.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isActive ? _finishTrip : _newTrip,
              icon: AppIcon(
                isActive ? AppIconName.stop : AppIconName.add,
                size: 20,
              ),
              label: Text(isActive ? 'Terminer le relevé' : 'Nouveau relevé'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (isActive)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _editTrip(_activeTrip!),
                icon: const AppIcon(AppIconName.edit, size: 18),
                label: const Text('Modifier ou supprimer'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          AppIcon(
            AppIconName.route,
            size: 38,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            'Aucun relevé pour cette période',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    final color = trip.category == TripCategory.professional
        ? const Color(0xFF3157C8)
        : const Color(0xFF16836B);
    final distance = trip.endKm == null ? null : _formatKm(trip.distanceKm);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _editTrip(trip),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: color.withValues(alpha: 0.12),
              foregroundColor: color,
              child: AppIcon(
                trip.category == TripCategory.professional
                    ? AppIconName.work
                    : AppIconName.home,
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy').format(trip.date),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${trip.category.label} · ${_formatKm(trip.startKm)}'
                    '${trip.endKm == null ? ' → en cours' : ' → ${_formatKm(trip.endKm!)}'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              distance ?? '—',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            AppIcon(
              AppIconName.edit,
              size: 18,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final AppIconName icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, color: color),
          const SizedBox(height: 14),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
