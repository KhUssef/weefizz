import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class ScaleIsland extends StatelessWidget {
  final double pixelLength; // shown on left (px)
  final TextEditingController cmController; // controlled input
  final bool enableEditing; // disable input until both points set
  final bool showActions; // show confirm/cancel only when ready
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final Color accentColor;

  const ScaleIsland({
    super.key,
    required this.pixelLength,
    required this.cmController,
    required this.enableEditing,
    required this.showActions,
    this.onCancel,
    this.onConfirm,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double maxW = constraints.maxWidth.clamp(0, double.infinity);
          final double islandMaxWidth = maxW > 0 ? (maxW - 24) : 480; // account for side margins
          return Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: islandMaxWidth.clamp(240, 520),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withOpacity(0.78),
                      border: Border.all(color: Colors.white.withOpacity(0.65)),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          '${pixelLength.toStringAsFixed(1)} px',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Text('='),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 110, maxWidth: 160),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: cmController,
                                  enabled: enableEditing,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('cm'),
                            ],
                          ),
                        ),
                        if (showActions) ...[
                          OutlinedButton(
                            onPressed: onCancel,
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.black87),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: onConfirm,
                            style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
                            child: const Text('Confirm'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
