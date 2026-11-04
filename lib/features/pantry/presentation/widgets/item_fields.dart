import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/util/quantity.dart';
import '../../domain/default_categories.dart';
import '../../domain/entities.dart';
import '../../domain/storage_location.dart';
import '../../domain/unit.dart';
import '../providers.dart';

/// Form state for an item definition (everything except its name, which each
/// screen handles itself).
class ItemFieldsController extends ChangeNotifier {
  ItemFieldsController({Item? item})
      : categoryId = item?.categoryId ?? kDefaultCategoryId,
        unit = item?.defaultUnit ?? Unit.pcs,
        location = item?.defaultStorageLocation ?? StorageLocation.pantry,
        essential = item?.isEssential ?? false,
        aliases = List<String>.of(item?.aliases ?? const <String>[]),
        brand = TextEditingController(text: item?.brand ?? ''),
        barcode = TextEditingController(text: item?.barcode ?? ''),
        notes = TextEditingController(text: item?.notes ?? ''),
        threshold = TextEditingController(
          text: item?.lowStockThreshold == null
              ? ''
              : formatNumber(item!.lowStockThreshold!),
        ),
        aliasInput = TextEditingController();

  final TextEditingController brand;
  final TextEditingController barcode;
  final TextEditingController notes;
  final TextEditingController threshold;
  final TextEditingController aliasInput;

  String categoryId;
  Unit unit;
  StorageLocation location;
  bool essential;
  final List<String> aliases;

  double? get thresholdValue => parseQuantity(threshold.text);

  void setCategory(String id) {
    categoryId = id;
    notifyListeners();
  }

  void setUnit(Unit value) {
    unit = value;
    notifyListeners();
  }

  void setLocation(StorageLocation value) {
    location = value;
    notifyListeners();
  }

  void setEssential(bool value) {
    essential = value;
    notifyListeners();
  }

  /// Adds what is typed in the alias box. Commas separate several names.
  void addAliasesFromInput() {
    final List<String> parts = aliasInput.text
        .split(',')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();
    for (final String part in parts) {
      final bool exists = aliases.any(
        (String a) => a.toLowerCase() == part.toLowerCase(),
      );
      if (!exists) {
        aliases.add(part);
      }
    }
    aliasInput.clear();
    notifyListeners();
  }

  void removeAlias(String alias) {
    aliases.remove(alias);
    notifyListeners();
  }

  String? _optional(TextEditingController c) {
    final String text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  List<String> _allAliases() {
    final List<String> all = List<String>.of(aliases);
    final String pending = aliasInput.text.trim();
    if (pending.isNotEmpty) {
      for (final String part in pending.split(',')) {
        final String alias = part.trim();
        if (alias.isNotEmpty &&
            !all.any((String a) => a.toLowerCase() == alias.toLowerCase())) {
          all.add(alias);
        }
      }
    }
    return all;
  }

  /// A new item named [name].
  ItemDraft toDraft(String name) {
    return ItemDraft(
      name: name,
      categoryId: categoryId,
      defaultUnit: unit,
      brand: _optional(brand),
      barcode: _optional(barcode),
      notes: _optional(notes),
      aliases: _allAliases(),
      lowStockThreshold: thresholdValue,
      isEssential: essential,
      defaultStorageLocation: location,
    );
  }

  /// The edited version of [original], renamed to [name].
  Item toItem(Item original, String name) {
    return Item(
      id: original.id,
      name: name,
      brand: _optional(brand),
      barcode: _optional(barcode),
      categoryId: categoryId,
      defaultUnit: unit,
      imagePath: original.imagePath,
      notes: _optional(notes),
      aliases: _allAliases(),
      lowStockThreshold: thresholdValue,
      isEssential: essential,
      defaultStorageLocation: location,
      createdAt: original.createdAt,
      updatedAt: original.updatedAt,
    );
  }

  @override
  void dispose() {
    brand.dispose();
    barcode.dispose();
    notes.dispose();
    threshold.dispose();
    aliasInput.dispose();
    super.dispose();
  }
}

/// Category, unit, brand, low-stock level, aliases, barcode and notes inputs.
/// Place inside a [Form] to get validation.
class ItemFields extends ConsumerWidget {
  const ItemFields({super.key, required this.controller});

  final ItemFieldsController controller;

  String? _validateThreshold(String? text) {
    final String value = (text ?? '').trim();
    if (value.isEmpty) {
      return null;
    }
    final double? parsed = parseQuantity(value);
    if (parsed == null || parsed < 0) {
      return 'Enter 0 or more';
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Category> categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final bool categoryKnown =
            categories.any((Category c) => c.id == controller.categoryId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DropdownButtonFormField<String>(
              key: ValueKey<String>(
                'cat-${controller.categoryId}-${categories.length}',
              ),
              initialValue: categoryKnown ? controller.categoryId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: <DropdownMenuItem<String>>[
                for (final Category c in categories)
                  DropdownMenuItem<String>(value: c.id, child: Text(c.name)),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  controller.setCategory(value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<Unit>(
                    key: ValueKey<String>('unit-${controller.unit.name}'),
                    initialValue: controller.unit,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: <DropdownMenuItem<Unit>>[
                      for (final Unit u in Unit.values)
                        DropdownMenuItem<Unit>(
                          value: u,
                          child: Text(u.symbol),
                        ),
                    ],
                    onChanged: (Unit? value) {
                      if (value != null) {
                        controller.setUnit(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<StorageLocation>(
                    key: ValueKey<String>('loc-${controller.location.name}'),
                    initialValue: controller.location,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Usually in'),
                    items: <DropdownMenuItem<StorageLocation>>[
                      for (final StorageLocation l in StorageLocation.values)
                        DropdownMenuItem<StorageLocation>(
                          value: l,
                          child: Text(l.label),
                        ),
                    ],
                    onChanged: (StorageLocation? value) {
                      if (value != null) {
                        controller.setLocation(value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: controller.brand,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Brand (optional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: controller.threshold,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Low-stock level (optional)',
                helperText: 'Warn when the amount left is at or below this',
                suffixText: controller.unit.symbol,
              ),
              validator: _validateThreshold,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Essential item'),
              subtitle: const Text('Always keep in stock'),
              value: controller.essential,
              onChanged: controller.setEssential,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller.aliasInput,
              textInputAction: TextInputAction.done,
              onSubmitted: (String _) => controller.addAliasesFromInput(),
              decoration: InputDecoration(
                labelText: 'Other names (Telugu, Hindi, ...)',
                helperText: 'Separate several names with commas',
                suffixIcon: IconButton(
                  tooltip: 'Add name',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: controller.addAliasesFromInput,
                ),
              ),
            ),
            if (controller.aliases.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final String alias in controller.aliases)
                    InputChip(
                      label: Text(alias),
                      onDeleted: () => controller.removeAlias(alias),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: controller.barcode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Barcode (optional)',
                helperText: 'Scanning arrives in a later update',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: controller.notes,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        );
      },
    );
  }
}
