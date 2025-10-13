import 'package:LoveGame/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'player_details_page.dart'; // 添加导入球员详情页面

class MatchDetailsPage extends StatefulWidget {
  final Map<String, dynamic>? matchData;
  final String? matchId;
  final String? tournamentId;
  final String? year;
  final String? player1ImageUrl;
  final String? player2ImageUrl;
  final String? player1FlagUrl;
  final String? player2FlagUrl;
  final String? typeMatch;
  // 添加传入的比分参数
  final Map<String, List<int>>? inputSetScores;
  final String? player1Id;
  final String? player2Id;
  final String? gs;

  const MatchDetailsPage({
    super.key,
    this.matchData,
    this.matchId,
    this.tournamentId,
    this.year,
    this.player1ImageUrl,
    this.player2ImageUrl,
    this.player1FlagUrl,
    this.player2FlagUrl,
    this.player1Id,
    this.player2Id,
    this.typeMatch,
    this.inputSetScores,
    this.gs,
  }) : assert(matchData != null ||
            (matchId != null && tournamentId != null && year != null));

  @override
  State<MatchDetailsPage> createState() => _MatchDetailsPageState();
}

class _MatchDetailsPageState extends State<MatchDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String _errorMessage = '';
  Map<String, dynamic>? _matchData;
  int _currentStatsPage = 0;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 如果直接传入了比赛数据，则直接使用
    if (widget.matchData != null) {
      _matchData = widget.matchData;
    } else {
      // 否则从API加载数据
      _loadMatchData();
    }

    // 打印传入的URL参数
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 从API加载比赛数据
  Future<void> _loadMatchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    debugPrint(
        'widget.matchId: ${widget.matchId}, widget.tournamentId: ${widget.tournamentId}, widget.year: ${widget.year}');
    try {
      if (widget.typeMatch == 'wta') {
        final url = widget.matchId ?? '';
        final matchStats = await ApiService.getWTAMatchStats(
            'https://www.wtatennis.com/tournaments/${widget.tournamentId}/strasbourg/${widget.year}/scores/${widget.matchId}',
            widget.tournamentId ?? '',
            widget.matchId ?? '');
        setState(() {
          _matchData = matchStats;
          _isLoading = false;
        });
      } else {
        if (widget.gs == 'usopen') {
          final year = widget.year ?? '2025';
          final matchId = widget.matchId ?? '';
          final url =
              'https://www.usopen.org/en_US/scores/feeds/$year/matches/complete/$matchId.json';

          try {
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              final matchInfo = data['matches'][0];

              // Transform usopen data to the structure expected by the UI
              final formattedData = {
                'Tournament': {
                  'TournamentCity': 'New York',
                  'EventCountry': 'USA',
                  'TournamentName': 'US Open',
                  'TournamentId': widget.tournamentId,
                },
                'Match': {
                  'RoundName': matchInfo['roundName'],
                  'MatchStatus': matchInfo['statusCode'] == 'D' ? 'F' : 'L',
                  'PlayerTeam': {
                    'Player': {
                      'PlayerFirstName': matchInfo['team1']['firstNameA'],
                      'PlayerLastName': matchInfo['team1']['lastNameA'],
                      'PlayerId': matchInfo['team1']['idA'],
                      'PlayerCountry': matchInfo['team1']['nationA'],
                    },
                    'SetScores': _buildSetScores(matchInfo, 1),
                  },
                  'OpponentTeam': {
                    'Player': {
                      'PlayerFirstName': matchInfo['team2']['firstNameA'],
                      'PlayerLastName': matchInfo['team2']['lastNameA'],
                      'PlayerId': matchInfo['team2']['idA'],
                      'PlayerCountry': matchInfo['team2']['nationA'],
                    },
                    'SetScores': _buildSetScores(matchInfo, 2),
                  },
                },
              };

              setState(() {
                _matchData = formattedData;
                _isLoading = false;
              });
            } else {
              setState(() {
                _isLoading = false;
                _errorMessage =
                    'Failed to load data: HTTP ${response.statusCode}';
              });
            }
          } catch (e) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Failed to load data: $e';
            });
          }
        } else {
          final year = widget.year ?? '2025';
          final tournamentId = widget.tournamentId ?? '1536';
          final matchId = widget.matchId ?? 'ms011';

          final url =
              'https://www.atptour.com/-/Hawkeye/MatchStats/$year/$tournamentId/$matchId';
          try {
            final response = await http.get(Uri.parse(url));

            if (response.statusCode == 200) {
              final data = json.decode(response.body);

              setState(() {
                _matchData = data;
                _isLoading = false;
              });
            } else {
              setState(() {
                _isLoading = false;
                _errorMessage = '加载失败: HTTP ${response.statusCode}';
              });
            }
          } catch (e) {
            debugPrint('HTTP request failed: $e');
            // 如果是SSL证书问题，尝试使用代理或其他方法
            if (e.toString().contains('CERTIFICATE_VERIFY_FAILED')) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'SSL证书验证失败，请检查网络连接';
              });
            } else {
              setState(() {
                _isLoading = false;
                _errorMessage = '加载失败: $e';
              });
            }
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '加载失败: $e';
      });
    }
  }

  List<Map<String, dynamic>> _buildSetScores(
      Map<String, dynamic> matchInfo, int team) {
    List<Map<String, dynamic>> setScores = [];
    final scores = matchInfo['scores']['sets'];
    final stats = matchInfo['base_stats'];

    // Overall stats
    Map<String, dynamic> overallStats = {};
    if (stats != null && stats['match'] != null) {
      final teamStats = stats['match']['team_$team'];
      overallStats = {
        'Aces': teamStats['t_ace'],
        'DoubleFaults': teamStats['df'],
        'FirstServeIn': teamStats['t_f_srv_in'],
        'FirstServeTotal': teamStats['t_f_srv'],
        'FirstServeWon': teamStats['t_f_srv_w'],
        'SecondServeWon': teamStats['t_s_srv_w'],
        'SecondServeTotal': teamStats['t_s_srv'],
        'BreakPointsWon': teamStats['t_bp_w'],
        'BreakPointsTotal': teamStats['t_bp'],
        'TotalPointsWon': teamStats['t_p_w_opp_srv'],
      };
    }
    setScores.add({'Stats': overallStats});

    for (int i = 0; i < scores.length; i++) {
      final set = scores[i];
      final teamIndex = team - 1;
      Map<String, dynamic> setStat = {};
      if (stats != null && stats['set_${i + 1}'] != null) {
        final teamSetStats = stats['set_${i + 1}']['team_$team'];
        setStat = {
          'Aces': teamSetStats['t_ace'],
          'DoubleFaults': teamSetStats['df'],
          'FirstServeIn': teamSetStats['t_f_srv_in'],
          'FirstServeTotal': teamSetStats['t_f_srv'],
          'FirstServeWon': teamSetStats['t_f_srv_w'],
          'SecondServeWon': teamSetStats['t_s_srv_w'],
          'SecondServeTotal': teamSetStats['t_s_srv'],
          'BreakPointsWon': teamSetStats['t_bp_w'],
          'BreakPointsTotal': teamSetStats['t_bp'],
          'TotalPointsWon': teamSetStats['t_p_w_opp_srv'],
        };
      }
      setScores.add({
        'SetScore': int.tryParse(set[teamIndex]['score'] ?? '0'),
        'TieBreakScore': int.tryParse(set[teamIndex]['tiebreak'] ?? '0'),
        'Stats': setStat,
      });
    }

    return setScores;
  }

  String _formatPlayerName(String name) {
    // 如果名称超过16个字符，按空格分隔，取第一个元素的第一个字母加空格连接最后一个元素
    if (name.length > 13) {
      List<String> nameParts = name.split(' ');
      if (nameParts.length > 1) {
        String firstName = nameParts.first;
        String lastName = nameParts.last;
        return '${firstName[0]}. $lastName';
      }
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('Match Details'),
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF94E831),
          ),
        ),
      );
    }

    // 显示错误状态
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('Match Details'),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadMatchData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF94E831),
                  foregroundColor: Colors.black,
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final tournament = _matchData!['Tournament'] ?? {};
    final match = _matchData!['Match'] ?? {};
// 如果没有数据
    if (_matchData == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text(
            'Match Detial',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon:
                const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '',
          ),
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'No Match Details',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    // 比赛基本信息
    final location = tournament['TournamentCity'] ?? '';
    final country = tournament['EventCountry'] ?? '';
    final titleName = tournament['TournamentName'] ?? '';
    final RoundName = match['RoundName'] ?? '';
    final isLive = match['MatchStatus'] == 'L'; // 'L'表示直播，'F'表示已完成

    // 球员信息
    final playerTeam = match['PlayerTeam'];
    final opponentTeam = match['OpponentTeam'];
    // 球员1信息
    final player1 = playerTeam['Player'] ?? {};
    final player2 = opponentTeam['Player'] ?? {};
    final player1FirstName = player1['PlayerFirstName'] ?? '';
    final player1LastName = player1['PlayerLastName'] ?? '';
    final player1Id = player1['PlayerId'] ?? '';
    final player2Id = player2['PlayerId'] ?? '';
    String extractedPlayer1Country = '';
    if (widget.player1FlagUrl != null && widget.player1FlagUrl!.isNotEmpty) {
      final uri = Uri.parse(widget.player1FlagUrl!);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last;
        // 移除.svg后缀并转换为大写以匹配国家代码
        extractedPlayer1Country =
            lastSegment.replaceAll('.svg', '').toUpperCase();
      }
    }
    String? player1Country = player1['PlayerCountry'] ?? '';
    String? player2Country = player2['PlayerCountry'] ?? '';
    String? player1ImageUrl = widget.player1ImageUrl;
    String? player1FlagUrl = widget.player1FlagUrl ?? '';
    String? player2ImageUrl = widget.player2ImageUrl;
    String? player2FlagUrl = widget.player2FlagUrl ?? '';
    debugPrint(
        'extractedPlayer1Country: $extractedPlayer1Country player1Country: $player1Country');
    if (extractedPlayer1Country.toLowerCase() ==
        player1Country.toString().toLowerCase()) {
      player1ImageUrl = widget.player1ImageUrl;
      player2ImageUrl = widget.player2ImageUrl;
    } else {
      player1ImageUrl = widget.player2ImageUrl;
      player2ImageUrl = widget.player1ImageUrl;
      player1FlagUrl = widget.player2FlagUrl ?? '';
      player2FlagUrl = widget.player1FlagUrl ?? '';
      player1Country = player2['PlayerCountry'];
      player2Country = player1['PlayerCountry'];
    }

    final player1Sets = playerTeam['SetScores'];
    final player2Sets = opponentTeam['SetScores'];
    if (player1Sets.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('Match Details'),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadMatchData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF94E831),
                  foregroundColor: Colors.black,
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    debugPrint('player1Sets: $player1Sets');
    debugPrint('player2Sets: $player2Sets');
    // 球员2信息

    final player2FirstName = player2['PlayerFirstName'];
    final player2LastName = player2['PlayerLastName'];

    // 获取比赛统计数据
    final player1Stats = player1Sets.isNotEmpty ? player1Sets[0]['Stats'] : {};
    final player2Stats = player2Sets.isNotEmpty ? player2Sets[0]['Stats'] : {};

    final player1SetsStats = player1Sets.isNotEmpty ? player1Sets : [];
    final player2SetsStats = player2Sets.isNotEmpty ? player2Sets : [];
    // 比分数据
    // 获取年度统计数据
    final player1YearStats = playerTeam['YearToDateStats'] ?? {};
    final player2YearStats = opponentTeam['YearToDateStats'] ?? {};

    List<String> player1ScoresList = [];
    List<String> player2ScoresList = [];
    List<String> player1TiebreakList = [];
    List<String> player2TiebreakList = [];

    // 从第1个索引开始，因为索引0是总体统计
    for (int i = 1; i < player1Sets.length; i++) {
      final set1 = player1Sets[i];
      final set2 = player2Sets[i];
      if (set1['SetScore'] != null && set2['SetScore'] != null) {
        player1ScoresList.add(set1['SetScore']?.toString() ?? '0');
        player2ScoresList.add(set2['SetScore']?.toString() ?? '0');
      }
      // 添加抢七比分
      player1TiebreakList.add(set1['TieBreakScore']?.toString() ?? '');
      player2TiebreakList.add(set2['TieBreakScore']?.toString() ?? '');
    }
    // 提取比分
    List<Map<String, String>> setScores = [];

    // 如果有传入的比分且API获取的比分为空，则使用传入的比分
    if (widget.inputSetScores != null && widget.inputSetScores!.isNotEmpty) {
      for (int i = 0; i < widget.inputSetScores!['player1']!.length; i++) {
        if (widget.inputSetScores!['player1']?[i] != 0) {
          debugPrint('player1 ${widget.player1Id} $player1Id ');
          if (widget.player1Id.toString().toLowerCase() ==
              player1Id.toString().toLowerCase()) {
            int score1 = widget.inputSetScores!['player1']![i];
            int score2 = widget.inputSetScores!['player2']![i];
            setScores.add(
                {'player1': score1.toString(), 'player2': score2.toString()});
          } else {
            int score1 = widget.inputSetScores!['player2']![i];
            int score2 = widget.inputSetScores!['player1']![i];
            setScores.add(
                {'player1': score1.toString(), 'player2': score2.toString()});
          }
        }
      }
    } else {
      // 否则使用API获取的比分
      for (int i = 0; i < player1Sets.length; i++) {
        String p1Score = '';
        String p2Score = '';

        if (player1Sets[i]['SetScore'] == null &&
            player2Sets[i]['SetScore'] == null) {
          continue;
        }
        if (player1Sets[i]['SetScore'] != null) {
          p1Score = player1Sets[i]['SetScore'].toString().padLeft(2, '');
        }
        if (player2Sets[i]['SetScore'] != null) {
          p2Score = player2Sets[i]['SetScore'].toString().padLeft(2, '');
        }

        setScores.add({'player1': p1Score, 'player2': p2Score});
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部区域 - 比赛地点和返回按钮
            _buildHeader('Match Detail', isLive),

            // 比分区域
            _buildScoreArea(
                player1Id ?? '',
                player2Id ?? '',
                _formatPlayerName('$player1FirstName $player1LastName'),
                player1Country ?? '',
                player1ImageUrl ?? '', // 添加空值检查
                player1FlagUrl,
                _formatPlayerName('$player2FirstName $player2LastName'),
                player2Country ?? '',
                player2ImageUrl ?? '', // 添加空值检查
                player2FlagUrl,
                setScores,
                player1TiebreakList,
                player2TiebreakList),

            const SizedBox(height: 12),
            // 统计数据区域

            Expanded(
              child: _buildStatsArea(player1Stats, player2Stats,
                  player1SetsStats, player2SetsStats),
            ),

            // 底部导航栏
          ],
        ),
      ),
    );
  }

  // 构建顶部区域
  Widget _buildHeader(String location, bool isLive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 返回按钮
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 比赛地点
          Text(
            location,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          // 直播标签
          if (isLive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 构建比分区域
  Widget _buildScoreArea(
      String player1Id,
      String player2Id,
      String player1Name,
      String player1Country,
      String player1ImageUrl,
      String player1FlagUrl,
      String player2Name,
      String player2Country,
      String player2ImageUrl,
      String player2FlagUrl,
      List<Map<String, String>> setScores,
      List<String> player1TiebreakList, // 明确指定类型为List<String>
      List<String> player2TiebreakList // 明确指定类型为List<String>
      ) {
    // 使用传入的URL或者默认URL
    final p1ImageUrl = player1ImageUrl.isNotEmpty
        ? player1ImageUrl
        : 'https://atptour.com/-/media/alias/player-headshot/default-player-headshot.png';
    final p2ImageUrl = player2ImageUrl.isNotEmpty
        ? player2ImageUrl
        : 'https://atptour.com/-/media/alias/player-headshot/default-player-headshot.png';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 背景图片
            Image.asset(
              'assets/images/madrid.webp',
              width: double.infinity,
              height: 260,
              fit: BoxFit.cover,
            ),
            // 渐变遮罩
            Container(
              width: double.infinity,
              height: 260,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.9),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  // 球员信息和比分
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 球员1
                      Column(
                        children: [
                          // 球员1头像
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  // 导航到球员详情页面
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PlayerDetailsPage(
                                        playerId: player1Id ?? '',
                                        playerName: player1Name,
                                        playerCountry: player1Country,
                                        playerColor: const Color(0xFF94E831),
                                        type: 'atp',
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFF94E831),
                                        width: 2),
                                    image: DecorationImage(
                                      image: NetworkImage(p1ImageUrl),
                                      fit: BoxFit.cover,
                                      onError: (exception, stackTrace) {},
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 球员1名称
                          Text(
                            player1Name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // 球员1国家
                          Row(
                            children: [
                              if (player1FlagUrl.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4.0),
                                  child: SvgPicture.network(
                                    player1FlagUrl,
                                    width: 16,
                                    height: 12,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                      width: 16,
                                      height: 12,
                                      color: Colors.grey.withOpacity(0.3),
                                      child: const Icon(Icons.flag,
                                          size: 8, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              Text(
                                player1Country,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // 比分
                      Column(
                        children: [
                          // 第一盘比分
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 球员1比分区域
                              Container(
                                width: 50,
                                alignment: Alignment.centerRight,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      setScores.isNotEmpty
                                          ? setScores[0]['player1'] ?? '-'
                                          : '-',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    // 显示抢七小分
                                    if (player1TiebreakList.isNotEmpty &&
                                        player1TiebreakList[0].isNotEmpty)
                                      Text(
                                        '(${player1TiebreakList[0]})',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // 分隔符
                              Container(
                                width: 30,
                                alignment: Alignment.center,
                                child: const Text(
                                  '-',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),

                              // 球员2比分区域
                              Container(
                                width: 50,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      setScores.isNotEmpty
                                          ? setScores[0]['player2'] ?? '-'
                                          : '-',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    // 显示抢七小分
                                    if (player2TiebreakList.isNotEmpty &&
                                        player2TiebreakList[0].isNotEmpty)
                                      Text(
                                        '(${player2TiebreakList[0]})',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 第二盘比分
                          if (setScores.length > 1)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 球员1比分区域
                                Container(
                                  width: 50,
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        setScores[1]['player1'] ?? '00',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      // 显示抢七小分
                                      if (player1TiebreakList.length > 1 &&
                                          player1TiebreakList[1].isNotEmpty)
                                        Text(
                                          '(${player1TiebreakList[1]})',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.7),
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // 分隔符
                                Container(
                                  width: 30,
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '-',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),

                                // 球员2比分区域
                                Container(
                                  width: 50,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        setScores[1]['player2'] ?? '01',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      // 显示抢七小分
                                      if (player2TiebreakList.length > 1 &&
                                          player2TiebreakList[1].isNotEmpty)
                                        Text(
                                          '(${player2TiebreakList[1]})',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.7),
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          if (setScores.length > 1) const SizedBox(height: 8),

                          // 第三盘比分
                          if (setScores.length > 2)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 球员1比分区域
                                Container(
                                  width: 50,
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        setScores[2]['player1'] ?? '02',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      // 显示抢七小分
                                      if (player1TiebreakList.length > 2 &&
                                          player1TiebreakList[2].isNotEmpty)
                                        Text(
                                          '(${player1TiebreakList[2]})',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.7),
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // 分隔符
                                Container(
                                  width: 30,
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '-',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),

                                // 球员2比分区域
                                Container(
                                  width: 50,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        setScores[2]['player2'] ?? '05',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      // 显示抢七小分
                                      if (player2TiebreakList.length > 2 &&
                                          player2TiebreakList[2].isNotEmpty)
                                        Text(
                                          '(${player2TiebreakList[2]})',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.7),
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          if (setScores.length > 2) const SizedBox(height: 8),

                          // 添加第四盘比分
                          if (setScores.length > 3)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 球员1比分区域
                                Container(
                                  width: 50,
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        setScores[3]['player1'] ?? '03',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      // 显示抢七小分
                                      if (player1TiebreakList.length > 3 &&
                                          player1TiebreakList[3].isNotEmpty)
                                        Text(
                                          '(${player1TiebreakList[3]})',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.7),
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // 分隔符
                                Container(
                                  width: 30,
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '-',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),

                                // 球员2比分区域
                                Container(
                                  width: 50,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        setScores[3]['player2'] ?? '06',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      // 显示抢七小分
                                      if (player2TiebreakList.length > 3 &&
                                          player2TiebreakList[3].isNotEmpty)
                                        Text(
                                          '(${player2TiebreakList[3]})',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.7),
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          if (setScores.length > 3) const SizedBox(height: 8),

                          // 添加第五盘比分
                          if (setScores.length > 4)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 球员1比分区域
                                Container(
                                  width: 50,
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        setScores[4]['player1'] ?? '04',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      // 显示抢七小分
                                      if (player1TiebreakList.length > 4 &&
                                          player1TiebreakList[4].isNotEmpty)
                                        Text(
                                          '(${player1TiebreakList[4]})',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.7),
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // 分隔符
                                Container(
                                  width: 30,
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '-',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),

                                // 球员2比分区域
                                Container(
                                  width: 50,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        setScores[4]['player2'] ?? '07',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      // 显示抢七小分
                                      if (player2TiebreakList.length > 4 &&
                                          player2TiebreakList[4].isNotEmpty)
                                        Text(
                                          '(${player2TiebreakList[4]})',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.7),
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),

                      // 球员2
                      Column(
                        children: [
                          // 球员2头像
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  // 导航到球员详情页面
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PlayerDetailsPage(
                                        playerId: player2Id ?? '',
                                        playerName: player2Name,
                                        playerCountry: player2Country,
                                        playerColor: const Color(0xFFAA00FF),
                                        type: 'atp',
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFFAA00FF),
                                        width: 2),
                                    image: DecorationImage(
                                      image: NetworkImage(p2ImageUrl),
                                      fit: BoxFit.cover,
                                      onError: (exception, stackTrace) {},
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 球员2名称
                          Text(
                            player2Name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // 球员2国家
                          Row(
                            children: [
                              if (player2FlagUrl.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4.0),
                                  child: SvgPicture.network(
                                    player2FlagUrl,
                                    width: 16,
                                    height: 12,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                      width: 16,
                                      height: 12,
                                      color: Colors.grey.withOpacity(0.3),
                                      child: const Icon(Icons.flag,
                                          size: 8, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              Text(
                                player2Country,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // 构建统计数据区域
  Widget _buildStatsArea(Map player1Stats, Map player2Stats,
      List player1SetsStats, List player2SetsStats) {
    // STATS统计数据
    final serviceStats1 = player1Stats['ServiceStats'] ?? {};
    final serviceStats2 = player2Stats['ServiceStats'] ?? {};
    final returnStats1 = player1Stats['ReturnStats'] ?? {};
    final returnStats2 = player2Stats['ReturnStats'] ?? {};
    final pointStats1 = player1Stats['PointStats'] ?? {};
    final pointStats2 = player2Stats['PointStats'] ?? {};
    //YTD STATS
    final player1YearStats =
        _matchData!['Match']['PlayerTeam']['YearToDateStats'] ?? {};
    final player2YearStats =
        _matchData!['Match']['OpponentTeam']['YearToDateStats'] ?? {};
    final serviceYTDStats1 = player1YearStats['ServiceRecordStats'] ?? {};
    final serviceYTDStats2 = player2YearStats['ServiceRecordStats'] ?? {};
    final returnYTDStats1 = player1YearStats['ReturnRecordStats'] ?? {};
    final returnYTDStats2 = player2YearStats['ReturnRecordStats'] ?? {};

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0D0C),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8, left: 8),
            child: Text(
              _currentStatsPage == 0
                  ? 'Match Stats'
                  : 'Set $_currentStatsPage Stats',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // 统计数据
          Expanded(
            child: PageView(
              onPageChanged: (index) {
                setState(() {
                  _currentStatsPage = index;
                });
              },
              children: [
                // 当前比赛统计
                ListView(padding: const EdgeInsets.all(16), children: [
                  if (widget.typeMatch == 'wta') ...[
                    // WTA比赛统计数据
                    // 发球统计
                    _buildCenteredStatBar(
                      'Aces',
                      serviceStats1['Aces']?['Number'] ?? 0,
                      serviceStats1['Aces']?['Number'] ??
                          0 + serviceStats2['Aces']?['Number'] ??
                          0,
                      serviceStats2['Aces']?['Number'] ?? 0,
                      serviceStats1['Aces']?['Number'] ??
                          0 + serviceStats2['Aces']?['Number'] ??
                          0,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Double Faults',
                      serviceStats1['DoubleFaults']?['Number'] ?? 0,
                      serviceStats1['DoubleFaults']?['Number'] ??
                          0 + serviceStats2['DoubleFaults']?['Number'] ??
                          0,
                      serviceStats2['DoubleFaults']?['Number'] ?? 0,
                      serviceStats1['DoubleFaults']?['Number'] ??
                          0 + serviceStats2['DoubleFaults']?['Number'] ??
                          0,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      '1st Serve %',
                      serviceStats1['1stServe']?['Dividend'] ?? 0,
                      serviceStats1['1stServe']?['Divisor'] ?? 1,
                      serviceStats2['1stServe']?['Dividend'] ?? 0,
                      serviceStats2['1stServe']?['Divisor'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      '1st Serve Points Won',
                      serviceStats1['1stServePointsWon']?['Dividend'] ?? 0,
                      serviceStats1['1stServePointsWon']?['Divisor'] ?? 1,
                      serviceStats2['1stServePointsWon']?['Dividend'] ?? 0,
                      serviceStats2['1stServePointsWon']?['Divisor'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      '2nd Serve Points Won %',
                      serviceStats1['2ndServePointsWon']?['Dividend'] ?? 0,
                      serviceStats1['2ndServePointsWon']?['Divisor'] ?? 1,
                      serviceStats2['2ndServePointsWon']?['Dividend'] ?? 0,
                      serviceStats2['2ndServePointsWon']?['Divisor'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Break Points Faced',
                      serviceStats1['BreakPointsFaced']?['Number:'] ?? 0,
                      1,
                      serviceStats2['BreakPointsFaced']?['Number:'] ?? 0,
                      1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Break Points Saved',
                      serviceStats1['BreakPointsSaved']?['Dividend'] ?? 0,
                      serviceStats1['BreakPointsSaved']?['Divisor'] ?? 1,
                      serviceStats2['BreakPointsSaved']?['Dividend'] ?? 0,
                      serviceStats2['BreakPointsSaved']?['Divisor'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Service Games Played',
                      serviceStats1['ServiceGamesPlayed']?['Number'] ?? 0,
                      serviceStats1['ServiceGamesPlayed']?['Number'] +
                          serviceStats2['ServiceGamesPlayed']?['Number'],
                      serviceStats2['ServiceGamesPlayed']?['Number'] ?? 0,
                      serviceStats1['ServiceGamesPlayed']?['Number'] +
                          serviceStats2['ServiceGamesPlayed']?['Number'],
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      '1st Return Points Won',
                      returnStats1['1stReturnPointsWon']?['Dividend'] ?? 0,
                      returnStats1['1stReturnPointsWon']?['Divisor'] ?? 1,
                      returnStats2['1stReturnPointsWon']?['Dividend'] ?? 0,
                      returnStats2['1stReturnPointsWon']?['Divisor'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      '2st Return Points Won',
                      returnStats1['2ndReturnPointsWon']?['Dividend'] ?? 0,
                      returnStats1['2ndReturnPointsWon']?['Divisor'] ?? 1,
                      returnStats2['2ndReturnPointsWon']?['Dividend'] ?? 0,
                      returnStats2['2ndReturnPointsWon']?['Divisor'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Break Points Converted',
                      returnStats1['BreakPointsConverted']?['Dividend'] ?? 0,
                      returnStats1['BreakPointsConverted']?['Divisor'] ?? 1,
                      returnStats2['BreakPointsConverted']?['Dividend'] ?? 0,
                      returnStats2['BreakPointsConverted']?['Divisor'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Return Games Played',
                      returnStats1['ReturnGamesPlayed']?['Number'] ?? 0,
                      returnStats1['ReturnGamesPlayed']?['Number'] ?? 100,
                      returnStats2['ReturnGamesPlayed']?['Number'] ?? 0,
                      returnStats2['ReturnGamesPlayed']?['Number'] ?? 100,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Total Service Points Won',
                      pointStats1['TotalServicePointsWon']?['Dividend'] ?? 0,
                      pointStats1['TotalServicePointsWon']?['Divisor'] ?? 1,
                      pointStats2['TotalServicePointsWon']?['Dividend'] ?? 0,
                      pointStats2['TotalServicePointsWon']?['Divisor'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Total Return Points Won',
                      pointStats1['TotalReturnPointsWon']?['Dividend'] ?? 0,
                      pointStats1['TotalReturnPointsWon']?['Divisor'] ?? 1,
                      pointStats2['TotalReturnPointsWon']?['Dividend'] ?? 0,
                      pointStats2['TotalReturnPointsWon']?['Divisor'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Total Points Won',
                      pointStats1['TotalPointsWon']?['Dividend'] ?? 0,
                      pointStats1['TotalPointsWon']?['Divisor'] ?? 1,
                      pointStats2['TotalPointsWon']?['Dividend'] ?? 0,
                      pointStats2['TotalPointsWon']?['Divisor'] ?? 1,
                    ),
                  ] else ...[
                    // ATP比赛统计数据
                    // 发球统计
                    _buildCenteredStatBar(
                      'Serve Rating',
                      serviceStats1['ServeRating']?['Number'] ?? 0,
                      1,
                      serviceStats2['ServeRating']?['Number'] ?? 0,
                      1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'ACE',
                      serviceStats1['Aces']?['Number'] ?? 0,
                      (serviceStats1['Aces']?['Number'] ?? 0) +
                          (serviceStats2['Aces']?['Number'] ?? 0),
                      serviceStats2['Aces']?['Number'] ?? 0,
                      (serviceStats1['Aces']?['Number'] ?? 0) +
                          (serviceStats2['Aces']?['Number'] ?? 0),
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Double Faults',
                      serviceStats1['DoubleFaults']?['Number'] ?? 0,
                      (serviceStats1['DoubleFaults']?['Number'] ?? 0) +
                          (serviceStats2['DoubleFaults']?['Number'] ?? 0),
                      serviceStats2['DoubleFaults']?['Number'] ?? 0,
                      (serviceStats1['DoubleFaults']?['Number'] ?? 0) +
                          (serviceStats2['DoubleFaults']?['Number'] ?? 0),
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      '1st Serve Points Won',
                      serviceStats1['FirstServePointsWon']?['Dividend'] ?? 0,
                      serviceStats1['FirstServePointsWon']?['Divisor'] ?? 1,
                      serviceStats2['FirstServePointsWon']?['Dividend'] ?? 0,
                      serviceStats2['FirstServePointsWon']?['Divisor'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      '2nd Serve Points Won',
                      serviceStats1['SecondServePointsWon']?['Dividend'] ?? 0,
                      serviceStats1['SecondServePointsWon']?['Divisor'] ?? 1,
                      serviceStats2['SecondServePointsWon']?['Dividend'] ?? 0,
                      serviceStats2['SecondServePointsWon']?['Divisor'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Break Points Saved',
                      serviceStats1['BreakPointsSaved']?['Dividend'] ?? 0,
                      serviceStats1['BreakPointsSaved']?['Divisor'] ?? 1,
                      serviceStats2['BreakPointsSaved']?['Dividend'] ?? 0,
                      serviceStats2['BreakPointsSaved']?['Divisor'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    // 接发球统计
                    _buildCenteredStatBar(
                      '1st Serve Return Points Won',
                      returnStats1['FirstServeReturnPointsWon']?['Dividend'] ??
                          0,
                      returnStats1['FirstServeReturnPointsWon']?['Divisor'] ??
                          1,
                      returnStats2['FirstServeReturnPointsWon']?['Dividend'] ??
                          0,
                      returnStats2['FirstServeReturnPointsWon']?['Divisor'] ??
                          1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      '2nd Serve Return Points Won',
                      returnStats1['SecondServeReturnPointsWon']?['Dividend'] ??
                          0,
                      returnStats1['SecondServeReturnPointsWon']?['Divisor'] ??
                          1,
                      returnStats2['SecondServeReturnPointsWon']?['Dividend'] ??
                          0,
                      returnStats2['SecondServeReturnPointsWon']?['Divisor'] ??
                          1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Break Points Converted',
                      returnStats1['BreakPointsConverted']?['Dividend'] ?? 0,
                      returnStats1['BreakPointsConverted']?['Divisor'] ?? 1,
                      returnStats2['BreakPointsConverted']?['Dividend'] ?? 0,
                      returnStats2['BreakPointsConverted']?['Divisor'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Return Games Played',
                      returnStats1['ReturnGamesPlayed']?['Number'] ?? 0,
                      1,
                      returnStats2['ReturnGamesPlayed']?['Number'] ?? 0,
                      1,
                    ),
                    const SizedBox(height: 16),
                    // 总体统计
                    _buildCenteredStatBar(
                      'Total Service Points Won',
                      pointStats1['TotalServicePointsWon']?['Dividend'] ?? 0,
                      pointStats1['TotalServicePointsWon']?['Divisor'] ?? 1,
                      pointStats2['TotalServicePointsWon']?['Dividend'] ?? 0,
                      pointStats2['TotalServicePointsWon']?['Divisor'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Total Return Points Won',
                      pointStats1['TotalReturnPointsWon']?['Dividend'] ?? 0,
                      pointStats1['TotalReturnPointsWon']?['Divisor'] ?? 1,
                      pointStats2['TotalReturnPointsWon']?['Dividend'] ?? 0,
                      pointStats2['TotalReturnPointsWon']?['Divisor'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Total Points Won',
                      pointStats1['TotalPointsWon']?['Dividend'] ?? 0,
                      pointStats1['TotalPointsWon']?['Divisor'] ?? 1,
                      pointStats2['TotalPointsWon']?['Dividend'] ?? 0,
                      pointStats2['TotalPointsWon']?['Divisor'] ?? 1,
                    ),
                  ],
                ]),

                for (int i = 1; i < player1SetsStats.length; i++)
                  ListView(padding: const EdgeInsets.all(16), children: [
                    if (widget.typeMatch == 'wta') ...[
                      _buildCenteredStatBar(
                        'Aces',
                        player2SetsStats[i]['Stats']['ServiceStats']['Aces']
                                ?['Number'] ??
                            0,
                        player1SetsStats[i]['Stats']['ServiceStats']['Aces']
                                ?['Number'] ??
                            0 +
                                player2SetsStats[i]['Stats']['ServiceStats']
                                    ['Aces']?['Number'] ??
                            0,
                        player2SetsStats[i]['Stats']['ServiceStats']['Aces']
                                ?['Number'] ??
                            0,
                        player1SetsStats[i]['Stats']['ServiceStats']['Aces']
                                ?['Number'] ??
                            0 +
                                player2SetsStats[i]['ServiceStats']['Stats']
                                    ['Aces']?['Number'] ??
                            0,
                      ),
                      // const SizedBox(height: 16),
                      // _buildCenteredStatBar(
                      //   'Double Faults',
                      //   player1SetsStats[i]['Stats']['DoubleFaults']
                      //           ?['Number'] ??
                      //       0,
                      //   player1SetsStats[i]['Stats']['DoubleFaults']
                      //           ?['Number'] ??
                      //       0 +
                      //           player2SetsStats[i]['Stats']['DoubleFaults']
                      //               ?['Number'] ??
                      //       0,
                      //   player2SetsStats[i]['Stats']['DoubleFaults']
                      //           ?['Number'] ??
                      //       0,
                      //   player2SetsStats[i]['Stats']['DoubleFaults']
                      //           ?['Number'] ??
                      //       0 +
                      //           player2SetsStats[i]['Stats']['DoubleFaults']
                      //               ?['Number'] ??
                      //       0,
                      // ),
                      // const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        '1st Serve %',
                        player1SetsStats[i]['Stats']['ServiceStats']['1stServe']
                                ?['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['ServiceStats']['1stServe']
                                ?['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['ServiceStats']['1stServe']
                                ?['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['ServiceStats']['1stServe']
                                ?['Divisor'] ??
                            1,
                      ),
                      const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        '1st Serve Points Won',
                        player1SetsStats[i]['Stats']['ServiceStats']
                                ['1stServePointsWon']?['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['ServiceStats']
                                ['1stServePointsWon']?['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['1stServePointsWon']?['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['1stServePointsWon']?['Divisor'] ??
                            1,
                      ),
                      const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        '2nd Serve Points Won',
                        player1SetsStats[i]['Stats']['ServiceStats']
                                ['2ndServePointsWon']?['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['ServiceStats']
                                ['2ndServePointsWon']?['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['2ndServePointsWon']?['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['2ndServePointsWon']?['Divisor'] ??
                            1,
                      ),
                      const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        'Break Points Faced',
                        player1SetsStats[i]['Stats']['ServiceStats']
                                ['BreakPointsFaced']?['Number'] ??
                            0,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['BreakPointsFaced']?['Number'] ??
                            1 +
                                player1SetsStats[i]['Stats']['ServiceStats']
                                    ['BreakPointsFaced']?['Number'] ??
                            1,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['BreakPointsFaced']?['Number'] ??
                            0,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['BreakPointsFaced']?['Number'] ??
                            1 +
                                player1SetsStats[i]['Stats']['ServiceStats']
                                    ['BreakPointsFaced']?['Number'] ??
                            1,
                      ),
                      const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        'Break Points Saved',
                        player1SetsStats[i]['Stats']['ServiceStats']
                                ['BreakPointsSaved']?['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['ServiceStats']
                                ['BreakPointsSaved']?['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['BreakPointsSaved']?['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['BreakPointsSaved']?['Divisor'] ??
                            1,
                      ),
                      const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        'Service Games Played',
                        player1SetsStats[i]['Stats']['ServiceStats']
                                ['ServiceGamesPlayed']?['Number'] ??
                            0,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['ServiceGamesPlayed']?['Number'] ??
                            1 +
                                player1SetsStats[i]['Stats']['ServiceStats']
                                    ['ServiceGamesPlayed']?['Number'] ??
                            1,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['ServiceGamesPlayed']?['Number'] ??
                            0,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['ServiceGamesPlayed']?['Number'] ??
                            1 +
                                player1SetsStats[i]['Stats']['ServiceStats']
                                    ['ServiceGamesPlayed']?['Number'] ??
                            1,
                      ),
                      const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        '1st Return Points Won',
                        player1SetsStats[i]['Stats']['ReturnStats']
                                ['1stReturnPointsWon']?['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['ReturnStats']
                                ['1stReturnPointsWon']?['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['ReturnStats']
                                ['1stReturnPointsWon']?['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['ReturnStats']
                                ['1stReturnPointsWon']?['Divisor'] ??
                            1,
                      ),
                      const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        '2nd Return Points Won',
                        player1SetsStats[i]['Stats']['ReturnStats']
                                ['2ndReturnPointsWon']?['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['ReturnStats']
                                ['2ndReturnPointsWon']?['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['ReturnStats']
                                ['2ndReturnPointsWon']?['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['ReturnStats']
                                ['2ndReturnPointsWon']?['Divisor'] ??
                            1,
                      ),
                      const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        'Break Points Converted',
                        player1SetsStats[i]['Stats']['ReturnStats']
                                ['BreakPointsConverted']?['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['ReturnStats']
                                ['BreakPointsConverted']?['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['ReturnStats']
                                ['BreakPointsConverted']?['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['ReturnStats']
                                ['BreakPointsConverted']?['Divisor'] ??
                            1,
                      ),

                      const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        'Total Service Points Won',
                        player1SetsStats[i]['Stats']['PointStats']
                                ['TotalServicePointsWon']?['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['PointStats']
                                ['TotalServicePointsWon']?['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['PointStats']
                                ['TotalServicePointsWon']?['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['PointStats']
                                ['TotalServicePointsWon']?['Divisor'] ??
                            1,
                      ),
                      const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        'Total Return Points Won',
                        player1SetsStats[i]['Stats']['PointStats']
                                ['TotalReturnPointsWon']?['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['PointStats']
                                ['TotalReturnPointsWon']?['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['PointStats']
                                ['TotalReturnPointsWon']?['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['PointStats']
                                ['TotalReturnPointsWon']?['Divisor'] ??
                            1,
                      ),
                      const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        'Total Points Won',
                        player1SetsStats[i]['Stats']['PointStats']
                                ['TotalPointsWon']?['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['PointStats']
                                ['TotalPointsWon']?['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['PointStats']
                                ['TotalPointsWon']?['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['PointStats']
                                ['TotalPointsWon']?['Divisor'] ??
                            1,
                      ),
                    ] else ...[
                      _buildCenteredStatBar(
                        'ACE',
                        player1SetsStats[i]['Stats']['ServiceStats']['Aces']
                                ['Number'] ??
                            0,
                        player1SetsStats[i]['Stats']['ServiceStats']['Aces']
                                ['Number'] +
                            player2SetsStats[i]['Stats']['ServiceStats']['Aces']
                                ['Number'],
                        player2SetsStats[i]['Stats']['ServiceStats']['Aces']
                                ['Number'] ??
                            0,
                        player1SetsStats[i]['Stats']['ServiceStats']['Aces']
                                ['Number'] +
                            player2SetsStats[i]['Stats']['ServiceStats']['Aces']
                                ['Number'],
                      ),
                      const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        'Double Faults',
                        player1SetsStats[i]['Stats']['ServiceStats']
                                ['DoubleFaults']['Number'] ??
                            0,
                        player1SetsStats[i]['Stats']['ServiceStats']
                                ['DoubleFaults']['Number'] +
                            player2SetsStats[i]['Stats']['ServiceStats']
                                ['DoubleFaults']['Number'],
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['DoubleFaults']['Number'] ??
                            0,
                        player1SetsStats[i]['Stats']['ServiceStats']
                                ['DoubleFaults']['Number'] +
                            player2SetsStats[i]['Stats']['ServiceStats']
                                ['DoubleFaults']['Number'],
                      ),

                      const SizedBox(height: 16),
                      // 发球统计
                      _buildCenteredStatBar(
                        '1st Serve %',
                        player1SetsStats[i]['Stats']['ServiceStats']
                                    ['FirstServe']['Dividend'] !=
                                null
                            ? int.parse(player1SetsStats[i]['Stats']
                                    ['ServiceStats']['FirstServe']['Dividend']
                                .toString())
                            : 0,
                        player1SetsStats[i]['Stats']['ServiceStats']
                                    ['FirstServe']['Divisor'] !=
                                null
                            ? int.parse(player1SetsStats[i]['Stats']
                                    ['ServiceStats']['FirstServe']['Divisor']
                                .toString())
                            : 1,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                    ['FirstServe']['Dividend'] !=
                                null
                            ? int.parse(player2SetsStats[i]['Stats']
                                    ['ServiceStats']['FirstServe']['Dividend']
                                .toString())
                            : 0,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                    ['FirstServe']['Divisor'] !=
                                null
                            ? int.parse(player2SetsStats[i]['Stats']
                                    ['ServiceStats']['FirstServe']['Divisor']
                                .toString())
                            : 1,
                      ),
                      const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        '1st Serve Points Won',
                        player1SetsStats[i]['Stats']['ServiceStats']
                                ['FirstServePointsWon']['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['ServiceStats']
                                ['FirstServePointsWon']['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['FirstServePointsWon']['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['FirstServePointsWon']['Divisor'] ??
                            1,
                      ),
                      const SizedBox(height: 16),

                      _buildCenteredStatBar(
                        '2nd Serve Points Won',
                        player1SetsStats[i]['Stats']['ServiceStats']
                                ['SecondServePointsWon']['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['ServiceStats']
                                ['SecondServePointsWon']['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['SecondServePointsWon']['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['SecondServePointsWon']['Divisor'] ??
                            1,
                      ),
                      const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        'Break Points Saved',
                        player1SetsStats[i]['Stats']['ServiceStats']
                                ['BreakPointsSaved']['Dividend'] ??
                            0,
                        (player1SetsStats[i]['Stats']['ServiceStats']
                                        ['BreakPointsSaved']['Divisor'] ??
                                    0) ==
                                0
                            ? 1
                            : player1SetsStats[i]['Stats']['ServiceStats']
                                    ['BreakPointsSaved']['Divisor'] ??
                                1,
                        player2SetsStats[i]['Stats']['ServiceStats']
                                ['BreakPointsSaved']['Dividend'] ??
                            0,
                        (player2SetsStats[i]['Stats']['ServiceStats']
                                        ['BreakPointsSaved']['Divisor'] ??
                                    0) ==
                                0
                            ? 1
                            : player2SetsStats[i]['Stats']['ServiceStats']
                                    ['BreakPointsSaved']['Divisor'] ??
                                1,
                      ),
                      const SizedBox(height: 16),

                      // 接发球统计
                      _buildCenteredStatBar(
                        '1st Serve Return Points Won',
                        player1SetsStats[i]['Stats']['ReturnStats']
                                ['FirstServeReturnPointsWon']['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['ReturnStats']
                                ['FirstServeReturnPointsWon']['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['ReturnStats']
                                ['FirstServeReturnPointsWon']['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['ReturnStats']
                                ['FirstServeReturnPointsWon']['Divisor'] ??
                            1,
                      ),
                      const SizedBox(height: 16),
                      // 接发球统计
                      _buildCenteredStatBar(
                        '2nd Serve Return Points Won',
                        player1SetsStats[i]['Stats']['ReturnStats']
                                ['SecondServeReturnPointsWon']['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['ReturnStats']
                                ['SecondServeReturnPointsWon']['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['ReturnStats']
                                ['SecondServeReturnPointsWon']['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['ReturnStats']
                                ['SecondServeReturnPointsWon']['Divisor'] ??
                            1,
                      ),
                      const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        'Break Points Converted',
                        player1SetsStats[i]['Stats']['ReturnStats']
                                ['BreakPointsConverted']['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['ReturnStats']
                                ['BreakPointsConverted']['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['ReturnStats']
                                ['BreakPointsConverted']['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['ReturnStats']
                                ['BreakPointsConverted']['Divisor'] ??
                            1,
                      ),
                      const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        'Return Games Played',
                        player1SetsStats[i]['Stats']['ReturnStats']
                                ['ReturnGamesPlayed']['Number'] ??
                            0,
                        1,
                        player2SetsStats[i]['Stats']['ReturnStats']
                                ['ReturnGamesPlayed']['Number'] ??
                            0,
                        1,
                      ),
                      const SizedBox(height: 16),
                      // 总体统计
                      _buildCenteredStatBar(
                        'Total Points Won',
                        player1SetsStats[i]['Stats']['PointStats']
                                ['TotalServicePointsWon']['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['PointStats']
                                ['TotalServicePointsWon']['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['PointStats']
                                ['TotalServicePointsWon']['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['PointStats']
                                ['TotalServicePointsWon']['Divisor'] ??
                            1,
                      ),
                      const SizedBox(height: 16),
                      // 总体统计
                      _buildCenteredStatBar(
                        'Total Return Points Won',
                        player1SetsStats[i]['Stats']['PointStats']
                                ['TotalReturnPointsWon']['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['PointStats']
                                ['TotalReturnPointsWon']['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['PointStats']
                                ['TotalReturnPointsWon']['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['PointStats']
                                ['TotalReturnPointsWon']['Divisor'] ??
                            1,
                      ),
                      // 总体统计
                      const SizedBox(height: 16),
                      _buildCenteredStatBar(
                        'Total Points Won',
                        player1SetsStats[i]['Stats']['PointStats']
                                ['TotalPointsWon']['Dividend'] ??
                            0,
                        player1SetsStats[i]['Stats']['PointStats']
                                ['TotalPointsWon']['Divisor'] ??
                            1,
                        player2SetsStats[i]['Stats']['PointStats']
                                ['TotalPointsWon']['Dividend'] ??
                            0,
                        player2SetsStats[i]['Stats']['PointStats']
                                ['TotalPointsWon']['Divisor'] ??
                            1,
                      ),
                    ]
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 页面指示器
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < player1SetsStats.length; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _currentStatsPage == i
                          ? const Color(0xFF94E831)
                          : Colors.grey.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建比赛统计选项卡
  // 构建得分统计
  // 构建中心对齐的统计条
  Widget _buildCenteredStatBar(String title, int player1Value, int player1Total,
      int player2Value, int player2Total) {
    // 计算百分比
    if (player1Total == 0) player1Total = 1;
    if (player2Total == 0) player2Total = 1;

    final player1Percent =
        player1Total > 0 ? (player1Value / player1Total * 100).round() : 0;
    final player2Percent =
        player2Total > 0 ? (player2Value / player2Total * 100).round() : 0;

    // 计算进度条宽度
    // 计算总百分比，用于确定每边的比例

    final totalWidth =
        MediaQuery.of(context).size.width * 0.65 - 16; // 减去左右padding和边距
    final player1Width =
        totalWidth / 2 * (player1Total > 0 ? (player1Value / player1Total) : 0);
    final player2Width =
        totalWidth / 2 * (player1Total > 0 ? (player2Value / player2Total) : 0);
    debugPrint(
        '$title $player1Width  $player1Total  $player2Width  $player2Total');
    final bool isYtdData = _currentStatsPage == 1;
    final bool isCountData = title.contains('ACE') ||
        title.contains('Double') ||
        title.contains('Serve Rating') ||
        title.contains('Return Games Played'); // 当分母为1时，通常是计数型数据

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 百分比和数值
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),

        // 进度条
        Row(
          children: [
            // 球员1百分比
            SizedBox(
              width: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCountData ? '$player1Value' : '$player1Percent%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  isCountData
                      ? Text(
                          '($player1Value/$player1Total)',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        )
                      : Text(
                          '',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                ],
              ),
            ),

            // 进度条
            Expanded(
              child: SizedBox(
                height: 12,
                // decoration: BoxDecoration(
                //   color: Colors.grey.withOpacity(0.2),
                //   borderRadius: BorderRadius.circular(6),
                // ),
                child: Row(
                  children: [
                    // 球员1进度
                    Container(
                      width: totalWidth / 2,
                      height: 12,
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          bottomLeft: Radius.circular(6),
                        ),
                      ),
                      child: Container(
                        width: player1Width == 0.0 ? 1 : player1Width,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Color(0xFF94E831),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(6),
                            bottomLeft: Radius.circular(6),
                            topRight: Radius.zero,
                            bottomRight: Radius.zero,
                          ),
                        ),
                      ),
                    ),
                    // 球员2进度
                    Container(
                      width: totalWidth / 2,
                      height: 12,
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.zero,
                          bottomLeft: Radius.zero,
                          topRight: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                      child: Container(
                        width: player2Width == 0.0 ? 0.1 : player2Width,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Color(0xFFAA00FF),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.zero,
                            bottomLeft: Radius.zero,
                            topRight: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 球员2百分比
            SizedBox(
              width: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isCountData ? '$player2Value' : '$player2Percent%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '($player2Value/$player2Total)',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
