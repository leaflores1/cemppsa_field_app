import 'package:flutter/material.dart';

class OutOfRangeReviewItem {
  final String readingKey;
  final String instrumentCode;
  final String label;
  final String rawValue;
  final double value;
  final double min;
  final double max;

  const OutOfRangeReviewItem({
    required this.readingKey,
    required this.instrumentCode,
    required this.label,
    required this.rawValue,
    required this.value,
    required this.min,
    required this.max,
  });

  String get formattedValue => _formatNumber(value);
  String get displayValue =>
      rawValue.trim().isNotEmpty ? rawValue.trim() : formattedValue;
  String get formattedRange => '${_formatNumber(min)} - ${_formatNumber(max)}';

  static String _formatNumber(double value) {
    final rounded = value.toStringAsFixed(2);
    if (rounded.endsWith('.00')) {
      return rounded.substring(0, rounded.length - 3);
    }
    if (rounded.endsWith('0')) {
      return rounded.substring(0, rounded.length - 1);
    }
    return rounded;
  }
}

Future<bool?> showOutOfRangeReviewSheet(
  BuildContext context, {
  required List<OutOfRangeReviewItem> items,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: const Color(0xFF1E293B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${items.length} valores fuera de rango',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Color(0xFF334155)),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.instrumentCode} | ${item.label}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Valor: ${item.displayValue} | Rango: ${item.formattedRange}',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      child: const Text('Revisar valores'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: const Color(0xFF0F172A),
                      ),
                      child: const Text('Confirmar igual'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
