import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyUtils {
  static const String _privacyAcceptedKey = 'privacy_accepted';

  // 检查用户是否已接受隐私政策
  static Future<bool> hasAcceptedPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_privacyAcceptedKey) ?? false;
  }

  // 标记用户已接受隐私政策
  static Future<void> markPrivacyAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyAcceptedKey, true);
  }

  // 显示隐私政策对话框
  static Future<bool> showPrivacyDialog(BuildContext context) async {
    final bool hasAccepted = await hasAcceptedPrivacy();
    
    // 如果用户已经接受，直接返回true
    if (hasAccepted) {
      return true;
    }
    
    // 显示隐私政策对话框
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Privacy Policy & Terms of Service',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to Tennis App!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'By using this app, you agree to our Privacy Policy and Terms of Service. We collect certain information to improve your experience and provide our services.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The app collects the following information:',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                _buildBulletPoint('Device information'),
                _buildBulletPoint('App usage data'),
                _buildBulletPoint('User preferences'),
                const SizedBox(height: 12),
                const Text(
                  'You can review our full Privacy Policy and Terms of Service on our website.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Decline', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Accept'),
              onPressed: () async {
                await markPrivacyAccepted();
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
    
    return result ?? false;
  }
  
  static Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.white70)),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}