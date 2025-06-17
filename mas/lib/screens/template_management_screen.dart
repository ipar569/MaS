import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'data_mapping_screen.dart';

class TemplateManagementScreen extends StatefulWidget {
  const TemplateManagementScreen({Key? key}) : super(key: key);

  @override
  State<TemplateManagementScreen> createState() => _TemplateManagementScreenState();
}

class _TemplateManagementScreenState extends State<TemplateManagementScreen> {
  String? templatePath;
  String? templateName;
  bool isLoading = false;
  String pattern = '<<>>'; // Set default to <<>>
  final Map<String, String> patternMap = {
    '<<>>': 'Double Angle Brackets (<< >>)',
    '{{}}': 'Double Curly Braces ({{ }})',
    '[]': 'Square Brackets ([ ])',
    '()': 'Parentheses (( ))',
  };

  String _getExample(String pattern) {
    switch (pattern) {
      case '<<>>':
        return '<<field>>';
      case '{{}}':
        return '{{field}}';
      case '[]':
        return '[field]';
      case '()':
        return '(field)';
      default:
        return '<<field>>';
    }
  }

  Future<void> _pickTemplate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx'],
      );

      if (result != null && result.files.first.path != null) {
        setState(() {
          templatePath = result.files.first.path;
          templateName = path.basename(result.files.first.path!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking template: $e')),
        );
      }
    }
  }

  void _navigateToDataMapping() {
    if (templatePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a template first')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DataMappingScreen(
          templatePath: templatePath!,
          initialPattern: pattern, // This will now always have a value
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Template Management'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Template Selection',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(text: templateName),
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Selected Template',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _pickTemplate,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Select Template'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: pattern,
                            decoration: InputDecoration(
                              labelText: 'Field Pattern',
                              border: const OutlineInputBorder(),
                              helperText: 'Example: ${_getExample(pattern)}',
                            ),
                            items: patternMap.entries.map((entry) {
                              return DropdownMenuItem(
                                value: entry.key,
                                child: Text('${entry.value} (Example: ${_getExample(entry.key)})'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  pattern = value;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _navigateToDataMapping,
                          icon: const Icon(Icons.data_array),
                          label: const Text('Map Data to Template'),
                        ),
                      ],
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