import 'dart:convert';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:geocoding/geocoding.dart';
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
      final url = Uri.parse('https://wttr.in/$zipcode?format=j1');
      final response = await http.get(url);
      if (response.statusCode != 200) {
        return {'error': 'Error getting weather: ${response.body}'};
      }

      return {'result': jsonDecode(response.body)};
    },
  ),
  Tool(
    name: 'location-to-zipcode',
    description: 'Get the zipcode for a location',
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
    onCall: (input) async {
      final location = input['location'];
      try {
        final locations = await locationFromAddress(location);
        if (locations.isEmpty) {
          return {'error': 'Could not find a zipcode for $location'};
        }
        // just get the first one
        final placemarks = await placemarkFromCoordinates(
          locations.first.latitude,
          locations.first.longitude,
        );
        if (placemarks.isEmpty) {
          return {'error': 'Could not find a zipcode for $location'};
        }
        return {'result': placemarks.first.postalCode};
      } on NoResultFoundException {
        return {'error': 'Could not find a zipcode for $location'};
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
