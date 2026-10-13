import 'package:flutter/material.dart';

/// Labels always accompany swatches, including unfamiliar seller colour names.
class ProductColorSelection extends StatelessWidget {
  const ProductColorSelection({
    super.key,
    required this.colors,
    required this.selectedColor,
    required this.onChanged,
  });
  final List<String> colors;
  final String? selectedColor;
  final ValueChanged<String> onChanged;

  static const _swatches = <String, Color>{
    'black': Colors.black,
    'white': Colors.white,
    'red': Colors.red,
    'blue': Colors.blue,
    'royal blue': Color(0xFF4169E1),
    'green': Colors.green,
    'yellow': Colors.yellow,
    'pink': Colors.pink,
    'purple': Colors.purple,
    'orange': Colors.orange,
    'grey': Colors.grey,
    'gray': Colors.grey,
    'brown': Colors.brown,
    'cream': Color(0xFFFFFDD0),
    'beige': Color(0xFFF5F5DC),
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose colour', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((label) {
            final swatch = _swatches[label.toLowerCase()];
            return ChoiceChip(
              label: Text(label),
              selected: label == selectedColor,
              labelStyle: TextStyle(
                color: label == selectedColor
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
              selectedColor: Theme.of(context).colorScheme.primary,
              avatar: swatch == null
                  ? null
                  : Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: swatch,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
              onSelected: (_) => onChanged(label),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          selectedColor == null
              ? 'Select an available colour before adding to cart.'
              : 'Selected colour: $selectedColor',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
