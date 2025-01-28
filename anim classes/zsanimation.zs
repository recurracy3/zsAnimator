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
	bool flipAnimX, flipAnimY;
	bool layered; // deprecated, does nothing
	bool destroying;
	// DO NOT change this. It's done by ZSAnimator itself.
	bool filledIn;
	ZSAnimator currentAnimator;
	
	// It's possible for animations to fall 'inbetween' tics defined by Zdoom, aka the default tic rate of 35/s, thanks to the variable framerate.
	// When this happens we need to determine the positions, rotations and scale between the last frame and the current frame as a percentage.
	double currentTicks;
	
	virtual void MakeFrameList() { }
	virtual void Initialize() { }
	void LinkList()
	{
		foreach(frame : frames)
		{
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
	
	void FlipLayer(int pspId, bool flipx = false, bool flipy = false)
	{
		for (int i = 0; i < frames.size(); i++)
		{
			let f = frames[i];
			if (f.pspId == pspId)
			{
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
				if (!test)
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
				if (!test)
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
		
		ZSAnimationFrame frameA = currNode.frame;
		ZSAnimationFrame frameB = currNode.frame;
		ret.pspId = frameA.pspId;
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
		ret.sprite = frameA.sprite;
		ret.flipy = frameA.flipy;
		ret.flags = frameA.flags;
		
		Vector3 rot = (0,0,0);
		Vector2 pos = (0,0);
		Vector2 sc = (0,0);
		
		if ((frameA && frameB) && frameA != frameB)
		{	
			if ((frameA.flags & ZSAnimator.LF_Additive) != 0)
			{
				if ((frameA.flags & ZSAnimator.LF_AdditiveNoPSP) == 0)
				{
					let pspF = ZSAnimator.GetCurrentPspAsFrame(ply, layer);
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
		}
		else if (frameA == frameB)
		{
			rot = (frameA.angles.x, frameA.angles.y, frameA.angles.z);
			pos = (frameA.pspOffsets.x, frameA.pspOffsets.y);
			sc = (frameA.pspScale.x, frameA.pspScale.y);
		}
		
		ret.angles = rot;
		ret.pspOffsets = pos;
		ret.pspScale = sc;
		return ret;
	}
	
	void ReplacePspIds(int original, int replacement)
	{
		for (int i = 0; i < frames.Size(); i++)
		{
			let f = frames[i];
			if (f.pspId == original) {
				f.pspId = replacement;
			}
		}
		
		// Map<int, ZSAnimationFrameNode> temp;
		
		// MapIterator<int, ZSAnimationFrameNode> it;
		// it.Init(nodemap);
		
		// foreach(k, v : it)
		// {
			// let newK = k;
			// if (k == original)
			// {
				// newK = replacement;
			// }
			// console.printf("inserting into temp %d", newK);
			// temp.Insert(newK, v);
		// }
		// nodemap = temp;
	}
	
	void CopyFrames(int origPspId, int newPspId)
	{
		Array<ZSAnimationFrame> newFrames;
		for (int i = 0; i < frames.Size(); i++)
		{
			let f = frames[i];
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
	
	override void OnDestroy()
	{
		super.OnDestroy();
	}
}