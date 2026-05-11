import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../errors/app_exception.dart';
import '../config/app_config.dart';

/// Lightweight API client using dart:io to avoid extra deps
class ApiClient {
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  const ApiClient({
    this.baseUrl = AppConfig.baseApiUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 20),
  });

  /// POST JSON and return decoded Map
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = connectTimeout;

    try {
      final url = Uri.parse(_fullUrl(path));
      final request = await client.postUrl(url).timeout(connectTimeout);

      // Default headers
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (headers != null) {
        headers.forEach(request.headers.set);
      }

      if (body != null) {
        // Avoid chunked transfer by setting content length explicitly
        final bodyString = jsonEncode(body);
        final bodyBytes = utf8.encode(bodyString);
        request.headers.set(HttpHeaders.contentLengthHeader, bodyBytes.length.toString());
        request.add(bodyBytes);
      }

      final response = await request.close().timeout(receiveTimeout);
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (responseBody.isEmpty) return <String, dynamic>{};
        final decoded = jsonDecode(responseBody);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'data': decoded};
      }

      // Non-2xx
      throw NetworkException(
        message: _extractMessage(responseBody) ??
            'Request failed with status ${response.statusCode}',
        code: response.statusCode.toString(),
      );
    } on SocketException catch (e) {
      throw NetworkException(
        message: 'Network error. Check your connection.',
        originalError: e,
      );
    } on HandshakeException catch (e) {
      throw NetworkException(
        message: 'Secure connection failed.',
        originalError: e,
      );
    } on TimeoutException catch (e) {
      throw NetworkException(
        message: 'Request timed out. Please try again.',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw NetworkException(
        message: 'Invalid server response.',
        originalError: e,
      );
    } finally {
      client.close(force: true);
    }
  }

  /// GET JSON and return decoded Map
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? headers,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = connectTimeout;

    try {
      final url = Uri.parse(_fullUrl(path));
      final request = await client.getUrl(url).timeout(connectTimeout);

      // Default headers
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (headers != null) {
        headers.forEach(request.headers.set);
      }

      final response = await request.close().timeout(receiveTimeout);
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (responseBody.isEmpty) return <String, dynamic>{};
        final decoded = jsonDecode(responseBody);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'data': decoded};
      }

      // Non-2xx
      throw NetworkException(
        message: _extractMessage(responseBody) ??
            'Request failed with status ${response.statusCode}',
        code: response.statusCode.toString(),
      );
    } on SocketException catch (e) {
      throw NetworkException(
        message: 'Network error. Check your connection.',
        originalError: e,
      );
    } on HandshakeException catch (e) {
      throw NetworkException(
        message: 'Secure connection failed.',
        originalError: e,
      );
    } on TimeoutException catch (e) {
      throw NetworkException(
        message: 'Request timed out. Please try again.',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw NetworkException(
        message: 'Invalid server response.',
        originalError: e,
      );
    } finally {
      client.close(force: true);
    }
  }

  /// PUT JSON and return decoded Map
  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = connectTimeout;

    try {
      final url = Uri.parse(_fullUrl(path));
      final request = await client.putUrl(url).timeout(connectTimeout);

      // Default headers
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (headers != null) {
        headers.forEach(request.headers.set);
      }

      if (body != null) {
        // Avoid chunked transfer by setting content length explicitly
        final bodyString = jsonEncode(body);
        final bodyBytes = utf8.encode(bodyString);
        request.headers.set(HttpHeaders.contentLengthHeader, bodyBytes.length.toString());
        request.add(bodyBytes);
      }

      final response = await request.close().timeout(receiveTimeout);
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (responseBody.isEmpty) return <String, dynamic>{};
        final decoded = jsonDecode(responseBody);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'data': decoded};
      }

      // Non-2xx
      throw NetworkException(
        message: _extractMessage(responseBody) ??
            'Request failed with status ${response.statusCode}',
        code: response.statusCode.toString(),
      );
    } on SocketException catch (e) {
      throw NetworkException(
        message: 'Network error. Check your connection.',
        originalError: e,
      );
    } on HandshakeException catch (e) {
      throw NetworkException(
        message: 'Secure connection failed.',
        originalError: e,
      );
    } on TimeoutException catch (e) {
      throw NetworkException(
        message: 'Request timed out. Please try again.',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw NetworkException(
        message: 'Invalid server response.',
        originalError: e,
      );
    } finally {
      client.close(force: true);
    }
  }

  /// PATCH JSON and return decoded Map
  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = connectTimeout;

    try {
      final url = Uri.parse(_fullUrl(path));
      final request = await client.patchUrl(url).timeout(connectTimeout);

      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (headers != null) {
        headers.forEach(request.headers.set);
      }

      if (body != null) {
        final bodyString = jsonEncode(body);
        final bodyBytes = utf8.encode(bodyString);
        request.headers.set(HttpHeaders.contentLengthHeader, bodyBytes.length.toString());
        request.add(bodyBytes);
      }

      final response = await request.close().timeout(receiveTimeout);
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (responseBody.isEmpty) return <String, dynamic>{};
        final decoded = jsonDecode(responseBody);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'data': decoded};
      }

      throw NetworkException(
        message: _extractMessage(responseBody) ??
            'Request failed with status ${response.statusCode}',
        code: response.statusCode.toString(),
      );
    } on SocketException catch (e) {
      throw NetworkException(message: 'Network error. Check your connection.', originalError: e);
    } on HandshakeException catch (e) {
      throw NetworkException(message: 'Secure connection failed.', originalError: e);
    } on TimeoutException catch (e) {
      throw NetworkException(message: 'Request timed out. Please try again.', originalError: e);
    } on FormatException catch (e) {
      throw NetworkException(message: 'Invalid server response.', originalError: e);
    } finally {
      client.close(force: true);
    }
  }

  /// POST multipart form-data (for file uploads)
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, String>? headers,
    required File file,
    required String fieldName,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = connectTimeout;

    try {
      final url = Uri.parse(_fullUrl(path));
      final request = await client.postUrl(url).timeout(connectTimeout);

      // Generate boundary for multipart
      final boundary = '----WebKitFormBoundary${DateTime.now().millisecondsSinceEpoch}';

      request.headers.set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=$boundary');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      if (headers != null) {
        headers.forEach(request.headers.set);
      }

      // Read file bytes
      final fileBytes = await file.readAsBytes();
      final fileName = file.path.split('/').last;

      // Build multipart body
      final bodyBytes = <int>[];

      // Add file part
      bodyBytes.addAll(utf8.encode('--$boundary\r\n'));
      bodyBytes.addAll(utf8.encode('Content-Disposition: form-data; name="$fieldName"; filename="$fileName"\r\n'));
      bodyBytes.addAll(utf8.encode('Content-Type: ${_getContentType(fileName)}\r\n\r\n'));
      bodyBytes.addAll(fileBytes);
      bodyBytes.addAll(utf8.encode('\r\n'));
      bodyBytes.addAll(utf8.encode('--$boundary--\r\n'));

      // Set content length and write body
      request.headers.set(HttpHeaders.contentLengthHeader, bodyBytes.length.toString());
      request.add(bodyBytes);

      final response = await request.close().timeout(receiveTimeout);
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (responseBody.isEmpty) return <String, dynamic>{};
        final decoded = jsonDecode(responseBody);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'data': decoded};
      }

      // Non-2xx
      throw NetworkException(
        message: _extractMessage(responseBody) ??
            'Request failed with status ${response.statusCode}',
        code: response.statusCode.toString(),
      );
    } on SocketException catch (e) {
      throw NetworkException(
        message: 'Network error. Check your connection.',
        originalError: e,
      );
    } on HandshakeException catch (e) {
      throw NetworkException(
        message: 'Secure connection failed.',
        originalError: e,
      );
    } on TimeoutException catch (e) {
      throw NetworkException(
        message: 'Request timed out. Please try again.',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw NetworkException(
        message: 'Invalid server response.',
        originalError: e,
      );
    } finally {
      client.close(force: true);
    }
  }

  String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  String _fullUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$normalizedBase$normalizedPath';
  }

  String? _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) return decoded['message'] as String;
    } catch (_) {}
    return null;
  }
}
