import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/util/date_only.dart';
import '../domain/food_estimate.dart';
import '../domain/takeaway_models.dart';
import '../domain/takeaway_repository.dart';
import 'providers.dart';
import 'takeaway_actions.dart';

/// Opens the add-takeaway form, or the edit form when [meal] is given.
Future<void> openTakeawayForm(BuildContext context, {TakeawayMeal? meal}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => TakeawayFormScreen(meal: meal),
    ),
  );
}

/// Add or edit food eaten from outside: what, which meal, how many portions,
/// the day and (optionally) the price.
class TakeawayFormScreen extends ConsumerStatefulWidget {
  const TakeawayFormScreen({super.key, this.meal});

  final TakeawayMeal? meal;

  @override
  ConsumerState<TakeawayFormScreen> createState() => _TakeawayFormScreenState();
}

class _TakeawayFormScreenState extends ConsumerState<TakeawayFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late MealSlot _slot;
  late double _portions;
  late DateTime _day;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final TakeawayMeal? meal = widget.meal;
    final DateTime now = ref.read(clockProvider)();
    _name = TextEditingController(text: meal?.name ?? '');
    _price = TextEditingController(
      text: meal?.price == null ? '' : _plain(meal!.price!),
    );
    _slot = meal?.meal ?? MealSlot.forTime(now);
    _portions = meal?.portions ?? 1;
    _day = meal?.eatenOn ?? dateOnly(now);
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  static String _plain(double value) {
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(2);
  }

  double? get _priceValue {
    final String text = _price.text.trim();
    if (text.isEmpty) {
      return null;
    }
    return double.tryParse(text);
  }

  bool get _priceInvalid =>
      _price.text.trim().isNotEmpty && _priceValue == null;

  String? get _problem {
    if (_priceInvalid) {
      return 'Enter the price as a number, or leave it empty.';
    }
    return validateTakeaway(
      name: _name.text,
      portions: _portions,
      price: _priceValue,
    );
  }

  Future<void> _pickDay() async {
    final DateTime today = dateOnly(ref.read(todayProvider));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _day.isAfter(today) ? today : _day,
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: today,
    );
    if (picked != null && mounted) {
      setState(() => _day = dateOnly(picked));
    }
  }

  void _changePortions(double delta) {
    final double next = _portions + delta;
    if (next < 0.5 || next > kTakeawayMaxPortions) {
      return;
    }
    setState(() => _portions = next);
  }

  Future<void> _save() async {
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final TakeawayRepository repo = ref.read(takeawayRepositoryProvider);
    final FoodEstimator estimator = ref.read(foodEstimatorProvider);
    final TakeawayMeal? existing = widget.meal;
    final String name = _name.text.trim();
    setState(() => _saving = true);
    try {
      final TakeawayMeal saved;
      if (existing == null) {
        saved = await repo.add(
          TakeawayDraft(
            name: name,
            meal: _slot,
            portions: _portions,
            eatenOn: _day,
            price: _priceValue,
            // A dish asked about before is reused, so it is not asked again.
            estimate: estimator.cached(name),
          ),
        );
      } else {
        final bool renamed = estimateKey(existing.name) != estimateKey(name);
        saved = existing.copyWith(
          name: name,
          meal: _slot,
          portions: _portions,
          eatenOn: _day,
          price: _priceValue,
          clearPrice: _priceValue == null,
          clearEstimate: renamed,
          estimate: renamed ? estimator.cached(name) : null,
        );
        await repo.update(saved);
      }
      navigator.pop();
      if (saved.estimate == null) {
        // Worked out in the background; the list shows it when it arrives.
        await workOutEstimate(
          estimator: estimator,
          messenger: messenger,
          meal: saved,
          saved: true,
        );
      }
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
    final String? problem = _problem;
    final bool showProblem =
        problem != null && (_name.text.trim().isNotEmpty || _priceInvalid);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.meal == null ? 'Add takeaway' : 'Edit takeaway'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            maxLength: kTakeawayNameMax,
            onChanged: (String _) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'What did you eat?',
              hintText: 'Masala dosa, Veg biryani, Samosa',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Meal', style: context.akText.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final MealSlot slot in MealSlot.values)
                ChoiceChip(
                  label: Text(slot.label),
                  selected: slot == _slot,
                  onSelected: (bool _) => setState(() => _slot = slot),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Portions', style: context.akText.titleSmall),
              ),
              IconButton(
                tooltip: 'Fewer portions',
                icon: const Icon(Icons.remove_circle_outline_rounded),
                onPressed: _portions > 0.5 ? () => _changePortions(-0.5) : null,
              ),
              SizedBox(
                width: 72,
                child: Text(
                  _portions == _portions.roundToDouble()
                      ? _portions.round().toString()
                      : _portions.toStringAsFixed(1),
                  textAlign: TextAlign.center,
                  style: context.akText.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'More portions',
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: _portions < kTakeawayMaxPortions
                    ? () => _changePortions(0.5)
                    : null,
              ),
            ],
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_rounded),
            title: const Text('Day'),
            subtitle: Text(formatDate(_day)),
            onTap: _pickDay,
          ),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: (String _) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Price paid (optional)',
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Gemini works out the ingredients and a rough nutrition estimate '
            'for the eating report. Only the food name is sent.',
            style: context.akText.bodySmall!.copyWith(
              color: colors.textSecondary,
            ),
          ),
          if (showProblem)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                problem,
                style: context.akText.bodySmall!.copyWith(
                  color: colors.expired.foreground,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: problem == null && !_saving ? _save : null,
            child: Text(widget.meal == null ? 'Save takeaway' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
