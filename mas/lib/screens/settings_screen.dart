import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Application Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Email Configuration',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              decoration: InputDecoration(
                                labelText: 'Base Email Address',
                                border: const OutlineInputBorder(),
                                labelStyle: TextStyle(color: colorScheme.onSurface),
                              ),
                              onChanged: (value) {
                                // TODO: Handle email change
                              },
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              decoration: InputDecoration(
                                labelText: 'Email Password/API Key',
                                border: const OutlineInputBorder(),
                                labelStyle: TextStyle(color: colorScheme.onSurface),
                              ),
                              obscureText: true,
                              onChanged: (value) {
                                // TODO: Handle password change
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Appearance',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Dark Mode',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                Switch(
                                  value: context.watch<ThemeProvider>().isDarkMode,
                                  onChanged: (value) {
                                    context.read<ThemeProvider>().toggleTheme();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'File Management',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              title: Text(
                                'Default Output Directory',
                                style: TextStyle(color: colorScheme.onSurface),
                              ),
                              subtitle: Text(
                                'Select where generated files are saved',
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                              trailing: Icon(Icons.folder_open, color: colorScheme.primary),
                              onTap: () {
                                // TODO: Implement directory selection
                              },
                            ),
                            const Divider(),
                            ListTile(
                              title: Text(
                                'Clear Generated Files',
                                style: TextStyle(color: colorScheme.onSurface),
                              ),
                              subtitle: Text(
                                'Remove all generated files',
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                              trailing: Icon(Icons.delete_forever, color: colorScheme.error),
                              onTap: () {
                                // TODO: Implement clear files
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 