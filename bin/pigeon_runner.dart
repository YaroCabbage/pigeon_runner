#!/usr/bin/env dart

import 'dart:io';

import 'package:dart_zx/dart_zx.dart' show $;
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

const kMkdirR = 'mkdir_r_';
const kMkdir = 'mkdir_';
const kDartPostfix = '.dart';

/// Batch runner for Pigeon code generation using dart_zx
/// Supports different settings for different folders/groups
void main(List<String> arguments) async {
  // Parse command line arguments
  final configFile = arguments.isNotEmpty ? arguments[0] : 'pigeon_build.yaml';

  // Configure dart_zx
  $.verbose = true;
  $.enableAnsiColor = true;

  // Read pigeon configuration
  final config = await _readPigeonConfig(configFile);

  if (config == null) {
    print('Error: Could not read pigeon configuration from $configFile');
    exit(1);
  }

  final groups = _parseConfigGroups(config);

  if (groups.isEmpty) {
    print('No pigeon groups found in configuration');
    return;
  }

  print('Found ${groups.length} pigeon group(s):');
  for (final group in groups) {
    print('  - ${group.name}: ${group.inputFiles.length} file(s)');
  }
  print('');

  // Process each group
  int totalSuccess = 0;
  int totalErrors = 0;

  for (final group in groups) {
    print('=== Processing Group: ${group.name} ===');

    int groupSuccess = 0;
    int groupErrors = 0;

    for (final inputFileInfo in group.inputFiles) {
      print('Processing: ${inputFileInfo.filePath}');

      try {
        // Generate code using pigeon command with group settings
        await _runPigeonForFile(inputFileInfo, group.settings);
        print('  ✓ Generated successfully');
        groupSuccess++;
      } catch (e) {
        print('  ✗ Error: $e');
        groupErrors++;
      }
    }

    print('Group ${group.name}: $groupSuccess successful, $groupErrors errors');
    print('');

    totalSuccess += groupSuccess;
    totalErrors += groupErrors;
  }

  // Print final summary
  print('=== Final Summary ===');
  print('Total successful: $totalSuccess files');
  print('Total errors: $totalErrors files');
  print('Total processed: ${totalSuccess + totalErrors} files');

  if (totalErrors > 0) {
    exit(1);
  }
}

/// Input file information with its parent source
class InputFileInfo {
  final String filePath;
  final String inputParent;

  InputFileInfo({required this.filePath, required this.inputParent});
}

/// Configuration group for pigeon files
class PigeonGroup {
  final String name;
  final List<InputFileInfo> inputFiles;
  final YamlMap settings;

  PigeonGroup({
    required this.name,
    required this.inputFiles,
    required this.settings,
  });
}

/// Read pigeon configuration from YAML file
Future<YamlMap?> _readPigeonConfig(String configPath) async {
  try {
    final configFile = File(configPath);
    if (!await configFile.exists()) {
      print('Configuration file not found: $configPath');
      return null;
    }

    final content = await configFile.readAsString();
    final yaml = loadYaml(content) as YamlMap;
    return yaml;
  } catch (e) {
    print('Error reading configuration: $e');
    return null;
  }
}

/// Parse configuration into groups with different settings
List<PigeonGroup> _parseConfigGroups(YamlMap config) {
  final groups = <PigeonGroup>[];

  // Check for groups configuration
  if (config.containsKey('groups')) {
    final groupsConfig = config['groups'] as YamlMap;

    for (final entry in groupsConfig.entries) {
      final groupName = entry.key.toString();
      final groupConfig = entry.value as YamlMap;

      final inputFiles = _getInputFiles(groupConfig);
      if (inputFiles.isNotEmpty) {
        groups.add(
          PigeonGroup(
            name: groupName,
            inputFiles: inputFiles,
            settings: groupConfig,
          ),
        );
      }
    }
  }

  // Fallback: treat root as single group if no groups defined
  if (groups.isEmpty) {
    final inputFiles = _getInputFiles(config);
    if (inputFiles.isNotEmpty) {
      groups.add(
        PigeonGroup(name: 'default', inputFiles: inputFiles, settings: config),
      );
    }
  }

  return groups;
}

/// Extract input files from configuration
List<InputFileInfo> _getInputFiles(YamlMap config) {
  final inputFiles = <InputFileInfo>[];

  // Check for single input file
  if (config.containsKey('input')) {
    final input = config['input'].toString();
    inputFiles.addAll(_processInput(input));
  }

  // Check for multiple input files
  if (config.containsKey('inputs')) {
    final inputs = config['inputs'];
    if (inputs is YamlList) {
      for (final input in inputs) {
        inputFiles.addAll(_processInput(input.toString()));
      }
    }
  }

  // Check for input_files (alternative naming)
  if (config.containsKey('input_files')) {
    final inputs = config['input_files'];
    if (inputs is YamlList) {
      for (final input in inputs) {
        inputFiles.addAll(_processInput(input.toString()));
      }
    }
  }

  return inputFiles;
}

/// Process input string - can be file, directory, or wildcard pattern
List<InputFileInfo> _processInput(String input) {
  final files = <InputFileInfo>[];

  // If input contains wildcard, process recursively
  if (input.contains('*') || input.contains('?')) {
    final foundFiles = _findFilesWithWildcard(input);
    for (final file in foundFiles) {
      files.add(InputFileInfo(filePath: file, inputParent: input));
    }
  } else {
    // Check if it's a directory or file
    final entity = FileSystemEntity.typeSync(input);

    if (entity == FileSystemEntityType.directory) {
      // Directory - process only top-level files
      final foundFiles = _findFilesInDirectory(input, recursive: false);
      for (final file in foundFiles) {
        files.add(InputFileInfo(filePath: file, inputParent: input));
      }
    } else if (entity == FileSystemEntityType.file) {
      // Single file
      files.add(InputFileInfo(filePath: input, inputParent: input));
    } else {
      print('Warning: Input not found: $input');
    }
  }

  return files;
}

/// Find files in directory
List<String> _findFilesInDirectory(String dirPath, {required bool recursive}) {
  final files = <String>[];
  final directory = Directory(dirPath);

  if (!directory.existsSync()) {
    print('Warning: Directory not found: $dirPath');
    return files;
  }

  try {
    final entities = directory.listSync(recursive: recursive);
    for (final entity in entities) {
      if (entity is File && entity.path.endsWith(kDartPostfix)) {
        files.add(entity.path);
      }
    }
  } catch (e) {
    print('Warning: Error reading directory $dirPath: $e');
  }

  return files;
}

/// Find files matching wildcard pattern (recursive)
List<String> _findFilesWithWildcard(String pattern) {
  final files = <String>[];

  // Extract directory part and pattern part
  final patternPath = path.dirname(pattern);
  final patternName = path.basename(pattern);

  final directory = Directory(
    patternPath == '.' ? Directory.current.path : patternPath,
  );

  if (!directory.existsSync()) {
    print('Warning: Directory not found: $patternPath');
    return files;
  }

  try {
    // Process recursively when using wildcards
    final entities = directory.listSync(recursive: true);
    for (final entity in entities) {
      if (entity is File) {
        final fileName = path.basename(entity.path);
        if (fileName.endsWith(kDartPostfix) &&
            _matchesPattern(fileName, patternName)) {
          files.add(entity.path);
        }
      }
    }
  } catch (e) {
    print('Warning: Error processing wildcard pattern $pattern: $e');
  }

  return files;
}

/// Simple pattern matching (supports * and ? wildcards)
bool _matchesPattern(String fileName, String pattern) {
  if (pattern == '*' || pattern == '*.*') return true;

  // Convert wildcard pattern to regex
  var regexPattern = pattern
      .replaceAll(RegExp(r'\.'), r'\.') // Escape dots
      .replaceAll('*', '.*') // * becomes .*
      .replaceAll('?', '.'); // ? becomes .

  return RegExp('^$regexPattern\$').hasMatch(fileName);
}

/// Run pigeon command for a specific file using configuration
Future<void> _runPigeonForFile(
  InputFileInfo inputFileInfo,
  YamlMap config,
) async {
  final pigeonArgs = <String>[];

  // Add input file
  pigeonArgs.addAll([
    '--input',
    File(inputFileInfo.filePath).resolveSymbolicLinksSync(),
  ]);

  // Convert all YAML options to pigeon arguments by adding "--" prefix
  for (final entry in config.entries) {
    final key = entry.key.toString();
    final value = entry.value;

    // Skip special keys that are not pigeon options
    if (_isSpecialKey(key)) continue;

    if (value is bool) {
      if (value == true) {
        pigeonArgs.add('--$key');
      }
    } else if (value is String && value.isNotEmpty) {
      final processedValue = await _processDirectoryOption(
        key,
        value,
        inputFileInfo.filePath,
        inputFileInfo.inputParent,
      );
      pigeonArgs.add('--$processedValue');
    } else if (value is YamlList) {
      // Handle list values (like copyright_header)
      for (final item in value) {
        pigeonArgs.addAll(['--$key', item.toString()]);
      }
    } else if (value != null) {
      throw "Failed to process option $key with value: $value";
    }
  }

  // Execute pigeon command using dart_zx
  final command = 'dart run pigeon ${pigeonArgs.join(' ')}';
  final result = await $.run(command);

  if (result.exitCode != 0) {
    throw Exception(
      'Pigeon failed with exit code ${result.exitCode}\n'
      'stderr: ${result.stderr}',
    );
  }
}

/// Process directory creation options with mkdir_ and mkdir_r_ prefixes
Future<String> _processDirectoryOption(
  String key,
  String value,
  String inputFile,
  String inputParent,
) async {
  if (key.startsWith(kMkdirR)) {
    // Recursive directory creation with intermediate directories
    final actualKey = key.replaceFirst(kMkdirR, ''); // Remove 'mkdir_r_' prefix
    final outputPath = _createRecursiveOutputPath(
      value,
      inputFile,
      inputParent,
    );
    await _ensureDirectoryExists(path.dirname(outputPath));
    return '$actualKey $outputPath';
  } else if (key.startsWith(kMkdir)) {
    final fileName = path.basename(inputFile);
    final filePathNormalized = path.normalize('$value/$fileName');

    // Simple directory creation
    final actualKey = key.replaceFirst(kMkdir, ''); // Remove 'mkdir_' prefix
    await _ensureDirectoryExists(value);
    return '$actualKey $filePathNormalized';
  }

  // If it's not a directory option
  return '$key $value';
}

/// Create recursive output path maintaining directory structure
String _createRecursiveOutputPath(
  String outputBasePath,
  String inputFilePath,
  String inputBasePath,
) {
  // Get the relative directory structure from the input file
  final inputFileDir = path.dirname(inputFilePath);
  final inputFilename = path.basename(inputFilePath);
  final generatedOutputFilename =
      '${path.basenameWithoutExtension(inputFilePath)}.g${path.extension(inputFilePath)}';

  // Calculate relative path from input parent to input file
  // String relativePath = '';

  var inputParentBaseParts = path.split(inputBasePath);
  final index = inputParentBaseParts.indexWhere((element) {
    return element.contains('*') || element.contains('?');
  });

  if (index != -1) {
    inputParentBaseParts = inputParentBaseParts.sublist(0, index);
  }

  final inputParentBaseCleaned = path.joinAll(inputParentBaseParts);
  final inputFilePathWithoutParentBase = inputFilePath.replaceFirst(
    inputParentBaseCleaned,
    '',
  );
  final inputFileParts = path.split(inputFilePathWithoutParentBase);
  inputFileParts.remove(inputFilename);

  final outPath = path.normalize(
    [outputBasePath, ...inputFileParts, generatedOutputFilename].join('/'),
  );

  return outPath;
}

/// Ensure directory exists, create if it doesn't
Future<void> _ensureDirectoryExists(String dirPath) async {
  if (dirPath.isEmpty) return;

  final directory = Directory(dirPath);
  if (!await directory.exists()) {
    try {
      await directory.create(recursive: true);
      print('  📁 Created directory: $dirPath');
    } catch (e) {
      print('  ⚠️ Warning: Could not create directory $dirPath: $e');
    }
  }
}

/// Check if key is special (not a pigeon option)
bool _isSpecialKey(String key) {
  const specialKeys = {'input', 'inputs', 'input_files', 'folder', 'pattern'};
  return specialKeys.contains(key);
}
