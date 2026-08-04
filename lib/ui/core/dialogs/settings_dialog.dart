import 'package:flutter/material.dart';
import '../widgets/data_source_settings_widget.dart';

/// Settings Dialog for Data Source configuration
/// Shows the DataSourceSettingsWidget in a dialog
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button at top right
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Settings widget
            const Flexible(
              child: SingleChildScrollView(
                child: DataSourceSettingsWidget(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
