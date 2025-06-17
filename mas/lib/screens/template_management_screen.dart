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
  List<FileSystemEntity> templates = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => isLoading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final templatesDir = Directory('${directory.path}/templates');
      if (!await templatesDir.exists()) {
        await templatesDir.create(recursive: true);
      }
      final files = await templatesDir.list().toList();
      setState(() {
        templates = files.where((file) {
          final extension = path.extension(file.path).toLowerCase();
          return extension == '.docx' || extension == '.pdf';
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading templates: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _uploadTemplate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx', 'pdf'],
      );

      if (result != null) {
        final file = result.files.first;
        final directory = await getApplicationDocumentsDirectory();
        final templatesDir = Directory('${directory.path}/templates');
        if (!await templatesDir.exists()) {
          await templatesDir.create(recursive: true);
        }

        final newPath = '${templatesDir.path}/${file.name}';
        final newFile = File(newPath);
        await newFile.writeAsBytes(await File(file.path!).readAsBytes());

        await _loadTemplates();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Template uploaded successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading template: $e')),
        );
      }
    }
  }

  Future<void> _deleteTemplate(FileSystemEntity file) async {
    try {
      await file.delete();
      await _loadTemplates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting template: $e')),
        );
      }
    }
  }

  void _navigateToDataMapping(FileSystemEntity file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DataMappingScreen(
          templatePath: file.path,
          templateName: path.basename(file.path),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Templates',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onBackground,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _uploadTemplate,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload Template'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Card(
                      child: templates.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 64,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No templates uploaded yet',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Upload a Word or PDF document to get started',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: templates.length,
                              itemBuilder: (context, index) {
                                final file = templates[index];
                                final fileName = path.basename(file.path);
                                final fileExtension = path.extension(file.path).toLowerCase();
                                
                                return ListTile(
                                  leading: Icon(
                                    fileExtension == '.pdf'
                                        ? Icons.picture_as_pdf
                                        : Icons.description,
                                    color: colorScheme.primary,
                                  ),
                                  title: Text(
                                    fileName,
                                    style: TextStyle(color: colorScheme.onSurface),
                                  ),
                                  subtitle: Text(
                                    'Last modified: ${File(file.path).lastModifiedSync()}',
                                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                                  ),
                                  onTap: () => _navigateToDataMapping(file),
                                  trailing: PopupMenuButton(
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'generate',
                                        child: Text('Generate Files'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                    onSelected: (value) async {
                                      if (value == 'generate') {
                                        _navigateToDataMapping(file);
                                      } else if (value == 'delete') {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Template'),
                                            content: Text(
                                                'Are you sure you want to delete "$fileName"?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context, true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          await _deleteTemplate(file);
                                        }
                                      }
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
    );
  }
} 