/*
 * @Descripttion: 
 * @Author: ouchao
 * @Email: ouchao@sendpalm.com
 * @version: 1.0
 * @Date: 2025-04-15 14:20:32
 * @LastEditors: ouchao
 * @LastEditTime: 2025-05-09 14:59:07
 */
import 'package:LoveGame/pages/splash_screen.dart';
import 'package:LoveGame/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'utils/constants.dart';
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'pages/tournament_calendar_page.dart';
import 'pages/player_rankings_page.dart'; // 添加排名页面导入
import 'utils/theme_provider.dart';
import 'services/platform_channel_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Love Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF94E831),
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(), // 使用启动页作为首页
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    HomePage(),
    TournamentCalendarPage(),
    PlayerRankingsPage(), // 添加排名页面
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    Color primaryColor = AppColors.primaryGreen;
    Color secondaryColor = const Color(0xFF121212);

    return Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens, // 包含 PlayerRankingsPage 的页面列表
        ),
        bottomNavigationBar: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: Container(
                decoration: BoxDecoration(
                  color: secondaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      spreadRadius: 1,
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: secondaryColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        spreadRadius: 1,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: BottomNavigationBar(
                    items: <BottomNavigationBarItem>[
                      BottomNavigationBarItem(
                        icon: SvgPicture.asset(
                          'assets/svg/tab_icon_tennis.svg',
                          width: 22,
                          height: 22,
                          colorFilter: const ColorFilter.mode(
                              Colors.grey, BlendMode.srcIn),
                        ),
                        label: 'Matches',
                        activeIcon: SvgPicture.asset(
                          'assets/svg/tab_icon_tennis.svg',
                          width: 22,
                          height: 22,
                          colorFilter:
                              ColorFilter.mode(primaryColor, BlendMode.srcIn),
                        ),
                      ),
                      BottomNavigationBarItem(
                        icon: SvgPicture.asset(
                          'assets/svg/tab_icon_calender.svg',
                          width: 22,
                          height: 22,
                          colorFilter: const ColorFilter.mode(
                              Colors.grey, BlendMode.srcIn),
                        ),
                        label: 'Tournnament',
                        activeIcon: SvgPicture.asset(
                          'assets/svg/tab_icon_calender.svg',
                          width: 22,
                          height: 22,
                          colorFilter:
                              ColorFilter.mode(primaryColor, BlendMode.srcIn),
                        ),
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.leaderboard),
                        label: 'Rankings',
                        activeIcon: Icon(Icons.leaderboard),
                      ),
                    ],
                    currentIndex: _selectedIndex,
                    elevation: 0.0,
                    selectedItemColor: primaryColor,
                    unselectedItemColor: Colors.grey,
                    backgroundColor: secondaryColor,
                    showSelectedLabels: true,
                    showUnselectedLabels: true,
                    type: BottomNavigationBarType.fixed,
                    selectedLabelStyle: const TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Roboto',
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Roboto',
                    ),
                    iconSize: 22.0,
                    onTap: _onItemTapped,
                  ),
                ))));
  }
}
