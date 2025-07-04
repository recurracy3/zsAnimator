	// ZSAnimator: A ZScript animation framework, allowing you to make first-person animations in blender usable in GZDoom.
    // Copyright (C) 2025 Recurracy

    // This program is free software: you can redistribute it and/or modify
    // it under the terms of the GNU General Public License as published by
    // the Free Software Foundation, either version 3 of the License, or
    // (at your option) any later version.

    // This program is distributed in the hope that it will be useful,
    // but WITHOUT ANY WARRANTY; without even the implied warranty of
    // MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    // GNU General Public License for more details.

    // You should have received a copy of the GNU General Public License
    // along with this program.  If not, see https://www.gnu.org/licenses.

/////////////////////////////////////////
// TODO:
// Rewrite ZSAnimator a little bit to be less
// naive and dependant on the Blender framework. Retain the current functionality
// but add an extra class that inherits ZSAnimator that cuts out a lot of the bloat.
// It should allow you to manually do some things regardless of the Blender part.
/////////////////////////////////////////

// Ideas:
// Maybe allow ZSAnimator to work on the UI layer as well? Could be interesting.



//////////////////////////////////////////
// About ZSAnimator
//
// ZSAnimator is intended to be a Blender -> GZdoom pipeline for making detailed first person animations, camera included.
// It currently, thus, does a lot for you to make the animations as smoothly as possible (literally).
// It's supposed to be a fire and forget kind of deal where you make an animation in Blender and export them with the supplied Blender addon.
// I wanted it to be as easy to use in ZScript as possible, with little functions necessary to set it up and get it working, as I would like it
// to be usable by people with little experience while also being a complete set of tools for people with more experience.
//////////////////////////////////////////


// This class is made and filled in by the Blender plugin.
// A frame can manipulate either the view, reference or a psprite.
class ZSAnimationFrame
{
	// ID of the psprite this AnimationFrame will change.
	// Can be special numbers defined in ZSAnimator. It changes the behavior of this frame.
	int pspId;
	// Frame number of this frame.
	int frameNum;
	// The rotations stored in this frame. PSPs normally have only one rotation axis, but
	// this is used by ZSAPSP to skew the sprite.
	Vector3 angles;
	// Z is the depth of the sprite and may be used later for perspective, and perhaps even automagically changing the psprite layer dynamically so it gets drawn over and under other sprites.
	Vector3 pspOffsets;
	// Scale of the psprite.
	Vector2 pspScale;
	// Whether interpolation has been enabled in the animation created by blender.
	// To disable this set the keyframe interpolation to LINEAR. Any other value means interpolation.
	bool interpolate;
	ZSAnimation anim;
	// If this is set this means that this frame is a reference. References normally do not change PSPids but manipulate a physical Actor in the world. To the player,
	// it will appear as if it is part of the screen.
	string reference;
	// Parent of this frame.
	int parentPspId;
	
	// ZSAnimator's Blender plugin dumps the frame data as these in the .zs files it generates.
	// The arguments are pretty straight forward.
	static ZSAnimationFrame Create(int pspId, int frameNum, Vector3 angles, Vector2 pspOffsets, Vector2 pspScale, bool interpolate, bool layered = false,
		string reference = "",
		float zPos = 0.0,
		int parent = ZSAnimator.None)
	{
		let frame = ZSAnimationFrame(New("ZSAnimationFrame"));
		frame.frameNum = frameNum;
		frame.pspId = pspId;
		frame.angles = angles;
		frame.pspOffsets = (pspOffsets.x, pspOffsets.y, zPos);
		frame.pspScale = pspScale;
		frame.parentPspId = parent;
		
		frame.interpolate = interpolate;
		frame.reference = reference;
		return frame;
	}
	
	void PrintFrameInfo()
	{
		console.printf("psp %d frame %d a: (%.3f %.3f %.3f) p: (%.3f %.3f) s: (%.3f %.3f) i: %d", 
			pspId, frameNum, 
			angles.x, angles.y, angles.z, 
			pspOffsets.x, pspOffsets.y, 
			pspScale.x, pspScale.y, 
			interpolate);
	}
	
	ZSAnimationFrame Clone()
	{
		ZSAnimationFrame f = New("ZSAnimationFrame");
		f.pspId = self.pspId;
		f.frameNum = self.frameNum;
		f.angles = self.angles;
		f.pspOffsets = self.pspOffsets;
		f.pspScale = self.pspScale;
		f.interpolate = self.interpolate;
		f.reference = self.reference;
		return f;
	}
}

// Nodes are a means for the automatic ZSAnimator pipeline to determine which frame will play next.
// This essentially forms a linked list.
class ZSAnimationFrameNode
{
	ZSAnimationFrameNode next;
	ZSAnimationFrameNode prev;
	ZSAnimationFrame frame;
	
	static ZSAnimationFrameNode Create()
	{
		let node = ZSAnimationFrameNode(New("ZSAnimationFrameNode"));
		return node;
	}
	
	ZSAnimationFrameNode GetLastNode(bool includeSelf = false)
	{
		let n = self;
		while (n.next)
		{
			n = n.next;
		}
		if (!includeSelf && n == self) { return NULL; }
		return n;
	}
	
	ZSAnimationFrameNode GetFirstNode(bool includeSelf = false)
	{
		let n = self;
		while (n.prev)
		{
			n = n.prev;
		}
		if (!includeSelf && n == self) { return NULL; }
		return n;
	}
}

// References allow you to change the location and rotation of things that AREN'T Psprites, but are still things seen from the first person perspective.
// For example, a flashlight emitter, or a laser pointer emitter.
class ZSAnimationReference : Actor
{
	PlayerInfo ply;
	Weapon parent;
	Vector3 animPos;
	Vector3 animRot; 
	Vector2 animScales;

	// I don't really know what this does besides divide the positions for some reason. I should probably change this.
	bool _projectFromView;
	property ProjectFromView : _projectFromView;
	// Multiplier of the positions, for reasons?
	Vector3 _posMults;
	property PosMults : _posMults;
	
	Default
	{
		+NOBLOCKMAP;
		+NOINTERACTION;
		-SOLID;
		+NOGRAVITY;
		
		ZSAnimationReference.PosMults (1,1,1);
	}
	
	override void Tick()
	{
		// I could probably do with omitting Tick() because, well, this Actor doesn't do shit beside lol get rotated idiot
		super.Tick();
		
		// Since references are supposed to turn a local view coordinate into a world coordinate,
		// use the player reference to adjust the coordinates accordingly.
		// Also make sure to use Quaternion maths to prevent gimbal locking and rotate the reference.
		
		float viewZ = ply.viewz;
		Vector3 plyAngs = (ply.mo.ViewAngle + ply.mo.angle, ply.mo.ViewPitch + ply.mo.Pitch, ply.mo.ViewRoll + ply.mo.Roll);
		Vector3 plyPos = (ply.mo.pos.x, ply.mo.pos.y, viewZ);
		
		Vector3 aPos = (self.animPos.x*1.2, self.animPos.y, self.animPos.z);
		aPos = (aPos.x * _posMults.x, aPos.y * _posMults.y, aPos.z * _posMults.z);
		if (self._projectFromView)
		{
			aPos = (aPos.x / 15.0, aPos.y / 15.0, aPos.z);
		}
		
		Quat base = Quat.FromAngles(plyAngs.x, plyAngs.y, plyAngs.z);
		Vector3 offs = base * (aPos.z*-1, aPos.x, aPos.y);
		Vector3 glob = level.Vec3Offset(plyPos, (offs.x, offs.y, offs.z));
		self.SetOrigin(glob, true);
		
		// set the angle of the reference
		Quat bonAng = Quat.FromAngles(animRot.x, animRot.z-90, animRot.y);
		Quat myrotQ = base * bonAng;
		Vector3 myrotV = myrotQ * (1,0,0);
		Vector3 rots = ZSanimator.QuatToEuler(myrotQ);
		self.A_SetAngle(rots.x, SPF_INTERPOLATE);
		self.A_SetPitch(rots.y, SPF_INTERPOLATE);
		self.A_SetRoll(rots.z, SPF_INTERPOLATE);
		
		self.scale = animScales;
	}
}

// Probably the main force of the Blender->ZSAnimator pipeline.
// The blender plugin shits out classes that inherit from this.
// This collects frame data and organises them. Actually playing the animations is done in instances of ZSAnimator.
Class ZSAnimation
{
	PlayerInfo ply;
	int frameCount;
	double playbackSpeed;
	bool running;
	Array<ZSAnimationFrame> frames;
	// Associative map of nodes, where the key is the PSP Id.
	Map<int, ZSAnimationFrameNode > nodeMap;
	Map<int, ZSAnimationFrameNode > currentNodes;
	bool spritesLinked;
	int lastTickDiff;
	bool layered; // deprecated, does nothing
	// DO NOT change this. It's done by ZSAnimator itself. Currently does nothing
	bool filledIn;
	ZSAnimator currentAnimator;
	
	// Used in conjecture with the 'reference' custom property. 
	Map<string, ZSAnimationReference> references;
	
	// It's possible for animations to fall 'inbetween' tics defined by Zdoom, aka the default tic rate of 35/s, thanks to the variable framerate.
	// When this happens we need to determine the positions, rotations and scale between the last frame and the current frame as a percentage.
	double currentTicks;
	
	int flags;
	
	// This is the function that the blender plugin fills in to make the frame list. It contains raw animation data as a ZSAnimationFrame.
	virtual void MakeFrameList() { }
	// This function is filled in by the blender plugin as well, sets things like frame count and stuff.
	virtual void Initialize() { }

	// Link up the node linked list.
	void LinkList()
	{
		foreach(frame : frames)
		{
			if (!frame || frame.bDestroyed) { continue; }
			ZSAnimationFrameNode n = ZSAnimationFrameNode.Create();
			if (!nodeMap.CheckKey(frame.pspId))
			{
				nodeMap.Insert(frame.pspId, n);
			}
			n.frame = frame;
			if (currentNodes.CheckKey(frame.pspId))
			{
				let prevNode = currentNodes.GetIfExists(frame.pspId);
				n.prev = prevNode;
				prevNode.next = n;
			}
			
			currentNodes.Insert(frame.pspId, n);
		}
		
		foreach(k,v : nodemap)
		{
			currentNodes.Insert(k, v);
			let n = v.next;
			while (n)
			{
				n = n.next;
			}
		}
	}
	
	void SetReference(string key, ZSAnimationReference val)
	{
		references.Insert(key, val);
	}

	void SetFlags(int flags, bool set = true)
	{
		if (set)
			self.flags |= flags;
		else
			self.flags &= ~flags;
	}
	
	ZSAnimationFrameNode GetNextNode(ZSAnimationFrameNode node, double ticksNow, double ticksNext, bool forceNext = false)
	{
		// forceNext = false;
		int tickDiff = abs(int(ticksNext) - int(ticksNow));
		ZSAnimationFrameNode ret = NULL;
		
		let n = node;
		int iterations = 0;
		int maxTicks;
		while (true)
		{
			iterations++;
			let test = n;
			if (test)
			{
				if (playbackSpeed >= 0.0) { test = test.next; } else { test = test.prev; }
			}
			
			if (!forceNext)
			{
				if (!test || !test.frame || test.frame.bDestroyed)
				{
					return n;
				}
				
				bool result = test.frame.frameNum > int(ticksNext);
				if (playbackSpeed < 0)
				{
					result = test.frame.frameNum < self.frameCount - int(ticksNext);
				}
				
				if (result)
				{
					return n;
				}
			}
			
			if (forceNext)
			{
				if (!test || !test.frame || test.frame.bDestroyed)
				{
					return n;
				}
				
				bool result = test.frame.frameNum >= int(ticksNext);
				if (playbackSpeed < 0)
				{
					result = test.frame.frameNum <= self.frameCount - int(ticksNext);
				}
				
				if (result)
				{
					return test;
				}
			}
			
			n = test;
		}
		return n;
	}
	
	void AdvanceAnimation()
	{
		Map<int, ZSAnimationFrameNode> temp;
		
		MapIterator<int, ZSanimationFrameNode> curIt;
		curIt.Init(currentNodes);
		
		foreach ( k, v : curIt )
		{
			let n = GetNextNode(v, currentTicks, currentTicks + abs(playbackSpeed));
			temp.Insert(k, n);
		}
		
		foreach ( k, v : temp )
		{
			currentNodes.insert(k, v);
		}
		curIt.ReInit();
		
		currentTicks += abs(playbackSpeed);
	}
	
	play ZSAnimationFrame EvaluateFrame(int layer, double ticksA, double ticksB)
	{
		let currNode = currentNodes.GetIfExists(layer);
		let nextNode = GetNextNode(currNode, ticksA, ticksB, true);
		
		let ret = ZSAnimationFrame.Create(layer, int(ticksA), (0,0,0), (0,0), (0,0), false);
		
		if (!currNode.frame || currNode.frame.bDestroyed) { return null; }
		ZSAnimationFrame frameA = currNode.frame;
		ZSAnimationFrame frameB = currNode.frame;
		ret.pspId = frameA.pspId;
		ret.reference = frameA.reference;
		if (nextNode)
		{
			frameB = nextNode.frame;
		}
		else
		{
			return frameA;
		}
		double tickPerc = 0.0;
		
		if (frameA.frameNum != frameB.frameNum)
		{
			double tickIn = ticksA;
			int nA = frameA.frameNum;
			int nB = frameB.frameNum;
			
			if (playbackSpeed < 0)
			{
				tickIn = int(self.frameCount) - ticksA;
			}
			tickPerc = ZSAnimator.LinearMap(tickIn, nA, nB, 0.0, 1.0, true);
		}
		else
		{
			//tickPerc = ticksA%1.0;
		}
		
		ret.interpolate = frameA.interpolate;
		
		Vector3 rot = (0,0,0);
		Vector3 pos = (0,0,0);
		Vector2 sc = (0,0);
		
		bool flipx = self.flags & ZSAnimator.LF_FlipX != 0;
		
		if ((frameA && frameB) && frameA != frameB)
		{	
			// TOOD: Bring back the additive function

			// if ((frameA.flags & ZSAnimator.LF_Additive) != 0)
			// {
			// 	if ((frameA.flags & ZSAnimator.LF_AdditiveNoPSP) == 0)
			// 	{
			// 		let pspF = ZSAnimator.GetCurrentPspAsFrame(ply, layer);
			// 		pspF.pspOffsets = ((pspF.pspOffsets.x-160.0)*(flipx?1:-1), (pspF.pspOffsets.y-100.0)*-1, pspF.pspOffsets.z);
					
			// 		let rotB = (framea.angles.x - pspF.angles.x,
			// 			framea.angles.y - pspF.angles.y,
			// 			framea.angles.z - pspF.angles.z);
			// 		let posB = (framea.pspOffsets.x - pspF.pspOffsets.x,
			// 			framea.pspOffsets.y - pspF.pspOffsets.y,
			// 			framea.pspOffsets.z - pspF.pspOffsets.z);
			// 		let scB = (framea.pspScale.x - pspF.pspScale.x,
			// 			framea.pspScale.y - pspF.pspScale.y);
					
			// 		rot = (frameB.angles.x - frameA.angles.x,
			// 			frameB.angles.y - frameA.angles.y,
			// 			frameB.angles.z - frameA.angles.z);
			// 		pos = (frameB.pspOffsets.x - frameA.pspOffsets.x,
			// 			frameB.pspOffsets.y - frameA.pspOffsets.y,
			// 			frameB.pspOffsets.z - frameA.pspOffsets.z);
			// 		sc = (frameB.pspScale.x - frameA.pspScale.x,
			// 			frameB.pspScale.y - frameA.pspScale.y);
					
			// 		rot.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, rot.x, rotB.x, false);
			// 		rot.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, rot.y, rotB.y, false);
			// 		rot.z = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, rot.z, rotB.z, false);
					
			// 		pos.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, pos.x, posB.x, false);
			// 		pos.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, pos.y, posB.y, false);
			// 		pos.z = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, pos.z, posB.z, false);
					
			// 		sc.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, sc.x, scB.x, false);
			// 		sc.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, sc.y, scB.y, false);
			// 	}
			// 	else
			// 	{
			// 		rot = (frameB.angles.x - frameA.angles.x,
			// 			frameB.angles.y - frameA.angles.y,
			// 			frameB.angles.z - frameA.angles.z);
			// 		pos = (frameB.pspOffsets.x - frameA.pspOffsets.x,
			// 			frameB.pspOffsets.y - frameA.pspOffsets.y,
			// 			frameB.pspOffsets.z - frameA.pspOffsets.z);
			// 		sc = (frameB.pspScale.x - frameA.pspScale.x,
			// 			frameB.pspScale.y - frameA.pspScale.y);
					
			// 		rot.x = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, rot.x, false);
			// 		rot.y = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, rot.y, false);
			// 		rot.z = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, rot.z, false);
					
			// 		pos.x = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, pos.x, false);
			// 		pos.y = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, pos.y, false);
			// 		pos.z = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, pos.z, false);
					
			// 		sc.x = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, sc.x, false);
			// 		sc.y = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, sc.y, false);
			// 	}
			// }
			// else
			// {
				rot.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.angles.x, frameB.angles.x, false);
				rot.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.angles.y, frameB.angles.y, false);
				rot.z = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.angles.z, frameB.angles.z, false);
				
				pos.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspOffsets.x, frameB.pspOffsets.x, false);
				pos.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspOffsets.y, frameB.pspOffsets.y, false);
				pos.z = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspOffsets.z, frameB.pspOffsets.z, false);
				
				sc.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspScale.x, frameB.pspScale.x, false);
				sc.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspScale.y, frameB.pspScale.y, false);
			// }
		}
		else if (frameA == frameB)
		{
			rot = (frameA.angles.x, frameA.angles.y, frameA.angles.z);
			pos = (frameA.pspOffsets.x, frameA.pspOffsets.y, frameA.pspOffsets.z);
			sc = (frameA.pspScale.x, frameA.pspScale.y);
		}
		
		ret.angles = rot;
		ret.pspOffsets = pos;
		ret.pspScale = sc;
		return ret;
	}
	
	play void DeleteFrames(int pspId)
	{
		for (int i = 0; i < frames.Size(); i++)
		{
			let f = frames[i];
			if (!f || f.bDestroyed) { continue; }
			if (f.pspId == pspId)
			{
				f.Destroy();
			}
		}
	}
	
	void ReplacePspIds(int original, int replacement)
	{
		for (int i = 0; i < frames.Size(); i++)
		{
			let f = frames[i];
			if (!f || f.bDestroyed) { continue; }
			if (f.pspId == original) {
				f.pspId = replacement;
			}
		}
	}
	
	void CopyFrames(int origPspId, int newPspId)
	{
		Array<ZSAnimationFrame> newFrames;
		for (int i = 0; i < frames.Size(); i++)
		{
			let f = frames[i];
			if (!f || f.bDestroyed) { continue; }
			if (f.pspId == origPspId)
			{
				let nf = f.Clone();
				nf.pspId = newPspId;
				newFrames.Push(nf);
			}
		}
		
		if (newFrames.Size() > 0)
		{
			frames.Append(newFrames);
		}
	}
	
	void GetFrames(Array<int> pspIds, out Array<ZSAnimationFrame> outframes, int startIndex = -1, int endIndex = -1)
	{
		for (int i = 0; i < frames.Size(); i++)
		{
			let f = frames[i];
			bool valid = false;
			if (pspIds.Size() <= 0) { valid = true; } // ignore the psp check if the array is not filled in
			for (int j = 0; j < pspIds.Size(); j++)
			{
				if (f.pspId == pspIDs[j])
				{
					valid = true;
					break;
				}
			}
			if (!valid) { continue; }
			
			if ((startIndex == -1 && endIndex == -1) || // always add the appropriate frames if the last two args are not filled in, or
			(endIndex >= startIndex && (f.frameNum >= startIndex && f.frameNum <= endIndex))) // if endIndex is larger than startIndex and
			// the frame's number falls between the arguments
			{
				outframes.push(f);
			}
		}
	}
	
	void OffsetPositions(int pspId, Vector2 offsets)
	{
		foreach(f : frames)
		{
			if (f.pspId == pspId)
			{
				f.pspOffsets.x += offsets.x;
				f.pspOffsets.y += offsets.y;
			}
		}
	}
}

Class ZSAnimator : Thinker
{	
	// I wish I named these better but I can't really do that anymore.
	enum SpecialAnimNums
	{
		PlayerView = -5000,
		None = -5001,
	}

	// Currently unused.
	// Could be used to determine which values to omit from the automatic animation
	// pipeline, I guess?
	// Should probably be a mask or something.
	enum FrameValue
	{
		ZSAFV_Position,
		ZSAFV_Rotation,
		ZSAFV_Scale
	}
	
	enum ZSAFlags
	{
		LF_Additive = 1 << 0, // When set, the offsets for this layer get added to the layer's current offset.
		LF_AdditiveNoPSP = 1 << 1, // When used in conjunction with LF_Additive, ZSAnimator does not apply the current PSPrite offsets but purely uses the delta between frames.
		LF_DontCenterPSP = 1 << 2, // When set, the PSPrite will not be centered automatically.
		LF_FlipX = 1 << 3, // Can be applied to individual frames. If applied to animations, flip the animation rotations and positions.
		LF_FlipY = 1 << 4 // Same as above.
	}

	// Things are bound to get really fucking muddy if I keep changing things around so this is here to maybe make things backwards compatible. 
	const ZSAVERSION = 1.1;
	
	PlayerInfo ply;
	// This prevents the Tick() from doing everything for you so you can do things yourself if you so desire.
	bool manual;
	Array<ZSAnimation> currentAnimations;

	// Because ZSAPSPs have to be stored somewhere. 
	// Key is the psprite id. 
	Map<int, ZSAPSP> zsaPspDict;

	////////////////////////////
	// END OF DECLARATIONS
	////////////////////////////
	
	static ZSAnimation GetAnimationFromClassName(Class<ZSanimation> animationClass)
	{
		let anim = ZSAnimation(New(animationClass));
		anim.Initialize();
		anim.MakeFrameList();
		return anim;
	}

	// Manipulate the supplied position, rotation and scale depending on the layerFlags.
	// Some animations need to be either flipped horizontally or vertically or whatever the hell and this takes care of that.
	// Returns the position, rotation and scale as values ready to be supplied to a TRS matrix.
	// Rotations are assumed to be in Blender format, meaning (-X, Y, Z) where X = roll, Y = yaw, Z = pitch.
	// For flags, refer to ZSAnimation.ZSAFlags.
	static clearscope Vector3, Vector3, Vector3 CalculateTRS(Vector3 translation, Vector3 rotation, Vector3 scale, int layerFlags = 0)
	{
		Vector3 retT = translation;
		Vector3 retR = rotation;
		Vector3 retS = scale;

		// Blender coords are flipped, so + == left/up, - == right/down.
		// GZDoom PSP coords are + == right/down, - == left/up.
		retT.x *= -1;
		retT.y *= -1;

		if (layerFlags & ZSAnimator.LF_FLIPX == ZSAnimator.LF_FLIPX)
		{
			// Whatever, flip the animation again.
			retT.x *= -1;
			retS.x *= -1;
		}

		if (layerFlags & ZSAnimator.LF_FLIPY == ZSAnimator.LF_FLIPY)
		{
			// flippy flip flip
			retT.y *= -1;
			reTS.y *= -1;
		}

		// Center the psprite (default behavior)
		if (!(layerFlags & ZSAnimator.LF_DontCenterPSP == ZSAnimator.LF_DontCenterPSP))
		{
			retT.x += 160.0;
			retT.y += 100.0;
		}

		return retT, retR, retS;
	}

	// Helper function.
	static clearscope double LinearMap(double val, double source_min, double source_max, double out_min, double out_max, bool clampIt = false) {
        double d = (val - source_min) * (out_max - out_min) / (source_max - source_min) + out_min;
        if (clampit) {
            double truemax = out_max > out_min ? out_max : out_min;
            double truemin = out_max > out_min ? out_min : out_max;
            d = Clamp(d, truemin, truemax);
        }
        return d;
    }
	
	// Pretty straight forward.
	static ZSAnimator Create()
	{
		ZSAnimator animator = ZSanimator(New("ZSAnimator"));
		return animator;
	}

	/////////////////////////////
	// END OF STATIC FUNCTIONS
	/////////////////////////////

	// Pretty straightforward really, return an instance of a ZSAPSP.
	ZSAPSP MakeZSAPSP(int pspId)
	{
		if (!IsPSPIDValid(pspId))
		{
			return NULL;
		}
		ZSAPSP p = New("ZSAPSP");
		p.pspId = pspId;
		p.animator = self;
		return p;
	}

	virtual bool IsPSPIDValid(int pspId)
	{
		Array<int> invalids;
		GetInvalidPSPIds(invalids);
		foreach(id : invalids)
		{
			if (pspId == id)
			{
				return false;
			}
		}
		return true;
	}

	virtual void GetInvalidPSPIds(out Array<int> invalidPspIds)
	{
		invalidPspIds.Push(ZSAnimator.PlayerView);
		invalidPspIds.Push(ZSAnimator.None);
	}

	// Wrapper function pretty much. You don't need to provide instances of ZSAPSP this way.
	void ParentPSPTo(int pspId, int parentPspId, bool keepViewport = false)
	{
		let zpsp = zsaPspDict.GetIfExists(pspId);
		let zpspP = zsaPspDict.GetIfExists(parentPspId);
		if (zpsp && zpspP)
		{
			zpsp.ParentTo(zPspP, keepViewport);
		}
	}

	bool AddZSAPSPToDict(ZSAPSP zsap)
	{
		if (!zsap) { return false; }
		if (!zsaPspDict.CheckKey(zsap.pspId))
		{
			zsaPspDict.Insert(zsap.pspId, zsap);
			return true;
		}
		return false;
	}

	void DestroyZSAPSP(int pspId)
	{
		let item = zsaPspDict.GetIfExists(pspId);
		if (item)
		{
			zsaPspDict.Remove(pspId);
			item.Destroy();
		}
	}

	// void SetPSPFlags(int pspId, int flags, bool set = true)
	// {
	// 	let zsap = zsaPspDict.GetIfExists(pspId);
	// 	if (!zsap || zsap.bDestroyed)
	// 	{
	// 		return;
	// 	}
	// 	if (set)
	// 	{
	// 		zsap.flags |= flags;
	// 	}
	// 	else
	// 	{
	// 		zsap.flags &= ~flags;
	// 	}
	// }

	void MapAnimPSPs(PlayerInfo ply, ZSAnimation anim)
	{
		foreach(frame : anim.frames)
		{
			if (!frame)
			{
				continue;
			}
			if (frame.pspId == ZSAnimator.PlayerView) { continue; }
			ZSAPSP zsap;
			if (!zsaPspDict.CheckKey(frame.pspId))
			{
				zsap = MakeZSAPSP(frame.pspId);
				AddZSAPSPToDict(zsap);
			}
			else
			{
				zsap = zsaPspDict.Get(frame.pspId);
			}

			let psp = ply.FindPSPrite(frame.pspId);
			if (psp)
			{
				zsap.psp = psp;
			}

			if (frame.parentPspId != ZSAnimator.None)
			{
				foreach(k, v : zsaPspDict)
				{
					if (v == zsap)
					{
						continue;
					}

					if (frame.parentPspId == v.pspId)
					{
						zsap.ParentTo(v);
					}
				}
			}
		}
	}
	
	// This function can be used to start an animation directly and let ZSAnimator handle everything.
	// TODO: Make frame and endFrame functional
	void StartAnimation(PlayerInfo ply, ZSAnimation anim, int frame = 0, int endFrame = 0, double playbackSpeed = 1.0)
	{
		playbackSpeed *= CVar.GetCVar("zsa_playbackSpeed", players[consoleplayer]).GetFloat();
		self.ply = ply;
		anim.currentAnimator = self;
		
		MapAnimPSPs(ply, anim);
		anim.LinkList();
		
		if (playbackSpeed < 0)
		{
			Map<int, ZSAnimationFrameNode> temp;
			MapIterator<int, ZSAnimationFrameNode> cnIt;
			cnIt.Init(anim.currentNodes);
			foreach(k, v : anim.currentNodes)
			{
				let n = v.GetLastNode(true);
				temp.Insert(k, n);
			}
			
			foreach(k, v : temp)
			{
				anim.currentNodes.insert(k, v);
			}
			cnIt.ReInit();
		}
		
		anim.currentTicks = frame;
		anim.running = true;
		anim.playbackSpeed = playbackSpeed;
		anim.lastTickDiff = 0;
		anim.ply = ply;
		currentAnimations.Push(anim);
	}
	
	//Stop the specified animation.
	void StopAnimation(Class<ZSanimation> anim)
	{
		for (int i = 0; i < currentAnimations.Size(); i++)
		{
			let c = currentAnimations[i];
			if (c IS anim)
			{
				c.Destroy();
			}
		}
	}
	
	// Stops ALL Animations.
	void StopAllAnimations()
	{
		Array<ZSAnimation> deletedAnims;
		
		for (int i = 0; i < currentAnimations.size(); i++)
		{
			currentAnimations[i].Destroy();
		}
		
		currentAnimations.Clear();
	}
	
	// Advance the animations to their next node, delete them if they have ended.
	play void AdvanceAnimations()
	{
		Array<ZSAnimation> deletedAnims;
		for (int i = 0; i < currentAnimations.size(); i++)
		{
			let currentAnimation = currentAnimations[i];
			if (currentAnimation && currentAnimation.running)
			{
				if (currentAnimation.currentTicks > currentAnimation.frameCount)
				{
					currentAnimation.running = false;
					deletedAnims.Push(currentAnimation);
				}
				else
				{
					currentAnimation.AdvanceAnimation();
				}
			}
		}
		
		for (int i = 0; i < deletedAnims.size(); i++)
		{
			let anim = deletedAnims[i];
			int animIndex = currentAnimations.Find(anim);
			if (animIndex != currentAnimations.Size())
			{
				currentAnimations.Delete(animIndex);
				anim.Destroy();
			}
		}
	}
	
	// Links psprite's states durations with the animation.
	void LinkPSprite(ZSAnimation anim, ZSAnimationFrame f, PSprite psp)
	{
		if (!psp) { return; }
		if (anim.spritesLinked && anim.playbackSpeed != 1.0)
		{
			double currentTicks = anim.currentTicks;
			double nextTicks = currentTicks + abs(anim.playbackSpeed);
			let currentNode = anim.currentNodes.GetIfExists(psp.id);
			let nextN = anim.GetNextNode(currentNode, currentTicks, nextTicks);
			bool equals = currentNode == nextN;
			if (abs(anim.playbackSpeed) > 1.0)
			{
				let st = psp.curState;	
				// this psp does not loop, or its next state does not exist, so we need to adjust the frames, possibly even skipping to the next frame if necessary
				if (st)
				{
					if (psp.tics > 0)
					{
						let a = int(nextTicks);
						let b = int(currentTicks);
						int ticsToSub = (a - b) - 1;
						while (ticsToSub > 0)
						{
							int pspTics = psp.tics;
							int subtracted;
							if (pspTics > 1)
							{
								int newtics = max(pspTics - ticsToSub, 1);
								subtracted = pspTics - newtics;
								ticsToSub -= subtracted;
								psp.tics = newtics;
							}
							else if (pspTics >= 0)
							{
								if (st && st.nextstate)
								{
									psp.setstate(st.nextstate);
									st = psp.curstate;
									ticsToSub -= 1;
								}
								else if (st && !st.nextstate)
								{
									psp.destroy();
									ticsToSub = 0;
								}
							}
							else if (pspTics <= -1)
							{
								ticsToSub -= 1;
							}
						}
					}
				}
			}
			else if (abs(anim.playbackSpeed) < 1.0)
			{
				int a = int(nextTicks);
				int b = int(currentTicks);
				int ticsToAdd = 1 - (a - b);
				if (ticsToAdd > 0)
				{
					psp.tics += 1;
				}
			}
		}
	}
	
	void SetPSPPosition(PSPrite psp, Vector2 pos)
	{
		psp.x = pos.x;
		psp.y = pos.y;
	}
	
	void SetPSPRotation(PSPrite psp, double ang)
	{
		psp.rotation = ang;
	}
	
	void SetPSPScale(Psprite psp, Vector2 scale)
	{
		psp.scale = scale;
	}
	
	// Credits to dodopod
	static clearscope Vector3 QuatToEuler(quat r)
    {
        // Roll        
        double sinRCosP = 2 * (r.w * r.x + r.y * r.z);
        double cosRCosP = 1 - 2 * (r.x * r.x + r.y * r.y);
        double roll = Atan2(sinRCosP, cosRCosP);

        // Pitch
        double sinP = 2 * (r.w * r.y - r.z * r.x);
        double pitch;
        if (Abs(sinP) >= 1) 
            pitch = 90 * (sinP < 0 ? -1 : 1);
        else 
            pitch = Asin(sinP);

        // Yaw
        double sinYCosP = 2 * (r.w * r.z + r.x * r.y);
        double cosYCosP = 1 - 2 * (r.y * r.y + r.z * r.z);
        double yaw = Atan2(sinYCosP, cosYCosP);

        return (yaw, pitch, roll);
    }
	
	// Reorder the incoming angles and prepare them for a transformation matrix.
	static clearscope Vector3 ReorderZSAToGuta(Vector3 angs)
	{
		// ORDER IN ZSANIMATOR:
		// YAW, PITCH, ROLL
		// (Y, Z, X)
		
		// EXPECTED ORDER IN GUTAMATICS:
		// YAW, PITCH, ROLL
		// (Z, Y, X)
		
		// (1, 0, 0) == rotate on forwards/back axis (results in rotating roll)
		// (0, 1, 0) == rotate by up/down axis (results in rotating yaw)
		// (0, 0, 1) == rotate by side axis (results in rotating pitch)

		return (angs.x*-1, angs.y, angs.z);
	}
	
	// Deprecated, should be deleted
	void TransformPSPCorners(Psprite psp, ZSAnimation anim, ZSAnimationFrame f)
	{
		if (!psp || !psp.curstate) { return; }
		if (!f) { return; }
		if (!anim) { return; }
		let texid = psp.curstate.GetSpriteTexture(0, spritenum: psp.sprite, framenum: psp.frame);
		int w, h;
		[w, h] = TexMan.GetSize(texid);
		Vector2 sprsize = (w, h);
		// Vector2 sprsize = TexMan.GetscaledSize(texid);
		
		Vector3 corner0 = (-sprSize.x/2, -sprSize.y/2, 0);
		Vector3 corner1 = (-sprSize.x/2, sprSize.y/2, 0);
		Vector3 corner2 = (sprSize.x/2, -sprSize.y/2, 0);
		Vector3 corner3 = (sprSize.x/2, sprSize.y/2, 0);
		Vector3 vecSc = (f.pspScale.x, f.pspScale.y, 1);
		
		Vector3 angs = (f.angles.x * ((anim.flags & ZSAnimator.LF_FLIPX == 0 ? -1 : 1)), f.angles.y, f.angles.z);
		angs = ZSAnimator.ReorderZSAToGuta(angs);
		
		// ORDER: Z Y X
		let rotScMatrix = zsaGMMatrix4.CreateTRSEuler((0,0,0), angs.z, angs.y, angs.x, vecSc);
		
		Vector3 v0 = rotScMatrix.multiplyVector3(corner0);
		Vector3 v1 = rotScMatrix.multiplyVector3(corner1);
		Vector3 v2 = rotScMatrix.multiplyVector3(corner2);
		Vector3 v3 = rotScMatrix.multiplyVector3(corner3);
		
		Vector3 diff0 = v0 - corner0;
		Vector3 diff1 = v1 - corner1;
		Vector3 diff2 = v2 - corner2;
		Vector3 diff3 = v3 - corner3;
		psp.coord0 = diff0.xy;
		psp.coord1 = diff1.xy;
		psp.coord2 = diff2.xy;
		psp.coord3 = diff3.xy;
	}
	
	// Deprecated
	play void ApplyPSP(ZSanimation anim, ZSanimationFrame f)
	{
		let psp = ply.FindPSprite(f.pspId);
		bool flipx = (anim.flags & ZSAnimator.LF_FlipX) != 0;
			
		if (psp)
		{
			psp.bPivotPercent = true;
			let xOffs = f.pspOffsets.x*(flipx ? 1 : -1);
			let yOffs = f.pspOffsets.y*-1;//-WEAPONTOP;
			psp.bAddWeapon = false;
			if (!psp.bAddWeapon)
			{
				//yOffs += WEAPONTOP/1.2;
				//yOffs /= 1.2;
			}
			
			psp.bInterpolate = !psp.firstTic && f.interpolate;
			
			double x, y;
			
			// if ((f.flags & ZSAnimator.LF_Additive) != 0)
			// {
			// 	x = psp.x + xOffs;
			// 	y = psp.y + yOffs;
			// }
			// else
			// {
			// 	if ((f.flags & ZSAnimator.LF_DontCenterPSP) == 0)
			// 	{
			// 		x = xOffs + 160.0;
			// 		y = yOffs + 100.0;
			// 	}
			// 	else
			// 	{
			// 		x = xOffs;
			// 		y = yOffs + (f.pspId == PSP_WEAPON ? WEAPONTOP : 0);
			// 	}
			// }
			if (!psp.bInterpolate)
			{
				psp.oldx = psp.x;
				psp.oldy = psp.y;
			}
			
			SetPSPPosition(psp, (x, y));
			
			// if (f.flipy || anim.flipAnimX)
			// {
				// psp.bflip = true;
			// }
			// else
			// {
				// psp.bflip = false;
			// }
			psp.pivot = (0.5,0.5);
			
			if (flipx)
			{
				f.pspScale = (f.pspScale.x * -1, f.pspScale.y * 1);
			}
			
			Vector2 sc;
			Double ang;
			// if ((f.flags & ZSAnimator.LF_ADDITIVE) != 0)
			// {
			// 	sc = (psp.scale.x + f.pspScale.x, psp.scale.y + f.pspScale.y);
			// 	ang = psp.rotation + f.angles.x;
			// }
			
			// SetPSPScale(psp, sc);
			// SetPSPRotation(psp, ang);
			TransformPSPCorners(psp, anim, f);
		}
	}
	
	// Todo: make additive functional again
	void ApplyView(ZSAnimation anim, ZSAnimationFrame f)
	{
		float viewScale = CVar.GetCVar("zsa_viewscale", players[consoleplayer]).GetFloat();
		double roll = f.angles.x * viewScale;
		double ang = f.angles.y * viewScale;
		double pit = f.angles.z * viewScale;
		double fovScale = f.pspscale.x;// * viewScale;
		
		/*if (anim.flipAnimX)
		{
			roll *= -1.0;
			ang *= -1.0;
		}*/
		
		// if ((f.flags & ZSAnimator.LF_Additive) != 0)
		// {
		// 	roll += ply.mo.viewroll;
		// 	ang += ply.mo.viewangle;
		// 	pit += ply.mo.viewpitch;
		// 	if (ply.ReadyWeapon)
		// 	{
		// 		if (ply.ReadyWeapon.FOVScale == 0)
		// 		{
		// 			ply.ReadyWeapon.FOVScale = 1;
		// 		}
				
		// 		fovScale += ply.ReadyWeapon.FOVScale;
		// 	}
		// }
		ply.mo.A_SetViewRoll(roll, SPF_INTERPOLATE);
		ply.mo.A_SetViewAngle(ang, SPF_INTERPOLATE);
		ply.mo.A_SetViewPitch(pit, SPF_INTERPOLATE);
		if (ply.ReadyWeapon)
		{
			ply.ReadyWeapon.FOVScale = fovScale;
		}
	}
	
	// Applies the Frame to the reference.
	void ApplyReference(ZSanimation anim, ZSAnimationFrame f)
	{
		if (!anim.references.CheckKey(f.reference))
		{
			ThrowAbortException(string.Format("Animation %s contains a frame with a reference (%s), but there is no reference set in the dictionary. " .. 
			"Make sure to call ZSAnimation.SetReference()", anim.GetClassName(), f.reference));
			return;
		}
		
		ZSAnimationReference animRef = anim.references.Get(f.reference);
		if (!animRef) { return; }
		
		Vector3 pos = (f.pspOffsets.x, f.pspOffsets.y, f.pspOffsets.z);
		if ((anim.flags & ZSanimator.LF_FlipX) != 0)
		{
			pos = (pos.x * -1, pos.y, pos.z);
		}
		animRef.animPos = pos;
		animRef.animScales = f.pspScale;
		
		Vector3 ang = f.angles;
		if ((anim.flags & ZSAnimator.LF_FlipX) != 0)
		{
			ang = (ang.x * -1, ang.y, ang.z);
		}
		animRef.animRot = ang;
	}
	
	// Wrapper to apply a frame.
	play void ApplyFrame(ZSAnimation anim, ZSAnimationFrame f)
	{
		if (f.pspId == ZSAnimator.PlayerView)
		{
			ApplyView(anim, f);
		}
		else if (f.pspId != ZSAnimator.None)
		{
			let zsap = zsaPspDict.GetIfExists(f.pspId);
			if (zsap.psp)
			{
				if (zsap.psp.bInterpolate && !f.interpolate)
				{
					zsap.SetInterpolation(false);
				}
				else if (!zsap.psp.bInterpolate && f.interpolate)
				{
					zsap.SetInterpolation(true);
				}
				zsap.psp.bInterpolate = f.interpolate;
			}
			// Due to an error in my blender files that I caught too late and cannot be arsed 
			// to fix, the angles need to be re-ordered.
			let reorder = ZSAnimator.ReorderZSAToGuta(f.angles);
			let [t,r,s] = CalculateTRS(f.pspOffsets, f.angles, (f.pspScale.x, f.pspScale.y, 1));
			r = ZSAnimator.ReorderZSAToGuta(r);
			zsap.SetTRS(t,r,s);
			zsap.ApplyToPSP();
			LinkPSprite(anim, f, zsap.psp);
		}
		else if (f.pspId == ZSAnimator.None && f.reference)
		{
			ApplyReference(anim, f);
		}
	}
	
	override void OnDestroy()
	{
		StopAllAnimations();
		super.OnDestroy();
	}

	// Updates the zsapsp directory.
	// Iterate through the player's psprites and make the zsapsp if necessary, then link it up.
	// This means ALL PSPRITES the player owns!!
	void UpdateZSAPSPs()
	{
		if (!ply)
		{
			return;
		}
		for (let p = ply.psprites; p != null; p = p.next)
		{
			console.printf("id %d", p.id);
			let zsap = zsaPspDict.GetIfExists(p.id);
			
			if (p.bDestroyed)
			{
				console.printf("destroyed");
				continue;
			}

			if (!zsap)
			{
				zsap = MakeZSAPSP(p.id);
				AddZSAPSPToDict(zsap);
			}

			if (zsap)			
			{
				zsap.psp = p;
			}
		}
	}

	virtual void HandleBlenderPipeline()
	{
		UpdateZSAPSPs();

		// BIG TODO:
		// Somehow rewrite this to make dynamically setting psprite information easier.
		for (int i = 0; i < currentAnimations.size(); i++)
		{
			let currentAnimation = currentAnimations[i];
			if (currentAnimation && currentAnimation.currentTicks < currentAnimation.frameCount)
			{
				MapIterator<int, ZSanimationFrameNode> it;
				it.Init(currentAnimation.nodeMap);
				foreach (k, v : it)
				{
					let f = currentAnimation.EvaluateFrame(k, currentAnimation.currentTicks, currentAnimation.currentTicks + abs(currentAnimation.playbackSpeed));
					// f.PrintFrameInfo();
					if (f)
					{
						ApplyFrame(currentAnimation, f);
					}
				}
			}
		}
		
		AdvanceAnimations();
	}
	
	override void Tick()
	{
		super.Tick();
		if (!manual)
		{
			HandleBlenderPipeline();
		}
	}
	
	// Returns a currently playing animation.
	ZSAnimation GetAnimation(Class<ZSAnimation> animationType)
	{
		for (int i = 0; i < currentAnimations.Size(); i++)
		{
			let a = currentAnimations[i];
			if (a IS animationType) { return a; }
		}
		return NULL;
	}
	
	// Preferred to call this over A_Overlay. Returns a pointer to the (newly made) ZSAPSP instance.
	play ZSAPSP CreateOverlay(int pspId, Actor caller, StateLabel lb = NULL)
	{
		if (!ply) { return NULL; }
		//ply.mo.A_Overlay(pspId, lb, noOverride);
		if (!IsPSPIDValid(pspId))
		{
			ThrowAbortException("PSP %d is not valid!", pspId);
		}
		PSprite psp = ply.GetPSprite(pspId);
		if (!psp) { return NULL; }
		psp.caller = caller;
		let st = caller.FindState(lb, true);
		psp.SetState(st);
		// Fucky things are gonna happen otherwise.
		psp.firstTic = true;

		ZSAPSP zsaPsp = NULL;
		if (!zsaPspDict.CheckKey(pspId))
		{
			zsaPsp = MakeZSAPSP(pspId);
			AddZSAPSPToDict(zsaPsp);
		}
		else
		{
			zsaPsp = zsaPspDict.GetIfExists(pspId);
		}
		zsaPsp.psp = psp;
		return zsaPSP;
	}
	
	// Returns the current PSPrite informmation as a ZSAnimationFrame if need be.
	// Todo: make it use ZSAPSP instead, as ZSAPSP has all three rotation axises etc. for scaling. 
	static ZSAnimationFrame GetCurrentPspAsFrame(PlayerInfo ply, int layerId)
	{
		let ret = ZSAnimationFrame.Create(layerId, 0, (0,0,0), (0,0), (0,0), false);
		
		if (layerId != ZSAnimator.PlayerView)
		{
			let psp = ply.FindPSprite(layerId);
			if (!psp) { return ret; }
			ret.angles = (psp.rotation, 0, 0);
			ret.pspOffsets = (psp.x, psp.y, 0);
			ret.pspScale = psp.scale;
			ret.interpolate = psp.bInterpolate;
		}
		else
		{
			ret.angles = (ply.mo.ViewRoll, ply.mo.ViewAngle, ply.mo.ViewPitch);
			if (!ply.ReadyWeapon) { return ret; }
			ret.pspScale = (ply.ReadyWeapon.FOVScale, ply.ReadyWeapon.FOVScale);
		}
		
		return ret;
	}
	
	// Wrapper function to animate a current PSP to something desired.
	// Todo: Rewrite this to both use ZSAPSP and be less hokey.
	void AnimatePSPTo(PlayerInfo ply, PSPrite psp, Vector2 pos, Vector2 sc, double ang, int tics, bool interpolate = true)
	{
		let frm = GetCurrentPspAsFrame(ply, psp.id);
		frm.pspOffsets.y -= WEAPONTOP;
		let to = ZSAnimationFrame.Create(psp.id, tics-1, (ang, 0, 0), pos, sc, interpolate);
		AnimateFromTo(ply, frm, to, tics, interpolate);
	}
	
	// Wrapper function to animate a current PSP to something desired.
	// Todo: Rewrite this to both use ZSAPSP and be less hokey and a bitch to work with, as right now, it's annoying as hell. I don't like it one bit.
	void AnimateFromTo(PlayerInfo ply, ZSAnimationFrame from, ZSAnimationFrame to, int tics, bool interpolate = true)
	{
		ZSAnimation anim = New("ZSAnimation");
		from.frameNum = 0;
		to.frameNum = tics-1;
		from.interpolate = interpolate;
		to.interpolate = interpolate;
		
		anim.frames.Push(from);
		anim.frames.Push(to);
		anim.frameCount = tics;
		
		anim.LinkList();
		StartAnimation(ply, anim);
	}

	void DumpDictionary()
	{
		foreach(k, v : self.zsaPspDict)
		{
			console.printf("%d has psp %d", k, v.psp != NULL);
		}
	}
}

class ZSAnimatorDebugger : EventHandler
{
	
}