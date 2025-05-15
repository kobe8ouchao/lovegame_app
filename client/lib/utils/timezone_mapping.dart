import 'package:flutter/foundation.dart';

/// 网球赛事地点到时区的映射表
class TimezoneMapping {
  /// 城市到时区偏移的映射（小时）
  /// 注意：这里的偏移是相对于UTC的，正值表示UTC以东，负值表示UTC以西
  /// 夏令时和冬令时的切换需要单独处理
  static final Map<String, Map<String, dynamic>> locationToTimezone = {
    // 澳大利亚和新西兰
    'Perth-Sydney, Australia': {
      'offset': 10,
      'code': 'AEST',
      'location': 'Australia/Sydney'
    },
    'Brisbane, Australia': {
      'offset': 10,
      'code': 'AEST',
      'location': 'Australia/Brisbane'
    },
    'Melbourne, Australia': {
      'offset': 10,
      'code': 'AEST',
      'location': 'Australia/Melbourne'
    },
    'Adelaide, Australia': {
      'offset': 9.5,
      'code': 'ACST',
      'location': 'Australia/Adelaide'
    },
    'Auckland, New Zealand': {
      'offset': 12,
      'code': 'NZST',
      'location': 'Pacific/Auckland'
    },

    // 亚洲
    'Hong Kong, Hong Kong': {
      'offset': 8,
      'code': 'HKT',
      'location': 'Asia/Hong_Kong'
    },
    'Shanghai, China': {
      'offset': 8,
      'code': 'CST',
      'location': 'Asia/Shanghai'
    },
    'Beijing, China': {'offset': 8, 'code': 'CST', 'location': 'Asia/Shanghai'},
    'Tokyo, Japan': {'offset': 9, 'code': 'JST', 'location': 'Asia/Tokyo'},
    'Seoul, Korea': {'offset': 9, 'code': 'KST', 'location': 'Asia/Seoul'},
    'Singapore, Singapore': {
      'offset': 8,
      'code': 'SGT',
      'location': 'Asia/Singapore'
    },
    'Dubai, UAE': {'offset': 4, 'code': 'GST', 'location': 'Asia/Dubai'},
    'Doha, Qatar': {'offset': 3, 'code': 'AST', 'location': 'Asia/Qatar'},

    // 欧洲
    'Rotterdam, Netherlands': {
      'offset': 1,
      'code': 'CET',
      'location': 'Europe/Amsterdam'
    },
    'Montpellier, France': {
      'offset': 1,
      'code': 'CET',
      'location': 'Europe/Paris'
    },
    'Marseille, France': {
      'offset': 1,
      'code': 'CET',
      'location': 'Europe/Paris'
    },
    'Paris, France': {'offset': 1, 'code': 'CET', 'location': 'Europe/Paris'},
    'Rome, Italy': {'offset': 1, 'code': 'CET', 'location': 'Europe/Rome'},
    'Madrid, Spain': {'offset': 1, 'code': 'CET', 'location': 'Europe/Madrid'},
    'Barcelona, Spain': {
      'offset': 1,
      'code': 'CET',
      'location': 'Europe/Madrid'
    },
    'Monte Carlo, Monaco': {
      'offset': 1,
      'code': 'CET',
      'location': 'Europe/Monaco'
    },
    'London, UK': {'offset': 0, 'code': 'GMT', 'location': 'Europe/London'},
    'Geneva, Switzerland': {
      'offset': 1,
      'code': 'CET',
      'location': 'Europe/Zurich'
    },
    'Munich, Germany': {
      'offset': 1,
      'code': 'CET',
      'location': 'Europe/Berlin'
    },
    'Stuttgart, Germany': {
      'offset': 1,
      'code': 'CET',
      'location': 'Europe/Berlin'
    },
    'Hamburg, Germany': {
      'offset': 1,
      'code': 'CET',
      'location': 'Europe/Berlin'
    },
    'Vienna, Austria': {
      'offset': 1,
      'code': 'CET',
      'location': 'Europe/Vienna'
    },
    'Stockholm, Sweden': {
      'offset': 1,
      'code': 'CET',
      'location': 'Europe/Stockholm'
    },

    // 北美洲
    'Dallas, United States': {
      'offset': -6,
      'code': 'CST',
      'location': 'America/Chicago'
    },
    'New York, United States': {
      'offset': -5,
      'code': 'EST',
      'location': 'America/New_York'
    },
    'Miami, United States': {
      'offset': -5,
      'code': 'EST',
      'location': 'America/New_York'
    },
    'Indian Wells, United States': {
      'offset': -8,
      'code': 'PST',
      'location': 'America/Los_Angeles'
    },
    'Los Angeles, United States': {
      'offset': -8,
      'code': 'PST',
      'location': 'America/Los_Angeles'
    },
    'Cincinnati, United States': {
      'offset': -5,
      'code': 'EST',
      'location': 'America/New_York'
    },
    'Atlanta, United States': {
      'offset': -5,
      'code': 'EST',
      'location': 'America/New_York'
    },
    'Washington, United States': {
      'offset': -5,
      'code': 'EST',
      'location': 'America/New_York'
    },
    'Montreal, Canada': {
      'offset': -5,
      'code': 'EST',
      'location': 'America/Toronto'
    },
    'Toronto, Canada': {
      'offset': -5,
      'code': 'EST',
      'location': 'America/Toronto'
    },

    // 南美洲
    'Rio de Janeiro, Brazil': {
      'offset': -3,
      'code': 'BRT',
      'location': 'America/Sao_Paulo'
    },
    'Buenos Aires, Argentina': {
      'offset': -3,
      'code': 'ART',
      'location': 'America/Argentina/Buenos_Aires'
    },

    // 非洲
    'Johannesburg, South Africa': {
      'offset': 2,
      'code': 'SAST',
      'location': 'Africa/Johannesburg'
    },

    // 多地点或未知地点的默认值
    'Multiple Locations': {'offset': 0, 'code': 'UTC', 'location': 'UTC'},
  };

  /// 根据地点获取时区信息
  static Map<String, dynamic> getTimezoneByLocation(String location) {
    // 尝试直接匹配
    if (locationToTimezone.containsKey(location)) {
      return locationToTimezone[location]!;
    }

    // 尝试部分匹配（只匹配城市名）
    for (var entry in locationToTimezone.entries) {
      final locationParts = entry.key.split(',');
      if (locationParts.isNotEmpty) {
        final city = locationParts[0].trim();
        if (location.contains(city)) {
          return entry.value;
        }
      }
    }

    // 如果找不到匹配，返回UTC
    debugPrint('未找到地点 "$location" 的时区信息，使用UTC');
    return {'offset': 0, 'code': 'UTC', 'location': 'UTC'};
  }

  /// 将比赛地点时间转换为用户本地时间
  static DateTime convertToLocalTime(DateTime venueTime, String location) {
    final timezoneInfo = getTimezoneByLocation(location);

    final int offsetHours = timezoneInfo['offset'] as int;
    DateTime now = DateTime.now();
    int offsetLocalInHours = now.timeZoneOffset.inHours;
    // 计算与UTC的差值（小时）
    int offset = offsetLocalInHours - offsetHours;
    final DateTime utcTime = venueTime.subtract(Duration(hours: offsetHours));

    // 2. 将UTC时间转换为本地时间
    // 这里使用toLocal()方法，它会自动应用设备的本地时区
    return utcTime.add(Duration(hours: offset));
  }

  /// 检查是否需要考虑夏令时
  /// 注意：这是一个简化的实现，实际应用中应使用timezone包进行更精确的处理
  static bool isDST(DateTime dateTime, String location) {
    // 北半球夏令时通常在3月底到10月底
    // 南半球夏令时通常在10月底到3月底
    final int month = dateTime.month;

    // 澳大利亚、新西兰等南半球国家
    if (location.contains('Australia') || location.contains('New Zealand')) {
      return month >= 10 || month <= 3;
    }

    // 欧洲、北美等北半球国家
    return month >= 3 && month <= 10;
  }
}
