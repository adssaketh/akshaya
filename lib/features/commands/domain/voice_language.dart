/// Which language the person speaks to the app. Display is always English.
enum VoiceLanguage {
  /// Try Indian English first and let the offline word lists and the AI cope
  /// with Telugu and Hindi words in the text.
  auto('auto', 'Automatic', 'en-IN', 'English, Telugu or Hindi, possibly mixed'),
  english('en', 'English', 'en-IN', 'English'),
  telugu('te', 'Telugu', 'te-IN', 'Telugu'),
  hindi('hi', 'Hindi', 'hi-IN', 'Hindi');

  const VoiceLanguage(this.key, this.label, this.localeId, this.promptHint);

  /// Stored in settings.
  final String key;

  /// English name shown in Settings.
  final String label;

  /// Locale passed to the speech recogniser.
  final String localeId;

  /// Tells the AI what language to expect (contains no personal data).
  final String promptHint;

  static VoiceLanguage fromKey(String? key) {
    for (final VoiceLanguage language in VoiceLanguage.values) {
      if (language.key == key) {
        return language;
      }
    }
    return VoiceLanguage.auto;
  }
}
