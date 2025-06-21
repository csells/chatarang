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
  /model <model> to change the model
  /list [filter] to show available models
  /help to show this message again
''';

  print(help);

  // things to track
  const model = defaultModel;
  var messages = <Message>[];
  final agent = Agent(model, apiKey: apiKeyFrom(model));

  while (true) {
    stdout.write('\x1B[94mYou\x1B[0m: ');
    final input = stdin.readLineSync();
    if (input == null || input.toLowerCase() == 'exit') break;

    // Use streaming to show responses in real-time
    final stream = agent.runStream(input, messages: messages);

    stdout.write('\x1B[93mAgent\x1B[0m: ');
    await for (final response in stream) {
      stdout.write(response.output);
      // Update messages for the next interaction
      messages = response.messages;
    }
    stdout.write('\n');
  }
}
