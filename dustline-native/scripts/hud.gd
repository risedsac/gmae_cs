extends Control

var game
var menu: Control
var shop: Control
var shop_status: Label
var shop_feedback: Label
var shop_detail_name: Label
var shop_detail_meta: Label
var shop_detail_state: Label
var shop_buy_button: Button
var shop_item_buttons={}
var shop_selected="ak"
var preview_viewport: SubViewport
var preview_model_root: Node3D
var preview_camera: Camera3D
const SHOP_ORDER=["ak","m4","awp","he","smoke","armor","kit"]
const SHOP_SHORTCUTS={KEY_1:"ak",KEY_2:"m4",KEY_3:"awp",KEY_4:"he",KEY_5:"smoke",KEY_6:"armor",KEY_7:"kit"}
const W=preload("res://scripts/weapons.gd")
var title: Label
var subtitle: Label
var begin_button: Button
var resume_button: Button
var font=preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
var ink=Color(.94,.93,.86)
var gold=Color(.89,.68,.34)

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE;process_mode=Node.PROCESS_MODE_ALWAYS
	build_menu();build_shop()

func label_at(parent: Node,text_: String,pos: Vector2,size_: int,color=Color(.93,.92,.86)) -> Label:
	var label=Label.new();label.text=text_;label.position=pos;label.add_theme_font_size_override("font_size",size_);label.add_theme_color_override("font_color",color);parent.add_child(label);return label

func styled_label(text_: String,size_: int,color=Color(.93,.92,.86)) -> Label:
	var label=Label.new();label.text=text_;label.add_theme_font_size_override("font_size",size_);label.add_theme_color_override("font_color",color);return label

func build_menu():
	menu=Control.new();menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(menu)
	var shade=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(.035,.05,.06,.88);menu.add_child(shade)
	var panel=Control.new();panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);panel.position=Vector2(-570,-330);menu.add_child(panel)
	label_at(panel,"DUSTLINE    /    DESERT OPERATIONS",Vector2(0,0),18,gold);title=label_at(panel,"沙漠行动",Vector2(0,55),66)
	subtitle=label_at(panel,"沙漠双点  ·  5v5 爆破",Vector2(3,145),22,Color(.7,.74,.72));label_at(panel,"进攻方安装 C4，防守方阻止或拆除。\n每回合阵亡后等待下一回合复活。",Vector2(3,207),20)
	begin_button=button(panel,"开始比赛   →",Vector2(0,310),Vector2(350,58));begin_button.pressed.connect(func():game.start())
	resume_button=button(panel,"继续游戏",Vector2(0,381),Vector2(350,50));resume_button.pressed.connect(func():game.resume());resume_button.visible=false
	var quit_button=button(panel,"退出",Vector2(0,510),Vector2(140,46));quit_button.pressed.connect(func():get_tree().quit())
	label_at(panel,"对局设置",Vector2(615,65),24,gold);label_at(panel,"你的阵营",Vector2(615,115),18)
	var team_select=OptionButton.new();team_select.position=Vector2(810,109);team_select.size=Vector2(240,38);team_select.add_item("进攻方 T");team_select.add_item("防守方 CT");team_select.item_selected.connect(func(i):game.player_team=i);panel.add_child(team_select)
	label_at(panel,"人机难度",Vector2(615,174),18);var difficulty=OptionButton.new();difficulty.position=Vector2(810,168);difficulty.size=Vector2(240,40)
	for text_ in ["新兵","标准","老兵"]:difficulty.add_item(text_)
	difficulty.selected=1;difficulty.item_selected.connect(func(i):game.difficulty=i);panel.add_child(difficulty)
	label_at(panel,"鼠标灵敏度",Vector2(615,234),18);var sensitivity=HSlider.new();sensitivity.position=Vector2(810,234);sensitivity.size=Vector2(240,28);sensitivity.min_value=.0006;sensitivity.max_value=.005;sensitivity.step=.0001;sensitivity.value=.002;sensitivity.value_changed.connect(func(v):game.player.sensitivity=v);panel.add_child(sensitivity)
	label_at(panel,"主音量",Vector2(615,294),18);var volume=HSlider.new();volume.position=Vector2(810,294);volume.size=Vector2(240,28);volume.min_value=0;volume.max_value=1;volume.step=.01;volume.value=.65;volume.value_changed.connect(func(v):game.sound.set_volume(v));panel.add_child(volume)
	label_at(panel,"WASD / Shift     移动 / 静步\nCtrl / Space       蹲伏 / 跳跃\nB / E                   购买 / 安拆包\nG / H                   手雷 / 烟雾弹",Vector2(615,350),18,Color(.68,.73,.73))
	label_at(panel,"鼠标左 / 右键   射击 / 开镜\nR / 1 / 2            换弹 / 主副武器\n滚轮 ↑ / ↓          循环切换武器\nEsc / Tab           暂停 / 战绩",Vector2(870,350),18,Color(.68,.73,.73))
	label_at(panel,"5v5   /   A & B   /   先赢 5 回合",Vector2(0,604),16,gold);label_at(panel,"离线爆破   ·   沙漠双点",Vector2(850,604),14,Color(.49,.56,.57))

func button(parent: Node,text_: String,pos: Vector2,size_: Vector2) -> Button:
	var b=Button.new();b.text=text_;b.position=pos;b.size=size_;b.add_theme_font_size_override("font_size",21);apply_button_style(b);parent.add_child(b);return b

func apply_button_style(b: Button):
	var style=StyleBoxFlat.new();style.bg_color=Color(.19,.23,.24);style.border_color=Color(.48,.48,.37);style.set_border_width_all(1);style.content_margin_left=16;style.content_margin_right=16;style.content_margin_top=10;style.content_margin_bottom=10;b.add_theme_stylebox_override("normal",style)
	var hover=style.duplicate();hover.bg_color=Color(.29,.32,.29);hover.border_color=gold;b.add_theme_stylebox_override("hover",hover)
	var focus=hover.duplicate();focus.border_color=Color(1,.82,.42);focus.set_border_width_all(2);b.add_theme_stylebox_override("focus",focus)
	var disabled=style.duplicate();disabled.bg_color=Color(.09,.11,.12);disabled.border_color=Color(.22,.24,.24);b.add_theme_stylebox_override("disabled",disabled);b.add_theme_color_override("font_disabled_color",Color(.48,.51,.50))

func show_menu():
	menu.visible=true;resume_button.visible=game.started and not game.finished;begin_button.text="重新开始   →" if game.started else "开始比赛   →";title.text="比赛结束" if game.finished else ("已暂停" if game.started else "沙漠行动")
	subtitle.text=("%d 次击杀  /  %d 次阵亡"%[game.kills,game.deaths]) if game.finished else "沙漠双点  ·  5v5 爆破"

func _process(_dt):
	if shop.visible:refresh_shop()
	queue_redraw()

func make_shop_preview(parent: Control):
	var frame=Panel.new();frame.custom_minimum_size=Vector2(520,315);frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL;frame.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var fs=StyleBoxFlat.new();fs.bg_color=Color(.045,.06,.067,.96);fs.border_color=Color(.20,.27,.27);fs.set_border_width_all(1);frame.add_theme_stylebox_override("panel",fs);parent.add_child(frame)
	var container=SubViewportContainer.new();container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);container.offset_left=8;container.offset_top=8;container.offset_right=-8;container.offset_bottom=-8;container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(container)
	preview_viewport=SubViewport.new();preview_viewport.size=Vector2i(720,420);preview_viewport.transparent_bg=true;preview_viewport.own_world_3d=true;preview_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;preview_viewport.msaa_3d=Viewport.MSAA_2X;container.add_child(preview_viewport)
	var env=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color(0,0,0,0);e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(.78,.84,.88);e.ambient_light_energy=1.2;e.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.environment=e;preview_viewport.add_child(env)
	var key=DirectionalLight3D.new();key.rotation_degrees=Vector3(-38,-28,0);key.light_energy=2.;key.light_color=Color(1,.90,.78);preview_viewport.add_child(key)
	var fill=DirectionalLight3D.new();fill.rotation_degrees=Vector3(22,150,0);fill.light_energy=.8;fill.light_color=Color(.55,.72,1);preview_viewport.add_child(fill)
	preview_model_root=Node3D.new();preview_viewport.add_child(preview_model_root)
	preview_camera=Camera3D.new();preview_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;preview_camera.position=Vector3(0,.02,2.2);preview_viewport.add_child(preview_camera);preview_camera.current=true

func shop_product_button(parent: Node,item: String,shortcut: int) -> Button:
	var b=Button.new();b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.custom_minimum_size=Vector2(350,50);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.focus_mode=Control.FOCUS_ALL;b.add_theme_font_size_override("font_size",18);apply_button_style(b);parent.add_child(b)
	b.pressed.connect(func():select_shop_item(item))
	b.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
			select_shop_item(item);game.buy(item);b.accept_event())
	b.set_meta("shortcut",shortcut);shop_item_buttons[item]=b;return b

func build_shop():
	shop=Control.new();shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shop.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shop);shop.visible=false
	var shade=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(.025,.04,.055,.97);shop.add_child(shade)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);margin.add_theme_constant_override("margin_left",54);margin.add_theme_constant_override("margin_right",54);margin.add_theme_constant_override("margin_top",38);margin.add_theme_constant_override("margin_bottom",38);shop.add_child(margin)
	var root=VBoxContainer.new();root.add_theme_constant_override("separation",14);margin.add_child(root)
	var top=HBoxContainer.new();root.add_child(top);top.add_child(styled_label("装备购买",36,gold));var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(spacer);shop_status=styled_label("",21,ink);top.add_child(shop_status)
	shop_feedback=styled_label("选择商品查看详情",17,Color(.68,.74,.73));shop_feedback.custom_minimum_size.y=28;root.add_child(shop_feedback)
	var line=HSeparator.new();root.add_child(line)
	var main=HBoxContainer.new();main.size_flags_vertical=Control.SIZE_EXPAND_FILL;main.add_theme_constant_override("separation",28);root.add_child(main)
	var left=VBoxContainer.new();left.custom_minimum_size.x=390;left.add_theme_constant_override("separation",7);main.add_child(left)
	var categories={"主武器":[],"投掷物":[],"装备":[]}
	for item in SHOP_ORDER:categories[str(game.BUY_CATALOG[item].category)].append(item)
	var shortcut=1
	for category in ["主武器","投掷物","装备"]:
		var heading=styled_label(category,18,gold);heading.custom_minimum_size.y=30;left.add_child(heading)
		for item in categories[category]:shop_product_button(left,item,shortcut);shortcut+=1
	var right=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right.size_flags_vertical=Control.SIZE_EXPAND_FILL;right.add_theme_constant_override("separation",10);main.add_child(right)
	shop_detail_name=styled_label("",30,gold);right.add_child(shop_detail_name);shop_detail_meta=styled_label("",17,Color(.72,.77,.76));right.add_child(shop_detail_meta);shop_detail_state=styled_label("",18,ink);right.add_child(shop_detail_state)
	make_shop_preview(right)
	shop_buy_button=Button.new();shop_buy_button.custom_minimum_size.y=54;shop_buy_button.add_theme_font_size_override("font_size",20);apply_button_style(shop_buy_button);shop_buy_button.pressed.connect(func():game.buy(shop_selected));right.add_child(shop_buy_button)
	var bottom=HBoxContainer.new();root.add_child(bottom);var hint=styled_label("单击选中 · 双击购买 · 1–7 快捷购买 · B 返回战场",15,Color(.66,.72,.71));hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bottom.add_child(hint)
	var close=Button.new();close.text="返回战场  [ B ]";close.custom_minimum_size=Vector2(245,45);apply_button_style(close);close.pressed.connect(func():game.toggle_buy());bottom.add_child(close)
	shop.visibility_changed.connect(func():
		if shop.visible:on_shop_opened()
		elif preview_viewport:preview_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED)

func on_shop_opened():
	set_shop_feedback("选择商品；双击可直接购买，不可购买原因会显示在商店内",true);select_shop_item(shop_selected);refresh_shop()
	var first=shop_item_buttons.get(shop_selected)
	if is_instance_valid(first):first.grab_focus()

func set_shop_feedback(text_: String,success: bool):
	if not is_instance_valid(shop_feedback):return
	shop_feedback.text=text_;shop_feedback.add_theme_color_override("font_color",Color(.55,.88,.62) if success else Color(1.,.48,.35))

func select_shop_item(item: String):
	if not game.BUY_CATALOG.has(item):return
	shop_selected=item;update_shop_preview(item);refresh_shop()

func clear_preview():
	if not is_instance_valid(preview_model_root):return
	for child in preview_model_root.get_children():child.queue_free()

func update_shop_preview(item: String):
	clear_preview()
	if not is_instance_valid(preview_viewport):return
	var model: Node3D=null;var ortho=1.4
	if item in ["ak","m4","awp"]:
		var indices={"ak":0,"m4":2,"awp":3};model=W.make(indices[item]);ortho=1.8 if item=="awp" else 1.55
	elif item in ["he","smoke"]:
		model=W.make_utility(item);ortho=.30
	if model:
		preview_model_root.add_child(model);model.rotation=Vector3(-.12,-1.02,.04);model.position=Vector3(0,-.03,0)
	preview_camera.size=ortho;preview_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func refresh_shop():
	if not is_instance_valid(shop_status) or not game.started:return
	shop_status.text="$%d    ·    购买剩余 %.0f 秒"%[game.player.money,maxf(0,game.buy_left)]
	for i in SHOP_ORDER.size():
		var item=SHOP_ORDER[i];var info: Dictionary=game.BUY_CATALOG[item];var state=game.buy_state(item);var b=shop_item_buttons.get(item) as Button
		if b:b.text="[%d]  %-10s   $%d    %s"%[i+1,str(info.name),int(info.price),str(state.status)]
	var selected_info: Dictionary=game.BUY_CATALOG[shop_selected];var selected_state=game.buy_state(shop_selected)
	shop_detail_name.text=str(selected_info.name);shop_detail_meta.text="%s   ·   $%d"%[str(selected_info.category),int(selected_info.price)]
	shop_detail_state.text="状态："+str(selected_state.status);shop_detail_state.add_theme_color_override("font_color",Color(.55,.88,.62) if bool(selected_state.enabled) else Color(1.,.55,.38))
	shop_buy_button.disabled=not bool(selected_state.enabled);shop_buy_button.text=("购买 %s  ·  $%d"%[str(selected_info.name),int(selected_info.price)]) if bool(selected_state.enabled) else str(selected_state.status)

func _unhandled_input(event):
	if not shop.visible or not event is InputEventKey or not event.pressed or event.echo:return
	if SHOP_SHORTCUTS.has(event.physical_keycode):
		var item=str(SHOP_SHORTCUTS[event.physical_keycode]);select_shop_item(item);game.buy(item);get_viewport().set_input_as_handled()

func text_at(text_: String,pos: Vector2,size_: int,color: Color):
	draw_string(font,pos+Vector2(1,2),text_,HORIZONTAL_ALIGNMENT_LEFT,-1,size_,Color(0,0,0,.65));draw_string(font,pos,text_,HORIZONTAL_ALIGNMENT_LEFT,-1,size_,color)

func observed_actor():
	var player=game.player
	if player.hp<=0:
		var target=player.spectator_actor()
		if is_instance_valid(target):return target
	return player

func _draw():
	if not game.started:return
	var w=size.x;var h=size.y;var center=Vector2(w/2,h/2);var player=game.player;var p=observed_actor();var spectating=p!=player
	var weapon_index=int(p.weapon);var shown_hp=int(p.hp);var shown_armor=0 if spectating else int(player.armor)
	var shown_ammo=int(p.ammo) if spectating else int(player.ammo[weapon_index]);var shown_reserve="--" if spectating else "%03d"%int(player.reserve[weapon_index])
	var shown_recoil=float(p.weapon_kick) if spectating else float(player.recoil)
	if not spectating and player.scoped and weapon_index==3 and player.hp>0:scope_mask(center,minf(h*.41,w*.35))
	draw_rect(Rect2(w/2-215,20,430,88),Color(.025,.04,.04,.86));var seconds=ceili(game.bomb_left if game.bomb_state=="planted" else (game.phase_left if game.phase=="freeze" else game.time_left))
	text_at("%02d:%02d"%[seconds/60,seconds%60],Vector2(w/2-42,59),29,Color(1,.37,.22) if game.bomb_state=="planted" else ink);text_at("T  %d"%game.scores[0],Vector2(w/2-191,61),28,gold);text_at("%d  CT"%game.scores[1],Vector2(w/2+105,61),28,Color(.45,.76,1))
	text_at("存活 %d"%game.team_alive(0).size(),Vector2(w/2-189,91),16,ink);text_at("第 %d 回合"%game.round_number,Vector2(w/2-46,91),15,ink);text_at("存活 %d"%game.team_alive(1).size(),Vector2(w/2+113,91),16,ink)
	draw_rect(Rect2(26,h-103,333,75),Color(.025,.04,.04,.78));text_at("+",Vector2(43,h-53),32,gold);text_at(str(shown_hp),Vector2(80,h-50),34,ink);text_at("护甲  %d"%shown_armor,Vector2(191,h-54),21,ink)
	draw_rect(Rect2(43,h-39,142,3),Color(.25,.29,.28));draw_rect(Rect2(43,h-39,142*clampf(shown_hp/100.,0.,1.),3),gold)
	text_at(("观战  "+str(p.callsign)) if spectating else ("$%d   B 购买"%player.money),Vector2(29,h-124),22,gold)
	text_at("HE %d   SMOKE %d   %s"%[int(p.grenades.he),int(p.grenades.smoke),"拆弹器" if p.kit else ""],Vector2(w-315,h-131),16,ink);draw_rect(Rect2(w-287,h-111,260,85),Color(.025,.04,.04,.78))
	text_at(W.DATA[weapon_index].name,Vector2(w-264,h-86),16,gold);text_at("%02d"%shown_ammo,Vector2(w-264,h-43),38,ink);text_at("/  "+shown_reserve,Vector2(w-191,h-47),22,Color(.65,.7,.68));text_at("滚轮 / 1 / 2 切枪",Vector2(w-181,h-18),12,ink)
	if shown_hp>0 and (spectating or (not player.scoped and player.utility_left<=0)):
		var gap=5+shown_recoil*12+Vector2(p.velocity.x,p.velocity.z).length()*1.2
		for dir in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:draw_line(center+dir*gap,center+dir*(gap+7),Color(.63,.95,.76),2)
	if game.hit_marker>0 and not spectating:
		for dir in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]:draw_line(center+dir*7,center+dir*13,ink,2)
	if float(p.reload_left)>0:
		var duration=2.35 if spectating else maxf(player.reload_duration,.001);progress_bar(center+Vector2(0,64),"正在换弹",1-float(p.reload_left)/duration)
	if not spectating and game.interaction_actor==player:progress_bar(center+Vector2(0,100),"安装 C4" if player.team==0 else "拆除 C4",game.interaction_progress/game.interaction_duration)
	elif not spectating and player.hp>0 and game.phase in ["live","planted"]:
		if player==game.bomb_carrier and game.world.site_at(player.position)!="":text_at("按住 E 安装 C4",center+Vector2(-82,84),20,gold)
		elif player.team==1 and game.bomb_state=="planted" and player.position.distance_to(game.bomb_position)<2.5:text_at("按住 E 拆除 C4",center+Vector2(-82,84),20,gold)
	if game.hurt_overlay>0 and not spectating:
		var c=Color(.7,.09,.04,game.hurt_overlay*.6);draw_rect(Rect2(0,0,w,12),c);draw_rect(Rect2(0,h-12,w,12),c);draw_rect(Rect2(0,0,12,h),c);draw_rect(Rect2(w-12,0,12,h),c)
	if player.hp<=0:
		text_at("观战 "+(str(p.callsign) if spectating else "本回合已阵亡"),Vector2(w/2-155,h-105),23,ink);text_at("点击切换队友 · 下一回合复活",Vector2(w/2-155,h-71),17,gold)
	if game.phase=="freeze":text_at("购买阶段 · B 购买 · "+("你携带 C4" if player==game.bomb_carrier else "准备行动"),Vector2(w/2-175,142),20,gold)
	if game.bomb_state=="planted":text_at(game.planted_site+" 点 C4 已安装",Vector2(w/2-88,140),20,Color(1,.44,.26))
	if game.phase=="end":draw_rect(Rect2(center+Vector2(-290,-70),Vector2(580,145)),Color(.035,.045,.05,.94));text_at(("进攻方" if game.winner==0 else "防守方")+"获胜",center+Vector2(-105,-12),35,gold);text_at(game.round_reason+" · %.0f 秒后下一回合"%game.phase_left,center+Vector2(-165,38),20,ink)
	if game.message_left>0:text_at(game.message,Vector2(maxf(240,w-510),183),17,ink)
	text_at(("进攻方  /  路线 "+game.plan) if p.team==0 else "防守方  /  A & B",Vector2(29,246),16,ink)
	if p==game.bomb_carrier:text_at("携带 C4 · 进入包点后按住 E",Vector2(29,276),15,gold)
	radar();if Input.is_action_pressed("score"):scoreboard(center)

func progress_bar(center: Vector2,label: String,progress: float):
	text_at(label,center+Vector2(-49,0),18,ink);draw_rect(Rect2(center+Vector2(-85,15),Vector2(170,4)),Color(.25,.29,.28));draw_rect(Rect2(center+Vector2(-85,15),Vector2(170*clampf(progress,0,1),4)),gold)

func scope_mask(c: Vector2,r: float):
	var black=Color(.005,.008,.01);draw_rect(Rect2(0,0,c.x-r,size.y),black);draw_rect(Rect2(c.x+r,0,size.x-c.x-r,size.y),black);draw_rect(Rect2(c.x-r,0,r*2,c.y-r),black);draw_rect(Rect2(c.x-r,c.y+r,r*2,size.y-c.y-r),black)
	for i in 4:
		var a=i*PI/2;var b=(i+1)*PI/2;var points=PackedVector2Array([c+Vector2(cos(a)+cos(b),sin(a)+sin(b))*r])
		for j in 33:
			var angle=lerpf(a,b,j/32.);points.append(c+Vector2(cos(angle),sin(angle))*r)
		draw_colored_polygon(points,black)
	draw_arc(c,r,0,TAU,128,Color(.06,.06,.06),6);draw_line(c-Vector2(r,0),c+Vector2(r,0),black,2,true);draw_line(c-Vector2(0,r),c+Vector2(0,r),black,2,true);draw_circle(c,1.4,Color(.68,.12,.08))

func radar():
	var origin=Vector2(30,30);draw_rect(Rect2(origin,Vector2(186,198)),Color(.025,.04,.04,.85));var scale_=2.65;var offset=origin+Vector2(94,99)
	for rect in game.world.solids:draw_rect(Rect2(offset+rect.position*scale_,rect.size*scale_),Color(.46,.48,.40,.68))
	for name_ in game.world.SITES:
		var site=game.world.SITES[name_];text_at(name_,offset+Vector2(site.x,site.z)*scale_+Vector2(-5,5),16,gold)
	var player=game.player;var p=observed_actor();var pt=offset+Vector2(p.position.x,p.position.z)*scale_;var dir=Vector2(-sin(p.rotation.y),-cos(p.rotation.y));var side=Vector2(-dir.y,dir.x)
	if p.hp>0:draw_colored_polygon(PackedVector2Array([pt+dir*7,pt-dir*4+side*4,pt-dir*4-side*4]),gold)
	for bot in game.bots:
		if bot.hp<=0 or bot==p:continue
		var to=bot.position-p.position;var eye=player.camera.global_position if p!=player else player.camera.global_position;var forward=-player.camera.global_basis.z if p!=player else -p.global_basis.z
		var seen=forward.dot(to.normalized())>.5 and to.length()<40 and game.clear_sight(eye,bot.position+Vector3.UP*1.5)
		if bot.team==p.team or seen:draw_circle(offset+Vector2(bot.position.x,bot.position.z)*scale_,3.3,Color(.37,.77,1) if bot.team==p.team else Color(.96,.36,.24))
	if game.bomb_state=="planted" or (p.team==0 and game.bomb_state=="dropped"):draw_circle(offset+Vector2(game.bomb_position.x,game.bomb_position.z)*scale_,4,Color(1,.7,.2))

func scoreboard(c: Vector2):
	draw_rect(Rect2(c+Vector2(-410,-252),Vector2(820,505)),Color(.025,.04,.05,.97))
	for team_ in 2:
		var x=c.x-378+team_*410;text_at(("进攻方 T" if team_==0 else "防守方 CT")+"   %d"%game.scores[team_],Vector2(x,c.y-196),27,gold if team_==0 else Color(.4,.77,1));text_at("队员                         击杀 / 阵亡",Vector2(x,c.y-136),16,ink);var row=0
		for a in game.actors():
			if a.team!=team_:continue
			var name_="你" if a==game.player else a.callsign;var k=game.kills if a==game.player else a.score_kills;var d=game.deaths if a==game.player else a.score_deaths
			text_at(("● " if a.hp>0 else "× ")+name_,Vector2(x,c.y-84+row*49),20,ink if a.hp>0 else Color(.5,.53,.54));text_at("%d / %d"%[k,d],Vector2(x+255,c.y-84+row*49),20,ink);row+=1
