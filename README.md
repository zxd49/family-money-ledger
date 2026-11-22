# 个人记账 PWA

移动端优先的单文件记账手机网页（蓝色 `#1677ff`），支持支出/收入记录、截图 OCR 识别账单、月度统计与历史筛选编辑。Supabase 云端优先、localStorage 兜底；表不存在或网络失败时优雅降级到本地，不会白屏。

## 文件清单

| 文件 | 说明 |
|---|---|
| `index.html` | 单文件应用，CSS/JS 全部内联；仅通过 jsdelivr CDN 引入 tesseract.js v5 |
| `manifest.json` | PWA 清单：standalone、主题色 `#1677ff`、192/512 图标 |
| `icon-192.png` | 192×192 蓝色圆角 ¥ 图标 |
| `icon-512.png` | 512×512 蓝色圆角 ¥ 图标 |
| `README.md` | 本文件（建表 SQL + 使用说明） |

> 未注册 service worker（与规格一致）；数据兜底依赖浏览器 localStorage。

## 部署

纯静态站点，把 `build/` 目录整体放到任意静态托管（Nginx / 对象存储 / GitHub Pages 等），用手机浏览器打开后可“添加到主屏幕”以 standalone 全屏运行。要求页面通过 HTTPS（或 localhost）访问，PWA 能力才完整。

## 建表 SQL（Supabase SQL Editor 执行）

表 `money_ledger`，列固定如下，前端不发明额外列：

```sql
create table money_ledger (
  id         bigint primary key,          -- 前端 genId：Date.now()*1000 + 3 位随机
  type       text,                        -- 'expense' | 'income'
  amount     numeric,
  category   text,
  note       text,
  date       text,                        -- 账单发生日，YYYY-MM-DD
  created_at text                         -- 录入时刻，ISO 字符串
);
```

演示用匿名读写：在 Authentication → Policies 中为该表放开 anon 角色的 select/insert/update/delete（生产环境请收紧 RLS）。

## 快速开始

1. 先在 Supabase SQL Editor 执行上面的建表 SQL（表不存在时应用仍可用，数据只存本机）。
2. 手机浏览器打开 GitHub Pages 网址，可「添加到主屏幕」当 App 用。
3. 记一笔：直接选分类填金额保存；或点顶部「📷 截图识别账单」，从微信/支付宝账单详情页截图选入，核对确认页后入账。

数据策略：每次保存/修改/删除先写本机 localStorage（界面立即生效），再尽力同步 Supabase；云端请求带 5 秒超时，网络挂起不阻塞操作；读取时云端与本地按 id 合并，同 id 云端优先。

### 云端连接约定

- URL：`https://gqvybdpgrfudiyvfqohr.supabase.co`
- Key：`sb_publishable_...`（sb_ 开头），请求头**只带 `apikey`**，**不带** `Authorization: Bearer`。
- 接口：`GET /rest/v1/money_ledger`、`POST`、`PATCH ?id=eq.<id>`、`DELETE ?id=eq.<id>`。

## 功能说明

### 1. 记一笔
- 顶部「📷 截图识别账单」入口；支出/收入分段切换。
- 分类 chips：支出（餐饮/交通/购物/住房/娱乐/医疗/通讯/其他）；收入（工资/兼职/红包/其他）。
- 金额（`inputmode=decimal`）、日期（默认今天）、备注，保存入账。

### 2. 统计
- 本月支出 / 收入 / 结余（收入−支出）三卡片。
- 本月支出按分类占比列表：金额、百分比、比例条。
- 近 6 个月收支对比：纯 CSS 并排柱状条（橙=支出，绿=收入），无图表库。

### 3. 历史
- 筛选：类型、分类、金额下限/上限、月份。
- 按日期倒序；每条显示类型色标、分类、金额（支出橙/收入绿）、日期、备注。
- 编辑：弹窗预填表单，保存后更新；删除：二次确认弹窗后删除。

### OCR 截图识别
- tesseract.js v5（jsdelivr），语言 `chi_sim+eng`，tessdata 默认从 tessdata.projectnaptha.com 加载。
- 流程：选图 → 预览 + 识别进度 → 解析文本 → **强制确认页**（金额/类型/分类/日期/商家备注均可编辑）→ 确认入账 / 重新识别 / 取消。识别结果**不直接落库**。
- 解析规则（纯函数，可单测）：
  - 金额：优先 `¥/￥/RMB/人民币` 后数字，其次「xx 元」，最后取合法区间（0.01–999999.99）内最像金额的数字；
  - 日期：`2026-11-22` / `2026/11/22` / `2026年11月22日`，统一输出 `YYYY-MM-DD`；
  - 商家/对方：`交易对方/交易对手/对方/商家/商品说明/商户/收款方/付款方` 行冒号后文字；
  - 类型：`支出/付款/已支付/转出/消费/转账支出` → expense；`收入/收款/转入/退款/入账/红包` → income；识别不出默认 expense，确认页可手切。

## 自测记录

解析正则抽成纯函数 `test/ledger_parser.js`，Node 下喂 3 段模拟微信/支付宝详情页文本断言：

1. 微信商户消费：`¥28.50` / `2026-11-20` / 瑞幸咖啡（望京店）/ expense —— 通过
2. 支付宝工资收入：`¥12,500.00` / `2026-11-18` / 公司财务部 / income —— 通过
3. 外卖支出（年月日 + 元）：`45.80` / `2026-11-15` / 美团外卖 / expense —— 通过
4. 边界：无金额文本 → `amount=null`、类型默认 expense —— 通过

`node --check` 校验 `index.html` 内联脚本：无语法错误。自测期间未向 Supabase `money_ledger` 写入任何数据（表当前 404，仅验证本地降级代码路径）。

## 已知限制

- 首次 OCR 需下载中文语言包，耗时取决于网络；截图模糊、字体过小或排版错乱时可能识别不到金额，需重拍或手动录入。
- 类型判断基于关键词；支出页出现“收款方”等字样时已做支出优先处理，但复杂账单仍建议在确认页核对类型。
- 云端表未建好或离线时，数据先存本机 localStorage；联网且表就绪后新写入走云端，读取时本地记录与云端按 id 合并（同 id 云端优先）。
- 未做 service worker 离线缓存外壳；应用外壳本身在断网时不可打开，仅已录入数据在本地可读。
- 单用户演示场景，未做多端冲突合并与加密；生产使用需补 RLS 策略与备份。
