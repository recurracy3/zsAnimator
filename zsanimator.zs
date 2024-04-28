class ZSAnimationFrame
{
	int pspId;
	int frameNum;
	Vector3 angles;
	Vector2 pspOffsets;
	Vector2 pspScale;
	bool interpolate;
	
	static ZSAnimationFrame Create(int pspId, int frameNum, Vector3 angles, Vector2 pspOffsets, Vector2 pspScale, bool interpolate)
	{
		let frame = ZSAnimationFrame(New("ZSAnimationFrame"));
		frame.frameNum = frameNum;
		frame.pspId = pspId;
		frame.angles = angles;
		frame.pspOffsets = pspOffsets;
		frame.pspScale = pspScale;
		frame.interpolate = interpolate;
		return frame;
	}
}

class ZSAnimationFrameNode
{
	ZSAnimationFrameNode next;
	Array<ZSAnimationFrame> frames;
	
	static ZSAnimationFrameNode Create()
	{
		let node = ZSAnimationFrameNode(New("ZSAnimationFrameNode"));
		return node;
	}
}

Class ZSAnimation
{
	enum AnimFlags
	{
		ZSA_INTERPOLATE = 1 << 0
	}
	
	int frameCount;
	bool running;
	//ZSAnimationFrame previousFrame;
	//Weapon currentWeapon;
	Array<ZSAnimationFrame> frames;
	ZSAnimationFrameNode currentNode;
	
	virtual void MakeFrameList() { }
	virtual void Initialize() { }
	void LinkList()
	{
		//console.printf("linking list, %d frames", frameCount);
		currentNode = ZSAnimationFrameNode.Create();
		ZSAnimationFrameNode last = currentNode;
		//console.printf("base node %p", currentNode);
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
			last = n;
		}
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
	
	void StartAnimation(PlayerInfo ply, Class<ZSAnimation> animationClass, int frame = 0)
	{
		if (currentAnimation == NULL || currentAnimation.GetClass() != animationClass)
		{
			self.ply = ply;
			currentAnimation = ZSAnimation(New(animationClass));
			console.printf("starting animation %s", currentAnimation.GetClassName());
			currentAnimation.Initialize();
			currentAnimation.MakeFrameList();
			currentAnimation.LinkList();
			currentAnimation.running = true;
		}
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
				if (n)
				{
					console.printf("i %d", currentTicks);
					for (int i = 0; i < n.frames.size(); i++)
					{
						let f = n.frames[i];
						if (f.pspId != ZSAnimator.PlayerView)
						{
							/*if (f.pspId == PSP_WEAPON)
							{
								ply.mo.A_WeaponOffset(f.pspOffsets.x*-1, f.pspOffsets.y*-1 + WEAPONTOP, WOF_INTERPOLATE);
							}
							else
							{
								ply.mo.A_OverlayFlags(f.pspId, PSPF_ADDWEAPON, false);
								//ply.mo.A_OverlayFlags(f.pspId, PSPF_PIVOTPERCENT, true);
								ply.mo.A_OverlayOffset(f.pspId, f.pspOffsets.x*-1, f.pspOffsets.y*-1, WOF_INTERPOLATE);
							}*/
							//ply.mo.A_OverlayPivot(f.pspId, 0.5, 0.5);
							//ply.mo.A_OverlayRotate(f.pspId, f.pspAngle);
							
							let psp = ply.findpsprite(f.pspId);
							if (psp)
							{
								psp.bPivotPercent = true;
								let xOffs = f.pspOffsets.x*-1;
								let yOffs = f.pspOffsets.y*-1;
								if (f.pspId == PSP_WEAPON)
								{
									yOffs += WEAPONTOP;
								}
								psp.bInterpolate = false;//f.interpolate;
								
								psp.x = xOffs;
								psp.y = yOffs;
								if (!f.interpolate)
								{
									psp.oldx = psp.x;
									psp.oldy = psp.y;
								}
								psp.pivot = (0.5,0.5);
								psp.scale = f.pspScale;
								psp.rotation = f.angles.x;
								console.printf("rotation %f %f", f.angles.x, psp.rotation);
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
					currentAnimation.currentNode = n.next;
				}
			}
			currentTicks += 1;
		}
	}
}