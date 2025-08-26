import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../main.dart'; // 导入 MainNavigationScreen

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // 修改为 TickerProviderStateMixin
  // 球心高度
  double y = 140.0;
  // Y 轴速度（初始为0，让球自然下落）
  double vy = 0.0;
  // 重力（调整为更自然的下落速度）
  double gravity = 2.5;
  // 地面反弹力（增加反弹力，使球弹得更高）
  double bounce = -0.55;
  // 球的半径
  double radius = 50.0;
  // 地面高度（屏幕中心）
  double height = 0;
  // 弹跳次数计数
  int bounceCount = 0;
  // 最大弹跳次数
  int maxBounces = 6;

  // 添加文字动画控制器
  late AnimationController _textAnimationController;
  late Animation<double> _textOpacityAnimation;
  bool _showText = false;

  // 动画控制器
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // Ticker对象
  Ticker? _ticker;

  void _fall(_) {
    y += vy;
    vy += gravity;

    // 如果球体触及地面，根据地面反弹力改变球体的 Y 轴速度
    if (y + radius > height) {
      bounceCount++;
      y = height - radius;

      // 随着弹跳次数增加，减少反弹力
      if (bounceCount <= maxBounces) {
        vy *= bounce * (1 - bounceCount * 0.05);
      } else {
        // 最后一次弹跳后停止
        vy = 0;

        // 当球体停止弹跳时，显示文字并延迟一段时间后跳转到首页
        if (_ticker != null) {
          _ticker!.stop();
          _ticker!.dispose();
          _ticker = null;

          // 显示文字
          setState(() {
            _showText = true;
          });

          // 启动文字动画
          _textAnimationController.forward();

          // 延迟2000毫秒后跳转，让用户看到完整的文字动画
          Timer(const Duration(milliseconds: 1000), () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (context) => const MainNavigationScreen()),
            );
          });
        }
      }
    } else if (y - radius < 0) {
      y = 0 + radius;
      vy *= bounce * 0.1; // 触顶反弹力较弱
    }

    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    // 设置状态栏为白色
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    // 创建动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 创建文字动画控制器
    _textAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 创建缩放动画
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 70,
      ),
    ]).animate(_animationController);

    // 创建透明度动画
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    ));

    // 创建文字透明度动画
    _textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textAnimationController,
      curve: Curves.easeIn,
    ));

    // 启动动画
    _animationController.forward();

    // 延迟启动物理弹跳动画
    Timer(const Duration(milliseconds: 1000), () {
      // 使用一个 Ticker 在每次更新界面时运行球体下落方法
      _ticker = Ticker(_fall)..start();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textAnimationController.dispose();
    if (_ticker != null) {
      _ticker!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 在 build 方法中获取屏幕尺寸并设置 height
    // 获取屏幕尺寸和安全区域信息
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final padding = mediaQuery.padding;

    // 计算可视区域高度（减去状态栏和底部安全区域）
    final visibleHeight = size.height - padding.top - padding.bottom;

    // 设置高度为可视区域的中心点
    height = visibleHeight / 2 + padding.top - 50;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A1A),
              Color(0xFF000000),
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, y - height),
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 网球图标
                        Container(
                          width: radius * 2.5,
                          height: radius * 2.5,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF94E831).withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 0.1,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/icon_tennis.png',
                              width: radius * 2.5,
                              height: radius * 2.5,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                // 如果图片加载失败，显示备用的绿色圆形
                                return Container(
                                  width: radius * 2.5 - 10,
                                  height: radius * 2.5 - 10,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF94E831),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        // 添加文字动画
                        SizedBox(
                          height: 70, // 预留足够的空间
                          child: _showText
                              ? AnimatedBuilder(
                                  animation: _textAnimationController,
                                  builder: (context, child) {
                                    return Opacity(
                                      opacity: _textOpacityAnimation.value,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(top: 20.0),
                                        child: Text(
                                          'Love Game Tennis',
                                          style: TextStyle(
                                            fontFamily:
                                                'Georgia', // 使用Georgia字体
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(
                                                blurRadius: 10.0,
                                                color: const Color(0xFF94E831)
                                                    .withOpacity(0.5),
                                                offset: const Offset(0, 0),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : const SizedBox(), // 空占位符
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
