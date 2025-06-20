import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';

Future<void> main() async {
  final apiKey = Platform.environment['GEMINI_API_KEY'];
  if (apiKey == null) {
    stderr.writeln('Please set the GEMINI_API_KEY environment variable.');
    exit(1);
  }

  final model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: apiKey,
    tools: [
      Tool(
        functionDeclarations: [
          FunctionDeclaration(
            'read_file',
            'Read the contents of a file at a relative path.',
            Schema(
              SchemaType.object,
              properties: {'path': Schema(SchemaType.string)},
            ),
          ),
          FunctionDeclaration(
            'list_files',
            'List all files in a given directory.',
            Schema(
              SchemaType.object,
              properties: {'dir': Schema(SchemaType.string)},
            ),
          ),
          FunctionDeclaration(
            'edit_file',
            'Overwrite the contents of a file with new content.',
            Schema(
              SchemaType.object,
              properties: {
                'path': Schema(SchemaType.string),
                'replace': Schema(SchemaType.string),
              },
            ),
          ),
        ],
      ),
    ],
  );

  final chat = model.startChat();

  print('Gemini 2.0 Flash Agent is running. Type "exit" to quit.');
  while (true) {
    stdout.write('\x1B[94mYou\x1B[0m: ');
    final input = stdin.readLineSync();
    if (input == null || input.toLowerCase() == 'exit') break;

    final response = await chat.sendMessage(Content.text(input));

    final text = response.text?.trim();
    if (text != null && text.isNotEmpty) {
      print('\x1B[93mGemini\x1B[0m: $text');
    }

    final functionResponses = <Content>[];
    for (final candidate in response.candidates) {
      for (final part in candidate.content.parts) {
        if (part is FunctionCall) {
          final result = await handleToolCall(part);
          print('\x1B[92mTool\x1B[0m: ${part.name}(${part.args})');
          functionResponses.add(
            Content.functionResponse(part.name, {'result': result}),
          );
        }
      }
    }

    if (functionResponses.isNotEmpty) {
      final response = await chat.sendMessage(
        Content(
          '',
          functionResponses.map((c) => c.parts).expand((p) => p).toList(),
        ),
      );
      if (response.text != null) {
        print('\x1B[93mGemini\x1B[0m: ${response.text}');
      }
    }
  }
}

Future<String> handleToolCall(FunctionCall call) async {
  final args = call.args;
  try {
    switch (call.name) {
      case 'read_file':
        return await readFile(args['path'] as String);
      case 'list_files':
        return await listFiles(args['dir'] as String? ?? '.');
      case 'edit_file':
        return await editFile(
          args['path'] as String,
          args['replace'] as String,
        );
      default:
        final err = 'Unknown tool: ${call.name}';
        print(err);
        return err;
    }
  } catch (e) {
    final err = 'Error executing ${call.name}: $e';
    print(err);
    return err;
  }
}

Future<String> readFile(String path) async {
  final file = File(path);
  if (!await file.exists()) return 'File not found: $path';
  return await file.readAsString();
}

Future<String> listFiles(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return 'Directory not found: $dirPath';
  final entries = await dir.list().toList();
  return entries.map((e) => e.path).join('\n');
}

Future<String> editFile(String path, String content) async {
  final file = File(path);
  await file.writeAsString(content);
  return 'File $path updated successfully.';
}
