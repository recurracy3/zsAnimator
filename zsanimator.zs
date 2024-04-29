class ZSAnimationFrame
{
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
}

Class ZSAnimation
{
	int frameCount;
	int framerate;
	bool running;
	//ZSAnimationFrame previousFrame;
	//Weapon currentWeapon;
	Array<ZSAnimationFrame> frames;
	ZSAnimationFrameNode currentNode;
	ZSAnimationFrameNode firstNode;
	ZSAnimationFrameNode lastNode;
	
	virtual void MakeFrameList() { }
	virtual void Initialize() { }
	void LinkList()
	{
		//console.printf("linking list, %d frames", frameCount);
		currentNode = ZSAnimationFrameNode.Create();
		ZSAnimationFrameNode last = currentNode;
		firstNode = currentNode;
		console.printf("base node %p", firstNode);
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
	
	void GotoNextFrame()
	{
		if (framerate >= 0.0)
			currentNode = currentNode.next;
		else
			currentNode = currentNode.prev;
	}
}

Class ZSAnimator : Thinker
{
	enum SpecialAnimNums
	{
		PlayerView = -5000,
		PSP_HANDS = 1001,
	}
	
	ZSAnimation currentAnimation;
	int currentTicks;
	PlayerInfo ply;
	double framerate;
	
	void StartAnimation(PlayerInfo ply, Class<ZSAnimation> animationClass, int frame = 0, double frameRate = 1.0)
	{
		if (currentAnimation == NULL || currentAnimation.GetClass() != animationClass)
		{
			self.ply = ply;
			currentAnimation = ZSAnimation(New(animationClass));
			currentAnimation.Initialize();
			currentAnimation.MakeFrameList();
			currentAnimation.LinkList();
			
			if (frameRate >= 0)
			{
				currentAnimation.currentNode = currentAnimation.firstNode;
			}
			else
			{
				currentAnimation.currentNode = currentAnimation.lastNode;
			}
			console.printf("base node %p", currentAnimation.currentNode);
			currentAnimation.running = true;
			currentAnimation.framerate = framerate;
			frameRate = 1.0;
		}
	}
	
	void GotoNextFrame()
	{
		currentAnimation.GotoNextFrame();
	}
	
	override void Tick()
	{
		super.Tick();
		if (currentAnimation)
		{
			if (currentTicks > currentAnimation.frameCount)
			{
				currentTicks = 0;
				currentAnimation.Destroy();
				currentAnimation = null;
				return;
			}
			else
			{
				let n = currentAnimation.currentNode;
				console.printf("node: %p", n);
				if (n)
				{
					// console.printf("i %d", currentTicks);
					for (int i = 0; i < n.frames.size(); i++)
					{
						let f = n.frames[i];
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
								
								psp.bInterpolate = f.interpolate;
								console.printf("frame %d psp %d interpolate %d", currentTicks, f.pspId, psp.bInterpolate);
								
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
					
					currentAnimation.GotoNextFrame();
				}
			}
			currentTicks += 1;
		}
	}
}