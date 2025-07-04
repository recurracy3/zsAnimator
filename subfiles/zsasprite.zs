// This class is a wrapper that allows you to retain a full TRS matrix in order to skew a sprite with Gutamatics' matrix functions.
// It's not a Thinker so it doesn't do any logic for you, you can either do that in ZSAnimator or your own classes.
class ZSAPSP
{
    enum corners
    {
        CORNER_TOPLEFT,
        CORNER_BOTTOMLEFT,
        CORNER_TOPRIGHT,
        CORNER_BOTTOMRIGHT
    }

    // Todo: Remove this from ZSAPSP, this should not be here, should be done in ZSAnimationFrame instead.
    int zsaLayerFlags;
    // The ID of this zsaPsp instance.
    int pspId;
    // The psprite this ZSAPSP instance wraps. For initialization this can be null but MUST be filled in by ZSAnimator directly after.
    PSprite psp;
    // The current Viewport TRS matrix of this PSP.
    zsaGMMatrix4 trsMatrix;
    int parentPspId;
    // This psp's parent. Can be null.
    ZSAPSP parent;
    // The children of this ZSAPSP.
    Array<ZSAPSP> children;
    // Pointer to the animator. Must not be null!
    ZSAnimator animator;

    // Local transform information. I should probably figure out a way to determine the order these are stored in.
    Vector3 localOffs;
    Vector3 localAngs;
    Vector3 localScale;
    // If true, if this ZSAPSP is destroyed through any means, destroy all child ZSAPSPs as well.
    bool collapseOnDestroy;

    // If the psp is destroyed by any means destroy this ZSAPSP as well.
    bool destroyIfPSPDestroyed;

    static ZSAPsp GetFromPSP(PSprite psp, ZSAnimator animator)
    {
        let zsaPsp = animator.GetifExists(pspId)
    }

    // Extract the scale portion of a gutamatics matrix. This does lose the signedness.
    static clearscope Vector3 GetScaleFromMatrix(zsagmmatrix4 matrix)
	{
		matrix = matrix.transpose();
		float x = (matrix.values[0][0], matrix.values[1][0], matrix.values[2][0]).length();
		float y = (matrix.values[0][1], matrix.values[1][1], matrix.values[2][1]).length();
		float z = (matrix.values[0][2], matrix.values[1][2], matrix.values[2][2]).length();
		return (x, y, z);
	}


    // This function applies the ZSAPSP fully to the psprite.
    // Does everything for you. Is called automatically by ZSAnimator through the StartAnimation pipeline.
    // This means setting the position of the Psprite,
    // and skewing its corners depending on its size.
    // This does not adjust the actual .rotation and .scale of the psprite.
    play void ApplyToPSP()
    {
        if (!psp)
        {
            return;
        }

        self.psp.bPivotPercent = true;
        self.psp.bAddWeapon = false;
		self.psp.pivot = (0.5,0.5);
        let viewTrs = LocalTRSToViewportTRS();
        self.trsMatrix = viewTrs;
        ApplyTRSMatrix(viewTrs);
    }

    // Fully applies a TRS matrix to the PSprite.
    play void ApplyTRSMatrix(zsaGMMatrix4 matrix)
    {
        Vector3 t = (matrix.values[0][3], matrix.values[1][3], 0);
        ApplyTranslation(t);
        TransformCorners(matrix);
    }

    // Transform the corners of the psprite. This allows you to skew a sprite if desired, seperately of 
    // the psprite's own rotation and scale.
    play void TransformCorners(zsaGMMatrix4 matrix)
    {
		if (!psp || !psp.curstate) { return; }
		let texid = psp.curstate.GetSpriteTexture(0, spritenum: psp.sprite, framenum: psp.frame);
		int w, h;
		[w, h] = TexMan.GetSize(texid);
		Vector2 sprsize = (w, h);
		
		Vector3 corner0 = (-sprSize.x/2, -sprSize.y/2, 0);
		Vector3 corner1 = (-sprSize.x/2, sprSize.y/2, 0);
		Vector3 corner2 = (sprSize.x/2, -sprSize.y/2, 0);
		Vector3 corner3 = (sprSize.x/2, sprSize.y/2, 0);

        for (int i = 0; i < 3; i++)
        {
            // Remove the translation portion here as it's (assumedly) done by ApplyTRSMatrix already.
            matrix.values[i][3] = 0;
        }
		
		Vector3 v0 = matrix.multiplyVector3(corner0);
		Vector3 v1 = matrix.multiplyVector3(corner1);
		Vector3 v2 = matrix.multiplyVector3(corner2);
		Vector3 v3 = matrix.multiplyVector3(corner3);
		
		Vector3 diff0 = v0 - corner0;
		Vector3 diff1 = v1 - corner1;
		Vector3 diff2 = v2 - corner2;
		Vector3 diff3 = v3 - corner3;
        // Rather naive attempt at ortho projection by just omitting the Z part of the translation entirely.
		psp.coord0 = diff0.xy;
		psp.coord1 = diff1.xy;
		psp.coord2 = diff2.xy;
		psp.coord3 = diff3.xy;
	}

    // Applies a translation to the PSP.
    // Mind you 'translation' in this case DOES NOT MEAN 'translation' in GZDoom terms, which is related to recoloring.
    play void ApplyTranslation(Vector3 t)
    {
        // Todo: Take out the flipx handling and similar stuff and move it to the ZSAnimation pipeline.
        if (!psp)
        {
            return;
        }

        bool flipx = flags & ZSAnimator.LF_FLIPX != 0;
        float x, y;

        if (!(flags & ZSAnimator.LF_DontCenterPSP == ZSAnimator.LF_DontCenterPSP))
        {
            x = t.x - 160.0;
            y = t.y - 100.0;
        }
        else
        {
            x = t.x;
            y = t.y + (psp.id == PSP_WEAPON ? WEAPONTOP : 0);
        }

        x = x * (flipx ? 1:-1);
        y = y * -1;

        self.psp.x = x;
        self.psp.y = y;

        psp.bInterpolate = !psp.firstTic;

        if (!psp.bInterpolate)
        {
            self.psp.oldx = psp.x;
            self.psp.oldy = psp.y;
        }
    }

    // Convert the local offsets into a viewport TRS.
    // This includes multiplying the local TRS by the parents' local TRS recursively.
    clearscope ZSAGMMatrix4 LocalTRSToViewportTRS()
    {
        // Todo: applying a perspective matrix, perhaps? Might be interesting.
        // This would require the Z part of localOffs to not be omitted.
        let angs = self.localAngs;
        ZSAGMMatrix4 ret = zsaGMMatrix4.CreateTRSEuler((localOffs.x, localOffs.y, 0), angs.x, angs.y, angs.z, (localScale.x, localScale.y, 1));
        if (parent)
        {
            let parentMatrix = parent.LocalTRSToViewportTRS();
            ret = parentMatrix.multiplyMatrix(ret);
        }
        return ret;
    }

    // Parent this ZSAPSP to a new PSP.
    // Todo: make keepViewport convert the viewport transform
    // into local transform... Somehow.
    void ParentTo(ZSAPSP newParent, bool keepViewport = false)
    {
        self.parent = newParent;
        if (newParent.children.Find(self) != newParent.children.Size())
        {
            newParent.children.Push(self);
        }
    }

    // Unparent this ZSAPSP.
    // Todo: make keepViewport retain the viewport transform
    // when unparenting... somehow...
    void Unparent(bool keepViewport = false)
    {
        let myIndex = self.parent.children.Find(self);
        if (myIndex != self.parent.children.Size())
        {
            self.parent.children.Delete(myIndex);
        }
        self.parent = NULL;
    }

    // Set the translation, rotation and scaling of this PSP.
    // Pretty much a wrapper function that allows you to do it all in one go.
    void SetTRS(Vector3 t, Vector3 r, Vector3 s)
    {
        self.localOffs = t;
        self.localAngs = r;
        self.localScale = s;
    }

    // Todo: Replace this with something more coherent, layer flags should not be handled by the ZSAPSP, honestly.
    // Perhaps move this to ZSAnimationFrame.
    void SetZSALayerFlags(int flags, bool set = true)
    {
        if (set)
        {
            self.zsaLayerFlags |= flags;
        }
        else
        {
            self.zsaLayerFlags &= ~flags;
        }
    }
}