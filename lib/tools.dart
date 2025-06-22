import 'dart:convert';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:http/http.dart' as http;

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
    name: 'weather',
    description: 'Get the weather for a US zipcode',
    inputSchema: {
      'type': 'object',
      'properties': {
        'zipcode': {
          'type': 'string',
          'description': 'The US zipcode to get the weather for.',
        },
      },
      'required': ['zipcode'],
    }.toSchema(),
    onCall: (input) async {
      final zipcode = input['zipcode'];
      final url = Uri.parse('https://wttr.in/US~$zipcode?format=j1');
      final response = await http.get(url);
      if (response.statusCode != 200) {
        return {'error': 'Error getting weather: ${response.body}'};
      }

      return {'result': jsonDecode(response.body)};
    },
  ),
  Tool(
    name: 'location-lookup',
    description: 'Get location data for a given search query.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'location': {
          'type': 'string',
          'description': 'The location to get the data for.',
        },
      },
      'required': ['location'],
    }.toSchema(),
    onCall: (input) async {
      final location = input['location'];
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': location,
          'format': 'jsonv2',
          'addressdetails': '1',
          'extratags': '1',
          'namedetails': '1',
        });
        final response = await http.get(uri);
        final searchResults = json.decode(response.body) as List<dynamic>;

        if (searchResults.isEmpty) {
          return {'error': 'Could not find a location for $location'};
        }

        return {'result': searchResults};
      } on Exception catch (e) {
        return {'error': 'Could not find a location for $location: $e'};
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
      final link = args['link'] as String?;
      if (link == null) {
        return {'error': 'link is required'};
      }
      final uri = Uri.parse(link);
      final response = await http.get(uri);
      return {'result': response.body};
    },
  ),
];
