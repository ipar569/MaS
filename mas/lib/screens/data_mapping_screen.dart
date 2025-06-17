import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';

class DataMappingScreen extends StatefulWidget {
  final String templatePath;
  final String templateName;

  const DataMappingScreen({
    Key? key,
    required this.templatePath,
    required this.templateName,
  }) : super(key: key);

  @override
  State<DataMappingScreen> createState() => _DataMappingScreenState();
}

class _DataMappingScreenState extends State<DataMappingScreen> {
  bool isLoading = false;
  bool hasHeaders = true;
  String? dataFilePath;
  List<List<String>> data = [];
  List<String> headers = [];
  List<String> templateFields = [];
  Map<String, String> fieldMappings = {};
  String namingConvention = '';
  String? outputDirectory;
  bool isAutoDetecting = false;

  @override
  void initState() {
    super.initState();
    _extractTemplateFields();
  }

  Future<void> _extractTemplateFields() async {
    setState(() => isLoading = true);
    try {
      final ext = path.extension(widget.templatePath).toLowerCase();
      String content = '';
      if (ext == '.docx') {
        // Unzip the docx and read word/document.xml
        final bytes = await File(widget.templatePath).readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        final docXmlFile = archive.files.firstWhere(
          (file) => file.name == 'word/document.xml',
          orElse: () => throw Exception('word/document.xml not found in docx'),
        );
        final xmlString = String.fromCharCodes(docXmlFile.content as List<int>);
        final document = XmlDocument.parse(xmlString);
        // Join all <w:t> nodes
        final textNodes = document.findAllElements('w:t');
        content = textNodes.map((node) => node.text).join('');
      } else {
        content = await File(widget.templatePath).readAsString();
      }
      // Extract fields wrapped in << >>
      final regex = RegExp(r'<<([^>]+)>>');
      final matches = regex.allMatches(content);
      setState(() {
        templateFields = matches.map((m) => m.group(1)!).toSet().toList();
        templateFields.sort();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error extracting template fields: $e')),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickDataFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );

      if (result != null && result.files.first.path != null) {
        setState(() {
          dataFilePath = result.files.first.path;
          isLoading = true;
        });

        await _loadDataFile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _loadDataFile() async {
    try {
      if (dataFilePath == null) return;

      final extension = path.extension(dataFilePath!).toLowerCase();
      if (extension == '.csv') {
        await _loadCsvFile();
      } else if (extension == '.xlsx') {
        await _loadExcelFile();
      }

      if (hasHeaders && data.isNotEmpty) {
        headers = data[0];
        data = data.sublist(1);
      } else {
        headers = List.generate(data[0].length, (index) => 'Column ${index + 1}');
      }

      _autoDetectMappings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data file: $e')),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadCsvFile() async {
    final file = File(dataFilePath!);
    final lines = await file.readAsLines();
    data = lines.map((line) => line.split(',').map((cell) => cell.trim()).toList()).toList();
  }

  Future<void> _loadExcelFile() async {
    final bytes = await File(dataFilePath!).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.keys.first;
    data = excel.tables[sheet]!.rows.map((row) {
      return row.map((cell) => cell?.value?.toString() ?? '').toList();
    }).toList();
  }

  void _autoDetectMappings() {
    setState(() => isAutoDetecting = true);
    try {
      for (final field in templateFields) {
        final matchingHeader = headers.firstWhere(
          (header) => header.toLowerCase() == field.toLowerCase(),
          orElse: () => '',
        );
        if (matchingHeader.isNotEmpty) {
          fieldMappings[field] = matchingHeader;
        }
      }
    } finally {
      setState(() => isAutoDetecting = false);
    }
  }

  Future<void> _selectOutputDirectory() async {
    try {
      final directory = await FilePicker.platform.getDirectoryPath();
      if (directory != null) {
        setState(() => outputDirectory = directory);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting directory: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Mapping'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
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
                              'Data File',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dataFilePath ?? 'No file selected',
                                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _pickDataFile,
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Select File'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Checkbox(
                                  value: hasHeaders,
                                  onChanged: (value) {
                                    setState(() {
                                      hasHeaders = value ?? true;
                                    });
                                    if (dataFilePath != null) {
                                      _loadDataFile();
                                    }
                                  },
                                ),
                                Text(
                                  'File contains headers',
                                  style: TextStyle(color: colorScheme.onSurface),
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
                              'Detected Template Fields',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (templateFields.isEmpty)
                              Text(
                                'No fields detected. Make sure your template contains placeholders like <<name>>.',
                                style: TextStyle(color: colorScheme.error),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                children: templateFields.map((field) => Chip(
                                  label: Text('<<$field>>'),
                                )).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (data.isNotEmpty) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Imported Data Columns',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: headers.map((header) => Chip(
                                  label: Text(header),
                                )).toList(),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Field Mappings',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _autoDetectMappings,
                                    icon: const Icon(Icons.auto_fix_high),
                                    label: const Text('Auto-detect'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ...templateFields.map((field) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '<<$field>>',
                                            style: TextStyle(color: colorScheme.onSurface),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          flex: 3,
                                          child: DropdownButton<String>(
                                            value: fieldMappings[field],
                                            isExpanded: true,
                                            hint: const Text('Select column'),
                                            items: headers.map((header) {
                                              return DropdownMenuItem(
                                                value: header,
                                                child: Text(header),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              if (value != null) {
                                                setState(() {
                                                  fieldMappings[field] = value;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                              const SizedBox(height: 16),
                              Divider(),
                              Text(
                                'Current Mappings:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...templateFields.map((field) => Text(
                                '<<$field>> → ${fieldMappings[field] ?? "(not mapped)"}',
                                style: TextStyle(
                                  color: fieldMappings[field] != null ? colorScheme.onSurface : colorScheme.error,
                                ),
                              )),
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
                                'Output Settings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                decoration: InputDecoration(
                                  labelText: 'File Naming Convention',
                                  hintText: 'e.g., {name}_document_{index}',
                                  border: const OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  setState(() => namingConvention = value);
                                },
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      outputDirectory ?? 'No output directory selected',
                                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _selectOutputDirectory,
                                    icon: const Icon(Icons.folder_open),
                                    label: const Text('Select Directory'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Add extra space at the bottom so the floating button doesn't cover content
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implement file generation
        },
        icon: const Icon(Icons.file_upload),
        label: const Text('Generate Files'),
      ),
    );
  }
} 