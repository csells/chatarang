// ignore_for_file: avoid_print

import 'dart:io';

import 'package:chatarang/commands.dart';
import 'package:chatarang/history.dart';
import 'package:chatarang/tools.dart';
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
      _ => throw Exception('Unknown provider: $provider'),
    };
  }

  final providerNames = Agent.providers.keys;
  final models = [
    for (final providerName in providerNames)
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
  /models [filter] to show available models
  /messages to show conversation history
  /help to show this message again

Everything else you type will be sent to the current model.
''';

  print(help);
  print(
    'Found ${models.length} models from ${providerNames.length} providers.',
  );

  final commandHandler = CommandHandler(
    agent: Agent(defaultModel, apiKey: apiKeyFrom(defaultModel), tools: tools),
    history: [],
    models: models,
    help: help,
    apiKeyFrom: apiKeyFrom,
  );

  while (true) {
    stdout.write('\x1B[94mYou\x1B[0m: ');
    final input = stdin.readLineSync();
    if (input == null) break;

    final line = input.trim();
    if (line.isEmpty) continue;

    final result = commandHandler.handleCommand(line: line);
    if (result.shouldExit) break;
    if (result.commandHandled) continue;

    // Use streaming to show responses in real-time
    final stream = commandHandler.agent.runStream(
      line,
      messages: commandHandler.messages,
    );

    stdout.write('\x1B[93m${commandHandler.agent.model}\x1B[0m: ');
    var finalMessages = <Message>[];
    await for (final response in stream) {
      stdout.write(response.output);
      finalMessages = response.messages;
    }

    final oldMessageCount = commandHandler.history.length;
    final newMessages = finalMessages.sublist(oldMessageCount);
    for (final msg in newMessages) {
      commandHandler.history.add(
        HistoryEntry(
          message: msg,
          modelName: msg.role == MessageRole.model
              ? commandHandler.agent.model
              : '',
        ),
      );
    }

    stdout.write('\n');
  }

  exit(0);
}
