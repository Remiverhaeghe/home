import 'package:flutter/material.dart';

/// Curseur qui montre toujours sa valeur : en grand au-dessus, avec les bornes sous les extrémités.
/// Le texte de la valeur est donné tout fait, pour que l'unité et la langue restent à l'appelant.
class ValueSlider extends StatelessWidget {
  const ValueSlider({
    super.key,
    this.title,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.minText,
    required this.maxText,
    this.divisions,
    required this.onChanged,
    this.onChangeEnd,
  });

  /// Ce que règle le curseur ; sans lui, la valeur est seule.
  final String? title;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final String minText;
  final String maxText;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext pContext) {
    final vTheme = Theme.of(pContext);
    final vColors = vTheme.colorScheme;
    final vTitle = title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (vTitle != null) Expanded(child: Text(vTitle, style: vTheme.textTheme.titleSmall)),
            DecoratedBox(
              decoration: BoxDecoration(
                color: vColors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text(
                  valueText,
                  style: vTheme.textTheme.titleMedium?.copyWith(
                    color: vColors.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: valueText,
          semanticFormatterCallback: (_) => valueText,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minText, style: vTheme.textTheme.labelSmall),
              Text(maxText, style: vTheme.textTheme.labelSmall),
            ],
          ),
        ),
      ],
    );
  }
}
