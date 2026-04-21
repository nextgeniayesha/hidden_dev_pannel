import 'dart:async';
import 'dart:convert';

import 'package:gql/language.dart' show printNode;
import 'package:graphql/client.dart';

import '../dev_panel_inspector.dart';
import '../models/captured_http_request.dart';
import '../models/http_method.dart';

/// Wraps an [HttpLink] and records each GraphQL round-trip for [DevPanelInspector].
///
/// Drop-in replacement for packages that wrapped [HttpLink] only for inspection.
class DevGraphqlInspectorLink extends Link {
  DevGraphqlInspectorLink(this._httpLink);

  final HttpLink _httpLink;

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    final sentTime = DateTime.now();
    final url = _httpLink.uri.toString();
    final headers = <String, String>{
      for (final e in _httpLink.defaultHeaders.entries)
        e.key: e.value.toString(),
    };
    final body = _encodeBody(request);

    return _httpLink
        .request(request, forward)
        .transform(
          StreamTransformer<Response, Response>.fromHandlers(
            handleData: (response, sink) {
              DevPanelInspector().addNewRequest(
                CapturedHttpRequest(
                  requestName:
                      request.operation.operationName ??
                      _shortQueryLabel(request),
                  requestMethod: HttpCaptureMethod.post,
                  url: url,
                  headers: headers,
                  requestBody: body,
                  sentTime: sentTime,
                  receivedTime: DateTime.now(),
                  statusCode: null,
                  responseBody: _encodeGraphqlResponse(response),
                ),
              );
              sink.add(response);
            },
            handleError:
                (Object error, StackTrace stack, EventSink<Response> sink) {
                  DevPanelInspector().addNewRequest(
                    CapturedHttpRequest(
                      requestName:
                          request.operation.operationName ??
                          _shortQueryLabel(request),
                      requestMethod: HttpCaptureMethod.post,
                      url: url,
                      headers: headers,
                      requestBody: body,
                      sentTime: sentTime,
                      receivedTime: DateTime.now(),
                      statusCode: null,
                      responseBody: error.toString(),
                    ),
                  );
                  sink.addError(error, stack);
                },
          ),
        );
  }

  static String _shortQueryLabel(Request request) {
    try {
      final q = printNode(request.operation.document);
      final parts = q.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
      final first = parts.isEmpty ? null : parts.first;
      return first == null ? 'GraphQL' : 'GraphQL $first';
    } catch (_) {
      return 'GraphQL';
    }
  }

  static String? _encodeBody(Request request) {
    try {
      final map = <String, dynamic>{
        'query': printNode(request.operation.document),
      };
      final vars = request.variables;
      if (vars.isNotEmpty) {
        map['variables'] = vars;
      }
      final opName = request.operation.operationName;
      if (opName != null && opName.isNotEmpty) {
        map['operationName'] = opName;
      }
      return jsonEncode(map);
    } catch (_) {
      return null;
    }
  }

  static String _encodeGraphqlResponse(Response response) {
    try {
      final payload = <String, dynamic>{};
      if (response.data != null) {
        payload['data'] = response.data;
      }
      if (response.errors != null && response.errors!.isNotEmpty) {
        payload['errors'] = [
          for (final e in response.errors!)
            <String, dynamic>{
              'message': e.message,
              if (e.path != null) 'path': e.path,
              if (e.extensions != null) 'extensions': e.extensions,
            },
        ];
      }
      final text = jsonEncode(payload);
      if (text.length > 800000) {
        return '${text.substring(0, 800000)}… [truncated]';
      }
      return text;
    } catch (_) {
      return response.toString();
    }
  }
}
