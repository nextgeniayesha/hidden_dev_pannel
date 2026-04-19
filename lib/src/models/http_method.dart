/// Mirrors common HTTP verbs used by Dio and manual captures.
enum HttpCaptureMethod {
  get_,
  post,
  put,
  patch,
  delete_,
  head,
  options;

  static HttpCaptureMethod fromString(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return HttpCaptureMethod.get_;
      case 'POST':
        return HttpCaptureMethod.post;
      case 'PUT':
        return HttpCaptureMethod.put;
      case 'PATCH':
        return HttpCaptureMethod.patch;
      case 'DELETE':
        return HttpCaptureMethod.delete_;
      case 'HEAD':
        return HttpCaptureMethod.head;
      case 'OPTIONS':
        return HttpCaptureMethod.options;
      default:
        return HttpCaptureMethod.post;
    }
  }

  String get name {
    switch (this) {
      case HttpCaptureMethod.get_:
        return 'GET';
      case HttpCaptureMethod.post:
        return 'POST';
      case HttpCaptureMethod.put:
        return 'PUT';
      case HttpCaptureMethod.patch:
        return 'PATCH';
      case HttpCaptureMethod.delete_:
        return 'DELETE';
      case HttpCaptureMethod.head:
        return 'HEAD';
      case HttpCaptureMethod.options:
        return 'OPTIONS';
    }
  }
}
