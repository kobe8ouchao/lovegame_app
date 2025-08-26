import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/ssl_config.dart';

/// 增强的HTTP服务，处理SSL证书问题
class HttpService {
  static const Duration _defaultTimeout = Duration(seconds: 10);

  /// 执行GET请求，自动处理SSL问题
  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      // 首先尝试标准HTTP请求
      return await http
          .get(uri, headers: headers)
          .timeout(timeout ?? _defaultTimeout);
    } catch (e) {
      debugPrint('Standard HTTP request failed: $e');

      // 如果是SSL证书问题，尝试使用代理或其他方法
      if (_isSSLError(e)) {
        return await _handleSSLError(uri, headers, timeout, e);
      }

      rethrow;
    }
  }

  /// 执行POST请求，自动处理SSL问题
  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    try {
      return await http
          .post(uri, headers: headers, body: body)
          .timeout(timeout ?? _defaultTimeout);
    } catch (e) {
      debugPrint('Standard HTTP POST request failed: $e');

      if (_isSSLError(e)) {
        return await _handleSSLError(uri, headers, timeout, e,
            method: 'POST', body: body);
      }

      rethrow;
    }
  }

  /// 检查是否是SSL相关错误
  static bool _isSSLError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('certificate_verify_failed') ||
        errorStr.contains('handshake') ||
        errorStr.contains('ssl') ||
        errorStr.contains('tls');
  }

  /// 处理SSL错误，尝试替代方案
  static Future<http.Response> _handleSSLError(
    Uri uri,
    Map<String, String>? headers,
    Duration? timeout,
    dynamic originalError, {
    String method = 'GET',
    Object? body,
  }) async {
    debugPrint('Handling SSL error for ${uri.toString()}: $originalError');

    // 方案1：尝试使用代理
    try {
      final proxyResponse =
          await _tryWithProxy(uri, headers, timeout, method, body);
      if (proxyResponse != null) {
        debugPrint('Successfully used proxy for ${uri.toString()}');
        return proxyResponse;
      }
    } catch (e) {
      debugPrint('Proxy approach failed: $e');
    }

    // 方案2：尝试使用HTTP而不是HTTPS（如果可能）
    try {
      final httpResponse =
          await _tryWithHttp(uri, headers, timeout, method, body);
      if (httpResponse != null) {
        debugPrint('Successfully used HTTP fallback for ${uri.toString()}');
        return httpResponse;
      }
    } catch (e) {
      debugPrint('HTTP fallback failed: $e');
    }

    // 方案3：使用自定义HTTP客户端（仅开发环境）
    if (kDebugMode) {
      try {
        final customResponse =
            await _tryWithCustomClient(uri, headers, timeout, method, body);
        if (customResponse != null) {
          debugPrint('Successfully used custom client for ${uri.toString()}');
          return customResponse;
        }
      } catch (e) {
        debugPrint('Custom client approach failed: $e');
      }
    }

    // 所有方案都失败，抛出原始错误
    throw originalError;
  }

  /// 尝试使用代理
  static Future<http.Response?> _tryWithProxy(
    Uri uri,
    Map<String, String>? headers,
    Duration? timeout,
    String method,
    Object? body,
  ) async {
    const List<String> proxyUrls = [
      'https://thingproxy.freeboard.io/fetch/',
      'https://api.allorigins.win/raw?url=',
      'https://cors-anywhere.herokuapp.com/',
    ];

    for (String proxyUrl in proxyUrls) {
      try {
        final proxyUri =
            Uri.parse(proxyUrl + Uri.encodeComponent(uri.toString()));
        final response = method == 'GET'
            ? await http
                .get(proxyUri, headers: headers)
                .timeout(timeout ?? _defaultTimeout)
            : await http
                .post(proxyUri, headers: headers, body: body)
                .timeout(timeout ?? _defaultTimeout);

        if (response.statusCode == 200) {
          return response;
        }
      } catch (e) {
        debugPrint('Proxy $proxyUrl failed: $e');
        continue;
      }
    }

    return null;
  }

  /// 尝试使用HTTP而不是HTTPS
  static Future<http.Response?> _tryWithHttp(
    Uri uri,
    Map<String, String>? headers,
    Duration? timeout,
    String method,
    Object? body,
  ) async {
    if (uri.scheme == 'https') {
      try {
        final httpUri = uri.replace(scheme: 'http');
        final response = method == 'GET'
            ? await http
                .get(httpUri, headers: headers)
                .timeout(timeout ?? _defaultTimeout)
            : await http
                .post(httpUri, headers: headers, body: body)
                .timeout(timeout ?? _defaultTimeout);

        if (response.statusCode == 200) {
          return response;
        }
      } catch (e) {
        debugPrint('HTTP fallback failed: $e');
      }
    }

    return null;
  }

  /// 尝试使用自定义HTTP客户端（仅开发环境）
  static Future<http.Response?> _tryWithCustomClient(
    Uri uri,
    Map<String, String>? headers,
    Duration? timeout,
    String method,
    Object? body,
  ) async {
    try {
      final client = SSLConfig.createHttpClient();

      final request = method == 'GET'
          ? await client.openUrl('GET', uri)
          : await client.openUrl('POST', uri);

      // 添加请求头
      if (headers != null) {
        headers.forEach((key, value) {
          request.headers.set(key, value);
        });
      }

      // 添加请求体
      if (method == 'POST' && body != null) {
        request.write(body.toString());
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      client.close();

      return http.Response(responseBody, response.statusCode);
    } catch (e) {
      debugPrint('Custom client failed: $e');
      return null;
    }
  }

  /// 获取用户友好的错误消息
  static String getErrorMessage(dynamic error) {
    return SSLConfig.getSSLErrorMessage(error);
  }
}
