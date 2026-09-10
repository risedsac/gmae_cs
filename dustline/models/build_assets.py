"""Original game weapon meshes. Run: blender -b --python models/build_assets.py."""
import sys, os
sys.path.insert(0,os.path.dirname(__file__))
from model_geometry import *

def build(pistol=False):
    root=empty('Sidearm' if pistol else 'Rifle')
    gun=empty('Gun',root); mag=empty('Magazine',root); support=empty('SupportArm',root); main=empty('MainArm',root); bolt=empty('Bolt',root)
    if not pistol:
        profile('Stamped receiver',[(-.71,-.067),(-.71,.034),(-.60,.075),(-.22,.074),(-.15,.035),(-.16,-.064)],.098,steel,gun)
        # Rounded dust cover with flattened lower silhouette.
        tube('Dust cover', (0,.047,-.65),(0,.047,-.19),.049,steel,gun,vertices=32)
        box('Cover rail',(0,.076,-.405),(.085,.019,.42),steel,gun,.008)
        for z in [-.29,-.49,-.62]: box('Cover rib',(0,.082,z),(.089,.01,.013),edge,gun,.004)
        profile('Walnut stock',[(.16,-.123),(.17,.031),(.10,.052),(-.04,.031),(-.18,.038),(-.19,-.047),(-.047,-.075),(.063,-.133)],.084,wood,gun,.0,.017)
        profile('Stock butt plate',[(.16,-.13),(.174,-.126),(.185,.033),(.164,.044)],.092,rubber,gun,bevel=.006)
        box('Stock collar',(0,-.005,-.145),(.099,.093,.042),steel,gun,.007)
        profile('Pistol grip',[(-.235,-.052),(-.327,-.068),(-.278,-.282),(-.196,-.275)],.068,wood,gun,bevel=.011)
        box('Grip cap',(0,-.277,-.235),(.071,.013,.079),black,gun,.006)
        profile('Lower handguard',[(-1.017,-.027),(-1.006,-.062),(-.732,-.062),(-.703,-.036),(-.71,.007),(-1.015,.007)],.111,wood,gun,bevel=.013)
        tube('Upper handguard',(0,.048,-1.006),(0,.048,-.734),.040,wood,gun,vertices=24)
        for z in [-1.015,-.728]: box('Handguard ferrule',(0,.005,z),(.119,.118,.026),steel,gun,.008)
        for i in range(3):
            for side in [-1,1]: box('Handguard vent',(side*.055,.018,-.78-i*.055),(.008,.022,.034),black,gun,.006)
        tube('Barrel',(0,.005,-1.016),(0,.005,-1.43),.018,steel,gun)
        tube('Gas tube',(0,.064,-1.01),(0,.064,-1.20),.020,steel,gun)
        profile('Gas block',[(-1.22,-.016),(-1.244,.018),(-1.194,.091),(-1.16,.085),(-1.171,.02)],.05,steel,gun)
        tube('Cleaning rod',(0,-.043,-.988),(0,-.043,-1.387),.0065,edge,gun,vertices=12)
        tube('Muzzle collar',(0,.005,-1.399),(0,.005,-1.454),.027,edge,gun)
        tube('Dark bore',(0,.005,-1.455),(0,.005,-1.458),.014,black,gun)
        profile('Front sight block',[(-1.345,-.02),(-1.379,-.014),(-1.38,.105),(-1.347,.10)],.041,steel,gun)
        for side in [-1,1]:
            line('Sight hood',[(side*.008,.146,-1.36),(side*.030,.146,-1.36),(side*.038,.126,-1.36),(side*.026,.106,-1.36)],.0055,steel,gun)
        box('Sight post',(0,.126,-1.36),(.008,.039,.009),edge,gun,.001)
        box('Rear sight base',(0,.096,-.698),(.067,.027,.092),steel,gun,.004)
        for x in [-.027,.027]: box('Rear notch',(x,.12,-.659),(.017,.020,.021),edge,gun,.002)
        box('Ejection opening',(.050,.026,-.34),(.004,.045,.152),black,gun,.005)
        box('Bolt carrier',(.053,.026,-.353),(.013,.029,.126),edge,bolt,.003)
        tube('Charging handle',(.052,.027,-.37),(.106,.027,-.37),.013,steel,bolt)
        line('Safety selector',[(.052,.012,-.206),(.061,-.022,-.23),(.061,-.031,-.432)],.009,steel,gun)
        for z in [-.184,-.535,-.606,-.669]:
            for x in [-.052,.052]: tube('Receiver rivet',(x, -.028,z),(x+math.copysign(.005,x),-.028,z),.0075,edge,gun,vertices=12)
        line('Trigger guard',[(0,-.065,-.365),(0,-.143,-.361),(0,-.155,-.446),(0,-.079,-.464)],.008,steel,gun)
        line('Trigger',[(0,-.063,-.395),(0,-.115,-.415),(0,-.126,-.398)],.007,edge,gun)
        # Continuous curved silhouette with ribs that follow the same curve.
        outline=[(-.575,-.059),(-.458,-.06),(-.458,-.155),(-.486,-.25),(-.539,-.337),(-.606,-.41),(-.711,-.365),(-.647,-.296),(-.602,-.215),(-.58,-.13)]
        profile('Curved magazine',outline,.077,steel,mag,bevel=.008)
        for side in [-1,1]:
            for offset in [0,.026,.052]:
                line('Magazine pressed rib',[(side*.040,-.122,-.485-offset),(side*.041,-.216,-.507-offset),(side*.041,-.294,-.55-offset),(side*.041,-.361,-.611-offset)],.0035,edge,mag)
        line('Magazine base seam',[(-.041,-.407,-.606),(-.042,-.365,-.711),(.042,-.365,-.711),(.042,-.407,-.606)],.005,edge,mag)
    else:
        profile('Slide chamfer',[(-.68,-.005),(-.674,.07),(-.637,.088),(-.326,.088),(-.298,.054),(-.298,-.006)],.111,steel,bolt,bevel=.009)
        box('Slide top',(0,.078,-.48),(.081,.019,.292),steel,bolt,.006)
        box('Ejection port',(.045,.067,-.499),(.025,.016,.075),black,bolt,.003)
        box('Chamber',(0,.075,-.492),(.047,.009,.065),edge,bolt,.003)
        profile('Polymer frame',[(-.674,-.027),(-.65,-.065),(-.446,-.066),(-.425,-.118),(-.374,-.109),(-.31,-.062),(-.301,-.01)],.11,rubber,gun)
        profile('Textured grip',[(-.32,-.042),(-.413,-.075),(-.352,-.302),(-.239,-.281)],.085,rubber,gun,bevel=.014)
        profile('Grip backstrap',[(-.314,-.078),(-.248,-.281),(-.23,-.27),(-.294,-.064)],.068,leather,gun)
        for side in [-1,1]:
            for i in range(7): box('Slide serration',(side*.056,.030,-.32-i*.017),(.004,.058,.006),edge,bolt,.0015)
            for i in range(5): line('Grip stippling',[(side*.044,-.125-i*.027,-.379+i*.008),(side*.044,-.128-i*.027,-.305+i*.008)],.0025,leather,gun)
        line('Squared trigger guard',[(0,-.045,-.544),(0,-.124,-.53),(0,-.151,-.473),(0,-.13,-.411)],.011,rubber,gun)
        line('Trigger',[(0,-.054,-.472),(0,-.111,-.489),(0,-.122,-.477)],.01,black,gun)
        tube('Barrel',(0,.026,-.663),(0,.026,-.691),.026,edge,gun)
        tube('Bore',(0,.026,-.692),(0,.026,-.695),.016,black,gun)
        for x in [-.038,.038]: box('Rear sight',(x,.103,-.332),(.022,.021,.031),black,bolt,.002)
        box('Front sight',(0,.104,-.645),(.018,.017,.027),black,bolt,.002)
        box('Magazine floor',(0,-.300,-.292),(.096,.027,.123),black,mag,.007)
        box('Slide catch',(-.06,-.006,-.374),(.014,.015,.043),edge,gun,.002)
    arm(main); arm(support,True,pistol)
    # Consolidate parts while retaining four independently animated pivots.
    for group in [gun,mag,support,main,bolt]:
        meshes=[]
        for obj in list(group.children):
            if obj.type=='CURVE':
                bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj; bpy.ops.object.convert(target='MESH')
            if obj.type=='MESH':
                bpy.context.view_layer.objects.active=obj
                for mod in list(obj.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
                meshes.append(obj)
        bpy.ops.object.select_all(action='DESELECT')
        for obj in meshes: obj.select_set(True)
        bpy.context.view_layer.objects.active=meshes[0]; bpy.ops.object.join(); meshes[0].name=group.name+'Surface'
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for o in root.children_recursive: o.select_set(True)
    path=os.path.join(OUT,'sidearm.glb' if pistol else 'rifle.glb')
    bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',use_selection=True,export_animations=False,export_yup=True,export_cameras=False,export_lights=False)
    return root

rifle=build(False); sidearm=build(True)
# Save both editable assets, arranged as a studio presentation.
sidearm.location.x=1.1
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK,'outputs/Dustline-weapons.blend'))

# Render the rifle in a player's view for silhouette / grip QA.
for o in [sidearm]+list(sidearm.children_recursive): o.hide_render=True
world=bpy.context.scene.world or bpy.data.worlds.new('Studio'); bpy.context.scene.world=world; world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.19,.23,.28,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.7
def area(name,pos,power,size):
    bpy.ops.object.light_add(type='AREA',location=co(pos)); l=bpy.context.object; l.name=name; l.data.energy=power; l.data.shape='DISK'; l.data.size=size
    l.rotation_euler=(co((0,0,-.55))-l.location).to_track_quat('-Z','Y').to_euler()
area('Large warm key',(-1.5,2,1),160,3); area('Cool edge',(2,1,-2),200,2)
bpy.ops.object.camera_add(location=co((.56,.35,.79))); camera=bpy.context.object
camera.rotation_euler=(co((0,-.1,-.53))-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.lens=43
scene=bpy.context.scene; scene.camera=camera; scene.render.engine='CYCLES'; scene.cycles.samples=24
scene.render.resolution_x=1100; scene.render.resolution_y=800; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.filepath=os.path.join(WORK,'work/weapon-studio.png')
scene.view_settings.view_transform='AgX'
bpy.ops.render.render(write_still=True)
print('Original weapon assets exported and rendered.')
