extends Control

var game
var menu: Control
var shop: Control
var shop_status: Label
const W=preload("res://scripts/weapons.gd")
var title: Label
var subtitle: Label
var begin_button: Button
var resume_button: Button
var font=preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
var ink=Color(.94,.93,.86)
var gold=Color(.89,.68,.34)

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	process_mode=Node.PROCESS_MODE_ALWAYS
	build_menu()
	build_shop()

func label_at(parent: Node,text_: String,pos: Vector2,size_: int,color=Color(.93,.92,.86)) -> Label:
	var label=Label.new();label.text=text_;label.position=pos;label.add_theme_font_size_override("font_size",size_)
	label.add_theme_color_override("font_color",color);parent.add_child(label);return label

func build_menu():
	menu=Control.new();menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(menu)
	var shade=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(.035,.05,.06,.88);menu.add_child(shade)
	var panel=Control.new();panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);panel.position=Vector2(-570,-330);menu.add_child(panel)
	label_at(panel,"DUSTLINE    /    DESERT OPERATIONS",Vector2(0,0),18,gold)
	title=label_at(panel,"沙漠行动",Vector2(0,55),66)
	subtitle=label_at(panel,"沙漠双点  ·  5v5 爆破",Vector2(3,145),22,Color(.7,.74,.72))
	label_at(panel,"进攻方安装 C4，防守方阻止或拆除。\n每回合阵亡后等待下一回合复活。",Vector2(3,207),20)
	begin_button=button(panel,"开始比赛   →",Vector2(0,310),Vector2(350,58));begin_button.pressed.connect(func():game.start())
	resume_button=button(panel,"继续游戏",Vector2(0,381),Vector2(350,50));resume_button.pressed.connect(func():game.resume());resume_button.visible=false
	var quit_button=button(panel,"退出",Vector2(0,510),Vector2(140,46));quit_button.pressed.connect(func():get_tree().quit())
	label_at(panel,"对局设置",Vector2(615,65),24,gold)
	label_at(panel,"你的阵营",Vector2(615,115),18)
	var team_select=OptionButton.new();team_select.position=Vector2(810,109);team_select.size=Vector2(240,38)
	team_select.add_item("进攻方 T");team_select.add_item("防守方 CT");team_select.item_selected.connect(func(i):game.player_team=i);panel.add_child(team_select)
	label_at(panel,"人机难度",Vector2(615,174),18)
	var difficulty=OptionButton.new();difficulty.position=Vector2(810,168);difficulty.size=Vector2(240,40)
	for text_ in ["新兵","标准","老兵"]:difficulty.add_item(text_)
	difficulty.selected=1;difficulty.item_selected.connect(func(i):game.difficulty=i);panel.add_child(difficulty)
	label_at(panel,"鼠标灵敏度",Vector2(615,234),18)
	var sensitivity=HSlider.new();sensitivity.position=Vector2(810,234);sensitivity.size=Vector2(240,28)
	sensitivity.min_value=.0006;sensitivity.max_value=.005;sensitivity.step=.0001;sensitivity.value=.002
	sensitivity.value_changed.connect(func(v):game.player.sensitivity=v);panel.add_child(sensitivity)
	label_at(panel,"主音量",Vector2(615,294),18)
	var volume=HSlider.new();volume.position=Vector2(810,294);volume.size=Vector2(240,28);volume.min_value=0;volume.max_value=1;volume.step=.01;volume.value=.65
	volume.value_changed.connect(func(v):game.sound.set_volume(v));panel.add_child(volume)
	label_at(panel,"WASD / Shift     移动 / 静步\nCtrl / Space       蹲伏 / 跳跃\nB / E                   购买 / 安拆包\nG / H                   手雷 / 烟雾弹",Vector2(615,350),18,Color(.68,.73,.73))
	label_at(panel,"鼠标左 / 右键   射击 / 开镜\nR / 1 / 2            换弹 / 主副武器\nQ                        切换进攻路线\nEsc / Tab           暂停 / 战绩",Vector2(870,350),18,Color(.68,.73,.73))
	label_at(panel,"5v5   /   A & B   /   先赢 5 回合",Vector2(0,604),16,gold)
	label_at(panel,"离线爆破   ·   沙漠双点",Vector2(850,604),14,Color(.49,.56,.57))

func button(parent: Node,text_: String,pos: Vector2,size_: Vector2) -> Button:
	var b=Button.new();b.text=text_;b.position=pos;b.size=size_;b.add_theme_font_size_override("font_size",21)
	var style=StyleBoxFlat.new();style.bg_color=Color(.19,.23,.24);style.border_color=Color(.48,.48,.37)
	style.set_border_width_all(1);style.content_margin_left=20;style.content_margin_right=20
	b.add_theme_stylebox_override("normal",style)
	var hover=style.duplicate();hover.bg_color=Color(.29,.32,.29);hover.border_color=gold;b.add_theme_stylebox_override("hover",hover)
	parent.add_child(b);return b

func show_menu():
	menu.visible=true
	resume_button.visible=game.started and not game.finished
	begin_button.text="重新开始   →" if game.started else "开始比赛   →"
	title.text="比赛结束" if game.finished else ("已暂停" if game.started else "沙漠行动")
	subtitle.text=("%d 次击杀  /  %d 次阵亡"%[game.kills,game.deaths]) if game.finished else "沙漠双点  ·  5v5 爆破"

func _process(_dt):
	if shop.visible:shop_status.text="$%d    /    购买剩余 %.0f 秒"%[game.player.money,game.buy_left]
	queue_redraw()

func text_at(text_: String,pos: Vector2,size_: int,color: Color):
	draw_string(font,pos+Vector2(1,2),text_,HORIZONTAL_ALIGNMENT_LEFT,-1,size_,Color(0,0,0,.65))
	draw_string(font,pos,text_,HORIZONTAL_ALIGNMENT_LEFT,-1,size_,color)

func build_shop():
	shop=Control.new();shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shop);shop.visible=false
	var shade=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(.025,.04,.055,.96);shop.add_child(shade)
	var panel=Control.new();panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);panel.position=Vector2(-580,-330);shop.add_child(panel)
	label_at(panel,"装备购买",Vector2(0,0),40,gold)
	shop_status=label_at(panel,"",Vector2(600,12),24)
	label_at(panel,"选择一把主武器；每种投掷物可携带一个。",Vector2(0,68),19)
	var cards=[["ak","AK-47",2700,"7.62 / 30 发","高伤害，控制连射"],["m4","M4A1",3100,"5.56 / 30 发","射速快，后坐力较低"],["awp","AWP",4750,"狙击步枪 / 5 发","右键开镜，射击后拉栓"]]
	for i in 3:
		var c=cards[i];var x=i*390
		label_at(panel,c[1],Vector2(x+12,136),31,gold)
		label_at(panel,c[3],Vector2(x+12,193),18)
		label_at(panel,c[4],Vector2(x+12,233),17,Color(.65,.72,.73))
		var buy_button=button(panel,"购买  $%d"%c[2],Vector2(x,291),Vector2(350,58))
		buy_button.pressed.connect(func():game.buy(c[0]))
	var items=[["he","手雷  $300"],["smoke","烟雾弹  $300"],["armor","护甲  $650"],["kit","拆弹器  $400"]]
	for i in 4:
		var item=items[i];var b=button(panel,item[1],Vector2(i*293,400),Vector2(268,55));b.pressed.connect(func():game.buy(item[0]))
	label_at(panel,"G 投掷手雷  ·  H 投掷烟雾弹  ·  CT 拆弹器将拆弹时间缩短至 5 秒",Vector2(0,490),17)
	label_at(panel,"每局开场 $5000；胜负和击杀获得金钱。存活时保留装备。",Vector2(0,530),17,Color(.65,.72,.73))
	var close=button(panel,"返回战场  [ B ]",Vector2(820,575),Vector2(310,52));close.pressed.connect(func():game.toggle_buy())

func _draw():
	if not game.started:return
	var w=size.x;var h=size.y;var center=Vector2(w/2,h/2);var p=game.player
	if p.scoped and p.weapon==3 and p.hp>0:scope_mask(center,minf(h*.41,w*.35))
	draw_rect(Rect2(w/2-215,20,430,88),Color(.025,.04,.04,.86))
	var seconds=ceili(game.bomb_left if game.bomb_state=="planted" else (game.phase_left if game.phase=="freeze" else game.time_left))
	text_at("%02d:%02d"%[seconds/60,seconds%60],Vector2(w/2-42,59),29,Color(1,.37,.22) if game.bomb_state=="planted" else ink)
	text_at("T  %d"%game.scores[0],Vector2(w/2-191,61),28,gold)
	text_at("%d  CT"%game.scores[1],Vector2(w/2+105,61),28,Color(.45,.76,1))
	text_at("存活 %d"%game.team_alive(0).size(),Vector2(w/2-189,91),16,ink)
	text_at("第 %d 回合"%game.round_number,Vector2(w/2-46,91),15,ink)
	text_at("存活 %d"%game.team_alive(1).size(),Vector2(w/2+113,91),16,ink)
	draw_rect(Rect2(26,h-103,333,75),Color(.025,.04,.04,.78))
	text_at("+",Vector2(43,h-53),32,gold);text_at(str(p.hp),Vector2(80,h-50),34,ink)
	text_at("护甲  %d"%p.armor,Vector2(191,h-54),21,ink)
	draw_rect(Rect2(43,h-39,142,3),Color(.25,.29,.28));draw_rect(Rect2(43,h-39,142*p.hp/100.,3),gold)
	text_at("$%d   B 购买"%p.money,Vector2(29,h-124),22,gold)
	text_at("HE %d   SMOKE %d   %s"%[p.grenades.he,p.grenades.smoke,"拆弹器" if p.kit else ""],Vector2(w-315,h-131),16,ink)
	draw_rect(Rect2(w-287,h-111,260,85),Color(.025,.04,.04,.78))
	text_at(W.DATA[p.weapon].name,Vector2(w-264,h-86),16,gold)
	text_at("%02d"%p.ammo[p.weapon],Vector2(w-264,h-43),38,ink)
	text_at("/  %03d"%p.reserve[p.weapon],Vector2(w-191,h-47),22,Color(.65,.7,.68))
	text_at("1 主武器    2 手枪",Vector2(w-181,h-18),12,ink)
	if p.hp>0 and not p.scoped:
		var gap=5+p.recoil*12+Vector2(p.velocity.x,p.velocity.z).length()*1.2
		for dir in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:draw_line(center+dir*gap,center+dir*(gap+7),Color(.63,.95,.76),2)
	if game.hit_marker>0:
		for dir in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]:draw_line(center+dir*7,center+dir*13,ink,2)
	if p.reload_left>0:progress_bar(center+Vector2(0,64),"正在换弹",1-p.reload_left/p.reload_duration)
	if game.interaction_actor==p:progress_bar(center+Vector2(0,100),"安装 C4" if p.team==0 else "拆除 C4",game.interaction_progress/game.interaction_duration)
	elif p.hp>0 and game.phase in ["live","planted"]:
		if p==game.bomb_carrier and game.world.site_at(p.position)!="":text_at("按住 E 安装 C4",center+Vector2(-82,84),20,gold)
		elif p.team==1 and game.bomb_state=="planted" and p.position.distance_to(game.bomb_position)<2.5:text_at("按住 E 拆除 C4",center+Vector2(-82,84),20,gold)
	if game.hurt_overlay>0:
		var c=Color(.7,.09,.04,game.hurt_overlay*.6)
		draw_rect(Rect2(0,0,w,12),c);draw_rect(Rect2(0,h-12,w,12),c);draw_rect(Rect2(0,0,12,h),c);draw_rect(Rect2(w-12,0,12,h),c)
	if p.hp<=0:
		var allies=game.team_alive(p.team)
		text_at("观战 "+(allies[p.spectator_index%allies.size()].callsign if not allies.is_empty() else "本回合已阵亡"),Vector2(w/2-155,h-105),23,ink)
		text_at("点击切换队友 · 下一回合复活",Vector2(w/2-155,h-71),17,gold)
	if game.phase=="freeze":text_at("购买阶段 · B 购买 · "+("你携带 C4" if p==game.bomb_carrier else "准备行动"),Vector2(w/2-175,142),20,gold)
	if game.bomb_state=="planted":text_at(game.planted_site+" 点 C4 已安装",Vector2(w/2-88,140),20,Color(1,.44,.26))
	if game.phase=="end":
		draw_rect(Rect2(center+Vector2(-290,-70),Vector2(580,145)),Color(.035,.045,.05,.94))
		text_at(("进攻方" if game.winner==0 else "防守方")+"获胜",center+Vector2(-105,-12),35,gold)
		text_at(game.round_reason+" · %.0f 秒后下一回合"%game.phase_left,center+Vector2(-165,38),20,ink)
	if game.message_left>0:text_at(game.message,Vector2(maxf(240,w-510),183),17,ink)
	text_at(("进攻方  /  路线 "+game.plan) if p.team==0 else "防守方  /  A & B",Vector2(29,246),16,ink)
	if p==game.bomb_carrier:text_at("携带 C4 · 进入包点后按住 E",Vector2(29,276),15,gold)
	radar()
	if Input.is_action_pressed("score"):scoreboard(center)

func progress_bar(center: Vector2,label: String,progress: float):
	text_at(label,center+Vector2(-49,0),18,ink)
	draw_rect(Rect2(center+Vector2(-85,15),Vector2(170,4)),Color(.25,.29,.28))
	draw_rect(Rect2(center+Vector2(-85,15),Vector2(170*clampf(progress,0,1),4)),gold)

func scope_mask(c: Vector2,r: float):
	var black=Color(.005,.008,.01)
	draw_rect(Rect2(0,0,c.x-r,size.y),black);draw_rect(Rect2(c.x+r,0,size.x-c.x-r,size.y),black)
	draw_rect(Rect2(c.x-r,0,r*2,c.y-r),black);draw_rect(Rect2(c.x-r,c.y+r,r*2,size.y-c.y-r),black)
	for i in 4:
		var a=i*PI/2;var b=(i+1)*PI/2
		var points=PackedVector2Array([c+Vector2(cos(a)+cos(b),sin(a)+sin(b))*r])
		for j in 33:
			var angle=lerpf(a,b,j/32.);points.append(c+Vector2(cos(angle),sin(angle))*r)
		draw_colored_polygon(points,black)
	draw_arc(c,r,0,TAU,128,Color(.06,.06,.06),6)
	draw_line(c-Vector2(r,0),c+Vector2(r,0),black,2,true);draw_line(c-Vector2(0,r),c+Vector2(0,r),black,2,true)
	draw_circle(c,1.4,Color(.68,.12,.08))

func radar():
	var origin=Vector2(30,30);draw_rect(Rect2(origin,Vector2(186,198)),Color(.025,.04,.04,.85))
	var scale_=2.65;var offset=origin+Vector2(94,99)
	for rect in game.world.solids:draw_rect(Rect2(offset+rect.position*scale_,rect.size*scale_),Color(.46,.48,.40,.68))
	for name_ in game.world.SITES:
		var site=game.world.SITES[name_];text_at(name_,offset+Vector2(site.x,site.z)*scale_+Vector2(-5,5),16,gold)
	var p=game.player;var pt=offset+Vector2(p.position.x,p.position.z)*scale_
	var dir=Vector2(-sin(p.rotation.y),-cos(p.rotation.y));var side=Vector2(-dir.y,dir.x)
	if p.hp>0:draw_colored_polygon(PackedVector2Array([pt+dir*7,pt-dir*4+side*4,pt-dir*4-side*4]),gold)
	for bot in game.bots:
		if bot.hp<=0:continue
		var to=bot.position-p.position;var seen=(-p.global_basis.z).dot(to.normalized())>.5 and to.length()<40 and game.clear_sight(p.camera.global_position,bot.position+Vector3.UP*1.5)
		if bot.team==p.team or (seen and p.hp>0):draw_circle(offset+Vector2(bot.position.x,bot.position.z)*scale_,3.3,Color(.37,.77,1) if bot.team==p.team else Color(.96,.36,.24))
	if game.bomb_state=="planted" or (p.team==0 and game.bomb_state=="dropped"):
		draw_circle(offset+Vector2(game.bomb_position.x,game.bomb_position.z)*scale_,4,Color(1,.7,.2))

func scoreboard(c: Vector2):
	draw_rect(Rect2(c+Vector2(-410,-252),Vector2(820,505)),Color(.025,.04,.05,.97))
	for team_ in 2:
		var x=c.x-378+team_*410
		text_at(("进攻方 T" if team_==0 else "防守方 CT")+"   %d"%game.scores[team_],Vector2(x,c.y-196),27,gold if team_==0 else Color(.4,.77,1))
		text_at("队员                         击杀 / 阵亡",Vector2(x,c.y-136),16,ink)
		var row=0
		for a in game.actors():
			if a.team!=team_:continue
			var name_="你" if a==game.player else a.callsign
			var k=game.kills if a==game.player else a.score_kills;var d=game.deaths if a==game.player else a.score_deaths
			text_at(("● " if a.hp>0 else "× ")+name_,Vector2(x,c.y-84+row*49),20,ink if a.hp>0 else Color(.5,.53,.54))
			text_at("%d / %d"%[k,d],Vector2(x+255,c.y-84+row*49),20,ink);row+=1
