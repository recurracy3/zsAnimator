class ZSAnimationFrame
{
	enum FrameValue
	{
		ZSAFV_Position,
		ZSAFV_Rotation,
		ZSAFV_Scale
	}
	
	int pspId;
	int frameNum;
	int firstFrameNum;
	Vector3 angles;
	Vector3 pspOffsets;
	Vector2 pspScale;
	bool interpolate;
	ZSAnimation anim;
	string reference;
	// ZSAnimationFrameNode node;
	
	int flags;
	
	static ZSAnimationFrame Create(int pspId, int frameNum, Vector3 angles, Vector2 pspOffsets, Vector2 pspScale, bool interpolate, bool layered = false,
		string reference = "",
		float zPos = 0.0)
	{
		let frame = ZSAnimationFrame(New("ZSAnimationFrame"));
		frame.frameNum = frameNum;
		frame.pspId = pspId;
		frame.angles = angles;
		frame.pspOffsets = (pspOffsets.x, pspOffsets.y, zPos);
		frame.pspScale = pspScale;
		// if (!layered)
		// {
			// if (frame.pspScale.x < 0)
			// {
				// frame.flipx = true;
			// }
			// if (frame.pspScale.y < 0)
			// {
				// frame.flipy = true;
			// }
		// }
		
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
		f.flags = self.flags;
		f.reference = self.reference;
		return f;
	}
}

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
	bool _projectFromView;
	property ProjectFromView : _projectFromView;
	
	Default
	{
		+NOBLOCKMAP;
		+NOINTERACTION;
		-SOLID;
		+NOGRAVITY;
	}
	
	override void Tick()
	{
		super.Tick();
		
		// Since references are supposed to turn a local view coordinate into a world coordinate,
		// use the player reference to adjust the coordinates accordingly.
		// Also make sure to use Quaternion maths to prevent gimbal locking and rotate the reference.
		
		//float viewZ = ply.viewz + (ply.mo.height * 0.5 - ply.mo.floorclip);
		float viewZ = ply.viewz;
		Vector3 plyAngs = (ply.mo.ViewAngle + ply.mo.angle, ply.mo.ViewPitch + ply.mo.Pitch, ply.mo.ViewRoll + ply.mo.Roll);
		Vector3 plyPos = (ply.mo.pos.x, ply.mo.pos.y, viewZ);
		
		Vector3 aPos = (self.animPos.x*1.2, self.animPos.y, self.animPos.z);
		if (self._projectFromView)
		{
			aPos = (aPos.x / 15.0, aPos.y / 15.0, aPos.z);
		}
		
		// console.printf("animpos %.2f %.2f %.2f", self.animPos.x, self.animPos.y, self.animPos.z);
		Quat base = Quat.FromAngles(plyAngs.x, plyAngs.y, plyAngs.z);
		Vector3 offs = base * (aPos.z*-1, aPos.x, aPos.y);
		// console.printf("offs %.2f %.2f %.2f", offs.x, offs.y, offs.z);
		Vector3 glob = level.Vec3Offset(plyPos, (offs.x, offs.y, offs.z));
		// console.printf("glob %.2f %.2f %.2f", glob.x, glob.y, glob.z);
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
		
		// self.A_SetAngle(atan2(myrotV.y, myrotV.x), SPF_INTERPOLATE);
		// self.A_SetPitch(-asin(myrotV.z), SPF_INTERPOLATE);
	}
}

Class ZSAnimation
{
	PlayerInfo ply;
	int frameCount;
	int framerate;
	double playbackSpeed;
	bool running;
	//ZSAnimationFrame previousFrame;
	//Weapon currentWeapon;
	Array<ZSAnimationFrame> frames;
	// Associative map of nodes, where the key is the PSP Id.
	Map<int, ZSAnimationFrameNode > nodeMap;
	Map<int, ZSAnimationFrameNode > currentNodes;
	// ZSAnimationFrameNode currentNode;
	// ZSAnimationFrameNode firstNode;
	// ZSAnimationFrameNode lastNode;
	bool spritesLinked;
	int lastTickDiff;
	bool layered; // deprecated, does nothing
	bool destroying;
	// DO NOT change this. It's done by ZSAnimator itself.
	bool filledIn;
	ZSAnimator currentAnimator;
	
	// Used in conjecture with the 'reference' custom property. 
	Map<string, ZSAnimationReference> references;
	
	// It's possible for animations to fall 'inbetween' tics defined by Zdoom, aka the default tic rate of 35/s, thanks to the variable framerate.
	// When this happens we need to determine the positions, rotations and scale between the last frame and the current frame as a percentage.
	double currentTicks;
	
	int flags;
	
	virtual void MakeFrameList() { }
	virtual void Initialize() { }
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
	
	void SetLayerFlags(int pspId, int flags, bool set = true)
	{
		for (int i = 0; i < frames.size(); i++)
		{
			let f = frames[i];
			if (!f || f.bDestroyed) { continue; }
			if (f.pspId == pspId)
			{
				if (set)
				{
					f.flags |= flags;
				}
				else
				{
					f.flags &= ~flags;
				}
			}
		}
	}
	
	void SetFlags(int newflags, bool set = true)
	{
		if (set)
			self.flags |= newflags;
		else
			self.flags &= ~newflags;
			
	}
	
	/*bool GotoNextFrame()
	{
		if (framerate >= 0.0)
			currentNode = currentNode.next;
		else
			currentNode = currentNode.prev;
			
		return currentNode != NULL;
	}*/
	
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
				
				// if (ticksNext >= n.frame.frameNum && ticksNext <= test.frame.frameNum)
				// {
					// return test;
				// }
			}
			
			n = test;
		}
		return n;
		
		// let n = currentNode;
		// int diff = abs(int(ticksNext) - int(ticksNow));
		// if (forceNext) diff = 1;
		
		// for (int i = 0; i < diff; i++)
		// {
			// if (playbackSpeed >= 0.0)
			// {
				// if (n.next)
					// n = n.next;
			// }
			// else
			// {
				// if (n.prev)
					// n = n.prev;
			// }
		// }
		
		// return n;
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
		
		// let n = EvaluateNextNode(currentTicks, currentTicks + playbackSpeed);
		// if (n != currentNode)
		// {
			// currentNode = n;
		// }
		// currentTicks += abs(playbackSpeed*ticRate);
		// return currentNode != NULL;
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
		
		// console.printf("frameA frameNum %d frameB frameNum %d", frameA.frameNum, frameB.frameNum);
		
		// if ((frameA.frameNum > 0 && frameB.frameNum > 0) && frameA.frameNum != frameB.frameNum)
		if (frameA.frameNum != frameB.frameNum)
		{
			double tickIn = ticksA;
			int nA = frameA.frameNum;
			int nB = frameB.frameNum;
			
			if (playbackSpeed < 0)
			{
				// nA = frameB.frameNum;
				// nB = frameA.frameNum;
				tickIn = int(self.frameCount) - ticksA;
			}
			tickPerc = ZSAnimator.LinearMap(tickIn, nA, nB, 0.0, 1.0, true);
		}
		else
		{
			//tickPerc = ticksA%1.0;
		}
		
		// console.printf("psp %d tickPerc %f ticksA %f ticksB %f frameA %d frameB %d", layer, tickPerc, ticksA, ticksB, frameA.frameNum, frameB.frameNum);
		
		ret.interpolate = frameA.interpolate;
		ret.flags = frameA.flags;
		
		Vector3 rot = (0,0,0);
		Vector3 pos = (0,0,0);
		Vector2 sc = (0,0);
		
		bool flipx = self.flags & ZSAnimator.LF_FlipX != 0;
		
		if ((frameA && frameB) && frameA != frameB)
		{	
			if ((frameA.flags & ZSAnimator.LF_Additive) != 0)
			{
				if ((frameA.flags & ZSAnimator.LF_AdditiveNoPSP) == 0)
				{
					let pspF = ZSAnimator.GetCurrentPspAsFrame(ply, layer);
					pspF.pspOffsets = ((pspF.pspOffsets.x-160.0)*(flipx?1:-1), (pspF.pspOffsets.y-100.0)*-1, pspF.pspOffsets.z);
					
					let rotB = (framea.angles.x - pspF.angles.x,
						framea.angles.y - pspF.angles.y,
						framea.angles.z - pspF.angles.z);
					let posB = (framea.pspOffsets.x - pspF.pspOffsets.x,
						framea.pspOffsets.y - pspF.pspOffsets.y,
						framea.pspOffsets.z - pspF.pspOffsets.z);
					let scB = (framea.pspScale.x - pspF.pspScale.x,
						framea.pspScale.y - pspF.pspScale.y);
					
					rot = (frameB.angles.x - frameA.angles.x,
						frameB.angles.y - frameA.angles.y,
						frameB.angles.z - frameA.angles.z);
					pos = (frameB.pspOffsets.x - frameA.pspOffsets.x,
						frameB.pspOffsets.y - frameA.pspOffsets.y,
						frameB.pspOffsets.z - frameA.pspOffsets.z);
					sc = (frameB.pspScale.x - frameA.pspScale.x,
						frameB.pspScale.y - frameA.pspScale.y);
					
					rot.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, rot.x, rotB.x, false);
					rot.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, rot.y, rotB.y, false);
					rot.z = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, rot.z, rotB.z, false);
					
					pos.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, pos.x, posB.x, false);
					pos.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, pos.y, posB.y, false);
					pos.z = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, pos.z, posB.z, false);
					
					sc.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, sc.x, scB.x, false);
					sc.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, sc.y, scB.y, false);
				}
				else
				{
					rot = (frameB.angles.x - frameA.angles.x,
						frameB.angles.y - frameA.angles.y,
						frameB.angles.z - frameA.angles.z);
					pos = (frameB.pspOffsets.x - frameA.pspOffsets.x,
						frameB.pspOffsets.y - frameA.pspOffsets.y,
						frameB.pspOffsets.z - frameA.pspOffsets.z);
					sc = (frameB.pspScale.x - frameA.pspScale.x,
						frameB.pspScale.y - frameA.pspScale.y);
					
					rot.x = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, rot.x, false);
					rot.y = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, rot.y, false);
					rot.z = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, rot.z, false);
					
					pos.x = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, pos.x, false);
					pos.y = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, pos.y, false);
					pos.z = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, pos.z, false);
					
					sc.x = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, sc.x, false);
					sc.y = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, sc.y, false);
				}
			}
			else
			{
				rot.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.angles.x, frameB.angles.x, false);
				rot.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.angles.y, frameB.angles.y, false);
				rot.z = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.angles.z, frameB.angles.z, false);
				
				pos.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspOffsets.x, frameB.pspOffsets.x, false);
				pos.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspOffsets.y, frameB.pspOffsets.y, false);
				pos.z = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspOffsets.z, frameB.pspOffsets.z, false);
				
				sc.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspScale.x, frameB.pspScale.x, false);
				sc.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspScale.y, frameB.pspScale.y, false);
			}
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
	static clearscope double LinearMap(double val, double source_min, double source_max, double out_min, double out_max, bool clampIt = false) {
        double d = (val - source_min) * (out_max - out_min) / (source_max - source_min) + out_min;
        if (clampit) {
            double truemax = out_max > out_min ? out_max : out_min;
            double truemin = out_max > out_min ? out_min : out_max;
            d = Clamp(d, truemin, truemax);
        }
        return d;
    }
	
	static ZSAnimator Create()
	{
		ZSAnimator animator = ZSanimator(New("ZSAnimator"));
		return animator;
	}
	
	enum SpecialAnimNums
	{
		PlayerView = -5000,
		None = -5001,
	}
	
	enum ZSAFlags
	{
		LF_Additive = 1 << 0, // When set, the offsets for this layer get added to the layer's current offset.
		LF_AdditiveNoPSP = 1 << 1, // When used in conjunction with LF_Additive, ZSAnimator does not apply the current PSPrite offsets but purely uses the delta between frames.
		LF_DontCenterPSP = 1 << 2, // When set, the PSPrite will not be centered automatically.
		LF_FlipX = 1 << 3, // Can be applied to individual frames. If applied to animations, flip the animation rotations and positions.
		LF_FlipY = 1 << 4 // Same as aboves
	}
	
	//ZSAnimation currentAnimation;
	PlayerInfo ply;
	bool manual;
	bool forceDisableInterpolation;
	Array<ZSAnimation> currentAnimations;
	
	static ZSAnimation GetAnimationFromClassName(Class<ZSanimation> animationClass)
	{
		let anim = ZSAnimation(New(animationClass));
		anim.Initialize();
		anim.MakeFrameList();
		return anim;
	}
	
	// This function can be used to start an animation directly and let ZSAnimator handle everything.
	void StartAnimation(PlayerInfo ply, ZSAnimation anim, int frame = 0, int endFrame = 0, double playbackSpeed = 1.0)
	{
		playbackSpeed *= CVar.GetCVar("zsa_playbackSpeed", players[consoleplayer]).GetFloat();
		/*let anim = ZSAnimation(New(animationClass));
		anim.Initialize();
		anim.MakeFrameList();
		anim.LinkList();*/
		self.ply = ply;
		
		// if (playbackSpeed >= 0)
		// {
			// anim.currentNode = anim.firstNode;
		// }
		// else
		// {
			// anim.currentNode = anim.lastNode;
		// }
		
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
		anim.currentAnimator = self;
		
		/*if (currentAnimation == NULL || currentAnimation.GetClass() != animationClass)
		{
			self.ply = ply;
			currentAnimation = ZSAnimation(New(animationClass));
			currentAnimation.Initialize();
			currentAnimation.MakeFrameList();
			currentAnimation.LinkList();
		}
		if (playbackSpeed >= 0)
		{
			currentAnimation.currentNode = currentAnimation.firstNode;
		}
		else
		{
			currentAnimation.currentNode = currentAnimation.lastNode;
		}
		
		currentAnimation.currentTicks = frame;
		currentAnimation.running = true;
		currentAnimation.playbackSpeed = playbackSpeed;
		currentAnimation.lastTickDiff = 0;
		currentAnimation.flipAnimX = flipAnimX;
		currentAnimation.flipAnimY = flipAnimY;*/
	}
	
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
	
	void StopAllAnimations()
	{
		Array<ZSAnimation> deletedAnims;
		
		for (int i = 0; i < currentAnimations.size(); i++)
		{
			currentAnimations[i].Destroy();
		}
		
		currentAnimations.Clear();
	}
	
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
					currentAnimation.destroying = true;
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
		
		/*if (!currentAnimation)
			return;
		
		currentAnimation.AdvanceAnimation();*/
	}
	
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
				//if (st && st.nextstate == NULL || st.nextstate != psp.curState)
				if (st)
				{
					// if (nextN && nextN.frames.size() >= 1 && psp.tics > 0)
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
	static Vector3 QuatToEuler(quat r)
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
	
	Vector3 ReorderToGuta(Vector3 angs)
	{
		// ORDER IN ZSANIMATOR:
		// ROLL == X
		// YAW == Y
		// PITCH == Z
		
		// ORDER OUT GUTAMATICS:
		// YAW == X
		// PITCH == Y
		// ROLL == Z
		
		// (1, 0, 0) == rotate on forwards axis (results in rotating roll)
		// (0, 1, 0) == rotate by up axis (results in rotating yaw)
		// (0, 0, 1) == rotate by side axis (results in rotating pitch)
		
		Quat q1 = Quat.AxisAngle((1, 0, 0), angs.x);
		Quat q2 = Quat.AxisAngle((0, 1, 0), angs.y);
		Quat q3 = Quat.AxisAngle((0, 0, 1), angs.z);
		Quat q = q1 * q2 * q3;
		let outV = QuatToEuler(q);
		
		// Quat inQ = Quat.FromAngles(
		
		return outV;
	}
	
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
		angs = ReorderToGuta(angs);
		
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
			
			psp.bInterpolate = !psp.firstTic && f.interpolate && !forceDisableInterpolation;
			
			double x, y;
			
			if ((f.flags & ZSAnimator.LF_Additive) != 0)
			{
				x = psp.x + xOffs;
				y = psp.y + yOffs;
			}
			else
			{
				if ((f.flags & ZSAnimator.LF_DontCenterPSP) == 0)
				{
					x = xOffs + 160.0;
					y = yOffs + 100.0;
				}
				else
				{
					x = xOffs;
					y = yOffs + (f.pspId == PSP_WEAPON ? WEAPONTOP : 0);
				}
			}
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
			if ((f.flags & ZSAnimator.LF_ADDITIVE) != 0)
			{
				sc = (psp.scale.x + f.pspScale.x, psp.scale.y + f.pspScale.y);
				ang = psp.rotation + f.angles.x;
			}
			
			// SetPSPScale(psp, sc);
			// SetPSPRotation(psp, ang);
			TransformPSPCorners(psp, anim, f);
			
			LinkPSprite(anim, f, psp);
		}
	}
	
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
		
		if ((f.flags & ZSAnimator.LF_Additive) != 0)
		{
			roll += ply.mo.viewroll;
			ang += ply.mo.viewangle;
			pit += ply.mo.viewpitch;
			if (ply.ReadyWeapon)
			{
				if (ply.ReadyWeapon.FOVScale == 0)
				{
					ply.ReadyWeapon.FOVScale = 1;
				}
				
				fovScale += ply.ReadyWeapon.FOVScale;
			}
		}
		ply.mo.A_SetViewRoll(roll, SPF_INTERPOLATE);
		ply.mo.A_SetViewAngle(ang, SPF_INTERPOLATE);
		ply.mo.A_SetViewPitch(pit, SPF_INTERPOLATE);
		if (ply.ReadyWeapon)
		{
			ply.ReadyWeapon.FOVScale = fovScale;
		}
	}
	
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
	
	play void ApplyFrame(ZSAnimation anim, ZSAnimationFrame f)
	{
		if (f.pspId == ZSAnimator.PlayerView)
		{
			ApplyView(anim, f);
		}
		else if (f.pspId != ZSAnimator.None)
		{
			ApplyPsp(anim, f);
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
	
	override void Tick()
	{
		super.Tick();
		
		if (manual) { return; }
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
				/*let n = currentAnimation.currentNode;
				if (n)
				{
					for (int j = 0; j < n.frames.size(); j++)
					{
						//let f = n.frames[i];
						let f = currentAnimation.EvaluateFrame(n.frames[j].pspId, currentAnimation.currentTicks, currentAnimation.currentTicks + currentAnimation.playbackSpeed);
						if (f)
						{
							ApplyFrame(currentAnimation, f);
						}
					}
				}*/
			}
		}
		
		AdvanceAnimations();
	}
	
	ZSAnimation GetAnimation(Class<ZSAnimation> animationType)
	{
		for (int i = 0; i < currentAnimations.Size(); i++)
		{
			let a = currentAnimations[i];
			if (a IS animationType) { return a; }
		}
		return NULL;
	}
	
	play void CreateOverlay(int pspId, Actor caller, StateLabel lb = NULL)
	{
		if (!ply) { return; }
		//ply.mo.A_Overlay(pspId, lb, noOverride);
		PSprite psp = ply.GetPSprite(pspId);
		if (!psp) { return; }
		psp.caller = caller;
		let st = caller.FindState(lb, true);
		psp.SetState(st);
		psp.firstTic = true;
	}
	
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
	
	void AnimatePSPTo(PlayerInfo ply, PSPrite psp, Vector2 pos, Vector2 sc, double ang, int tics, bool interpolate = true)
	{
		let frm = GetCurrentPspAsFrame(ply, psp.id);
		frm.pspOffsets.y -= WEAPONTOP;
		let to = ZSAnimationFrame.Create(psp.id, tics-1, (ang, 0, 0), pos, sc, interpolate);
		AnimateFromTo(ply, frm, to, tics, interpolate);
	}
	
	void AnimateFromTo(PlayerInfo ply, ZSAnimationFrame from, ZSAnimationFrame to, int tics, bool interpolate = true)
	{
		ZSAnimation anim = New("ZSAnimation");
		// let curPos = (psp.x, psp.y);
		// let curAng = psp.rotation;
		// let curSc = psp.scale;
		from.frameNum = 0;
		to.frameNum = tics-1;
		from.interpolate = interpolate;
		to.interpolate = interpolate;
		
		anim.frames.Push(from);
		anim.frames.Push(to);
		anim.frameCount = tics;
		anim.SetLayerFlags(from.pspId, LF_DontCenterPSP);
		
		anim.LinkList();
		
		// anim.frames.Push(ZSAnimationFrame.Create(psp.id, 0, (curAng, 0, 0), curPos, curSc, interpolate));
		// anim.frames.Push(ZSAnimationFrame.Create(psp.id, tics, (ang, 0, 0), pos, sc, interpolate));
		StartAnimation(ply, anim);
	}
}

class ZSAnimatorDebugger : EventHandler
{
	
}