import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../domain/guide_content.dart';
import '../domain/guide_models.dart';
import '../domain/guide_search.dart';
import 'guide_topic_screen.dart';

/// Opens the user guide.
Future<void> openGuide(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => const GuideScreen(),
    ),
  );
}

/// The user guide: a search box, the feature areas as chips, and every topic
/// as a card. Searching looks through titles, steps, tips and the other words
/// people use for a feature ("mic", "barcode", "throw away").
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final TextEditingController _controller = TextEditingController();
  final GuideSearch _search = GuideSearch(kGuideTopics);
  GuideArea? _area;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String value) => setState(() => _query = value);

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final bool searching = _query.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('User guide')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _controller,
                onChanged: _setQuery,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search: barcode, expiry, share list...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _clear,
                        ),
                ),
              ),
            ),
            if (!searching)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _area == null,
                      onSelected: (bool _) => setState(() => _area = null),
                    ),
                    for (final GuideArea area in GuideArea.values) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      ChoiceChip(
                        avatar: Icon(area.icon, size: AppSizes.iconSm),
                        label: Text(area.title),
                        selected: _area == area,
                        onSelected: (bool _) => setState(
                          () => _area = _area == area ? null : area,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: searching ? _results(context) : _browse(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Search results, best match first.
  Widget _results(BuildContext context) {
    final List<GuideTopic> found = _search.search(_query);
    if (found.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nothing found',
        body: 'Try a simpler word, such as expiry, scan, share or recipe.',
      );
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            found.length == 1 ? '1 result' : '${found.length} results',
            style: context.akText.labelMedium!.copyWith(
              color: context.akColors.textSecondary,
            ),
          ),
        ),
        for (final GuideTopic topic in found)
          _TopicTile(topic: topic, showArea: true),
      ],
    );
  }

  /// All topics grouped by area, or one area when a chip is selected.
  Widget _browse(BuildContext context) {
    final List<GuideArea> areas =
        _area == null ? GuideArea.values : <GuideArea>[_area!];
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        if (_area == null) const _StartHereCard(),
        for (final GuideArea area in areas) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  area.icon,
                  size: AppSizes.iconMd,
                  color: context.akColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(area.title, style: context.akText.titleMedium),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              area.blurb,
              style: context.akText.bodySmall!.copyWith(
                color: context.akColors.textSecondary,
              ),
            ),
          ),
          for (final GuideTopic topic in kGuideTopics)
            if (topic.area == area) _TopicTile(topic: topic),
        ],
      ],
    );
  }
}

/// The card at the top: the one page a new person should read first.
class _StartHereCard extends StatelessWidget {
  const _StartHereCard();

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final GuideTopic? first = guideTopicById('tabs');
    return Material(
      color: colors.surfaceAlt,
      borderRadius: AppRadius.cardBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: first == null ? null : () => openGuideTopic(context, first),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              Icon(Icons.waving_hand_rounded, color: colors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('New here?', style: context.akText.titleSmall),
                    Text(
                      'Start with the five tabs, then search for anything '
                      'you want to do.',
                      style: context.akText.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// One topic as a tappable card.
class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic, this.showArea = false});

  final GuideTopic topic;

  /// Shows the area name above the title (used in search results).
  final bool showArea;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colors.surface,
        borderRadius: AppRadius.cardBorder,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openGuideTopic(context, topic),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: AppSizes.avatar,
                    height: AppSizes.avatar,
                    child: Icon(
                      topic.area.icon,
                      size: AppSizes.iconMd,
                      color: colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (showArea)
                        Text(
                          topic.area.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.akText.labelSmall!.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      Text(
                        topic.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.akText.titleSmall,
                      ),
                      Text(
                        topic.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.akText.bodySmall!.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
