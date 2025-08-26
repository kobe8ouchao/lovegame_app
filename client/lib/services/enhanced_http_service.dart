import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EnhancedHttpService {
  static final EnhancedHttpService _instance = EnhancedHttpService._internal();
  factory EnhancedHttpService() => _instance;
  EnhancedHttpService._internal();

  final Random _random = Random();
  
  final List<String> _userAgents = [
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0',
  ];

  String get _randomUserAgent => _userAgents[_random.nextInt(_userAgents.length)];

  Future<List<dynamic>> getPlayerRankings() async {
    const String url = 'https://www.atptour.com/en/-/www/rank/sglroll/250?v=1';
    debugPrint('Enhanced HTTP获取ATP球员排名数据: $url');

    // 首先访问主页面建立会话
    await _establishSession();
    
    // 等待一段时间模拟真实用户行为
    await Future.delayed(Duration(milliseconds: 500 + _random.nextInt(1000)));

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: _buildHeaders(),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Enhanced HTTP成功获取ATP排名数据，数量: ${data.length}');
        return data;
      } else {
        debugPrint('Enhanced HTTP获取ATP排名数据失败，状态码: ${response.statusCode}');
        
        // 如果失败，尝试重新建立会话后再试一次
        if (response.statusCode == 403 || response.statusCode == 429) {
          debugPrint('检测到反爬机制，等待后重试...');
          await Future.delayed(Duration(seconds: 2 + _random.nextInt(3)));
          return await _retryWithNewSession();
        }
        
        return [];
      }
    } catch (e) {
      debugPrint('Enhanced HTTP请求失败: $e');
      return [];
    }
  }

  Future<void> _establishSession() async {
    try {
      debugPrint('建立ATP Tour会话...');
      
      // 访问主页
      await http.get(
        Uri.parse('https://www.atptour.com/en/rankings/singles'),
        headers: {
          'User-Agent': _randomUserAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Accept-Encoding': 'gzip, deflate, br',
          'DNT': '1',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'none',
          'Cache-Control': 'max-age=0',
        },
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('会话建立完成');
    } catch (e) {
      debugPrint('建立会话失败: $e');
    }
  }

  Map<String, String> _buildHeaders() {
    return {
      'Accept': 'application/json, text/javascript, */*; q=0.01',
      'Accept-Language': 'en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7',
      'Accept-Encoding': 'gzip, deflate, br',
      'Referer': 'https://www.atptour.com/en/rankings/singles',
      'X-Requested-With': 'XMLHttpRequest',
      'User-Agent': _randomUserAgent,
      'DNT': '1',
      'Connection': 'keep-alive',
      'Sec-Fetch-Dest': 'empty',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Site': 'same-origin',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      'Cookie': _buildCookieString(),
    };
  }

  String _buildCookieString() {
    // 使用你提供的cookie，但添加一些随机性
    final baseCookie = '_ga=GA1.1.760912777.1744781494; OptanonAlertBoxClosed=2025-04-16T05:31:41.327Z; _fbp=fb.1.1744781503790.957500700664593250; _tt_enable_cookie=1; _ttp=01JRYH9VSHZ7D93CVMEZ3V9WE5_.tt.1; atp_visitor-id=9ed9e1bf-8859-45a2-84e4-edee66ea25d0';
    
    // 添加一些动态cookie
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sessionId = _generateRandomString(32);
    
    return '$baseCookie; _session_id=$sessionId; _timestamp=$timestamp; __cf_bm=${_generateCloudflareToken()}';
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(_random.nextInt(chars.length)))
    );
  }

  String _generateCloudflareToken() {
    // 生成类似Cloudflare token的字符串
    final part1 = _generateRandomString(43);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final part2 = _generateRandomString(64);
    return '$part1-$timestamp-1.0.1.1-$part2';
  }

  Future<List<dynamic>> _retryWithNewSession() async {
    try {
      // 重新建立会话
      await _establishSession();
      await Future.delayed(Duration(seconds: 1 + _random.nextInt(2)));
      
      const String url = 'https://www.atptour.com/en/-/www/rank/sglroll/250?v=1';
      final response = await http.get(
        Uri.parse(url),
        headers: _buildHeaders(),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('重试成功获取ATP排名数据，数量: ${data.length}');
        return data;
      } else {
        debugPrint('重试仍然失败，状态码: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('重试请求失败: $e');
      return [];
    }
  }
}
