/*
 * @Descripttion: 
 * @Author: ouchao
 * @Email: ouchao@sendpalm.com
 * @version: 1.0
 * @Date: 2025-04-15 14:20:32
 * @LastEditors: ouchao
 * @LastEditTime: 2026-01-17 15:22:57
 */
import 'package:LoveGame/pages/splash_screen.dart';
import 'package:LoveGame/utils/constants.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'pages/home_page.dart';
import 'pages/tournament_calendar_page.dart';
import 'pages/player_rankings_page.dart'; // 添加排名页面导入
import 'utils/ssl_config.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

void main() {
  // 初始化SSL配置
  SSLConfig.configureSSL();

  // 设置全局状态栏样式
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: LiquidGlassLayer(
                        settings: LiquidGlassSettings(
                          thickness: 15,
                          blur: 8,
                          refractiveIndex: 1.2,
                          lightIntensity: 0.7,
                          saturation: 1.1,
                          lightAngle: 0.5 * math.pi,
                          glassColor: Colors.white.withOpacity(0.1),
                        ),
                        child: LiquidGlass(
                          shape: LiquidRoundedSuperellipse(
                            borderRadius: 20,
                          ),
                          child: Container(),
                        ),
                      ),
                    ),
                    BottomNavigationBar(
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
                      selectedItemColor: primaryColor,
                      unselectedItemColor: Colors.grey,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
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
                  ],
                ))));
  }
}
