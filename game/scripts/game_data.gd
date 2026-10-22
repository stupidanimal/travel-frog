class_name GameData
## 静态数据表：商店、目的地、访客、文案等（服务器和客户端共用）。

# ---- 时间参数（加速版，单位秒） ----
const GROW_TIME := 25.0          # 三叶草长满一轮
const TRIP_MIN := 80.0           # 旅行最短时长
const TRIP_MAX := 160.0          # 旅行最长时长
const TRIP_CD_MIN := 45.0        # 回家后再次出发的最短冷却
const TRIP_CD_MAX := 80.0        # 冷却上限
const TRIP_CD_FIRST := 25.0      # 刚领养时第一次出发的冷却
const NO_FOOD_CD := 12.0         # 没有便当不让走时的提示冷却
const ACT_MIN := 6.0             # 在家行为最短持续
const ACT_MAX := 16.0            # 在家行为最长持续
const VISIT_CD_MIN := 25.0       # 访客出现间隔
const VISIT_CD_MAX := 45.0
const VISIT_LIFE := 100.0        # 访客停留时间
const MAX_VISITORS := 2
const TICK := 0.5                # 服务器世界节拍

# ---- 食物（消耗品：出门时吃掉） ----
const FOODS := {
	"cong_bing": {"name": "香葱烤饼", "price": 20, "desc": "咸香松脆，最常带的干粮", "bias": ["城市", "草原"]},
	"nangua": {"name": "南瓜贝果", "price": 30, "desc": "甜甜的，适合去森林散步", "bias": ["森林", "山"]},
	"aicao": {"name": "艾草团子", "price": 45, "desc": "清甜软糯，常常走到海边", "bias": ["海边", "神社"]},
	"lakabao": {"name": "辣味咖喱包", "price": 60, "desc": "吃完浑身是劲，直奔温泉", "bias": ["温泉", "山"]},
}

# ---- 道具（不消耗，跟着蛙走，影响目的地） ----
const ITEMS := {
	"toujin": {"name": "条纹头巾", "price": 50, "desc": "系上头巾进城更神气", "bias": ["城市"]},
	"shuihu": {"name": "竹水壶", "price": 55, "desc": "爬山不怕口渴", "bias": ["山"]},
	"lazhu": {"name": "露营蜡烛", "price": 60, "desc": "照亮黑漆漆的洞窟", "bias": ["洞窟"]},
	"zhangpeng": {"name": "小帐篷", "price": 80, "desc": "能在草原、森林露营", "bias": ["草原", "森林"]},
}

# ---- 护身符（消耗品：出发时用掉） ----
const CHARMS := {
	"yumite": {"name": "开运御守", "price": 100, "desc": "旅途顺利，保证带回特产", "bias": []},
}
const FOUR := "four"             # 四叶草的护身符编号（花园里薅的）

# ---- 目的地 ----
# sky_top/sky_bottom/ground 为 0xRRGGBB；text 是明信片文案池；gifts 是特产池
const DESTS := {
	"山": {
		"sky_top": 0x9fd4ff, "sky_bottom": 0xe8f6ff, "ground": 0x7fae6a,
		"shape": "mountain",
		"texts": ["爬到山顶眺望，云软得像棉花糖。", "风把汗水吹干了，山路很安静。", "在半山腰的亭子里睡了个午觉。"],
		"gifts": ["山葡萄", "木陀螺"],
	},
	"海边": {
		"sky_top": 0x8ed8ff, "sky_bottom": 0xfff3d6, "ground": 0x4f9fd6,
		"shape": "sea",
		"texts": ["海浪一下一下舔着脚丫，凉凉的。", "捡了一下午贝壳，挑出最白的那颗。", "咸咸的海风吹得肚皮咕咕叫。"],
		"gifts": ["贝壳风铃", "海盐糖"],
	},
	"温泉": {
		"sky_top": 0xb8a8d8, "sky_bottom": 0xf6dfe6, "ground": 0x8d7fb0,
		"shape": "onsen",
		"texts": ["泡得全身软绵绵，差点睡过去。", "温泉蛋很烫，但很好吃。", "雾气里看月亮，像一盏纸灯笼。"],
		"gifts": ["温泉布巾", "橘子汽水"],
	},
	"城市": {
		"sky_top": 0xffd9a0, "sky_bottom": 0xfff0dd, "ground": 0x9a9a9a,
		"shape": "city",
		"texts": ["高楼之间的天空被切成细长一条。", "路口的红绿灯变换，人群像潮水。", "在天桥上看了很久的车灯河流。"],
		"gifts": ["冰箱贴", "汽水硬糖"],
	},
	"森林": {
		"sky_top": 0xa8e0b8, "sky_bottom": 0xe9f7e0, "ground": 0x4e8f5a,
		"shape": "forest",
		"texts": ["树影把阳光切成一片一片。", "遇见一只松鼠，我们互相看了很久。", "苔藓踩上去软软的，像地毯。"],
		"gifts": ["松果", "树皮小船"],
	},
	"草原": {
		"sky_top": 0xbde3ff, "sky_bottom": 0xf3fff0, "ground": 0x8fc96b,
		"shape": "field",
		"texts": ["躺进草里，只露出肚皮晒太阳。", "风吹过来，整片草浪都在点头。", "数了三十朵蒲公英，一口气吹飞。"],
		"gifts": ["狗尾巴草", "野花标本"],
	},
	"神社": {
		"sky_top": 0xffc9c9, "sky_bottom": 0xfff2e4, "ground": 0xb08968,
		"shape": "torii",
		"texts": ["石阶两边的灯笼安安静静。", "摇铃许了个愿，希望明天也有饭吃。", "绘马架上写满了别人的愿望。"],
		"gifts": ["御守残片", "祈愿绘马"],
	},
	"洞窟": {
		"sky_top": 0x4a5a78, "sky_bottom": 0x8fa3c0, "ground": 0x3a4256,
		"shape": "cave",
		"texts": ["蜡烛的光只够照亮脚边一小圈。", "洞里滴水的声音，一滴一滴地数。", "深处的墙壁上有亮晶晶的东西。"],
		"gifts": ["萤石", "钟乳石片"],
	},
}
const CARD_VARIANTS := 3         # 每个目的地 3 张不同明信片

# ---- 院子访客 ----
const VISITORS := {
	"hudie": {"name": "小蝴蝶", "fav": "aicao"},
	"mifeng": {"name": "小蜜蜂", "fav": "cong_bing"},
	"piaochong": {"name": "七星瓢虫", "fav": "nangua"},
	"songshu": {"name": "小松鼠", "fav": "lakabao"},
	"wugui": {"name": "小乌龟", "fav": "nangua"},
}

# ---- 蛙的名字 ----
const FROG_NAMES := ["呱", "小呱", "泡呱", "阿呱", "呱太", "呱唧", "豆呱", "瓦呱"]

# ---- 在家行为 ----
const ACTS := {
	"idle": "在窗边发呆",
	"read": "在看书",
	"write": "在写日记",
	"craft": "在削木头",
	"eat": "在吃饭",
}

static func food_name(id: String) -> String:
	if FOODS.has(id): return FOODS[id]["name"]
	if ITEMS.has(id): return ITEMS[id]["name"]
	if CHARMS.has(id): return CHARMS[id]["name"]
	if id == FOUR: return "四叶草"
	return id

static func card_id(dest: String, art: int) -> String:
	return dest + "#" + str(art)

static func dest_of_card(cid: String) -> String:
	return cid.get_slice("#", 0)
