import 'package:LoveGame/pages/player_details_page.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

class TennisScoreCard extends StatelessWidget {
  final String player1;
  final String player2;
  final String player1Rank;
  final String player2Rank;
  final String player1Country;
  final String player2Country;
  final bool serving1;
  final bool serving2;
  final bool isLive;
  final String roundInfo;
  final List<int> set1Scores; // 第一位球员在每盘的得分
  final List<int> set2Scores; // 第二位球员在每盘的得分
  final List<int> tiebreak1; // 第一位球员在抢七中的小分
  final List<int> tiebreak2; // 第二位球员在抢七中的小分
  final String currentGameScore1; // 当前局的得分 (0, 15, 30, 40, Ad)
  final String currentGameScore2;
  final String? matchDuration; // 比赛时长，仅用于已完成的比赛
  final VoidCallback? onWatchPressed;
  final VoidCallback? onDetailPressed;
  final bool isPlayer1Winner; // 新增：标识球员1是否为获胜者
  final bool isPlayer2Winner; // 新增：标识球员2是否为获胜者
  final String? matchType;
  final String? player1FlagUrl;
  final String? player2FlagUrl;
  final String? player1ImageUrl;
  final String? player2ImageUrl;
  final String? matchTime;
  final String? stadium;
  final String? tournamentName;
  // 添加球员ID参数
  final String? player1Id;
  final String? player2Id;
  final String? typePlayer;

  const TennisScoreCard(
      {super.key,
      required this.player1,
      required this.player2,
      this.player1Rank = '',
      this.player2Rank = '',
      required this.player1Country,
      required this.player2Country,
      this.serving1 = false,
      this.serving2 = false,
      this.isLive = true,
      required this.roundInfo,
      required this.set1Scores,
      required this.set2Scores,
      this.tiebreak1 = const [],
      this.tiebreak2 = const [],
      this.currentGameScore1 = '0',
      this.currentGameScore2 = '0',
      this.matchDuration,
      this.onWatchPressed,
      this.onDetailPressed,
      this.isPlayer1Winner = false, // 默认为false
      this.isPlayer2Winner = false, // 默认为false
      this.matchType,
      this.player2FlagUrl,
      this.player1FlagUrl,
      this.player1ImageUrl,
      this.player2ImageUrl,
      this.matchTime,
      this.stadium,
      this.tournamentName,
      this.player1Id,
      this.player2Id,
      this.typePlayer});
  String _formatPlayerName(String name) {
    // 如果名称超过16个字符，按空格分隔，取第一个元素的第一个字母加空格连接最后一个元素
    if (name.length > 13) {
      List<String> nameParts = name.split(' ');
      if (nameParts.length > 1) {
        String firstName = nameParts.first;

        String lastName = nameParts.last;
        if (lastName.contains('-')) {
          List<String> lastNameParts = name.split('-');
          return '${firstName[0]}. ${lastNameParts[1]}';
        } else {
          return '${firstName[0]}. $lastName';
        }
      }
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    // 获取国旗图片URL

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const backgroundColor = Color(0xFF0C0D0C); // 使用深灰色背景
    final borderColor = Colors.white.withOpacity(0.04); // 减小边框透明度，使其更加微妙

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5), // 减小边框宽度
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 显示比赛状态和回合信息
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 8.0),
            child: Row(
              children: [
                // 直播或已完成状态指示器
                if (isLive)
                  GestureDetector(
                    onTap: () async {
                      final Uri url =
                          Uri.parse('https://www.haixing.cc/live?type=5');
                      if (!await launchUrl(url)) {
                        throw Exception('无法打开 $url');
                      }
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFF94E831),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF94E831).withOpacity(0.3),
                                blurRadius: 6,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Color(0xFF94E831),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      Text(
                        matchType.toString().toLowerCase() == 'completed'
                            ? 'Completed'
                            : 'Schedule',
                        style: const TextStyle(
                          color: Color(0xFFAC49FF),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 6),
                Text(
                  '${tournamentName.toString().replaceAll(RegExp(r'[\r\n]+'), '')},$roundInfo',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // 分隔线
          Divider(
            height: 1,
            thickness: 1,
            color: borderColor,
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(0.0, 12.0, 12.0, 10.0),
            child: Column(
              children: [
                // 比分表格
                LayoutBuilder(builder: (context, constraints) {
                  // 计算每列的宽度
                  final availableWidth = constraints.maxWidth;
                  final playerColumnWidth = availableWidth * 0.55; // 球员名列宽度
                  // 确保所有行有相同数量的列
                  // 根据比赛局数动态确定总列数
                  // 获取最大局数，考虑到两位球员的得分
                  int maxSets = math.max(set1Scores.length, set2Scores.length);
                  // 确保至少显示3局，最多显示5局
                  maxSets = math.max(3, math.min(5, maxSets));
                  // 总列数 = 球员列 + 当前局分列(如果是直播) + 实际局数
                  final int totalColumns = 1 + (isLive ? 1 : 0) + maxSets;

                  // 计算每个比分列的宽度
                  final scoreColumnWidth =
                      (availableWidth - playerColumnWidth) / (totalColumns - 1);
                  final adjustedScoreColumnWidth =
                      math.max(scoreColumnWidth, 22.0);
                  // 创建列宽映射
                  final Map<int, TableColumnWidth> columnWidths = {
                    0: FixedColumnWidth(playerColumnWidth), // 球员名字列
                  };

                  // 为所有比分列设置相同宽度
                  for (int i = 1; i < totalColumns; i++) {
                    columnWidths[i] = FixedColumnWidth(scoreColumnWidth);
                  }
                  return Table(
                    defaultColumnWidth: FixedColumnWidth(scoreColumnWidth),
                    columnWidths: columnWidths,
                    children: [
                      TableRow(
                        children: [
                          // 球员1名称
                          TableCell(
                            verticalAlignment:
                                TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment:
                                    MainAxisAlignment.start, // 添加这一行
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (player1FlagUrl!.isNotEmpty)
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(4.0), // 国旗添加圆角
                                      child: SvgPicture.network(
                                        player1FlagUrl.toString().trim(),
                                        width: 22, // 国旗尺寸稍小
                                        height: 16,
                                        placeholderBuilder:
                                            (BuildContext context) => Container(
                                          width: 22,
                                          height: 16,
                                          color: Colors.grey.withOpacity(0.3),
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                        width: 22, // 国旗尺寸稍小
                                        height: 16,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: const Color(0xFFD7D9DC),
                                            width: 1,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        clipBehavior: Clip.hardEdge,
                                        child: null),
                                  const SizedBox(width: 6),
                                  // 添加球员头像
                                  GestureDetector(
                                    onTap: () {
                                      if (player1Id != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PlayerDetailsPage(
                                              playerId: player1Id!,
                                              playerName: player1,
                                              playerCountry: player1Country,
                                              playerColor:
                                                  const Color(0xFF94E831),
                                              type: typePlayer ?? 'atp',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: player1ImageUrl != null &&
                                                player1ImageUrl!.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: player1ImageUrl!,
                                                fit: BoxFit.cover,
                                                memCacheWidth: 120,
                                                maxWidthDiskCache: 120,
                                                errorWidget:
                                                    (context, url, error) {
                                                  return Container(
                                                    color: Colors.grey.shade800,
                                                    child: const Icon(
                                                      Icons.person,
                                                      color: Colors.white70,
                                                      size: 16,
                                                    ),
                                                  );
                                                },
                                              )
                                            : Container(
                                                color: Colors.grey.shade800,
                                                child: const Icon(
                                                  Icons.person,
                                                  color: Colors.white70,
                                                  size: 16,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                            child: Text(
                                          '${_formatPlayerName(player1.replaceAll(RegExp(r'[\r\n]+'), ''))} ${player1Rank.replaceAll(RegExp(r'[\r\n]+'), '')}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14.0,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        )),
                                        if (!isLive && isPlayer1Winner)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 4.0),
                                            child: Icon(
                                              Icons.check_circle,
                                              color: Color(0xFF94E831),
                                              size: 14.0,
                                            ),
                                          ),
                                        // 显示发球指示器
                                        if (isLive && serving1)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 8.0),
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF94E831),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.sports_tennis,
                                                color: Colors.black,
                                                size: 8,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isLive)
                            TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 8.0),
                                child: isLive
                                    ? Container(
                                        constraints:
                                            const BoxConstraints(minWidth: 22),
                                        child: Text(
                                          currentGameScore1.isNotEmpty &&
                                                  currentGameScore1 != 'null'
                                              ? currentGameScore1
                                              : '',
                                          style: const TextStyle(
                                            color: Color(0xFF94E831),
                                            fontSize: 14.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      )
                                    : const SizedBox(), // 非直播时为空
                              ),
                            ),
                          // 动态生成局分列
                          for (int i = 0; i < maxSets; i++)
                            TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Container(
                                alignment: Alignment.centerRight,
                                child: _buildSetScoreWidget(
                                  set1Scores.length > i
                                      ? set1Scores[i]
                                      : 0, // 球员1的分数
                                  set2Scores.length > i
                                      ? set2Scores[i]
                                      : 0, // 对手(球员2)的分数
                                  tiebreak1.length > i
                                      ? tiebreak1[i]
                                      : 0, // 球员1的抢七分
                                  tiebreak2.length > i
                                      ? tiebreak2[i]
                                      : 0, // 对手的抢七分
                                  isPlayer1: true,
                                ),
                              ),
                            ),
                        ],
                      ),
                      // 球员之间的间隔
                      TableRow(
                        children: [
                          TableCell(
                              child: SizedBox(height: isLive ? 6.0 : 10.0)),
                          if (isLive)
                            TableCell(
                                child: SizedBox(height: isLive ? 6.0 : 10.0)),
                          for (int i = 0; i < maxSets; i++)
                            TableCell(
                                child: SizedBox(height: isLive ? 6.0 : 10.0)),
                        ],
                      ),
                      // 球员2信息
                      TableRow(
                        children: [
                          // 球员2名称
                          TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment:
                                      MainAxisAlignment.start, // 添加这一行
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (player2FlagUrl!.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                            4.0), // 国旗添加圆角
                                        child: SvgPicture.network(
                                          player2FlagUrl!,
                                          width: 22, // 国旗尺寸稍小
                                          height: 16,
                                          placeholderBuilder:
                                              (BuildContext context) =>
                                                  Container(
                                            width: 22,
                                            height: 16,
                                            color: Colors.grey.withOpacity(0.3),
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                          width: 22, // 国旗尺寸稍小
                                          height: 16,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: const Color(0xFFD7D9DC),
                                              width: 1,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          clipBehavior: Clip.hardEdge,
                                          child: null),
                                    const SizedBox(width: 6),
                                    // 添加球员头像
                                    GestureDetector(
                                      onTap: () {
                                        if (player2Id != null) {
                                          debugPrint(
                                              'onTap: $player2Id,$player2Country');

                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  PlayerDetailsPage(
                                                playerId: player2Id!,
                                                playerName: player2,
                                                playerCountry: player2Country,
                                                playerColor:
                                                    const Color(0xFF94E831),
                                                type: typePlayer ?? 'atp',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.2),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: player2ImageUrl != null &&
                                                  player2ImageUrl!.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: player2ImageUrl!,
                                                  fit: BoxFit.cover,
                                                  memCacheWidth: 120,
                                                  maxWidthDiskCache: 120,
                                                  errorWidget: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      color:
                                                          Colors.grey.shade800,
                                                      child: const Icon(
                                                        Icons.person,
                                                        color: Colors.white70,
                                                        size: 16,
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Container(
                                                  color: Colors.grey.shade800,
                                                  child: const Icon(
                                                    Icons.person,
                                                    color: Colors.white70,
                                                    size: 16,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                              child: Text(
                                            '${_formatPlayerName(player2.replaceAll(RegExp(r'[\r\n]+'), ''))} ${player2Rank.replaceAll(RegExp(r'[\r\n]+'), '')}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14.0,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          )),
                                          if (!isLive && isPlayer2Winner)
                                            const Padding(
                                              padding:
                                                  EdgeInsets.only(left: 4.0),
                                              child: Icon(
                                                Icons.check_circle,
                                                color: Color(0xFF94E831),
                                                size: 14.0,
                                              ),
                                            ),
                                          // 显示发球指示器
                                          if (isLive && serving2)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 8.0),
                                              child: Container(
                                                width: 12,
                                                height: 12,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF94E831),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.sports_tennis,
                                                  color: Colors.black,
                                                  size: 8,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          if (isLive)
                            TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 8.0),
                                child: isLive
                                    ? Text(
                                        currentGameScore2.isNotEmpty &&
                                                currentGameScore2 != 'null'
                                            ? currentGameScore2
                                            : '',
                                        style: const TextStyle(
                                          color: Color(0xFF94E831),
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : const SizedBox(), // 非直播时为空
                              ),
                            ),
                          for (int i = 0; i < maxSets; i++)
                            TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Container(
                                alignment: Alignment.centerRight,
                                child: _buildSetScoreWidget(
                                  set2Scores.length > i
                                      ? set2Scores[i]
                                      : 0, // 球员2的分数
                                  set1Scores.length > i
                                      ? set1Scores[i]
                                      : 0, // 对手(球员1)的分数
                                  tiebreak2.length > i
                                      ? tiebreak2[i]
                                      : 0, // 球员2的抢七分
                                  tiebreak1.length > i
                                      ? tiebreak1[i]
                                      : 0, // 对手的抢七分
                                  isPlayer1: false,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                }),
                Padding(
                  padding:
                      const EdgeInsets.only(left: 12, top: 14.0, bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // 两端对齐
                    children: [
                      // 左侧显示比赛时间
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_outlined,
                            size: 14,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            matchTime != null && matchTime!.isNotEmpty
                                ? matchTime!.replaceAll(RegExp(r'[\r\n]+'), '')
                                : matchType.toString().toLowerCase() ==
                                            'completed' ||
                                        matchType.toString().toLowerCase() ==
                                            'live'
                                    ? '-'
                                    : 'To Be Determined',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),

                      // 右侧显示比赛地点
                      Row(
                        children: [
                          if (stadium != null && stadium!.isNotEmpty)
                            Image.asset(
                              'assets/images/icon_stadium.png',
                              width: 14,
                              height: 14,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          const SizedBox(width: 4),
                          Text(
                            stadium != null && stadium!.isNotEmpty
                                ? stadium!.replaceAll(RegExp(r'[\r\n]+'), '')
                                : '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 0.0),

                // 按钮区域

                Padding(
                    padding: const EdgeInsets.fromLTRB(
                        12.0, 0.0, 0.0, 0.0), // 添加12像素的边距
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 详情按钮
                        Expanded(
                          flex: 1, // 占50%宽度
                          child: TextButton(
                            onPressed: onDetailPressed,
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF0C0D0C),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              foregroundColor: Colors.white.withOpacity(0.7),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                    color: Colors.white.withOpacity(0.1)),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Match detail',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10), // 中间间距10像素
                        // 观看按钮
                        Expanded(
                          flex: 1, // 占50%宽度
                          child: TextButton(
                            onPressed: onWatchPressed,
                            style: TextButton.styleFrom(
                              backgroundColor: isLive
                                  ? const Color(0xFF94E831)
                                  : const Color(0xFF0C0D0C),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                    color: Colors.white.withOpacity(0.1)),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Watch',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isLive
                                      ? const Color(0xFF0C0D0C)
                                      : Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ))
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 根据国家代码获取国旗图片URL

  String formatGameScore(int points) {
    switch (points) {
      case 0:
        return '0';
      case 1:
        return '15';
      case 2:
        return '30';
      case 3:
        return '40';
      case 4:
        return 'Ad';
      default:
        return '';
    }
  }

  bool isDeuce(int player1Points, int player2Points) {
    return player1Points >= 3 &&
        player2Points >= 3 &&
        player1Points == player2Points;
  }

  String getCurrentGameScore(int player1Points, int player2Points) {
    if (isDeuce(player1Points, player2Points)) {
      return '40';
    }

    if (player1Points >= 3 && player2Points >= 3) {
      if (player1Points > player2Points) {
        return 'Ad';
      } else if (player2Points > player1Points) {
        return '40';
      }
    }

    return formatGameScore(player1Points);
  }

  Widget _buildSetScoreWidget(
      int playerScore, int opponentScore, int playerTie, int opponentTie,
      {bool isPlayer1 = true}) {
    // 直接查找此列的索引
    // debugPrint(
    //     'playerScore: $playerScore, opponentScore: $opponentScore,playerTie: $playerTie, opponentTie: $opponentTie');

    // 抢七情况的处理
    bool isStandardTiebreak = (playerTie != 0 || opponentTie != 0) ||
        ((playerScore == 7 && opponentScore == 6) ||
            (playerScore == 6 && opponentScore == 7));
    bool isExtendedTiebreak = (playerTie > 7 || opponentTie > 7);

    // 判断是否显示小分
    // debugPrint('isStandardTiebreak: $isStandardTiebreak');
    // 标准抢七(7-6)：小分显示在输的一方
    if (isStandardTiebreak) {
      bool isLosingPlayer = playerScore < opponentScore;

      if (isLosingPlayer) {
        return _buildTiebreakScore(playerScore, playerTie);
      }
    }
    // 延长抢七(>7分)：双方都显示小分
    else if (isExtendedTiebreak) {
      return _buildTiebreakScore(playerScore, opponentTie);
    }

    // 常规情况，直接显示分数
    return Stack(
      clipBehavior: Clip.none, // 允许超出父容器
      alignment: Alignment.center,
      children: [
        Text(
          playerScore.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15.0,
          ),
        ),
        const SizedBox(height: 16.0),
      ],
    );
  }

  // 创建显示抢七小分的Widget
  Widget _buildTiebreakScore(int score, int tiebreakPoint) {
    return Stack(
      clipBehavior: Clip.none, // 允许超出父容器
      alignment: Alignment.center,
      children: [
        Text(
          score.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15.0,
          ),
        ),
        Positioned(
          top: -5,
          right: -12,
          child: Text(
            '($tiebreakPoint)',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 9.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
