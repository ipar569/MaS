import 'package:flutter/material.dart';

class TemplateManagementScreen extends StatelessWidget {
  const TemplateManagementScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Template Management'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Templates',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement template upload
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload Template'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: ListView.builder(
                  itemCount: 0, // TODO: Replace with actual template list
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.description),
                      title: const Text('Template Name'),
                      subtitle: const Text('Last modified: Date'),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'generate',
                            child: Text('Generate Files'),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                        onSelected: (value) {
                          // TODO: Handle menu item selection
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Show file generation dialog
        },
        icon: const Icon(Icons.file_upload),
        label: const Text('Generate Files'),
      ),
    );
  }
} 