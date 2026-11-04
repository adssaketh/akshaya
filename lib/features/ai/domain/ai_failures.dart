import 'ai_gate.dart';

/// Why an AI call did not give a usable answer. Callers fall back to offline
/// mode on every one of these; none of them loses data.
sealed class AiFailure implements Exception {
  const AiFailure(this.message);

  /// Safe to show to the person.
  final String message;

  @override
  String toString() => message;
}

/// AI may not be used right now (off, not set up, cap reached...).
final class AiUnavailableFailure extends AiFailure {
  AiUnavailableFailure(this.availability)
      : super(availability.message ?? 'AI is not available.');

  final AiAvailability availability;
}

/// The free quota or rate limit answered "too many requests".
final class AiQuotaFailure extends AiFailure {
  const AiQuotaFailure()
      : super('AI limit reached for now, using offline mode.');
}

/// No internet.
final class AiOfflineFailure extends AiFailure {
  const AiOfflineFailure() : super('No internet, using offline mode.');
}

/// The AI service had a problem or timed out.
final class AiServiceFailure extends AiFailure {
  const AiServiceFailure()
      : super('AI is not responding, using offline mode.');
}

/// The AI answered with something that is not the agreed format.
final class AiInvalidResponseFailure extends AiFailure {
  const AiInvalidResponseFailure(this.detail)
      : super('AI gave an answer the app could not use, using offline mode.');

  /// For logs and tests only.
  final String detail;
}
