/*
 * @Descripttion: 
 * @Author: ouchao
 * @Email: ouchao@sendpalm.com
 * @version: 1.0
 * @Date: 2025-04-21 17:22:17
 * @LastEditors: ouchao
 * @LastEditTime: 2025-05-15 16:05:24
 */
import 'package:LoveGame/utils/timezone_mapping.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:html/dom.dart' as dom;

class ApiService {
  static const String _baseUrl = 'https://www.atptour.com';
  static const List<String> _proxyUrls = [
    // 'https://api.allorigins.win/raw?url=',
    // 'https://cors-anywhere.herokuapp.com/',
    // 'https://cors.sh/?url=',
    'https://thingproxy.freeboard.io/fetch/',
    // 'https://cors.io/?'
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
        fullUrls = 'https://api.wtatennis.com$endpoint';
      }

      try {
        return Uri.parse(_currentProxyUrl + Uri.encodeComponent(fullUrls));
      } catch (e) {
        _rotateProxy(); // 如果当前代理有问题，轮换到下一个
        return Uri.parse(_currentProxyUrl + Uri.encodeComponent(fullUrls));
      }
    } else {
      // 移动平台直接请求
      debugPrint('wta&&&&&&&&$type');
      if (type == 'wta') {
        fullUrls = 'https://api.wtatennis.com$endpoint';
      }
      return Uri.parse(_currentProxyUrl + Uri.encodeComponent(fullUrls));
    }
  }

  // 获取ATP赛事日历数据
  static Future<Map<String, dynamic>> getTournamentCalendar() async {
    try {
      final String endpoint = '/en/-/tournaments/calendar/tour';
      final Uri uri = _buildUri(endpoint, '');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 10));

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
        final String scheduleUrl = tournament['ScheduleUrl'];
        final Uri uri = _buildUri(scheduleUrl, '');

        final response = await http.get(
          uri,
          headers: {
            'Accept': 'text/html',
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        );
        debugPrint('schedule!!!!!${response.statusCode}');
        if (response.statusCode == 200) {
          final document = parse(response.body);

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
                String timePrefix = "";
                if (displayTime.contains("Starts At")) {
                  timePrefix = "Starts At ";
                } else if (displayTime.contains("Not Before")) {
                  timePrefix = "Not Before ";
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
                adjustedDisplayTime = "$timePrefix$formattedTime";

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
              if (spans.length > 0) {
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

            // 获取名字 (a标签内容)
            final player1NameLinks = player1Element.getElementsByTagName('a');
            if (player1NameLinks.isNotEmpty) {
              player1Name = player1NameLinks.first.text
                  .trim()
                  .replaceAll(RegExp(r'[\r\n]+'), '');
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

            // 获取名字 (a标签内容)
            final player2NameLinks = player2Element.getElementsByTagName('a');
            if (player2NameLinks.isNotEmpty) {
              player2Name = player2NameLinks.first.text
                  .trim()
                  .replaceAll(RegExp(r'[\r\n]+'), '');
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
            };
            // 添加到对应日期的比赛列表
            matchesByDate[dateStr]!.add(matchData);
          }
        } else {
          debugPrint('获取比赛数据失败: ${response.statusCode}');
        }
      }

      return matchesByDate;
    } catch (e) {
      debugPrint('解析比赛数据异常: $e');
      return matchesByDate;
    }
  }

  // 获取特定比赛的实时数据
  static Future<Map<String, dynamic>> getLiveTournamentData(
      String tournamentId) async {
    try {
      final String endpoint = '/en/-/www/LiveMatches/2025/$tournamentId';
      final Uri uri = _buildUri(endpoint, "");

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 10));
      debugPrint('getLiveTournamentData!!!!!!!!!!!${response.statusCode}');
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to get live tournament data: $e');
      rethrow;
    }
  }

  // 解析比赛数据为应用内部格式
  static List<Map<String, dynamic>> parseMatchesData(
      Map<String, dynamic> apiData, String tId) {
    List<Map<String, dynamic>> matches = [];
    debugPrint('parseMatchesData!!!!!!!!!!!$apiData');
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
                  playerTeam['Seed'] != null ? '(${playerTeam['Seed']})' : '',
              'player2Rank': opponentTeam['Seed'] != null
                  ? '(${opponentTeam['Seed']})'
                  : '',
              'player1Country': player1['PlayerCountry'] ?? '',
              'player2Country': player2['PlayerCountry'] ?? '',
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
          scores.add(set['SetScore']);
        }
        // } else {
        //   scores.add(0);
        // }
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
          tiebreakScores.add(set['TieBreakScore']);
        }
        // } else {
        //   tiebreakScores.add(0);
        // }
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

  // 获取ATP球员排名
  Future<List<dynamic>> getPlayerRankings() async {
    try {
      const String endpoint = '/en/-/www/rank/sglroll/250?v=1';
      final Uri uri = _buildUri(endpoint, '');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        print('获取排名失败: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('获取排名异常: $e');
      // 如果API调用失败，返回空列表
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

  static Future<Map<String, List<Map<String, dynamic>>>>
      getATPMatchesResultData(String? scoresUrl, String? name) async {
    Map<String, List<Map<String, dynamic>>> matchesByDate = {};
    try {
      final String? endpoint = scoresUrl;
      final Uri uri = _buildUri(endpoint!, '');
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );
      debugPrint('getATPMatchesResultData!!!!!!!!!!!${response.statusCode}');
      if (response.statusCode == 200) {
        final document = parse(response.body);
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
            String VarmatchId = "";
            String VartournamentId = "";
            String Varyear = "";
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
      }
    } catch (e) {
      print('Error fetching ATP matches============: $e');
    }

    return matchesByDate;
  }

  // 获取球员详情数据
  static Future<Map<String, dynamic>> getPlayerDetails(String playerId) async {
    try {
      final String endpoint = '/en/-/www/players/hero/$playerId?v=1';
      final Uri uri = _buildUri(endpoint, '');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('获取球员数据失败: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('获取球员详情异常: $e');
      // 如果API调用失败，尝试加载本地数据
      return loadLocalPlayerData();
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

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 10));

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

// 获取WTA球员排名
  Future<List<dynamic>> getWTAPlayerRankings() async {
    try {
      String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String endpoint =
          '/tennis/players/ranked?metric=SINGLES&type=PointsSingles&sort=desc&at=$currentDate&pageSize=200';

      final Uri uri = _buildUri(endpoint, 'wta');
      debugPrint('getWTAPlayerRankings uri: $uri');
      final response = await http.get(
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
                'https://wtafiles.blob.core.windows.net/images/headshots/${item['player']['id'].toString()}.jpg', // WTA API没有提供头像URL
            'UrlCountryFlag':
                'https://www.wtatennis.com/resources/v6.41.0/i/elements/flags/${item['player']['countryCode'].toLowerCase()}.svg', // WTA API没有提供国旗URL
          };
        }).toList();

        return formattedData;
      } else {
        throw Exception('Failed to load WTA player rankings');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
