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
	Vector3 angles;
	Vector2 pspOffsets;
	Vector2 pspScale;
	bool interpolate;
	bool flipx;
	bool flipy;
	string sprite;
	bool followWeapon;
	ZSAnimationFrameNode node;
	
	int flags;
	
	static ZSAnimationFrame Create(int pspId, int frameNum, Vector3 angles, Vector2 pspOffsets, Vector2 pspScale, bool interpolate, bool layered = false, bool followWeapon = false)
	{
		let frame = ZSAnimationFrame(New("ZSAnimationFrame"));
		frame.frameNum = frameNum;
		frame.pspId = pspId;
		frame.angles = angles;
		frame.pspOffsets = pspOffsets;
		frame.pspScale = pspScale;
		if (!layered)
		{
			if (frame.pspScale.x < 0)
			{
				frame.flipx = true;
			}
			if (frame.pspScale.y < 0)
			{
				frame.flipy = true;
			}
			frame.pspScale = (abs(frame.pspScale.X), abs(frame.pspScale.Y));
		}
		
		frame.interpolate = interpolate;
		frame.followWeapon = followWeapon;
		return frame;
	}
	
	void PrintFrameInfo()
	{
		console.printf("psp %d frame %d a: (%.3f %.3f %.3f) p: (%.3f %.3f) s: (%.3f %.3f) i: %d s: %s", 
			pspId, frameNum, 
			angles.x, angles.y, angles.z, 
			pspOffsets.x, pspOffsets.y, 
			pspScale.x, pspScale.y, 
			interpolate,
			sprite);
	}
}

class ZSAnimationFrameNode
{
	ZSAnimationFrameNode next;
	ZSAnimationFrameNode prev;
	Array<ZSAnimationFrame> frames;
	
	static ZSAnimationFrameNode Create()
	{
		let node = ZSAnimationFrameNode(New("ZSAnimationFrameNode"));
		return node;
	}
	
	ZSAnimationFrame GetFrameByLayer(int pspId)
	{
		for (int i = 0; i < frames.Size(); i++)
		{
			let f = frames[i];
			if (f.pspId == pspId)
			{
				return f;
			}
		}
		return NULL;
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
	ZSAnimationFrameNode currentNode;
	ZSAnimationFrameNode firstNode;
	ZSAnimationFrameNode lastNode;
	bool spritesLinked;
	int lastTickDiff;
	bool flipAnimX, flipAnimY;
	bool layered; // deprecated, does nothing
	bool destroying;
	
	// It's possible for animations to fall 'inbetween' tics defined by Zdoom, aka the default tic rate of 35/s, thanks to the variable framerate.
	// When this happens we need to determine the positions, rotations and scale between the last frame and the current frame as a percentage.
	double currentTicks;
	
	virtual void MakeFrameList() { }
	virtual void Initialize() { }
	void LinkList()
	{
		//console.printf("linking list, %d frames", frameCount);
		currentNode = ZSAnimationFrameNode.Create();
		ZSAnimationFrameNode last = currentNode;
		firstNode = currentNode;
		for (int f = 0; f <= frameCount; f++)
		{
			ZSAnimationFrameNode n = ZSAnimationFrameNode.Create();
			for (int i = 0; i < frames.Size(); i++)
			{
				ZSAnimationFrame frame = frames[i];
				if (frame.frameNum == f)
				{
					last.frames.push(frame);
					frame.node = n;
					//console.printf("pushed frame %d cur. size %d", f, n.frames.size());
				}
			}
			
			last.next = n;
			n.prev = last;
			last = n;
		}
		
		lastNode = last;
	}
	
	void FlipLayer(int pspId, bool flipx = false, bool flipy = false)
	{
		for (int i = 0; i < frames.size(); i++)
		{
			let f = frames[i];
			if (f.pspId == pspId)
			{
				// console.printf("try flip layer %d", pspId);
				f.flipx = flipx;
				f.flipy = flipy;
			}
		}
	}
	
	void SetLayerFlags(int pspId, int flags, bool set = true)
	{
		for (int i = 0; i < frames.size(); i++)
		{
			let f = frames[i];
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
	
	/*bool GotoNextFrame()
	{
		if (framerate >= 0.0)
			currentNode = currentNode.next;
		else
			currentNode = currentNode.prev;
			
		return currentNode != NULL;
	}*/
	
	ZSAnimationFrameNode EvaluateNextNode(double ticksNow, double ticksNext, bool forceNext = false)
	{
		let n = currentNode;
		int diff = abs(int(ticksNext) - int(ticksNow));
		if (forceNext) diff = 1;
		//console.printf("now %f next %f diff %f", ticksNow, ticksNext, diff);
		
		for (int i = 0; i < diff; i++)
		{
			if (playbackSpeed >= 0.0)
			{
				if (n.next)
					n = n.next;
			}
			else
			{
				if (n.prev)
					n = n.prev;
			}
		}
		
		return n;
	}
	
	bool AdvanceAnimation(double ticRate = 1.0)
	{
		let n = EvaluateNextNode(currentTicks, currentTicks + playbackSpeed);
		if (n != currentNode)
		{
			currentNode = n;
		}
		currentTicks += abs(playbackSpeed*ticRate);
		return currentNode != NULL;
	}
	
	ZSAnimationFrame GetCurrentPspAsFrame(int layerId)
	{
		let ret = ZSAnimationFrame.Create(layerId, 0, (0,0,0), (0,0), (0,0), false);
		
		if (layerId != ZSAnimator.PlayerView)
		{
			let psp = ply.FindPSprite(layerId);
			if (!psp) { return ret; }
			ret.angles = (psp.rotation, 0, 0);
			ret.pspOffsets = (psp.x, psp.y);
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
	
	ZSAnimationFrame EvaluateFrame(int layer, double ticksA, double ticksB)
	{
		let currNode = currentNode;
		let nextNode = EvaluateNextNode(ticksA, ticksB, true);
		//double tickPerc = tickDiff % 1.0;
		double tickPerc = ticksA%1.0;
		double margin = 0.01;
		bool dontEval = false;
		//bool dontEval = tickPerc <= margin || tickPerc >= 1.0-margin;
		//if (self.layered) { dontEval = false; }
		//console.printf("a %f b %f tickperc %f margin %f eval: %d", ticksA, ticksB, tickPerc, margin, dontEval);
		if (dontEval)
		{
			// console.printf("dont eval psp %d tic %d", layer, ticksA);
			let n = currNode;
			if (tickPerc >= 1-margin)
				n = nextNode;
				
			for (int i = 0; i < n.frames.Size(); i++)
			{
				let f = n.frames[i];
				if (f.pspId == layer)
				{
					// f.PrintFrameInfo();
					return f;
				}
			}
			return NULL;
		}
		
		let ret = ZSAnimationFrame.Create(layer, int(ticksA), (0,0,0), (0,0), (0,0), false);
		
		ZSAnimationFrame frameA = NULL;
		ZSAnimationFrame frameB = NULL;
		for (int i = 0; i < currNode.frames.size(); i++)
		{
			let f = currNode.frames[i];
			if (f.pspId == layer)
			{
				frameA = f;
				break;
			}
		}
		
		for (int i = 0; i < nextNode.frames.size(); i++)
		{
			let f = nextNode.frames[i];
			if (f.pspId == layer)
			{
				frameB = f;
				break;
			}
		}
		
		if (frameA && frameB)
		{
			// console.printf("layered %d", self.layered);
			// console.printf("evaluating psp %d frame %f %f %f layered %d", layer, ticksA, ticksB, tickPerc, self.layered);
			
			ret.interpolate = frameA.interpolate;
			ret.sprite = frameA.sprite;
			ret.flipy = frameA.flipy;
			ret.flags = frameA.flags;
			
			Vector3 rot = (0,0,0);
			Vector2 pos = (0,0);
			Vector2 sc = (0,0);
			
			// rot.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.angles.x, frameB.angles.x, false);
			// rot.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.angles.y, frameB.angles.y, false);
			// rot.z = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.angles.z, frameB.angles.z, false);
			
			// pos.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspOffsets.x, frameB.pspOffsets.x, false);
			// pos.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspOffsets.y, frameB.pspOffsets.y, false);
			
			// sc.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspScale.x, frameB.pspScale.x, false);
			// sc.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspScale.y, frameB.pspScale.y, false);
			
			console.printf("flags %d", frameA.flags);
			if ((frameA.flags & ZSAnimator.LF_Additive) != 0)
			{
				if ((frameA.flags & ZSAnimator.LF_AdditiveNoPSP) == 0)
				{
					let pspF = GetCurrentPspAsFrame(layer);
					pspF.pspOffsets = ((pspF.pspOffsets.x-160.0)*(self.flipAnimX?1:-1), (pspF.pspOffsets.y-100.0)*-1);
					
					let rotB = (framea.angles.x - pspF.angles.x,
						framea.angles.y - pspF.angles.y,
						framea.angles.z - pspF.angles.z);
					let posB = (framea.pspOffsets.x - pspF.pspOffsets.x,
						framea.pspOffsets.y - pspF.pspOffsets.y);
					let scB = (framea.pspScale.x - pspF.pspScale.x,
						framea.pspScale.y - pspF.pspScale.y);
					
					rot = (frameB.angles.x - frameA.angles.x,
						frameB.angles.y - frameA.angles.y,
						frameB.angles.z - frameA.angles.z);
					pos = (frameB.pspOffsets.x - frameA.pspOffsets.x,
						frameB.pspOffsets.y - frameA.pspOffsets.y);
					sc = (frameB.pspScale.x - frameA.pspScale.x,
						frameB.pspScale.y - frameA.pspScale.y);
					
					rot.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, rot.x, rotB.x, false);
					rot.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, rot.y, rotB.y, false);
					rot.z = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, rot.z, rotB.z, false);
					
					pos.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, pos.x, posB.x, false);
					pos.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, pos.y, posB.y, false);
					
					sc.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, sc.x, scB.x, false);
					sc.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, sc.y, scB.y, false);
				}
				else
				{
					rot = (frameB.angles.x - frameA.angles.x,
						frameB.angles.y - frameA.angles.y,
						frameB.angles.z - frameA.angles.z);
					pos = (frameB.pspOffsets.x - frameA.pspOffsets.x,
						frameB.pspOffsets.y - frameA.pspOffsets.y);
					sc = (frameB.pspScale.x - frameA.pspScale.x,
						frameB.pspScale.y - frameA.pspScale.y);
					
					rot.x = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, rot.x, false);
					rot.y = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, rot.y, false);
					rot.z = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, rot.z, false);
					
					pos.x = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, pos.x, false);
					pos.y = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, pos.y, false);
					
					sc.x = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, sc.x, false);
					sc.y = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, 0, sc.y, false);
				}
				
				// rot.x = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, rot.x, frameB.angles.x, false);
				// rot.y = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, rot.y, frameB.angles.y, false);
				// rot.z = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, rot.z, frameB.angles.z, false);
				
				// pos.x = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, pos.x, frameB.pspOffsets.x, false);
				// pos.y = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, pos.y, frameB.pspOffsets.y, false);
				
				// console.printf("pos x y %f %f", pos.x, pos.y);
				
				// sc.x = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, sc.x, frameB.pspScale.x, false);
				// sc.y = ZSAnimator.LinearMap(tickPerc, 1.0, 0.0, sc.y, frameB.pspScale.y, false);
				
				// rot = (rot.x - frameA.angles.x,
					// rot.y - frameA.angles.y,
					// rot.z - frameA.angles.z);
				// pos = (pos.x - frameA.pspOffsets.x,
					// pos.y - frameA.pspOffsets.y);
				// sc = (sc.x - frameA.pspScale.x,
					// sc.y - frameA.pspScale.y);
					
				// let pspF = GetCurrentPspAsFrame(layer);
				// pspF.pspOffsets = ((pspF.pspOffsets.x-160.0)*(self.flipAnimX?1:-1), (pspF.pspOffsets.y-100.0)*-1);
				// pos = (pos.x - pspF.pspOffsets.x, 
					// pos.y - pspF.pspOffsets.y);
					
				// console.printf("pos %f %f", pos.x, pos.y);
					
				// bool flipRotation = (pspf.pspId == ZSAnimator.PlayerView && self.flipAnimX) || frameA.flipy;
					
				// if (flipRotation)
				// {
					// rot = (rot.x*-1, rot.y*-1, rot.z);
				// }
				// rot = ((rot.x - pspF.angles.x) + (frameA.flipy ? 0.0 : 0.0),
					// rot.y - pspF.angles.y,
					// rot.z - pspF.angles.z);
				
				// sc = (sc.x - pspF.pspScale.x, sc.y - pspF.pspScale.y);
			}
			else
			{
				rot.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.angles.x, frameB.angles.x, false);
				rot.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.angles.y, frameB.angles.y, false);
				rot.z = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.angles.z, frameB.angles.z, false);
				
				pos.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspOffsets.x, frameB.pspOffsets.x, false);
				pos.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspOffsets.y, frameB.pspOffsets.y, false);
				
				sc.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspScale.x, frameB.pspScale.x, false);
				sc.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspScale.y, frameB.pspScale.y, false);
			}
			
			//console.printf("perc %f", tickPerc);
			//rot.X = ZSAnimator.LinearMap(
			
			/*if (self.layered)
			{
				let pspF = GetCurrentPspAsFrame(layer);
				pspF.pspOffsets = ((pspF.pspOffsets.x-160.0)*(self.flipAnimX?1:-1), (pspF.pspOffsets.y-100.0)*-1);
				pos = (pos.x - pspF.pspOffsets.x, 
					pos.y - pspF.pspOffsets.y);
					
				bool flipRotation = (pspf.pspId == ZSAnimator.PlayerView && self.flipAnimX) || frameA.flipy;
				// console.printf("flip rot %d isview %d flipanimx %d flipy %d", flipRotation, pspf.pspId == zsAnimator.PlayerView, self.flipAnimX, frameA.flipy);
					
				if (flipRotation)
				{
					rot = (rot.x*-1, rot.y*-1, rot.z);
					// ret.flipy = false;
				}
				rot = ((rot.x - pspF.angles.x) + (frameA.flipy ? 0.0 : 0.0),
					rot.y - pspF.angles.y,
					rot.z - pspF.angles.z);
				
				sc = (sc.x - pspF.pspScale.x, sc.y - pspF.pspScale.y);
			}*/
			
			ret.angles = rot;
			ret.pspOffsets = pos;
			ret.pspScale = sc;
		}
		return ret;
	}
	
	void ReplacePspIds(int original, int replacement)
	{
		for (int i = 0; i < frames.Size(); i++)
		{
			let f = frames[i];
			if (f.pspId == original) f.pspId = replacement;
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
		PSP_HANDS = 1001,
	}
	
	enum ZSAFlags
	{
		LF_Additive = 1 << 0, // When set, the offsets for this layer get added to the layer's current offset.
		LF_AdditiveNoPSP = 1 << 1, // When used in conjunction with LF_Additive, ZSAnimator does not apply the current PSPrite offsets but purely uses the delta between frames.
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
		anim.LinkList();
		return anim;
	}
	
	// This function can be used to start an animation directly and let ZSAnimator handle everything.
	void StartAnimation(PlayerInfo ply, ZSAnimation anim, int frame = 0, int endFrame = 0, double playbackSpeed = 1.0)
	{
		playbackSpeed *= CVar.FindCVar("zsa_playbackSpeed").GetFloat();
		/*let anim = ZSAnimation(New(animationClass));
		anim.Initialize();
		anim.MakeFrameList();
		anim.LinkList();*/
		self.ply = ply;
		
		if (playbackSpeed >= 0)
		{
			anim.currentNode = anim.firstNode;
		}
		else
		{
			anim.currentNode = anim.lastNode;
		}
		
		anim.currentTicks = frame;
		anim.running = true;
		anim.playbackSpeed = playbackSpeed;
		anim.lastTickDiff = 0;
		anim.ply = ply;
		currentAnimations.Push(anim);
		
		/*if (currentAnimation == NULL || currentAnimation.GetClass() != animationClass)
		{
			self.ply = ply;
			currentAnimation = ZSAnimation(New(animationClass));
			//console.printf("start anim %s", currentAnimation.GetClassName());
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
	
	void StopAllAnimations()
	{
		Array<ZSAnimation> deletedAnims;
		
		for (int i = 0; i < currentAnimations.size(); i++)
		{
			currentAnimations[i].Destroy();
		}
		
		currentAnimations.Clear();
	}
	
	void AdvanceAnimations()
	{
		Array<ZSAnimation> deletedAnims;
		for (int i = 0; i < currentAnimations.size(); i++)
		{
			let currentAnimation = currentAnimations[i];
			if (currentAnimation)
			{
				if (currentAnimation.currentTicks > currentAnimation.frameCount)
				{
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
			double nextTicks = currentTicks + anim.playbackSpeed;
			let nextN = anim.EvaluateNextNode(currentTicks, nextTicks);
			bool equals = anim.currentNode == nextN;
			// the next node is equal to the current node. thus, we must delay the current state.
			if (equals && anim.playbackSpeed < 1.0)
			{
				psp.tics += 1;
			}
			else if (anim.playbackSpeed > 1.0)
			{
				let st = psp.curState;
				double diff = nextTicks - currentTicks;
				
				// this psp does not loop, or its next state does not exist, so we need to adjust the frames, possibly even skipping to the next frame if necessary
				//if (st && st.nextstate == NULL || st.nextstate != psp.curState)
				if (st)
				{
					if (nextN && nextN.frames.size() >= 1 && psp.tics > 0)
					{
						int ticsToSub = (nextN.frames[0].frameNum - f.frameNum) - 1;
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
							else if (pspTics == 1)
							{
								if (st && st.nextstate)
								{
									psp.setstate(st.nextstate);
									st = psp.curstate;
									ticsToSub -= 1;
								}
								else
								{
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
		}
	}
	
	void ApplyFrame(ZSAnimation anim, ZSAnimationFrame f)
	{
		if (f.pspId != ZSAnimator.PlayerView)
		{
			let psp = ply.FindPSprite(f.pspId);
			
			if (psp)
			{
				psp.bPivotPercent = true;
				let xOffs = f.pspOffsets.x*(anim.flipAnimX ? 1 : -1);
				let yOffs = f.pspOffsets.y*(anim.flipAnimY ? -1 : -1);//-WEAPONTOP;
				// if (f.pspId == PSP_WEAPON)
				// {
					// yOffs += WEAPONTOP;
				// }
				psp.bAddWeapon = f.followWeapon;
				if (!psp.bAddWeapon)
				{
					//yOffs += WEAPONTOP/1.2;
					//yOffs /= 1.2;
				}
				
				//console.printf("psp %d first tic %d", f.pspid, psp.firstTic);
				/*if (psp.firstTic)
				{
					psp.x = 160.0;
					psp.y = 100.0;
					psp.oldx = xOffs;
					psp.oldy = yOffs;
				}*/
				psp.bInterpolate = f.interpolate && !forceDisableInterpolation;
				
				if ((f.flags & ZSAnimator.LF_Additive) != 0)
				{
					psp.x = psp.x + xOffs;
					psp.y = psp.y + yOffs;
				}
				else
				{
					psp.x = xOffs + 160.0;
					psp.y = yOffs + 100.0;
				}
				if (!psp.bInterpolate)
				{
					psp.oldx = psp.x;
					psp.oldy = psp.y;
				}
				
				if (f.flipy || anim.flipAnimX)
				{
					psp.bflip = true;
				}
				else
				{
					psp.bflip = false;
				}
				psp.pivot = (0.5,0.5);
				//psp.scale = f.pspScale;
				
				if ((f.flags & ZSAnimator.LF_ADDITIVE) != 0)
				{
					let sc = (psp.scale.x + f.pspScale.x, psp.scale.y + f.pspScale.y);
					/*if (psp.bflip)
					{
						//sc = (abs(sc.x), abs(sc.y));
					}*/
					
					// psp.scale = sc;
					psp.scale = (psp.scale.x + f.pspScale.x, psp.scale.y + f.pspScale.y);
					psp.rotation += f.angles.x;
				
					// console.printf("psp %d layered %d rot %.3f, %.3f flip %d %d, f.pspscale %f sc %f pspscale %f", f.pspId, anim.layered, f.angles.x, psp.rotation, f.flipy, psp.bflip, f.pspscale.x, sc.x, psp.scale.x);
				}
				else
				{
					// console.printf("psp %d scale %f %f", f.pspid, psp.scale.x, psp.scale.y);
					if (psp.bflip)
					{
						// console.printf("bflip is true %f %f", f.pspscale.x, f.pspscale.y);
						f.pspScale = (abs(f.pspScale.x), abs(f.pspScale.y));
						// console.printf("bflip is true %f %f", f.pspscale.x, f.pspscale.y);
					}
					psp.scale = f.pspScale;
					// console.printf("psp %d scale %f %f", f.pspid, psp.scale.x, psp.scale.y);
					//psp.rotation = f.angles.x;// + (f.flipy ? 180.0 : 0.0);
					psp.rotation = f.angles.x * (f.flipy ? -1 : 1) + (f.flipy ? 180.0 : 0.0);
					// console.printf("psp %d layered %d rot %.3f, %.3f flip %d %d, f.pspscale %f pspscale %f", f.pspId, anim.layered, f.angles.x, psp.rotation, f.flipy, psp.bflip, f.pspscale.x, psp.scale.x);
					// console.printf("interp %d", psp.binterpolate);
				}
				
				//console.printf("psp %d frame %d xp yp %.3f %.3f", f.pspId, f.frameNum, psp.x, psp.y);
				//console.printf("psp %d frame %d r %.3f", f.pspId, f.frameNum, psp.rotation);
				//f.PrintFrameInfo();
				
				//psp.rotation = f.angles.x * (f.flipy ? -1 : 1) + (f.flipy ? 180.0 : 0.0);
				// console.printf("layer %d rotation %f %f", f.pspId, f.angles.x, psp.rotation);
				
				//currentAnimation.spritesLinked = false;
				LinkPSprite(anim, f, psp);
			}
		}
		else
		{
			float viewScale = CVar.FindCVar('zsa_viewscale').GetFloat();
			double roll = f.angles.x * viewScale;
			double ang = f.angles.y * viewScale;
			double pit = f.angles.z * viewScale;
			double fovScale = f.pspscale.x * viewScale;
			
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
				let n = currentAnimation.currentNode;
				//console.printf("ticks %f", currentAnimation.currentTicks);
				if (n)
				{
					// console.printf("i %d", currentTicks);
					for (int j = 0; j < n.frames.size(); j++)
					{
						//let f = n.frames[i];
						let f = currentAnimation.EvaluateFrame(n.frames[j].pspId, currentAnimation.currentTicks, currentAnimation.currentTicks + currentAnimation.playbackSpeed);
						if (f)
						{
							ApplyFrame(currentAnimation, f);
						}
					}
				}
			}
		}
		
		AdvanceAnimations();
	}
}