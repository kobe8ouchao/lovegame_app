import 'package:LoveGame/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/svg_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class PlayerDetailsPage extends StatefulWidget {
  final String playerId;
  final String playerName;
  final String playerCountry;
  final Color playerColor;
  final String type; // 添加类型参数

  const PlayerDetailsPage({
    super.key,
    required this.playerId,
    required this.playerName,
    required this.playerCountry,
    required this.playerColor,
    required this.type, // 添加类型参数
  });

  @override
  _PlayerDetailsPageState createState() => _PlayerDetailsPageState();
}

class _PlayerDetailsPageState extends State<PlayerDetailsPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _playerData = {};
  final bool _isFavorite = false;

  // 球员基本信息
  String _rank = '';
  String _rankMove = '';
  String _age = '';
  String _weight = '';
  String _height = '';
  String _turnedPro = '';
  String _birthplace = '';
  String _plays = '';
  String _backhand = '';
  String _coach = '';
  String _nationality = '';

  // 赛季数据
  String _ytdWinLoss = '';
  String _ytdTitles = '';
  int _ytdWins = 0;
  int _ytdLosses = 0;
  String _headshot = '';

  // 生涯数据
  String _careerWinLoss = '';
  String _careerTitles = '';
  String _careerHighRank = '';
  String _careerHighRankDate = '';
  String _SglYtdPrizeFormatted = '';
  String _CareerPrizeFormatted = '';

  @override
  void initState() {
    super.initState();
    _loadPlayerDetails();
  }

  Future<void> _loadPlayerDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 根据类型调用不同的 API
      Map<String, dynamic> data;
      if (widget.type == 'wta') {
        data = await ApiService.getWTAPlayerDetails(widget.playerId,
            "${widget.playerName.split(' ').first.toLowerCase()}-${widget.playerName.split(' ')[1].toLowerCase()}");
      } else {
        data = await ApiService.getPlayerDetails(widget.playerId);
      }

      setState(() {
        _playerData = data;
        _parsePlayerData(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load player data: $e';
      });
      debugPrint('Error loading player details: $e');
    }
  }

  void _parsePlayerData(Map<String, dynamic> data) {
    // 从JSON数据中提取信息
    _rank = data['SglRank']?.toString() ?? '';
    _rankMove = '${data['SglRankMove'] ?? 0}';

    // 胜负记录
    _ytdWins = data['SglYtdWon'] ?? 0;
    _ytdLosses = data['SglYtdLost'] ?? 0;
    _ytdWinLoss = '$_ytdWins / $_ytdLosses';

    final sglCareerWon = data['SglCareerWon'] ?? 0;
    final sglCareerLost = data['SglCareerLost'] ?? 0;
    _careerWinLoss = '$sglCareerWon / $sglCareerLost';

    // 冠军数
    _ytdTitles = data['SglYtdTitles']?.toString() ?? '0';
    _careerTitles = data['SglCareerTitles']?.toString() ?? '0';

    // 最高排名
    _careerHighRank = data['SglHiRank']?.toString() ?? '';
    _careerHighRankDate = data['SglHiRankDate'] != null
        ? DateTime.parse(data['SglHiRankDate']).year.toString()
        : '';

    // 个人信息
    final birthDate =
        data['BirthDate'] != null ? DateTime.parse(data['BirthDate']) : null;
    _age = data['Age']?.toString() ?? '';

    // 转换单位为公制，但保留原始数据
    final weightLbs = data['WeightLb'] != null
        ? int.tryParse(data['WeightLb'].toString()) ?? 0
        : 0;
    final weightKg = (weightLbs * 0.453592).round(); // 磅转公斤
    _weight = weightKg > 0 ? '$weightKg' : '';

    // 身高转换为厘米，但保留原始数据
    final heightFt = data['HeightFt'] ?? '';
    if (heightFt.isNotEmpty && heightFt.contains("'")) {
      try {
        final parts = heightFt.split("'");
        final feet = int.tryParse(parts[0].trim()) ?? 0;
        final inches = int.tryParse(parts[1].replaceAll('"', '').trim()) ?? 0;
        final totalCm = ((feet * 30.48) + (inches * 2.54)).round();
        _height = '$totalCm cm';
      } catch (e) {
        _height = heightFt;
      }
    } else {
      _height = heightFt;
    }

    _turnedPro = data['ProYear']?.toString() ?? '';
    _birthplace = data['BirthCity'] ?? '';
    if (data['BirthCountry'] != null) {
      _birthplace += ', ${data['BirthCountry']}';
    }

    _nationality = data['Nationality'] ?? widget.playerCountry;
    debugPrint('Counntry: $_nationality');
    // 打法
    _plays = data['PlayHand']?['Description'] ?? 'Right-Handed';
    _backhand = data['BackHand']?['Description'] ?? 'Two-Handed';
    //奖金
    _SglYtdPrizeFormatted = data['SglYtdPrizeFormatted'] ?? '--';
    _CareerPrizeFormatted = data['CareerPrizeFormatted'] ?? '--';
    _coach = data['Coach'] ?? '';
    _headshot = data['ImageUrl'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Players Overview',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          tooltip: '', // 设置为空字符串以禁用长按提示
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        bottom: true, // 确保底部有安全区域
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF94E831)))
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.white),
                    ),
                  )
                : _buildPlayerDetails(),
      ),
    );
  }

  Widget _buildPlayerDetails() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildPlayerInfo(),
              _buildStatsSection(),
              // _buildSocialMediaSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.black,
      elevation: 0,
      title: const Text(
        'Players Overview',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      // actions: [
      //   IconButton(
      //     icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border,
      //         color: _isFavorite ? Colors.red : Colors.white),
      //     onPressed: () {
      //       setState(() {
      //         _isFavorite = !_isFavorite;
      //       });
      //     },
      //   ),
      // ],
    );
  }

  Widget _buildPlayerInfo() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(255, 0, 0, 0),
            Color.fromARGB(255, 0, 0, 0),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Stack(
        children: [
          // 右侧球员图片作为背景
          Positioned(
            right: -20, // 向右延伸更多，使图片更宽
            top: 10, // 将图片向下移动
            height: 180, // 设置固定高度，截取超出部分
            width: MediaQuery.of(context).size.width * 0.6, // 增加宽度比例
            child: Opacity(
              opacity: 0.85, // 稍微调整透明度
              child: widget.type == 'wta'
                  ? Image.network(
                      _headshot,
                      fit: BoxFit.cover, // 使用cover而不是contain，确保填充整个区域
                      alignment: Alignment.topRight, // 改为顶部对齐，确保显示上半身
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.transparent,
                        );
                      },
                    )
                  : Image.network(
                      'https://atptour.com/-/media/alias/player-gladiator-headshot/${widget.playerId}',
                      fit: BoxFit.cover, // 使用cover而不是contain，确保填充整个区域
                      alignment: Alignment.topRight, // 改为顶部对齐，确保显示上半身
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.transparent,
                        );
                      },
                    ),
            ),
          ),

          // 前景内容
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 球员姓名
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      widget.playerName.split(' ').first.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      widget.playerName.split(' ').last.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF94E831),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              // 国籍
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 16,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: widget.type == 'wta'
                        ? SvgPicture.network(
                            'https://www.atptour.com/-/media/images/flags/${_nationality.toString().toLowerCase()}.svg',
                            fit: BoxFit.cover,
                            placeholderBuilder: (context) =>
                                Container(color: Colors.grey),
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Colors.grey,
                              child:
                                  const Icon(Icons.flag, color: Colors.white),
                            ),
                          )
                        : _playerData['ScRelativeUrlPlayerCountryFlag'] != null
                            ? SvgPicture.network(
                                'https://atptour.com${_playerData['ScRelativeUrlPlayerCountryFlag']}',
                                fit: BoxFit.cover,
                                placeholderBuilder: (context) =>
                                    Container(color: Colors.grey),
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: Colors.grey,
                                  child: const Icon(Icons.flag,
                                      color: Colors.white),
                                ),
                              )
                            : Container(color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _nationality,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 80), // 增加空间，让背景图片更加明显

              // 底部一排球员信息
              Container(
                margin: const EdgeInsets.only(top: 30), // 增加上边距，避免覆盖图片
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoColumn('Rank', _rank, '(Singles)'),
                    _buildInfoColumn('Age', _age, 'years'),
                    _buildInfoColumn('Height', _height,
                        '(${_playerData['HeightFt'] ?? ''})'),
                    _buildInfoColumn('Weight', '$_weight kg',
                        '(${_playerData['WeightLb'] ?? ''} lbs)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, String subValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '-' : value,
          style: const TextStyle(
            color: Color(0xFF94E831),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subValue,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 个人信息卡片
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0C0D0C),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  // offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 个人信息标题
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: const Text(
                    'PLAYER INFO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // 个人信息行
                _buildDetailRow('Birthplace', _birthplace),
                _buildDetailRow('Turned Pro', _turnedPro),
                _buildDetailRow('Plays', _plays),
                _buildDetailRow('Backhand', _backhand),
                _buildDetailRow('Coach', _coach),
                _buildDetailRow('Social Media', ''),
              ],
            ),
          ),

          // 赛季数据卡片
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0C0D0C),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 赛季数据标题
                Row(
                  children: [
                    const Text(
                      'SEASON STATS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF94E831),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '2025',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 赛季数据内容
                _buildStatsRow('Rank/Move', '$_rank / $_rankMove'),
                _buildStatsRow('Win/Loss', _ytdWinLoss),
                _buildStatsRow('Titles', _ytdTitles),
                _buildStatsRow('Yeas Prize Money', _SglYtdPrizeFormatted),
              ],
            ),
          ),

          // 生涯数据卡片
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0C0D0C),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 生涯数据标题
                const Text(
                  'CAREER STATS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // 生涯数据内容
                _buildStatsRow('Career High', _careerHighRank),
                _buildStatsRow('Win/Loss', _careerWinLoss),
                _buildStatsRow('Titles', _careerTitles),
                _buildStatsRow('Career Prize Money', _CareerPrizeFormatted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF94E831),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: label == 'Social Media'
                ? Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          final instagramUrl =
                              _playerData['InstagramUrl'] ?? '';
                          if (instagramUrl.isNotEmpty) {
                            _launchUrl(instagramUrl);
                          } else {
                            _launchUrl('https://www.instagram.com/atptour/');
                          }
                        },
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: () {
                          final twitterUrl = _playerData['TwitterUrl'] ?? '';
                          if (twitterUrl.isNotEmpty) {
                            _launchUrl(twitterUrl);
                          } else {
                            _launchUrl('https://twitter.com/atptour');
                          }
                        },
                        child: const Icon(Icons.alternate_email,
                            color: Colors.white, size: 22),
                      ),
                    ],
                  )
                : Text(
                    value.isEmpty ? '-' : value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // 添加打开URL的方法
  void _launchUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('无法打开URL: $e');
    }
  }

  Widget _buildStatsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              color: Color(0xFF94E831),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialMediaSection() {
    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'View Full Player Profile',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.open_in_new,
            color: Color(0xFF94E831),
            size: 20,
          ),
        ],
      ),
    );
  }
}
