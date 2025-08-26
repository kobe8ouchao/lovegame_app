import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

/// SVG加载辅助类，提供错误处理和验证
class SvgHelper {
  /// 安全加载网络SVG，带有错误处理
  static Widget safeNetworkSvg({
    required String url,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Widget? placeholder,
    Widget? errorWidget,
    ColorFilter? colorFilter,
  }) {
    return FutureBuilder<Widget>(
      future: _loadSafeSvg(
        url: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: placeholder,
        errorWidget: errorWidget,
        colorFilter: colorFilter,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ?? _defaultPlaceholder(width, height);
        }
        
        if (snapshot.hasError || !snapshot.hasData) {
          return errorWidget ?? _defaultErrorWidget(width, height);
        }
        
        return snapshot.data!;
      },
    );
  }

  /// 异步加载和验证SVG
  static Future<Widget> _loadSafeSvg({
    required String url,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Widget? placeholder,
    Widget? errorWidget,
    ColorFilter? colorFilter,
  }) async {
    try {
      // 验证URL
      final uri = Uri.tryParse(url);
      if (url.isEmpty || uri == null || !uri.hasAbsolutePath) {
        throw Exception('Invalid URL');
      }

      // 预先验证SVG内容
      final isValid = await _validateSvgContent(url);
      if (!isValid) {
        throw Exception('Invalid SVG content');
      }

      // 如果验证通过，使用标准的SvgPicture.network
      return SvgPicture.network(
        url,
        width: width,
        height: height,
        fit: fit,
        placeholderBuilder: (context) => placeholder ?? _defaultPlaceholder(width, height),
        errorBuilder: (context, error, stackTrace) {
          debugPrint('SVG loading error for $url: $error');
          return errorWidget ?? _defaultErrorWidget(width, height);
        },
        colorFilter: colorFilter,
      );
    } catch (e) {
      debugPrint('SVG validation failed for $url: $e');
      return errorWidget ?? _defaultErrorWidget(width, height);
    }
  }

  /// 验证SVG内容是否有效
  static Future<bool> _validateSvgContent(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode != 200) {
        return false;
      }

      final content = response.body;
      
      // 基本的SVG内容验证
      if (!content.contains('<svg') || !content.contains('</svg>')) {
        return false;
      }

      // 检查是否包含明显的XML错误
      if (content.contains('<?xml') && !content.contains('?>')) {
        return false;
      }

      // 检查是否有未闭合的标签（简单验证）
      final openTags = '<'.allMatches(content).length;
      final closeTags = '>'.allMatches(content).length;
      if (openTags != closeTags) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('SVG content validation error: $e');
      return false;
    }
  }

  /// 默认占位符
  static Widget _defaultPlaceholder(double? width, double? height) {
    return Container(
      width: width ?? 24,
      height: height ?? 24,
      color: Colors.grey.withOpacity(0.3),
      child: const Center(
        child: SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
          ),
        ),
      ),
    );
  }

  /// 默认错误组件
  static Widget _defaultErrorWidget(double? width, double? height) {
    return Container(
      width: width ?? 24,
      height: height ?? 24,
      color: Colors.grey.withOpacity(0.3),
      child: Icon(
        Icons.flag,
        size: (width != null && height != null) ? (width + height) / 4 : 12,
        color: Colors.grey,
      ),
    );
  }

  /// 为国旗SVG提供专门的加载方法
  static Widget flagSvg({
    required String url,
    double width = 22,
    double height = 16,
  }) {
    return safeNetworkSvg(
      url: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorWidget: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Icon(
          Icons.flag,
          size: width * 0.6,
          color: Colors.grey,
        ),
      ),
    );
  }
}
