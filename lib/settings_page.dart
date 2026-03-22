import 'package:flutter/material.dart';
import 'theme_service.dart';
import 'app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Appearance',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: AnimatedBuilder(
              animation: themeService,
              builder: (context, _) {
                return SwitchListTile(
                  secondary: Icon(
                    themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    themeService.isDarkMode ? 'Dark theme is on' : 'Light theme is on',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  value: themeService.isDarkMode,
                  onChanged: (value) => themeService.setDarkMode(value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
