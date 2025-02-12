# This script is licensed as public domain.

bl_info = {
    "name": "Export ZScript (.zs)",
    "author": "Recurracy",
    "version": (2024, 10, 21),
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

optionalProperties = {"reference"}

class zScriptAnimation:
    def __init__(self, animationName):
        self.frameCount = 0
        self.frames = []
        self.className = 'ZSAnimation' + animationName
        self.filledIn = False
    
    # convert this data to a zscript file
    def toZscript(self):
        result = ''
        result += 'class {0} : ZSAnimation {{\n'.format(self.className)
        result += '\toverride void Initialize() {{\n\t\tframeCount = {0}; \n\t\tfilledIn = {1};'.format(self.frameCount, self.filledIn)
        result += '\t}\n'
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
        self.sprite = ""
        self.duration = 0
        self.optionals = {}
        
    #convert this data to a zscript line
    def toZscript(self):
        if (self.layerName.startswith("!")):
            self.layerName = 'ZSAnimator.None'
        # format: 
        # {0}: bone name (psp index)
        # {1}: frame number
        # {2}-{4}: angles x y z
        # {5}-{6}: pspoffset x y
        # {7}-{8}: pspscale x y
        # {9}: interpolation
        curStr = ("frames.Push(ZSAnimationFrame.Create({0}, {1}, ({2}, {3}, {4}), ({5}, {6}), ({7}, {8}), {9}").format(self.layerName, self.frame,
            self.rotation.x, self.rotation.y, self.rotation.z,
            self.posOffs.z, self.posOffs.y,
            self.scale.z, self.scale.y,
            self.interpolation)
            
        self.optionals["zPos"] = self.posOffs.x
            
        print(self.optionals)
        for k in self.optionals:
            op = self.optionals[k]
            curStr += ",{0}: ".format(k)
            if isinstance(op, str):
                curStr += "\""
            curStr += "{0}".format(op)
            if isinstance(op, str):
                curStr += "\""
            
        curStr += "))"
        return curStr

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

def keyframe_exists(fcurves, bonename, framenum):
    for fci, fc in enumerate(fcurves):
#        print('bonename {0} datapath {1}'.format(bonename, fc.data_path))
        if (bonename not in fc.data_path):
            continue
#        print('fc name {0} {1}'.format(fc.data_path, bonename))
        for pi, p in enumerate(fc.keyframe_points):
            print('point x {0} framenum {1}'.format(p.co.x, framenum))
            if (p.co.x == framenum):
#                print('found keyframe at {0}'.format(framenum))
                return True
#    e = enumerate(fcurve.keyframe_points)
#    for index, item in e:
#        print('item co x {0} {1}'.format(item.co.x, framenum))
#        if(item.co.x == framenum):
#            return True
    return False
    
def boneHasProperty(bone, prop):
    try:
        return bone[prop];
    except:
        return None;
    
def exportZSFullEval(context, filename, animName, actionName):
    scene = bpy.data.scenes['Scene']
    action = bpy.data.actions[actionName]
    obj = context.object
    obj.animation_data.action = action
    selectedBones = bpy.context.selected_pose_bones
    totalFrames = 0
    
    zAnim = zScriptAnimation(animName)
    
    for framenum in range(scene.frame_start, scene.frame_end+1):
        frameOffs = framenum - (scene.frame_start)
        bpy.context.scene.frame_set(framenum)
        print('framenum {0} offs {1}'.format(framenum, frameOffs))
        for b in selectedBones:
            print(b.name)
            print(b.scale)
            zFrame = zScriptFrame(frameOffs)
            zFrame.layerName = b.name
            zFrame.rotation = mathutils.Euler((math.degrees(b.rotation_euler.x), math.degrees(b.rotation_euler.y), math.degrees(b.rotation_euler.z)), ('XYZ'))
            zFrame.posOffs = b.location * 100.0
            zFrame.scale = mathutils.Vector((b.scale.x, b.scale.y, b.scale.z))
            print(zFrame.scale)
            zFrame.interpolation = True
            
            for p in optionalProperties:
                propVal = boneHasProperty(b, p)
                if (propVal != None):
                    zFrame.optionals[p] = propVal
                    
            print(zFrame.toZscript())
            zAnim.frames.append(zFrame)
            
        zAnim.frameCount += 1;
    
    write_file(filename, zAnim)
            
        
def exportZS(context, filename, animName, actionName, fillinFrames):
    scene = bpy.data.scenes['Scene']
    action = bpy.data.actions[actionName]
    obj = context.object
    obj.animation_data.action = action
    fcurves = obj.animation_data.action.fcurves
    bones = obj.data.bones
    selectedBones = bpy.context.selected_pose_bones
    lastZFrame = None
    totalFrames = 0
    
    zAnim = zScriptAnimation(animName)
    
    for framenum in range(scene.frame_start, scene.frame_end+1):
        frameOffs = framenum - (scene.frame_start)
        print('framenum {0} offs {1}'.format(framenum, frameOffs))
        properties = {}
        kfExists = False
        aborted = False
        skipThis = False
        
        for fci, fc in enumerate(fcurves):
            path = fc.data_path
            bone = bones[path[12 : path.find(']') - 1]]
            
            found = False
            for selBone in selectedBones:
                if (bone.name == selBone.name and not found):
                    found = True
                    
            if (not found):
                continue
            
            if (not fillinFrames):
                found = False
                
                print('path', path)
                found = True
                
                if (not found):
                    continue
                
#            if (not bone.select):
#                continue

            if (not fillinFrames):
                if (not keyframe_exists(fcurves, bone.name, framenum)):
                    print('skipping, no keyframe')
                    continue
            
            print('checking bone {0}'.format(bone.name))
            
            #initialize the properties for this bone
            if not bone.name in properties:
                properties[bone.name] = {}
                properties[bone.name]['location'] = []
                properties[bone.name]['rotation_euler'] = []
                properties[bone.name]['scale'] = []
                properties[bone.name]['interpolation'] = 'BEZIER'
                properties[bone.name]['sprite'] = ""
                properties[bone.name]['duration'] = 0
                properties[bone.name]['optionals'] = {}
            
            # calculate the curve positions for this frame
            eval = fc.evaluate(framenum)
            
            # determine which property is being adjusted by this curve
            bonenamelen = len(bone.name)
            propname = fc.data_path[12 + bonenamelen + 3 :]
            print('property {0}'.format(propname))
            if (propname == 'rotation_euler'):
                eval = math.degrees(eval)
#            if (propname == 'scale' and bone.name != 'ZSAnimator.PlayerView'):
#                eval *= spriteScaleMult
            if (propname == 'location'):
                eval *= 100.0;
            
            print('evaluated {0}'.format(eval))
                    
            properties[bone.name][propname].append(eval)
            
            #check if custom properties exist for this bone
            for p in optionalProperties:
                print(p)
                try:
                    properties[bone.name]['optionals'][p] = bone[p]
                except:
                    print("no {0}".format(p))
            
            # we need to remember when interpolation should not be applied, so we can get the last keyframe before the current one
            keyframe = get_last_keyframe(fc, framenum)
            if keyframe != None:
                properties[bone.name]['interpolation'] = keyframe.interpolation
                
            # if the bone is parented to PSP_WEAPON set followWeapon to true.
                
            #get the sprite for this frame, if applicable
#            for child in obj.children:
#                if (child.parent_bone == bone.name and !child.hide_viewport):
#                    print(child.name)
#                    if 'sprite' in child:
#                        properties[bone.name]['sprite'] = child['sprite']
                    
#                    if 'duration' in child:
#                        properties[bone.name]['duration'] = child['duration']
                        
#                    break
                
#            print('current properties: {0}'.format(properties))

        if (not aborted):
            totalFrames += 1
            print('total frames ', totalFrames)
        
        print('collected properties:')
        print(properties)
        #if (not (framenum == scene.frame_start)):
        for key in properties:
            zFrame = zScriptFrame(frameOffs)
            zFrame.layerName = key
            val = properties[key]
            print(properties[key])
            zFrame.rotation = mathutils.Euler((val['rotation_euler'][0], val['rotation_euler'][1], val['rotation_euler'][2]), 'XYZ')
            zFrame.posOffs = mathutils.Vector((val['location'][0], val['location'][1], val['location'][2]))
            zFrame.scale = mathutils.Vector((val['scale'][0], val['scale'][1], val['scale'][2]))
            
            zFrame.interpolation = True if val['interpolation'] != 'CONSTANT' else False
            
            zFrame.optionals = val['optionals']
            
            zAnim.frames.append(zFrame)
                
    totalFrames -= 1
    
    zAnim.frameCount = totalFrames
    zAnim.filledIn = fillinFrames
    write_file(filename, zAnim)

class ZScriptExport(bpy.types.Operator, bpy_extras.io_utils.ExportHelper):
    bl_idname = "export.zs"
    bl_label = "Export ZScript"
    filename_ext = ".zs"
    # initialize properties in export field
    animName: bpy.props.StringProperty(name="Animation name", default="")
    actionName: bpy.props.StringProperty(name="Action name", default="")
    fillinFrames: bpy.props.BoolProperty(name="Fill in frames", description="Fill in key frames. Makes ZScript interpolate by itself", default=True)
    
    def execute(self, context):
        print('lol')
        # exportZS(context, self.properties.filepath, self.properties.animName, self.properties.actionName, self.properties.fillinFrames)
        exportZSFullEval(context, self.properties.filepath, self.properties.animName, self.properties.actionName)
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