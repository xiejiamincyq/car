class_name GameText
extends RefCounted

const LANGUAGE_SYSTEM := "system"
const LANGUAGE_ZH := "zh"
const LANGUAGE_EN := "en"
const LANGUAGE_PREFERENCES := [LANGUAGE_SYSTEM, LANGUAGE_ZH, LANGUAGE_EN]

const TEXT_ROWS := [
	["title.subtitle", "霓虹海岸 · 极速生存赛", "NEON COAST · SURVIVAL RACE"],
	["title.objective", "目标：穿越车流，抵达 3200 米终点。\n通过 3 个检查点会补充燃油；燃油耗尽则比赛结束。", "GOAL: Weave through traffic and reach the 3200 m finish.\nThree checkpoints restore fuel; running dry ends the race."],
	["title.start", "开始比赛", "START RACE"],
	["title.settings", "设置", "SETTINGS"],
	["title.controls", "操作说明", "CONTROLS"],
	["title.quit", "退出游戏", "QUIT GAME"],
	["title.difficulty", "难度：{0}", "DIFFICULTY: {0}"],
	["tour.heading", "霓虹海岸巡回赛", "NEON COAST TOUR"],
	["tour.hint", "方向键选择赛道  Enter 确认  Esc 返回", "ARROW KEYS SELECT  ENTER CONFIRMS  ESC BACK"],
	["tour.locked_short", "未解锁", "LOCKED"],
	["tour.available", "可以出赛", "AVAILABLE"],
	["tour.locked", "先完成上一条赛道", "CLEAR THE PREVIOUS TRACK"],
	["tour.details", "{0}  ·  {1}\n奖牌：{2}    最佳得分：{3}    最佳时间：{4}", "{0}  ·  {1}\nMEDAL: {2}    BEST SCORE: {3}    BEST TIME: {4}"],
	["tour.medals.0", "无", "NONE"],
	["tour.medals.1", "铜牌", "BRONZE"],
	["tour.medals.2", "银牌", "SILVER"],
	["tour.medals.3", "金牌", "GOLD"],
	["track_neon_coast", "霓虹海岸", "NEON COAST"],
	["track_freight_harbor", "货运港湾", "FREIGHT HARBOR"],
	["track_storm_ridge", "风暴山脊", "STORM RIDGE"],
	["track_sunrise_express", "日出快线", "SUNRISE EXPRESS"],
	["garage.heading", "选择赛车", "SELECT YOUR CAR"],
	["garage.hint", "方向键选择车辆  Enter 驾驶  Esc 返回地图", "ARROW KEYS SELECT  ENTER DRIVES  ESC RETURNS TO MAP"],
	["garage.locked_short", "未解锁", "LOCKED"],
	["garage.available", "可以驾驶", "AVAILABLE"],
	["garage.details", "{0}  ·  {1}  ·  {2}\n极速 {3}   加速 {4}   制动 {5}   转向 {6}   碰撞损速 {7}", "{0}  ·  {1}  ·  {2}\nSPEED {3}   ACCEL {4}   BRAKE {5}   STEER {6}   CRASH LOSS {7}"],
	["vehicle_pulse_gt", "脉冲 GT", "PULSE GT"],
	["vehicle_driftwing", "漂移之翼", "DRIFTWING"],
	["vehicle_flashpoint", "闪击点", "FLASHPOINT"],
	["vehicle_comet_rs", "彗星 RS", "COMET RS"],
	["vehicle_tidebreaker", "破潮者", "TIDEBREAKER"],
	["vehicle_aurora_x", "极光 X", "AURORA X"],
	["vehicle_role_balanced", "均衡型", "BALANCED"],
	["vehicle_role_agile", "灵巧型", "AGILE"],
	["vehicle_role_sprint", "冲刺型", "SPRINTER"],
	["vehicle_role_speed", "极速型", "TOP SPEED"],
	["vehicle_role_stable", "稳健型", "STABLE"],
	["vehicle_role_expert", "专家型", "EXPERT"],
	["unlock_starter", "初始车辆", "STARTER CAR"],
	["unlock_first_clear", "完成任意一条赛道后解锁", "CLEAR ANY TRACK TO UNLOCK"],
	["unlock_four_medals", "累计 4 枚奖牌后解锁", "EARN 4 TOTAL MEDALS TO UNLOCK"],
	["unlock_all_tracks", "完成全部赛道后解锁", "CLEAR ALL TRACKS TO UNLOCK"],
	["difficulty.easy", "轻松", "EASY"],
	["difficulty.normal", "标准", "NORMAL"],
	["difficulty.hard", "困难", "HARD"],
	["settings.heading", "设置", "SETTINGS"],
	["settings.volume", "主音量：{0}%（- / + 调整）", "MASTER VOLUME: {0}% (- / +)"],
	["settings.mute", "静音：{0}", "MUTE: {0}"],
	["settings.display", "显示模式：{0}", "DISPLAY: {0}"],
	["settings.language", "语言：{0}", "LANGUAGE: {0}"],
	["settings.language.system", "跟随系统", "SYSTEM"],
	["settings.language.zh", "中文", "CHINESE"],
	["settings.language.en", "英文", "ENGLISH"],
	["settings.high_contrast", "高对比配色：{0}", "HIGH-CONTRAST COLORS: {0}"],
	["settings.reduced_flashing", "减少闪烁：{0}", "REDUCED FLASHING: {0}"],
	["settings.screen_shake", "屏幕震动：{0}", "SCREEN SHAKE: {0}"],
	["settings.back", "返回", "BACK"],
	["common.on", "开", "ON"],
	["common.off", "关", "OFF"],
	["common.fullscreen", "全屏", "FULLSCREEN"],
	["common.windowed", "窗口", "WINDOWED"],
	["controls.heading", "键盘操作", "KEYBOARD CONTROLS"],
	["controls.body", "W / ↑  加速      S / ↓  减速\nA / ←  左转      D / →  右转\nSpace  暂停      M  静音    F11  全屏\n菜单使用方向键，Enter 确认，Esc 返回", "W / ↑  ACCELERATE      S / ↓  BRAKE\nA / ←  STEER LEFT      D / →  STEER RIGHT\nSPACE  PAUSE      M  MUTE      F11  FULLSCREEN\nARROW KEYS navigate, ENTER confirms, ESC goes back"],
	["pause.heading", "比赛暂停", "RACE PAUSED"],
	["pause.resume", "继续比赛", "RESUME RACE"],
	["pause.restart", "重新开始", "RESTART"],
	["pause.settings", "设置", "SETTINGS"],
	["pause.title", "返回标题", "RETURN TO TITLE"],
	["result.clear", "赛程完成", "RACE COMPLETE"],
	["result.over", "比赛结束", "RACE OVER"],
	["result.new_record", "NEW RECORD", "NEW RECORD"],
	["result.stats", "统计", "STATS"],
	["result.replay", "返回巡回地图", "RETURN TO TOUR"],
	["result.title", "返回标题", "RETURN TO TITLE"],
	["result.reason.clear", "抵达终点", "FINISH REACHED"],
	["result.reason.fuel", "燃油耗尽", "OUT OF FUEL"],
	["result.summary", "{0}\n\n得分  {1}\n距离  {2}m\n超车  {3}    近失  {4}\n到达赛段  {5}\n局种子  {6}", "{0}\n\nSCORE  {1}\nDISTANCE  {2}m\nOVERTAKES  {3}    NEAR MISSES  {4}\nSTAGE REACHED  {5}\nRUN SEED  {6}"],
	["confirm.restart", "当前比赛进度将丢失，确定重新开始？", "Current race progress will be lost. Restart?"],
	["confirm.title", "当前比赛进度将丢失，确定返回标题？", "Current race progress will be lost. Return to title?"],
	["confirm.yes", "确定", "CONFIRM"],
	["confirm.no", "取消，保留本局", "CANCEL, KEEP RACING"],
	["scores.none", "最高成绩：暂无成绩", "BEST SCORES: NONE"],
	["scores.heading", "最高成绩", "BEST SCORES"],
	["scores.entry", "{0}. {1}  {2}  {3}m", "{0}. {1}  {2}  {3}m"],
	["hud.speed", "速度  {0} km/h", "SPEED  {0} km/h"],
	["hud.score", "得分  {0}    距离  {1}m", "SCORE  {0}    DIST  {1}m"],
	["hud.fuel", "燃油  {0}%  {1}", "FUEL  {0}%  {1}"],
	["hud.fuel.low", "燃油偏低", "LOW FUEL!"],
	["hud.fuel.critical", "燃油危险", "FUEL CRITICAL!"],
	["hud.status", "赛段 {0}  |  COMBO x{1} {2}  |  {3}", "STAGE {0}  |  COMBO x{1} {2}  |  {3}"],
	["hud.ready", "就绪", "READY"],
	["hud.controls", "W/S 速度  A/D 转向  Space 暂停  M 静音  |  种子 {0}", "W/S SPEED  A/D STEER  SPACE PAUSE  M MUTE  |  SEED {0}"],
	["phase.title", "标题", "TITLE"],
	["phase.countdown", "倒计时", "COUNTDOWN"],
	["phase.running", "比赛中", "RUNNING"],
	["phase.paused", "已暂停", "PAUSED"],
	["phase.clear", "已通关", "CLEAR"],
	["phase.over", "比赛结束", "GAME OVER"],
	["lane.warning", "{0} 号车道即将封闭", "LANE {0} CLOSING SOON"],
	["lane.closed", "{0} 号车道封闭", "LANE {0} CLOSED"],
	["feedback.stage", "赛段 {0}", "STAGE {0}"],
	["feedback.checkpoint", "检查点 {0} / {1}　燃油 +{2}", "CHECKPOINT {0} / {1}  FUEL +{2}"],
	["overlay.paused", "已暂停\n\n[ SPACE ]  继续     [ R ]  重开", "PAUSED\n\n[ SPACE ]  RESUME     [ R ]  RESTART"],
	["overlay.game_over", "燃油耗尽\n\n得分  {0}     距离  {1}m", "OUT OF FUEL\n\nSCORE  {0}     DIST  {1}m"],
]

static func resolve_language(preference: String, system_locale: String) -> String:
	if preference == LANGUAGE_ZH or preference == LANGUAGE_EN:
		return preference
	return LANGUAGE_ZH if system_locale.to_lower().begins_with("zh") else LANGUAGE_EN

static func get_text(key: String, language: String, values: Array = []) -> String:
	var column := 1 if language == LANGUAGE_ZH else 2
	for row in TEXT_ROWS:
		if row[0] == key:
			return String(row[column]).format(values)
	return "[%s]" % key

static func catalog_keys_match() -> bool:
	for row in TEXT_ROWS:
		if row.size() != 3 or String(row[0]).is_empty() or String(row[1]).is_empty() or String(row[2]).is_empty():
			return false
	return true
