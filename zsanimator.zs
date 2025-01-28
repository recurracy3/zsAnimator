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
	Vector2 pspOffsets;
	Vector2 pspScale;
	bool interpolate;
	bool flipx;
	bool flipy;
	string sprite;
	bool followWeapon;
	// ZSAnimationFrameNode node;
	
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
	
	ZSAnimationFrame Clone()
	{
		ZSAnimationFrame f = New("ZSAnimationFrame");
		f.pspId = self.pspId;
		f.frameNum = self.frameNum;
		f.angles = self.angles;
		f.pspOffsets = self.pspOffsets;
		f.pspScale = self.pspScale;
		f.interpolate = self.interpolate;
		f.flipx = self.flipx;
		f.flipy = self.flipy;
		f.flags = self.flags;
		return f;
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
		LF_DontCenterPSP = 1 << 2, // When set, the PSPrite will not be centered automatically.
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
		playbackSpeed *= CVar.FindCVar("zsa_playbackSpeed").GetFloat();
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
				psp.bAddWeapon = f.followWeapon;
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
				
				if (f.flipy || anim.flipAnimX)
				{
					psp.bflip = true;
				}
				else
				{
					psp.bflip = false;
				}
				psp.pivot = (0.5,0.5);
				
				Vector2 sc;
				Double ang;
				if ((f.flags & ZSAnimator.LF_ADDITIVE) != 0)
				{
					sc = (psp.scale.x + f.pspScale.x, psp.scale.y + f.pspScale.y);
					ang = psp.rotation + f.angles.x;
				}
				else
				{
					if (psp.bflip)
					{
						f.pspScale = (abs(f.pspScale.x), abs(f.pspScale.y));
					}
					sc = f.pspScale;
					ang = f.angles.x * (f.flipy ? -1 : 1) + (f.flipy ? 180.0 : 0.0);
				}
				
				SetPSPScale(psp, sc);
				SetPSPRotation(psp, ang);
				
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
		psp.SetState(caller.ResolveState(lb));
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