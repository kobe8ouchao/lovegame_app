import 'dart:async';
import 'dart:convert';

import 'package:LoveGame/pages/settings_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
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
    'https://images.unsplash.com/photo-1465125672495-63cdc2fa22ed?q=80&w=2940&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
    'https://images.unsplash.com/photo-1545151414-8a948e1ea54f?q=80&w=3087&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
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

  Future<void> _loadWTA() async {
    try {
      // 获取当前日期的WTA赛事
      final tournaments = await getCurrentWTATournaments(selectedDate);

      if (tournaments.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      List<Map<String, dynamic>> wtaMatches = [];
      debugPrint('tou>>>>>>rnamet ${tournaments.length}');
      // 遍历所有赛事，获取比赛数据
      for (var tournament in tournaments) {
        try {
          var wtaMatchesByDate0 =
              await ApiService.getWTAMatches(tournament, selectedDate);
          wtaMatches.addAll(wtaMatchesByDate0);
          debugPrint('wtaMatchesByDate0 ===== ${wtaMatchesByDate0.length}');
        } catch (e) {
          debugPrint('获取WTA比赛数据失败: $e');
        }
      }
      // 转换为Map<String, dynamic>
      Map<String, dynamic> wtaMatchesByDate = {_selectedDateStr: wtaMatches};
      setState(() {
        _displayedWTAMatches = wtaMatchesByDate[_selectedDateStr] ?? [];
      });
    } catch (e) {
      print('获取WTA赛事时出错: $e');
      return;
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

    // 加载WTA数据
    _loadWTA().then((_) {
      // 加载完WTA数据后再更新显示
      _updateDisplayedMatches();
      setState(() {
        _isLoading = false; // 加载完成后，关闭加载指示器
      });
    }).catchError((error) {
      debugPrint('加载WTA数据出错: $error');
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

  // 加载实时比赛数据
  Future<void> _loadCompletedMatches() async {
    setState(() {
      _isLoadingCompleted = true;
    });

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
          final matchesData = await ApiService.getATPMatchesResultData(
              url['ScoresUrl'], url['Name']);
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

      debugPrint(' _loadCompletedMatches $_selectedDateStr');
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
              'player1Rank': match['player1Rank'] ?? '', // ATP数据中可能没有排名信息
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
              'isPlayer1Winner': match['isPlayer1Winner'], // 添加获胜者标识
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
        _isLoading = false;
        _errorMessage = '加载比赛数据失败';
        print('Error loading ATP matches: $e');
      });
    }
  }

  // 模拟初始加载

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

                                        debugPrint('item ===== :$match');
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
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      MatchDetailsPage(
                                                    matchId:
                                                        match['matchId'] ?? '',
                                                    tournamentId:
                                                        match['tournamentId'] ??
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
                                                    // 添加传入的比分数据，支持5盘
                                                    inputSetScores: {
                                                      'player1': match[
                                                              'player1SetScores'] ??
                                                          [],
                                                      'player2': match[
                                                              'player2SetScores'] ??
                                                          []
                                                    },
                                                    player1Id:
                                                        match['player1Id'] ??
                                                            '',
                                                    player2Id:
                                                        match['player2Id'] ??
                                                            '',
                                                  ),
                                                ),
                                              );
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
