import 'dart:async';
import 'dart:convert';

import 'package:LoveGame/pages/gs_match_detail_page.dart';
import 'package:LoveGame/pages/settings_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/tennis_calendar.dart';
import '../components/glass_icon_button.dart';
import '../components/tennis_score_card.dart';
import '../services/api_service.dart';
import 'match_details_page.dart';
import '../utils/privacy_utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime selectedDate = DateTime.now(); // 使用当前日期
  // 使用固定的示例日期
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _matches = [];
  // 分别存储直播和已完成的比赛
  List<Map<String, dynamic>> _liveMatches = [];
  Map<String, List<Map<String, dynamic>>> _completedMatchesByDate = {};
  List<Map<String, dynamic>> _displayedCompletedMatches = [];
  bool _isLoadingLive = false;
  bool _isLoadingCompleted = false;
  bool _isLoading = false;
  bool _noMoreData = false;
  bool _isRefreshing = false;
  bool _isLoadingScheduled = false;
  Map<String, List<Map<String, dynamic>>> _scheduledMatchesByDate = {};
  List<Map<String, dynamic>> _displayedScheduledMatches = [];
  List<Map<String, dynamic>> _displayedWTAMatches = [];
  final String _tournamentLocation = '';
  String _errorMessage = '';
  String _selectedDateStr = '';
  List<Map<String, dynamic>> _currentTournaments = [];
  List<String> imageBanners = [
    'https://images.unsplash.com/photo-1568060835183-1ab3240b1008?q=80&w=2064&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1751275061697-0f3aede33696?q=80&w=1740&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1545151414-8a948e1ea54f?q=80&w=3087&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1595435934249-5df7ed86e1c0?q=80&w=1920&auto=format&fit=crop',
  ];
  int _currentImageIndex = 0;
  Timer? _autoSlideTimer;
  @override
  void initState() {
    super.initState();
    final formatter = DateFormat('E, dd MMMM, yyyy');
    setState(() {
      _selectedDateStr = formatter.format(DateTime.now());
    });
    _loadData();

    _scrollController.addListener(_onScroll);
    _startImageAutoSlide();
    // 检查隐私政策
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPrivacyPolicy();
    });
  }

  void _startImageAutoSlide() {
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (imageBanners.isNotEmpty && mounted) {
        setState(() {
          _currentImageIndex = (_currentImageIndex + 1) % imageBanners.length;
        });
      }
    });
  }

  // 检查隐私政策
  Future<void> _checkPrivacyPolicy() async {
    final accepted = await PrivacyUtils.showPrivacyDialog(context);
    if (!accepted) {
      // 如果用户拒绝，可以选择退出应用
      SystemNavigator.pop();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _autoSlideTimer?.cancel();
    super.dispose();
  }

  // 根据日期获取正在举行的WTA赛事
  Future<List<Map<String, dynamic>>> getCurrentWTATournaments(
      DateTime date) async {
    List<Map<String, dynamic>> currentTournaments = [];
    try {
      // 加载WTA赛事数据
      final String jsonString =
          await rootBundle.loadString('assets/2025_wta_tournament.json');
      final Map<String, dynamic> tournamentData = json.decode(jsonString);

      if (tournamentData.containsKey('content')) {
        final List<dynamic> tournaments = tournamentData['content'];

        for (var tournament in tournaments) {
          // 解析比赛的开始和结束日期
          final startDate = DateTime.parse(tournament['startDate']);
          final endDate = DateTime.parse(tournament['endDate']);

          // 检查选择的日期是否在比赛日期范围内
          if (date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              date.isBefore(endDate.add(const Duration(days: 1)))) {
            currentTournaments.add(tournament);
          }
        }
      }

      return currentTournaments;
    } catch (e) {
      debugPrint('获取WTA赛事时出错: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _findCurrentTournamentsScoresUrls() async {
    List<String> scoresUrls = [];
    try {
      // 加载本地比赛数据
      final tournamentData = await ApiService.loadLocalTournamentData();

      final DateTime now = selectedDate; // 使用选择的日期而不是当前日期

      _currentTournaments = [];

      if (tournamentData.containsKey('TournamentDates')) {
        for (var dateGroup in tournamentData['TournamentDates']) {
          for (var tournament in dateGroup['Tournaments']) {
            // 解析比赛的开始和结束日期
            final startDate = DateTime.parse(tournament['startDate']);
            final endDate = DateTime.parse(tournament['endDate']);

            // 检查选择的日期是否在比赛日期范围内
            if (now.isAfter(startDate.subtract(const Duration(days: 1))) &&
                now.isBefore(endDate.add(const Duration(days: 1)))) {
              _currentTournaments.add(tournament);
              if (tournament.containsKey('ScoresUrl')) {
                scoresUrls.add(tournament['ScoresUrl']);
              }
            }
          }
        }
      }
      debugPrint('找到的比赛URL: $scoresUrls');
      return _currentTournaments;
    } catch (e) {
      debugPrint('查找当前比赛URL时出错: $e');
      return [];
    }
  }

  Future<void> _saveWTAMatchesToLocalStorage(
      String dateKey, List<Map<String, dynamic>> matches) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataString = json.encode(matches);
      await prefs.setString('wta_matches_$dateKey', dataString);

      // 设置数据过期时间（例如7天后过期）
      final expirationTime = DateTime.now().add(const Duration(days: 7));
      await prefs.setString(
          'wta_matches_${dateKey}_expiry', expirationTime.toIso8601String());

      debugPrint('WTA比赛数据已保存到本地存储: $dateKey');
    } catch (e) {
      debugPrint('保存WTA数据到本地存储失败: $e');
    }
  }

  // 从本地存储获取WTA比赛数据
  Future<List<Map<String, dynamic>>?> _getWTAMatchesFromLocalStorage(
      String dateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDataString = prefs.getString('wta_matches_$dateKey');

      if (cachedDataString != null) {
        final List<dynamic> cachedList = json.decode(cachedDataString);
        return cachedList.cast<Map<String, dynamic>>();
      }

      return null;
    } catch (e) {
      debugPrint('从本地存储获取WTA数据失败: $e');
      return null;
    }
  }

  Future<void> _loadWTA() async {
    try {
      // 获取今天的日期（只保留年月日）
      final today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final selectedDay =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

      // 如果不是今天日期且是过去日期，尝试从本地存储获取数据
      if (selectedDay.isBefore(today)) {
        debugPrint('检查本地存储的WTA比赛数据: $_selectedDateStr');

        // 尝试从本地存储获取数据
        final cachedData =
            await _getWTAMatchesFromLocalStorage(_selectedDateStr);

        if (cachedData != null && cachedData.isNotEmpty) {
          debugPrint('从本地存储获取到WTA数据，数量: ${cachedData.length}');

          // 将本地存储的数据转换为应用所需的格式
          List<Map<String, dynamic>> formattedMatches = [];
          for (var match in cachedData) {
            // WTA数据格式转换
            formattedMatches.add({
              'player1': match['player1'] ?? '',
              'player2': match['player2'] ?? '',
              'player1Rank': match['player1Rank'] ?? '',
              'player2Rank': match['player2Rank'] ?? '',
              'player1Country': match['player1Country'] ?? '',
              'player2Country': match['player2Country'] ?? '',
              'player1FlagUrl': match['player1FlagUrl'] ?? '',
              'player2FlagUrl': match['player2FlagUrl'] ?? '',
              'player2ImageUrl': match['player2ImageUrl'] ?? '',
              'player1ImageUrl': match['player1ImageUrl'] ?? '',
              'serving1': match['serving1'] ?? false,
              'serving2': match['serving2'] ?? false,
              'roundInfo': match['roundInfo'] ?? '',
              'stadium': match['stadium'] ?? '',
              'matchTime': match['matchTime'] ?? '',
              'player1SetScores': match['player1SetScores'] ?? [],
              'player2SetScores': match['player2SetScores'] ?? [],
              'player1TiebreakScores': match['player1TiebreakScores'] ?? [],
              'player2TiebreakScores': match['player2TiebreakScores'] ?? [],
              'currentGameScore1': match['currentGameScore1'] ?? '',
              'currentGameScore2': match['currentGameScore2'] ?? '',
              'isPlayer1Winner': match['isPlayer1Winner'] ?? false,
              'isPlayer2Winner': match['isPlayer2Winner'] ?? false,
              'matchType': match['matchType'] ?? 'completed',
              'tournamentName': match['tournamentName'] ?? '',
              'matchId': match['matchId'] ?? '',
              'tournamentId': match['tournamentId'] ?? '',
              'year': match['year'] ?? '',
              'typePlayer': match['typePlayer'] ?? 'wta',
              'player1Id': match['player1Id'] ?? '',
              'player2Id': match['player2Id'] ?? '',
              'isLive': match['isLive'] ?? false,
              'matchDuration': match['matchDuration'] ?? '',
            });
          }

          setState(() {
            _displayedWTAMatches = formattedMatches;
          });

          return;
        } else {
          debugPrint('本地存储无WTA数据，开始网络请求');
        }
      }

      // 如果是今天或者本地存储没有数据，进行网络请求
      await _loadWTAFromNetwork();
    } catch (e) {
      print('获取WTA赛事时出错: $e');
      setState(() {
        _displayedWTAMatches = [];
      });
    }
  }

// 从网络加载WTA比赛数据（原有逻辑）
  Future<void> _loadWTAFromNetwork() async {
    try {
      // 获取当前日期的WTA赛事
      final tournaments = await getCurrentWTATournaments(selectedDate);

      if (tournaments.isEmpty) {
        setState(() {
          _displayedWTAMatches = [];
        });
        return;
      }

      List<Map<String, dynamic>> wtaMatches = [];
      debugPrint('tournament数量: ${tournaments.length}');

      // 遍历所有赛事，获取比赛数据
      for (var tournament in tournaments) {
        try {
          var wtaMatchesByDate0 =
              await ApiService.getWTAMatches(tournament, selectedDate);
          wtaMatches.addAll(wtaMatchesByDate0);
          debugPrint('wtaMatchesByDate0数量: ${wtaMatchesByDate0.length}');
        } catch (e) {
          debugPrint('获取WTA比赛数据失败: $e');
        }
      }

      // 保存数据到本地存储（只保存过去日期的数据）
      final today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final selectedDay =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

      if (selectedDay.isBefore(today) && wtaMatches.isNotEmpty) {
        await _saveWTAMatchesToLocalStorage(_selectedDateStr, wtaMatches);
      }

      setState(() {
        _displayedWTAMatches = wtaMatches;
      });
    } catch (e) {
      print('获取WTA赛事时出错: $e');
      setState(() {
        _displayedWTAMatches = [];
      });
    }
  }

  void _onScroll() {
    // if (_scrollController.position.pixels >=
    //         _scrollController.position.maxScrollExtent - 200 &&
    //     !_isLoading &&
    //     !_noMoreData) {
    //   _loadMoreMatches();
    // }
  }

  // 加载所有数据
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 并行加载各类比赛数据
      await Future.wait([
        _loadLiveMatches(),
        _loadCompletedMatches(),
        _loadScheduledMatches(),
        _loadWTA(),
      ]);

      // 统一更新显示
      _updateDisplayedMatches();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '加载比赛数据失败: $e';
        print('Error loading match data: $e');
      });
    }
  }

  // 加载计划比赛数据
  Future<void> _loadScheduledMatches() async {
    setState(() {
      _isLoadingScheduled = true; // 假设您有这个状态变量，如果没有需要添加
    });

    try {
      // 使用选择的日期调用API获取计划比赛
      final scheduledMatches =
          await ApiService.getScheduelTournamentMatches(selectedDate);

      setState(() {
        _scheduledMatchesByDate = scheduledMatches; // 假设您有这个状态变量，如果没有需要添加
        _isLoadingScheduled = false;

        // 更新显示的比赛列表
        _updateDisplayedScheduledMatches();
      });
    } catch (e) {
      setState(() {
        _isLoadingScheduled = false;
        _errorMessage = '加载计划比赛数据失败';
        print('Error loading scheduled matches: $e');
      });
    }
  }

  // 更新显示的计划比赛
  void _updateDisplayedScheduledMatches() {
    setState(() {
      _displayedScheduledMatches =
          _scheduledMatchesByDate[_selectedDateStr] ?? [];

      // 更新_matches列表，确保包含最新的所有类型比赛
      _matches.clear();
      if (_liveMatches.isNotEmpty) {
        _matches.addAll(_liveMatches); // 先添加直播比赛
      }
      if (_displayedScheduledMatches.isNotEmpty) {
        _matches.addAll(_displayedScheduledMatches); // 添加计划比赛
      }
      if (_displayedCompletedMatches.isNotEmpty) {
        _matches.addAll(_displayedCompletedMatches); // 再添加已完成比赛
      }
    });
  }

  // 日期选择回调
  void _onDateSelected(DateTime date) {
    // 将日期转换为与API返回格式相匹配的字符串
    final formatter = DateFormat('E, dd MMMM, yyyy');
    final dateStr = formatter.format(date);

    setState(() {
      selectedDate = date;
      _selectedDateStr = dateStr;
      _isLoading = true; // 设置加载状态为true，显示加载指示器
      _matches.clear(); // 清空当前比赛列表，避免显示旧数据
    });

    // 滚动到顶部，让用户看到刷新状态
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // 获取今天的日期（只保留年月日，不考虑时间）
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final selectedDay = DateTime(date.year, date.month, date.day);

    // 获取昨天和明天的日期
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    // 根据选择的日期决定加载哪些数据
    List<Future<void>> loadingTasks = [];

    if (selectedDay.isBefore(today)) {
      // 如果选择的日期小于今天，加载已完成比赛和WTA数据
      debugPrint('加载过去日期的数据：已完成比赛 + WTA');
      loadingTasks.add(_loadCompletedMatches());
      loadingTasks.add(_loadWTA());
    } else if (selectedDay.isAfter(today)) {
      // 如果选择的日期大于今天，加载计划比赛和WTA数据
      debugPrint('加载未来日期的数据：计划比赛 + WTA');
      loadingTasks.add(_loadScheduledMatches());
      loadingTasks.add(_loadWTA());
    } else if (selectedDay.isAtSameMomentAs(today)) {
      // 如果选择的是今天，加载所有类型的数据
      debugPrint('加载今天的数据：所有类型比赛');
      loadingTasks.add(_loadLiveMatches());
      loadingTasks.add(_loadCompletedMatches());
      loadingTasks.add(_loadScheduledMatches());
      loadingTasks.add(_loadWTA());
    } else {
      // 备用情况，只加载WTA数据
      debugPrint('加载备用数据：仅WTA');
      loadingTasks.add(_loadWTA());
    }

    // 执行选定的加载任务
    Future.wait(loadingTasks).then((_) {
      // 所有数据加载完成后更新显示
      _updateDisplayedMatches();
      setState(() {
        _isLoading = false; // 加载完成后，关闭加载指示器
      });
    }).catchError((error) {
      debugPrint('加载数据出错: $error');
      setState(() {
        _isLoading = false;
        _errorMessage = '加载比赛数据失败: $error';
      });
    });
  }

  // 加载实时比赛数据
  Future<void> _loadLiveMatches() async {
    setState(() {
      _isLoadingLive = true;
    });

    try {
      // 查找当前日期的比赛URL
      final liveTournamentIds = await _findCurrentTournamentsLiveIds();
      if (liveTournamentIds.isEmpty) {
        setState(() {
          _liveMatches = [];
          _isLoadingLive = false;
        });
        return;
      }

      // 获取直播比赛数据
      List<Map<String, dynamic>> allLiveMatches = [];
      for (String tournamentId in liveTournamentIds) {
        try {
          final liveMatches =
              await ApiService.getLiveTournamentData(tournamentId);
          allLiveMatches
              .addAll(ApiService.parseMatchesData(liveMatches, tournamentId));
        } catch (e) {
          print('获取直播比赛数据失败，tournamentId: $tournamentId, 错误: $e');
        }
      }

      setState(() {
        _liveMatches = allLiveMatches;
        _isLoadingLive = false;
        // 更新_matches列表，确保包含最新的直播比赛
        _updateDisplayedMatches();
      });
    } catch (e) {
      setState(() {
        _isLoadingLive = false;
        _errorMessage = '加载直播比赛数据失败';
        print('加载直播比赛数据错误: $e');
      });
    }
  }

  // 查找当前比赛的直播ID
  Future<List<String>> _findCurrentTournamentsLiveIds() async {
    List<String> liveIds = [];
    try {
      // 如果_currentTournaments为空，先加载当前比赛
      if (_currentTournaments.isEmpty) {
        final tournamentData = await ApiService.loadLocalTournamentData();
        final DateTime now = selectedDate;

        if (tournamentData.containsKey('TournamentDates')) {
          for (var dateGroup in tournamentData['TournamentDates']) {
            for (var tournament in dateGroup['Tournaments']) {
              // 解析比赛的开始和结束日期
              final startDate = DateTime.parse(tournament['startDate']);
              final endDate = DateTime.parse(tournament['endDate']);

              // 检查选择的日期是否在比赛日期范围内
              if (now.isAfter(startDate.subtract(const Duration(days: 1))) &&
                  now.isBefore(endDate.add(const Duration(days: 1)))) {
                _currentTournaments.add(tournament);
              }
            }
          }
        }
      }

      // 从当前比赛中提取直播ID
      for (var tournament in _currentTournaments) {
        if (tournament.containsKey('Id')) {
          liveIds.add(tournament['Id'].toString());
        }
      }

      debugPrint('找到的直播比赛ID: $liveIds');
      return liveIds;
    } catch (e) {
      debugPrint('查找当前比赛直播ID时出错: $e');
      return [];
    }
  }

  // 优化后的加载已完成比赛数据方法
  Future<void> _loadCompletedMatches() async {
    setState(() {
      _isLoadingCompleted = true;
    });

    try {
      // 获取今天的日期（只保留年月日）
      final today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final selectedDay =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

      // 如果不是今天日期且是过去日期，尝试从本地存储获取数据
      if (selectedDay.isBefore(today)) {
        debugPrint('检查本地存储的已完成比赛数据: $_selectedDateStr');

        // 尝试从本地存储获取数据
        final cachedData =
            await _getCompletedMatchesFromLocalStorage(_selectedDateStr);

        if (cachedData != null && cachedData.isNotEmpty) {
          debugPrint('从本地存储获取到数据，数量: ${cachedData.length}');

          // 将本地存储的数据转换为应用所需的格式
          _matches.clear();
          for (var match in cachedData) {
            final player1SetScores =
                match['player1SetScores'] as List<dynamic>? ?? [];
            final player2SetScores =
                match['player2SetScores'] as List<dynamic>? ?? [];
            final player1TiebreakScores =
                match['player1TiebreakScores'] as List<dynamic>? ?? [];
            final player2TiebreakScores =
                match['player2TiebreakScores'] as List<dynamic>? ?? [];

            // 将本地数据转换为应用所需的格式
            _matches.add({
              'player1': match['player1'] ?? '',
              'player2': match['player2'] ?? '',
              'player1Rank': match['player1Rank'] ?? '',
              'player2Rank': match['player2Rank'] ?? '',
              'player1Country': match['player1Country'] ?? '',
              'player2Country': match['player2Country'] ?? '',
              'player1FlagUrl': match['player1FlagUrl'] ?? '',
              'player2FlagUrl': match['player2FlagUrl'] ?? '',
              'player2ImageUrl': match['player2ImageUrl'] ?? '',
              'player1ImageUrl': match['player1ImageUrl'] ?? '',
              'serving1': false,
              'serving2': false,
              'roundInfo': match['roundInfo'] ?? '',
              'stadium': match['stadium'] ?? '',
              'matchTime': match['matchTime'] ?? '',
              'player1SetScores': player1SetScores,
              'player2SetScores': player2SetScores,
              'player1TiebreakScores': player1TiebreakScores,
              'player2TiebreakScores': player2TiebreakScores,
              'currentGameScore1': '',
              'currentGameScore2': '',
              'isPlayer1Winner': match['isPlayer1Winner'] ?? false,
              'isPlayer2Winner': match['isPlayer2Winner'] ?? false,
              'matchType': 'completed',
              'tournamentName': match['tournamentName'] ?? '',
              'matchId': match['matchId'] ?? '',
              'tournamentId': match['tournamentId'] ?? '',
              'year': match['year'] ?? '',
            });
          }

          setState(() {
            _completedMatchesByDate = {_selectedDateStr: cachedData};
            _displayedCompletedMatches = _matches;
            _isLoadingCompleted = false;
            _noMoreData = false;
          });

          // 更新显示的比赛列表
          return;
        } else {
          debugPrint('本地存储无数据，开始网络请求');
        }
      }

      // 如果是今天或者本地存储没有数据，进行网络请求
      await _loadCompletedMatchesFromNetwork();
    } catch (e) {
      setState(() {
        _isLoadingCompleted = false;
        _errorMessage = '加载已完成比赛数据失败';
        print('Error loading completed matches: $e');
      });
    }
  }

// 从本地存储获取已完成比赛数据
  Future<List<Map<String, dynamic>>?> _getCompletedMatchesFromLocalStorage(
      String dateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDataString = prefs.getString('completed_matches_$dateKey');

      if (cachedDataString != null) {
        final List<dynamic> cachedList = json.decode(cachedDataString);
        return cachedList.cast<Map<String, dynamic>>();
      }

      return null;
    } catch (e) {
      debugPrint('从本地存储获取数据失败: $e');
      return null;
    }
  }

// 保存已完成比赛数据到本地存储
  Future<void> _saveCompletedMatchesToLocalStorage(
      String dateKey, List<Map<String, dynamic>> matches) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataString = json.encode(matches);
      await prefs.setString('completed_matches_$dateKey', dataString);

      // 可选：设置数据过期时间（例如7天后过期）
      final expirationTime = DateTime.now().add(const Duration(days: 7));
      await prefs.setString('completed_matches_${dateKey}_expiry',
          expirationTime.toIso8601String());

      debugPrint('已完成比赛数据已保存到本地存储: $dateKey');
    } catch (e) {
      debugPrint('保存数据到本地存储失败: $e');
    }
  }

// 检查本地存储数据是否过期
  Future<bool> _isLocalDataExpired(String dateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryString =
          prefs.getString('completed_matches_${dateKey}_expiry');

      if (expiryString != null) {
        final expiryTime = DateTime.parse(expiryString);
        return DateTime.now().isAfter(expiryTime);
      }

      return true; // 如果没有过期时间，认为已过期
    } catch (e) {
      debugPrint('检查数据过期时间失败: $e');
      return true;
    }
  }

// 从网络加载已完成比赛数据（原有逻辑）
  Future<void> _loadCompletedMatchesFromNetwork() async {
    try {
      // 查找当前日期的比赛URL
      final scoresUrls = await _findCurrentTournamentsScoresUrls();
      debugPrint('找到的比赛URL: $scoresUrls');

      if (scoresUrls.isEmpty) {
        // 如果没有找到比赛URL，使用默认URL
        _completedMatchesByDate = {};
      } else {
        // 如果找到了比赛URL，依次获取每个比赛的数据并合并
        _completedMatchesByDate = {};

        for (var url in scoresUrls) {
          Map<String, List<Map<String, dynamic>>> matchesData = {};
          if (url['Type'] == 'GS') {
            final year = selectedDate.year.toString();
            if (url['Name'] == 'US Open') {
              matchesData = await ApiService.getUSOpenMatchesResultData(
                  year, url['Name']);
            }
          } else {
            matchesData = await ApiService.getATPMatchesResultData(
                url['ScoresUrl'], url['Name']);
          }
          // 合并数据
          imageBanners.add(url['TournamentImage']);
          imageBanners.add(url['tournamentImage2']);
          matchesData.forEach((date, matches) {
            if (_completedMatchesByDate.containsKey(date)) {
              _completedMatchesByDate[date]!.addAll(matches);
            } else {
              _completedMatchesByDate[date] = matches;
            }
          });
        }
      }

      debugPrint('网络请求完成: $_selectedDateStr');

      // 保存数据到本地存储（只保存过去日期的数据）
      final today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final selectedDay =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

      if (selectedDay.isBefore(today) &&
          _completedMatchesByDate.containsKey(_selectedDateStr)) {
        debugPrint('保存数据到本地存储: $_selectedDateStr');
        await _saveCompletedMatchesToLocalStorage(
            _selectedDateStr, _completedMatchesByDate[_selectedDateStr]!);
      }

      setState(() {
        _matches.clear();
        if (_completedMatchesByDate.isEmpty) {
          _errorMessage = 'No matches result';
          _noMoreData = true;
        } else {
          // 将ATP比赛数据转换为应用所需的格式
          for (var match in _completedMatchesByDate[_selectedDateStr] ?? []) {
            final player1SetScores =
                match['player1SetScores'] as List<dynamic>? ?? [];
            final player2SetScores =
                match['player2SetScores'] as List<dynamic>? ?? [];
            final player1TiebreakScores =
                match['player1TiebreakScores'] as List<dynamic>? ?? [];
            final player2TiebreakScores =
                match['player2TiebreakScores'] as List<dynamic>? ?? [];

            final set1Scores = player1SetScores;
            final set2Scores = player2SetScores;

            // 将ATP比赛数据转换为应用所需的格式
            _matches.add({
              'player1': match['player1'] ?? '',
              'player2': match['player2'] ?? '',
              'player1Rank': match['player1Rank'] ?? '',
              'player2Rank': match['player2Rank'] ?? '',
              'player1Country': match['player1Country'] ?? '',
              'player2Country': match['player2Country'] ?? '',
              'player1FlagUrl': match['player1FlagUrl'] ?? '',
              'player2FlagUrl': match['player2FlagUrl'] ?? '',
              'player2ImageUrl': match['player2ImageUrl'] ?? '',
              'player1ImageUrl': match['player1ImageUrl'] ?? '',
              'serving1': false,
              'serving2': false,
              'roundInfo': match['roundInfo'] ?? '',
              'stadium': match['stadium'] ?? '',
              'matchTime': match['matchTime'] ?? '',
              'player1SetScores': set1Scores,
              'player2SetScores': set2Scores,
              'player1TiebreakScores': player1TiebreakScores,
              'player2TiebreakScores': player2TiebreakScores,
              'currentGameScore1': '',
              'currentGameScore2': '',
              'isPlayer1Winner': match['isPlayer1Winner'],
              'isPlayer2Winner': match['isPlayer2Winner'],
              'matchType': 'completed',
              'tournamentName': match['tournamentName'] ?? '',
              'matchId': match['matchId'] ?? '',
              'tournamentId': match['tournamentId'] ?? '',
              'year': match['year'] ?? '',
            });
          }
          _noMoreData = false;
        }
        _displayedCompletedMatches = _matches;
        _isLoadingCompleted = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCompleted = false;
        _errorMessage = '加载比赛数据失败';
        print('Error loading ATP matches: $e');
      });
    }
  }

// 清理过期的本地存储数据（可在应用启动时调用）
  Future<void> _cleanupExpiredLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (String key in keys) {
        if (key.startsWith('completed_matches_') && key.endsWith('_expiry')) {
          final dataKey = key.replaceAll('_expiry', '');
          final isExpired = await _isLocalDataExpired(
              dataKey.replaceAll('completed_matches_', ''));

          if (isExpired) {
            await prefs.remove(dataKey);
            await prefs.remove(key);
            debugPrint('清理过期数据: $dataKey');
          }
        }
      }
    } catch (e) {
      debugPrint('清理过期数据失败: $e');
    }
  }

  // 模拟加载更多
  Future<void> _loadMoreMatches() async {
    if (_isLoading || _noMoreData) return;

    setState(() {
      _isLoading = false;
    });
  }

  void _updateDisplayedMatches() {
    setState(() {
      _matches.clear();
      // 获取今天的日期（只保留年月日，不考虑时间）
      final today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);

      // 直接使用selectedDate变量，它已经是DateTime类型
      final selectedDay =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

      // 1. 只有当选择的日期是今天时，才添加直播比赛（优先级最高）
      if (selectedDay.isAtSameMomentAs(today) && _liveMatches.isNotEmpty) {
        _matches.addAll(_liveMatches);
      }
      List<Map<String, dynamic>> wtaLiveMatches = [];
      List<Map<String, dynamic>> wtaOtherMatches = [];
      for (var match in _displayedWTAMatches) {
        if (match['matchType'] == 'Live') {
          wtaLiveMatches.add(match);
        } else {
          wtaOtherMatches.add(match);
        }
      }
      if (wtaLiveMatches.isNotEmpty) {
        _matches.addAll(wtaLiveMatches);
      }

      // 2. 再添加计划比赛（优先级次之）
      if (selectedDay.isAtSameMomentAs(today) || selectedDay.isAfter(today)) {
        final scheduledMatches =
            _scheduledMatchesByDate[_selectedDateStr] ?? [];
        if (scheduledMatches.isNotEmpty) {
          _displayedScheduledMatches = scheduledMatches;
          _matches.addAll(_displayedScheduledMatches);
        } else {
          _displayedScheduledMatches = [];
        }
      }

      // 3. 最后添加已完成比赛（优先级最低）
      final completedMatches = _completedMatchesByDate[_selectedDateStr] ?? [];
      debugPrint(
          ' _updateDisplayedMatches $_selectedDateStr----${completedMatches.length}');

      if (completedMatches.isNotEmpty) {
        _displayedCompletedMatches = completedMatches;
        _matches.addAll(_displayedCompletedMatches);
      } else {
        _displayedCompletedMatches = [];
      }
      for (var i = 0; i < _matches.length; i++) {
        if (_liveMatches.contains(_matches[i])) {
          _matches[i]['matchType'] = 'Live';
        } else if (_displayedScheduledMatches.contains(_matches[i])) {
          _matches[i]['matchType'] = 'Scheduled';
        } else {
          _matches[i]['matchType'] = 'Completed';
        }
      }
      if (wtaOtherMatches.isNotEmpty) {
        _matches.addAll(wtaOtherMatches);
      }
    });
  }

  bool _showRefreshComplete = false;

  // 模拟刷新
  Future<void> _onRefresh() async {
    debugPrint('>>>>>_onRefresh');
    setState(() {
      _isRefreshing = true;
    });
    await _loadData();
    setState(() {
      _isRefreshing = false;
      _showRefreshComplete = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showRefreshComplete = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black, // 设置背景色为黑色，确保底部过渡平滑

        body: Stack(
          children: [
            // 背景图片容器
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height / 3.5 +
                  120, // 高度增加到300，底部部分会被圆角裁剪
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                child: Stack(
                  children: [
                    // 背景图片
                    SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: imageBanners.isNotEmpty
                          ? AnimatedSwitcher(
                              duration: const Duration(milliseconds: 800),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              child: CachedNetworkImage(
                                key: ValueKey<String>(
                                    imageBanners[_currentImageIndex]),
                                imageUrl: imageBanners[_currentImageIndex],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error),
                              ),
                            )
                          : Image.network(
                              'https://images.unsplash.com/photo-1595435934249-5df7ed86e1c0?q=80&w=1920&auto=format&fit=crop',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.black,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              Colors.white),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.black,
                                  child: Center(
                                    child: Icon(
                                      Icons.error_outline,
                                      color:
                                          Theme.of(context).colorScheme.error,
                                      size: 48,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    // 渐变遮罩
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.1),
                              Colors.black.withOpacity(0.4),
                              Colors.black.withOpacity(0.5),
                            ],
                            stops: const [0.0, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // 在背景图片底部添加日历组件
                    Positioned(
                      bottom: 10, //
                      left: 0,
                      right: 0,
                      child: TennisCalendar(
                        selectedDate: selectedDate,
                        onDateSelected: (date) {
                          _onDateSelected(date);
                          // final formatter = DateFormat('E, d MMMM, yyyy');
                          // setState(() {
                          //   selectedDate = date;
                          //   _selectedDateStr = formatter.format(date);
                          // });
                          // 重新加载该日期的比赛
                          // _onRefresh();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 主要内容
            SafeArea(
                child: Column(
              children: [
                // 顶部栏
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tennis',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GlassIconButton(
                        icon: Icons.settings,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(height: MediaQuery.of(context).size.height / 3.5 + 20),

                // 比赛列表
                Expanded(
                  child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black,
                      ),
                      margin: const EdgeInsets.only(top: 0),
                      child: RefreshIndicator(
                        onRefresh: _onRefresh,
                        color: Colors.white,
                        backgroundColor: Colors.black,
                        child: Column(
                          children: [
                            // 刷新完成提示
                            AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: _showRefreshComplete ? 30 : 0,
                                color: Colors.transparent,
                                child: Center(
                                  child: _showRefreshComplete
                                      ? const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Color(0xFF94E831),
                                              size: 16,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Completed Refeshed',
                                              style: TextStyle(
                                                color: Color(0xFF94E831),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        )
                                      : null,
                                )),
                            // 原有的列表内容
                            Expanded(
                              child: _matches.isEmpty && !_isLoading
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SvgPicture.asset(
                                            'assets/svg/icon_no_match.svg',
                                            width: 56,
                                            height: 56,
                                            colorFilter: const ColorFilter.mode(
                                                Color.fromARGB(
                                                    64, 255, 255, 255),
                                                BlendMode.srcIn),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            _errorMessage.isNotEmpty
                                                ? _errorMessage
                                                : 'No matches ',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 0.5,
                                              ),
                                            ),
                                            child: ElevatedButton(
                                              onPressed: _onRefresh,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.black,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 30,
                                                        vertical: 0),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text(
                                                'Refresh',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w400,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      controller: _scrollController,
                                      physics:
                                          const AlwaysScrollableScrollPhysics(
                                        parent: BouncingScrollPhysics(),
                                      ),
                                      itemCount: _matches.length + 1,
                                      itemBuilder: (context, index) {
                                        if (index == _matches.length) {
                                          return Container(
                                            padding: const EdgeInsets.all(16.0),
                                            alignment: Alignment.center,
                                            child: _isLoading
                                                ? const CupertinoActivityIndicator(
                                                    radius: 16.0,
                                                    color: Color(0xFF94E831),
                                                  )
                                                : _noMoreData
                                                    ? const Text(
                                                        'No more match',
                                                        style: TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 14.0,
                                                        ),
                                                      )
                                                    : const SizedBox.shrink(),
                                          );
                                        }
                                        final match = _matches[index];
                                        // 安全检查：确保访问数组元素前先检查数组是否为空

                                        // debugPrint('item ===== :$match');
                                        return TennisScoreCard(
                                          player1: match['player1'] ?? '',
                                          player2: match['player2'] ?? '',
                                          player1Rank:
                                              match['player1Rank'] ?? '',
                                          player2Rank:
                                              match['player2Rank'] ?? '',
                                          player1Country:
                                              match['player1Country'] ?? '',
                                          player2Country:
                                              match['player2Country'] ?? '',
                                          player2FlagUrl:
                                              match['player2FlagUrl'] ?? '',
                                          player1FlagUrl:
                                              match['player1FlagUrl'] ?? '',
                                          player1ImageUrl:
                                              match['player1ImageUrl'] ?? '',
                                          player2ImageUrl:
                                              match['player2ImageUrl'] ?? '',
                                          serving1: match['serving1'] ?? false,
                                          serving2: match['serving2'] ?? false,
                                          roundInfo: match['roundInfo'] ?? '',
                                          set1Scores: List<int>.from(
                                              match['player1SetScores'] ?? []),
                                          set2Scores: List<int>.from(
                                              match['player2SetScores'] ?? []),
                                          tiebreak1: List<int>.from(
                                              match['player1TiebreakScores'] ??
                                                  []),
                                          tiebreak2: List<int>.from(
                                              match['player2TiebreakScores'] ??
                                                  []),
                                          currentGameScore1:
                                              match['currentGameScore1'] ?? '',
                                          currentGameScore2:
                                              match['currentGameScore2'] ?? '',
                                          isLive: match['isLive'] ?? false,
                                          matchDuration:
                                              match['matchDuration'] ?? '',
                                          isPlayer1Winner:
                                              match['isPlayer1Winner'] ?? false,
                                          isPlayer2Winner:
                                              match['isPlayer2Winner'] ?? false,
                                          matchType:
                                              match['matchType'] ?? false,
                                          stadium: match['stadium'] ?? '',
                                          matchTime: match['matchTime'] ?? '',
                                          tournamentName:
                                              match['tournamentName'] ?? '',
                                          player1Id: match['player1Id'] ?? '',
                                          player2Id: match['player2Id'] ?? '',
                                          typePlayer:
                                              match['typePlayer'] ?? 'atp',
                                          onWatchPressed: () async {
                                            final Uri url = Uri.parse(
                                                'https://www.haixing.cc/live?type=5');
                                            if (!await launchUrl(url)) {
                                              throw Exception('无法打开 $url');
                                            }
                                          },
                                          onDetailPressed: () {
                                            if (match['matchType'] ==
                                                'Scheduled') {
                                              // 使用SnackBar提示比赛未开始
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '${match['player1']} vs ${match['player2']} match has not started yet',
                                                    style: const TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                  backgroundColor:
                                                      const Color(0xFF333333),
                                                  duration: const Duration(
                                                      seconds: 2),
                                                ),
                                              );
                                            } else {
                                              final gs = match['GS']
                                                      ?.toString()
                                                      .toLowerCase() ??
                                                  '';
                                              if (gs.isNotEmpty) {
                                                // Navigate to GS match details page
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        GSMatchDetailsPage(
                                                      matchId:
                                                          match['matchId'] ??
                                                              '',
                                                      tournamentId: match[
                                                              'tournamentId'] ??
                                                          '',
                                                      year: match['year'] ?? '',
                                                      player1ImageUrl: match[
                                                              'player1ImageUrl'] ??
                                                          '',
                                                      player2ImageUrl: match[
                                                              'player2ImageUrl'] ??
                                                          '',
                                                      player1FlagUrl: match[
                                                              'player1FlagUrl'] ??
                                                          '',
                                                      player2FlagUrl: match[
                                                              'player2FlagUrl'] ??
                                                          '',
                                                      typeMatch:
                                                          match['typePlayer'] ??
                                                              'atp',
                                                      inputSetScores: {
                                                        'player1': (match[
                                                                        'player1SetScores']
                                                                    as List<
                                                                        dynamic>?)
                                                                ?.cast<int>() ??
                                                            [],
                                                        'player2': (match[
                                                                        'player2SetScores']
                                                                    as List<
                                                                        dynamic>?)
                                                                ?.cast<int>() ??
                                                            []
                                                      },
                                                      player1Id:
                                                          match['player1Id'] ??
                                                              '',
                                                      player2Id:
                                                          match['player2Id'] ??
                                                              '',
                                                      gs: gs,
                                                    ),
                                                  ),
                                                );
                                              } else {
                                                // Navigate to regular match details page
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        MatchDetailsPage(
                                                      matchId:
                                                          match['matchId'] ??
                                                              '',
                                                      tournamentId: match[
                                                              'tournamentId'] ??
                                                          '',
                                                      year: match['year'] ?? '',
                                                      player1ImageUrl: match[
                                                              'player1ImageUrl'] ??
                                                          '',
                                                      player2ImageUrl: match[
                                                              'player2ImageUrl'] ??
                                                          '',
                                                      player1FlagUrl: match[
                                                              'player1FlagUrl'] ??
                                                          '',
                                                      player2FlagUrl: match[
                                                              'player2FlagUrl'] ??
                                                          '',
                                                      typeMatch:
                                                          match['typePlayer'] ??
                                                              'atp',
                                                      inputSetScores: {
                                                        'player1': (match[
                                                                        'player1SetScores']
                                                                    as List<
                                                                        dynamic>?)
                                                                ?.cast<int>() ??
                                                            [],
                                                        'player2': (match[
                                                                        'player2SetScores']
                                                                    as List<
                                                                        dynamic>?)
                                                                ?.cast<int>() ??
                                                            []
                                                      },
                                                      player1Id:
                                                          match['player1Id'] ??
                                                              '',
                                                      player2Id:
                                                          match['player2Id'] ??
                                                              '',
                                                      gs: gs,
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        );
                                      }),
                            ),
                          ],
                        ),
                      )),
                ),
              ],
            )),
          ],
        ));
  }
}
