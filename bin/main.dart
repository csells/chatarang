// ignore_for_file: avoid_print

import 'dart:io';

import 'package:chatarang/commands.dart';
import 'package:chatarang/env.dart';
import 'package:chatarang/history.dart';
import 'package:cli_repl/cli_repl.dart';
import 'package:dartantic_ai/dartantic_ai.dart';

const defaultModel = 'google';

Future<void> main() async {
  Agent.environment.addAll(Env.tryAll);
  final providerNames = Agent.providers.keys;
  final models = [
    for (final providerName in providerNames)
      ...(await Agent.providerFor(providerName).listModels())
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

  // Print initial information before starting REPL
  stdout.write(help);
  stdout.write('\n');
  stdout.write(
    'Found ${models.length} models from ${providerNames.length} providers.\n',
  );
  await stdout.flush();

  final commandHandler = CommandHandler(
    defaultModel: defaultModel,
    history: [],
    models: models,
    help: help,
  );

  final repl = Repl(prompt: '\x1B[94mYou\x1B[0m: ');

  for (final line in repl.run()) {
    if (line.trim().isEmpty) continue;

    final result = commandHandler.handleCommand(line: line.trim());
    if (result.shouldExit) break;
    if (result.commandHandled) continue;

    // Use streaming to show responses in real-time
    final stream = commandHandler.agent.runStream(
      line.trim(),
      messages: commandHandler.messages,
    );

    stdout.write('\x1B[93m${commandHandler.agent.model}\x1B[0m: ');
    await stdout.flush();
    var finalMessages = <Message>[];
    await for (final response in stream) {
      stdout.write(response.output);
      await stdout.flush();
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

    stdout.write('\n\n');
    await stdout.flush();
  }

  exit(0);
}
