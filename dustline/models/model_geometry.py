"""Original visual game props, authored in Blender. Run: blender -b --python models/build_assets.py.
All coordinates below are view-model coordinates (Y up, muzzle toward -Z).
The assets are illustrative meshes, not manufacturing models.
"""
import bpy, math, random, os
import numpy as np
from mathutils import Vector

random.seed(47)
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '../public/assets')
WORK = os.path.abspath(os.environ.get('DUSTLINE_ARTIFACT_DIR', os.path.join(HERE, '../work/model-artifacts')))
os.makedirs(os.path.join(WORK, 'outputs'), exist_ok=True)
os.makedirs(os.path.join(WORK, 'work'), exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def co(p): return Vector((p[0], -p[2], p[1]))
def empty(name, parent=None, pos=(0,0,0)):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o)
    o.parent=parent; o.location=co(pos); return o

def material(name, color, metallic=0, roughness=.6, texture=None):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metallic; p.inputs['Roughness'].default_value=roughness
    if texture:
        n=512; y,x=np.mgrid[0:n,0:n]; rng=np.random.default_rng(77)
        noise=rng.random((n,n))-.5
        if texture=='walnut':
            grain=np.sin(x*.21 + np.sin(y*.018)*3 + np.sin(y*.051)*.9)
            grain += .5*np.sin(x*.66+np.sin(y*.03)*4)
            shade=.92 + grain*.14 + noise*.08
        elif texture=='steel':
            shade=.9+noise*.18 + np.sin(x*1.5)*.035
            for i in range(95):
                row=random.randrange(n); start=random.randrange(n-40)
                shade[row:row+1,start:start+random.randrange(8,40)]=1.45
        else:
            shade=.94+noise*.10+(x%4==0)*.05+(y%4==0)*.04
        rgba=np.ones((n,n,4),dtype=np.float32)
        # Image pixels are stored in linear space by Blender, exported as sRGB.
        for i in range(3):
            linear=np.clip(color[i]*shade,0,1)
            rgba[:,:,i]=np.where(linear<=.0031308,linear*12.92,1.055*np.power(linear,1/2.4)-.055)
        im=bpy.data.images.new(name+' albedo',n,n)
        im.pixels.foreach_set(rgba.ravel()); im.pack()
        tex=m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=im
        m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
    return m

steel=material('Parkerized steel',(.048,.055,.061),.82,.37,'steel')
edge=material('Worn steel edges',(.14,.15,.15),.86,.31)
black=material('Recesses',(.011,.014,.016),.32,.69)
wood=material('Oiled walnut',(.16,.05,.019),0,.36,'walnut')
rubber=material('Grip polymer',(.025,.032,.030),0,.81,'fabric')
cloth=material('Olive ripstop',(.13,.15,.11),0,.92,'fabric')
glove=material('Suede gloves',(.19,.17,.118),0,.87,'fabric')
leather=material('Glove reinforcement',(.067,.066,.049),0,.65)
stitch=material('Stitching',(.29,.28,.22),0,.9)

def finish(o, name, mat, parent, bevel=0, smooth=False):
    o.name=name; o.parent=parent; o.data.materials.append(mat)
    if bevel:
        mod=o.modifiers.new('Machined edge radii','BEVEL'); mod.width=bevel; mod.segments=3
        mod.affect='EDGES'
        mod=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL'); mod.keep_sharp=True; mod.weight=35
    for p in o.data.polygons: p.use_smooth=smooth
    return o

def box(name, p, size, mat, parent, bevel=.005):
    bpy.ops.mesh.primitive_cube_add(size=1,location=co(p)); o=bpy.context.object
    o.dimensions=(size[0],size[2],size[1]); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat,parent,bevel)

def ellipsoid(name,p,size,mat,parent):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=co(p)); o=bpy.context.object
    o.scale=(size[0],size[2],size[1]); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat,parent,0,True)

def tube(name,a,b,r,mat,parent,r2=None,vertices=24):
    a,b=co(a),co(b); d=b-a
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r if r2 is None else r2,depth=d.length,location=(a+b)/2)
    o=bpy.context.object; o.rotation_mode='QUATERNION'; o.rotation_quaternion=d.to_track_quat('Z','Y')
    return finish(o,name,mat,parent,.0015,True)

def line(name, points, radius, mat, parent):
    c=bpy.data.curves.new(name,'CURVE'); c.dimensions='3D'; c.resolution_u=2; c.bevel_depth=radius; c.bevel_resolution=2
    s=c.splines.new('POLY'); s.points.add(len(points)-1)
    for v,p in zip(s.points,points): v.co=(*co(p),1)
    o=bpy.data.objects.new(name,c); bpy.context.collection.objects.link(o); o.parent=parent; c.materials.append(mat)
    return o

def profile(name, yz, width, mat, parent, x=0, bevel=.006):
    # Side silhouette extruded through X. yz pairs are (longitudinal Z, height Y).
    verts=[co((x+side*width/2,y,z)) for side in [-1,1] for z,y in yz]; n=len(yz)
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    m=bpy.data.meshes.new(name); m.from_pydata(verts,[],faces); m.update()
    o=bpy.data.objects.new(name,m); bpy.context.collection.objects.link(o)
    finish(o,name,mat,parent,bevel)
    # A longitudinal UV projection keeps grain following the wooden furniture.
    uv=m.uv_layers.new()
    for poly in m.polygons:
        for li in poly.loop_indices:
            v=m.vertices[m.loops[li].vertex_index].co
            uv.data[li].uv=(v.x*5+v.z*3, v.y*2.8)
    return o

def arm(parent, support=False, pistol=False):
    # Lofts form tapered fabric with restrained creases; palms and curled fingers
    # are individually surfaced rather than rectangular hand placeholders.
    if support:
        a=(-.39,-.61,.14); b=(-.10,-.22,-.72 if not pistol else -.30)
        palm=(-.035,-.115,-.83) if not pistol else (-.055,-.16,-.31)
    else:
        a=(.29,-.51,.24); b=(.06,-.245,-.24); palm=(.033,-.175,-.29)
    av,bv=Vector(a),Vector(b); d=(bv-av).normalized()
    u=d.cross(Vector((1,0,0))).normalized(); v=d.cross(u).normalized()
    verts=[]; rings=18; sides=20
    for j in range(rings):
        t=j/(rings-1); center=av.lerp(bv,t)
        r=(.105*(1-t)+.067*t)*(1+.035*math.sin(j*3.1))
        for k in range(sides):
            ang=k*2*math.pi/sides
            rad=r*(1+.045*math.sin(ang*5+j*.7))
            verts.append(co(center+(u*math.cos(ang)+v*math.sin(ang))*rad))
    faces=[]
    for j in range(rings-1):
        for k in range(sides):
            q=j*sides+k; qn=j*sides+(k+1)%sides
            faces.append((q,qn,qn+sides,q+sides))
    m=bpy.data.meshes.new('Tailored sleeve'); m.from_pydata(verts,[],faces); m.update()
    o=bpy.data.objects.new('Tailored sleeve',m); bpy.context.collection.objects.link(o); finish(o,o.name,cloth,parent,0,True)
    # Cylindrical texture coordinates for the fabric weave.
    uv=m.uv_layers.new()
    for poly in m.polygons:
        for li in poly.loop_indices:
            idx=m.loops[li].vertex_index; uv.data[li].uv=((idx%sides)/sides,idx//sides/rings)
    end=tuple(bv+d*.048)
    tube('Elastic cuff',b,end,.071,leather,parent,r2=.068)
    tube('Gloved wrist',end,palm,.063,glove,parent,r2=.061)
    ellipsoid('Palm',palm,(.061,.077,.062),glove,parent)
    if support and not pistol:
        for i in range(4):
            z=-.9+i*.033
            points=[(-.074,-.12,z),(-.069,-.034,z),(-.03,.003,z),(.019,-.008,z)]
            line('Curled support finger',points,.016,glove,parent)
            ellipsoid('Knuckle pad',(-.067,-.051,z),(.017,.022,.019),leather,parent)
        line('Support thumb',[(.018,-.12,-.79),(.074,-.07,-.80),(.055,-.032,-.85)],.023,glove,parent)
    else:
        for i in range(4):
            y=-.135-i*.036
            points=[(.057,y,-.249),(.078,y,-.293),(.063,y,-.34),(.011,y,-.349)]
            line('Grip finger',points,.017,glove,parent)
            ellipsoid('Knuckle pad',(.073,y,-.28),(.015,.015,.025),leather,parent)
        line('Thumb',[(.008,-.21,-.235),(-.058,-.145,-.25),(-.047,-.105,-.31)],.021,glove,parent)
    line('Glove seam',[(palm[0]+.03,palm[1]-.04,palm[2]+.055),(palm[0]+.05,palm[1]+.016,palm[2]+.048),(palm[0]+.01,palm[1]+.06,palm[2]+.038)],.0017,stitch,parent)

