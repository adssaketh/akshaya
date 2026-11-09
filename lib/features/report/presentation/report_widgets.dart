import 'package:akshaya/core/design/design.dart';
import 'package:flutter/material.dart';

import '../domain/report_models.dart';

class VerdictRow extends StatelessWidget {
  const VerdictRow({super.key, required this.report});

  final ConsumptionReport report;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = context.akText;
    switch (report.verdict) {
      case BalanceVerdict.balanced:
        return const Align(
          alignment: Alignment.centerLeft,
          child: StatusChip(kind: StatusKind.fresh, label: 'Balanced'),
        );
      case BalanceVerdict.partly:
        return const Align(
          alignment: Alignment.centerLeft,
          child: StatusChip(
            kind: StatusKind.expiring,
            label: 'Partly balanced',
          ),
        );
      case BalanceVerdict.notBalanced:
        return const Align(
          alignment: Alignment.centerLeft,
          child: StatusChip(
            kind: StatusKind.expired,
            label: 'Not balanced yet',
          ),
        );
      case BalanceVerdict.notEnoughData:
        return Text(
          report.period == ReportPeriod.today
              ? 'Too little marked as used to judge the balance yet.'
              : 'Too few days logged to judge the balance yet.',
          style: text.bodyMedium,
        );
    }
  }
}

class GroupChip extends StatelessWidget {
  const GroupChip({
    super.key,
    required this.group,
    required this.present,
    required this.judged,
  });

  final PlateGroup group;
  final bool present;
  final bool judged;

  @override
  Widget build(BuildContext context) {
    final AkshayaColors colors = context.akColors;
    final StatusColors good = colors.forStatus(StatusKind.fresh);
    final Color foreground = present ? good.foreground : colors.textSecondary;
    final Color background = present ? good.background : colors.surfaceAlt;
    final IconData icon = present
        ? Icons.check_circle_rounded
        : (judged
              ? Icons.remove_circle_outline_rounded
              : Icons.circle_outlined);
    return Semantics(
      label: '${group.label}: ${present ? 'included' : 'not included'}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: background,
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: AppSizes.iconXs, color: foreground),
              const SizedBox(width: AppSpacing.xs),
              Text(
                group.label,
                style: context.akText.labelSmall!.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
