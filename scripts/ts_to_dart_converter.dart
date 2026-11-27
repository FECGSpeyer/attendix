#!/usr/bin/env dart
// ignore_for_file: avoid_print

// TypeScript to Dart/Freezed Model Converter
//
// Usage:
//   dart run scripts/ts_to_dart_converter.dart <typescript_file> [output_dir]
//
// Example:
//   dart run scripts/ts_to_dart_converter.dart ../attendance/src/app/utilities/interfaces.ts lib/data/models/generated

import 'dart:io';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run scripts/ts_to_dart_converter.dart <typescript_file> [output_dir]');
    print('Example: dart run scripts/ts_to_dart_converter.dart ../attendance/src/app/utilities/interfaces.ts');
    exit(1);
  }

  final inputFile = File(args[0]);
  final outputDir = args.length > 1 ? args[1] : 'lib/data/models/generated';

  if (!inputFile.existsSync()) {
    print('Error: File not found: ${args[0]}');
    exit(1);
  }

  print('🔄 Converting TypeScript interfaces to Dart...');
  print('   Input: ${inputFile.path}');
  print('   Output: $outputDir');

  final content = inputFile.readAsStringSync();
  final interfaces = parseTypeScriptInterfaces(content);

  print('   Found ${interfaces.length} interfaces');

  // Create output directory
  final dir = Directory(outputDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  // Generate Dart files
  for (final interface in interfaces) {
    final dartCode = generateFreezedModel(interface);
    final fileName = camelToSnake(interface.name);
    final outputFile = File('$outputDir/${fileName}_generated.dart');
    outputFile.writeAsStringSync(dartCode);
    print('   ✅ Generated: ${outputFile.path}');
  }

  // Generate barrel file
  final barrelContent = interfaces
      .map((i) => "export '${camelToSnake(i.name)}_generated.dart';")
      .join('\n');
  File('$outputDir/generated.dart').writeAsStringSync(barrelContent);

  print('\n✨ Done! Run `dart run build_runner build` to generate freezed code.');
}

/// Parse TypeScript interfaces from content
List<TSInterface> parseTypeScriptInterfaces(String content) {
  final interfaces = <TSInterface>[];
  
  // Match interface declarations
  final interfaceRegex = RegExp(
    r'export\s+interface\s+(\w+)\s*(?:extends\s+([\w,\s]+))?\s*\{([^}]+)\}',
    multiLine: true,
    dotAll: true,
  );

  for (final match in interfaceRegex.allMatches(content)) {
    final name = match.group(1)!;
    final extendsClause = match.group(2);
    final body = match.group(3)!;
    
    // Skip certain interfaces
    if (_skipInterfaces.contains(name)) continue;

    final properties = parseProperties(body);
    
    interfaces.add(TSInterface(
      name: name,
      extends_: extendsClause?.split(',').map((e) => e.trim()).toList(),
      properties: properties,
    ));
  }

  return interfaces;
}

/// Parse properties from interface body
List<TSProperty> parseProperties(String body) {
  final properties = <TSProperty>[];
  
  // Remove comments first
  body = body.replaceAll(RegExp(r'//[^\n]*'), '');
  body = body.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  
  // Match property declarations
  // Handles: name: Type, name?: Type, name: Type | null
  final propRegex = RegExp(
    r'(\w+)(\?)?:\s*([^;,\n]+)',
    multiLine: true,
  );

  for (final match in propRegex.allMatches(body)) {
    final name = match.group(1)!;
    
    // Skip if name contains spaces or is invalid
    if (name.contains(' ') || !RegExp(r'^[a-zA-Z_]\w*$').hasMatch(name)) {
      continue;
    }
    
    final optional = match.group(2) == '?';
    var type = match.group(3)!.trim();
    
    // Skip computed/readonly properties
    if (type.contains('Computed') || type.isEmpty) {
      continue;
    }
    
    // Handle union with null
    final nullable = type.contains('| null') || type.contains('null |') || optional;
    type = type.replaceAll(RegExp(r'\s*\|\s*null'), '').replaceAll(RegExp(r'null\s*\|\s*'), '').trim();
    
    // Clean up type - remove trailing comments
    type = type.split('//').first.trim();
    
    properties.add(TSProperty(
      name: name,
      type: type,
      optional: optional,
      nullable: nullable,
    ));
  }

  return properties;
}

/// Generate Freezed model from TypeScript interface
String generateFreezedModel(TSInterface interface) {
  final className = interface.name;
  final snakeName = camelToSnake(className);
  
  final buffer = StringBuffer();
  
  // Header
  buffer.writeln("// GENERATED CODE - DO NOT MODIFY BY HAND");
  buffer.writeln("// Generated from TypeScript interface: ${interface.name}");
  buffer.writeln("// Run: dart run scripts/ts_to_dart_converter.dart");
  buffer.writeln();
  buffer.writeln("import 'package:freezed_annotation/freezed_annotation.dart';");
  buffer.writeln();
  buffer.writeln("part '${snakeName}_generated.freezed.dart';");
  buffer.writeln("part '${snakeName}_generated.g.dart';");
  buffer.writeln();
  
  // Class documentation
  buffer.writeln("/// $className model");
  buffer.writeln("/// Generated from TypeScript interface");
  buffer.writeln("@freezed");
  buffer.writeln("class $className with _\$$className {");
  buffer.writeln("  const factory $className({");
  
  // Properties
  for (final prop in interface.properties) {
    final dartType = _tsDartTypeMap[prop.type] ?? _mapComplexType(prop.type);
    final nullableSuffix = prop.nullable ? '?' : '';
    final jsonKey = prop.name != _toDartFieldName(prop.name) 
        ? "@JsonKey(name: '${prop.name}') "
        : "";
    final required = !prop.nullable && !prop.optional ? "required " : "";
    
    buffer.writeln("    $jsonKey$required$dartType$nullableSuffix ${_toDartFieldName(prop.name)},");
  }
  
  buffer.writeln("  }) = _$className;");
  buffer.writeln();
  buffer.writeln("  factory $className.fromJson(Map<String, dynamic> json) =>");
  buffer.writeln("      _\$${className}FromJson(json);");
  buffer.writeln("}");
  
  return buffer.toString();
}

/// Map TypeScript types to Dart types
const _tsDartTypeMap = <String, String>{
  'string': 'String',
  'number': 'int',
  'boolean': 'bool',
  'Date': 'DateTime',
  'any': 'dynamic',
  'object': 'Map<String, dynamic>',
  'unknown': 'dynamic',
  'void': 'void',
  'never': 'Never',
  'undefined': 'void',
};

/// Map complex types
String _mapComplexType(String tsType) {
  // Array types: Type[] or Array<Type>
  if (tsType.endsWith('[]')) {
    final innerType = tsType.substring(0, tsType.length - 2);
    final dartInner = _tsDartTypeMap[innerType] ?? innerType;
    return 'List<$dartInner>';
  }
  
  if (tsType.startsWith('Array<') && tsType.endsWith('>')) {
    final innerType = tsType.substring(6, tsType.length - 1);
    final dartInner = _tsDartTypeMap[innerType] ?? innerType;
    return 'List<$dartInner>';
  }
  
  // Record/Map types
  if (tsType.startsWith('Record<')) {
    return 'Map<String, dynamic>';
  }
  
  // Partial types
  if (tsType.startsWith('Partial<')) {
    final innerType = tsType.substring(8, tsType.length - 1);
    return innerType;
  }
  
  // Promise (convert to Future concept, but for model just use the inner type)
  if (tsType.startsWith('Promise<')) {
    final innerType = tsType.substring(8, tsType.length - 1);
    return _tsDartTypeMap[innerType] ?? innerType;
  }
  
  // Default: use as-is (might be another interface)
  return tsType;
}

/// Convert camelCase to snake_case
String camelToSnake(String input) {
  return input
      .replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}')
      .replaceFirst(RegExp(r'^_'), '');
}

/// Convert to valid Dart field name
String _toDartFieldName(String name) {
  // Reserved words
  const reserved = {'class', 'enum', 'extends', 'super', 'this', 'new', 'const', 'final', 'var', 'void', 'return', 'if', 'else', 'for', 'while', 'do', 'switch', 'case', 'default', 'break', 'continue', 'try', 'catch', 'finally', 'throw', 'assert', 'true', 'false', 'null', 'in', 'is', 'as'};
  
  if (reserved.contains(name)) {
    return '${name}_';
  }
  return name;
}

/// Interfaces to skip (helper types, etc.)
const _skipInterfaces = <String>{
  'HttpsCallableResult',
  'Unsubscribe',
  'DocumentReference',
  'DocumentData',
  'Timestamp',
};

/// TypeScript Interface representation
class TSInterface {
  final String name;
  final List<String>? extends_;
  final List<TSProperty> properties;

  TSInterface({
    required this.name,
    this.extends_,
    required this.properties,
  });
}

/// TypeScript Property representation
class TSProperty {
  final String name;
  final String type;
  final bool optional;
  final bool nullable;

  TSProperty({
    required this.name,
    required this.type,
    this.optional = false,
    this.nullable = false,
  });
}