import 'package:flutter/material.dart';

import '../../../core/ui/feedback.dart';
import '../../ai/domain/ai_failures.dart';
import '../domain/takeaway_models.dart';
import 'providers.dart';

/// Asks Gemini for the ingredients and nutrition of [meal] and saves them on
/// it. A failure is shown as a short message and never loses the takeaway.
///
/// [saved] is true right after the takeaway was saved, so the message can say
/// so.
Future<void> workOutEstimate({
  required FoodEstimator estimator,
  required ScaffoldMessengerState messenger,
  required TakeawayMeal meal,
  bool saved = false,
}) async {
  final String lead = saved
      ? 'Saved, but the ingredients could not be worked out. '
      : 'Could not work out the ingredients. ';
  try {
    await estimator.fillTakeaway(meal);
  } on AiFailure catch (failure) {
    showMessage(messenger, '$lead${failure.message}');
  } on Object {
    showMessage(messenger, '${lead}Please try again later.');
  }
}
