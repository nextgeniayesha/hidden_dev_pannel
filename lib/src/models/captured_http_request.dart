import 'http_method.dart';

/// Single HTTP exchange shown in the API inspector.
class CapturedHttpRequest {
  final String? requestName;
  final HttpCaptureMethod requestMethod;
  final String url;
  final dynamic headers;
  final dynamic requestBody;
  final DateTime? sentTime;
  final DateTime? receivedTime;
  final int? statusCode;
  final dynamic responseBody;

  const CapturedHttpRequest({
    this.requestName,
    required this.requestMethod,
    required this.url,
    this.headers,
    this.requestBody,
    this.sentTime,
    this.receivedTime,
    this.statusCode,
    this.responseBody,
  });

  CapturedHttpRequest copyWith({
    String? requestName,
    HttpCaptureMethod? requestMethod,
    String? url,
    dynamic headers,
    dynamic requestBody,
    DateTime? sentTime,
    DateTime? receivedTime,
    int? statusCode,
    dynamic responseBody,
  }) {
    return CapturedHttpRequest(
      requestName: requestName ?? this.requestName,
      requestMethod: requestMethod ?? this.requestMethod,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      requestBody: requestBody ?? this.requestBody,
      sentTime: sentTime ?? this.sentTime,
      receivedTime: receivedTime ?? this.receivedTime,
      statusCode: statusCode ?? this.statusCode,
      responseBody: responseBody ?? this.responseBody,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (requestName != null) 'requestName': requestName,
      'requestMethod': requestMethod.name,
      'url': url,
      'headers': headers,
      'requestBody': requestBody,
      if (sentTime != null) 'sentTime': sentTime!.toIso8601String(),
      if (receivedTime != null) 'receivedTime': receivedTime!.toIso8601String(),
      if (statusCode != null) 'statusCode': statusCode,
      'responseBody': responseBody,
    };
  }
}
