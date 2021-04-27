import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:pretty_json/pretty_json.dart';

void help(ArgParser argParser) {
  print('>>> repo is a basic app for the GitHub API');
  print('>>> Usage: repo <command> [options] [repo name]');
  print('>>> Valid commands: ${argParser.commands.keys.toList()}');
  print('>>> Valid options:\n${argParser.usage}');
}

void create(ArgResults results) async {
  final token = await _token(results);
  final private = results.wasParsed('private');
  final repo = _repo(results.command?.rest ?? []);

  print('Preparing to create ${private ? 'private' : 'public'} repo $repo');

  final headers = {'Authorization': 'token $token'};
  final url = Uri.https('api.github.com', '/user/repos');
  final payload = json.encode({'name': repo, 'private': private});
  final response = await http.post(url, headers: headers, body: payload);

  if (response.statusCode >= 200 && response.statusCode < 300) {
    print('Succesfully create $repo');
    if (results.wasParsed('verbose')) {
      print(prettyJson(json.decode(response.body), indent: 4));
    }
  } else {
    print('Error: ${response.statusCode}');
    print(prettyJson(json.decode(response.body), indent: 4));
  }
}

void delete(ArgResults results) async {
  final token = await _token(results);
  final repo = _repo(results.command?.rest ?? []);

  if (!results.wasParsed('yes')) {
    stdout.write('Confirm to delete $repo (y/n): ');
    final input = stdin.readLineSync() ?? '';
    if (input.isEmpty || input[0].toUpperCase() != 'Y') return;
  }

  print('Preparing to delete $repo');
  final headers = {'Authorization': 'token $token'};
  final url = Uri.https('api.github.com', '/repos/berkobob/$repo');
  final response = await http.delete(url, headers: headers);

  if (response.statusCode >= 200 && response.statusCode < 300) {
    print('Succesfully deleted $repo');
  } else {
    print('Error: ${response.statusCode}');
    print(prettyJson(json.decode(response.body), indent: 4));
  }
}

void main(List<String> args) {
  final argParser = ArgParser(allowTrailingOptions: false)
    ..addOption('token', abbr: 't', help: 'Your Github API token')
    ..addFlag('private', abbr: 'p', help: 'Is this repo private?')
    ..addFlag('verbose', abbr: 'v', help: 'Print JSON API response')
    ..addFlag('yes',
        abbr: 'y', help: 'Confirm to delete repo', negatable: false)
    ..addCommand('help')
    ..addCommand('create')
    ..addCommand('delete')
    ..addFlag('help', abbr: 'h', help: 'This help message', negatable: false);

  final results = argParser.parse(args);

  if (results.wasParsed('help') || results.arguments.isEmpty) {
    help(argParser);
    exit(0);
  }

  switch (results.command?.name) {
    case 'help':
      help(argParser);
      break;
    case 'create':
      create(results);
      break;
    case 'delete':
      delete(results);
      break;
    default:
      print('Invalid command: ${results.rest}');
      help(argParser);
  }
}

String _repo(List<String> rest) {
  if (rest.isNotEmpty) return rest[0];
  var name = '';
  stdout.write('Enter repo name: ');
  // ignore: curly_braces_in_flow_control_structures
  while (name == '') name = stdin.readLineSync() ?? '';
  return name;
}

Future<String> _token(ArgResults results) async {
  var token = '';
  if (results.wasParsed('token')) token = results['token'];

  if (token == '' && Platform.environment.keys.contains('token')) {
    token = Platform.environment['token']!;
  }

  final pat = File('.pat');
  if (token == '' && await pat.exists()) token = await pat.readAsString();

  while (token == '') {
    stdout.write('Enter Personal Access Token: ');
    token = stdin.readLineSync() ?? '';
  }

  await pat.writeAsString(token, flush: true);

  return token;
}
