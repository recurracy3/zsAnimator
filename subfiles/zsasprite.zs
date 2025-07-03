class ZSAPSP
{
    enum corners
    {
        CORNER_TOPLEFT,
        CORNER_BOTTOMLEFT,
        CORNER_TOPRIGHT,
        CORNER_BOTTOMRIGHT
    }

    int flags;
    // The ID of this zsaPsp instance.
    int pspId;
    // The psprite this ZSAPSP instance wraps. For initialization this can be null but MUST be filled in by ZSAnimator directly after.
    PSprite psp;
    // The current TRS matrix of this PSP.
    zsaGMMatrix4 trsMatrix;
    // This psp's parent. Can be null.
    int parentPspId;
    ZSAPSP parent;
    // The children of this ZSAPSP.
    Array<ZSAPSP> children;
    // Pointer to the animator. Must not be null!
    ZSAnimator animator;

    Vector3 localOffs;
    Vector3 localAngs;
    Vector3 localScale;
    // If true, if this ZSAPSP is destroyed, destroy all child ZSAPSPs as well.
    bool collapseOnDestroy;

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
        ApplyTRSMatrix(viewTrs);
    }

    play void ApplyTRSMatrix(zsaGMMatrix4 matrix)
    {
        Vector3 t = (matrix.values[0][3], matrix.values[1][3], 0);
        ApplyTranslation(t);

        if (!psp)
        {
            return;
        }

        let a = matrix.rotationToEulerAngles();
        psp.rotation = a;

        let sc = ZSanimator.GetScaleFromMatrix(matrix.Transpose());
        psp.scale.x = sc.x;
        psp.scale.y = sc.y;
    }

    play void ApplyTranslation(Vector3 t)
    {
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

    ZSAGMMatrix4 LocalTRSToViewportTRS()
    {
        let angs = self.localAngs;//ZSAnimator.ReorderEulerToGuta(self.localAngs);
        ZSAGMMatrix4 ret = zsaGMMatrix4.CreateTRSEuler((localOffs.x, localOffs.y, 0), angs.x, angs.y, angs.z, (localScale.x, localScale.y, 1));
        if (parent)
        {
            let parentMatrix = parent.LocalTRSToViewportTRS();
            ret = parentMatrix.multiplyMatrix(ret);
        }
        return ret;
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

    void SetTRS(Vector3 t, Vector3 r, Vector3 s)
    {
        self.localOffs = t;
        self.localAngs = r;
        self.localScale = s;
    }

    void SetFlags(int flags, bool set = true)
    {
        if (set)
        {
            self.flags |= flags;
        }
        else
        {
            self.flags &= ~flags;
        }
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