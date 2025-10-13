/*
 * @Descripttion: 
 * @Author: ouchao
 * @Email: ouchao@sendpalm.com
 * @version: 1.0
 * @Date: 2025-04-21 17:22:17
 * @LastEditors: ouchao
 * @LastEditTime: 2025-09-12 14:35:30
 */
import 'package:LoveGame/utils/timezone_mapping.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:html/dom.dart' as dom;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'http_service.dart';

class ApiService {
  // 创建自定义HTTP客户端，处理SSL证书问题
  static http.Client? _httpClient;

  static http.Client get _client {
    _httpClient ??= _createHttpClient();
    return _httpClient!;
  }

  static http.Client _createHttpClient() {
    if (kIsWeb) {
      return http.Client();
    } else {
      // 在移动平台上创建支持SSL的客户端
      return http.Client();
    }
  }

  // 创建支持SSL的HTTP请求
  static Future<http.Response> _makeHttpRequest(
      Uri uri, Map<String, String> headers,
      {Duration? timeout}) async {
    try {
      if (kIsWeb) {
        // Web平台使用标准HTTP客户端
        return await http
            .get(uri, headers: headers)
            .timeout(timeout ?? const Duration(seconds: 10));
      } else {
        // 移动平台使用自定义客户端
        print('mobile ----=====uri: $uri');
        return await _client
            .get(uri, headers: headers)
            .timeout(timeout ?? const Duration(seconds: 10));
      }
    } catch (e) {
      if (e.toString().contains('CERTIFICATE_VERIFY_FAILED')) {
        // 如果SSL证书验证失败，尝试使用不安全的连接（仅用于开发/测试）
        debugPrint(
            'SSL certificate verification failed, attempting alternative approach: $e');

        // 对于开发环境，可以尝试跳过证书验证
        if (kDebugMode) {
          try {
            // 创建新的URI，尝试不同的协议或代理
            final alternativeUri = _buildAlternativeUri(uri);
            return await _client
                .get(alternativeUri, headers: headers)
                .timeout(timeout ?? const Duration(seconds: 10));
          } catch (altError) {
            debugPrint('Alternative approach also failed: $altError');
          }
        }
      }
      rethrow;
    }
  }

  // 构建替代URI，尝试不同的代理或协议
  static Uri _buildAlternativeUri(Uri originalUri) {
    // 如果当前代理失败，尝试下一个代理
    _rotateProxy();
    return Uri.parse(
        _currentProxyUrl + Uri.encodeComponent(originalUri.toString()));
  }

  // 获取WTA比赛统计数据
  static Future<Map<String, dynamic>> getWTAMatchStats(
      String url, String tournament, String matchId) async {
    try {
      final matchScore = await getWTAMatcheScore(tournament, matchId);
      debugPrint('getWTAMatcheScore-------matchScore $matchScore');
      if (matchScore.isEmpty) {
        return {};
      }

      // 添加空值检查
      String city = '';
      if (matchScore['Tournament'] != null &&
          matchScore['Tournament']['city'] != null) {
        city = matchScore['Tournament']['city'].toString().toLowerCase();
        // 将空格替换为短横线
        city = city.replaceAll(' ', '-');
      } else {
        debugPrint('警告: Tournament或city为空，使用默认值');
        // 使用默认值或从其他地方获取城市名
        city = 'default';
      }

      String matchUrl =
          'https://www.wtatennis.com/tournaments/$tournament/$city/2025/scores/$matchId';
      final Uri uri = _buildUri(matchUrl, 'wta');
      final response = await HttpService.get(uri);
      var htmlContent = "";
      if (response.statusCode == 200) {
        htmlContent = response.body;
      }
      // 使用HeadlessInAppWebView获取HTML内容
      // debugPrint('开始获取WTA比赛HTML内容，URL: $matchUrl-$city');
      // final htmlContent = await _getWTAMatchHtmlWithWebView(matchUrl);
      // debugPrint('获取到WTA比赛HTML内容长度: ${htmlContent.length}');

      if (htmlContent.isNotEmpty) {
        final document = parse(htmlContent);
        Map<String, dynamic> matchStats = {
          'Tournament': {},
          'Match': {
            'TeamTieResults': null,
            'MatchId': matchId,
            'IsDoubles': false,
            'RoundName': '',
            'Round': {
              'RoundId': 4,
              'ShortName': 'R16',
              'LongName': 'Round of 16',
              'ScRoundName': 'Round of 16'
            },
            'CourtName': '',
            'MatchTimeTotal': matchScore['MatchTimeTotal'],
            'MatchTime': matchScore['MatchTimeTotal'],
            'ExtendedMessage': '',
            'Message': '',
            'MatchStatus': matchScore['MatchStatus'],
            'Status': 'F',
            'ServerTeam': -1,
            'LastServer': null,
            'WinningPlayerId': 'MM58',
            'Winner': 'MM58',
            'DateSeq': '9',
            'IsQualifier': false,
            'IsWatchLive': null,
            'NumberOfSets': matchScore['NumSets'],
            'ScoringSystem': '1',
            'Reason': null,
            'PlayerTeam': {
              'Player': {
                'PlayerId': "${matchScore['PlayerIDA']}",
                'PlayerCountry': "${matchScore['PlayerCountryA']}",
                'PlayerFirstName': "${matchScore['PlayerNameFirstA']}",
                'PlayerLastName': "${matchScore['PlayerNameLastA']}",
                'PlayerCountryName': ''
              },
              'SetScores': [],
              'YearToDateStats': {}
            },
            'OpponentTeam': {
              'Player': {
                'PlayerId': "${matchScore['PlayerIDB']}",
                'PlayerCountry': "${matchScore['PlayerCountryB']}",
                'PlayerFirstName': "${matchScore['PlayerNameFirstB']}",
                'PlayerLastName': "${matchScore['PlayerNameLastB']}",
                'PlayerCountryName': ''
              },
              'SetScores': [],
              'YearToDateStats': {}
            }
          }
        };

        // 获取所有统计数据标签页内容
        final tabContents =
            document.getElementsByClassName('mc-stats__tab-content');

        if (tabContents.isNotEmpty) {
          // 第一个是比赛总体统计
          final matchStatsBlock = _parseWTAStatsBlock(tabContents[0], 0);
          matchStats['Match']['PlayerTeam']['SetScores'].add({
            'Stats': matchStatsBlock['player1Stats'],
            'SetScore': null,
            'TieBreakScore': null
          });

          matchStats['Match']['OpponentTeam']['SetScores'].add({
            'Stats': matchStatsBlock['player2Stats'],
            'SetScore': null,
            'TieBreakScore': null
          });

          debugPrint(
              'matchStats Match PlayerTeam====: ${matchStats['Match']['PlayerTeam']['SetScores']}');
          debugPrint(
              'matchStats Match OpponentTeam====: ${matchStats['Match']['OpponentTeam']['SetScores']}');

          // 剩余的是每盘统计
          for (var i = 1; i < tabContents.length; i++) {
            final setStats = _parseWTAStatsBlock(tabContents[i], i);
            if (setStats['player1Stats']['ServiceStats'] == null) {
              continue;
            }
            String setScore1 = '';
            String setScore2 = '';
            String tie1 = '';
            String tie2 = '';
            switch (i) {
              case 1:
                setScore1 = "${matchScore['ScoreSet1A']}";
                setScore2 = "${matchScore['ScoreSet1B']}";
                tie1 = "${matchScore['ScoreSet1A']}";
                tie2 = "${matchScore['ScoreSet1B']}";
                break;
              case 2:
                setScore1 = "${matchScore['ScoreSet2A']}";
                setScore2 = "${matchScore['ScoreSet2B']}";
                tie1 = "${matchScore['ScoreSet1A']}";
                tie2 = "${matchScore['ScoreSet1B']}";
                break;
              case 3:
                setScore1 = "${matchScore['ScoreSet3A']}";
                setScore2 = "${matchScore['ScoreSet3B']}";
                tie1 = "${matchScore['ScoreSet1A']}";
                tie2 = "${matchScore['ScoreSet1B']}";
                break;
              default:
                break;
            }

            matchStats['Match']['PlayerTeam']['SetScores'].add({
              'Stats': setStats['player1Stats'],
              'SetScore': setScore1.isNotEmpty ? setScore1 : null,
              'TieBreakScore': null
            });
            matchStats['Match']['OpponentTeam']['SetScores'].add({
              'Stats': setStats['player2Stats'],
              'SetScore': setScore2.isNotEmpty ? setScore2 : null,
              'TieBreakScore': null
            });
          }
        }

        return matchStats;
      } else {
        throw Exception('获取WTA比赛HTML内容为空');
      }
    } catch (e) {
      debugPrint('获取WTA比赛统计数据异常: $e');
      return {};
    }
  }

  // 解析WTA统计数据块
  static Map<String, dynamic> _parseWTAStatsBlock(dom.Element block, index) {
    Map<String, dynamic> stats = {
      'player1Stats': {}, // 初始化 player1Stats
      'player2Stats': {} // 初始化 player2Stats
    };
    // 获取所有统计块
    final statBlocks = block.getElementsByClassName('compare-stats-block');

    int i = 0;
    for (var statBlock in statBlocks) {
      if (i == 0) {
        i++;
        continue;
      }
      final rows = statBlock.getElementsByClassName('compare-stats-block__row');
      // 第一个块：发球统计
      if (stats['player1Stats']['ServiceStats'] == null) {
        Map<String, dynamic> serviceStats1 = {};
        Map<String, dynamic> serviceStats2 = {};
        for (var row in rows) {
          final label = row
              .getElementsByClassName('compare-stats-block__label')
              .first
              .text
              .trim()
              .replaceAll(' ', '');
          final cols =
              row.getElementsByClassName('compare-stats-block__content-col');

          if (cols.length >= 3) {
            final player1Value = cols[0].text.trim();
            final player2Value = cols[2].text.trim();
            // 检查是否有详细数据
            final details1 =
                cols[0].getElementsByClassName('compare-stats-block__detail');
            if (details1.isNotEmpty) {
              // 处理类似 "10/100" 的数据
              final player1Parts = details1.first.text.trim().split('/');
              serviceStats1[label] = {
                'Dividend': int.tryParse(player1Parts[0]) ?? 0,
                'Divisor': int.tryParse(player1Parts[1]) ?? 0
              };
            } else {
              serviceStats1[label] = {
                'Number': int.tryParse(player1Value) ?? 0,
              };
            }
            final details2 =
                cols[2].getElementsByClassName('compare-stats-block__detail');
            if (details2.isNotEmpty) {
              // 处理类似 "10/100" 的数据
              final player2Parts = details2.first.text.trim().split('/');
              serviceStats2[label] = {
                'Dividend': int.tryParse(player2Parts[0]) ?? 0,
                'Divisor': int.tryParse(player2Parts[1]) ?? 0
              };
            } else {
              serviceStats2[label] = {
                'Number': int.tryParse(player2Value) ?? 0,
              };
            }
          }
        }

        stats['player1Stats']['ServiceStats'] = serviceStats1;
        stats['player2Stats']['ServiceStats'] = serviceStats2;
      }
      // 第二个块：接发球统计
      else if (stats['player1Stats']['ReturnStats'] == null) {
        Map<String, dynamic> returnStats1 = {};
        Map<String, dynamic> returnStats2 = {};
        for (var row in rows) {
          final label = row
              .getElementsByClassName('compare-stats-block__label')
              .first
              .text
              .trim()
              .replaceAll(' ', '');
          final cols =
              row.getElementsByClassName('compare-stats-block__content-col');

          if (cols.length >= 3) {
            final player1Value = cols[0].text.trim();
            final player2Value = cols[2].text.trim();

            final details1 =
                cols[0].getElementsByClassName('compare-stats-block__detail');
            if (details1.isNotEmpty) {
              final player1Parts = details1.first.text.trim().split('/');

              returnStats1[label] = {
                'Dividend': int.tryParse(player1Parts[0]) ?? 0,
                'Divisor': int.tryParse(player1Parts[1]) ?? 0
              };
              debugPrint('label=============$label ${returnStats1[label]}');
            } else {
              returnStats1[label] = {'Number': int.tryParse(player1Value) ?? 0};
            }
            final details2 =
                cols[2].getElementsByClassName('compare-stats-block__detail');
            if (details2.isNotEmpty) {
              final player2Parts = details2.first.text.trim().split('/');
              returnStats2[label] = {
                'Dividend': int.tryParse(player2Parts[0]) ?? 0,
                'Divisor': int.tryParse(player2Parts[1]) ?? 0
              };
            } else {
              returnStats2[label] = {'Number': int.tryParse(player2Value) ?? 0};
            }
          }
        }

        stats['player1Stats']['ReturnStats'] = returnStats1;
        stats['player2Stats']['ReturnStats'] = returnStats2;
      }
      // 第三个块：得分统计
      else {
        Map<String, dynamic> pointStats1 = {};
        Map<String, dynamic> pointStats2 = {};
        for (var row in rows) {
          final label = row
              .getElementsByClassName('compare-stats-block__label')
              .first
              .text
              .trim()
              .replaceAll(' ', '');
          final cols =
              row.getElementsByClassName('compare-stats-block__content-col');

          if (cols.length >= 3) {
            final player1Value = cols[0].text.trim();
            final player2Value = cols[2].text.trim();

            final details1 =
                cols[0].getElementsByClassName('compare-stats-block__detail');
            if (details1.isNotEmpty) {
              final player1Parts = details1.first.text.trim().split('/');

              pointStats1[label] = {
                'Dividend': int.tryParse(player1Parts[0]) ?? 0,
                'Divisor': int.tryParse(player1Parts[1]) ?? 0
              };
            } else {
              pointStats1[label] = {'Number': int.tryParse(player1Value) ?? 0};
            }
            final details2 =
                cols[2].getElementsByClassName('compare-stats-block__detail');
            if (details2.isNotEmpty) {
              final player2Parts = details2.first.text.trim().split('/');
              pointStats2[label] = {
                'Dividend': int.tryParse(player2Parts[0]) ?? 0,
                'Divisor': int.tryParse(player2Parts[1]) ?? 0
              };
            } else {
              pointStats2[label] = {'Number': int.tryParse(player2Value) ?? 0};
            }
          }
        }
        stats['player1Stats']['PointStats'] = pointStats1;
        stats['player2Stats']['PointStats'] = pointStats2;
      }
    }
    i++;
    return stats;
  }

  static const String _baseUrl = 'https://www.atptour.com';
  static const List<String> _proxyUrls = [
    'https://api.allorigins.win/raw?url=',
    'https://cors-anywhere.herokuapp.com/',
    'https://thingproxy.freeboard.io/fetch/',
    'https://corsproxy.io/?',
    'https://api.codetabs.com/v1/proxy?quest=',
    'https://yacdn.org/proxy/',
    'https://cors.bridged.cc/',
    'https://crossorigin.me/',
  ];
  static int _currentProxyIndex = 0;

  static String get _currentProxyUrl {
    return _proxyUrls[_currentProxyIndex];
  }

  static void _rotateProxy() {
    _currentProxyIndex = (_currentProxyIndex + 1) % _proxyUrls.length;
  }

  // 构建URI，根据平台决定是否使用代理
  static Uri _buildUri(String endpoint, String type) {
    String fullUrls = _baseUrl + endpoint;
    if (kIsWeb) {
      if (type == 'wta') {
        if (endpoint.contains('https')) {
          fullUrls = endpoint;
        } else {
          fullUrls = 'https://api.wtatennis.com$endpoint';
        }
      }

      try {
        return Uri.parse(_currentProxyUrl + Uri.encodeComponent(fullUrls));
      } catch (e) {
        _rotateProxy(); // 如果当前代理有问题，轮换到下一个
        return Uri.parse(_currentProxyUrl + Uri.encodeComponent(fullUrls));
      }
    } else {
      // 移动平台直接请求
      if (type == 'wta') {
        if (endpoint.contains('https')) {
          fullUrls = endpoint;
        } else {
          fullUrls = 'https://api.wtatennis.com$endpoint';
        }
      }
      return Uri.parse(_currentProxyUrl + Uri.encodeComponent(fullUrls));
    }
  }

  // 获取ATP赛事日历数据
  static Future<Map<String, dynamic>> getTournamentCalendar() async {
    try {
      const String endpoint = '/en/-/tournaments/calendar/tour';
      final Uri uri = _buildUri(endpoint, '');

      final response = await _makeHttpRequest(
        uri,
        {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
        timeout: const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to get tournament calendar data: $e');
      rethrow;
    }
  }

  // 加载本地比赛数据
  static Future<Map<String, dynamic>> loadLocalTournamentData() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/2025_atp_tournament.json');
      return json.decode(jsonString);
    } catch (e) {
      print('Failed to load local tournament data: $e');
      return {};
    }
  }

  // 根据当前日期查找正在进行的比赛
  static Future<List<Map<String, dynamic>>> findCurrentTournaments() async {
    final tournamentData = await loadLocalTournamentData();
    final DateTime now = DateTime.now();

    List<Map<String, dynamic>> currentTournaments = [];

    if (tournamentData.containsKey('TournamentDates')) {
      for (var dateGroup in tournamentData['TournamentDates']) {
        for (var tournament in dateGroup['Tournaments']) {
          // 解析比赛的开始和结束日期
          final startDate = DateTime.parse(tournament['startDate']);
          final endDate = DateTime.parse(tournament['endDate']);
          if (kDebugMode) {
            print('$startDate ==== $endDate');
          }
          // 检查当前日期是否在比赛日期范围内
          if (now.isAfter(startDate) &&
              now.isBefore(endDate.add(const Duration(days: 1)))) {
            currentTournaments.add(tournament);
          }
        }
      }
    }
    return currentTournaments;
  }

  // 使用HeadlessInAppWebView获取WTA比赛HTML内容
  static Future<String> _getWTAMatchHtmlWithWebView(String matchUrl) async {
    final completer = Completer<String>();
    HeadlessInAppWebView? headlessWebView;

    try {
      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(matchUrl)),
        initialSettings: InAppWebViewSettings(
          userAgent:
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          javaScriptEnabled: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          clearCache: false,
        ),
        onWebViewCreated: (controller) {
          debugPrint('WTA比赛页面 HeadlessInAppWebView创建成功');
        },
        onLoadStart: (controller, url) {
          debugPrint('开始加载WTA比赛页面: $url');
        },
        onLoadStop: (controller, url) async {
          debugPrint('WTA比赛页面加载完成: $url');

          try {
            // 等待页面完全渲染
            await Future.delayed(const Duration(seconds: 2));

            // 获取页面HTML内容
            final jsCode = '''
              (function() {
                try {
                  console.log('开始获取WTA比赛页面HTML...');
                  return document.documentElement.outerHTML;
                } catch (e) {
                  console.error('获取HTML时出错:', e);
                  return '';
                }
              })()
            ''';

            final result = await controller.evaluateJavascript(source: jsCode);
            debugPrint('WTA比赛HTML获取结果长度: ${result?.toString().length ?? 0}');

            if (result != null && result.toString().isNotEmpty) {
              completer.complete(result.toString());
            } else {
              debugPrint('WTA比赛HTML为空，尝试重新获取');
              await Future.delayed(const Duration(seconds: 2));
              final retryResult =
                  await controller.evaluateJavascript(source: jsCode);
              completer.complete(retryResult?.toString() ?? '');
            }
          } catch (e) {
            debugPrint('获取WTA比赛HTML时出错: $e');
            completer.complete('');
          }
        },
        onReceivedError: (controller, request, error) {
          debugPrint('WTA比赛WebView加载错误: ${error.description}');
          if (!completer.isCompleted) {
            completer.complete('');
          }
        },
        onReceivedHttpError: (controller, request, errorResponse) {
          debugPrint(
              'WTA比赛HTTP错误: ${errorResponse.statusCode}, URL: ${request.url}');
          // 记录更详细的错误信息
          debugPrint('WTA比赛HTTP错误详情: ${errorResponse.reasonPhrase}');
          if (!completer.isCompleted) {
            completer.complete('');
          }
        },
      );

      await headlessWebView.run();

      // 设置超时
      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('WTA比赛WebView请求超时');
          return '';
        },
      );

      return result;
    } catch (e) {
      debugPrint('WTA比赛HeadlessInAppWebView异常: $e');
      return '';
    } finally {
      try {
        await headlessWebView?.dispose();
        debugPrint('WTA比赛HeadlessInAppWebView已释放');
      } catch (e) {
        debugPrint('释放WTA比赛WebView时出错: $e');
      }
    }
  }

  // 使用HeadlessInAppWebView获取赛程HTML内容
  static Future<String> _getScheduleHtmlWithWebView(String scheduleUrl) async {
    final completer = Completer<String>();
    HeadlessInAppWebView? headlessWebView;

    try {
      final String fullUrl = 'https://www.atptour.com$scheduleUrl';

      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(fullUrl)),
        initialSettings: InAppWebViewSettings(
          userAgent:
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          javaScriptEnabled: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          clearCache: false,
        ),
        onWebViewCreated: (controller) {
          debugPrint('赛程页面 HeadlessInAppWebView创建成功');
        },
        onLoadStart: (controller, url) {
          debugPrint('开始加载赛程页面: $url');
        },
        onLoadStop: (controller, url) async {
          debugPrint('赛程页面加载完成: $url');

          try {
            // 等待页面完全渲染
            await Future.delayed(const Duration(seconds: 2));

            // 获取页面HTML内容
            final jsCode = '''
              (function() {
                try {
                  console.log('开始获取赛程页面HTML...');
                  return document.documentElement.outerHTML;
                } catch (e) {
                  console.error('获取HTML时出错:', e);
                  return '';
                }
              })()
            ''';

            final result = await controller.evaluateJavascript(source: jsCode);
            debugPrint('赛程HTML获取结果长度: ${result?.toString().length ?? 0}');

            if (result != null && result.toString().isNotEmpty) {
              completer.complete(result.toString());
            } else {
              debugPrint('赛程HTML为空，尝试重新获取');
              await Future.delayed(const Duration(seconds: 2));
              final retryResult =
                  await controller.evaluateJavascript(source: jsCode);
              completer.complete(retryResult?.toString() ?? '');
            }
          } catch (e) {
            debugPrint('获取赛程HTML时出错: $e');
            completer.complete('');
          }
        },
        onReceivedError: (controller, request, error) {
          debugPrint('赛程WebView加载错误: ${error.description}');
          if (!completer.isCompleted) {
            completer.complete('');
          }
        },
        onReceivedHttpError: (controller, request, errorResponse) {
          debugPrint('赛程HTTP错误: ${errorResponse.statusCode}');
          if (!completer.isCompleted) {
            completer.complete('');
          }
        },
      );

      await headlessWebView.run();

      // 设置超时
      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('赛程WebView请求超时');
          return '';
        },
      );

      return result;
    } catch (e) {
      debugPrint('赛程HeadlessInAppWebView异常: $e');
      return '';
    } finally {
      try {
        await headlessWebView?.dispose();
        debugPrint('赛程HeadlessInAppWebView已释放');
      } catch (e) {
        debugPrint('释放赛程WebView时出错: $e');
      }
    }
  }

  // 获取当日巡回赛比赛数据
  static Future<Map<String, List<Map<String, dynamic>>>>
      getScheduelTournamentMatches(DateTime date) async {
    Map<String, List<Map<String, dynamic>>> matchesByDate = {};
    try {
      // 1. 从本地加载巡回赛数据
      final tournamentData = await loadLocalTournamentData();
      final DateTime now = date;
      final List<Map<String, dynamic>> todayTournaments = [];

      // 2. 查找当日进行的巡回赛
      if (tournamentData.containsKey('TournamentDates')) {
        for (var dateGroup in tournamentData['TournamentDates']) {
          for (var tournament in dateGroup['Tournaments']) {
            // 解析比赛的开始和结束日期
            final startDate = DateTime.parse(tournament['startDate']);
            final endDate = DateTime.parse(tournament['endDate']);

            // 检查当前日期是否在比赛日期范围内
            if (now.isAfter(startDate.subtract(const Duration(days: 1))) &&
                now.isBefore(endDate.add(const Duration(days: 1)))) {
              if (tournament.containsKey('ScheduleUrl')) {
                todayTournaments.add(tournament);
              }
            }
          }
        }
      }

      // 3. 如果没有找到当日比赛，返回空结果
      if (todayTournaments.isEmpty) {
        return matchesByDate;
      }

      // 4. 获取每个巡回赛的比赛数据
      for (var tournament in todayTournaments) {
        // if (tournament['Type'] == 'GS') {
        //   continue;
        // }
        final String scheduleUrl = tournament['ScheduleUrl'];

        // 使用HeadlessInAppWebView获取HTML内容
        final htmlContent = await _getScheduleHtmlWithWebView(scheduleUrl);
        if (htmlContent.isNotEmpty) {
          final document = parse(htmlContent);

          // 5. 解析比赛日期
          final tournamentDays =
              document.getElementsByClassName('tournament-day');
          final dateHeader = tournamentDays[0].getElementsByTagName('h4');
          String dateStr = '';

          // 直接获取h4的文本内容，但排除其中的span标签内容
          for (var node in dateHeader.first.nodes) {
            if (node is dom.Text) {
              dateStr += node.text.trim();
            }
          }
          // 清理日期字符串，移除多余空格
          dateStr = dateStr.trim();
          if (!matchesByDate.containsKey(dateStr)) {
            matchesByDate[dateStr] = [];
          }
          final schedules = document.getElementsByClassName('schedule');
          debugPrint('解析schedules: ${schedules.length}, 解析日期: $dateStr');
          for (var scheduleItem in schedules) {
            // 为该日期创建一个空列表
            if (!matchesByDate.containsKey(dateStr)) {
              matchesByDate[dateStr] = [];
            }
            final String dateTime =
                scheduleItem.attributes['data-datetime'] ?? '';
            final String displayTime =
                scheduleItem.attributes['data-displaytime'] ?? '';

            String adjustedDisplayTime = displayTime;

            if (dateTime.isNotEmpty) {
              try {
                // 判断是"Starts At"还是"Not Before"
                String timePrefix = '';
                if (displayTime.contains('Starts At')) {
                  timePrefix = 'Starts At ';
                } else if (displayTime.contains('Not Before')) {
                  timePrefix = 'Not Before ';
                }

                // 直接解析dateTime（ISO格式）
                final DateTime originalDateTime = DateTime.parse(dateTime);
                final localDateTime = TimezoneMapping.convertToLocalTime(
                    originalDateTime, tournament['Location'] ?? '');
                debugPrint('当地时间: $originalDateTime');
                debugPrint('本地时间: $localDateTime');

                debugPrint('时间转换后: $localDateTime $originalDateTime');
                // 格式化为新的时间字符串
                final String formattedTime =
                    '${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}';

                // 检查日期是否变化
                bool dateChanged = localDateTime.day != originalDateTime.day ||
                    localDateTime.month != originalDateTime.month ||
                    localDateTime.year != originalDateTime.year;

                // 重新构建显示时间，保留原始前缀
                adjustedDisplayTime = '$timePrefix$formattedTime';

                // 如果日期变化，添加提示
                if (dateChanged) {
                  if (localDateTime.isAfter(originalDateTime)) {
                    adjustedDisplayTime = '$adjustedDisplayTime (Next Day)';
                  } else {
                    adjustedDisplayTime = '$adjustedDisplayTime (Before Day)';
                  }
                }
              } catch (e) {
                debugPrint('时间转换错误: $e');
                // 出错时使用原始时间
              }
            }

            final String matchDate =
                scheduleItem.attributes['data-matchdate'] ?? '';
            final String suffix = scheduleItem.attributes['data-suffix'] ?? '';
            debugPrint(
                '解析比赛时间: $dateTime, 解析显示时间: $displayTime, 解析比赛日期: $matchDate, 解析后缀: $suffix');
            final matchType = scheduleItem.getElementsByClassName('match-type');
            final score =
                scheduleItem.getElementsByClassName('schedule-cta-score');
            if (matchType.isNotEmpty) {
              continue;
            }
            if (score.isNotEmpty && score.first.text.trim() != '–––') {
              continue;
            }

            // 获取比赛时间
            final locationTimestamp = scheduleItem
                .getElementsByClassName('schedule-location-timestamp');
            String matchTime = '';
            String courtInfo = '';
            if (locationTimestamp.isNotEmpty) {
              final spans =
                  locationTimestamp.first.getElementsByTagName('span');
              // 第一个span是球场信息
              if (spans.isNotEmpty) {
                courtInfo = spans[0].text.trim();
              }
              final timestamp =
                  locationTimestamp.first.getElementsByClassName('timestamp');
              if (timestamp.isNotEmpty) {
                matchTime = timestamp.first.text.trim();
              }
            }

            // 获取比赛轮次
            final scheduleContent =
                scheduleItem.getElementsByClassName('schedule-content');
            String round = '';
            if (scheduleContent.isNotEmpty) {
              final scheduleType =
                  scheduleContent.first.getElementsByClassName('schedule-type');
              if (scheduleType.isNotEmpty) {
                round = scheduleType.first.text.trim();
              }
            }

            // 获取球员信息
            final schedulePlayers =
                scheduleItem.getElementsByClassName('schedule-players');
            if (schedulePlayers.isEmpty) continue;

            final players =
                schedulePlayers.first.getElementsByClassName('player');
            final opponents =
                schedulePlayers.first.getElementsByClassName('opponent');

            if (players.isEmpty || opponents.isEmpty) continue;
            final isDouble = players.first
                .getElementsByClassName('names'); // 检查是否是双打比赛shuang'g
            if (isDouble.isNotEmpty) {
              continue;
            }
            // 获取球员1信息
            final player1Element = players.first;
            String player1Name = '';
            String player1Rank = '';
            String player1Id = '';
            // 获取名字 (a标签内容)
            final player1NameLinks = player1Element.getElementsByTagName('a');
            if (player1NameLinks.isNotEmpty) {
              player1Name = player1NameLinks.first.text
                  .trim()
                  .replaceAll(RegExp(r'[\r\n]+'), '');
              final href = player1NameLinks.first.attributes['href'];
              if (href != null && href.isNotEmpty) {
                final parts = href.split('/');
                if (parts.length >= 4) {
                  // 获取倒数第二个部分作为球员ID
                  player1Id = parts[parts.length - 2];
                }
              }
            }
            // 获取排名 (rank class内容)
            final player1RankElements = player1Element
                .getElementsByClassName('rank')
                .first
                .getElementsByTagName('span');

            if (player1RankElements.isNotEmpty) {
              player1Rank = player1RankElements.first.text
                  .trim()
                  .replaceAll(RegExp(r'[\r\n]+'), '');
            }
            final player1Country =
                player1Element.getElementsByClassName('atp-flag').isNotEmpty
                    ? player1Element
                        .getElementsByClassName('atp-flag')
                        .first
                        .text
                        .trim()
                        .replaceAll(RegExp(r'[\r\n]+'), '')
                    : '';
            String player1FlagUrl = '';
            if (player1Element.getElementsByClassName('atp-flag').isNotEmpty) {
              final flagElement =
                  player1Element.getElementsByClassName('atp-flag').first;
              if (flagElement.getElementsByTagName('use').isNotEmpty) {
                final useElement =
                    flagElement.getElementsByTagName('use').first;
                String flagHref = useElement.attributes['href'] ?? '';
                if (flagHref.isNotEmpty) {
                  // 按照-分割，获取最后一个元素作为国家代码
                  List<String> parts = flagHref.split('-');
                  if (parts.isNotEmpty) {
                    String countryCode = parts.last;
                    // 构建完整的国旗URL
                    player1FlagUrl =
                        'https://www.atptour.com/-/media/images/flags/$countryCode.svg';
                  } else {
                    // 如果分割后为空，使用原始URL
                    player1FlagUrl = 'https://www.atptour.com$flagHref';
                  }
                }
              }
            }
            String player1ImageUrl = '';
            final player1ImageElements =
                player1Element.getElementsByClassName('player-image');
            if (player1ImageElements.isNotEmpty) {
              final srcAttr = player1ImageElements.first.attributes['src'];
              if (srcAttr != null && srcAttr.isNotEmpty) {
                // 如果src是相对路径，添加基础URL
                if (srcAttr.startsWith('/')) {
                  player1ImageUrl = 'https://www.atptour.com$srcAttr';
                } else {
                  player1ImageUrl = srcAttr;
                }
              }
            }

            // 获取球员2信息
            final player2Element = opponents.first;
            String player2Name = '';
            String player2Rank = '';
            String player2Id = '';
            // 获取名字 (a标签内容)
            final player2NameLinks = player2Element.getElementsByTagName('a');
            if (player2NameLinks.isNotEmpty) {
              player2Name = player2NameLinks.first.text
                  .trim()
                  .replaceAll(RegExp(r'[\r\n]+'), '');
              final href = player2NameLinks.first.attributes['href'];

              if (href != null && href.isNotEmpty) {
                final parts = href.split('/');
                if (parts.length >= 4) {
                  // 获取倒数第二个部分作为球员ID
                  player2Id = parts[parts.length - 2];
                }
              }
            }

            // 获取排名 (rank class内容)
            final player2RankElements =
                player2Element.getElementsByClassName('rank');
            if (player2RankElements.isNotEmpty) {
              player2Rank = player2RankElements.first.text
                  .trim()
                  .replaceAll(RegExp(r'[\r\n]+'), '');
            }
            final player2Country =
                player2Element.getElementsByClassName('atp-flag').isNotEmpty
                    ? player2Element
                        .getElementsByClassName('atp-flag')
                        .first
                        .text
                        .trim()
                    : '';
            String player2FlagUrl = '';
            if (player2Element.getElementsByClassName('atp-flag').isNotEmpty) {
              final flagElement =
                  player2Element.getElementsByClassName('atp-flag').first;
              if (flagElement.getElementsByTagName('use').isNotEmpty) {
                final useElement =
                    flagElement.getElementsByTagName('use').first;
                String flagHref = useElement.attributes['href'] ?? '';
                if (flagHref.isNotEmpty) {
                  // 按照-分割，获取最后一个元素作为国家代码
                  List<String> parts = flagHref.split('-');
                  if (parts.isNotEmpty) {
                    String countryCode = parts.last;
                    // 构建完整的国旗URL
                    player2FlagUrl =
                        'https://www.atptour.com/-/media/images/flags/$countryCode.svg';
                  } else {
                    // 如果分割后为空，使用原始URL
                    player2FlagUrl = 'https://www.atptour.com$flagHref';
                  }
                }
              }
            }
            String player2ImageUrl = '';
            final player2ImageElements =
                player2Element.getElementsByClassName('player-image');
            if (player2ImageElements.isNotEmpty) {
              final srcAttr = player2ImageElements.first.attributes['src'];
              if (srcAttr != null && srcAttr.isNotEmpty) {
                // 如果src是相对路径，添加基础URL
                if (srcAttr.startsWith('/')) {
                  player2ImageUrl = 'https://www.atptour.com$srcAttr';
                } else {
                  player2ImageUrl = srcAttr;
                }
              }
            }
            // 7. 构建比赛数据，与现有格式保持一致
            final matchData = {
              'roundInfo': round,
              'matchTime': adjustedDisplayTime,
              'player1': player1Name,
              'player2': player2Name,
              'player1Rank': player1Rank,
              'player2Rank': player2Rank,
              'player1Country': player1Country,
              'player2Country': player2Country,
              'player1FlagUrl': player1FlagUrl,
              'player2FlagUrl': player2FlagUrl,
              'player1ImageUrl': player1ImageUrl,
              'player2ImageUrl': player2ImageUrl,
              // 使用新的存储格式，对于未开始的比赛，设置默认值
              'player1SetScores': [0, 0, 0],
              'player2SetScores': [0, 0, 0],
              'player1TiebreakScores': [0, 0, 0],
              'player2TiebreakScores': [0, 0, 0],
              'isCompleted': false, // 标记为未完成的
              'matchDuration': matchTime,
              'isPlayer1Winner': false, // 添加获胜者标识
              'isPlayer2Winner': false,
              'courtInfo': courtInfo, // 添加获胜者标识
              'matchType': 'unmatch',
              'tournamentName': tournament['Name'],
              'player1Id': player1Id, // 添加球员1 ID
              'player2Id': player2Id, // 添加球员2 ID
            };
            // 添加到对应日期的比赛列表
            matchesByDate[dateStr]!.add(matchData);
          }
        } else {
          debugPrint('获取比赛数据失败: HTML内容为空');
        }
      }

      return matchesByDate;
    } catch (e) {
      debugPrint('解析比赛数据异常: $e');
      return matchesByDate;
    }
  }

  // 获取特定比赛的实时数据 - 使用HeadlessInAppWebView
  static Future<Map<String, dynamic>> getLiveTournamentData(
      String tournamentId) async {
    debugPrint('使用HeadlessInAppWebView获取实时比赛数据: $tournamentId');

    try {
      final data = await _getLiveTournamentDataWithWebView(tournamentId);
      if (data.isNotEmpty) {
        debugPrint('WebView成功获取实时比赛数据');
        return data;
      } else {
        debugPrint('WebView未获取到实时比赛数据，尝试备用方案');
        return await _fallbackGetLiveTournamentData(tournamentId);
      }
    } catch (e) {
      debugPrint('WebView获取实时比赛数据失败: $e，尝试备用方案');
      return await _fallbackGetLiveTournamentData(tournamentId);
    }
  }

  // 使用HeadlessInAppWebView获取实时比赛数据
  static Future<Map<String, dynamic>> _getLiveTournamentDataWithWebView(
      String tournamentId) async {
    final completer = Completer<Map<String, dynamic>>();
    HeadlessInAppWebView? headlessWebView;

    try {
      final String apiUrl =
          'https://www.atptour.com/en/-/www/LiveMatches/2025/$tournamentId';

      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(apiUrl)),
        initialSettings: InAppWebViewSettings(
          userAgent:
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          javaScriptEnabled: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          clearCache: false,
        ),
        onWebViewCreated: (controller) {
          debugPrint('实时比赛数据 HeadlessInAppWebView创建成功');
        },
        onLoadStart: (controller, url) {
          debugPrint('开始加载实时比赛页面: $url');
        },
        onLoadStop: (controller, url) async {
          debugPrint('实时比赛页面加载完成: $url');

          try {
            // 等待页面完全渲染
            await Future.delayed(const Duration(seconds: 2));

            // 直接解析页面内容获取实时比赛数据
            final jsCode = '''
              (function() {
                try {
                  console.log('开始解析实时比赛数据...');
                  
                  // 检查页面是否已经包含JSON数据
                  const bodyText = document.body.textContent || document.body.innerText;
                  console.log('实时比赛页面内容长度:', bodyText.length);
                  
                  // 尝试解析JSON数据
                  try {
                    const data = JSON.parse(bodyText);
                    if (data && typeof data === 'object') {
                      console.log('成功解析实时比赛JSON数据');
                      return data;
                    }
                  } catch (e) {
                    console.log('实时比赛页面内容不是JSON格式');
                  }
                  
                  console.log('无法解析实时比赛数据');
                  return null;
                } catch (e) {
                  console.error('实时比赛JavaScript解析错误:', e);
                  return null;
                }
              })()
            ''';

            final result = await controller.evaluateJavascript(source: jsCode);
            debugPrint('实时比赛JavaScript执行结果: $result');
            debugPrint('实时比赛JavaScript执行结果类型: ${result.runtimeType}');

            if (result != null) {
              try {
                Map<String, dynamic> liveData;
                if (result is Map) {
                  liveData = Map<String, dynamic>.from(result);
                } else if (result is String && result.isNotEmpty) {
                  try {
                    liveData = json.decode(result);
                  } catch (e) {
                    debugPrint('实时比赛JSON解析失败: $e, 原始数据: $result');
                    completer.complete({});
                    return;
                  }
                } else {
                  debugPrint('实时比赛未知的结果格式: $result (${result.runtimeType})');
                  completer.complete({});
                  return;
                }

                if (liveData.isNotEmpty) {
                  debugPrint('成功解析实时比赛数据');
                  completer.complete(liveData);
                } else {
                  debugPrint('实时比赛数据为空');
                  completer.complete({});
                }
              } catch (e) {
                debugPrint('解析实时比赛数据失败: $e');
                completer.complete({});
              }
            } else {
              debugPrint('实时比赛JavaScript返回null，尝试重新获取');
              // 等待更长时间后重试
              await Future.delayed(const Duration(seconds: 3));
              try {
                final retryResult =
                    await controller.evaluateJavascript(source: jsCode);
                debugPrint('实时比赛重试结果: $retryResult');
                if (retryResult != null && retryResult is Map) {
                  completer.complete(Map<String, dynamic>.from(retryResult));
                } else {
                  completer.complete({});
                }
              } catch (e) {
                debugPrint('实时比赛重试失败: $e');
                completer.complete({});
              }
            }
          } catch (e) {
            debugPrint('执行实时比赛JavaScript时出错: $e');
            completer.complete({});
          }
        },
        onReceivedError: (controller, request, error) {
          debugPrint('实时比赛WebView加载错误: ${error.description}');
          if (!completer.isCompleted) {
            completer.complete({});
          }
        },
        onReceivedHttpError: (controller, request, errorResponse) {
          debugPrint('实时比赛HTTP错误: ${errorResponse.statusCode}');
          if (!completer.isCompleted) {
            completer.complete({});
          }
        },
      );

      await headlessWebView.run();

      // 设置超时
      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('实时比赛WebView请求超时');
          return <String, dynamic>{};
        },
      );

      return result;
    } catch (e) {
      debugPrint('实时比赛HeadlessInAppWebView异常: $e');
      return {};
    } finally {
      try {
        await headlessWebView?.dispose();
        debugPrint('实时比赛HeadlessInAppWebView已释放');
      } catch (e) {
        debugPrint('释放实时比赛WebView时出错: $e');
      }
    }
  }

  // 实时比赛备用方案：原有的HTTP请求方法
  static Future<Map<String, dynamic>> _fallbackGetLiveTournamentData(
      String tournamentId) async {
    debugPrint('实时比赛备用方案获取数据: $tournamentId');

    try {
      final String endpoint = '/en/-/www/LiveMatches/2025/$tournamentId';
      final Uri uri = _buildUri(endpoint, '');

      final response = await _makeHttpRequest(
        uri,
        {
          'Accept': 'application/json',
          'Referer': 'https://www.atptour.com/en',
          'X-Requested-With': 'XMLHttpRequest',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
        timeout: const Duration(seconds: 10),
      );
      debugPrint('实时比赛备用方案状态码: ${response.statusCode}');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('实时比赛备用方案获取数据失败，状态码: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      debugPrint('实时比赛备用方案请求失败: $e');
      return {};
    }
  }

  // 解析比赛数据为应用内部格式
  static List<Map<String, dynamic>> parseMatchesData(
      Map<String, dynamic> apiData, String tId) {
    List<Map<String, dynamic>> matches = [];
    // debugPrint('parseMatchesData!!!!!!!!!!!$apiData');
    try {
      if (apiData.containsKey('LiveMatches') &&
          apiData['LiveMatches'] is List) {
        final liveMatches = apiData['LiveMatches'];
        final tournamentName = apiData['EventTitle'] ?? '';
        final tournamentId = tId;
        final location =
            '${apiData['EventCity'] ?? ''}, ${apiData['EventCountry'] ?? ''}';
        for (var match in liveMatches) {
          if (!match['IsDoubles']) {
            // 只处理单打比赛
            final playerTeam = match['PlayerTeam'] ?? {};
            final opponentTeam = match['OpponentTeam'] ?? {};

            // 获取球员信息
            final player1 = playerTeam['Player'] ?? {};
            final player2 = opponentTeam['Player'] ?? {};

            // 构建球员头像URL
            String player1ImageUrl = '';
            String player2ImageUrl = '';

            if (playerTeam.containsKey('PlayerHeadshotUrl')) {
              player1ImageUrl =
                  'https://www.atptour.com${playerTeam['PlayerHeadshotUrl'].toString().toLowerCase()}';
            }

            if (opponentTeam.containsKey('PlayerHeadshotUrl')) {
              player2ImageUrl =
                  'https://www.atptour.com${opponentTeam['PlayerHeadshotUrl'].toString().toLowerCase()}';
            }

            // 构建国旗URL
            String player1FlagUrl = '';
            String player2FlagUrl = '';

            if (player1.containsKey('PlayerCountry')) {
              final countryCode = player1['PlayerCountry'] ?? '';
              if (countryCode.isNotEmpty) {
                player1FlagUrl =
                    'https://www.atptour.com/-/media/images/flags/${countryCode.toLowerCase()}.svg';
              }
            }

            if (player2.containsKey('PlayerCountry')) {
              final countryCode = player2['PlayerCountry'] ?? '';
              if (countryCode.isNotEmpty) {
                player2FlagUrl =
                    'https://www.atptour.com/-/media/images/flags/${countryCode.toLowerCase()}.svg';
              }
            }
            String lastUpdated = '';
            if (match['LastUpdated'] != null) {
              try {
                DateTime dateTime =
                    DateTime.parse(match['LastUpdated'].toString());
                lastUpdated = DateFormat('yyyy-MM-dd').format(dateTime);
              } catch (e) {
                print('日期格式解析错误: $e');
                lastUpdated = '';
              }
            }
            // 构建比赛数据
            Map<String, dynamic> matchData = {
              'player1':
                  '${player1['PlayerFirstName'] ?? ''} ${player1['PlayerLastName'] ?? ''}',
              'player2':
                  '${player2['PlayerFirstName'] ?? ''} ${player2['PlayerLastName'] ?? ''}',
              'player1Rank':
                  playerTeam['Seed'] != null && playerTeam['Seed'] != 0
                      ? '(${playerTeam['Seed'].toInt()})'
                      : '',
              'player2Rank':
                  opponentTeam['Seed'] != null && opponentTeam['Seed'] != 0
                      ? '(${opponentTeam['Seed'].toInt()})'
                      : '',
              'player1Country': player1['PlayerCountry'] ?? '',
              'player2Country': player2['PlayerCountry'] ?? '',
              'player1Id': player1['PlayerId'] ?? '',
              'player2Id': player2['PlayerId'] ?? '',
              'player1FlagUrl': player1FlagUrl,
              'player2FlagUrl': player2FlagUrl,
              'player1ImageUrl': player1ImageUrl,
              'player2ImageUrl': player2ImageUrl,
              'serving1': match['ServerTeam'] == 0,
              'serving2': match['ServerTeam'] == 1,
              'roundInfo': match['RoundName'] ?? '',
              'stadium': match['CourtName'] ?? '',
              'matchTime': match['MatchTimeTotal'] ?? '',
              'tournamentName': tournamentName,
              'location': location,
              'matchStatus': match['MatchStatus'] ?? '',
              'player1SetScores': _extractSetScores(playerTeam['SetScores']),
              'player2SetScores': _extractSetScores(opponentTeam['SetScores']),
              'currentGameScore1':
                  _getCurrentGameScore(playerTeam['GameScore']),
              'currentGameScore2':
                  _getCurrentGameScore(opponentTeam['GameScore']),
              'player1TiebreakScores':
                  _extractTiebreakScores(playerTeam['SetScores']),
              'player2TiebreakScores':
                  _extractTiebreakScores(opponentTeam['SetScores']),
              'isPlayer1Winner': match['MatchStatus'] == 'F' &&
                  _isWinner(playerTeam['SetScores']),
              'isPlayer2Winner': match['MatchStatus'] == 'F' &&
                  _isWinner(opponentTeam['SetScores']),
              'matchType': 'live',
              'isLive': true,
              'matchId': match['MatchId'] ?? '',
              'tournamentId': tournamentId,
              'LastUpdated': lastUpdated,
              'year': '2025',
            };
            debugPrint('api获取直播比赛数据 $matchData $tournamentId');
            matches.add(matchData);
          }
        }
      }
      debugPrint('liveMatchs====================: $matches');
    } catch (e) {
      print('Failed to parse match data: $e');
    }

    return matches;
  }

  // 判断是否为获胜者
  static bool _isWinner(List<dynamic>? setScores) {
    if (setScores == null || setScores.isEmpty) return false;

    int setsWon = 0;
    for (var set in setScores) {
      if (set['IsWinner'] == true) {
        setsWon++;
      }
    }

    return setsWon >= 2; // 网球比赛通常是三盘两胜制
  }

  // 提取局分
  static List<int> _extractSetScores(List<dynamic>? setScores) {
    List<int> scores = [];
    if (setScores != null) {
      for (var set in setScores) {
        if (set['SetScore'] != null) {
          // 安全地转换为int，处理double类型
          final score = set['SetScore'];
          if (score is int) {
            scores.add(score);
          } else if (score is double) {
            scores.add(score.toInt());
          } else if (score is String) {
            scores.add(int.tryParse(score) ?? 0);
          }
        }
      }
    }
    // 确保至少有3个元素
    while (scores.length < 3) {
      scores.add(0);
    }
    return scores;
  }

  // 提取抢七分数
  static List<int> _extractTiebreakScores(List<dynamic>? setScores) {
    List<int> tiebreakScores = [];
    if (setScores != null) {
      for (var set in setScores) {
        if (set['TieBreakScore'] != null) {
          // 安全地转换为int，处理double类型
          final score = set['TieBreakScore'];
          if (score is int) {
            tiebreakScores.add(score);
          } else if (score is double) {
            tiebreakScores.add(score.toInt());
          } else if (score is String) {
            tiebreakScores.add(int.tryParse(score) ?? 0);
          }
        }
      }
    }
    // 确保至少有3个元素
    while (tiebreakScores.length < 3) {
      tiebreakScores.add(0);
    }
    return tiebreakScores;
  }

  // 获取当前局比分
  static String _getCurrentGameScore(dynamic gameScore) {
    return gameScore.toString();
    // if (gameScore == null) return '0';

    // switch (gameScore.toString()) {
    //   case '0':
    //     return '0';
    //   case '1':
    //     return '15';
    //   case '2':
    //     return '30';
    //   case '3':
    //     return '40';
    //   case '4':
    //     return 'A';
    //   default:
    //     return '0';
    // }
  }

  // 使用代理轮换机制的HTTP请求
  Future<String?> _makeRequestWithProxyRotation(
      String originalUrl, Map<String, String> headers) async {
    for (int i = 0; i < _proxyUrls.length; i++) {
      try {
        final proxyUrl = _proxyUrls[_currentProxyIndex];
        final proxiedUrl = proxyUrl + Uri.encodeComponent(originalUrl);
        debugPrint(
            '尝试代理 ${_currentProxyIndex + 1}/${_proxyUrls.length}: $proxyUrl');

        final response = await http
            .get(
              Uri.parse(proxiedUrl),
              headers: headers,
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          debugPrint('代理请求成功: ${response.statusCode}');
          return response.body;
        } else {
          debugPrint('代理返回错误状态码: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('代理 ${_currentProxyIndex + 1} 失败: $e');
      }

      // 轮换到下一个代理
      _rotateProxy();
    }

    return null;
  }

  // 获取ATP球员排名 - 使用HeadlessInAppWebView
  Future<List<dynamic>> getPlayerRankings() async {
    debugPrint('使用HeadlessInAppWebView获取ATP球员排名数据...');

    try {
      final data = await _getPlayerRankingsWithWebView();
      if (data.isNotEmpty) {
        debugPrint('WebView成功获取ATP排名数据，数量: ${data.length}');
        return data;
      } else {
        debugPrint('WebView未获取到数据，尝试备用方案');
        return await _fallbackGetPlayerRankings();
      }
    } catch (e) {
      debugPrint('WebView获取ATP排名数据失败: $e，尝试备用方案');
      return await _fallbackGetPlayerRankings();
    }
  }

  // 使用HeadlessInAppWebView获取排名数据
  Future<List<dynamic>> _getPlayerRankingsWithWebView() async {
    final completer = Completer<List<dynamic>>();
    HeadlessInAppWebView? headlessWebView;

    try {
      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(
            url: WebUri(
                'https://www.atptour.com/en/-/www/rank/sglroll/250?v=1')),
        initialSettings: InAppWebViewSettings(
          userAgent:
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          javaScriptEnabled: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          clearCache: false,
        ),
        onWebViewCreated: (controller) {
          debugPrint('HeadlessInAppWebView创建成功');
        },
        onLoadStart: (controller, url) {
          debugPrint('开始加载页面: $url');
        },
        onLoadStop: (controller, url) async {
          debugPrint('页面加载完成: $url');

          try {
            // 等待页面完全渲染
            await Future.delayed(const Duration(seconds: 2));

            // 直接解析页面内容获取排名数据
            final jsCode = '''
              (function() {
                try {
                  console.log('开始解析页面排名数据...');
                  
                  // 检查页面是否已经包含JSON数据
                  const bodyText = document.body.textContent || document.body.innerText;
                  console.log('页面内容长度:', bodyText.length);
                  
                  // 尝试解析JSON数据
                  try {
                    const data = JSON.parse(bodyText);
                    if (Array.isArray(data) && data.length > 0) {
                      console.log('成功解析JSON数据，数量:', data.length);
                      return data;
                    }
                  } catch (e) {
                    console.log('页面内容不是JSON格式，尝试从DOM解析');
                  }
                  
                  // 如果不是JSON，尝试从表格中提取数据
                  const rankings = [];
                  const rows = document.querySelectorAll('table tbody tr, .ranking-row, .player-row');
                  console.log('找到行数:', rows.length);
                  
                  rows.forEach((row, index) => {
                    try {
                      const rankElement = row.querySelector('.rank, .ranking, [data-rank]');
                      const nameElement = row.querySelector('.player-name, .name, a[href*="/players/"]');
                      const pointsElement = row.querySelector('.points, .ranking-points, [data-points]');
                      
                      if (rankElement && nameElement) {
                        const rank = rankElement.textContent.trim();
                        const name = nameElement.textContent.trim();
                        const points = pointsElement ? pointsElement.textContent.trim() : '0';
                        
                        rankings.push({
                          Rank: parseInt(rank) || index + 1,
                          PlayerFirstName: name.split(' ')[0] || '',
                          PlayerLastName: name.split(' ').slice(1).join(' ') || '',
                          Points: parseInt(points.replace(/[^0-9]/g, '')) || 0
                        });
                      }
                    } catch (e) {
                      console.error('解析行数据失败:', e);
                    }
                  });
                  
                  console.log('从DOM解析到数据数量:', rankings.length);
                  return rankings.length > 0 ? rankings : null;
                } catch (e) {
                  console.error('JavaScript解析错误:', e);
                  return null;
                }
              })()
            ''';

            final result = await controller.evaluateJavascript(source: jsCode);
            debugPrint('JavaScript执行结果: $result');
            debugPrint('JavaScript执行结果类型: ${result.runtimeType}');

            if (result != null) {
              try {
                List<dynamic> rankingData;
                if (result is List) {
                  rankingData = result.cast<dynamic>();
                } else if (result is String && result.isNotEmpty) {
                  try {
                    rankingData = json.decode(result);
                  } catch (e) {
                    debugPrint('JSON解析失败: $e, 原始数据: $result');
                    completer.complete([]);
                    return;
                  }
                } else {
                  debugPrint('未知的结果格式: $result (${result.runtimeType})');
                  completer.complete([]);
                  return;
                }

                if (rankingData.isNotEmpty) {
                  debugPrint('成功解析排名数据，数量: ${rankingData.length}');
                  completer.complete(rankingData);
                } else {
                  debugPrint('排名数据为空');
                  completer.complete([]);
                }
              } catch (e) {
                debugPrint('解析排名数据失败: $e');
                completer.complete([]);
              }
            } else {
              debugPrint('JavaScript返回null，尝试重新获取');
              // 等待更长时间后重试
              await Future.delayed(const Duration(seconds: 3));
              try {
                final retryResult =
                    await controller.evaluateJavascript(source: jsCode);
                debugPrint('重试结果: $retryResult');
                if (retryResult != null &&
                    retryResult is List &&
                    retryResult.isNotEmpty) {
                  completer.complete(retryResult.cast<dynamic>());
                } else {
                  completer.complete([]);
                }
              } catch (e) {
                debugPrint('重试失败: $e');
                completer.complete([]);
              }
            }
          } catch (e) {
            debugPrint('执行JavaScript时出错: $e');
            completer.complete([]);
          }
        },
        onReceivedError: (controller, request, error) {
          debugPrint('WebView加载错误: ${error.description}');
          if (!completer.isCompleted) {
            completer.complete([]);
          }
        },
        onReceivedHttpError: (controller, request, errorResponse) {
          debugPrint('HTTP错误: ${errorResponse.statusCode}');
          if (!completer.isCompleted) {
            completer.complete([]);
          }
        },
      );

      await headlessWebView.run();

      // 设置超时
      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('WebView请求超时');
          return <dynamic>[];
        },
      );

      return result;
    } catch (e) {
      debugPrint('HeadlessInAppWebView异常: $e');
      return [];
    } finally {
      try {
        await headlessWebView?.dispose();
        debugPrint('HeadlessInAppWebView已释放');
      } catch (e) {
        debugPrint('释放WebView时出错: $e');
      }
    }
  }

  // 备用方案：原有的HTTP请求方法
  Future<List<dynamic>> _fallbackGetPlayerRankings() async {
    const String url = 'https://www.atptour.com/en/-/www/rank/sglroll/250?v=1';
    debugPrint('备用方案获取ATP球员排名数据: $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Referer': 'https://www.atptour.com/en/rankings/singles',
          'X-Requested-With': 'XMLHttpRequest',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Cookie':
              '_ga=GA1.1.760912777.1744781494; OptanonAlertBoxClosed=2025-04-16T05:31:41.327Z; _fbp=fb.1.1744781503790.957500700664593250; _tt_enable_cookie=1; _ttp=01JRYH9VSHZ7D93CVMEZ3V9WE5_.tt.1; atp_visitor-id=9ed9e1bf-8859-45a2-84e4-edee66ea25d0; _ce.s=v~8517b6f07d5e4eb92cec618d1ff66e0fbf707134~lcw~1748423316300~vir~returning~lva~1748423316300~vpv~5~v11.fhb~1747033157293~v11.lhb~1747637435354~v11.cs~356004~v11.s~6d114a00-394d-11f0-80dd-bba7b4cf98d6~v11.vs~8517b6f07d5e4eb92cec618d1ff66e0fbf707134~v11.ss~1748166515371~v11ls~6d114a00-394d-11f0-80dd-bba7b4cf98d6~lcw~1748508474391; ttcsid_CES2GFBC77UAS1JKFA70=1750038866429::vNAP1-ThO2i35HPPVAUf.65.1750038866429; ttcsid=1750038866430::QN3w5N045j5fzSoWtzvp.66.1750038866430; __gads=ID=b5a2dbe17f4f559f:T=1731463440:RT=1750155161:S=ALNI_MYH3y_uCZ5V1n4b9cCFOjtEp9eRqQ; __gpi=UID=00000f941a166c11:T=1731463440:RT=1750155161:S=ALNI_MaK4RTdlhRWZneZHXLFn5QUUBX1Hw; __eoi=ID=72b707958af4af57:T=1747033156:RT=1750155161:S=AA-Afjak3KbXyZ9-0fFm8eD6KQq-; OptanonConsent=isGpcEnabled=0&datestamp=Tue+Jun+17+2025+18%3A15%3A51+GMT%2B0800+(%E4%B8%AD%E5%9B%BD%E6%A0%87%E5%87%86%E6%97%B6%E9%97%B4)&version=202502.1.0&browserGpcFlag=0&isIABGlobal=false&hosts=&consentId=94e9c412-8984-4e16-9b8e-5455fb388799&interactionCount=1&isAnonUser=1&landingPath=NotLandingPage&groups=C0001%3A1%2CC0002%3A1%2CC0004%3A1%2CC0003%3A1&intType=1&geolocation=TR%3B34&AwaitingReconsent=false; cf_clearance=5uXuquHZM5UwUVtlsvMvpWCPeIzfL8iC2OvOMxWUeLk-1750155351-1.2.1.1-_t1PkFbQ7NrZTd_2BFrCRGia9WpewXsaNS.OdjpUAmhdffcdGb4Q0dW_tEx0tgriUGQm_076aDrszNPr8qJnHpzByn0mjVn6fgVkWnlaK4dRjLUPPrHbzo9DfKcjJX1f2pR1vRd6P_FQg0w5rKiaLlqkGx2CntkiKXiB8AoiXpcIUfmCDHq4ixI6cvFWQpdFw4XwM6tq6VxWCztt4iIg0TZp24YpfqzKaQO.mOiA7uvsqbuBMTbr5I6l412Ev7CdE8j9MINB_txGo9NZi0iay.Hl.4pnpxS.JfnUDOKKGNtX_Sj.dVtcyCLv5UyuUtpEJOijmIYl8YOuM3zbZ5ei7BhpQYwMfZoBdAPxIpJkrMQ; _ga_D7VPPXYD0V=GS2.1.s1750155164\$o73\$g1\$t1750155405\$j60\$l0\$h0; __cf_bm=Z83rc.SGEbouFi3bo_Nw3sKs_qN3La_WR_.o2_mSTw8-1755765248-1.0.1.1-A_XNiMcot_P5Dp5oE8MHaXS3JD4CpYUoiDjcr6hE76KFiTJZfuqT_1LU2xNI0Hq7DB7FzGsV0HJ.FZOHQQTr6tCVDlnIeJdnza7.X3mgLAQ',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('备用方案ATP排名数据解析成功，数量: ${data.length}');
        return data;
      } else {
        debugPrint('备用方案获取ATP排名数据失败，状态码: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('备用方案ATP排名数据请求失败: $e');
      return [];
    }
  }

  // 根据关键词搜索球员
  Future<List<dynamic>> searchPlayers(String keyword) async {
    try {
      // 实际项目中，可能会有专门的搜索API
      // 这里我们简化处理，获取所有排名然后在客户端过滤
      final allPlayers = await getPlayerRankings();

      if (keyword.isEmpty) {
        return allPlayers;
      }

      // 过滤包含关键词的球员
      return allPlayers.where((player) {
        final String fullName =
            '${player['PlayerFirstName']} ${player['PlayerLastName']}'
                .toLowerCase();
        return fullName.contains(keyword.toLowerCase());
      }).toList();
    } catch (e) {
      print('搜索球员异常: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getWTAMatcheScore(
      String tournamentId, String matchId) async {
    Map<String, dynamic> score = {};
    final currentYear = DateTime.now().year.toString();
    try {
      String endpoint =
          '/tennis/tournaments/$tournamentId/$currentYear/matches/$matchId/score';
      debugPrint(
          'getWTAMatcheScore!!!!!!!!!!!$tournamentId,$matchId,$endpoint');
      final Uri uri = _buildUri(endpoint, 'wta');
      final response = await HttpService.get(uri);
      debugPrint(
          'getWTAMatcheScore!!!!!!!!!!!$tournamentId,$matchId,$uri ${response.statusCode}');
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data != null && data is List && data.isNotEmpty) {
            score = data[0];
          }
        } catch (e) {
          debugPrint('WTA比分JSON解析失败: $e');
        }
      }
      return score;
    } catch (e) {
      print('Error fetching WTA scores: $e');
      return {};
    }
  }

  // 获取WTA比赛数据
  static Future<List<Map<String, dynamic>>> getWTAMatches(
      Map<String, dynamic> tournament, DateTime date) async {
    Map<String, List<Map<String, dynamic>>> matchesByDate = {};
    final formatter = DateFormat('yyyy-MM-dd');
    final dateStr = formatter.format(date);
    final formattedDate = DateFormat('E, dd MMMM, yyyy').format(date);
    final currentYear = DateTime.now().year.toString();
    int tournamentId = tournament['tournamentGroup']['id'];
    // try {
    String endpoint =
        '/tennis/tournaments/$tournamentId/$currentYear/matches?from=$dateStr&to=$dateStr';
    final Uri uri = _buildUri(endpoint, 'wta');
    final response = await http.get(uri);
    debugPrint(
        'getWTAMatches!!!!!!!!!!!$tournamentId,$dateStr,$uri ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> matches = data['matches'] ?? [];

      // 过滤只显示单打比赛
      final singleMatches =
          matches.where((match) => match['DrawMatchType'] == 'S').toList();

      List<Map<String, dynamic>> formattedMatches = [];

      for (var match in singleMatches) {
        // 获取比赛状态
        final matchState = match['MatchState'] ?? '';

        // 构建球员1信息
        final player1 = {
          'Name':
              '${match['PlayerNameFirstA'] ?? ''} ${match['PlayerNameLastA'] ?? ''}',
          'Rank': match['SeedA'] ?? '',
          'Country': match['PlayerCountryA'] ?? '',
          'ID': match['PlayerIDA'] ?? '',
        };

        // 构建球员2信息
        final player2 = {
          'Name':
              '${match['PlayerNameFirstB'] ?? ''} ${match['PlayerNameLastB'] ?? ''}',
          'Rank': match['SeedB'] ?? '',
          'Country': match['PlayerCountryB'] ?? '',
          'ID': match['PlayerIDB'] ?? '',
        };

        // 构建比分信息
        List<Map<String, dynamic>> sets = [];

        // 第一盘
        if (match['ScoreSet1A'] != null &&
            match['ScoreSet1A'].isNotEmpty &&
            match['ScoreSet1B'] != null &&
            match['ScoreSet1B'].isNotEmpty) {
          sets.add({
            'Player1Score': int.tryParse(match['ScoreSet1A']) ?? 0,
            'Player2Score': int.tryParse(match['ScoreSet1B']) ?? 0,
            'TiebreakScore': match['ScoreTbSet1'] ?? '',
          });
        }

        // 第二盘
        if (match['ScoreSet2A'] != null &&
            match['ScoreSet2A'].isNotEmpty &&
            match['ScoreSet2B'] != null &&
            match['ScoreSet2B'].isNotEmpty) {
          sets.add({
            'Player1Score': int.tryParse(match['ScoreSet2A']) ?? 0,
            'Player2Score': int.tryParse(match['ScoreSet2B']) ?? 0,
            'TiebreakScore': match['ScoreTbSet2'] ?? '',
          });
        }

        // 第三盘
        if (match['ScoreSet3A'] != null &&
            match['ScoreSet3A'].isNotEmpty &&
            match['ScoreSet3B'] != null &&
            match['ScoreSet3B'].isNotEmpty) {
          sets.add({
            'Player1Score': int.tryParse(match['ScoreSet3A']) ?? 0,
            'Player2Score': int.tryParse(match['ScoreSet3B']) ?? 0,
            'TiebreakScore': match['ScoreTbSet3'] ?? '',
          });
        }

        // 处理比分
        List<int> player1SetScores = [];
        List<int> player2SetScores = [];
        List<int> player1TiebreakScores = [];
        List<int> player2TiebreakScores = [];

        for (var set in sets) {
          player1SetScores.add(set['Player1Score'] ?? 0);
          player2SetScores.add(set['Player2Score'] ?? 0);

          // 处理抢七
          if (set['TiebreakScore'] != null && set['TiebreakScore'].isNotEmpty) {
            final tiebreakParts = set['TiebreakScore'].toString().split('-');
            if (tiebreakParts.length == 2) {
              player1TiebreakScores.add(int.tryParse(tiebreakParts[0]) ?? 0);
              player2TiebreakScores.add(int.tryParse(tiebreakParts[1]) ?? 0);
            } else {
              player1TiebreakScores.add(0);
              player2TiebreakScores.add(0);
            }
          } else {
            player1TiebreakScores.add(0);
            player2TiebreakScores.add(0);
          }
        }

        // 确保至少有3个元素（即使没有比分）
        while (player1SetScores.length < 3) {
          player1SetScores.add(0);
        }
        while (player2SetScores.length < 3) {
          player2SetScores.add(0);
        }
        while (player1TiebreakScores.length < 3) {
          player1TiebreakScores.add(0);
        }
        while (player2TiebreakScores.length < 3) {
          player2TiebreakScores.add(0);
        }

        // 确定比赛类型
        String matchType = 'Scheduled';
        if (matchState == 'P') {
          matchType = 'Live';
        } else if (matchState == 'F') {
          matchType = 'Completed';
        } else if (matchState == 'U') {
          matchType = 'Scheduled';
        }

        // 确定获胜者
        bool isPlayer1Winner = false;
        bool isPlayer2Winner = false;
        if (matchState == 'F') {
          if (match['Winner'] == '2') {
            isPlayer1Winner = true;
          } else if (match['Winner'] == '3') {
            isPlayer2Winner = true;
          }
        }
        final String dateTime = match['MatchTimeStamp'] ?? '';
        String adjustedDisplayTime = '';
        if (dateTime.isNotEmpty) {
          try {
            // 直接解析dateTime（ISO格式）
            final DateTime originalDateTime = DateTime.parse(dateTime);
            final localDateTime = TimezoneMapping.convertToLocalTime(
                originalDateTime, tournament['Location'] ?? '');
            debugPrint('当地时间: $originalDateTime');
            debugPrint('本地时间: $localDateTime');

            debugPrint('时间转换后: $localDateTime $originalDateTime');
            // 格式化为新的时间字符串
            final String formattedTime =
                '${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}';

            // 检查日期是否变化
            bool dateChanged = localDateTime.day != originalDateTime.day ||
                localDateTime.month != originalDateTime.month ||
                localDateTime.year != originalDateTime.year;

            // 重新构建显示时间，保留原始前缀
            adjustedDisplayTime = formattedTime;
            debugPrint('本地时间: $adjustedDisplayTime,$dateChanged');
            // 如果日期变化，添加提示
            if (dateChanged) {
              if (localDateTime.isAfter(originalDateTime)) {
                adjustedDisplayTime = '$adjustedDisplayTime (Next Day)';
              } else {
                adjustedDisplayTime = '$adjustedDisplayTime (Before Day)';
              }
            }
          } catch (e) {
            debugPrint('时间转换错误: $e');
            // 出错时使用原始时间
          }
        }

        // 创建格式化的比赛数据
        Map<String, dynamic> formattedMatch = {
          'player1': player1['Name'],
          'player2': player2['Name'],
          'player1Rank': player1['Rank'].toString().isNotEmpty
              ? '(${player1['Rank'].toString()})'
              : '',
          'player2Rank': player2['Rank'].toString().isNotEmpty
              ? '(${player2['Rank'].toString()})'
              : '',
          'player1Country': player1['Country'],
          'player2Country': player2['Country'],
          'player1FlagUrl':
              'https://www.atptour.com/-/media/images/flags/${player1['Country'].toString().toLowerCase()}.svg',
          'player2FlagUrl':
              'https://www.atptour.com/-/media/images/flags/${player2['Country'].toString().toLowerCase()}.svg',
          'player1Id': player1['ID'],
          'player2Id': player2['ID'],
          'player1SetScores': player1SetScores,
          'player2SetScores': player2SetScores,
          'player1TiebreakScores': player1TiebreakScores,
          'player2TiebreakScores': player2TiebreakScores,
          'roundInfo': "Round ${match['RoundID'] ?? ''}",
          'matchType': matchType,
          'serving1': match['Serve'] == 'A' ? true : false,
          'serving2': match['Serve'] == 'B' ? true : false,
          'matchTime': matchState == 'F' || matchState == 'P'
              ? '${match['MatchTimeTotal']}'
              : adjustedDisplayTime,
          'matchDuration': match['MatchTimeTotal'] ?? '',
          'isPlayer1Winner': isPlayer1Winner,
          'isPlayer2Winner': isPlayer2Winner,
          'player1ImageUrl':
              'https://wtafiles.blob.core.windows.net/images/headshots/${player1['ID'].toString()}.jpg',
          'player2ImageUrl':
              'https://wtafiles.blob.core.windows.net/images/headshots/${player2['ID'].toString()}.jpg',
          'isCompleted': matchState == 'F',
          'isLive': matchState == 'P',
          'stadium': match['CourtName'] != null
              ? '${match['CourtName'] ?? 'Court ${match['CourtID']}'}'
              : 'Court ${match['CourtID']}',
          'typePlayer': 'wta',
          'tournamentId': tournamentId.toString(),
          'matchId': match['MatchID'] ?? '',
          'currentGameScore1': '${match['PointA'] ?? ''}',
          'currentGameScore2': '${match['PointB'] ?? ''}',
          'tournamentName':
              '${tournament['tournamentGroup']['name'] ?? ''} ${tournament['tournamentGroup']['level'] ?? ''}',
        };

        formattedMatches.add(formattedMatch);
      }

      matchesByDate[formattedDate] = formattedMatches;
      return formattedMatches;
    } else {
      return [];
    }
    // } catch (e) {
    //   print('Error fetching WTA matches: $e');
    //   return [];
    // }
  }

  // 使用HeadlessInAppWebView获取ATP比赛结果HTML内容
  static Future<String> _getATPResultsHtmlWithWebView(String scoresUrl) async {
    final completer = Completer<String>();
    HeadlessInAppWebView? headlessWebView;

    try {
      final String fullUrl = 'https://www.atptour.com$scoresUrl';

      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(fullUrl)),
        initialSettings: InAppWebViewSettings(
          userAgent:
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          javaScriptEnabled: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          clearCache: false,
        ),
        onWebViewCreated: (controller) {
          debugPrint('ATP比赛结果页面 HeadlessInAppWebView创建成功');
        },
        onLoadStart: (controller, url) {
          debugPrint('开始加载ATP比赛结果页面: $url');
        },
        onLoadStop: (controller, url) async {
          debugPrint('ATP比赛结果页面加载完成: $url');

          try {
            // 等待页面完全渲染
            await Future.delayed(const Duration(seconds: 2));

            // 获取页面HTML内容
            final jsCode = '''
              (function() {
                try {
                  console.log('开始获取ATP比赛结果页面HTML...');
                  return document.documentElement.outerHTML;
                } catch (e) {
                  console.error('获取HTML时出错:', e);
                  return '';
                }
              })()
            ''';

            final result = await controller.evaluateJavascript(source: jsCode);
            debugPrint('ATP比赛结果HTML获取结果长度: ${result?.toString().length ?? 0}');

            if (result != null && result.toString().isNotEmpty) {
              completer.complete(result.toString());
            } else {
              debugPrint('ATP比赛结果HTML为空，尝试重新获取');
              await Future.delayed(const Duration(seconds: 2));
              final retryResult =
                  await controller.evaluateJavascript(source: jsCode);
              completer.complete(retryResult?.toString() ?? '');
            }
          } catch (e) {
            debugPrint('获取ATP比赛结果HTML时出错: $e');
            completer.complete('');
          }
        },
        onReceivedError: (controller, request, error) {
          debugPrint('ATP比赛结果WebView加载错误: ${error.description}');
          if (!completer.isCompleted) {
            completer.complete('');
          }
        },
        onReceivedHttpError: (controller, request, errorResponse) {
          debugPrint('ATP比赛结果HTTP错误: ${errorResponse.statusCode}');
          if (!completer.isCompleted) {
            completer.complete('');
          }
        },
      );

      await headlessWebView.run();

      // 设置超时
      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('ATP比赛结果WebView请求超时');
          return '';
        },
      );

      return result;
    } catch (e) {
      debugPrint('ATP比赛结果HeadlessInAppWebView异常: $e');
      return '';
    } finally {
      try {
        await headlessWebView?.dispose();
        debugPrint('ATP比赛结果HeadlessInAppWebView已释放');
      } catch (e) {
        debugPrint('释放ATP比赛结果WebView时出错: $e');
      }
    }
  }

  // 使用HeadlessInAppWebView获取WTA球员详情HTML内容
  static Future<String> _getWTAPlayerDetailsHtmlWithWebView(
      String playerUrl) async {
    final completer = Completer<String>();
    HeadlessInAppWebView? headlessWebView;

    try {
      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(playerUrl)),
        initialSettings: InAppWebViewSettings(
          userAgent:
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          javaScriptEnabled: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          clearCache: false,
        ),
        onWebViewCreated: (controller) {
          debugPrint('WTA球员详情页面 HeadlessInAppWebView创建成功');
        },
        onLoadStart: (controller, url) {
          debugPrint('开始加载WTA球员详情页面: $url');
        },
        onLoadStop: (controller, url) async {
          debugPrint('WTA球员详情页面加载完成: $url');

          try {
            // 等待页面完全渲染
            await Future.delayed(const Duration(seconds: 2));

            // 获取页面HTML内容
            final jsCode = '''
              (function() {
                try {
                  console.log('开始获取WTA球员详情页面HTML...');
                  return document.documentElement.outerHTML;
                } catch (e) {
                  console.error('获取HTML时出错:', e);
                  return '';
                }
              })()
            ''';

            final result = await controller.evaluateJavascript(source: jsCode);
            debugPrint('WTA球员详情HTML获取结果长度: ${result?.toString().length ?? 0}');

            if (result != null && result.toString().isNotEmpty) {
              completer.complete(result.toString());
            } else {
              debugPrint('WTA球员详情HTML为空，尝试重新获取');
              await Future.delayed(const Duration(seconds: 2));
              final retryResult =
                  await controller.evaluateJavascript(source: jsCode);
              completer.complete(retryResult?.toString() ?? '');
            }
          } catch (e) {
            debugPrint('获取WTA球员详情HTML时出错: $e');
            completer.complete('');
          }
        },
        onReceivedError: (controller, request, error) {
          debugPrint('WTA球员详情WebView加载错误: ${error.description}');
          if (!completer.isCompleted) {
            completer.complete('');
          }
        },
        onReceivedHttpError: (controller, request, errorResponse) {
          debugPrint('WTA球员详情HTTP错误: ${errorResponse.statusCode}');
          if (!completer.isCompleted) {
            completer.complete('');
          }
        },
      );

      await headlessWebView.run();

      // 设置超时
      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('WTA球员详情WebView请求超时');
          return '';
        },
      );

      return result;
    } catch (e) {
      debugPrint('WTA球员详情HeadlessInAppWebView异常: $e');
      return '';
    } finally {
      try {
        await headlessWebView?.dispose();
        debugPrint('WTA球员详情HeadlessInAppWebView已释放');
      } catch (e) {
        debugPrint('释放WTA球员详情WebView时出错: $e');
      }
    }
  }

  // 使用HeadlessInAppWebView获取US Open JSON数据
  static Future<String> _getUSOpenJsonWithWebView(String url) async {
    final completer = Completer<String>();
    HeadlessInAppWebView? headlessWebView;

    try {
      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          userAgent:
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          javaScriptEnabled: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          clearCache: false,
          cacheEnabled: true,
          allowFileAccessFromFileURLs: true,
          allowUniversalAccessFromFileURLs: true,
        ),
        onLoadStop: (controller, url) async {
          try {
            // 等待页面完全加载和JavaScript执行
            await Future.delayed(const Duration(seconds: 2));

            // 获取响应内容
            final result = await controller.evaluateJavascript(
                source: 'document.body.innerText');

            if (result != null && result.toString().isNotEmpty) {
              // 尝试清理和验证JSON
              String jsonStr = result.toString().trim();
              debugPrint('获取到US Open JSON数据长度: ${jsonStr.length}');

              // 检查是否是有效的JSON
              try {
                // 尝试解析JSON以验证格式
                json.decode(jsonStr);
                debugPrint('JSON格式验证成功');
                completer.complete(jsonStr);
              } catch (jsonError) {
                debugPrint('JSON解析错误: $jsonError');
                // 尝试修复常见的JSON格式问题
                try {
                  // 检查是否有未转义的引号或控制字符
                  String cleanedJson = jsonStr
                      .replaceAll(RegExp(r'\n'), '\n')
                      .replaceAll(RegExp(r'\r'), '\r')
                      .replaceAll(RegExp(r'\t'), '\t');

                  // 再次尝试解析
                  json.decode(cleanedJson);
                  debugPrint('JSON格式修复成功');
                  completer.complete(cleanedJson);
                } catch (e) {
                  debugPrint('JSON格式无法修复: $e');
                  completer.complete('');
                }
              }
            } else {
              debugPrint('获取到的JSON数据为空');
              completer.complete('');
            }
          } catch (e) {
            debugPrint('获取页面内容错误: $e');
            completer.complete('');
          }
        },
        onReceivedError: (controller, request, error) {
          debugPrint('WebView加载错误: ${error.description}');
          if (!completer.isCompleted) {
            completer.complete('');
          }
        },
      );

      await headlessWebView.run();

      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('获取JSON数据超时');
          return '';
        },
      );
      return result;
    } catch (e) {
      debugPrint('_getUSOpenJsonWithWebView异常: $e');
      return '';
    } finally {
      try {
        await headlessWebView?.dispose();
      } catch (e) {
        debugPrint('释放WebView资源时出错: $e');
      }
    }
  }

  // 获取美网比赛数据
  static Future<Map<String, List<Map<String, dynamic>>>>
      getUSOpenMatchesResultData(String? year, String? name) async {
    Map<String, List<Map<String, dynamic>>> matchesByDate = {};
    try {
      final eventDaysUrl =
          'https://www.usopen.org/en_US/scores/feeds/$year/completed_matches/eventDays.json';
      final eventDaysJson = await _getUSOpenJsonWithWebView(eventDaysUrl);
      if (eventDaysJson.isNotEmpty) {
        final eventDaysData = json.decode(eventDaysJson);
        final Map<String, String> dailyUrls = {};

        if (eventDaysData['eventDays'] is List) {
          for (var day in eventDaysData['eventDays']) {
            if (day['url'] != null &&
                day['message'] != null &&
                day['events'].length > 0) {
              dailyUrls[day['message']] = day['url'];
              // break;
            }
          }
        }
        for (var entry in dailyUrls.entries) {
          final dateStr = entry.key;
          final matchesUrl = entry.value;
          final fullMatchesUrl = matchesUrl;

          final matchesJson = await _getUSOpenJsonWithWebView(fullMatchesUrl);
          debugPrint('usopen-----matchesData: $fullMatchesUrl');
          if (matchesJson.isNotEmpty) {
            final matchesData = json.decode(matchesJson);

            final matches = matchesData['matches'] as List<dynamic>;
            List<Map<String, dynamic>> formattedMatches = [];

            String formattedDate = '';
            try {
              final datePart = dateStr.split(':').last.trim();
              final parsedDate = DateFormat('EEEE, MMMM d').parse(datePart);
              final finalDate =
                  DateTime(int.parse(year!), parsedDate.month, parsedDate.day);
              formattedDate = DateFormat('E, dd MMMM, yyyy').format(finalDate);
            } catch (e) {
              formattedDate = dateStr;
            }

            for (var match in matches) {
              if (match['eventCode'] != 'MS' && match['eventCode'] != 'WS') {
                continue;
              }

              final team1 = match['team1'];
              final team2 = match['team2'];

              List<int> player1SetScores = [];
              List<int> player2SetScores = [];
              List<int> player1TiebreakScores = [];
              List<int> player2TiebreakScores = [];
              final bool isMensMatch = match['eventCode'] == 'MS';

              if (match['scores'] != null && match['scores']['sets'] != null) {
                for (var set in match['scores']['sets']) {
                  if (set is List &&
                      set.length >= 2 &&
                      set[0] != null &&
                      set[1] != null) {
                    player1SetScores.add(set[0]['score'] ?? 0);
                    player2SetScores.add(set[1]['score'] ?? 0);
                    player1TiebreakScores.add(
                        int.tryParse(set[0]['tiebreak']?.toString() ?? '') ??
                            0);
                    player2TiebreakScores.add(
                        int.tryParse(set[1]['tiebreak']?.toString() ?? '') ??
                            0);
                  } else {
                    // Handle incomplete sets, e.g., from retirements
                    player1SetScores.add(0);
                    player2SetScores.add(0);
                    player1TiebreakScores.add(0);
                    player2TiebreakScores.add(0);
                  }
                }
              }

              // Pad remaining sets for display consistency
              // while (player1SetScores.length < maxSets) {
              //   player1SetScores.add(0);
              //   player2SetScores.add(0);
              //   player1TiebreakScores.add(0);
              //   player2TiebreakScores.add(0);
              // }

              final matchData = {
                'tournamentName': name,
                'roundInfo': match['roundNameShort'],
                'stadium': match['shortCourtName'],
                'matchTime': match['duration'],
                'isCompleted': match['status'] == 'Completed',
                'matchStatus':
                    match['status'] == 'Completed' ? 'Completed' : 'Scheduled',
                'player1': team1['displayNameA'],
                'player2': team2['displayNameA'],
                'player1Id': isMensMatch
                    ? (team1['idA'] ?? '').replaceFirst('atp', '')
                    : (team1['idA'] ?? '').replaceFirst('wta', ''),
                'player2Id': isMensMatch
                    ? (team2['idA'] ?? '').replaceFirst('atp', '')
                    : (team2['idA'] ?? '').replaceFirst('wta', ''),
                'player1Rank':
                    team1['seed'] != null ? '(${team1['seed']})' : '',
                'player2Rank':
                    team2['seed'] != null ? '(${team2['seed']})' : '',
                'player1ImageUrl': isMensMatch
                    ? 'https://www.atptour.com/-/media/alias/player-headshot/${(team1['idA'] ?? '').replaceFirst('atp', '')}'
                    : 'https://wtafiles.blob.core.windows.net/images/headshots/${(team1['idA'] ?? '').replaceFirst('wta', '')}.jpg', // No image URL in new API
                'player2ImageUrl': isMensMatch
                    ? 'https://www.atptour.com/-/media/alias/player-headshot/${(team2['idA'] ?? '').replaceFirst('atp', '')}'
                    : 'https://wtafiles.blob.core.windows.net/images/headshots/${(team2['idA'] ?? '').replaceFirst('wta', '')}.jpg', // No image URL in new API
                'player1FlagUrl':
                    'https://www.atptour.com/-/media/images/flags/${team1['nationA'].toString().toLowerCase()}.svg',
                'player2FlagUrl':
                    'https://www.atptour.com/-/media/images/flags/${team2['nationA'].toString().toLowerCase()}.svg',
                'player1Country': team1['nationA'],
                'player2Country': team2['nationA'],
                'player1SetScores': player1SetScores,
                'player2SetScores': player2SetScores,
                'player1TiebreakScores': player1TiebreakScores,
                'player2TiebreakScores': player2TiebreakScores,
                'isWinner1': match['winner'] == '1',
                'isWinner2': match['winner'] == '2',
                'matchDuration': match['duration'] ?? '-',
                'isPlayer1Winner': match['winner'] == '1',
                'isPlayer2Winner': match['winner'] == '2',
                'matchType':
                    match['status'] == 'Completed' ? 'completed' : 'unmatch',
                'matchId': match['match_id'],
                'tournamentId': '560', // Hardcoded for US Open
                'year': year,
                'GS': 'usopen'
              };
              formattedMatches.add(matchData);
            }
            debugPrint(
                'usopen-----matchesData: $formattedDate,$formattedMatches');
            matchesByDate[formattedDate] = formattedMatches;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching US Open matches: $e');
    }
    return matchesByDate;
  }

  static Future<Map<String, List<Map<String, dynamic>>>>
      getATPMatchesResultData(String? scoresUrl, String? name) async {
    Map<String, List<Map<String, dynamic>>> matchesByDate = {};
    try {
      // 使用HeadlessInAppWebView获取HTML内容
      final htmlContent = await _getATPResultsHtmlWithWebView(scoresUrl!);
      debugPrint('getATPMatchesResultData HTML长度: ${htmlContent.length}');
      if (htmlContent.isNotEmpty) {
        final document = parse(htmlContent);
        final accordionItems =
            document.getElementsByClassName('atp_accordion-item');

        for (var accordionItem in accordionItems) {
          // 查找日期元素
          final tournamentDays =
              accordionItem.getElementsByClassName('tournament-day');
          if (tournamentDays.isEmpty) continue;

          // 获取日期文本
          final dateHeader = tournamentDays.first.getElementsByTagName('h4');
          if (dateHeader.isEmpty) continue;
          String dateStr = '';
          // 直接获取h4的文本内容，但排除其中的span标签内容
          for (var node in dateHeader.first.nodes) {
            if (node is dom.Text) {
              dateStr += node.text.trim();
            }
          }
          // 清理日期字符串，移除多余空格
          dateStr = dateStr.trim();
          debugPrint('解析日期: $dateStr');

          // 为该日期创建一个空列表
          matchesByDate[dateStr] = [];

          // 获取所有比赛元素
          final matchElements = accordionItem.getElementsByClassName('match');
          for (var matchElement in matchElements) {
            // 获取轮次和时间信息
            final matchHeader =
                matchElement.getElementsByClassName('match-header').first;
            final headerSpans = matchHeader.getElementsByTagName('span');
            final arrRound = headerSpans.first.text.split('-');
            String round = '';
            String Stadium = '';
            if (arrRound.length > 1) {
              round = arrRound[0].trim();
              Stadium = arrRound[1].trim();
            }
            final String matchTime =
                headerSpans.length > 1 ? headerSpans[1].text.trim() : '';

            // 在获取比赛内容的部分
            final matchContent =
                matchElement.getElementsByClassName('match-content').first;
            final statsItems =
                matchContent.getElementsByClassName('stats-item');
            final matchCta = matchElement.getElementsByClassName('match-cta');
            String VarmatchId = '';
            String VartournamentId = '';
            String Varyear = '';
            if (matchCta.isNotEmpty) {
              final links = matchCta.first.getElementsByTagName('a');
              if (links.length >= 2) {
                final detailLink = links[1].attributes['href'];
                if (detailLink != null && detailLink.isNotEmpty) {
                  // 解析链接获取 year, tournamentId, matchId
                  final segments = detailLink.split('/');
                  if (segments.length >= 3) {
                    final matchId = segments.last;
                    final tournamentId = segments[segments.length - 2];
                    final year = segments[segments.length - 3];
                    // 添加到比赛数据中
                    VarmatchId = matchId;
                    VartournamentId = tournamentId;
                    Varyear = year;
                  }
                }
              }
            }
            if (statsItems.length >= 2) {
              // 检查哪位球员是获胜者
              final win1 = statsItems[0].getElementsByClassName('winner');
              final win2 = statsItems[1].getElementsByClassName('winner');

              final isPlayer1Winner = win1.isNotEmpty == true;
              final isPlayer2Winner = win2.isNotEmpty == true;

              // 获取第一个选手信息
              final player1Info =
                  statsItems[0].getElementsByClassName('player-info').first;
              final player1NameLink = player1Info
                  .getElementsByClassName('name')
                  .first
                  .getElementsByTagName('a');
              var player1Name = '';
              var player1Rank = '';
              if (player1NameLink.isNotEmpty) {
                player1Name = player1NameLink.first.text
                    .trim()
                    .replaceAll(RegExp(r'[\r\n]+'), '');
              }
              var player1Id = '';
              if (player1NameLink.isNotEmpty) {
                final href = player1NameLink.first.attributes['href'];

                if (href != null && href.isNotEmpty) {
                  final parts = href.split('/');
                  if (parts.length >= 4) {
                    // 获取倒数第二个部分作为球员ID
                    player1Id = parts[parts.length - 2];
                  }
                }
              }
              final player1RankObj = player1Info
                  .getElementsByClassName('name')
                  .first
                  .getElementsByTagName('span')
                  .first
                  .text
                  .trim();
              if (player1RankObj.isNotEmpty) {
                player1Rank = player1RankObj;
              }
              // 获取第一个选手的国家
              final player1Country =
                  player1Info.getElementsByClassName('atp-flag').isNotEmpty
                      ? player1Info
                              .getElementsByClassName('atp-flag')
                              .first
                              .attributes['data-country'] ??
                          ''
                      : '';
              String player1FlagUrl = '';
              if (player1Info.getElementsByClassName('atp-flag').isNotEmpty) {
                final flagElement =
                    player1Info.getElementsByClassName('atp-flag').first;
                if (flagElement.getElementsByTagName('use').isNotEmpty) {
                  final useElement =
                      flagElement.getElementsByTagName('use').first;
                  if (useElement.attributes.containsKey('href')) {
                    String flagHref = useElement.attributes['href'] ?? '';
                    if (flagHref.isNotEmpty) {
                      // 按照-分割，获取最后一个元素作为国家代码
                      List<String> parts = flagHref.split('-');
                      if (parts.isNotEmpty) {
                        String countryCode = parts.last;
                        // 构建完整的国旗URL
                        player1FlagUrl =
                            'https://www.atptour.com/-/media/images/flags/$countryCode.svg';
                      } else {
                        // 如果分割后为空，使用原始URL
                        player1FlagUrl = 'https://www.atptour.com$flagHref';
                      }
                    }
                  }
                }
              }
              String player1ImageUrl = '';
              final player1ImageElements =
                  player1Info.getElementsByClassName('player-image');
              if (player1ImageElements.isNotEmpty) {
                final srcAttr = player1ImageElements.first.attributes['src'];
                if (srcAttr != null && srcAttr.isNotEmpty) {
                  // 如果src是相对路径，添加基础URL
                  if (srcAttr.startsWith('/')) {
                    player1ImageUrl = 'https://www.atptour.com$srcAttr';
                  } else {
                    player1ImageUrl = srcAttr;
                  }
                }
              }
              // 获取第二个选手信息
              final player2Info =
                  statsItems[1].getElementsByClassName('player-info').first;
              final player2NameLink = player2Info
                  .getElementsByClassName('name')
                  .first
                  .getElementsByTagName('a');
              var player2Name = '';
              var player2Rank = '';

              if (player2NameLink.isNotEmpty) {
                player2Name = player2NameLink.first.text
                    .trim()
                    .replaceAll(RegExp(r'[\r\n]+'), '');
              }
              var player2Id = '';
              if (player2NameLink.isNotEmpty) {
                final href = player2NameLink.first.attributes['href'];

                if (href != null && href.isNotEmpty) {
                  final parts = href.split('/');
                  if (parts.length >= 4) {
                    // 获取倒数第二个部分作为球员ID
                    player2Id = parts[parts.length - 2];
                  }
                }
              }
              final player2RankObj = player2Info
                  .getElementsByClassName('name')
                  .first
                  .getElementsByTagName('span')
                  .first
                  .text
                  .trim();
              if (player2RankObj.isNotEmpty) {
                player2Rank = player2RankObj;
              }
              final player2Country =
                  player2Info.getElementsByClassName('atp-flag').isNotEmpty
                      ? player2Info
                              .getElementsByClassName('atp-flag')
                              .first
                              .attributes['data-country'] ??
                          ''
                      : '';
// 获取球员2国旗图片URL
              String player2FlagUrl = '';
              if (player2Info.getElementsByClassName('atp-flag').isNotEmpty) {
                final flagElement =
                    player2Info.getElementsByClassName('atp-flag').first;
                if (flagElement.getElementsByTagName('use').isNotEmpty) {
                  final useElement =
                      flagElement.getElementsByTagName('use').first;
                  String flagHref = useElement.attributes['href'] ?? '';
                  if (flagHref.isNotEmpty) {
                    // 按照-分割，获取最后一个元素作为国家代码
                    List<String> parts = flagHref.split('-');
                    if (parts.isNotEmpty) {
                      String countryCode = parts.last;
                      // 构建完整的国旗URL
                      player2FlagUrl =
                          'https://www.atptour.com/-/media/images/flags/$countryCode.svg';
                    } else {
                      // 如果分割后为空，使用原始URL
                      player2FlagUrl = 'https://www.atptour.com$flagHref';
                    }
                  }
                }
              }
              // 获取球员2头像
              String player2ImageUrl = '';
              final player2ImageElements =
                  player2Info.getElementsByClassName('player-image');
              if (player2ImageElements.isNotEmpty) {
                final srcAttr = player2ImageElements.first.attributes['src'];
                if (srcAttr != null && srcAttr.isNotEmpty) {
                  // 如果src是相对路径，添加基础URL
                  if (srcAttr.startsWith('/')) {
                    player2ImageUrl = 'https://www.atptour.com$srcAttr';
                  } else {
                    player2ImageUrl = srcAttr;
                  }
                }
              }
              // 获取比分信息
              final scores1 = statsItems[0].getElementsByClassName('scores');
              final scores2 = statsItems[1].getElementsByClassName('scores');

              // 改为按球员分别存储比分
              List<int> player1SetScores = [];
              List<int> player2SetScores = [];
              List<int> player1TiebreakScores = [];
              List<int> player2TiebreakScores = [];

              if (scores1.isNotEmpty && scores2.isNotEmpty) {
                // 获取每个选手的得分元素
                final scoreItems1 =
                    scores1.first.getElementsByClassName('score-item');
                final scoreItems2 =
                    scores2.first.getElementsByClassName('score-item');

                // 确保两个选手的得分项数量相同
                final minItems = scoreItems1.length < scoreItems2.length
                    ? scoreItems1.length
                    : scoreItems2.length;

                for (int i = 1; i < minItems; i++) {
                  // 获取当前盘的得分元素
                  final item1 = scoreItems1[i];
                  final item2 = scoreItems2[i];

                  // 获取每个得分项中的所有span元素
                  final spans1 = item1.getElementsByTagName('span');
                  final spans2 = item2.getElementsByTagName('span');

                  // 获取主要得分（第一个span）
                  final s1 = int.tryParse(
                          spans1.isNotEmpty ? spans1[0].text.trim() : '0') ??
                      0;
                  final s2 = int.tryParse(
                          spans2.isNotEmpty ? spans2[0].text.trim() : '0') ??
                      0;

                  // 添加到各自的盘分数组
                  player1SetScores.add(s1);
                  player2SetScores.add(s2);

                  // 检查是否有抢七小分（第二个span）
                  int tb1 = 0;
                  int tb2 = 0;

                  // 检查player1的抢七小分
                  if (spans1.length > 1) {
                    final tiebreakText = spans1[1].text.trim();

                    tb1 = int.tryParse(tiebreakText) ?? 0;
                  }

                  // 检查player2的抢七小分
                  if (spans2.length > 1) {
                    final tiebreakText = spans2[1].text.trim();
                    tb2 = int.tryParse(tiebreakText) ?? 0;
                  }

                  // 添加到各自的抢七分数组
                  player1TiebreakScores.add(tb1);
                  player2TiebreakScores.add(tb2);
                }
              }

              // 创建比赛数据对象时添加获胜者信息
              final matchData = {
                'roundInfo': round,
                'stadium': Stadium,
                'matchTime': matchTime,
                'player1': player1Name,
                'player2': player2Name,
                'player1Id': player1Id,
                'player2Id': player2Id,
                'player1Rank': player1Rank,
                'player2Rank': player2Rank,
                'player1Country': player1Country,
                'player2Country': player2Country,
                'player1FlagUrl': player1FlagUrl,
                'player2FlagUrl': player2FlagUrl,
                'player1ImageUrl': player1ImageUrl,
                'player2ImageUrl': player2ImageUrl,
                // 使用新的存储格式
                'player1SetScores': player1SetScores,
                'player2SetScores': player2SetScores,
                'player1TiebreakScores': player1TiebreakScores,
                'player2TiebreakScores': player2TiebreakScores,
                'isCompleted': true, // 标记为已完成的
                'matchDuration': matchTime,
                'isPlayer1Winner': isPlayer1Winner, // 添加获胜者标识
                'isPlayer2Winner': isPlayer2Winner, // 添加获胜者标识
                'matchType': 'completed',
                'tournamentName': name,
                'matchId': VarmatchId,
                'tournamentId': VartournamentId,
                'year': Varyear,
              };
              matchesByDate[dateStr]!.add(matchData);
            }
          }
        }
      } else {
        debugPrint('获取ATP比赛结果数据失败: HTML内容为空');
      }
    } catch (e) {
      print('Error fetching ATP matches============: $e');
    }

    return matchesByDate;
  }

  // 使用HeadlessInAppWebView获取ATP球员详情JSON对象
  static Future<Map<String, dynamic>> _getPlayerDetailsHtmlWithWebView(
      String playerUrl) async {
    final completer = Completer<Map<String, dynamic>>();
    HeadlessInAppWebView? headlessWebView;

    try {
      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(playerUrl)),
        initialSettings: InAppWebViewSettings(
          userAgent:
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          javaScriptEnabled: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          clearCache: false,
        ),
        onWebViewCreated: (controller) {
          debugPrint('ATP球员详情页面 HeadlessInAppWebView创建成功');
        },
        onLoadStart: (controller, url) {
          debugPrint('开始加载ATP球员详情页面: $url');
        },
        onLoadStop: (controller, url) async {
          debugPrint('ATP球员详情页面加载完成: $url');

          try {
            // 等待页面完全渲染
            await Future.delayed(const Duration(seconds: 2));

            // 获取页面JSON内容
            final jsCode = '''
              (function() {
                try {
                  console.log('开始解析ATP球员详情页面数据...');
                  
                  // 检查页面是否已经包含JSON数据
                  const bodyText = document.body.textContent || document.body.innerText;
                  console.log('页面内容长度:', bodyText.length);
                  
                  // 尝试解析JSON数据
                  try {
                    const data = JSON.parse(bodyText);
                    if (data && typeof data === 'object') {
                      console.log('成功解析ATP球员详情JSON数据');
                      return data;
                    }
                  } catch (e) {
                    console.log('页面内容不是JSON格式，返回原始内容');
                    return bodyText;
                  }
                  
                  console.log('无法解析ATP球员详情数据');
                  return null;
                } catch (e) {
                  console.error('ATP球员详情JavaScript解析错误:', e);
                  return null;
                }
              })()
            ''';

            final result = await controller.evaluateJavascript(source: jsCode);
            debugPrint('ATP球员详情获取结果: ${result?.toString()}');

            if (result != null) {
              if (result is Map) {
                completer.complete(Map<String, dynamic>.from(result));
              } else if (result is String && result.isNotEmpty) {
                try {
                  final parsedData = json.decode(result);
                  if (parsedData is Map<String, dynamic>) {
                    completer.complete(parsedData);
                  } else {
                    completer.complete({'rawContent': result});
                  }
                } catch (e) {
                  debugPrint('解析JavaScript返回的JSON失败: $e');
                  completer.complete({'rawContent': result});
                }
              } else {
                completer.complete({});
              }
            } else {
              debugPrint('ATP球员详情为空，尝试重新获取');
              await Future.delayed(const Duration(seconds: 2));
              final retryResult =
                  await controller.evaluateJavascript(source: jsCode);
              if (retryResult != null && retryResult is Map) {
                completer.complete(Map<String, dynamic>.from(retryResult));
              } else {
                completer.complete({});
              }
            }
          } catch (e) {
            debugPrint('获取ATP球员详情HTML时出错: $e');
            completer.complete({});
          }
        },
        onReceivedError: (controller, request, error) {
          debugPrint('ATP球员详情WebView加载错误: ${error.description}');
          if (!completer.isCompleted) {
            completer.complete({});
          }
        },
        onReceivedHttpError: (controller, request, errorResponse) {
          debugPrint('ATP球员详情HTTP错误: ${errorResponse.statusCode}');
          if (!completer.isCompleted) {
            completer.complete({});
          }
        },
      );

      await headlessWebView.run();

      // 设置超时
      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('ATP球员详情WebView请求超时');
          return <String, dynamic>{};
        },
      );

      return result;
    } catch (e) {
      debugPrint('ATP球员详情HeadlessInAppWebView异常: $e');
      return <String, dynamic>{};
    } finally {
      try {
        await headlessWebView?.dispose();
        debugPrint('ATP球员详情HeadlessInAppWebView已释放');
      } catch (e) {
        debugPrint('释放ATP球员详情WebView时出错: $e');
      }
    }
  }

  // 获取球员详情数据
  static Future<Map<String, dynamic>> getPlayerDetails(String playerId) async {
    try {
      // 构建ATP球员详情页面URL
      final String playerUrl =
          'https://www.atptour.com/en/-/www/players/hero/$playerId?v=1';
      debugPrint('ATP球员详情URL: $playerUrl');

      // 使用HeadlessInAppWebView获取JSON对象
      final playerData = await _getPlayerDetailsHtmlWithWebView(playerUrl);
      debugPrint('getPlayerDetails 获取到的数据: $playerData');

      if (playerData.isNotEmpty) {
        // 添加playerId到返回的数据中
        playerData['playerId'] = playerId;
        return playerData;
      } else {
        throw Exception('获取ATP球员数据失败: 返回数据为空');
      }
    } catch (e) {
      debugPrint('获取球员详情异常: $e');
      // 如果WebView调用失败，尝试加载本地数据
      return loadLocalPlayerData();
    }
  }

  // 获取WTA女子球员详情页数据
  static Future<Map<String, dynamic>> getWTAPlayerDetails(
      String playerId, String playername) async {
    try {
      // 构建完整URL
      String playerUrl =
          'https://www.wtatennis.com/players/$playerId/$playername';
      debugPrint('WTAgURI=======$playerUrl');

      // 使用HeadlessInAppWebView获取HTML内容
      final htmlContent = await _getWTAPlayerDetailsHtmlWithWebView(playerUrl);
      debugPrint('getWTAPlayerDetails HTML长度: ${htmlContent.length}');

      if (htmlContent.isNotEmpty) {
        final document = parse(htmlContent);
        Map<String, dynamic> playerData = {};
        // 先查找player-headshot__photo容器
        final headshotContainers =
            document.getElementsByClassName('player-headshot__photo');
        if (headshotContainers.isNotEmpty) {
          // 在容器内查找object-fit-cover-picture__img元素
          final playerImageElements = headshotContainers.first
              .getElementsByClassName('object-fit-cover-picture__img');
          if (playerImageElements.isNotEmpty) {
            final srcAttr = playerImageElements.first.attributes['src'];
            if (srcAttr != null && srcAttr.isNotEmpty) {
              // 如果src是相对路径，添加基础URL
              if (srcAttr.startsWith('/')) {
                playerData['ImageUrl'] = 'https://www.wtatennis.com$srcAttr';
              } else {
                playerData['ImageUrl'] = srcAttr;
              }
            } else {
              playerData['ImageUrl'] = ''; // 默认值
            }
          } else {
            playerData['ImageUrl'] = ''; // 默认值
          }
        } else {
          playerData['ImageUrl'] = ''; // 默认值
        }
        debugPrint('ImageUrl: ${playerData['ImageUrl']}');
        // 获取球员基本信息
        final bioInfoContainer =
            document.getElementsByClassName('profile-bio__info');

        if (bioInfoContainer.isNotEmpty) {
          final bioItems = bioInfoContainer.first
              .getElementsByClassName('profile-bio__info-block');
          debugPrint('${bioItems.length}');
          // 按顺序分别是持拍手，职业排名，身高，生日，出生地
          for (var i = 0; i < bioItems.length; i++) {
            final item = bioItems[i];
            debugPrint('$i ==== $item');
            final value = item
                .getElementsByClassName('profile-bio__info-content')
                .first
                .text
                .trim();

            switch (i) {
              case 0:
                playerData['Plays'] = value; // 持拍手
                playerData['PlayHand'] = {'Description': value}; // 与 ATP 格式统一
                break;
              case 1:
                playerData['CurrentRank'] =
                    value.replaceAll(RegExp(r'[^\d]'), ''); // 职业排名，只保留数字
                playerData['SglRank'] =
                    value.replaceAll(RegExp(r'[^\d]'), ''); // 与 ATP 格式统一
                playerData['SglRankMove'] = '0'; // 默认值
                break;
              case 2:
                playerData['Height'] = value; // 身高
                // 处理身高格式，分离英制和公制单位
                if (value.contains('(') && value.contains(')')) {
                  // 格式如 "5' 11\" (1.82m)"
                  final regex = RegExp(r'(.*?)\s*\((.*?)\)');
                  final match = regex.firstMatch(value);
                  if (match != null) {
                    playerData['HeightFt'] =
                        match.group(1)?.trim() ?? ''; // 英制单位 (5' 11")
                    playerData['HeightCm'] =
                        match.group(2)?.trim() ?? ''; // 公制单位 (1.82m)
                  } else {
                    playerData['HeightFt'] = value;
                    playerData['HeightCm'] = '';
                  }
                } else {
                  playerData['HeightFt'] = value;
                  playerData['HeightCm'] = '';
                }
                break;
              case 3:
                debugPrint(value);
                break;
              case 4:
                playerData['Birthplace'] = value; // 出生地
                playerData['BirthCity'] = value; // 与 ATP 格式统一
                break;
            }
          }
        }

        // 获取当前教练
        final currentCoach = document.getElementsByClassName('current-coach');
        debugPrint('$currentCoach');
        if (currentCoach.isNotEmpty) {
          final coachValue =
              currentCoach.first.getElementsByClassName('current-coach__info');
          if (coachValue.isNotEmpty) {
            playerData['Coach'] = coachValue.first.text.trim();
          } else {
            playerData['Coach'] = ''; // 默认值
          }
        } else {
          playerData['Coach'] = ''; // 默认值
        }

        // 获取本赛季统计数据
        final statBlocks = document.getElementsByClassName('stat-block');
        if (statBlocks.isNotEmpty) {
          List<Map<String, String>> seasonStats = [];

          for (var block in statBlocks) {
            debugPrint('$block');

            final statValue = block
                .getElementsByClassName('stat-block__stat')
                .first
                .text
                .trim();

            seasonStats.add({
              'value': statValue,
            });
          }

          // 按顺序分别是排名，冠军，胜负和奖金
          if (seasonStats.length >= 4) {
            playerData['YTDRank'] = seasonStats[0]['value'] ?? '0';
            playerData['YTDTitles'] = seasonStats[1]['value'] ?? '0';
            playerData['YTDWinLoss'] = seasonStats[2]['value'] ?? '0/0';
            playerData['YTDPrizeMoney'] = seasonStats[3]['value'] ?? '0';

            // 与 ATP 格式统一
            playerData['SglYtdTitles'] = seasonStats[1]['value'] ?? '0';

            // 解析胜负记录
            final winLoss = (seasonStats[2]['value'] ?? '0/0').split('/');
            playerData['SglYtdWon'] = int.tryParse(winLoss[0].trim()) ?? 0;
            playerData['SglYtdLost'] =
                winLoss.length > 1 ? int.tryParse(winLoss[1].trim()) ?? 0 : 0;

            playerData['SglYtdPrizeFormatted'] = seasonStats[3]['value'] ?? '0';
          } else {
            // 默认值
            playerData['YTDRank'] = '0';
            playerData['YTDTitles'] = '0';
            playerData['YTDWinLoss'] = '0/0';
            playerData['YTDPrizeMoney'] = '0';
            playerData['SglYtdTitles'] = '0';
            playerData['SglYtdWon'] = 0;
            playerData['SglYtdLost'] = 0;
            playerData['SglYtdPrizeFormatted'] = '0';
          }
        } else {
          // 默认值
          playerData['YTDRank'] = '0';
          playerData['YTDTitles'] = '0';
          playerData['YTDWinLoss'] = '0/0';
          playerData['YTDPrizeMoney'] = '0';
          playerData['SglYtdTitles'] = '0';
          playerData['SglYtdWon'] = 0;
          playerData['SglYtdLost'] = 0;
          playerData['SglYtdPrizeFormatted'] = '0';
        }

        // 获取球员姓名
        final playerName =
            document.getElementsByClassName('profile-header__name-wrap');
        if (playerName.isNotEmpty) {
          playerData['Name'] = playerName.first.text.trim();
        } else {
          playerData['Name'] = ''; // 默认值
        }

        // 添加球员类型标识
        playerData['PlayerType'] = 'WTA';
        playerData['ScRelativeUrlPlayerCountryFlag'] = '';
        // 添加其他 ATP 格式字段的默认值
        playerData['BackHand'] = {'Description': 'Two-Handed'};
        if (document
            .getElementsByClassName('profile-header__meta-item')
            .first
            .text
            .contains('yrs')) {
          playerData['Age'] = document
              .getElementsByClassName('profile-header__meta-item')[0]
              .text
              .trim();
        } else if (document
                .getElementsByClassName('profile-header__meta-item')
                .length >=
            2) {
          playerData['Age'] = document
              .getElementsByClassName('profile-header__meta-item')[1]
              .text
              .trim();
        } else {
          playerData['Age'] = '--';
        }
        playerData['WeightLb'] = '--';
        playerData['ProYear'] = '--';
        final profileHeader = document.getElementsByClassName('profile-header');

        if (profileHeader.isNotEmpty) {
          final dataPlayerStats =
              profileHeader.first.attributes['data-player-stats'];
          debugPrint('profileHeader 000000$dataPlayerStats');
          if (dataPlayerStats != null && dataPlayerStats.isNotEmpty) {
            try {
              // 解析JSON数据
              final statsData = json.decode(dataPlayerStats);

              // 获取career下的数据
              if (statsData.containsKey('career')) {
                final careerData = statsData['career'];

                // 获取单打数据
                if (careerData.containsKey('singles')) {
                  final singleData = careerData['singles'];

                  // 获取胜负场次
                  if (singleData.containsKey('winLoss')) {
                    final wonLost = singleData['winLoss'];
                    final parts = wonLost.toString().split('/');
                    if (parts.length == 2) {
                      playerData['SglCareerWon'] =
                          int.tryParse(parts[0].trim()) ?? 0;
                      playerData['SglCareerLost'] =
                          int.tryParse(parts[1].trim()) ?? 0;
                    }
                  }

                  // 获取冠军数
                  if (singleData.containsKey('titles')) {
                    playerData['SglCareerTitles'] =
                        singleData['titles'].toString();
                  }

                  // 获取最高排名
                  if (singleData.containsKey('rank')) {
                    playerData['SglHiRank'] = singleData['rank'].toString();
                  }
                }

                // 获取奖金数据
                if (careerData.containsKey('prizeMoney')) {
                  playerData['CareerPrizeFormatted'] =
                      '\$${NumberFormat('#,###').format(int.tryParse(careerData['prizeMoney'].toString()) ?? 0)}';
                }
              }
            } catch (e) {
              debugPrint('解析球员统计数据JSON出错: $e');
            }
          }
        } else {
          playerData['SglCareerWon'] = 0;
          playerData['SglCareerLost'] = 0;
          playerData['SglCareerTitles'] = '0';
          playerData['SglHiRank'] = '0';
          playerData['SglHiRankDate'] = DateTime.now().toString();
          playerData['CareerPrizeFormatted'] = '0';
        }

        return playerData;
      } else {
        throw Exception('获取WTA球员数据失败: HTML内容为空');
      }
    } catch (e) {
      debugPrint('解析WTA球员数据异常: $e');
      // 返回默认数据结构，确保与 ATP 格式一致
      return {
        'Name': '',
        'SglRank': '0',
        'SglRankMove': '0',
        'PlayHand': {'Description': 'Right-Handed'},
        'BackHand': {'Description': 'Two-Handed'},
        'Age': '0',
        'WeightLb': '0',
        'HeightFt': '',
        'BirthDate': '',
        'BirthCity': '',
        'ProYear': '0',
        'Nationality': '',
        'Coach': '',
        'SglYtdWon': 0,
        'SglYtdLost': 0,
        'SglYtdTitles': '0',
        'SglCareerWon': 0,
        'SglCareerLost': 0,
        'SglCareerTitles': '0',
        'SglHiRank': '0',
        'SglHiRankDate': DateTime.now().toString(),
        'SglYtdPrizeFormatted': '0',
        'CareerPrizeFormatted': '0',
        'PlayerType': 'WTA',
        'ImageUrl': '',
        'FlagUrl': '',
      };
    }
  }

  // 加载本地球员数据
  static Future<Map<String, dynamic>> loadLocalPlayerData() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/player.json');
      return json.decode(jsonString);
    } catch (e) {
      debugPrint('加载本地球员数据失败: $e');
      return {};
    }
  }

  // 获取比赛统计数据
  static Future<Map<String, dynamic>> getMatchStats(
      String year, String tournamentId, String matchId) async {
    try {
      final String endpoint =
          '/-/Hawkeye/MatchStats/Complete/$year/$tournamentId/$matchId';
      final Uri uri = _buildUri(endpoint, '');

      final response = await _makeHttpRequest(
        uri,
        {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
        timeout: const Duration(seconds: 10),
      );

      debugPrint('getMatchStats status: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          // 尝试解析为JSON
          return json.decode(response.body);
        } catch (e) {
          // 如果不是JSON格式，可能是HTML，需要解析HTML
          debugPrint('解析比赛统计数据失败，尝试解析HTML: $e');
          return _parseMatchStatsHtml(response.body);
        }
      } else {
        throw Exception('获取比赛统计数据失败: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('获取比赛统计数据异常: $e');
      // 如果API调用失败，返回模拟数据用于UI展示
      return _getMockMatchStats();
    }
  }

  // 解析比赛统计数据HTML
  static Map<String, dynamic> _parseMatchStatsHtml(String htmlBody) {
    try {
      final document = parse(htmlBody);

      // 提取球员信息
      final playerElements = document.querySelectorAll('.player-name');
      List<Map<String, String>> players = [];

      for (var element in playerElements) {
        final name = element.text.trim();
        final country =
            element.parent?.querySelector('.player-country')?.text.trim() ?? '';
        players.add({
          'name': name,
          'country': country,
        });
      }

      // 提取比分信息
      final scoreElements = document.querySelectorAll('.set-score');
      List<Map<String, int>> sets = [];

      for (int i = 0; i < scoreElements.length; i += 2) {
        if (i + 1 < scoreElements.length) {
          sets.add({
            'player1': int.tryParse(scoreElements[i].text.trim()) ?? 0,
            'player2': int.tryParse(scoreElements[i + 1].text.trim()) ?? 0,
          });
        }
      }

      // 提取统计数据
      final statsRows = document.querySelectorAll('.stats-row');
      Map<String, dynamic> player1Stats = {};
      Map<String, dynamic> player2Stats = {};

      for (var row in statsRows) {
        final statName = row.querySelector('.stat-name')?.text.trim() ?? '';
        final player1Value = double.tryParse(row
                    .querySelector('.player1-value')
                    ?.text
                    .trim()
                    .replaceAll('%', '') ??
                '0') ??
            0.0;
        final player2Value = double.tryParse(row
                    .querySelector('.player2-value')
                    ?.text
                    .trim()
                    .replaceAll('%', '') ??
                '0') ??
            0.0;

        player1Stats[statName] = player1Value;
        player2Stats[statName] = player2Value;
      }

      return {
        'players': players,
        'score': {'sets': sets},
        'stats': {
          'player1': player1Stats,
          'player2': player2Stats,
        },
      };
    } catch (e) {
      debugPrint('解析HTML失败: $e');
      return _getMockMatchStats();
    }
  }

  // 获取模拟比赛统计数据（当API调用失败时使用）
  static Map<String, dynamic> _getMockMatchStats() {
    return {
      'players': [
        {'name': 'Ashleigh Barty', 'country': 'Australia'},
        {'name': 'Iga Swiatek', 'country': 'Poland'},
      ],
      'score': {
        'sets': [
          {'player1': 7, 'player2': 5},
          {'player1': 0, 'player2': 1},
          {'player1': 2, 'player2': 5},
        ],
      },
      'stats': {
        'player1': {
          'firstServePercentage': 52.0,
          'pointsWonPercentage': 61.0,
          'firstServePointsWonPercentage': 52.0,
          'secondServePointsWonPercentage': 32.0,
        },
        'player2': {
          'firstServePercentage': 67.0,
          'pointsWonPercentage': 42.0,
          'firstServePointsWonPercentage': 24.0,
          'secondServePointsWonPercentage': 36.0,
        },
      },
    };
  }

// 从US Open网站获取WTA球员详细信息
  static Future<Map<String, dynamic>> getWTAPlayerDetailsFromUSOpen(
      String playerId, String playername) async {
    try {
      // 获取当前年份
      final currentYear = DateTime.now().year;

      // 构建完整URL
      final String playerUrl =
          'https://www.usopen.org/en_US/scores/feeds/$currentYear/players/details/wta$playerId.json';
      debugPrint('US Open WTA球员详情URL: $playerUrl');

      // 使用HeadlessInAppWebView获取JSON数据
      final jsonString = await _getUSOpenJsonWithWebView(playerUrl);

      if (jsonString.isNotEmpty) {
        final Map<String, dynamic> data = json.decode(jsonString);
        debugPrint('成功获取US Open WTA球员数据');

        // 将US Open数据格式转换为与现有格式一致
        Map<String, dynamic> playerData = {
          'Name': '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}',
          'SglRank': data['rank']?['current_singles']?.toString() ?? '0',
          'SglRankMove': '0', // US Open数据中没有这个字段
          'PlayHand': {'Description': data['plays'] ?? 'Right-Handed'},
          'BackHand': {'Description': 'Two-Handed'}, // US Open数据中没有这个字段
          'Age': _calculateAge(data['birth']?['date']),
          'WeightLb': '-',
          'HeightFt': data['height']?['imperial'] ?? '-',
          'HeightCM': data['height']?['metric'] ?? '',
          'BirthDate': data['birth']?['date'] ?? '',
          'BirthCity': data['birth']?['place'] ?? '',
          'ProYear': data['turned_pro']?.toString() ?? '0',
          'Nationality': data['nation']?['code'] ?? '',
          'Coach': '-', // US Open数据中没有这个字段
          'SglYtdWon': data['results']?['year']?['matches_won'] ?? 0,
          'SglYtdLost': data['results']?['year']?['matches_lost'] ?? 0,
          'SglYtdTitles': '0', // US Open数据中没有这个字段
          'SglCareerWon': data['results']?['career']?['matches_won'] ?? 0,
          'SglCareerLost': data['results']?['career']?['matches_lost'] ?? 0,
          'SglCareerTitles':
              data['results']?['career']?['singles_titles']?.toString() ?? '0',
          'SglHiRank': data['rank']?['high_singles']?.toString() ?? '0',
          'SglHiRankDate':
              data['rank']?['high_singles_date'] ?? DateTime.now().toString(),
          'SglYtdPrizeFormatted':
              data['results']?['year']?['singles_prize_money'] ?? '0',
          'CareerPrizeFormatted':
              data['results']?['career']?['prize_money'] ?? '0',
          'PlayerType': 'WTA',
          'ImageUrl':
              'https://wtafiles.blob.core.windows.net/images/headshots/' +
                  playerId.toString() +
                  '.jpg', // 假设的图片URL格式
          'FlagUrl': 'https://www.atptour.com/-/media/images/flags/' +
              (data['nation']?['code']?.toLowerCase() ?? 'xxx') +
              '.svg', // 假设的国旗URL格式
        };

        return playerData;
      } else {
        throw Exception('获取US Open WTA球员数据失败: JSON数据为空');
      }
    } catch (e) {
      debugPrint('获取US Open WTA球员数据异常: $e');
      // 返回默认数据结构
      return {
        'Name': '',
        'SglRank': '0',
        'SglRankMove': '0',
        'PlayHand': {'Description': 'Right-Handed'},
        'BackHand': {'Description': 'Two-Handed'},
        'Age': '0',
        'WeightLb': '0',
        'HeightFt': '',
        'BirthDate': '',
        'BirthCity': '',
        'ProYear': '0',
        'Nationality': '',
        'Coach': '',
        'SglYtdWon': 0,
        'SglYtdLost': 0,
        'SglYtdTitles': '0',
        'SglCareerWon': 0,
        'SglCareerLost': 0,
        'SglCareerTitles': '0',
        'SglHiRank': '0',
        'SglHiRankDate': DateTime.now().toString(),
        'SglYtdPrizeFormatted': '0',
        'CareerPrizeFormatted': '0',
        'PlayerType': 'WTA',
        'ImageUrl': '',
        'FlagUrl': '',
      };
    }
  }

  // 根据生日计算年龄
  static String _calculateAge(String? birthDateStr) {
    if (birthDateStr == null || birthDateStr.isEmpty) {
      return '0';
    }

    try {
      DateTime birthDate;
      // 尝试解析不同格式的日期
      try {
        // 首先尝试解析ISO格式日期 (如 "2007-04-29")
        birthDate = DateTime.parse(birthDateStr);
      } catch (e) {
        try {
          // 尝试解析格式如 "29 April 2007"
          final parts = birthDateStr.split(' ');
          if (parts.length < 3) return '0';

          final day = int.tryParse(parts[0]) ?? 1;
          final month = _getMonthNumber(parts[1]);
          final year = int.tryParse(parts[2]) ?? 2000;

          birthDate = DateTime(year, month, day);
        } catch (e2) {
          debugPrint('无法解析日期格式: $birthDateStr, 错误: $e2');
          return '0';
        }
      }

      final today = DateTime.now();

      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }

      return age.toString();
    } catch (e) {
      debugPrint('计算年龄出错: $e');
      return '0';
    }
  }

  // 将月份名称转换为数字
  static int _getMonthNumber(String monthName) {
    const months = {
      'January': 1,
      'February': 2,
      'March': 3,
      'April': 4,
      'May': 5,
      'June': 6,
      'July': 7,
      'August': 8,
      'September': 9,
      'October': 10,
      'November': 11,
      'December': 12
    };

    return months[monthName] ?? 1;
  }

  // 获取WTA球员排名
  // 获取WTA球员排名 - 使用HeadlessInAppWebView
  Future<List<dynamic>> getWTAPlayerRankings() async {
    debugPrint('使用HeadlessInAppWebView获取WTA球员排名数据...');

    try {
      final data = await _getWTAPlayerRankingsWithWebView();
      if (data.isNotEmpty) {
        debugPrint('WebView成功获取WTA排名数据，数量: ${data.length}');
        return data;
      } else {
        debugPrint('WebView未获取到WTA数据，尝试备用方案');
        return await _fallbackGetWTAPlayerRankings();
      }
    } catch (e) {
      debugPrint('WebView获取WTA排名数据失败: $e，尝试备用方案');
      return await _fallbackGetWTAPlayerRankings();
    }
  }

  // 使用HeadlessInAppWebView获取WTA排名数据
  Future<List<dynamic>> _getWTAPlayerRankingsWithWebView() async {
    final completer = Completer<List<dynamic>>();
    HeadlessInAppWebView? headlessWebView;

    try {
      String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String apiUrl =
          'https://api.wtatennis.com/tennis/players/ranked?metric=SINGLES&type=PointsSingles&sort=desc&at=$currentDate&pageSize=200';

      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(apiUrl)),
        initialSettings: InAppWebViewSettings(
          userAgent:
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          javaScriptEnabled: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          clearCache: false,
        ),
        onWebViewCreated: (controller) {
          debugPrint('WTA HeadlessInAppWebView创建成功');
        },
        onLoadStart: (controller, url) {
          debugPrint('开始加载WTA页面: $url');
        },
        onLoadStop: (controller, url) async {
          debugPrint('WTA页面加载完成: $url');

          try {
            // 等待页面完全渲染
            await Future.delayed(const Duration(seconds: 2));

            // 直接解析页面内容获取WTA排名数据
            final jsCode = '''
              (function() {
                try {
                  console.log('开始解析WTA页面排名数据...');
                  
                  // 检查页面是否已经包含JSON数据
                  const bodyText = document.body.textContent || document.body.innerText;
                  console.log('WTA页面内容长度:', bodyText.length);
                  
                  // 尝试解析JSON数据
                  try {
                    const data = JSON.parse(bodyText);
                    if (Array.isArray(data) && data.length > 0) {
                      console.log('成功解析WTA JSON数据，数量:', data.length);
                      
                      // 将WTA数据格式转换为与ATP相同的格式
                      const formattedData = data.map((item) => {
                        return {
                          'PlayerId': item.player?.id?.toString() || '',
                          'Name': item.player?.fullName || '',
                          'FirstName': item.player?.firstName || '',
                          'LastName': item.player?.lastName || '',
                          'CountryCode': item.player?.countryCode || '',
                          'RankNo': item.ranking || 0,
                          'Points': item.points?.toString() || '0',
                          'Movement': item.movement || 0,
                          'UrlHeadshotImage': 'https://wtafiles.blob.core.windows.net/images/headshots/' + (item.player?.id?.toString() || '') + '.jpg',
                          'UrlCountryFlag': 'https://www.wtatennis.com/resources/v6.41.0/i/elements/flags/' + (item.player?.countryCode?.toLowerCase() || '') + '.svg'
                        };
                      });
                      
                      return formattedData;
                    }
                  } catch (e) {
                    console.log('WTA页面内容不是JSON格式');
                  }
                  
                  console.log('无法解析WTA数据');
                  return null;
                } catch (e) {
                  console.error('WTA JavaScript解析错误:', e);
                  return null;
                }
              })()
            ''';

            final result = await controller.evaluateJavascript(source: jsCode);
            debugPrint('WTA JavaScript执行结果: $result');
            debugPrint('WTA JavaScript执行结果类型: ${result.runtimeType}');

            if (result != null) {
              try {
                List<dynamic> rankingData;
                if (result is List) {
                  rankingData = result.cast<dynamic>();
                } else if (result is String && result.isNotEmpty) {
                  try {
                    rankingData = json.decode(result);
                  } catch (e) {
                    debugPrint('WTA JSON解析失败: $e, 原始数据: $result');
                    completer.complete([]);
                    return;
                  }
                } else {
                  debugPrint('WTA未知的结果格式: $result (${result.runtimeType})');
                  completer.complete([]);
                  return;
                }

                if (rankingData.isNotEmpty) {
                  debugPrint('成功解析WTA排名数据，数量: ${rankingData.length}');
                  completer.complete(rankingData);
                } else {
                  debugPrint('WTA排名数据为空');
                  completer.complete([]);
                }
              } catch (e) {
                debugPrint('解析WTA排名数据失败: $e');
                completer.complete([]);
              }
            } else {
              debugPrint('WTA JavaScript返回null，尝试重新获取');
              // 等待更长时间后重试
              await Future.delayed(const Duration(seconds: 3));
              try {
                final retryResult =
                    await controller.evaluateJavascript(source: jsCode);
                debugPrint('WTA重试结果: $retryResult');
                if (retryResult != null &&
                    retryResult is List &&
                    retryResult.isNotEmpty) {
                  completer.complete(retryResult.cast<dynamic>());
                } else {
                  completer.complete([]);
                }
              } catch (e) {
                debugPrint('WTA重试失败: $e');
                completer.complete([]);
              }
            }
          } catch (e) {
            debugPrint('执行WTA JavaScript时出错: $e');
            completer.complete([]);
          }
        },
        onReceivedError: (controller, request, error) {
          debugPrint('WTA WebView加载错误: ${error.description}');
          if (!completer.isCompleted) {
            completer.complete([]);
          }
        },
        onReceivedHttpError: (controller, request, errorResponse) {
          debugPrint('WTA HTTP错误: ${errorResponse.statusCode}');
          if (!completer.isCompleted) {
            completer.complete([]);
          }
        },
      );

      await headlessWebView.run();

      // 设置超时
      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('WTA WebView请求超时');
          return <dynamic>[];
        },
      );

      return result;
    } catch (e) {
      debugPrint('WTA HeadlessInAppWebView异常: $e');
      return [];
    } finally {
      try {
        await headlessWebView?.dispose();
        debugPrint('WTA HeadlessInAppWebView已释放');
      } catch (e) {
        debugPrint('释放WTA WebView时出错: $e');
      }
    }
  }

  // WTA备用方案：原有的HTTP请求方法
  Future<List<dynamic>> _fallbackGetWTAPlayerRankings() async {
    debugPrint('WTA备用方案获取球员排名数据');

    try {
      String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String endpoint =
          '/tennis/players/ranked?metric=SINGLES&type=PointsSingles&sort=desc&at=$currentDate&pageSize=200';

      final Uri uri = _buildUri(endpoint, 'wta');
      debugPrint('getWTAPlayerRankings uri: $uri');
      final response = await HttpService.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // 将WTA数据格式转换为与ATP相同的格式
        final List<dynamic> formattedData = data.map((item) {
          return {
            'PlayerId': item['player']['id'].toString(),
            'Name': item['player']['fullName'],
            'FirstName': item['player']['firstName'],
            'LastName': item['player']['lastName'],
            'CountryCode': item['player']['countryCode'],
            'RankNo': item['ranking'],
            'Points': item['points'].toString(),
            'Movement': item['movement'],
            'UrlHeadshotImage':
                'https://wtafiles.blob.core.windows.net/images/headshots/${item['player']['id'].toString()}.jpg',
            'UrlCountryFlag':
                'https://www.wtatennis.com/resources/v6.41.0/i/elements/flags/${item['player']['countryCode'].toLowerCase()}.svg',
          };
        }).toList();

        return formattedData;
      } else {
        debugPrint('WTA备用方案获取排名数据失败，状态码: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('WTA备用方案排名数据请求失败: $e');
      return [];
    }
  }
}
