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

  String apiKeyFrom(String model) {
    final provider = model.split(RegExp('[/:]')).first;
    return switch (provider) {
      'google' => googleApiKey,
      'openai' => openAiApiKey,
      'openrouter' => openRouterApiKey,
      'gemini-compat' => googleApiKey,
      _ => throw Exception('Invalid provider: $provider'),
    };
  }

  final models = [
    for (final providerName in [
      'google',
      'openai',
      'openrouter',
      'gemini-compat',
    ])
      ...(await Agent.providerFor(
            providerName,
            apiKey: apiKeyFrom(providerName),
          ).listModels())
          .where((m) => m.stable)
          .map((m) => '$providerName:${m.name}'),
  ];

  const help = '''
chatarang is now running.
  type /exit to... ummm... exit.
  also /quit works
  /model [model] to see or change the model
  /list [filter] to show available models
  /messages to show conversation history
  /help to show this message again
''';

  print(help);

  // things to track
  var messages = <Message>[];
  final messageModels = <String>[];
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
        case '/messages':
          if (messages.isEmpty) {
            print('No messages yet.');
          } else {
            var modelMessageIndex = 0;
            for (final message in messages) {
              final role = message.role.name;
              if (role == 'user') {
                print('\x1B[94mYou\x1B[0m: ${message.text}');
              } else {
                // should be 'model'
                final modelName = modelMessageIndex < messageModels.length
                    ? messageModels[modelMessageIndex++]
                    : agent.model;
                print('\x1B[93m$modelName\x1B[0m: ${message.text}');
              }
            }
          }
          continue;
        case '/model':
          if (args.isEmpty) {
            print('Current model: ${agent.model}');
          } else {
            final newModel = args.join(':');
            if (models.contains(newModel)) {
              try {
                agent = Agent(newModel, apiKey: apiKeyFrom(newModel));
                print('Model set to: $newModel');
              } on Exception catch (ex) {
                print('Error setting model: $ex');
              }
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

    messageModels.add(agent.model);

    stdout.write('\n');
  }

  exit(0);
}
