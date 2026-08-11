import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class KpiStrip extends StatelessWidget {
  final List<KpiItem> items;
  const KpiStrip({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final k = items[i];
          return Container(
            width: 140,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k.label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const Spacer(),
                Text(k.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                if (k.hint != null)
                  Text(k.hint!, style: TextStyle(fontSize: 10, color: k.hintColor ?? Colors.green)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class KpiItem {
  final String label;
  final String value;
  final String? hint;
  final Color? hintColor;
  const KpiItem(this.label, this.value, {this.hint, this.hintColor});
}

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  const SectionCard({super.key, required this.title, required this.child, this.actions});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                ...?actions,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class FilterChips extends StatelessWidget {
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;
  const FilterChips({super.key, required this.labels, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: labels
          .map((l) => ChoiceChip(
                label: Text(l),
                selected: selected == l,
                onSelected: (_) => onSelected(l),
              ))
          .toList(),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const StatusPill(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class EmptyHint extends StatelessWidget {
  final String text;
  const EmptyHint(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(text, style: const TextStyle(color: AppColors.textSecondary))));
}
