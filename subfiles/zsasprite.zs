class ZSAPSP
{
    enum corners
    {
        CORNER_TOPLEFT,
        CORNER_BOTTOMLEFT,
        CORNER_TOPRIGHT,
        CORNER_BOTTOMRIGHT
    }

    // The ID of this zsaPsp instance.
    int pspId;
    // The psprite this ZSAPSP instance wraps. For initialization this can be null but MUST be filled in by ZSAnimator on the first animation tic.
    PSprite psp;
    // The previous TRS matrix of this PSP, for interpolation.
    zsaGMMatrix4 prevTrsMatrix;
    // The current TRS matrix of this PSP.
    zsaGMMatrix4 trsMatrix;
    // This psp's parent. Can be null.
    ZSAPSP parent;
    // The children of this ZSAPSP.
    Array<ZSAPSP> children;
    // Pointer to the animator. Must not be null!
    ZSAnimator animator;

    // If true, if this ZSAPSP is destroyed, destroy all child ZSAPSPs as well.
    bool collapseOnDestroy;

    void ApplyTRSMatrix(zsaGMMatrix4 matrix)
    {
        
    }

    ZSAGMMatrix4 LocalTRSToViewportTRS()
    {
        return NULL;
    }

    ZSAGMMatrix4 GetTRSMatrixFromFrame(ZSAnimationFrame frame)
    {
        return NULL;
    }

    void ParentTo(ZSAPSP newParent, bool keepViewport = false)
    {
        self.parent = newParent;
        if (newParent.children.Find(self) != newParent.children.Size())
        {
            newParent.children.Push(self);
        }
    }

    void Unparent(bool keepViewport = false)
    {
        let myIndex = self.parent.children.Find(self);
        if (myIndex != self.parent.children.Size())
        {
            self.parent.children.Delete(myIndex);
        }
        self.parent = NULL;
    }

    void TransformCorners()
    {
        // if (!psp || !psp.curstate) { return; }
		// let texid = psp.curstate.GetSpriteTexture(0, spritenum: psp.sprite, framenum: psp.frame);
		// int w, h;
		// [w, h] = TexMan.GetSize(texid);
		// Vector2 sprsize = (w, h);
		// // Vector2 sprsize = TexMan.GetscaledSize(texid);
		
		// Vector3 corner0 = (-sprSize.x/2, -sprSize.y/2, 0);
		// Vector3 corner1 = (-sprSize.x/2, sprSize.y/2, 0);
		// Vector3 corner2 = (sprSize.x/2, -sprSize.y/2, 0);
		// Vector3 corner3 = (sprSize.x/2, sprSize.y/2, 0);
		// Vector3 vecSc = (f.pspScale.x, f.pspScale.y, 1);
		
		// Vector3 angs = (f.angles.x * ((anim.flags & ZSAnimator.LF_FLIPX == 0 ? -1 : 1)), f.angles.y, f.angles.z);
		// angs = ZSAnimator.ReorderEulerToGuta(angs);
		
		// // ORDER: Z Y X
		// let rotScMatrix = zsaGMMatrix4.CreateTRSEuler((0,0,0), angs.z, angs.y, angs.x, vecSc);
		
		// Vector3 v0 = rotScMatrix.multiplyVector3(corner0);
		// Vector3 v1 = rotScMatrix.multiplyVector3(corner1);
		// Vector3 v2 = rotScMatrix.multiplyVector3(corner2);
		// Vector3 v3 = rotScMatrix.multiplyVector3(corner3);
		
		// Vector3 diff0 = v0 - corner0;
		// Vector3 diff1 = v1 - corner1;
		// Vector3 diff2 = v2 - corner2;
		// Vector3 diff3 = v3 - corner3;
		// psp.coord0 = diff0.xy;
		// psp.coord1 = diff1.xy;
		// psp.coord2 = diff2.xy;
		// psp.coord3 = diff3.xy;
    }
}