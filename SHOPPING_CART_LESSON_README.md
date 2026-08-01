# 购物车教材接入

## 1. 复制原项目代码

在 `flutter_ui_playground` 项目根目录运行：

```powershell
.\copy_shopping_cart_answers.ps1 `
  -ShoppingRoot "C:\你的路径\shoppingapp123"
```

脚本会把购物车相关原文件复制到：

```text
assets/lessons/shopping/cart/answers/
```

并逐个比较 SHA-256，确保标准答案与 `shoppingapp123` 原文件完全一致。

## 2. 注册 assets

在 `pubspec.yaml` 的 `flutter:` 下加入：

```yaml
assets:
  - assets/lessons/shopping/cart/answers/
```

已有 `assets:` 时，只追加目录，不要建立第二个 `assets:`。

## 3. 加入教材

把 `shopping_cart_lesson_snippet.dart` 中的：

```dart
static final _shoppingCartLesson = Lesson(...)
```

复制到 `LessonCatalog` 类内部。

然后在 `shoppingLessons` 中把原来的购物车预告替换成：

```dart
_shoppingCartLesson,
```

## 4. 检查

```powershell
dart format lib
flutter pub get
flutter analyze
flutter test
```

## 拆分结果

课程共 16 个步骤：

1. Product
2. CartItem
3. CartService / LocalCartService
4. CartRepository
5. CartProvider
6. CartItemTile
7. CartPage
8. CartIconButton
9. ProductDetails 加入购物车
10. ProductList 入口
11. HomePage 入口
12. MainPage 底部分页
13. main.dart 全局注入
14. CartItem 转 OrderItem
15. CheckoutProvider 读取和清空购物车
16. CheckoutPage 展示购物车
