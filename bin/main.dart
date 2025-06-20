import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';

Future<void> main() async {
  final apiKey = Platform.environment['GEMINI_API_KEY'];
  if (apiKey == null) {
    stderr.writeln('Please set the GEMINI_API_KEY environment variable.');
    exit(1);
  }

  // Create tools for file operations
  final readFileTool = Tool(
    name: 'read_file',
    description: 'Read the contents of a file at a relative path.',
    onCall: readFile,
    inputSchema: {
      'type': 'object',
      'properties': {
        'path': {'type': 'string'},
      },
      'required': ['path'],
    }.toSchema(),
  );

  final listFilesTool = Tool(
    name: 'list_files',
    description: 'List all files in a given directory.',
    onCall: listFiles,
    inputSchema: {
      'type': 'object',
      'properties': {
        'dir': {'type': 'string'},
      },
    }.toSchema(),
  );

  final editFileTool = Tool(
    name: 'edit_file',
    description: 'Overwrite the contents of a file with new content.',
    onCall: editFile,
    inputSchema: {
      'type': 'object',
      'properties': {
        'path': {'type': 'string'},
        'replace': {'type': 'string'},
      },
      'required': ['path', 'replace'],
    }.toSchema(),
  );

  // Create agent with tools
  final agent = Agent(
    'google:gemini-2.5-flash',
    apiKey: apiKey,
    tools: [readFileTool, listFilesTool, editFileTool],
  );

  print('Chatarang Agent is running. Type "exit" to quit.');

  // Keep track of chat history
  var messages = <Message>[];

  while (true) {
    stdout.write('\x1B[94mYou\x1B[0m: ');
    final input = stdin.readLineSync();
    if (input == null || input.toLowerCase() == 'exit') break;

    try {
      // Use streaming to show responses in real-time
      final stream = agent.runStream(input, messages: messages);

      stdout.write('\x1B[93mAgent\x1B[0m: ');
      await for (final response in stream) {
        stdout.write(response.output);
        // Update messages for the next interaction
        messages = response.messages;
      }
      stdout.write('\n');
    } catch (e) {
      print('\x1B[91mError\x1B[0m: $e');
    }
  }
}

Future<Map<String, dynamic>> readFile(Map<String, dynamic> args) async {
  final path = args['path'] as String;
  try {
    final file = File(path);
    if (!await file.exists()) return {'result': 'File not found: $path'};
    final content = await file.readAsString();
    return {'result': content};
  } catch (e) {
    return {'result': 'Error reading file: $e'};
  }
}

Future<Map<String, dynamic>> listFiles(Map<String, dynamic> args) async {
  final dirPath = args['dir'] as String? ?? '.';
  try {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return {'result': 'Directory not found: $dirPath'};
    final entries = await dir.list().toList();
    final paths = entries.map((e) => e.path).join('\n');
    return {'result': paths};
  } catch (e) {
    return {'result': 'Error listing files: $e'};
  }
}

Future<Map<String, dynamic>> editFile(Map<String, dynamic> args) async {
  final path = args['path'] as String;
  final content = args['replace'] as String;
  try {
    final file = File(path);
    await file.writeAsString(content);
    return {'result': 'File $path updated successfully.'};
  } catch (e) {
    return {'result': 'Error editing file: $e'};
  }
}
