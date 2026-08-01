param(
  [Parameter(Mandatory = $true)]
  [string]$ShoppingRoot,

  [string]$LearningRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

$destination = Join-Path `
  $LearningRoot `
  'assets\lessons\shopping\cart\answers'

New-Item `
  -ItemType Directory `
  -Force `
  -Path $destination | Out-Null

$files = @(
  @{ Source = 'lib\models\product.dart'; Target = 'product.dart' },
  @{ Source = 'lib\models\cart_item.dart'; Target = 'cart_item.dart' },
  @{ Source = 'lib\services\cart_service.dart'; Target = 'cart_service.dart' },
  @{ Source = 'lib\repositories\cart_repository.dart'; Target = 'cart_repository.dart' },
  @{ Source = 'lib\providers\cart_provider.dart'; Target = 'cart_provider.dart' },
  @{ Source = 'lib\widgets\cart_item_tile.dart'; Target = 'cart_item_tile.dart' },
  @{ Source = 'lib\screens\cart_page.dart'; Target = 'cart_page.dart' },
  @{ Source = 'lib\widgets\cart_icon_button.dart'; Target = 'cart_icon_button.dart' },
  @{ Source = 'lib\screens\product_details.dart'; Target = 'product_details.dart' },
  @{ Source = 'lib\screens\product_list.dart'; Target = 'product_list.dart' },
  @{ Source = 'lib\screens\home_page.dart'; Target = 'home_page.dart' },
  @{ Source = 'lib\screens\main_page.dart'; Target = 'main_page.dart' },
  @{ Source = 'lib\main.dart'; Target = 'main.dart' },

  # 购物车与结算/订单衔接
  @{ Source = 'lib\models\order.dart'; Target = 'order.dart' },
  @{ Source = 'lib\providers\checkout_provider.dart'; Target = 'checkout_provider.dart' },
  @{ Source = 'lib\screens\checkout_page.dart'; Target = 'checkout_page.dart' }
)

foreach ($file in $files) {
  $sourcePath = Join-Path $ShoppingRoot $file.Source
  $targetPath = Join-Path $destination $file.Target

  if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "找不到原文件：$sourcePath"
  }

  Copy-Item `
    -LiteralPath $sourcePath `
    -Destination $targetPath `
    -Force

  $sourceHash = (
    Get-FileHash `
      -LiteralPath $sourcePath `
      -Algorithm SHA256
  ).Hash

  $targetHash = (
    Get-FileHash `
      -LiteralPath $targetPath `
      -Algorithm SHA256
  ).Hash

  if ($sourceHash -ne $targetHash) {
    throw "复制后哈希不一致：$($file.Source)"
  }

  Write-Host (
    "已复制并验证：{0}  SHA256={1}" `
      -f $file.Target, $targetHash
  )
}

Write-Host ''
Write-Host '购物车教材标准答案已全部复制完成。'
Write-Host "目标目录：$destination"
