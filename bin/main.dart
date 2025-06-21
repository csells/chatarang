// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dotenv/dotenv.dart';
import 'package:http/http.dart' as http;

const defaultModel = 'google';

//
// Tools
//

final tools = [
  Tool(
    name: 'current-time',
    description: 'Get the current time.',
    onCall: (args) async => {'result': DateTime.now().toIso8601String()},
  ),
  Tool(
    name: 'current-date',
    description: 'Get the current date.',
    onCall: (args) async => {'result': DateTime.now().toIso8601String()},
  ),
  Tool(
    name: 'location-to-zipcode',
    description: 'Get the zipcode for a location.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'location': {
          'type': 'string',
          'description': 'The location to get the zipcode for.',
        },
      },
      'required': ['location'],
    }.toSchema(),
    onCall: (args) async {
      // In a real app, this would use a geocoding API
      final location = args['location'];
      return {'result': '90210'};
    },
  ),
  Tool(
    name: 'weather',
    description: 'Get the weather for a zipcode.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'zipcode': {
          'type': 'string',
          'description': 'The zipcode to get the weather for.',
        },
      },
      'required': ['zipcode'],
    }.toSchema(),
    onCall: (args) async {
      final zipcode = args['zipcode'];
      if (zipcode == null) return {'error': 'zipcode is required'};

      try {
        final uri = Uri.parse('https://wttr.in/$zipcode?format=j1');
        final response = await http.get(uri);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final condition =
              // ignore: avoid_dynamic_calls
              data['current_condition'][0]['weatherDesc'][0]['value'];
          return {'result': condition};
        } else {
          return {'error': 'Failed to get weather for $zipcode'};
        }
      } on Exception catch (e) {
        return {'error': 'Error getting weather for $zipcode: $e'};
      }
    },
  ),
  Tool(
    name: 'surf-web',
    description: 'Get the content of a web page.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'link': {
          'type': 'string',
          'description': 'The URL of the web page to get the content of.',
        },
      },
      'required': ['link'],
    }.toSchema(),
    onCall: (args) async {
      final link = args['link'];
      final uri = Uri.parse(link);
      final response = await http.get(uri);
      return {'result': response.body};
    },
  ),
];

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
  /models [filter] to show available models
  /messages to show conversation history
  /help to show this message again

Everything else you type will be sent to the current model.
''';

  print(help);

  // things to track
  var messages = <Message>[];
  final messageModels = <String>[];
  var agent = Agent(
    defaultModel,
    apiKey: apiKeyFrom(defaultModel),
    tools: tools,
  );

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
        case '/models':
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
              final role = message.role;
              switch (role) {
                case MessageRole.user:
                  print('\x1B[94mYou\x1B[0m: ${message.text}');
                case MessageRole.model:
                  final modelName = modelMessageIndex < messageModels.length
                      ? messageModels[modelMessageIndex++]
                      : agent.model;
                  for (final part in message.parts) {
                    if (part is TextPart) {
                      print('\x1B[93m$modelName\x1B[0m: ${part.text}');
                    } else if (part is ToolPart) {
                      if (part.kind == ToolPartKind.call) {
                        final args = const JsonEncoder.withIndent(
                          '  ',
                        ).convert(part.arguments);
                        print('\x1B[95mTool Call\x1B[0m: ${part.name}\n$args');
                      } else {
                        // result
                        print(
                          '\x1B[96mTool Result for ${part.id}\x1B[0m: '
                          '${part.result}',
                        );
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
          continue;
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
          continue;
        default:
          print('Unknown command: $command');
          continue;
      }
    }

    final oldModelMessageCount = messages
        .where((m) => m.role == MessageRole.model)
        .length;

    // Use streaming to show responses in real-time
    final stream = agent.runStream(line, messages: messages);

    stdout.write('\x1B[93m${agent.model}\x1B[0m: ');
    await for (final response in stream) {
      stdout.write(response.output);
      // Update messages for the next interaction
      messages = response.messages;
    }

    final newModelMessageCount = messages
        .where((m) => m.role == MessageRole.model)
        .length;
    if (newModelMessageCount > oldModelMessageCount) {
      for (var i = 0; i < newModelMessageCount - oldModelMessageCount; i++) {
        messageModels.add(agent.model);
      }
    }

    stdout.write('\n');
  }

  exit(0);
}
