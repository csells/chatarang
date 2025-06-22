// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:dartantic_ai/dartantic_ai.dart';

import 'history.dart';
import 'tools.dart';

class HandleCommandResult {
  HandleCommandResult({this.shouldExit = false, this.commandHandled = true});
  final bool shouldExit;
  final bool commandHandled;
}

class CommandHandler {
  CommandHandler({
    required this.agent,
    required this.history,
    required this.models,
    required this.help,
    required this.apiKeyFrom,
  });
  Agent agent;
  List<HistoryEntry> history;
  final List<String> models;
  final String help;
  final String Function(String) apiKeyFrom;

  List<Message> get messages => history.map((e) => e.message).toList();

  HandleCommandResult handleCommand({required String line}) {
    if (!line.startsWith('/')) {
      return HandleCommandResult(commandHandled: false);
    }

    final parts = line.split(' ');
    final command = parts.first.toLowerCase();
    final args = parts.sublist(1);

    if (command == '/exit' || command == '/quit') {
      return HandleCommandResult(shouldExit: true);
    }

    switch (command) {
      case '/help':
        print(help);
        return HandleCommandResult();

      case '/models':
        models
            .where((m) => args.every((arg) => m.contains(arg)))
            .forEach(print);
        return HandleCommandResult();

      case '/messages':
        print('');
        if (history.isEmpty) {
          print('No messages yet.');
        } else {
          for (final entry in history) {
            final message = entry.message;
            final role = message.role;
            switch (role) {
              case MessageRole.user:
                // A user message can contain text and/or tool results to be
                // sent to the model. We iterate through the parts to display
                // them in order.
                for (final part in message.parts) {
                  if (part is TextPart) {
                    if (part.text.isNotEmpty) {
                      print('\x1B[94mYou\x1B[0m: ${part.text}');
                    }
                  } else if (part is ToolPart) {
                    if (part.kind == ToolPartKind.result) {
                      final result = const JsonEncoder.withIndent(
                        '  ',
                      ).convert(part.result);

                      var resultToShow = result;
                      if (resultToShow.length > 256) {
                        resultToShow = '${resultToShow.substring(0, 256)}...';
                      }

                      print(
                        '\x1B[96mTool.result\x1B[0m: ${part.name}: '
                        '$resultToShow',
                      );
                    }
                  }
                }
              case MessageRole.model:
                final modelName = entry.modelName;
                for (final part in message.parts) {
                  if (part is TextPart) {
                    print('\x1B[93m$modelName\x1B[0m: ${part.text}');
                  } else if (part is ToolPart) {
                    if (part.kind == ToolPartKind.call) {
                      final args = const JsonEncoder.withIndent(
                        '  ',
                      ).convert(part.arguments);
                      print('\x1B[95mTool.call\x1B[0m: ${part.name}($args)');
                    }
                  }
                }
              case MessageRole.system:
                // Should not happen, but including for completeness
                print(
                  '\x1B[91m${role.name.toUpperCase()}\x1B[0m: '
                  '${message.text}',
                );
            }
          }
        }
        return HandleCommandResult();

      case '/model':
        if (args.isEmpty) {
          print('Current model: ${agent.model}');
        } else {
          final newModel = args.join(':');
          if (models.contains(newModel)) {
            try {
              agent = Agent(
                newModel,
                apiKey: apiKeyFrom(newModel),
                tools: tools,
              );
              print('Model set to: $newModel');
            } on Exception catch (ex) {
              print('Error setting model: $ex');
            }
          } else {
            print('Unknown model: $newModel. Use /models to see models.');
          }
        }
        return HandleCommandResult();

      default:
        print('Unknown command: $command');
        return HandleCommandResult();
    }
  }
}
