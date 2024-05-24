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
		}
		
		//frame.pspScale = (abs(frame.pspScale.X), abs(frame.pspScale.Y));
		frame.interpolate = interpolate;
		frame.followWeapon = followWeapon;
		return frame;
	}
	
	void PrintFrameInfo()
	{
		console.printf("psp %d frame %d a: (%.2f %.2f %.2f) p: (%.2f %.2f) s: (%.2f %.2f) i: %d s: %s", 
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
	bool flipx, flipy;
	bool spritesLinked;
	int lastTickDiff;
	bool flipAnimX, flipAnimY;
	bool layered;
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
	
	ZSAnimationFrame EvaluateFrame(int layer, double ticksA, double ticksB)
	{
		let currNode = currentNode;
		let nextNode = EvaluateNextNode(ticksA, ticksB, true);
		//double tickPerc = tickDiff % 1.0;
		double tickPerc = ticksA%1.0;
		double margin = 0.01;
		bool dontEval = tickPerc <= margin || tickPerc >= 1.0-margin;
		//console.printf("a %f b %f tickperc %f margin %f eval: %d", ticksA, ticksB, tickPerc, margin, dontEval);
		if (dontEval)
		{
			let n = currNode;
			if (tickPerc >= 1-margin)
				n = nextNode;
				
			for (int i = 0; i < n.frames.Size(); i++)
			{
				let f = n.frames[i];
				if (f.pspId == layer)
				{
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
			ret.interpolate = frameA.interpolate;
			ret.sprite = frameA.sprite;
			ret.flipy = frameA.flipy;
			Vector3 rot = (0,0,0);
			Vector2 pos = (0,0);
			Vector2 sc = (0,0);
			//frameA.PrintFrameInfo();
			//frameB.PrintFrameInfo();
			
			rot.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.angles.x, frameB.angles.x, false);
			rot.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.angles.y, frameB.angles.y, false);
			rot.z = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.angles.z, frameB.angles.z, false);
			
			pos.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspOffsets.x, frameB.pspOffsets.x, false);
			pos.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspOffsets.y, frameB.pspOffsets.y, false);
			
			sc.x = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspScale.x, frameB.pspScale.x, false);
			sc.y = ZSAnimator.LinearMap(tickPerc, 0.0, 1.0, frameA.pspScale.y, frameB.pspScale.y, false);
			
			//console.printf("perc %f", tickPerc);
			//rot.X = ZSAnimator.LinearMap(
			
			ret.angles = rot;
			ret.pspOffsets = pos;
			ret.pspScale = sc;
		}
		return ret;
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
	
	//ZSAnimation currentAnimation;
	PlayerInfo ply;
	bool manual;
	bool forceDisableInterpolation;
	Array<ZSAnimation> currentAnimations;
	
	// This function can be used to start an animation directly and let ZSAnimator handle everything.
	void StartAnimation(PlayerInfo ply, Class<ZSAnimation> animationClass, int frame = 0, int endFrame = 0, double playbackSpeed = 1.0, bool manual = false, bool flipAnimX = false, bool flipAnimY = false)
	{
		playbackSpeed *= CVar.FindCVar("zsa_playbackSpeed").GetFloat();
		let anim = ZSAnimation(New(animationClass));
		anim.Initialize();
		anim.MakeFrameList();
		anim.LinkList();
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
		anim.flipAnimX = flipAnimX;
		anim.flipAnimY = flipAnimY;
		currentAnimations.Push(anim);
		
		console.printf("start anim %s, flip: %d %d", anim.GetClassName(), flipAnimX, flipAnimY);
		console.printf("layered %d", anim.layered);
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
								if (st.nextstate)
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
				if (psp.firstTic)
				{
					psp.x = 160.0;
					psp.y = 100.0;
					psp.oldx = xOffs;
					psp.oldy = yOffs;
				}
				psp.bInterpolate = !psp.firstTic && f.interpolate && !forceDisableInterpolation;
				
				if (anim.layered)
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
				
				if (anim.layered)
				{
					let sc = (psp.scale.x + f.pspScale.x, psp.scale.y + f.pspScale.y);
					psp.scale = sc;
					//psp.scale = (psp.scale.x + f.pspScale.x, psp.scale.y + f.pspScale.y);
					psp.rotation += f.angles.x;
				}
				else
				{
					if (psp.bflip)
					{
						f.pspScale = (abs(f.pspScale.x), abs(f.pspScale.y));
					}
					psp.scale = f.pspScale;
					psp.rotation = f.angles.x * (f.flipy ? -1 : 1) + (f.flipy ? 180.0 : 0.0);
				}
				
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
			
			if (anim.flipAnimX)
			{
				roll *= -1.0;
				ang *= -1.0;
			}
			
			if (anim.layered)
			{
				roll += ply.mo.viewroll;
				ang += ply.mo.viewangle;
				pit += ply.mo.viewpitch;
			}
			ply.mo.A_SetViewRoll(roll, SPF_INTERPOLATE);
			ply.mo.A_SetViewAngle(ang, SPF_INTERPOLATE);
			ply.mo.A_SetViewPitch(pit, SPF_INTERPOLATE);
			/*if (ply.ReadyWeapon)
				ply.ReadyWeapon.FOVScale = f.pspscale.x;*/
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
							console.printf("applying animation %d layer %d frame %d", i, j, f.frameNum);
							ApplyFrame(currentAnimation, f);
						}
					}
				}
			}
		}
		
		AdvanceAnimations();
	}
}