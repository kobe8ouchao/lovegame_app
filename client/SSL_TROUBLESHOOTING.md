# SSL Certificate Troubleshooting Guide

## 问题描述
您的Flutter应用遇到了SSL证书验证失败的错误：
```
CERTIFICATE_VERIFY_FAILED: application verification failure(handshake.cc:295)
```

## 解决方案

### 1. 已实现的解决方案

我们已经在代码中实现了以下解决方案：

#### SSL配置工具 (`lib/utils/ssl_config.dart`)
- 自动配置SSL设置
- 开发环境和生产环境的不同配置
- 创建支持SSL的HTTP客户端

#### 增强HTTP服务 (`lib/services/http_service.dart`)
- 自动检测SSL错误
- 多种备用方案：
  - 使用代理服务器
  - HTTP回退（如果可能）
  - 自定义HTTP客户端（仅开发环境）

#### 更新的API服务 (`lib/services/api_service.dart`)
- 所有HTTP请求都使用新的HttpService
- 自动错误处理和重试机制

### 2. 使用方法

#### 自动配置
SSL配置会在应用启动时自动初始化：
```dart
void main() {
  SSLConfig.configureSSL(); // 自动配置SSL
  runApp(const MyApp());
}
```

#### HTTP请求
所有HTTP请求现在都使用HttpService，它会自动处理SSL问题：
```dart
// 之前
final response = await http.get(uri);

// 现在
final response = await HttpService.get(uri);
```

### 3. 代理服务器配置

如果SSL问题持续存在，系统会自动尝试以下代理服务器：
- `https://thingproxy.freeboard.io/fetch/`
- `https://api.allorigins.win/raw?url=`
- `https://cors-anywhere.herokuapp.com/`

### 4. 开发环境特殊处理

在开发环境中（`kDebugMode = true`），系统会：
- 使用更宽松的SSL验证
- 接受自签名证书
- 提供详细的调试信息

### 5. 生产环境注意事项

在生产环境中：
- 使用严格的SSL验证
- 不接受自签名证书
- 确保所有API端点使用有效的SSL证书

### 6. 故障排除

#### 如果问题仍然存在：

1. **检查网络连接**
   - 确保设备有稳定的网络连接
   - 检查防火墙设置

2. **检查API端点**
   - 验证ATP Tour和WTA Tennis的API是否可访问
   - 检查这些网站是否正常运行

3. **更新证书**
   - 在iOS上，确保设备信任相关证书
   - 在Android上，检查系统证书存储

4. **使用代理**
   - 如果直接访问失败，系统会自动尝试代理服务器
   - 可以手动配置其他代理服务器

### 7. 代码示例

#### 错误处理
```dart
try {
  final response = await HttpService.get(uri);
  // 处理响应
} catch (e) {
  final errorMessage = HttpService.getErrorMessage(e);
  // 显示用户友好的错误消息
}
```

#### 自定义SSL配置
```dart
// 在开发环境中
if (kDebugMode) {
  final client = SSLConfig.createHttpClient();
  // 使用自定义客户端
}
```

### 8. 联系支持

如果问题持续存在，请：
1. 检查Flutter和Dart版本
2. 查看完整的错误日志
3. 确认目标API的状态
4. 提供设备信息和操作系统版本

## 更新日志

- **2025-08-15**: 实现SSL配置工具和增强HTTP服务
- **2025-08-15**: 更新所有API服务使用新的HTTP服务
- **2025-08-15**: 添加自动SSL配置初始化 