# This script is licensed as public domain.

bl_info = {
    "name": "Export ZScript (.zs)",
    "author": "Recurracy",
    "version": (2024, 4, 27),
    "blender": (4, 0, 0),
    "location": "File > Export > ZScript",
    "description": "Export as a ZScript file (.zs)",
    "warning": "",
    "wiki_url": "",
    "tracker_url": "",
    "category": "Import-Export"}

import bpy
import bpy_extras.io_utils
import os
import os.path
import json
import mathutils
import math
from bpy import context
import bpy.props
import functools

class zScriptAnimation:
    def __init__(self, animationName):
        self.frameCount = 0
        self.frames = []
        self.className = 'ZSAnimation' + animationName
    
    # convert this data to a zscript file
    def toZscript(self):
        result = ''
        result += 'class {0} : ZSAnimation {{\n'.format(self.className)
        result += '\toverride void Initialize() {{ frameCount = {0}; }}\n'.format(self.frameCount)
        result += '\toverride void MakeFrameList() {\n'
        for frame in self.frames:
            result += '\t' + frame.toZscript() + ';\n'
            
        result += '\n}\n}'
        return result

class zScriptFrame:
    def __init__(self, framenum):
        self.frame = framenum
        self.layerName = ''
        self.rotation = mathutils.Euler((0,0,0), ('XYZ'))
        self.posOffs = mathutils.Vector((0,0,0))
        self.scale = mathutils.Vector((0,0,0))
        self.ang = 0
        self.boneData = {}
        self.interpolation = True
        
    #convert this data to a zscript line
    def toZscript(self):
        # format: 
        # {0}: bone name (psp index)
        # {1}: frame number
        # {2}-{4}: angles x y z
        # {5}-{6}: pspoffset x y
        # {7}-{8}: pspscale x y
        # {9}: interpolation
        return 'frames.Push(ZSAnimationFrame.Create({0}, {1}, ({2}, {3}, {4}), ({5}, {6}), ({7}, {8}), {9}))'.format(self.layerName, self.frame,
            self.rotation.x, self.rotation.y, self.rotation.z,
            self.posOffs.z, self.posOffs.y,
            self.scale.z, self.scale.y,
            self.interpolation)

def write_file(fname, zAnim):
    with open(fname, 'w', encoding='utf-8') as f:
        print('Writing zscript file {0}'.format(fname))
        f.write(zAnim.toZscript())
        f.close()
        
def get_last_keyframe(fcurve, frame):
    e = enumerate(fcurve.keyframe_points)
    kf = None
    for index, item in e:
        if (item.co.x <= frame+1):
            kf = item
            
    return kf
        
def exportZS(context, filename, animName, actionName, posScale, spriteScaleMult):
    scene = bpy.data.scenes['Scene']
    action = bpy.data.actions[actionName]
    obj = context.object
    obj.animation_data.action = action
    fcurves = obj.animation_data.action.fcurves
    bones = obj.data.bones
    
    zAnim = zScriptAnimation(animName)
    
    for framenum in range(scene.frame_start, scene.frame_end+1):
        frameOffs = framenum - (scene.frame_start)
        print('framenum {0} offs {1}'.format(framenum, frameOffs))
        properties = {}
        
        for fci, fc in enumerate(fcurves):
            path = fc.data_path
            bone = bones[path[12 : path.find(']') - 1]]
            if (not bone.select):
                continue
            
            if (bone.name.startswith('!')):
                continue
            
            #initialize the properties for this bone
            if not bone.name in properties:
                properties[bone.name] = {}
                properties[bone.name]['location'] = []
                properties[bone.name]['rotation_euler'] = []
                properties[bone.name]['scale'] = []
                properties[bone.name]['interpolation'] = 'BEZIER'
            
            # calculate the curve positions for this frame
            eval = fc.evaluate(framenum)
            
            # determine which property is being adjusted by this curve
            bonenamelen = len(bone.name)
            propname = fc.data_path[12 + bonenamelen + 3 :]
            if (propname == 'rotation_euler'):
                eval = math.degrees(eval)
            if (propname == 'location'):
                eval *= posScale
            if (propname == 'scale' and bone.name != 'ZSAnimator.PlayerView'):
                eval *= spriteScaleMult
            properties[bone.name][propname].append(eval)
            
            # we need to remember when interpolation should not be applied, so we can get the last keyframe before the current one
            keyframe = get_last_keyframe(fc, framenum)
            if keyframe != None:
                properties[bone.name]['interpolation'] = keyframe.interpolation
                
            print(properties)
        
        for key in properties:
            zFrame = zScriptFrame(frameOffs)
            zFrame.layerName = key
            val = properties[key]
            camRot = val['rotation_euler']
            zFrame.rotation = mathutils.Euler((camRot[0], camRot[1], camRot[2]), 'XYZ')
            zFrame.ang = val['rotation_euler'][0]
            zFrame.posOffs = mathutils.Vector((val['location'][0], val['location'][1], val['location'][2]))
            zFrame.scale = mathutils.Vector((val['scale'][0], val['scale'][1], val['scale'][2]))
            zFrame.interpolation = True if val['interpolation'] != 'LINEAR' else False
                
            zAnim.frames.append(zFrame)
    
    zAnim.frameCount = scene.frame_end - scene.frame_start
    write_file(filename, zAnim)

class ZScriptExport(bpy.types.Operator, bpy_extras.io_utils.ExportHelper):
    bl_idname = "export.zs"
    bl_label = "Export ZScript"
    filename_ext = ".zs"
    # initialize properties in export field
    animName: bpy.props.StringProperty(name="Animation name", default="")
    actionName: bpy.props.StringProperty(name="Action name", default="")
    posScale: bpy.props.FloatProperty(name="Position Scale", description="Position scalar", default=100.0, min=0.01, step=0.01, precision=4)
    spriteScaleMult: bpy.props.FloatProperty(name="Sprites Scale Multiplier", description="Multiply the scale of sprites by this value", default=1.0, min=0.01, step=0.01, precision=4)
    
    def execute(self, context):
        exportZS(context, self.properties.filepath, self.properties.animName, self.properties.actionName, self.properties.posScale, self.properties.spriteScaleMult)
        return {'FINISHED'}
#        unregister()

def menu_func(self, context):
    self.layout.operator(ZScriptExport.bl_idname, text="ZScript Animation")


def register():
    bpy.utils.register_class(ZScriptExport)
    bpy.types.TOPBAR_MT_file_export.append(menu_func)

def unregister():
    bpy.utils.unregister_class(ZScriptExport)
    bpy.types.TOPBAR_MT_file_export.remove(menu_func)

if __name__ == "__main__":
    register()