import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import 'player_details_page.dart'; // 添加这一行导入
import 'package:cached_network_image/cached_network_image.dart';

class PlayerRankingsPage extends StatefulWidget {
  const PlayerRankingsPage({super.key});

  @override
  State<PlayerRankingsPage> createState() => _PlayerRankingsPageState();
}

class _PlayerRankingsPageState extends State<PlayerRankingsPage> {
  final ApiService _apiService = ApiService();

  // 更新颜色以匹配图片中的绿色调
  final Color _primaryColor = const Color(0xFF94E831);
  final Color _secondaryColor = const Color(0xFF121212);
  final Color _backgroundColor = const Color(0xFF121212);

  // 添加上升下降颜色
  final Color _upColor = const Color(0xFF4CD964); // 绿色
  final Color _downColor = const Color(0xFFFF3B30); // 红色
  final Color _neutralColor = const Color(0xFFE6C200); // 黄色

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<dynamic> _players = [];
  List<dynamic> _filteredPlayers = [];
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _hasMoreData = true;
  bool _isSearching = false;
  bool _showSearchResults = false;
  Timer? _debounce;

  // 添加筛选选项
  bool _showATP = true;
  bool _showWTA = false;
  bool _showSingles = true;
  bool _showDoubles = false;

  // 添加缓存机制
  final Map<String, List<dynamic>> _cachedData = {};
  final Set<String> _loadedFilters = {};

  @override
  void initState() {
    super.initState();
    debugPrint('PlayerRankingsPage initState 开始');
    _loadPlayerRankings();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_onSearchChanged);
    debugPrint('PlayerRankingsPage initState 完成');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  String _formatPlayerName(String name) {
    // 如果名称超过18个字符，按空格分隔，取第一个元素的第一个字母加空格连接最后一个元素
    if (name.length > 18) {
      List<String> nameParts = name.split(' ');
      if (nameParts.length > 1) {
        String firstName = nameParts.first;
        String lastName = nameParts.last;
        return '${firstName[0]}. $lastName';
      }
    }
    return name;
  }

  // 添加新的变量来存储不同类型的排名数据
  final List<dynamic> _atpSinglesPlayers = [];
  final List<dynamic> _atpDoublesPlayers = [];
  final List<dynamic> _wtaSinglesPlayers = [];
  final List<dynamic> _wtaDoublesPlayers = [];

  // 生成缓存键
  String _getCacheKey() {
    String type = _showATP ? 'ATP' : 'WTA';
    String category = _showSingles ? 'Singles' : 'Doubles';
    return '${type}_$category';
  }

  // 修改加载球员排名数据的方法
  Future<void> _loadPlayerRankings() async {
    debugPrint('=== _loadPlayerRankings 开始执行 ===');
    String cacheKey = _getCacheKey();
    debugPrint('Cache Key: $cacheKey');
    debugPrint(
        '当前状态: ATP=$_showATP, WTA=$_showWTA, Singles=$_showSingles, Doubles=$_showDoubles');

    // 检查是否已经加载过这个筛选条件的数据
    if (_cachedData.containsKey(cacheKey)) {
      setState(() {
        _players = _cachedData[cacheKey]!;
        _filteredPlayers = List.from(_cachedData[cacheKey]!);
        _isLoading = false;
      });
      return;
    }

    // 如果没有缓存，则加载数据
    debugPrint('开始加载数据...');
    setState(() {
      _players = [];
      _filteredPlayers = [];
      _isLoading = true;
    });

    try {
      debugPrint('调用API获取数据: ${_showATP ? "ATP" : "WTA"}');
      final players = _showATP
          ? await _apiService.getPlayerRankings()
          : await _apiService.getWTAPlayerRankings();
      debugPrint('API返回数据数量: ${players.length}');

      // 缓存数据
      _cachedData[cacheKey] = players;
      _loadedFilters.add(cacheKey);

      setState(() {
        _players = players;
        _filteredPlayers = List.from(players);
        _isLoading = false;
        _hasMoreData = false; // 一次性加载所有数据
      });
      debugPrint('数据加载完成，设置状态完成');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('=== 加载排名数据失败 ===');
      debugPrint('错误详情: $e');
      debugPrint('错误类型: ${e.runtimeType}');
    }
    debugPrint('=== _loadPlayerRankings 执行完成 ===');
  }

// 修改筛选选项的构建方法

  // 搜索输入变化处理
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (_searchController.text.isEmpty) {
        setState(() {
          _showSearchResults = false;
          _filteredPlayers = List.from(_players); // 恢复原始列表
        });
        return;
      }

      _searchPlayersLocally(_searchController.text);
    });
  }

  // 本地搜索球员
  void _searchPlayersLocally(String keyword) {
    setState(() {
      _isSearching = true;
    });

    try {
      // 在本地列表中搜索
      final results = _players.where((player) {
        final name = player['Name'] ?? '';
        final firstName = player['FirstName'] ?? '';
        final lastName = player['LastName'] ?? '';
        final fullName = '$firstName $lastName';

        return name.toLowerCase().contains(keyword.toLowerCase()) ||
            fullName.toLowerCase().contains(keyword.toLowerCase());
      }).toList();

      setState(() {
        if (_showSearchResults) {
          // 如果显示下拉提示，更新搜索结果
          _searchResults = results;
        } else {
          // 直接更新列表显示
          _filteredPlayers = results;
        }
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      debugPrint('搜索球员失败: $e');
    }
  }

  // 搜索球员
  Future<void> _searchPlayers(String keyword) async {
    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    try {
      final results = await _apiService.searchPlayers(keyword);

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      print('搜索球员失败: $e');
    }
  }

  // 滚动监听器
  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMoreData) {
      // 如果需要分页加载，可以在这里实现
    }
  }

  // 下拉刷新
  Future<void> _refreshData() async {
    await _loadPlayerRankings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Top 250 Ranked Players',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(children: [
        Column(
          children: [
            // 搜索栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 44, // 减小高度
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: _showSearchResults
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        )
                      : BorderRadius.circular(12), // 减小圆角
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search for players...',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.grey, size: 20),
                    // 添加清除按钮
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: Colors.grey, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _showSearchResults = false;
                                _filteredPlayers =
                                    List.from(_players); // 恢复原始列表
                              });
                              // 可选：取消焦点
                              FocusScope.of(context).unfocus();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  // 在 TextField 的 onSubmitted 回调中
                  onSubmitted: (value) {
                    setState(() {
                      _showSearchResults = false;
                    });
                    if (value.isNotEmpty) {
                      _searchPlayersLocally(value);
                    } else {
                      setState(() {
                        _filteredPlayers = List.from(_players); // 恢复原始列表
                      });
                    }
                  },
                ),
              ),
            ),

            // 筛选选项
            _buildFilterOptions(),

            // 搜索结果下拉列表
            if (_showSearchResults)
              Positioned(
                  top: 52, // 搜索框高度 + 上下 padding
                  left: 16,
                  right: 16,
                  child: Material(
                    elevation: 8,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: Container(
                      width: double.infinity,
                      margin: EdgeInsets.zero,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: _isSearching
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(
                                    color: _primaryColor),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final player = _searchResults[index];
                                return ListTile(
                                  title: Text(
                                    '${player['Name']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Rank #${player['RankNo']}',
                                    style: const TextStyle(
                                        fontSize: 14, color: Color(0xFF6B6B6B)),
                                  ),
                                  leading: CircleAvatar(
                                    backgroundImage: CachedNetworkImageProvider(
                                      player['UrlHeadshotImage'] != null &&
                                              player['UrlHeadshotImage']
                                                  .toString()
                                                  .isNotEmpty
                                          ? player['UrlHeadshotImage']
                                                  .toString()
                                                  .startsWith('http')
                                              ? player['UrlHeadshotImage']
                                              : 'https://atptour.com${player['UrlHeadshotImage']}'
                                          : !_showATP
                                              ? 'https://www.atptour.com/assets/tournament/assets/headshot_placeholder.jpg'
                                              : 'https://atptour.com/-/media/alias/player-headshot/default-player-headshot.png',
                                    ),
                                    backgroundColor: Colors.grey[800],
                                  ),
                                  trailing: player['CountryCode'] != null
                                      ? SizedBox(
                                          width: 30,
                                          height: 20,
                                          child: _buildCountryFlag(
                                              player['UrlCountryFlag'],
                                              player['CountryCode']),
                                        )
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _searchController.text =
                                          '${player['Name']}';
                                      _showSearchResults = false;
                                      // 可以添加导航到球员详情页的逻辑
                                    });

                                    // 导航到球员详情页
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PlayerDetailsPage(
                                          playerId: player['PlayerId'] ?? '',
                                          playerName: player['Name'] ?? '',
                                          playerCountry:
                                              player['CountryCode'] ?? '',
                                          playerColor: _primaryColor,
                                          type: _showATP
                                              ? 'atp'
                                              : 'wta', // 添加类型参数
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  )),
            // 球员列表
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: _primaryColor,
                child: _isLoading && _players.isEmpty
                    ? Center(
                        child: CircularProgressIndicator(color: _primaryColor))
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _filteredPlayers.length,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemBuilder: (context, index) {
                          final player = _filteredPlayers[index];
                          return _buildPlayerItem(player, index + 1);
                        },
                      ),
              ),
            ),
          ],
        )
      ]),
    );
  }

  // 构建筛选选项
  Widget _buildFilterOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // ATP 按钮
          _buildFilterButton('ATP', _showATP, () {
            if (!_showATP) {
              setState(() {
                _showATP = true;
                _showWTA = false;
              });
              _loadPlayerRankings(); // 使用缓存机制加载数据
            }
          }),
          const SizedBox(width: 8),
          // WTA 按钮
          _buildFilterButton('WTA', _showWTA, () {
            if (!_showWTA) {
              setState(() {
                _showATP = false;
                _showWTA = true;
              });
              _loadPlayerRankings(); // 使用缓存机制加载数据
            }
          }),
          const Spacer(),
          // Singles 按钮
          _buildFilterButton('Singles', _showSingles, () {
            if (!_showSingles) {
              setState(() {
                _showSingles = true;
                _showDoubles = false;
              });
              _loadPlayerRankings(); // 使用缓存机制加载数据
            }
          }),
          // const SizedBox(width: 8),
          // // Doubles 按钮
          // _buildFilterButton('Doubles', _showDoubles, () {
          //   if (!_showDoubles) {
          //     setState(() {
          //       _showSingles = false;
          //       _showDoubles = true;
          //     });
          //     _loadPlayerRankings(); // 使用缓存机制加载数据
          //   }
          // }),
        ],
      ),
    );
  }

  // 构建筛选按钮
  Widget _buildFilterButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // 构建球员列表项
  Widget _buildPlayerItem(dynamic player, int rank) {
    final String name = player['Name'] ?? '';
    final String firstName = player['FirstName'] ?? '';
    final String lastName = player['LastName'] ?? '';
    final String countryCode = player['CountryCode'] ?? '';
    final String points = player['Points'] ?? '';
    final int movement = (player['Movement'] as num?)?.toInt() ?? 0;
    final String urlCountryFlag = player['UrlCountryFlag'] ?? '';
    final String urlHeadshotImage = player['UrlHeadshotImage'] ?? '';

    // 确定排名变化的颜色和图标
    Color movementColor = _neutralColor;
    IconData movementIcon = Icons.remove;
    if (movement > 0) {
      movementColor = _upColor;
      movementIcon = Icons.arrow_drop_up;
    } else if (movement < 0) {
      movementColor = _downColor;
      movementIcon = Icons.arrow_drop_down;
    }

    return GestureDetector(
      onTap: () {
        // 导航到球员详情页
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerDetailsPage(
              playerId: player['PlayerId'] ?? '',
              playerName: name.isNotEmpty ? name : '$lastName $firstName',
              playerCountry: countryCode,
              playerColor: _primaryColor,
              type: _showATP ? 'atp' : 'wta',
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 0.5,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              // 头像 - 使用占位图片如果没有头像URL
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[800],
                child: ClipOval(
                  child: Image.network(
                    urlHeadshotImage.isNotEmpty
                        ? urlHeadshotImage.startsWith('http')
                            ? urlHeadshotImage
                            : 'https://www.atptour.com$urlHeadshotImage'
                        : _showATP
                            ? 'https://www.atptour.com/-/media/alias/player-headshot/default-player-headshot.png'
                            : 'https://www.atptour.com/assets/tournament/assets/headshot_placeholder.jpg',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.person,
                        color: Colors.white.withOpacity(0.7),
                        size: 24,
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 姓名和积分
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name.isNotEmpty
                              ? _formatPlayerName(
                                  name.replaceAll(RegExp(r'[\r\n]+'), ''))
                              : _formatPlayerName('$lastName $firstName'
                                  .replaceAll(RegExp(r'[\r\n]+'), '')),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          points,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Rank 和排名变动
              SizedBox(
                width: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '#$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 排名变动指示器
                    if (movement != 0)
                      Icon(
                        movementIcon,
                        color: movementColor,
                        size: 12,
                      )
                    else
                      const Icon(
                        Icons.remove,
                        color: Color(0xFF6B6B6B),
                        size: 12,
                      ),
                    Text(
                      movement != 0 ? '${movement.abs()}' : '',
                      style: TextStyle(
                        color: movement != 0
                            ? movementColor
                            : const Color(0xFF6B6B6B),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Country Flag & Code
              SizedBox(
                width: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 国旗图片
                    _buildCountryFlag(urlCountryFlag, countryCode),
                    const SizedBox(width: 8),
                    // 国家代码
                    Text(
                      countryCode,
                      style: const TextStyle(
                        color: Color(0xFF6B6B6B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建国旗
  Widget _buildCountryFlag(String? flagUrl, String countryCode) {
    if (flagUrl != null && flagUrl.isNotEmpty) {
      if (flagUrl.toLowerCase().endsWith('.svg')) {
        // 处理SVG格式的国旗
        try {
          final String fullUrl = flagUrl.startsWith('http')
              ? flagUrl
              : 'https://atptour.com$flagUrl';
          return SvgPicture.network(
            fullUrl,
            width: 22,
            height: 16,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 22,
              height: 16,
              color: Colors.grey.withOpacity(0.3),
              child: const Icon(Icons.flag, size: 12, color: Colors.grey),
            ),
            placeholderBuilder: (BuildContext context) => Container(
              width: 22,
              height: 16,
              color: Colors.grey[800],
            ),
          );
        } catch (e) {
          print('加载SVG失败: $e');
        }
      }

      // 处理其他格式的国旗
      return Container(
        width: 22,
        height: 16,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
              flagUrl.startsWith('http')
                  ? flagUrl
                  : 'https://atptour.com$flagUrl',
            ),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 0.5,
          ),
        ),
      );
    }

    // 如果没有国旗URL，显示国家代码的第一个字母
    return Container(
      width: 22,
      height: 16,
      decoration: BoxDecoration(
        color: const Color(0xFF6B6B6B),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        countryCode.isNotEmpty ? countryCode[0] : '',
        style: const TextStyle(
          color: Color(0xFF6B6B6B),
          fontSize: 8,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
