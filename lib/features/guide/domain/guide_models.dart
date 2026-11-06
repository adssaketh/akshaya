import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;

/// The groups the user guide is split into. The order here is the order the
/// guide shows them in.
enum GuideArea {
  start(
    'Getting started',
    Icons.waving_hand_rounded,
    'The tabs, colours and basics',
  ),
  pantry(
    'Pantry',
    Icons.inventory_2_rounded,
    'Adding, using and finding food',
  ),
  shopping(
    'Shopping',
    Icons.shopping_basket_rounded,
    'Lists, suggestions and Done shopping',
  ),
  voice(
    'Voice and text',
    Icons.mic_rounded,
    'Say it or type it in any language',
  ),
  alerts(
    'Alerts',
    Icons.notifications_active_rounded,
    'Daily reminders and their buttons',
  ),
  recipes(
    'Recipes and meals',
    Icons.soup_kitchen_rounded,
    'Ideas, cooking and the weekly plan',
  ),
  rescue(
    'Food rescue and waste',
    Icons.health_and_safety_rounded,
    'Use it before it goes off',
  ),
  planning(
    'Counting and buying',
    Icons.fact_check_rounded,
    'Count the shelf and know what to buy',
  ),
  household(
    'Household and sync',
    Icons.groups_rounded,
    'Share one pantry between phones',
  ),
  travel(
    'Travel and widgets',
    Icons.luggage_rounded,
    'Trips, home screen widgets, shortcuts',
  ),
  settings(
    'Settings and backup',
    Icons.settings_rounded,
    'Look, privacy and saving your data',
  );

  const GuideArea(this.title, this.icon, this.blurb);

  final String title;
  final IconData icon;
  final String blurb;
}

/// The small drawn example shown at the top of a guide topic. Each value maps
/// to one illustration built from the app's own design widgets.
enum GuidePreview {
  tabs,
  statusChips,
  summaryTiles,
  quickActions,
  undoSnackbar,
  pantryList,
  addItemForm,
  lowStockFields,
  openedFields,
  itemDetail,
  useSheet,
  otherNames,
  barcodeScan,
  cookedFood,
  shoppingList,
  suggestions,
  repeatEntry,
  doneShopping,
  shareText,
  commandCard,
  voiceExamples,
  settingsAi,
  alertNotification,
  settingsAlerts,
  prepNotification,
  recipeIdeas,
  recipeDetail,
  preferencesSheet,
  mealPlan,
  foodRescue,
  settingsFreeze,
  wasteReasons,
  insights,
  countCard,
  settingsCount,
  runsOut,
  whatToBuy,
  signIn,
  household,
  syncStatus,
  tripBanner,
  homeWidget,
  appShortcuts,
  themeCards,
  settingsGeneral,
  settingsCategories,
  settingsLock,
  settingsBackup,
}

/// One page of the user guide.
class GuideTopic {
  const GuideTopic({
    required this.id,
    required this.area,
    required this.title,
    required this.summary,
    required this.whereToFind,
    required this.steps,
    required this.preview,
    this.tips = const <String>[],
    this.keywords = const <String>[],
    this.related = const <String>[],
  });

  /// Stable identifier (also used for "Related" links).
  final String id;
  final GuideArea area;
  final String title;

  /// One or two sentences: what the feature is for.
  final String summary;

  /// Where to tap to reach it, for example "Pantry tab > scan button".
  final String whereToFind;

  /// What to do, in order.
  final List<String> steps;
  final GuidePreview preview;
  final List<String> tips;

  /// Extra words people might search for that the text does not contain.
  final List<String> keywords;

  /// Ids of other topics worth reading next.
  final List<String> related;
}
