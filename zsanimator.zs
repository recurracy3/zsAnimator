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
	
	static ZSAnimationFrame Create(int pspId, int frameNum, Vector3 angles, Vector2 pspOffsets, Vector2 pspScale, bool interpolate)
	{
		let frame = ZSAnimationFrame(New("ZSAnimationFrame"));
		frame.frameNum = frameNum;
		frame.pspId = pspId;
		frame.angles = angles;
		frame.pspOffsets = pspOffsets;
		frame.pspScale = pspScale;
		if (frame.pspScale.x < 0)
		{
			frame.flipx = true;
		}
		if (frame.pspScale.y < 0)
		{
			frame.flipy = true;
		}
		
		frame.pspScale = (abs(frame.pspScale.X), abs(frame.pspScale.Y));
		frame.interpolate = interpolate;
		return frame;
	}
	
	void PrintFrameInfo()
	{
		console.printf("psp %d frame %d a: (%.2f %.2f %.2f) p: (%.2f %.2f) s: (%.2f %.2f) i: %d", pspId, frameNum, angles.x, angles.y, angles.z, pspOffsets.x, pspOffsets.y, pspScale.x, pspScale.y, interpolate);
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
		/*int ticks = currentTicks;
		currentTicks += playbackSpeed;
		int diff = int(currentTicks) - ticks;
		for (int i = 0; i < diff; i++)
		{
			if (framerate >= 0.0)
			{
				if (currentNode.next)
					currentNode = currentNode.next;
			}
			else
			{
				if (currentNode.prev)
					currentNode = currentNode.prev;
			}
		}
			
		return currentNode != NULL;*/
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
			if (tickPerc >= 0.99)
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
	
	ZSAnimation currentAnimation;
	PlayerInfo ply;
	bool manual;
	bool forceDisableInterpolation;
	
	// This function can be used to start an animation directly and let ZSAnimator handle everything.
	void StartAnimation(PlayerInfo ply, Class<ZSAnimation> animationClass, int frame = 0, double playbackSpeed = 1.0, bool manual = false)
	{
		playbackSpeed *= CVar.FindCVar("zsa_playbackSpeed").GetFloat();
		if (currentAnimation == NULL || currentAnimation.GetClass() != animationClass)
		{
			self.ply = ply;
			currentAnimation = ZSAnimation(New(animationClass));
			console.printf("start anim %s", currentAnimation.GetClassName());
			currentAnimation.Initialize();
			currentAnimation.MakeFrameList();
			currentAnimation.LinkList();
			
			if (playbackSpeed >= 0)
			{
				currentAnimation.currentNode = currentAnimation.firstNode;
			}
			else
			{
				currentAnimation.currentNode = currentAnimation.lastNode;
			}
			currentAnimation.running = true;
			currentAnimation.playbackSpeed = playbackSpeed;
		}
	}
	
	void GotoNextFrame()
	{
		currentAnimation.AdvanceAnimation();
	}
	
	void ApplyFrame(ZSAnimationFrame f)
	{
		//let f = n.frames[i];
		//currentAnimation.EvaluateFrame(n.frames[i].pspId, currentAnimation.currentTicks, currentAnimation.currentTicks + currentAnimation.playbackSpeed);
		if (f.pspId != ZSAnimator.PlayerView)
		{
			let psp = ply.findpsprite(f.pspId);
			if (psp)
			{
				psp.bPivotPercent = true;
				let xOffs = f.pspOffsets.x*-1 + 160.0;
				let yOffs = f.pspOffsets.y*-1 + 100.0;//-WEAPONTOP;
				// if (f.pspId == PSP_WEAPON)
				// {
					// yOffs += WEAPONTOP;
				// }
				if (!psp.bAddWeapon)
				{
					yOffs += WEAPONTOP/1.2;
					yOffs /= 1.2;
				}
				
				psp.bInterpolate = f.interpolate && !forceDisableInterpolation;
				
				psp.x = xOffs;
				psp.y = yOffs;
				if (!psp.bInterpolate)
				{
					psp.oldx = psp.x;
					psp.oldy = psp.y;
				}
				
				if (f.flipy)
				{
					psp.bflip = true;
				}
				psp.pivot = (0.5,0.5);
				psp.scale = f.pspScale;
				psp.rotation = f.angles.x * (f.flipy ? -1 : 1) + (f.flipy ? 180.0 : 0.0);
				// console.printf("layer %d rotation %f %f", f.pspId, f.angles.x, psp.rotation);
			}
		}
		else
		{
			float viewScale = CVar.FindCVar('zsa_viewscale').GetFloat();
			ply.mo.A_SetViewRoll(f.angles.x * viewScale, SPF_INTERPOLATE);
			ply.mo.A_SetViewAngle(f.angles.y * viewScale, SPF_INTERPOLATE);
			ply.mo.A_SetViewPitch(f.angles.z * viewScale, SPF_INTERPOLATE);
			ply.ReadyWeapon.FOVScale = f.pspscale.x;
		}
	}
	
	override void Tick()
	{
		super.Tick();
		
		if (currentAnimation)
		{
			if (currentAnimation.currentTicks > currentAnimation.frameCount)
			{
				currentAnimation.Destroy();
				currentAnimation = null;
				return; 
			}
		}
		
		if (manual) { return; }
		if (currentAnimation)
		{
			// TODO: Rework this to allow multiple layered animations at once.
			if (currentAnimation.currentTicks > currentAnimation.frameCount)
			{
				currentAnimation.Destroy();
				currentAnimation = null;
				return;
			}
			else
			{
				let n = currentAnimation.currentNode;
				console.printf("ticks %f", currentAnimation.currentTicks);
				if (n)
				{
					// console.printf("i %d", currentTicks);
					for (int i = 0; i < n.frames.size(); i++)
					{
						//let f = n.frames[i];
						let f = currentAnimation.EvaluateFrame(n.frames[i].pspId, currentAnimation.currentTicks, currentAnimation.currentTicks + currentAnimation.playbackSpeed);
						ApplyFrame(f);
					}
					
					currentAnimation.AdvanceAnimation();
				}
			}
		}
	}
}