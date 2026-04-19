import 'dart:collection';
import 'dart:convert';

/// JSON / GraphQL body formatting for the inspector UI.
class JsonPretty {
  static String format(dynamic data) {
    if (data == null) return '-';
    final graphQlEnvelope = _tryFormatGraphQlEnvelope(data);
    if (graphQlEnvelope != null) return graphQlEnvelope;
    final normalized = _normalizeForPretty(data);
    if (normalized == null) return '-';
    if (normalized is String) return normalized;
    try {
      return const JsonEncoder.withIndent('  ').convert(normalized);
    } catch (_) {
      return normalized.toString();
    }
  }

  static String? _tryFormatGraphQlEnvelope(dynamic data) {
    Map<String, dynamic>? map;

    if (data is Map) {
      map = Map<String, dynamic>.from(data);
    } else if (data is String) {
      final decoded = _tryDecodeJsonRecursively(data.trim());
      if (decoded is Map) {
        map = Map<String, dynamic>.from(decoded);
      }
    }
    if (map == null) return null;

    final queryValue = map['query'];
    if (queryValue is! String) return null;
    final formattedQuery = _tryFormatGraphQl(queryValue);
    if (formattedQuery == null) return null;

    final buffer = StringBuffer();
    buffer.writeln('{');
    buffer.writeln('  "query":');
    for (final line in formattedQuery.split('\n')) {
      buffer.writeln('    $line');
    }

    if (map.containsKey('operationName')) {
      buffer.writeln(
        '  , "operationName": ${jsonEncode(map['operationName'])}',
      );
    }
    if (map.containsKey('variables')) {
      final sortedVars = sortJson(map['variables']);
      final varsPretty =
          const JsonEncoder.withIndent('    ').convert(sortedVars);
      buffer.writeln('  , "variables": $varsPretty');
    }
    buffer.write('}');
    return buffer.toString();
  }

  static dynamic _normalizeForPretty(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return '-';
      final decoded = _tryDecodeJsonRecursively(trimmed);
      if (decoded != null) return sortJson(decoded);
      final formattedGraphQl = _tryFormatGraphQl(trimmed);
      if (formattedGraphQl != null) return formattedGraphQl;
      return value;
    }

    if (value is Map || value is List) {
      return sortJson(value);
    }
    return value;
  }

  static dynamic _tryDecodeJsonRecursively(String input) {
    dynamic current = input;
    for (var i = 0; i < 4; i++) {
      if (current is! String) return current;
      final text = current.trim();
      if (text.isEmpty) return null;

      final looksJsonObjectOrArray =
          (text.startsWith('{') && text.endsWith('}')) ||
              (text.startsWith('[') && text.endsWith(']'));
      final looksWrappedJsonString =
          (text.startsWith('"') && text.endsWith('"'));

      if (!looksJsonObjectOrArray && !looksWrappedJsonString) {
        return null;
      }

      try {
        current = jsonDecode(text);
      } catch (_) {
        return null;
      }
    }
    return current is String ? null : current;
  }

  static dynamic sortJson(dynamic value) {
    if (value is Map) {
      final sorted = SplayTreeMap<String, dynamic>();
      value.forEach((key, val) {
        sorted[key.toString()] = sortJson(val);
      });
      return sorted;
    }
    if (value is List) {
      return value.map(sortJson).toList(growable: false);
    }
    if (value is String) {
      final formattedGraphQl = _tryFormatGraphQl(value);
      if (formattedGraphQl != null) return formattedGraphQl;
    }
    return value;
  }

  static String? _tryFormatGraphQl(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;

    final lower = text.toLowerCase();
    final looksGraphQl = (lower.startsWith('query ') ||
            lower.startsWith('mutation ') ||
            lower.startsWith('subscription ') ||
            lower.startsWith('fragment ')) &&
        text.contains('{') &&
        text.contains('}');
    if (!looksGraphQl) return null;

    final out = StringBuffer();
    var indent = 0;
    var inString = false;
    var escaped = false;
    var prevWasSpace = false;

    void writeIndent() => out.write('  ' * indent);

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];

      if (inString) {
        out.write(ch);
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }

      if (ch == '"') {
        inString = true;
        out.write(ch);
        prevWasSpace = false;
        continue;
      }

      if (ch == '{') {
        out.write(' {\n');
        indent++;
        writeIndent();
        prevWasSpace = false;
        continue;
      }

      if (ch == '}') {
        out.write('\n');
        indent = indent > 0 ? indent - 1 : 0;
        writeIndent();
        out.write('}');
        if (i + 1 < text.length && text[i + 1] != '}') {
          out.write('\n');
          writeIndent();
        }
        prevWasSpace = false;
        continue;
      }

      if (ch == ',') {
        out.write(',\n');
        writeIndent();
        prevWasSpace = false;
        continue;
      }

      if (ch == '\n' || ch == '\r' || ch == '\t' || ch == ' ') {
        if (!prevWasSpace) {
          out.write(' ');
          prevWasSpace = true;
        }
        continue;
      }

      out.write(ch);
      prevWasSpace = false;
    }

    return out.toString().trim();
  }
}
