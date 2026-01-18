import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'player_details_page.dart'; // Import player details page

class GSMatchDetailsPage extends StatefulWidget {
  final Map<String, dynamic>? matchData;
  final String? matchId;
  final String? tournamentId;
  final String? year;
  final String? player1ImageUrl;
  final String? player2ImageUrl;
  final String? player1FlagUrl;
  final String? player2FlagUrl;
  final String? typeMatch;
  // Add input set scores parameter
  final Map<String, List<int>>? inputSetScores;
  final String? player1Id;
  final String? player2Id;
  final String? gs;

  const GSMatchDetailsPage({
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
  State<GSMatchDetailsPage> createState() => _GSMatchDetailsPageState();
}

class _GSMatchDetailsPageState extends State<GSMatchDetailsPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String _errorMessage = '';
  Map<String, dynamic>? _matchData;
  int _currentStatsPage = 0;

  @override
  void initState() {
    super.initState();

    // If match data is passed directly, use it
    if (widget.matchData != null) {
      _matchData = widget.matchData;
    } else {
      // Otherwise, load data from API
      _loadMatchData();
    }
  }

  // Load match data from API
  Future<void> _loadMatchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    debugPrint(
        'widget.matchId: ${widget.matchId}, widget.tournamentId: ${widget.tournamentId}, widget.year: ${widget.year}');
    try {
      final year = widget.year ?? DateTime.now().year.toString();
      final matchId = widget.matchId ?? '';
      final url =
          'https://www.usopen.org/en_US/scores/feeds/$year/matches/complete/$matchId.json';

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
          _errorMessage = 'Failed to load data: HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load data: $e';
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
    // If the name exceeds 13 characters, split by space, take the first letter of the first element and concatenate with the last element
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
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF94E831),
          ),
        ),
      );
    }

    // Show error state
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
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
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final tournament = _matchData!['Tournament'] ?? {};
    final match = _matchData!['Match'] ?? {};

    // If there is no data
    if (_matchData == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Text(
            'No Match Details',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    // Basic match information
    final location = tournament['TournamentCity'] ?? '';
    final country = tournament['EventCountry'] ?? '';
    final titleName = tournament['TournamentName'] ?? '';
    final RoundName = match['RoundName'] ?? '';
    final isLive =
        match['MatchStatus'] == 'L'; // 'L' for live, 'F' for finished

    // Player information
    final playerTeam = match['PlayerTeam'];
    final opponentTeam = match['OpponentTeam'];
    // Player 1 information
    final player1 = playerTeam['Player'] ?? {};
    final player2 = opponentTeam['Player'] ?? {};
    final player1FirstName = player1['PlayerFirstName'] ?? '';
    final player1LastName = player1['PlayerLastName'] ?? '';
    // final player1Name = '$player1FirstName $player1LastName';
    final player1Id = player1['PlayerId'] ?? '';
    final player2Id = player2['PlayerId'] ?? '';
    String extractedPlayer1Country = '';
    if (widget.player1FlagUrl != null && widget.player1FlagUrl!.isNotEmpty) {
      final uri = Uri.parse(widget.player1FlagUrl!);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last;
        // Remove .svg suffix and convert to uppercase to match country code
        extractedPlayer1Country =
            lastSegment.replaceAll('.svg', '').toUpperCase();
      }
    }
    String? player1Country = player1['PlayerCountry'] ?? '';
    String? player2Country = player2['PlayerCountry'] ?? '';
    String? player1ImageUrl = player1Id.contains('atp')
        ? 'https://www.atptour.com/-/media/alias/player-headshot/${player1Id.replaceFirst('atp', '')}'
        : 'https://wtafiles.blob.core.windows.net/images/headshots/${(player1Id).replaceFirst('wta', '')}.jpg';
    String? player1FlagUrl =
        'https://www.atptour.com/-/media/images/flags/${player1Country.toString().toLowerCase()}.svg';
    String? player2ImageUrl = player2Id.contains('atp')
        ? 'https://www.atptour.com/-/media/alias/player-headshot/${player2Id.replaceFirst('atp', '')}'
        : 'https://wtafiles.blob.core.windows.net/images/headshots/${(player2Id).replaceFirst('wta', '')}.jpg';
    String? player2FlagUrl =
        'https://www.atptour.com/-/media/images/flags/${player2Country.toString().toLowerCase()}.svg';
    debugPrint(
        'extractedPlayer1Country: $extractedPlayer1Country player1Country: $player1Country');
    // if (extractedPlayer1Country.toLowerCase() ==
    //     player1Country.toString().toLowerCase()) {
    //   player1ImageUrl = widget.player1ImageUrl;
    //   player2ImageUrl = widget.player2ImageUrl;
    // } else {
    //   player1ImageUrl = widget.player2ImageUrl;
    //   player2ImageUrl = widget.player1ImageUrl;
    //   player1FlagUrl = widget.player2FlagUrl ?? '';
    //   player2FlagUrl = widget.player1FlagUrl ?? '';
    //   player1Country = player2['PlayerCountry'];
    //   player2Country = player1['PlayerCountry'];
    // }

    final player1Sets = playerTeam['SetScores'];
    final player2Sets = opponentTeam['SetScores'];
    if (player1Sets.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
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
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    debugPrint('player1Sets: $player1Sets');
    debugPrint('player2Sets: $player2Sets');
    // Player 2 information

    final player2FirstName = player2['PlayerFirstName'];
    final player2LastName = player2['PlayerLastName'];

    // Get match statistics
    final player1Stats = player1Sets.isNotEmpty ? player1Sets[0]['Stats'] : {};
    final player2Stats = player2Sets.isNotEmpty ? player2Sets[0]['Stats'] : {};

    final player1SetsStats = player1Sets.isNotEmpty ? player1Sets : [];
    final player2SetsStats = player2Sets.isNotEmpty ? player2Sets : [];
    // Score data
    // Get year-to-date statistics
    final player1YearStats = playerTeam['YearToDateStats'] ?? {};
    final player2YearStats = opponentTeam['YearToDateStats'] ?? {};

    List<String> player1ScoresList = [];
    List<String> player2ScoresList = [];
    List<String> player1TiebreakList = [];
    List<String> player2TiebreakList = [];

    // Start from index 1, because index 0 is overall statistics
    for (int i = 1; i < player1Sets.length; i++) {
      final set1 = player1Sets[i];
      final set2 = player2Sets[i];
      if (set1['SetScore'] != null && set2['SetScore'] != null) {
        player1ScoresList.add(set1['SetScore']?.toString() ?? '0');
        player2ScoresList.add(set2['SetScore']?.toString() ?? '0');
      }
      // Add tiebreak score
      player1TiebreakList.add(set1['TieBreakScore']?.toString() ?? '');
      player2TiebreakList.add(set2['TieBreakScore']?.toString() ?? '');
    }
    // Extract scores
    List<Map<String, String>> setScores = [];

    // If there are input scores and the API scores are empty, use the input scores
    if (widget.inputSetScores != null && widget.inputSetScores!.isNotEmpty) {
      for (int i = 0; i < widget.inputSetScores!['player1']!.length; i++) {
        if (widget.inputSetScores!['player1']?[i] != 0) {
          debugPrint('player1 ${widget.player1Id} $player1Id ');
          // if (widget.player1Id.toString().toLowerCase() ==
          //     player1Id.toString().toLowerCase()) {
          int score1 = widget.inputSetScores!['player1']![i];
          int score2 = widget.inputSetScores!['player2']![i];
          setScores.add(
              {'player1': score1.toString(), 'player2': score2.toString()});
          // } else {
          //   int score1 = widget.inputSetScores!['player1']![i];
          //   int score2 = widget.inputSetScores!['player2']![i];
          //   setScores.add(
          //       {'player1': score2.toString(), 'player2': score1.toString()});
          // }
        }
      }
    } else {
      for (int i = 0; i < player1ScoresList.length; i++) {
        setScores.add({
          'player1': player1ScoresList[i],
          'player2': player2ScoresList[i],
        });
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top area - match location and back button
            _buildHeader('Match Detail', isLive),

            // Score area - Ensure player 1 is on the left with their scores
            _buildScoreArea(
                player1Id ?? '',
                player2Id ?? '',
                _formatPlayerName('$player1FirstName $player1LastName'),
                player1Country ?? '',
                player1ImageUrl ?? '',
                player1FlagUrl,
                _formatPlayerName('$player2FirstName $player2LastName'),
                player2Country ?? '',
                player2ImageUrl ?? '',
                player2FlagUrl,
                setScores,
                player1TiebreakList,
                player2TiebreakList),

            const SizedBox(height: 12),
            // Stats area

            Expanded(
              child: _buildStatsArea(player1Stats, player2Stats,
                  player1SetsStats, player2SetsStats),
            ),

            // Bottom navigation bar
          ],
        ),
      ),
    );
  }

  // Build header area
  Widget _buildHeader(String location, bool isLive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back button
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

          // Match location
          Text(
            location,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          // Live tag
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

  // Build score area with correct player and score alignment
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
      List<String> player1TiebreakList,
      List<String> player2TiebreakList) {
    // Determine the winner based on set scores and calculate total sets won
    bool isPlayer1Winner = false;
    int player1Sets = 0;
    int player2Sets = 0;

    if (setScores.isNotEmpty) {
      for (var set in setScores) {
        int p1Score = int.tryParse(set['player1'] ?? '0') ?? 0;
        int p2Score = int.tryParse(set['player2'] ?? '0') ?? 0;

        if (p1Score > p2Score) {
          player1Sets++;
        } else if (p2Score > p1Score) {
          player2Sets++;
        }
      }

      isPlayer1Winner = player1Sets > player2Sets;
    }

    // Calculate total points won for each player
    int player1TotalPoints = 0;
    int player2TotalPoints = 0;

    for (var set in setScores) {
      player1TotalPoints += int.tryParse(set['player1'] ?? '0') ?? 0;
      player2TotalPoints += int.tryParse(set['player2'] ?? '0') ?? 0;
    }
    // Use passed URLs or default URLs
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
            // Background image
            Image.asset(
              'assets/images/madrid.webp',
              width: double.infinity,
              height: 260,
              fit: BoxFit.cover,
            ),
            // Gradient mask
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
                  // Player information and scores
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Player 1
                      Column(
                        children: [
                          // Player 1 avatar
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  // Navigate to player details page
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PlayerDetailsPage(
                                        playerId: widget.player1Id ?? '',
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
                          // Player 1 name with winner highlight
                          Text(
                            player1Name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // Player 1 country
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

                      // Scores
                      Column(
                        children: [
                          // First set scores
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Player 1 score area
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
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    // Show tiebreak score
                                    if (player1TiebreakList.isNotEmpty &&
                                        player1TiebreakList[0].isNotEmpty &&
                                        player1TiebreakList[0] != '0')
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

                              // Separator
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

                              // Player 2 score area
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
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    // Show tiebreak score
                                    if (player2TiebreakList.isNotEmpty &&
                                        player2TiebreakList[0].isNotEmpty &&
                                        player2TiebreakList[0] != '0')
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

                          // Second set scores
                          if (setScores.length > 1)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Player 1 score area
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
                                      // Show tiebreak score
                                      if (player1TiebreakList.length > 1 &&
                                          player1TiebreakList[1].isNotEmpty &&
                                          player1TiebreakList[1] != '0')
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

                                // Separator
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

                                // Player 2 score area
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
                                      // Show tiebreak score
                                      if (player2TiebreakList.length > 1 &&
                                          player2TiebreakList[1].isNotEmpty &&
                                          player2TiebreakList[1] != '0')
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

                          // Third set scores
                          if (setScores.length > 2)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Player 1 score area
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
                                      // Show tiebreak score
                                      if (player1TiebreakList.length > 2 &&
                                          player1TiebreakList[2]
                                              .isNotEmpty && // Check if the score is not empty
                                          player1TiebreakList[2] != '0')
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

                                // Separator
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

                                // Player 2 score area
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
                                      // Show tiebreak score
                                      if (player2TiebreakList.length > 2 &&
                                          player2TiebreakList[2]
                                              .isNotEmpty && // Check if the score is not empty
                                          player2TiebreakList[2] != '0')
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

                          // Add fourth set scores
                          if (setScores.length > 3)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Player 1 score area
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
                                      // Show tiebreak score
                                      if (player1TiebreakList.length > 3 &&
                                          player1TiebreakList[3]
                                              .isNotEmpty && // Check if the score is not empty
                                          player1TiebreakList[3] != '0')
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

                                // Separator
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

                                // Player 2 score area
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
                                      // Show tiebreak score
                                      if (player2TiebreakList.length > 3 &&
                                          player2TiebreakList[3]
                                              .isNotEmpty && // Check if the score is not empty
                                          player2TiebreakList[3] != '0')
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

                          // Add fifth set scores
                          if (setScores.length > 4)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Player 1 score area
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
                                      // Show tiebreak score
                                      if (player1TiebreakList.length > 4 &&
                                          player1TiebreakList[4]
                                              .isNotEmpty && // Check if the score is not empty
                                          player1TiebreakList[4] != '0')
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

                                // Separator
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

                                // Player 2 score area
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
                                      // Show tiebreak score only if not empty and not "0"
                                      if (player2TiebreakList.length > 4 &&
                                          player2TiebreakList[4].isNotEmpty &&
                                          player2TiebreakList[4] != '0')
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

                      // Player 2
                      Column(
                        children: [
                          // Player 2 avatar
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  // Navigate to player details page
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PlayerDetailsPage(
                                        playerId: widget.player2Id ?? '',
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
                          // Player 2 name with winner highlight
                          Text(
                            player2Name,
                            style: TextStyle(
                              color: !isPlayer1Winner
                                  ? const Color(0xFF94E831)
                                  : Colors.white,
                              fontSize: 14,
                              fontWeight: !isPlayer1Winner
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                            ),
                          ),
                          // Player 2 country
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

  // Build stats area
  Widget _buildStatsArea(Map player1Stats, Map player2Stats,
      List player1SetsStats, List player2SetsStats) {
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
          // Title
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
          // Stats data
          Expanded(
            child: PageView(
              onPageChanged: (index) {
                setState(() {
                  _currentStatsPage = index;
                });
              },
              children: [
                // Current match stats
                ListView(padding: const EdgeInsets.all(16), children: [
                  _buildCenteredStatBar(
                    'Aces',
                    player1Stats['Aces'] ?? 0,
                    (player1Stats['Aces'] ?? 0) + (player2Stats['Aces'] ?? 0),
                    player2Stats['Aces'] ?? 0,
                    (player1Stats['Aces'] ?? 0) + (player2Stats['Aces'] ?? 0),
                  ),
                  const SizedBox(height: 16),
                  _buildCenteredStatBar(
                    'Double Faults',
                    player1Stats['DoubleFaults'] ?? 0,
                    (player1Stats['DoubleFaults'] ?? 0) +
                        (player2Stats['DoubleFaults'] ?? 0),
                    player2Stats['DoubleFaults'] ?? 0,
                    (player1Stats['DoubleFaults'] ?? 0) +
                        (player2Stats['DoubleFaults'] ?? 0),
                  ),
                  const SizedBox(height: 16),
                  _buildCenteredStatBar(
                    '1st Serve %',
                    player1Stats['FirstServeIn'] ?? 0,
                    player1Stats['FirstServeTotal'] ?? 1,
                    player2Stats['FirstServeIn'] ?? 0,
                    player2Stats['FirstServeTotal'] ?? 1,
                  ),
                  const SizedBox(height: 16),
                  _buildCenteredStatBar(
                    '1st Serve Points Won',
                    player1Stats['FirstServeWon'] ?? 0,
                    player1Stats['FirstServeIn'] ?? 1,
                    player2Stats['FirstServeWon'] ?? 0,
                    player2Stats['FirstServeIn'] ?? 1,
                  ),
                  const SizedBox(height: 16),
                  _buildCenteredStatBar(
                    '2nd Serve Points Won',
                    player1Stats['SecondServeWon'] ?? 0,
                    player1Stats['SecondServeTotal'] ?? 1,
                    player2Stats['SecondServeWon'] ?? 0,
                    player2Stats['SecondServeTotal'] ?? 1,
                  ),
                  const SizedBox(height: 16),
                  _buildCenteredStatBar(
                    'Break Points Won',
                    player1Stats['BreakPointsWon'] ?? 0,
                    player1Stats['BreakPointsTotal'] ?? 1,
                    player2Stats['BreakPointsWon'] ?? 0,
                    player2Stats['BreakPointsTotal'] ?? 1,
                  ),
                  const SizedBox(height: 16),
                  _buildCenteredStatBar(
                    'Total Points Won',
                    player1Stats['TotalPointsWon'] ?? 0,
                    (player1Stats['TotalPointsWon'] ?? 0) +
                        (player2Stats['TotalPointsWon'] ?? 0),
                    player2Stats['TotalPointsWon'] ?? 0,
                    (player1Stats['TotalPointsWon'] ?? 0) +
                        (player2Stats['TotalPointsWon'] ?? 0),
                  ),
                ]),

                for (int i = 1; i < player1SetsStats.length; i++)
                  ListView(padding: const EdgeInsets.all(16), children: [
                    _buildCenteredStatBar(
                      'Aces',
                      player1SetsStats[i]['Stats']['Aces'] ?? 0,
                      (player1SetsStats[i]['Stats']['Aces'] ?? 0) +
                          (player2SetsStats[i]['Stats']['Aces'] ?? 0),
                      player2SetsStats[i]['Stats']['Aces'] ?? 0,
                      (player1SetsStats[i]['Stats']['Aces'] ?? 0) +
                          (player2SetsStats[i]['Stats']['Aces'] ?? 0),
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Double Faults',
                      player1SetsStats[i]['Stats']['DoubleFaults'] ?? 0,
                      (player1SetsStats[i]['Stats']['DoubleFaults'] ?? 0) +
                          (player2SetsStats[i]['Stats']['DoubleFaults'] ?? 0),
                      player2SetsStats[i]['Stats']['DoubleFaults'] ?? 0,
                      (player1SetsStats[i]['Stats']['DoubleFaults'] ?? 0) +
                          (player2SetsStats[i]['Stats']['DoubleFaults'] ?? 0),
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      '1st Serve %',
                      player1SetsStats[i]['Stats']['FirstServeIn'] ?? 0,
                      player1SetsStats[i]['Stats']['FirstServeTotal'] ?? 1,
                      player2SetsStats[i]['Stats']['FirstServeIn'] ?? 0,
                      player2SetsStats[i]['Stats']['FirstServeTotal'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      '1st Serve Points Won',
                      player1SetsStats[i]['Stats']['FirstServeWon'] ?? 0,
                      player1SetsStats[i]['Stats']['FirstServeIn'] ?? 1,
                      player2SetsStats[i]['Stats']['FirstServeWon'] ?? 0,
                      player2SetsStats[i]['Stats']['FirstServeIn'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      '2nd Serve Points Won',
                      player1SetsStats[i]['Stats']['SecondServeWon'] ?? 0,
                      player1SetsStats[i]['Stats']['SecondServeTotal'] ?? 1,
                      player2SetsStats[i]['Stats']['SecondServeWon'] ?? 0,
                      player2SetsStats[i]['Stats']['SecondServeTotal'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Break Points Won',
                      player1SetsStats[i]['Stats']['BreakPointsWon'] ?? 0,
                      player1SetsStats[i]['Stats']['BreakPointsTotal'] ?? 1,
                      player2SetsStats[i]['Stats']['BreakPointsWon'] ?? 0,
                      player2SetsStats[i]['Stats']['BreakPointsTotal'] ?? 1,
                    ),
                    const SizedBox(height: 16),
                    _buildCenteredStatBar(
                      'Total Points Won',
                      player1SetsStats[i]['Stats']['TotalPointsWon'] ?? 0,
                      (player1SetsStats[i]['Stats']['TotalPointsWon'] ?? 0) +
                          (player2SetsStats[i]['Stats']['TotalPointsWon'] ?? 0),
                      player2SetsStats[i]['Stats']['TotalPointsWon'] ?? 0,
                      (player1SetsStats[i]['Stats']['TotalPointsWon'] ?? 0) +
                          (player2SetsStats[i]['Stats']['TotalPointsWon'] ?? 0),
                    ),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Page indicators
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

  // Build centered stats bar
  Widget _buildCenteredStatBar(String title, int player1Value, int player1Total,
      int player2Value, int player2Total) {
    // Calculate percentages
    if (player1Total == 0) player1Total = 1;
    if (player2Total == 0) player2Total = 1;

    final player1Percent =
        player1Total > 0 ? (player1Value / player1Total * 100).round() : 0;
    final player2Percent =
        player2Total > 0 ? (player2Value / player2Total * 100).round() : 0;

    // Calculate progress bar width
    final totalWidth = MediaQuery.of(context).size.width * 0.65 -
        16; // Remove left and right padding and margins
    final player1Width =
        totalWidth / 2 * (player1Total > 0 ? (player1Value / player1Total) : 0);
    final player2Width =
        totalWidth / 2 * (player2Total > 0 ? (player2Value / player2Total) : 0);

    final bool isCountData = title.contains('Aces') ||
        title.contains('Double Faults') ||
        title.contains(
            'Total Points Won'); // When denominator is 1, it's usually count data

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Percentages and values
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

        // Progress bar
        Row(
          children: [
            // Player 1 percentage
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
                  Text(
                    '($player1Value/$player1Total)',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            // Progress bar
            Expanded(
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    // Player 1 progress
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
                    // Player 2 progress
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

            // Player 2 percentage
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
