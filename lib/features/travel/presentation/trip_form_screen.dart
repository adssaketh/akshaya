import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/util/date_only.dart';
import '../../pantry/domain/unit.dart';
import '../domain/trip_models.dart';
import '../domain/trip_repository.dart';
import 'trip_providers.dart';

/// Opens the add-trip form, or the edit form when [trip] is given.
Future<void> openTripForm(BuildContext context, {Trip? trip}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => TripFormScreen(trip: trip),
    ),
  );
}

/// Add or edit a trip: name, dates, what to pause and the back-home list.
class TripFormScreen extends ConsumerStatefulWidget {
  const TripFormScreen({super.key, this.trip});

  final Trip? trip;

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  late final TextEditingController _name;
  late DateTime _start;
  late DateTime _end;
  late bool _pauseRecurring;
  late bool _pauseAlerts;
  late List<EssentialLine> _essentials;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Trip? trip = widget.trip;
    final DateTime today = dateOnly(ref.read(todayProvider));
    _name = TextEditingController(text: trip?.name ?? '');
    _start = trip?.start ?? addDays(today, 1);
    _end = trip?.end ?? addDays(today, 4);
    _pauseRecurring = trip?.pauseRecurring ?? true;
    _pauseAlerts = trip?.pauseAlerts ?? true;
    _essentials = List<EssentialLine>.of(trip?.essentials ?? EssentialLine.defaults);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _dateError => validateTripDates(_start, _end);

  Future<void> _pickStart() async {
    final DateTime today = dateOnly(ref.read(todayProvider));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: _start.isBefore(today) ? _start : today,
      lastDate: addDays(today, 730),
      helpText: 'Day you leave',
    );
    if (picked == null) {
      return;
    }
    setState(() {
      final int nights = daysBetween(_start, _end);
      _start = dateOnly(picked);
      // Keep the trip as long as it was.
      _end = addDays(_start, nights > 0 ? nights : 1);
    });
  }

  Future<void> _pickEnd() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _end.isAfter(_start) ? _end : addDays(_start, 1),
      firstDate: addDays(_start, 1),
      lastDate: addDays(_start, kMaxTripNights),
      helpText: 'Day you are back',
    );
    if (picked != null) {
      setState(() => _end = dateOnly(picked));
    }
  }

  Future<void> _addEssential() async {
    final EssentialLine? line = await showDialog<EssentialLine>(
      context: context,
      builder: (BuildContext _) => const _EssentialDialog(),
    );
    if (line != null) {
      setState(() => _essentials.add(line));
    }
  }

  Future<void> _save() async {
    if (_dateError != null || _saving) {
      return;
    }
    setState(() => _saving = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final TripRepository repo = ref.read(tripRepositoryProvider);
    try {
      final Trip? existing = widget.trip;
      if (existing == null) {
        await repo.add(
          TripDraft(
            name: _name.text.trim(),
            start: _start,
            end: _end,
            pauseRecurring: _pauseRecurring,
            pauseAlerts: _pauseAlerts,
            essentials: _essentials,
          ),
        );
      } else {
        await repo.update(
          existing.copyWith(
            name: _name.text.trim(),
            start: _start,
            end: _end,
            pauseRecurring: _pauseRecurring,
            pauseAlerts: _pauseAlerts,
            essentials: _essentials,
            // A new return day means the checklist is due again.
            essentialsAdded: existing.essentialsAdded && existing.end == _end,
          ),
        );
      }
      navigator.pop();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _saving = false);
      }
      showMessage(messenger, failureMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final String? error = _dateError;
    final int nights = daysBetween(_start, _end);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip == null ? 'Add trip' : 'Edit trip'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Trip name (optional)',
              hintText: 'Goa, Home town, Conference',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flight_takeoff_rounded),
            title: const Text('Leaving'),
            subtitle: Text(formatDate(_start)),
            onTap: _pickStart,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flight_land_rounded),
            title: const Text('Back home'),
            subtitle: Text(
              error == null
                  ? '${formatDate(_end)} · $nights ${nights == 1 ? 'night' : 'nights'}'
                  : formatDate(_end),
            ),
            onTap: _pickEnd,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                error,
                style: context.akText.bodySmall!.copyWith(
                  color: colors.expired.foreground,
                ),
              ),
            ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pause expiry and stock alerts'),
            subtitle: const Text('Until the day you are back'),
            value: _pauseAlerts,
            onChanged: (bool v) => setState(() => _pauseAlerts = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pause repeating shopping items'),
            subtitle: const Text('They come back on the day you return'),
            value: _pauseRecurring,
            onChanged: (bool v) => setState(() => _pauseRecurring = v),
          ),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          const SectionHeader(title: 'Back home checklist'),
          Text(
            'Added to your shopping list the day before you return '
            '(${formatDateShort(addDays(_end, -1))}).',
            style: context.akText.bodySmall!.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (int i = 0; i < _essentials.length; i++)
            ListTile(
              key: ValueKey<String>('essential-$i-${_essentials[i].name}'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shopping_basket_outlined),
              title: Text(_essentials[i].name),
              subtitle: Text(_essentials[i].unit.format(_essentials[i].quantity)),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _essentials.removeAt(i)),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addEssential,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add item'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: error == null && !_saving ? _save : null,
            child: Text(widget.trip == null ? 'Save trip' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}

class _EssentialDialog extends StatefulWidget {
  const _EssentialDialog();

  @override
  State<_EssentialDialog> createState() => _EssentialDialogState();
}

class _EssentialDialogState extends State<_EssentialDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _quantity = TextEditingController(text: '1');
  Unit _unit = Unit.pcs;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _name.text.trim();
    final double? quantity = double.tryParse(_quantity.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    if (quantity == null || quantity <= 0 || quantity > 100000) {
      setState(() => _error = 'Enter an amount above zero.');
      return;
    }
    Navigator.of(context).pop(
      EssentialLine(name: name, quantity: quantity, unit: _unit),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to checklist'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Item (English)'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              DropdownButton<Unit>(
                value: _unit,
                items: <DropdownMenuItem<Unit>>[
                  for (final Unit u in Unit.values)
                    DropdownMenuItem<Unit>(value: u, child: Text(u.symbol)),
                ],
                onChanged: (Unit? u) {
                  if (u != null) {
                    setState(() => _unit = u);
                  }
                },
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                _error!,
                style: context.akText.bodySmall!.copyWith(
                  color: context.akColors.expired.foreground,
                ),
              ),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
