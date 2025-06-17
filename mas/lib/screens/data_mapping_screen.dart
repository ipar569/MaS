import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:excel/excel.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'dart:math';

class DataMappingScreen extends StatefulWidget {
  final String templatePath;
  final String initialPattern;

  const DataMappingScreen({
    super.key,
    required this.templatePath,
    required this.initialPattern,
  });

  @override
  State<DataMappingScreen> createState() => _DataMappingScreenState();
}

class _DataMappingScreenState extends State<DataMappingScreen> {
  List<String> templateFields = [];
  List<String> dataColumns = [];
  List<Map<String, dynamic>> dataRows = [];
  Map<String, String> fieldMappings = {};
  bool isGenerating = false;
  int currentProgress = 0;
  int totalFiles = 0;
  String? generationError;
  String? outputDirectory;
  late String pattern;
  final Map<String, String> patternMap = {
    '<<>>': 'Double Angle Brackets (<< >>)',
    '{{}}': 'Double Curly Braces ({{ }})',
    '[]': 'Square Brackets ([ ])',
    '()': 'Parentheses (( ))',
  };

  // File naming options
  bool includeDate = false;
  bool includeTime = false;
  String customText = '';
  String? selectedField;
  bool useIncrementingNumber = false;
  String numberSeparator = '_';
  int startNumber = 1;
  int numberPadding = 3;

  // Controllers for text fields
  final TextEditingController customTextController = TextEditingController();
  final TextEditingController dateFormatController = TextEditingController(text: 'yyyyMMdd');
  final TextEditingController numberSeparatorController = TextEditingController(text: '-');
  final TextEditingController startNumberController = TextEditingController(text: '1');
  final TextEditingController numberPaddingController = TextEditingController(text: '3');

  String? dataPath;

  @override
  void initState() {
    super.initState();
    // Initialize pattern from widget or use default
    pattern = widget.initialPattern.isNotEmpty ? widget.initialPattern : '<<>>';
    print('Initializing DataMappingScreen with pattern: $pattern'); // Debug log
    
    // Extract template fields after a short delay to ensure widget is initialized
    Future.delayed(const Duration(milliseconds: 100), () {
      _extractTemplateFields();
    });
  }

  @override
  void dispose() {
    customTextController.dispose();
    dateFormatController.dispose();
    numberSeparatorController.dispose();
    startNumberController.dispose();
    numberPaddingController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (dataPath == null) return;

    try {
      final bytes = await File(dataPath!).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables.keys.first;
      final rows = excel.tables[sheet]!.rows;

      if (rows.isEmpty) return;

      // Get column headers
      dataColumns = rows[0]
          .map((cell) => cell?.value?.toString() ?? '')
          .where((header) => header.isNotEmpty)
          .toList();

      // Get data rows
      dataRows = rows.skip(1).map((row) {
        final map = <String, dynamic>{};
        for (var i = 0; i < dataColumns.length; i++) {
          map[dataColumns[i]] = row[i]?.value;
        }
        return map;
      }).toList();

      // Auto-map fields based on column names
      _autoMapFields();

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  void _autoMapFields() {
    if (templateFields.isEmpty || dataColumns.isEmpty) return;

    // Create a map of lowercase field names to their original case
    final lowercaseFields = templateFields.fold<Map<String, String>>({}, (map, field) {
      map[field.toLowerCase()] = field;
      return map;
    });

    // Try to match columns to fields
    for (final column in dataColumns) {
      final lowercaseColumn = column.toLowerCase();
      
      // Try exact match first
      if (lowercaseFields.containsKey(lowercaseColumn)) {
        fieldMappings[lowercaseFields[lowercaseColumn]!] = column;
        continue;
      }

      // Try removing spaces and special characters
      final normalizedColumn = lowercaseColumn.replaceAll(RegExp(r'[^a-z0-9]'), '');
      for (final field in lowercaseFields.keys) {
        final normalizedField = field.replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (normalizedColumn == normalizedField) {
          fieldMappings[lowercaseFields[field]!] = column;
          break;
        }
      }
    }

    print('Auto-mapped fields: $fieldMappings');
  }

  Future<void> _pickDataFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result != null && result.files.first.path != null) {
        setState(() {
          dataPath = result.files.first.path;
        });
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking data file: $e')),
        );
      }
    }
  }

  Future<void> _extractTemplateFields() async {
    if (widget.templatePath == null) return;

    try {
      final bytes = await File(widget.templatePath!).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final docFile = archive.files.firstWhere((f) => f.name == 'word/document.xml');
      final xmlString = utf8.decode(docFile.content as List<int>);
      
      print('=== Template Field Extraction Debug ===');
      print('Template path: ${widget.templatePath}');
      print('Selected pattern: $pattern');
      
      // Parse the XML document
      final document = XmlDocument.parse(xmlString);
      final body = document.findAllElements('w:body').first;
      final text = body.text;
      
      print('Document text length: ${text.length}');
      print('First 500 chars of text: ${text.substring(0, min(500, text.length))}');
      
      // Get the correct pattern based on the selected pattern
      String searchPattern;
      switch (pattern) {
        case '<<>>':
          searchPattern = r'<<([^>]+)>>';
          break;
        case '{{}}':
          searchPattern = r'\{\{([^}]+)\}\}';
          break;
        case '[]':
          searchPattern = r'\[([^\]]+)\]';
          break;
        case '()':
          searchPattern = r'\(([^)]+)\)';
          break;
        default:
          searchPattern = r'\{\{([^}]+)\}\}';
      }
      
      print('Using search pattern: $searchPattern');
      final regex = RegExp(searchPattern);
      final matches = regex.allMatches(text);
      print('Number of matches found: ${matches.length}');
      
      // Log each match in detail
      matches.forEach((match) {
        print('Found field: ${match.group(0)}');
        print('Field name: ${match.group(1)}');
        print('Position: ${match.start} to ${match.end}');
      });
      
      // Extract unique field names
      final newFields = matches
          .map((match) => match.group(1) ?? '')
          .where((field) => field.isNotEmpty)
          .toSet()
          .toList();
          
      print('Extracted fields: $newFields');
      
      if (newFields.isEmpty) {
        print('WARNING: No fields found in template!');
        print('Document text preview (first 2000 chars):');
        print(text.substring(0, min(2000, text.length)));
      }
      
      setState(() {
        templateFields = newFields;
      });
    } catch (e, stackTrace) {
      print('Error extracting template fields: $e');
      print('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error extracting template fields: $e')),
      );
    }
  }

  Future<void> _selectOutputDirectory() async {
    final directory = await FilePicker.platform.getDirectoryPath();
    if (directory != null) {
      setState(() {
        outputDirectory = directory;
      });
    }
  }

  String _generateFileName(int index, Map<String, dynamic> row) {
    final parts = <String>[];

    // Add date if enabled
    if (includeDate) {
      final now = DateTime.now();
      final formatter = DateFormat(dateFormatController.text);
      parts.add(formatter.format(now));
    }

    // Add time if enabled
    if (includeTime) {
      final now = DateTime.now();
      final formatter = DateFormat('HHmmss');
      parts.add(formatter.format(now));
    }

    // Add custom text if provided
    if (customText.isNotEmpty) {
      parts.add(customText);
    }

    // Add selected field value if any
    if (selectedField != null && row[selectedField] != null) {
      parts.add(row[selectedField].toString());
    }

    // Add incrementing number if enabled
    if (useIncrementingNumber) {
      final number = (startNumber + index).toString().padLeft(numberPadding, '0');
      parts.add(number);
    }

    // Join all parts with the separator
    return parts.join(numberSeparator);
  }

  Future<void> _generateFiles() async {
    if (templateFields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No template fields detected')),
      );
      return;
    }

    if (dataColumns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data columns available')),
      );
      return;
    }

    // Validate field mappings
    final unmappedFields = templateFields.where((field) => 
      fieldMappings[field] == null || fieldMappings[field]!.isEmpty
    ).toList();

    if (unmappedFields.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please map all fields: ${unmappedFields.join(", ")}'),
        ),
      );
      return;
    }

    setState(() {
      isGenerating = true;
      currentProgress = 0;
      generationError = null;
    });

    try {
      // Read the template file
      final templateBytes = await File(widget.templatePath!).readAsBytes();
      final archive = ZipDecoder().decodeBytes(templateBytes);
      
      // Calculate total files to generate
      totalFiles = dataRows.length;
      
      // Create output directory if it doesn't exist
      final outputDir = Directory(outputDirectory ?? '');
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      for (var i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        // Find document.xml
        final docFile = archive.files.firstWhere((f) => f.name == 'word/document.xml');
        final xmlString = utf8.decode(docFile.content as List<int>);
        var newXmlString = xmlString;
        
        // Replace placeholders
        for (final field in templateFields) {
          final column = fieldMappings[field]!;
          final value = row[column]?.toString() ?? '';
          String placeholder;
          switch (pattern) {
            case '<<>>':
              placeholder = '<<$field>>';
              break;
            case '{{}}':
              placeholder = '{{$field}}';
              break;
            case '[]':
              placeholder = '[$field]';
              break;
            case '()':
              placeholder = '($field)';
              break;
            default:
              placeholder = '{{$field}}';
          }
          newXmlString = newXmlString.replaceAll(placeholder, value);
        }
        
        // Create new archive
        final newArchive = Archive();
        for (final file in archive.files) {
          if (file.name == 'word/document.xml') {
            final contentBytes = utf8.encode(newXmlString);
            newArchive.addFile(ArchiveFile(file.name, contentBytes.length, contentBytes));
          } else {
            newArchive.addFile(ArchiveFile(file.name, file.size, file.content));
          }
        }
        
        // Generate filename
        final fileName = _generateFileName(i, row);
        final outputPath = path.join(outputDirectory!, '$fileName.docx');
        
        // Save new docx
        final outputBytes = ZipEncoder().encode(newArchive)!;
        await File(outputPath).writeAsBytes(outputBytes);
        
        setState(() {
          currentProgress = i + 1;
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully generated $totalFiles files'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        generationError = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isGenerating = false;
      });
    }
  }

  void _showPatternDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Field Pattern'),
        content: DropdownButtonFormField<String>(
          value: pattern,
          items: patternMap.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: (value) async {
            if (value != null && value != pattern) {
              Navigator.pop(context);
              
              // Update pattern
              setState(() {
                pattern = value;
              });
              
              // Clear existing fields and mappings
              templateFields.clear();
              fieldMappings.clear();
              
              // Re-extract fields with new pattern
              await _extractTemplateFields();
              
              // Re-run auto-mapping if we have data
              if (dataColumns.isNotEmpty) {
                _autoMapFields();
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showOutputSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Output File Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('File Name Components:'),
                CheckboxListTile(
                  title: const Text('Include Date'),
                  value: includeDate,
                  onChanged: (value) {
                    setState(() {
                      includeDate = value ?? false;
                    });
                  },
                ),
                if (includeDate)
                  TextField(
                    controller: dateFormatController,
                    decoration: const InputDecoration(
                      labelText: 'Date Format',
                      hintText: 'yyyyMMdd',
                    ),
                  ),
                CheckboxListTile(
                  title: const Text('Include Time'),
                  value: includeTime,
                  onChanged: (value) {
                    setState(() {
                      includeTime = value ?? false;
                    });
                  },
                ),
                TextField(
                  controller: customTextController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Text',
                    hintText: 'Enter custom text for filename',
                  ),
                  onChanged: (value) {
                    setState(() {
                      customText = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                const Text('Select Field from Data:'),
                DropdownButton<String>(
                  value: selectedField,
                  isExpanded: true,
                  hint: const Text('Select a field'),
                  items: dataColumns.map((column) {
                    return DropdownMenuItem(
                      value: column,
                      child: Text(column),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedField = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Use Incrementing Number'),
                  value: useIncrementingNumber,
                  onChanged: (value) {
                    setState(() {
                      useIncrementingNumber = value ?? false;
                    });
                  },
                ),
                if (useIncrementingNumber) ...[
                  TextField(
                    controller: numberSeparatorController,
                    decoration: const InputDecoration(
                      labelText: 'Number Separator',
                      hintText: '-',
                    ),
                    onChanged: (value) {
                      setState(() {
                        numberSeparator = value;
                      });
                    },
                  ),
                  TextField(
                    controller: startNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Start Number',
                      hintText: '1',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        startNumber = int.tryParse(value) ?? 1;
                      });
                    },
                  ),
                  TextField(
                    controller: numberPaddingController,
                    decoration: const InputDecoration(
                      labelText: 'Number Padding',
                      hintText: '3',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        numberPadding = int.tryParse(value) ?? 3;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Preview:'),
                const SizedBox(height: 8),
                Text(
                  _generateFileName(0, dataRows.isNotEmpty ? dataRows[0] : {}),
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                this.setState(() {
                  // Update all the state variables
                  includeDate = includeDate;
                  includeTime = includeTime;
                  customText = customTextController.text;
                  selectedField = selectedField;
                  useIncrementingNumber = useIncrementingNumber;
                  numberSeparator = numberSeparatorController.text;
                  startNumber = int.tryParse(startNumberController.text) ?? 1;
                  numberPadding = int.tryParse(numberPaddingController.text) ?? 3;
                });
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldMappingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Field Mapping',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _showPatternDialog,
                      icon: const Icon(Icons.settings),
                      label: Text('Pattern: ${patternMap[pattern]}'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _autoMapFields,
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Auto Map'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (templateFields.isEmpty)
              const Center(
                child: Text('No template fields detected'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: templateFields.length,
                itemBuilder: (context, index) {
                  final field = templateFields[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(field),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButton<String>(
                            value: fieldMappings[field] ?? '',
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Select a column'),
                              ),
                              ...dataColumns.map((column) => DropdownMenuItem(
                                value: column,
                                child: Text(column),
                              )),
                            ],
                            onChanged: (value) {
                              setState(() {
                                fieldMappings[field] = value ?? '';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutputSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Output Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showOutputSettingsDialog,
                  icon: const Icon(Icons.settings),
                  label: const Text('Configure'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Output Directory'),
              subtitle: Text(outputDirectory ?? 'Not selected'),
              trailing: ElevatedButton(
                onPressed: _selectOutputDirectory,
                child: const Text('Select'),
              ),
            ),
            if (outputDirectory != null) ...[
              const Divider(),
              const Text('Current Settings:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (includeDate)
                    Chip(label: Text('Date: ${dateFormatController.text}')),
                  if (includeTime)
                    const Chip(label: Text('Time')),
                  if (customText.isNotEmpty)
                    Chip(label: Text('Text: $customText')),
                  if (selectedField != null)
                    Chip(label: Text('Field: $selectedField')),
                  if (useIncrementingNumber)
                    Chip(
                      label: Text(
                        'Number: ${startNumber.toString().padLeft(numberPadding, '0')}',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Preview:'),
              Text(
                _generateFileName(0, dataRows.isNotEmpty ? dataRows[0] : {}),
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGenerationProgress() {
    if (!isGenerating) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generation Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: totalFiles > 0 ? currentProgress / totalFiles : 0,
            ),
            const SizedBox(height: 8),
            Text('Generating file $currentProgress of $totalFiles'),
            if (generationError != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error: $generationError',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Mapping'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data File',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (dataPath == null)
                      ElevatedButton.icon(
                        onPressed: _pickDataFile,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Select Data File (Excel/CSV)'),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.table_chart),
                            title: Text(path.basename(dataPath!)),
                            subtitle: Text(dataPath!),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _pickDataFile,
                            icon: const Icon(Icons.edit),
                            label: const Text('Change Data File'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildFieldMappingSection(),
            const SizedBox(height: 16),
            _buildOutputSettingsSection(),
            const SizedBox(height: 16),
            _buildGenerationProgress(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isGenerating ? null : _generateFiles,
              child: Text(isGenerating ? 'Generating...' : 'Generate Files'),
            ),
          ],
        ),
      ),
    );
  }
} 