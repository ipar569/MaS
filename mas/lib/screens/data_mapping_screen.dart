import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:excel/excel.dart';
import 'package:archive/archive.dart';
import 'dart:convert';
import 'dart:math';
import 'package:docx_template/docx_template.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class DataMappingScreen extends StatefulWidget {
  final String templatePath;
  final String initialPattern;

  const DataMappingScreen({
    Key? key,
    required this.templatePath,
    this.initialPattern = '',
  }) : super(key: key);

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
  List<Map<String, dynamic>> customTexts = []; // List of custom texts with IDs
  List<Map<String, dynamic>> fieldValues = []; // List of field values with IDs
  bool useIncrementingNumber = false;
  String numberSeparator = '_';
  int startNumber = 1;
  int numberPadding = 3;
  String dateFormat = 'yyyyMMdd';
  String timeFormat = 'HHmmss';
  bool useCustomSeparator = false;
  String customSeparator = '_';
  List<String> componentOrder = [];

  // Controllers for text fields
  final Map<String, TextEditingController> customTextControllers = {};
  final TextEditingController dateFormatController = TextEditingController(text: 'yyyyMMdd');
  final TextEditingController timeFormatController = TextEditingController(text: 'HHmmss');
  final TextEditingController numberSeparatorController = TextEditingController(text: '_');
  final TextEditingController startNumberController = TextEditingController(text: '1');
  final TextEditingController numberPaddingController = TextEditingController(text: '3');
  final TextEditingController customSeparatorController = TextEditingController(text: '_');

  String? dataPath;

  @override
  void initState() {
    super.initState();
    // Initialize pattern from widget or use default
    pattern = widget.initialPattern.isNotEmpty ? widget.initialPattern : '<<>>';
    print('Initializing DataMappingScreen with pattern: $pattern'); // Debug log
    
    // Initialize output directory
    _initializeOutputDirectory();
    
    // Extract template fields after a short delay to ensure widget is initialized
    Future.delayed(const Duration(milliseconds: 100), () {
      _extractTemplateFields();
    });
  }

  @override
  void dispose() {
    customTextControllers.values.forEach((controller) => controller.dispose());
    dateFormatController.dispose();
    timeFormatController.dispose();
    numberSeparatorController.dispose();
    startNumberController.dispose();
    numberPaddingController.dispose();
    customSeparatorController.dispose();
    super.dispose();
  }

  Future<void> _initializeOutputDirectory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedDir = prefs.getString('lastOutputDirectory');
      
      if (savedDir == null) {
        // Set default directory in app's documents folder
        final appDir = await getApplicationDocumentsDirectory();
        savedDir = '${appDir.path}/generated_documents';
        
        // Create the directory if it doesn't exist
        final dir = Directory(savedDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        
        await prefs.setString('lastOutputDirectory', savedDir);
      } else {
        // Verify the saved directory exists
        final dir = Directory(savedDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }
      
      if (mounted) {
        setState(() {
          outputDirectory = savedDir;
        });
      }
    } catch (e) {
      print('Error initializing output directory: $e');
      // Set a fallback directory
      if (mounted) {
        setState(() {
          outputDirectory = 'generated_documents';
        });
      }
    }
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
    try {
      // Use FilePicker to select a directory
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Output Directory',
      );

      if (selectedDirectory != null) {
        print('Selected directory: $selectedDirectory'); // Debug log

        // Create the directory if it doesn't exist
        final dir = Directory(selectedDirectory);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        // Save the selected directory
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastOutputDirectory', selectedDirectory);
        
        setState(() {
          outputDirectory = selectedDirectory;
        });

        // Show confirmation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Output directory set to: $selectedDirectory')),
          );
        }
      }
    } catch (e) {
      print('Error selecting directory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting directory: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateFileName(int index, Map<String, dynamic> row) {
    final parts = <String>[];

    // Follow the component order
    for (final component in componentOrder) {
      if (component.startsWith('custom_text_')) {
        final id = component.replaceFirst('custom_text_', '');
        final customText = customTexts.firstWhere(
          (ct) => ct['id'] == id,
          orElse: () => {'text': ''},
        );
        if (customText['text'].isNotEmpty) {
          parts.add(customText['text']);
        }
      } else if (component.startsWith('field_value_')) {
        final id = component.replaceFirst('field_value_', '');
        final fieldValue = fieldValues.firstWhere(
          (fv) => fv['id'] == id,
          orElse: () => {'field': null},
        );
        if (fieldValue['field'] != null && row.containsKey(fieldValue['field'])) {
          final value = row[fieldValue['field']]?.toString() ?? '';
          if (value.isNotEmpty) {
            parts.add(value);
          }
        }
      } else if (component == 'date' && includeDate) {
        final now = DateTime.now();
        final formatter = DateFormat(dateFormat);
        parts.add(formatter.format(now));
      } else if (component == 'time' && includeTime) {
        final now = DateTime.now();
        final formatter = DateFormat(timeFormat);
        parts.add(formatter.format(now));
      } else if (component == 'number' && useIncrementingNumber) {
        final number = startNumber + index;
        parts.add(number.toString().padLeft(numberPadding, '0'));
      }
    }

    // Join all parts with the appropriate separator
    final separator = useCustomSeparator ? customSeparator : numberSeparator;
    return parts.join(separator);
  }

  void _addCustomText() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      customTexts.add({
        'id': id,
        'text': '',
      });
      customTextControllers[id] = TextEditingController();
      componentOrder.add('custom_text_$id');
    });
  }

  void _addFieldValue() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      fieldValues.add({
        'id': id,
        'field': null,
      });
      componentOrder.add('field_value_$id');
    });
  }

  void _removeCustomText(String id) {
    setState(() {
      customTexts.removeWhere((ct) => ct['id'] == id);
      customTextControllers[id]?.dispose();
      customTextControllers.remove(id);
      componentOrder.remove('custom_text_$id');
    });
  }

  void _removeFieldValue(String id) {
    setState(() {
      fieldValues.removeWhere((fv) => fv['id'] == id);
      componentOrder.remove('field_value_$id');
    });
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
            // File Naming Card
            _buildFileNamingSection(),
            const SizedBox(height: 16),
            // Output Directory Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Output Directory',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _selectOutputDirectory,
                          icon: const Icon(Icons.folder),
                          label: const Text('Change Directory'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.folder),
                      title: const Text('Directory'),
                      subtitle: Text(outputDirectory ?? 'Not selected'),
                    ),
                  ],
                ),
              ),
            ),
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
                    DropdownButton<String>(
                      value: pattern,
                      items: patternMap.entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        if (value != null && value != pattern) {
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
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _autoMapFields,
                      tooltip: 'Auto-map Fields',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (templateFields.isEmpty)
              const Center(
                child: Text('No fields found in template'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: templateFields.length,
                itemBuilder: (context, index) {
                  final field = templateFields[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              field,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButton<String>(
                              value: fieldMappings[field],
                              isExpanded: true,
                              hint: const Text('Select column'),
                              items: dataColumns.map((column) {
                                return DropdownMenuItem(
                                  value: column,
                                  child: Text(column),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  if (value == null) {
                                    fieldMappings.remove(field);
                                  } else {
                                    fieldMappings[field] = value;
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileNamingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'File Naming',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Component Order
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Component Order',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: componentOrder.map((component) {
                        String label;
                        IconData icon;
                        if (component.startsWith('custom_text_')) {
                          final id = component.replaceFirst('custom_text_', '');
                          final customText = customTexts.firstWhere(
                            (ct) => ct['id'] == id,
                            orElse: () => {'text': ''},
                          );
                          label = 'Text: ${customText['text']}';
                          icon = Icons.text_fields;
                        } else if (component.startsWith('field_value_')) {
                          final id = component.replaceFirst('field_value_', '');
                          final fieldValue = fieldValues.firstWhere(
                            (fv) => fv['id'] == id,
                            orElse: () => {'field': null},
                          );
                          label = 'Field: ${fieldValue['field'] ?? "None"}';
                          icon = Icons.table_chart;
                        } else {
                          switch (component) {
                            case 'date':
                              label = 'Date: ${dateFormatController.text}';
                              icon = Icons.calendar_today;
                              break;
                            case 'time':
                              label = 'Time: ${timeFormatController.text}';
                              icon = Icons.access_time;
                              break;
                            case 'number':
                              label = 'Number: ${startNumber.toString().padLeft(numberPadding, '0')}';
                              icon = Icons.format_list_numbered;
                              break;
                            default:
                              label = component;
                              icon = Icons.help_outline;
                          }
                        }
                        return ListTile(
                          key: ValueKey(component),
                          leading: Icon(icon),
                          title: Text(label),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              if (component.startsWith('custom_text_')) {
                                _removeCustomText(component.replaceFirst('custom_text_', ''));
                              } else if (component.startsWith('field_value_')) {
                                _removeFieldValue(component.replaceFirst('field_value_', ''));
                              } else {
                                setState(() {
                                  componentOrder.remove(component);
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final item = componentOrder.removeAt(oldIndex);
                          componentOrder.insert(newIndex, item);
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.text_fields),
                          label: const Text('Add Custom Text'),
                          onPressed: _addCustomText,
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.table_chart),
                          label: const Text('Add Field'),
                          onPressed: _addFieldValue,
                        ),
                        if (!componentOrder.contains('date'))
                          ActionChip(
                            avatar: const Icon(Icons.calendar_today),
                            label: const Text('Add Date'),
                            onPressed: () {
                              setState(() {
                                componentOrder.add('date');
                              });
                            },
                          ),
                        if (!componentOrder.contains('time'))
                          ActionChip(
                            avatar: const Icon(Icons.access_time),
                            label: const Text('Add Time'),
                            onPressed: () {
                              setState(() {
                                componentOrder.add('time');
                              });
                            },
                          ),
                        if (!componentOrder.contains('number'))
                          ActionChip(
                            avatar: const Icon(Icons.format_list_numbered),
                            label: const Text('Add Number'),
                            onPressed: () {
                              setState(() {
                                componentOrder.add('number');
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Component Settings
            ...customTexts.map((customText) {
              final id = customText['id'];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Custom Text',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _removeCustomText(id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: customTextControllers[id],
                        decoration: const InputDecoration(
                          labelText: 'Text',
                          hintText: 'Enter text to include',
                          prefixIcon: Icon(Icons.text_fields),
                        ),
                        onChanged: (value) {
                          setState(() {
                            customText['text'] = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

            ...fieldValues.map((fieldValue) {
              final id = fieldValue['id'];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Field Value',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _removeFieldValue(id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: fieldValue['field'],
                        decoration: const InputDecoration(
                          labelText: 'Select Field',
                          prefixIcon: Icon(Icons.table_chart),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('None'),
                          ),
                          ...dataColumns.map((column) {
                            return DropdownMenuItem(
                              value: column,
                              child: Text(column),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            fieldValue['field'] = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

            if (componentOrder.contains('date'))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: includeDate,
                            onChanged: (value) {
                              setState(() {
                                includeDate = value ?? false;
                              });
                            },
                          ),
                          const Text(
                            'Date Format',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (includeDate) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: dateFormatController,
                          decoration: const InputDecoration(
                            labelText: 'Format',
                            hintText: 'yyyyMMdd',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          onChanged: (value) {
                            setState(() {
                              dateFormat = value.isNotEmpty ? value : 'yyyyMMdd';
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            if (componentOrder.contains('time'))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: includeTime,
                            onChanged: (value) {
                              setState(() {
                                includeTime = value ?? false;
                              });
                            },
                          ),
                          const Text(
                            'Time Format',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (includeTime) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: timeFormatController,
                          decoration: const InputDecoration(
                            labelText: 'Format',
                            hintText: 'HHmmss',
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          onChanged: (value) {
                            setState(() {
                              timeFormat = value.isNotEmpty ? value : 'HHmmss';
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            if (componentOrder.contains('number'))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: useIncrementingNumber,
                            onChanged: (value) {
                              setState(() {
                                useIncrementingNumber = value ?? false;
                              });
                            },
                          ),
                          const Text(
                            'Number Settings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (useIncrementingNumber) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: startNumberController,
                                decoration: const InputDecoration(
                                  labelText: 'Start Number',
                                  prefixIcon: Icon(Icons.format_list_numbered),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() {
                                    startNumber = int.tryParse(value) ?? 1;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: numberPaddingController,
                                decoration: const InputDecoration(
                                  labelText: 'Number Padding',
                                  prefixIcon: Icon(Icons.format_size),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() {
                                    numberPadding = int.tryParse(value) ?? 3;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Separator options
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: useCustomSeparator,
                          onChanged: (value) {
                            setState(() {
                              useCustomSeparator = value ?? false;
                            });
                          },
                        ),
                        const Text(
                          'Separator',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (useCustomSeparator) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customSeparatorController,
                        decoration: const InputDecoration(
                          labelText: 'Custom Separator',
                          hintText: 'Character to separate parts',
                          prefixIcon: Icon(Icons.segment),
                        ),
                        onChanged: (value) {
                          setState(() {
                            customSeparator = value.isNotEmpty ? value : '_';
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Preview
            Card(
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preview:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _generateFileName(0, dataRows.isNotEmpty ? dataRows[0] : {}),
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 18,
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

  Future<void> _generateFiles() async {
    if (widget.templatePath == null) return;

    setState(() {
      isGenerating = true;
      generationError = null;
      currentProgress = 0;
      totalFiles = dataRows.length;
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
        
        // Generate filename using the naming pattern
        final fileName = _generateFileName(i, row);
        final outputPath = '$outputDir/$fileName.docx';
        
        // Save the modified document
        final outputBytes = ZipEncoder().encode(newArchive);
        if (outputBytes != null) {
          await File(outputPath).writeAsBytes(outputBytes);
          print('Generated file: $outputPath');
        }

        setState(() {
          currentProgress = i + 1;
        });
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
} 