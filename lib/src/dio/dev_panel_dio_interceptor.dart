import 'package:dio/dio.dart';

import '../dev_panel_inspector.dart';
import '../models/captured_http_request.dart';
import '../models/http_method.dart';

/// Records every Dio request/response for [DevPanelInspector].
class DevPanelDioInterceptor extends Interceptor {
  /// [RequestOptions.extra] only allows [String] keys (see Dio `extra` typing).
  static const String _sentExtraKey =
      'hidden_dev_pannel.sent_time';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_sentExtraKey] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _recordFromDio(
      response.requestOptions,
      response.statusCode,
      response.data,
      response.headers.map,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _recordFromDio(
      err.requestOptions,
      err.response?.statusCode,
      err.response?.data ?? err.message,
      err.response?.headers.map ?? const {},
    );
    handler.next(err);
  }

  void _recordFromDio(
    RequestOptions options,
    int? statusCode,
    dynamic body,
    dynamic headers,
  ) {
    final sent = options.extra[_sentExtraKey] as DateTime?;
    final url = options.uri.toString();
    final method = HttpCaptureMethod.fromString(options.method);
    final reqBody = options.data;
    final name = options.path.isNotEmpty ? options.path : url;

    DevPanelInspector().addNewRequest(
      CapturedHttpRequest(
        requestName: name,
        requestMethod: method,
        url: url,
        headers: options.headers,
        requestBody: reqBody,
        sentTime: sent,
        receivedTime: DateTime.now(),
        statusCode: statusCode,
        responseBody: body,
      ),
    );
  }
}
