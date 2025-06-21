// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dotenv/dotenv.dart';

const defaultModel = 'google';

Future<void> main() async {
  final env = DotEnv()..load();
  final googleApiKey = env['GEMINI_API_KEY']!;
  final openAiApiKey = env['OPENAI_API_KEY']!;
  final openRouterApiKey = env['OPENROUTER_API_KEY']!;

  String apiKeyFrom(String model) => switch (model.split('/:').first) {
    'gemini' => googleApiKey,
    'openai' => openAiApiKey,
    'openrouter' => openRouterApiKey,
    'gemini-compat' => googleApiKey,
    _ => throw Exception('Invalid model: $model'),
  };

  final models = [
    for (final providerName in [
      'google',
      'openai',
      'openrouter',
      'gemini-compat',
    ])
      ...(await Agent.providerFor(providerName).listModels())
          .where((m) => m.stable)
          .map((m) => '$providerName:${m.name}'),
  ];

  const help = '''
chatarang is now running.
  type /exit to... ummm... exit.
  also /quit works
  /model [model] to see or change the model
  /list [filter] to show available models
  /help to show this message again
''';

  print(help);

  // things to track
  var messages = <Message>[];
  var agent = Agent(defaultModel, apiKey: apiKeyFrom(defaultModel));

  while (true) {
    stdout.write('\x1B[94mYou\x1B[0m: ');
    final input = stdin.readLineSync();
    if (input == null) break;

    final line = input.trim();
    if (line.isEmpty) continue;

    if (line.startsWith('/')) {
      final parts = line.split(' ');
      final command = parts.first.toLowerCase();
      final args = parts.sublist(1);

      if (command == '/exit' || command == '/quit') {
        break;
      }

      switch (command) {
        case '/help':
          print(help);
          continue;
        case '/list':
          models
              .where((m) => args.every((arg) => m.contains(arg)))
              .forEach(print);
          continue;
        case '/model':
          if (args.isEmpty) {
            print('Current model: $model');
          } else {
            final newModel = args.join(':');
            if (models.contains(newModel)) {
              agent = Agent(newModel, apiKey: apiKeyFrom(newModel));
              messages = [];
              print('Model set to: $newModel');
            } else {
              print('Unknown model: $newModel. Use /list to see models.');
            }
          }
          continue;
        default:
          print('Unknown command: $command');
          continue;
      }
    }

    // Use streaming to show responses in real-time
    final stream = agent.runStream(line, messages: messages);

    stdout.write('\x1B[93m${agent.model}\x1B[0m: ');
    await for (final response in stream) {
      stdout.write(response.output);
      // Update messages for the next interaction
      messages = response.messages;
    }
    stdout.write('\n');
  }

  exit(0);
}
