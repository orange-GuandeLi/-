# 物品美术资源

## 规格（重要）

- **16×16 像素 PNG**，**透明背景**，正方形
- 会被**整数倍 4 倍**放大显示（16 → 64px）。非 1:1 的比例会导致像素被压扁或放大后大小不均
- 图形主体尽量占满画布，四周留 5% 余量，避免被右上角的等级徽章压住
- 导入设置保持 Godot 默认；**不要**开 Mipmaps，会破坏像素边缘
- 全局过滤已经是最近邻（`default_texture_filter=0`），不用单独调

## 命名表

| 文件名 | 物品 | 等级 | 原始编号 |
|--------|------|------|----------|
| `leaf.png` | 叶子 | 1 | item994 |
| `wheat.png` | 麦穗 | 1 | item416 |
| `dew.png` | 露珠 | 1 | item1141 |
| `flower.png` | 花 | 2 | item1040 |
| `sprout.png` | 嫩芽 | 2 | item1002 |
| `crystal.png` | 冰晶 | 2 | item1131 |
| `berry.png` | 浆果 | 3 | item415 |
| `tree.png` | 小树 | 3 | item1003 |
| `gem.png` | 紫晶 | 3 | item1064 |
| `sacred_fruit.png` | 圣果 | 4 | item505 |

原始素材在 `_source/items.zip`（1244 张），已解包到 `_source/extracted/`。
全部 1244 张的编号索引图在 `docs/sheet_0.png` ~ `docs/sheet_3.png`。

## 换素材

1. 找好 16×16 透明 PNG
2. 按上表命名放进本目录
3. 回到 Godot 编辑器，资源会自动导入并替换

没放图片的物品会自动退回代码绘制的占位图形，游戏照常运行。

## 加新物品

1. 图片按 id 命名放进来（例如 `star.png`）
2. 在 `scripts/game_data.gd` 的 `ITEMS` 里加一条，**key 必须和文件名一致**
3. 在 `RECIPES` 里加一条合成规则（两边 id 必须相同）
4. 需要的话在 `docs/` 的索引图里补上——`tools/contact_sheet.gd` 可以重新生成
