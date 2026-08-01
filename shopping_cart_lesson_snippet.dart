// 放进 LessonCatalog 类里面。
// shoppingLessons 中把原来的购物车 _comingSoon(...) 替换为：
// _shoppingCartLesson,

static final _shoppingCartLesson = Lesson(
  id: 'shopping-cart-complete',
  title: '完整购物车',
  description:
      '完全按照 shoppingapp123 的原始代码，完成购物车模型、'
      '本地持久化、Repository、Provider、页面、入口、全局注入和结算衔接。',
  difficulty: '高级完整项目版',
  category: '购物车',
  tags: const [
    'Model',
    'SharedPreferences',
    'Repository',
    'Provider',
    'UI',
    'Integration',
  ],
  estimatedMinutes: 360,
  prerequisites: const [
    '了解 Dart class 和 factory',
    '了解 async/await',
    '了解 ChangeNotifier 与 Provider',
    '了解 Service / Repository 分层',
  ],
  steps: [
    LessonStep(
      id: 'shopping-cart-part-01-product-model',
      part: 'Part 1：商品模型',
      title: '建立 Product',
      instruction:
          '按照原项目完整建立 Product 字段、JSON 转换和测试商品数据。',
      stepType: LessonStepType.model,
      explanation:
          '购物车会保存完整 Product，因此商品必须先支持 toJson 和 fromJson。',
      starterCode: '''class Product {
}
''',
      standardAnswerAssets: const {
        'product.dart':
            'assets/lessons/shopping/cart/answers/product.dart',
      },
      hints: const [
        '字段包括 id、categoryId、title、image、price 和 sold。',
        'price 从 JSON 读取时转换为 double。',
        'sold 从 JSON 读取时转换为 int。',
      ],
      requirements: const [
        RequiredClassRequirement('Product'),
        RequiredFieldRequirement('id'),
        RequiredFieldRequirement('categoryId'),
        RequiredFieldRequirement('title'),
        RequiredFieldRequirement('image'),
        RequiredFieldRequirement('price'),
        RequiredFieldRequirement('sold'),
        RequiredMethodRequirement('toJson'),
        RequiredCodeIdentifierRequirement('fromJson'),
        RequiredCodeIdentifierRequirement('products'),
      ],
      relatedFiles: const ['product.dart'],
      checkMode: CheckMode.dartAst,
    ),
    LessonStep(
      id: 'shopping-cart-part-02-cart-item',
      part: 'Part 2：购物车项目模型',
      title: '建立 CartItem',
      instruction:
          '按照原项目建立商品、数量、小计、copyWith 和 JSON 转换。',
      stepType: LessonStepType.model,
      explanation:
          'CartItem 把 Product 和 quantity 组合成一条可保存的购物车数据。',
      starterCode: '''class CartItem {
}
''',
      standardAnswerAssets: const {
        'cart_item.dart':
            'assets/lessons/shopping/cart/answers/cart_item.dart',
      },
      hints: const [
        'subtotal 等于商品价格乘以数量。',
        'copyWith 用于数量增加或减少。',
        'toJson 必须继续调用 product.toJson()。',
      ],
      requirements: const [
        RequiredClassRequirement('CartItem'),
        RequiredFieldRequirement('product'),
        RequiredFieldRequirement('quantity'),
        RequiredCodeIdentifierRequirement('subtotal'),
        RequiredMethodRequirement('copyWith'),
        RequiredMethodRequirement('toJson'),
        RequiredCodeIdentifierRequirement('fromJson'),
      ],
      relatedFiles: const ['cart_item.dart'],
      checkMode: CheckMode.dartAst,
    ),
    LessonStep(
      id: 'shopping-cart-part-03-cart-service',
      part: 'Part 3：本地购物车服务',
      title: '使用 SharedPreferences 保存购物车',
      instruction:
          '完整实现 CartService 和 LocalCartService，包括读取、保存、清除和损坏数据恢复。',
      stepType: LessonStepType.service,
      explanation:
          'Service 只负责把购物车转换为 JSON 并写入本地，不处理页面状态。',
      starterCode: '''abstract class CartService {
}

class LocalCartService implements CartService {
}
''',
      standardAnswerAssets: const {
        'cart_service.dart':
            'assets/lessons/shopping/cart/answers/cart_service.dart',
      },
      hints: const [
        '使用 SharedPreferencesAsync。',
        '保存前使用 jsonEncode。',
        '读取后使用 jsonDecode 和 CartItem.fromJson。',
        '损坏数据要 remove 后返回空列表。',
      ],
      requirements: const [
        RequiredClassRequirement('CartService'),
        RequiredClassRequirement('LocalCartService'),
        RequiredMethodRequirement('loadItems'),
        RequiredMethodRequirement('saveItems'),
        RequiredMethodRequirement('clear'),
        RequiredMethodCallRequirement('getString'),
        RequiredMethodCallRequirement('setString'),
        RequiredMethodCallRequirement('jsonDecode'),
        RequiredMethodCallRequirement('jsonEncode'),
        RequiredAwaitRequirement(),
      ],
      relatedFiles: const ['cart_service.dart'],
      checkMode: CheckMode.dartAst,
    ),
    LessonStep(
      id: 'shopping-cart-part-04-cart-repository',
      part: 'Part 4：购物车 Repository',
      title: '隔离数据来源',
      instruction:
          '建立 CartRepository，把 Provider 与 CartService 隔开。',
      stepType: LessonStepType.service,
      explanation:
          'Repository 对上提供购物车语义，对下转发给具体 Service。',
      starterCode: '''class CartRepository {
}
''',
      standardAnswerAssets: const {
        'cart_repository.dart':
            'assets/lessons/shopping/cart/answers/cart_repository.dart',
      },
      hints: const [
        '构造函数注入 CartService。',
        'loadCart 对应 loadItems。',
        'saveCart 对应 saveItems。',
        'clearCart 对应 clear。',
      ],
      requirements: const [
        RequiredClassRequirement('CartRepository'),
        RequiredFieldRequirement('_service'),
        RequiredMethodRequirement('loadCart'),
        RequiredMethodRequirement('saveCart'),
        RequiredMethodRequirement('clearCart'),
        RequiredMethodCallRequirement('loadItems'),
        RequiredMethodCallRequirement('saveItems'),
        RequiredMethodCallRequirement('clear'),
      ],
      relatedFiles: const ['cart_repository.dart'],
      checkMode: CheckMode.dartAst,
    ),
    LessonStep(
      id: 'shopping-cart-part-05-cart-provider',
      part: 'Part 5：购物车状态管理',
      title: '完整实现 CartProvider',
      instruction:
          '按照原项目实现加载、统计、加入、增减、删除、清空、操作队列、乐观更新和失败回滚。',
      stepType: LessonStepType.logic,
      explanation:
          '这是购物车核心。操作队列避免快速点击覆盖数据；乐观更新让页面先变化，保存失败再回滚。',
      starterCode: '''enum CartStatus {
  initial,
  loading,
  ready,
  error,
}

class CartProvider extends ChangeNotifier {
}
''',
      standardAnswerAssets: const {
        'cart_provider.dart':
            'assets/lessons/shopping/cart/answers/cart_provider.dart',
      },
      hints: const [
        '列表对外返回 UnmodifiableListView。',
        '所有写操作进入 _enqueue。',
        '_saveOptimistically 先更新 UI，再保存，失败时恢复 previousItems。',
        '数量减到 1 以下时直接移除项目。',
      ],
      requirements: const [
        RequiredClassRequirement('CartProvider'),
        RequiredFieldRequirement('_repository'),
        RequiredFieldRequirement('_items'),
        RequiredFieldRequirement('_status'),
        RequiredFieldRequirement('_operationQueue'),
        RequiredMethodRequirement('loadCart'),
        RequiredMethodRequirement('addProduct'),
        RequiredMethodRequirement('increaseQuantity'),
        RequiredMethodRequirement('decreaseQuantity'),
        RequiredMethodRequirement('removeProduct'),
        RequiredMethodRequirement('clearCart'),
        RequiredMethodRequirement('_saveOptimistically'),
        RequiredMethodRequirement('_enqueue'),
        RequiredMethodRequirement('_findProductIndex'),
        RequiredCodeIdentifierRequirement('totalQuantity'),
        RequiredCodeIdentifierRequirement('totalPrice'),
        RequiredMethodCallRequirement('notifyListeners'),
        RequiredAwaitRequirement(),
        RequiredRethrowRequirement(),
      ],
      relatedFiles: const ['cart_provider.dart'],
      checkMode: CheckMode.dartAst,
    ),
    LessonStep(
      id: 'shopping-cart-part-06-cart-item-tile',
      part: 'Part 6：购物车商品卡片',
      title: '建立 CartItemTile',
      instruction:
          '完整实现商品图片、标题、单价、小计、数量按钮和删除按钮。',
      stepType: LessonStepType.ui,
      explanation:
          'CartItemTile 只负责显示并通过回调把操作交还给 CartPage。',
      starterCode: '''class CartItemTile extends StatelessWidget {
}
''',
      standardAnswerAssets: const {
        'cart_item_tile.dart':
            'assets/lessons/shopping/cart/answers/cart_item_tile.dart',
      },
      hints: const [
        '不要在 Tile 内直接读取 Provider。',
        '增加、减少、删除都由 VoidCallback 注入。',
        '图片加载失败时显示占位图标。',
      ],
      requirements: const [
        RequiredClassRequirement('CartItemTile'),
        RequiredClassRequirement('_ProductImage'),
        RequiredClassRequirement('_QuantityButton'),
        RequiredFieldRequirement('item'),
        RequiredFieldRequirement('onIncrease'),
        RequiredFieldRequirement('onDecrease'),
        RequiredFieldRequirement('onRemove'),
        RequiredMethodRequirement('build'),
        RequiredCodeIdentifierRequirement('subtotal'),
        RequiredCodeIdentifierRequirement('OutlinedButton'),
        RequiredCodeIdentifierRequirement('delete_outline'),
      ],
      relatedFiles: const ['cart_item_tile.dart'],
      checkMode: CheckMode.dartAst,
    ),
    LessonStep(
      id: 'shopping-cart-part-07-cart-page',
      part: 'Part 7：购物车页面',
      title: '完整实现 CartPage',
      instruction:
          '完成加载、错误、空状态、商品列表、增减、删除、清空、总价、结算入口和错误提示。',
      stepType: LessonStepType.ui,
      explanation:
          'CartPage 负责把 CartProvider 的所有状态和操作组合成一个完整购物车页面。',
      starterCode: '''class CartPage extends StatefulWidget {
}

class _CartPageState extends State<CartPage> {
}
''',
      standardAnswerAssets: const {
        'cart_page.dart':
            'assets/lessons/shopping/cart/answers/cart_page.dart',
      },
      hints: const [
        '使用 context.watch 监听页面状态。',
        '每个项目使用 CartItemTile。',
        '清空前显示 AlertDialog。',
        '操作失败统一交给 _runCartAction。',
      ],
      requirements: const [
        RequiredClassRequirement('CartPage'),
        RequiredClassRequirement('_CartPageState'),
        RequiredMethodRequirement('_buildBody'),
        RequiredMethodRequirement('_buildEmptyView'),
        RequiredMethodRequirement('_buildErrorView'),
        RequiredMethodRequirement('_buildCheckoutBar'),
        RequiredMethodRequirement('_confirmClearCart'),
        RequiredMethodRequirement('_runCartAction'),
        RequiredMethodRequirement('_checkout'),
        RequiredMethodCallRequirement('increaseQuantity'),
        RequiredMethodCallRequirement('decreaseQuantity'),
        RequiredMethodCallRequirement('removeProduct'),
        RequiredMethodCallRequirement('clearCart'),
        RequiredCodeIdentifierRequirement('RefreshIndicator'),
        RequiredCodeIdentifierRequirement('CartItemTile'),
        RequiredCodeIdentifierRequirement('totalQuantity'),
        RequiredCodeIdentifierRequirement('totalPrice'),
        RequiredAwaitRequirement(),
      ],
      relatedFiles: const ['cart_page.dart'],
      checkMode: CheckMode.dartAst,
    ),
    LessonStep(
      id: 'shopping-cart-part-08-cart-icon',
      part: 'Part 8：购物车数量徽标',
      title: '建立 CartIconButton',
      instruction:
          '实现购物车入口、Selector 局部监听、数量红点和 99+ 上限。',
      stepType: LessonStepType.ui,
      explanation:
          'Selector 只监听 totalQuantity，避免其他购物车状态改变时整颗按钮重建。',
      starterCode: '''class CartIconButton extends StatelessWidget {
}
''',
      standardAnswerAssets: const {
        'cart_icon_button.dart':
            'assets/lessons/shopping/cart/answers/cart_icon_button.dart',
      },
      hints: const [
        'Selector 的结果类型是 int。',
        '数量为 0 时不显示红点。',
        '点击后进入 CartPage。',
      ],
      requirements: const [
        RequiredClassRequirement('CartIconButton'),
        RequiredMethodRequirement('build'),
        RequiredCodeIdentifierRequirement('Selector'),
        RequiredCodeIdentifierRequirement('totalQuantity'),
        RequiredCodeIdentifierRequirement('Stack'),
        RequiredCodeIdentifierRequirement('Positioned'),
        RequiredIntegerLiteralRequirement(99),
        RequiredCodeIdentifierRequirement('CartPage'),
      ],
      relatedFiles: const ['cart_icon_button.dart'],
      checkMode: CheckMode.dartAst,
    ),
    LessonStep(
      id: 'shopping-cart-part-09-product-details',
      part: 'Part 9：从商品详情加入购物车',
      title: '加入购物车与立即购买',
      instruction:
          '完整实现商品详情中的数量显示、加入购物车、立即购买、SnackBar 和跳转。',
      stepType: LessonStepType.integration,
      explanation:
          '商品详情是 CartProvider.addProduct 的主要业务入口。',
      starterCode: '''class ProductDetails extends StatefulWidget {
}

class _ProductDetailsState extends State<ProductDetails> {
}
''',
      standardAnswerAssets: const {
        'product_details.dart':
            'assets/lessons/shopping/cart/answers/product_details.dart',
      },
      hints: const [
        '使用 context.select 监听当前商品数量。',
        '_addToCart 成功后显示带“查看”操作的 SnackBar。',
        '_buyNow 先加入购物车，再打开 CartPage。',
      ],
      requirements: const [
        RequiredClassRequirement('ProductDetails'),
        RequiredClassRequirement('_ProductDetailsState'),
        RequiredMethodRequirement('_addToCart'),
        RequiredMethodRequirement('_buyNow'),
        RequiredMethodRequirement('_openCart'),
        RequiredMethodCallRequirement('addProduct'),
        RequiredMethodCallRequirement('quantityOf'),
        RequiredCodeIdentifierRequirement('mounted'),
        RequiredCodeIdentifierRequirement('CartIconButton'),
        RequiredCodeIdentifierRequirement('CartPage'),
        RequiredAwaitRequirement(),
      ],
      relatedFiles: const ['product_details.dart'],
      checkMode: CheckMode.dartAst,
    ),
    LessonStep(
      id: 'shopping-cart-part-10-product-list-entry',
      part: 'Part 10：商品列表入口',
      title: '在商品列表显示购物车入口',
      instruction:
          '保留原项目商品过滤、商品网格、详情跳转和 AppBar 购物车按钮。',
      stepType: LessonStepType.integration,
      explanation:
          '用户在浏览分类商品时，可以直接查看购物车数量并进入购物车。',
      starterCode: '''class ProductList extends StatefulWidget {
}

class _ProductListState extends State<ProductList> {
}
''',
      standardAnswerAssets: const {
        'product_list.dart':
            'assets/lessons/shopping/cart/answers/product_list.dart',
      },
      hints: const [
        'AppBar actions 放 CartIconButton。',
        'ProductCard 点击后进入 ProductDetails。',
      ],
      requirements: const [
        RequiredClassRequirement('ProductList'),
        RequiredClassRequirement('_ProductListState'),
        RequiredMethodRequirement('_buildProductGrid'),
        RequiredMethodRequirement('_openDetails'),
        RequiredCodeIdentifierRequirement('CartIconButton'),
        RequiredCodeIdentifierRequirement('ProductCard'),
        RequiredCodeIdentifierRequirement('ProductDetails'),
        RequiredCodeIdentifierRequirement('GridView'),
      ],
      relatedFiles: const ['product_list.dart'],
      checkMode: CheckMode.dartAst,
    ),
    LessonStep(
      id: 'shopping-cart-part-11-home-entry',
      part: 'Part 11：首页购物车入口',
      title: '在首页显示购物车按钮',
      instruction:
          '保留原项目首页完整结构，并把 CartIconButton 放进 AppBar actions。',
      stepType: LessonStepType.integration,
      explanation:
          '首页入口让用户从 App 的最上层随时查看购物车。',
      starterCode: '''class HomePage extends StatefulWidget {
}

class _HomePageState extends State<HomePage> {
}
''',
      standardAnswerAssets: const {
        'home_page.dart':
            'assets/lessons/shopping/cart/answers/home_page.dart',
      },
      hints: const [
        'CartIconButton 位于账号按钮之后。',
        '分类点击后进入 ProductList。',
      ],
      requirements: const [
        RequiredClassRequirement('HomePage'),
        RequiredClassRequirement('_HomePageState'),
        RequiredMethodRequirement('_buildAppBar'),
        RequiredMethodRequirement('_openProductList'),
        RequiredCodeIdentifierRequirement('CartIconButton'),
        RequiredCodeIdentifierRequirement('ProductList'),
      ],
      relatedFiles: const ['home_page.dart'],
      checkMode: CheckMode.dartAst,
    ),
    LessonStep(
      id: 'shopping-cart-part-12-main-navigation',
      part: 'Part 12：底部购物车分页',
      title: '在 MainPage 加入购物车 Tab',
      instruction:
          '使用 IndexedStack 保存页面状态，并在 NavigationBar 加入购物车目的地。',
      stepType: LessonStepType.integration,
      explanation:
          'MainPage 提供首页和购物车两个长期保留状态的主分页。',
      starterCode: '''class MainPage extends StatefulWidget {
}

class _MainPageState extends State<MainPage> {
}
''',
      standardAnswerAssets: const {
        'main_page.dart':
            'assets/lessons/shopping/cart/answers/main_page.dart',
      },
      hints: const [
        '_pages 同时包含 HomePage 和 CartPage。',
        'IndexedStack 不会在切换后销毁另一页。',
      ],
      requirements: const [
        RequiredClassRequirement('MainPage'),
        RequiredClassRequirement('_MainPageState'),
        RequiredFieldRequirement('_currentIndex'),
        RequiredFieldRequirement('_pages'),
        RequiredMethodRequirement('_changePage'),
        RequiredCodeIdentifierRequirement('IndexedStack'),
        RequiredCodeIdentifierRequirement('NavigationBar'),
        RequiredCodeIdentifierRequirement('CartPage'),
      ],
      relatedFiles: const ['main_page.dart'],
      checkMode: CheckMode.dartAst,
    ),
    LessonStep(
      id: 'shopping-cart-part-13-provider-injection',
      part: 'Part 13：全局注入',
      title: '在 main.dart 注入购物车',
      instruction:
          '按照原项目建立 LocalCartService、CartRepository 和 CartProvider，并在启动时 loadCart。',
      stepType: LessonStepType.integration,
      explanation:
          'Provider 必须放在 MaterialApp 上方，商品页、购物车页和结算页才能共享同一份购物车状态。',
      starterCode: '''Future<void> main() async {
}

class MyApp extends StatelessWidget {
}
''',
      standardAnswerAssets: const {
        'main.dart':
            'assets/lessons/shopping/cart/answers/main.dart',
      },
      hints: const [
        '先创建 CartRepository(service: LocalCartService())。',
        '用 ChangeNotifierProvider 创建 CartProvider。',
        '创建后立即调用 loadCart。',
      ],
      requirements: const [
        RequiredClassRequirement('MyApp'),
        RequiredCodeIdentifierRequirement('CartRepository'),
        RequiredCodeIdentifierRequirement('LocalCartService'),
        RequiredCodeIdentifierRequirement('MultiProvider'),
        RequiredCodeIdentifierRequirement('ChangeNotifierProvider'),
        RequiredCodeIdentifierRequirement('CartProvider'),
        RequiredMethodCallRequirement('loadCart'),
      ],
      relatedFiles: const ['main.dart'],
      checkMode: CheckMode.dartAst,
    ),
    LessonStep(
      id: 'shopping-cart-part-14-order-item-conversion',
      part: 'Part 14：购物车转订单项目',
      title: '把 CartItem 转换为 OrderItem',
      instruction:
          '保留原项目 Order 模型，并实现 OrderItem.fromCartItem。',
      stepType: LessonStepType.model,
      explanation:
          '提交订单时不能继续直接依赖可变购物车，而要把商品资料复制成订单快照。',
      starterCode: '''class OrderItem {
}

class Order {
}
''',
      standardAnswerAssets: const {
        'order.dart':
            'assets/lessons/shopping/cart/answers/order.dart',
      },
      hints: const [
        'fromCartItem 复制商品 ID、标题、图片、单价和数量。',
        '订单项目保留自己的 subtotal。',
      ],
      requirements: const [
        RequiredClassRequirement('OrderItem'),
        RequiredClassRequirement('Order'),
        RequiredCodeIdentifierRequirement('fromCartItem'),
        RequiredCodeIdentifierRequirement('CartItem'),
        RequiredCodeIdentifierRequirement('subtotal'),
        RequiredMethodRequirement('toJson'),
        RequiredCodeIdentifierRequirement('fromJson'),
      ],
      relatedFiles: const ['order.dart'],
      checkMode: CheckMode.dartAst,
    ),
    LessonStep(
      id: 'shopping-cart-part-15-checkout-provider',
      part: 'Part 15：结算状态衔接',
      title: '结算时读取并清空购物车',
      instruction:
          '完整实现 CheckoutProvider 对购物车总价、订单项目和下单后清空的处理。',
      stepType: LessonStepType.integration,
      explanation:
          'CheckoutProvider 把 cart.items 转换为 OrderItem，并在订单创建成功后清空购物车。',
      starterCode: '''class CheckoutProvider extends ChangeNotifier {
}
''',
      standardAnswerAssets: const {
        'checkout_provider.dart':
            'assets/lessons/shopping/cart/answers/checkout_provider.dart',
      },
      hints: const [
        'total 等于 cart.totalPrice 加运费。',
        '使用 OrderItem.fromCartItem 转换所有项目。',
        '订单成功后调用 cart.clearCart。',
        '清空失败不能重复建立订单。',
      ],
      requirements: const [
        RequiredClassRequirement('CheckoutProvider'),
        RequiredMethodRequirement('total'),
        RequiredMethodRequirement('placeOrder'),
        RequiredCodeIdentifierRequirement('CartProvider'),
        RequiredCodeIdentifierRequirement('items'),
        RequiredCodeIdentifierRequirement('OrderItem'),
        RequiredMethodCallRequirement('fromCartItem'),
        RequiredMethodCallRequirement('clearCart'),
        RequiredAwaitRequirement(),
      ],
      relatedFiles: const ['checkout_provider.dart'],
      checkMode: CheckMode.dartAst,
    ),
    LessonStep(
      id: 'shopping-cart-part-16-checkout-page',
      part: 'Part 16：结算页面展示购物车',
      title: '在结算页显示商品与金额',
      instruction:
          '完整保留 CheckoutPage 对购物车商品、数量、小计、总价和提交订单的展示。',
      stepType: LessonStepType.integration,
      explanation:
          '这是购物车数据进入结算 UI 的最后一层。',
      starterCode: '''class CheckoutPage extends StatelessWidget {
}
''',
      standardAnswerAssets: const {
        'checkout_page.dart':
            'assets/lessons/shopping/cart/answers/checkout_page.dart',
      },
      hints: const [
        '同时 watch CheckoutProvider 和 CartProvider。',
        '商品区域遍历 cart.items。',
        '金额区域使用 cart.totalPrice。',
        '提交时把 CartProvider 传入 placeOrder。',
      ],
      requirements: const [
        RequiredClassRequirement('CheckoutPage'),
        RequiredMethodRequirement('_buildProductSection'),
        RequiredMethodRequirement('_buildPriceSection'),
        RequiredMethodRequirement('_placeOrder'),
        RequiredCodeIdentifierRequirement('CartProvider'),
        RequiredCodeIdentifierRequirement('items'),
        RequiredCodeIdentifierRequirement('totalPrice'),
        RequiredMethodCallRequirement('placeOrder'),
        RequiredAwaitRequirement(),
      ],
      relatedFiles: const ['checkout_page.dart'],
      checkMode: CheckMode.dartAst,
    ),
  ],
);
