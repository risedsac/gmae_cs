extends SceneTree
var game
var passed=0
var failed=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 if ok:passed+=1;print("PASS ",message)
 else:failed+=1;push_error("FAIL "+message)
func frames(n: int):
 for i in n:await physics_frame
func fresh(team_=0):
 Input.action_release("interact");Input.action_release("forward");Input.action_release("fire")
 game.player_team=team_;game.start()
 for b in game.bots:b.set_physics_process(false)
 game.player.set_physics_process(true)
 await frames(4)
func live():game.phase="live";game.phase_left=0;game.hud.shop.visible=false
func plant_at(pos: Vector3):
 game.bomb_state="planted";game.phase="planted";game.bomb_position=pos;game.planted_site=game.world.site_at(pos);game.bomb_left=40;game.bomb_carrier=null
func run():
 game=load("res://main.tscn").instantiate();root.add_child(game);game.test_mode=true
 await fresh()
 var p=game.player
 check(game.actors().size()==10 and game.team_alive(0).size()==5 and game.team_alive(1).size()==5,"exactly 5v5 including player and four teammates")
 check(game.bomb_carrier==p and p.team==0,"attacker player starts carrying C4")
 for a in game.actors():check(game.world.walkable(a.position),"spawn outside solids: "+a.name)
 for site in ["A","B"]:
  var route=game.world.route_to(site,0);var prev=Vector3(0,0,25);var total=0.
  for point in route:
   var path=game.world.path(prev,point);check(not path.is_empty(),site+" route segment reachable")
   total+=path.size()*.5;prev=point
  check(game.world.site_at(prev)==site,"attack route ends inside "+site+" plant zone")
 check(game.can_buy(),"buy allowed during freeze in own spawn")
 var pos=p.position;Input.action_press("forward");p.shot_queued=true;await frames(10);Input.action_release("forward")
 check(Vector2(pos.x-p.position.x,pos.z-p.position.z).length()<.03 and p.ammo[1]==12,"freeze blocks movement and shooting")
 check(game.buy("ak") and p.primary==0 and p.money==2300,"AK purchase debits correct price and equips")
 var cash=p.money;check(not game.buy("ak") and p.money==cash,"duplicate primary rejected without charging")
 check(not game.buy("awp") and p.money==cash,"insufficient funds cannot buy sniper")
 p.money=16000;check(game.buy("m4") and p.primary==2 and not p.owned[0],"M4 replaces primary with distinct model and data")
 check(game.buy("awp") and p.primary==3 and p.ammo[3]==5,"sniper equips five round magazine")
 check(game.buy("he") and game.buy("smoke"),"both utility types purchasable")
 cash=p.money;check(not game.buy("he") and p.money==cash,"grenade capacity prevents duplicate purchases")
 check(game.buy("armor") and p.armor==100,"armor purchase restores armor")
 check(not game.buy("kit"),"attackers cannot buy defuse kit")
 p.position=Vector3(20,0,0);check(not game.buy("m4"),"buying outside spawn rejected")
 p.position=Vector3(0,0,25);game.buy_left=0;check(not game.buy("m4"),"buying after timer rejected")
 live();p.equip_primary(0);p.shot_cooldown=0
 var ally=game.bots[0];var enemy=game.bots[4]
 p.position=Vector3(0,0,24);ally.position=Vector3(0,0,19);enemy.position=Vector3(2,0,19)
 await frames(3)
 p.camera.look_at(ally.position+Vector3.UP);p.fire()
 check(ally.hp==100,"bullets do not damage teammates")
 p.recoil=0;p.shot_cooldown=0;p.camera.look_at(enemy.position+Vector3.UP);p.fire()
 check(enemy.hp==64,"rifle native hitscan damages hostile actor")
 p.equip_primary(3);p.scoped=true;p.update_view(0,0)
 check(p.camera.fov==25 and not p.weapon_anchor.visible,"sniper scope changes FOV and hides viewmodel")
 p.switch_weapon(1);check(not p.scoped,"switching weapon exits scope")
 p.position=Vector3(0,0,24);await frames(3)
 game.interact(p,true,4);check(game.bomb_state=="carried","cannot plant outside bomb sites")
 p.position=Vector3(18,0,-21);p.velocity=Vector3.ZERO;await frames(4)
 Input.action_press("interact");await frames(50);Input.action_release("interact");await frames(2)
 check(game.interaction_progress==0 and game.bomb_state=="carried","releasing E cancels planting progress")
 Input.action_press("interact");await frames(197);Input.action_release("interact")
 check(game.bomb_state=="planted" and game.planted_site=="A","holding E plants at A site")
 for a in game.team_alive(0):a.take_damage(10000,false,enemy)
 check(game.phase=="planted","planted bomb keeps round alive after attackers eliminated")
 game.bomb_left=.01;await frames(2)
 check(game.winner==0 and game.phase=="end","C4 detonation awards attack round")
 var score=game.scores[0];game.end_round(0,"duplicate");check(game.scores[0]==score,"round result cannot score twice")
 await fresh(1);live();check(p.team==1 and game.bomb_carrier.team==0 and game.bomb_carrier!=p,"CT choice assigns bomb to opposing AI")
 p.money=5000;game.phase="freeze";check(game.buy("kit") and p.kit,"CT can buy defuse kit")
 live();p.position=Vector3(-16,0,-24);p.velocity=Vector3.ZERO;await frames(4);plant_at(p.position)
 Input.action_press("interact");await frames(160);Input.action_release("interact");await frames(2)
 check(game.interaction_progress==0 and game.bomb_state=="planted","releasing E cancels defuse")
 Input.action_press("interact");await frames(305);Input.action_release("interact")
 check(game.bomb_state=="defused" and game.winner==1,"kit defuse finishes after five seconds")
 await fresh(1);live();p.position=Vector3(18,0,-21);p.velocity=Vector3.ZERO;await frames(4);plant_at(p.position);p.kit=false
 Input.action_press("interact");await frames(305)
 check(game.bomb_state=="planted","no-kit defuse does not finish in five seconds")
 await frames(305);Input.action_release("interact")
 check(game.bomb_state=="defused","no-kit defuse finishes in ten seconds")
 await fresh();live();var drop=p.position;p.take_damage(10000,false,game.bots[4])
 check(game.bomb_state=="dropped" and p.hp==0,"carrier death drops C4 and does not respawn mid-round")
 ally=game.bots[0];ally.position=drop;await frames(3)
 check(game.bomb_carrier==ally and game.bomb_state=="carried","living teammate picks up dropped C4")
 await frames(200);check(p.hp==0,"death remains spectating until next round")
 game.end_round(1,"test");var money=p.money;game.phase_left=.01;await frames(3)
 check(p.hp==100 and game.phase=="freeze" and p.primary==-1 and p.money==money,"new round respawns dead player with economy retained and weapons lost")
 await fresh();live();game.time_left=.01;await frames(2);check(game.winner==1,"unplanted timeout awards defense")
 await fresh();live()
 for a in game.team_alive(1):a.take_damage(10000,false,p)
 check(game.winner==0,"eliminating defenders awards attack")
 await fresh();live()
 for a in game.team_alive(0):a.take_damage(10000,false,game.bots[4])
 check(game.winner==1,"eliminating attackers before plant awards defense")
 await fresh();live();p.grenades={"he":1,"smoke":1};p.position=Vector3(0,0,25)
 check(game.throw_grenade(p,"he",Vector3.FORWARD,p.position+Vector3.UP*1.6) and p.grenades.he==0,"throw consumes grenade and creates native rigid body")
 check(not game.throw_grenade(p,"he",Vector3.FORWARD,p.position+Vector3.UP),"cannot throw missing utility")
 var projectile=game.projectiles[0];var before_fuse=projectile.fuse
 game.pause();await frames(20);check(is_equal_approx(projectile.fuse,before_fuse),"pause freezes grenade fuse")
 game.resume();await frames(110);check(game.projectiles.is_empty(),"HE fuse detonates and removes projectile")
 enemy=game.bots[4];enemy.position=Vector3(2,0,20);await frames(3)
 game.explode(Vector3(2,0,19),7,110,p);check(enemy.hp<100,"HE applies radial hostile damage")
 enemy.hp=100;enemy.position=Vector3(-7,0,-11);await frames(3)
 game.explode(Vector3(-7,0,8),25,110,p);check(enemy.hp==100,"wall blocks explosion damage")
 game.add_smoke(Vector3(0,0,17));await frames(35)
 check(not game.clear_sight(Vector3(0,1.5,23),Vector3(0,1.5,12)),"smoke blocks AI and radar visibility")
 check(game.ray(Vector3(0,1.5,23),Vector3(0,1.5,12),1).is_empty(),"smoke does not become bulletproof collision")
 enemy.position=Vector3(0,0,12);enemy.rotation.y=PI;p.position=Vector3(0,0,23);await frames(3)
 check(not enemy.see_actor(p),"enemy cannot detect player through smoke")
 game.smokes[0].left=.01;await frames(2);check(game.smokes.is_empty(),"smoke expires and removes visibility blocker")
 check(not ally.see_actor(p),"AI perception rejects friendly targets")
 p.equip_primary(3);p.scoped=true;p.shot_cooldown=0;p.recoil=0;p.reload_left=0;p.fire()
 check(not p.scoped and p.rescope_after_shot,"scoped sniper shot exits zoom during bolt cycle")
 await frames(90);check(p.scoped,"sniper returns to scope after bolt cycle")
 p.ammo[3]=2;p.reserve[3]=1;p.request_reload();check(not p.scoped,"sniper reload cancels scope")
 await frames(190);check(p.ammo[3]==3 and p.reserve[3]==0,"sniper reload respects reserve ammunition")
 p.equip_primary(2);p.shot_cooldown=0;p.ammo[2]=30
 Input.action_press("fire");await frames(31);Input.action_release("fire")
 check(p.ammo[2]<=25 and p.ammo[2]>=23,"M4 automatic fire uses its own cadence")
 check(AudioServer.get_bus_effect_count(0)>0,"master bus has a peak limiter for overlapping shots")
 await fresh(1);live();game.plan="B";p.protection=999
 var carrier=game.bomb_carrier;carrier.position=Vector3(-16,0,-22);carrier.route_stage=5;carrier.set_physics_process(true)
 await frames(210)
 check(game.bomb_state=="planted" and game.planted_site=="B","attacking AI independently plants at B")
 carrier.set_physics_process(false)
 for actor in game.team_alive(0):actor.protection=999
 var defender=game.bots[0];defender.position=game.bomb_position+Vector3(.65,0,0);defender.set_physics_process(true)
 game.add_smoke(game.bomb_position)
 await frames(310)
 check(game.bomb_state=="defused" and game.winner==1,"defending teammate AI defuses even inside smoke")
 await fresh();live();p.equip_primary(2);p.grenades.smoke=1
 game.end_round(0,"test");game.phase_left=.01;await frames(3)
 check(p.primary==2 and p.owned[2] and p.grenades.smoke==1,"surviving player keeps weapons and unused utility")
 game.scores=[4,0];live();game.end_round(0,"match point");game.phase_left=.01;await frames(3)
 check(game.finished and not game.active,"first five rounds ends match and opens result menu")
 # Live AI: observe progress and actions without forcing a winner.
 await fresh(1);live();p.protection=999
 for b in game.bots:b.set_physics_process(true)
 var moved={};var initial={};var max_shots=0;var objective_seen=false;var initial_round=game.round_number
 for b in game.bots:initial[b.index]=b.position;moved[b.index]=0.
 for f in 9000:
  await physics_frame
  for b in game.bots:moved[b.index]+=b.position.distance_to(initial[b.index]);initial[b.index]=b.position;max_shots+=b.shot_count;b.shot_count=0
  if game.bomb_state in ["planted","defused","exploded"]:objective_seen=true
  if game.round_number>initial_round or game.finished:break
 check(max_shots>10,"both-team AI simulation produces combat ("+str(max_shots)+" shots)")
 var mobile=0
 for value in moved.values():if value>10:mobile+=1
 check(mobile>=7,"AI agents traverse attack and defense routes")
 print("AI_OBJECTIVE_OBSERVED ",objective_seen," phase=",game.phase," reason=",game.round_reason)
 print("DEMOLITION_RESULT ",passed," passed / ",failed," failed")
 game.sound.silence();OS.delay_msec(100);paused=false;game.queue_free();await process_frame;await process_frame
 quit(1 if failed else 0)
