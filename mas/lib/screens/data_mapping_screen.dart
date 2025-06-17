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
import 'package:docx_template/docx_template.dart';

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
    print('=== Auto Mapping Debug ===');
    print('Template fields: $templateFields');
    print('Data columns: $dataColumns');
    
    // Create a map of lowercase field names to their original case
    final fieldMap = {
      for (var field in templateFields)
        field.toLowerCase(): field
    };
    
    print('Field map: $fieldMap');
    
    // Try to match data columns to template fields
    for (final column in dataColumns) {
      print('\nTrying to match column: $column');
      
      // Try exact match first
      if (fieldMap.containsKey(column.toLowerCase())) {
        final field = fieldMap[column.toLowerCase()]!;
        print('Found exact match for $column -> $field');
        fieldMappings[field] = column;
        continue;
      }
      
      // Try normalized match (remove spaces and special characters)
      final normalizedColumn = column.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      print('Normalized column: $normalizedColumn');
      
      for (final field in templateFields) {
        final normalizedField = field.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        print('Comparing with normalized field: $normalizedField');
        
        if (normalizedColumn == normalizedField) {
          print('Found normalized match for $column -> $field');
          fieldMappings[field] = column;
          break;
        }
      }
    }
    
    print('Final field mappings: $fieldMappings');
    setState(() {});
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
      print('=== Template Field Extraction Debug ===');
      print('Template path: ${widget.templatePath}');
      print('Selected pattern: $pattern');
      
      // Read the template file
      final bytes = await File(widget.templatePath!).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final docFile = archive.files.firstWhere((f) => f.name == 'word/document.xml');
      final xmlString = utf8.decode(docFile.content as List<int>);
      
      print('XML content length: ${xmlString.length}');
      print('First 500 chars of XML: ${xmlString.substring(0, min(500, xmlString.length))}');
      
      List<String> fields = [];
      
      if (pattern == '<<>>') {
        print('Processing double angle pattern...');
        // Try both raw and HTML-encoded patterns
        final patterns = [
          ['<<', '>>'],  // Raw pattern
          ['&lt;&lt;', '&gt;&gt;'],  // HTML encoded
        ];
        
        for (final patternPair in patterns) {
          final startMarker = patternPair[0];
          final endMarker = patternPair[1];
          print('Trying pattern with markers: $startMarker and $endMarker');
          
          int startIndex = 0;
          while (true) {
            startIndex = xmlString.indexOf(startMarker, startIndex);
            if (startIndex == -1) break;
            
            final endIndex = xmlString.indexOf(endMarker, startIndex);
            if (endIndex == -1) break;
            
            final field = xmlString.substring(startIndex + startMarker.length, endIndex);
            print('Found field: $startMarker$field$endMarker');
            fields.add(field);
            
            startIndex = endIndex + endMarker.length;
          }
        }
      } else {
        // Get the correct pattern based on the selected pattern
        String searchPattern;
        switch (pattern) {
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
        final matches = regex.allMatches(xmlString);
        
        fields = matches
            .map((match) => match.group(1) ?? '')
            .where((field) => field.isNotEmpty)
            .toList();
      }
      
      print('Extracted fields: $fields');
      
      if (fields.isEmpty) {
        print('WARNING: No fields found in template!');
        print('Document text preview (first 2000 chars):');
        print(xmlString.substring(0, min(2000, xmlString.length)));
      }
      
      setState(() {
        templateFields = fields;
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
    if (widget.templatePath == null) return;

    setState(() {
      isGenerating = true;
      generationError = null;
    });

    try {
      print('=== File Generation Debug ===');
      print('Template path: ${widget.templatePath}');
      print('Number of data rows: ${dataRows.length}');
      print('Field mappings: $fieldMappings');
      print('Data columns: $dataColumns');
      
      // Create output directory if it doesn't exist
      final outputDir = outputDirectory ?? 'generated_documents';
      await Directory(outputDir).create(recursive: true);
      
      // Read the template file
      final bytes = await File(widget.templatePath!).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      // Generate a file for each row
      for (var i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        print('\nProcessing row $i:');
        print('Row data: $row');
        
        // Create a new document for each row
        final newArchive = Archive();
        
        // Copy all files from the original archive
        for (final file in archive.files) {
          if (file.name == 'word/document.xml') {
            // Get the XML content
            var xmlContent = utf8.decode(file.content as List<int>);
            print('Original XML content length: ${xmlContent.length}');
            
            if (pattern == '<<>>') {
              print('Processing double angle pattern...');
              // Process each field mapping
              for (final entry in fieldMappings.entries) {
                final field = entry.key;
                final column = entry.value;
                final value = row[column]?.toString() ?? '';
                print('Replacing field: <<$field>> with value: $value');
                
                // Try both raw and HTML-encoded patterns
                xmlContent = xmlContent
                    .replaceAll('<<$field>>', value)
                    .replaceAll('&lt;&lt;$field&gt;&gt;', value);
              }
            } else {
              // Get the correct pattern based on the selected pattern
              String searchPattern;
              switch (pattern) {
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
              
              // Find all field matches
              final matches = regex.allMatches(xmlContent);
              print('Found ${matches.length} field matches in template');
              
              // Create a map of replacements
              final replacements = <String, String>{};
              
              // Process each match
              for (final match in matches) {
                final fieldName = match.group(1);
                if (fieldName != null) {
                  print('Processing field: $fieldName');
                  final mappedColumn = fieldMappings[fieldName];
                  if (mappedColumn != null) {
                    final value = row[mappedColumn]?.toString() ?? '';
                    print('Mapped to column: $mappedColumn, value: $value');
                    
                    // Store the replacement
                    replacements[match.group(0)!] = value;
                  } else {
                    print('Warning: No mapping found for field: $fieldName');
                  }
                }
              }
              
              // Apply all replacements
              for (final entry in replacements.entries) {
                print('Replacing ${entry.key} with ${entry.value}');
                xmlContent = xmlContent.replaceAll(entry.key, entry.value);
              }
            }
            
            print('Modified XML content length: ${xmlContent.length}');
            
            // Add the modified document.xml
            newArchive.addFile(ArchiveFile(
              file.name,
              utf8.encode(xmlContent).length,
              utf8.encode(xmlContent),
            ));
          } else {
            // Copy other files as is
            newArchive.addFile(file);
          }
        }
        
        // Generate output filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final outputPath = '$outputDir/document_${i + 1}_$timestamp.docx';
        
        // Save the modified document
        final outputBytes = ZipEncoder().encode(newArchive);
        if (outputBytes != null) {
          await File(outputPath).writeAsBytes(outputBytes);
          print('Generated file: $outputPath');
        }
      }
      
      setState(() {
        isGenerating = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generated ${dataRows.length} documents in $outputDir')),
      );
    } catch (e, stackTrace) {
      print('Error generating files: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        isGenerating = false;
        generationError = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating files: $e')),
      );
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