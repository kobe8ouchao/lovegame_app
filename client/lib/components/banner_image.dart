import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BannerImage extends StatelessWidget {
  final String imageUrl;
  final double height;
  final Widget? child;
  final double overlayOpacity;
  final bool hasForeground;

  const BannerImage({
    super.key,
    required this.imageUrl,
    this.height = 300.0,
    this.child,
    this.overlayOpacity = 0.35,
    this.hasForeground = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 图片
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            memCacheWidth: 1080,
            maxWidthDiskCache: 1080,
            errorWidget: (context, url, error) {
              return Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white.withOpacity(0.3),
                  size: 64,
                ),
              );
            },
            progressIndicatorBuilder: (context, url, downloadProgress) {
              return Center(
                child: CircularProgressIndicator(
                  value: downloadProgress.progress,
                  color: const Color(0xFF94E831),
                ),
              );
            },
          ),

          // 半透明黑色遮罩
          Container(
            color: Colors.black.withOpacity(overlayOpacity),
          ),

          // 前景子组件（如文字内容）
          if (hasForeground && child != null) child!,
        ],
      ),
    );
  }
}
