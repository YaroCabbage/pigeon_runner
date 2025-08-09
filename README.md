# Pigeon Batch Runner

A Dart script that runs Pigeon code generation for multiple files using dart_zx, with support for different settings per group/folder.

## Features

- **Group-based Processing**: Different settings for different folders/groups of files
- **Smart Input Processing**: Handles directories (top-level only) vs wildcards (recursive)
- **Automatic Option Translation**: YAML options automatically converted to pigeon arguments
- **Progress Tracking**: Shows progress per group and overall summary
- **Error Handling**: Continues processing even if individual files fail

## ⚠️ Warning: Potential Directory Overlap
**The situation with overlapping parent and child directories has not been tested.**

For example: `parent_directory/child_directory`. You might have settings for `parent_directory` and separate settings for `child_directory`.

Most likely, overwriting will occur in the order of processing. That is, if `parent_directory` comes first, files will be generated from there. Then they will be overwritten by files from `child_directory`.

## Installation

This package is intended to support development of Dart projects with pigeon inside. In general, add it to your pubspec.yaml as a dev_dependencies by running the following command.

```bash
dart pub add dev:pigeon_runner
```

## Usage Examples

### Basic Usage

```bash
# Use default pigeon_build.yaml
dart pigeon_runner

# Use custom config file
dart pigeon_runner my_pigeon_config.yaml
```

### Configuration Examples

#### Top-level files only (non-recursive)

```yaml
groups:
  api_core:
    input: lib/pigeon/api  # Directory - only top-level .dart files
    dart_out: lib/generated/api/
    java_package: com.example.api
    dart_null_safety: true
```

#### All files recursively

```yaml
groups:
  auth_all:
    input: lib/pigeon/auth/**/*.dart  # Wildcard - recursive through all subdirs
    dart_out: lib/generated/auth/
    java_package: com.example.auth
    objc_prefix: AUTH
```

#### Mixed inputs

```yaml
groups:
  mixed:
    inputs:
      - lib/pigeon/core                    # Directory (top-level only)
      - lib/pigeon/plugins/*_api.dart      # Wildcard (recursive)
      - lib/pigeon/special/custom.dart     # Single file
    dart_out: lib/generated/mixed/
    objc_prefix: MIX
    kotlin_package: com.example.mixed
```

#### Complete example with multiple groups

```yaml
groups:
  # API group - for main API files
  api:
    input: lib/pigeon/api
    dart_out: lib/generated/api/
    dart_null_safety: true
    objc_header_out: ios/Runner/API.h
    objc_source_out: ios/Runner/API.m
    objc_prefix: API
    java_out: android/app/src/main/java/com/example/API.java
    java_package: com.example.api
    swift_out: ios/Runner/API.swift

  # Auth group - for authentication files
  auth:
    inputs:
      - lib/pigeon/auth/login_api.dart
      - lib/pigeon/auth/oauth_api.dart
    dart_out: lib/generated/auth/
    dart_null_safety: true
    objc_header_out: ios/Runner/Auth.h
    objc_source_out: ios/Runner/Auth.m
    objc_prefix: AUTH
    java_out: android/app/src/main/java/com/example/Auth.java
    java_package: com.example.auth
    kotlin_out: android/app/src/main/kotlin/Auth.kt
    kotlin_package: com.example.auth

  # Data group - for data transfer objects
  data:
    input: lib/pigeon/data/**/*.dart  # Recursive wildcard
    dart_out: lib/generated/data/
    dart_null_safety: true
    one_language: true  # Only generate Dart code

  # Legacy group - for old APIs with different settings
  legacy:
    inputs:
      - lib/pigeon/legacy/old_api.dart
    dart_out: lib/generated/legacy/
    dart_null_safety: false  # Legacy code without null safety
    objc_prefix: LEGACY
    java_package: com.example.legacy
    debug_generators: true
```

## Input Processing Behavior

### Directory Input (Non-recursive)

```yaml
input: lib/pigeon/api
```

**Processes:**
- ✓ `lib/pigeon/api/user.dart`
- ✓ `lib/pigeon/api/auth.dart`
- ✗ `lib/pigeon/api/v2/user.dart` (in subdirectory - skipped)

### Wildcard Input (Recursive)

```yaml
input: lib/pigeon/api/**/*.dart
```

**Processes:**
- ✓ `lib/pigeon/api/user.dart`
- ✓ `lib/pigeon/api/auth.dart`
- ✓ `lib/pigeon/api/v2/user.dart` (in subdirectory - included)
- ✓ `lib/pigeon/api/v2/legacy/old.dart` (deeply nested - included)

### Wildcard Patterns

```yaml
# All .dart files recursively
input: lib/pigeon/**/*.dart

# Only API files recursively  
input: lib/pigeon/**/*_api.dart

# Files starting with "user"
input: lib/pigeon/**/user*.dart

# Single character wildcard
input: lib/pigeon/**/api?.dart
```

## Option Translation

All YAML options are automatically converted to pigeon arguments by adding `--` prefix.

**For available parameter names, refer to:**
- [Pigeon library source](https://github.com/flutter/packages/blob/98ac61aaa1c07c2e4c42361ad1735a1bb23c6f65/packages/pigeon/lib/src/pigeon_lib.dart)
- [Pigeon example configuration](https://github.com/flutter/packages/blob/main/packages/pigeon/example/app/pigeons/messages.dart)

### YAML Configuration:
```yaml
dart_null_safety: true
java_package: com.example.myapp
objc_prefix: API
debug_generators: true
copyright_header:
  - "// Generated code"
  - "// Do not edit"
```

### Becomes Pigeon Arguments:
```bash
--dart_null_safety --java_package com.example.myapp --objc_prefix API --debug_generators --copyright_header "// Generated code" --copyright_header "// Do not edit"
```

### Option Types:
- **Boolean `true`**: Becomes a flag (e.g., `dart_null_safety: true` → `--dart_null_safety`)
- **Boolean `false`**: Ignored (no flag added)
- **String/Number**: Becomes key-value pair (e.g., `java_package: com.example` → `--java_package com.example`)
- **List**: Each item becomes separate argument (e.g., multiple `--copyright_header` entries)

## Backward Compatibility

The script supports the old single-group format:

```yaml
# Old format - treated as "default" group
inputs:
  - lib/pigeon/api.dart
  - lib/pigeon/auth.dart
dart_out: lib/generated/
java_package: com.example
dart_null_safety: true
```

## Dependencies

Add these to your `pubspec.yaml`:

```yaml
dependencies:
  path: ^1.8.0
  ansicolor: ^2.0.1
  dart_zx: # Your local package
  rxdart: ^0.27.0
  uuid: ^3.0.0
  yaml: ^3.1.0

dev_dependencies:
  pigeon: ^22.0.0  # For the dart run pigeon command
```

## Output Example

```
Found 3 pigeon group(s):
  - api: 2 file(s)
  - auth: 3 file(s)
  - data: 5 file(s)

=== Processing Group: api ===
Processing: lib/pigeon/api/user.dart
  ✓ Generated successfully
Processing: lib/pigeon/api/settings.dart
  ✓ Generated successfully
Group api: 2 successful, 0 errors

=== Processing Group: auth ===
Processing: lib/pigeon/auth/login_api.dart
  ✓ Generated successfully
Processing: lib/pigeon/auth/oauth_api.dart
  ✗ Error: Pigeon failed with exit code 1
Processing: lib/pigeon/auth/token_api.dart
  ✓ Generated successfully
Group auth: 2 successful, 1 errors

=== Processing Group: data ===
Processing: lib/pigeon/data/user_model.dart
  ✓ Generated successfully
...

=== Final Summary ===
Total successful: 9 files
Total errors: 1 files
Total processed: 10 files
```