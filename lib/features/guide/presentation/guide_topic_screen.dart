import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../domain/guide_content.dart';
import '../domain/guide_models.dart';
import 'guide_previews.dart';

/// Opens one page of the guide.
Future<void> openGuideTopic(BuildContext context, GuideTopic topic) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => GuideTopicScreen(topic: topic),
    ),
  );
}

/// One guide page: what the feature is for, a small picture of it, where to
/// find it, the steps, and tips.
class GuideTopicScreen extends StatelessWidget {
  const GuideTopicScreen({super.key, required this.topic});

  final GuideTopic topic;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final TextTheme text = context.akText;

    final List<GuideTopic> related = <GuideTopic>[
      for (final String id in topic.related)
        if (guideTopicById(id) case final GuideTopic found) found,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(topic.area.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(topic.title, style: text.headlineSmall),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(topic.summary, style: text.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            GuidePreviewView(preview: topic.preview),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Example picture. Your screen may look a little different.',
              style: text.bodySmall!.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.explore_rounded,
                  size: AppSizes.iconMd,
                  color: colors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Where to find it',
                        style: text.labelMedium!.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(topic.whereToFind, style: text.bodyLarge),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Semantics(
              header: true,
              child: Text('How to', style: text.titleMedium),
            ),
            const SizedBox(height: AppSpacing.md),
            for (int i = 0; i < topic.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ExcludeSemantics(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(
                          width: AppSizes.avatar - AppSpacing.sm,
                          height: AppSizes.avatar - AppSpacing.sm,
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: text.labelLarge!.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          topic.steps[i],
                          style: text.bodyLarge,
                          semanticsLabel: 'Step ${i + 1}: ${topic.steps[i]}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (topic.tips.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: AppRadius.cardBorder,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            size: AppSizes.iconMd,
                            color: colors.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Good to know', style: text.titleSmall),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final String tip in topic.tips)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.sm,
                          ),
                          child: Text(tip, style: text.bodyMedium),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (related.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              Semantics(
                header: true,
                child: Text('Read next', style: text.titleMedium),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final GuideTopic next in related)
                    ActionChip(
                      avatar: Icon(next.area.icon, size: AppSizes.iconSm),
                      label: Text(next.title),
                      onPressed: () => openGuideTopic(context, next),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
