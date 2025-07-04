    // ZSAnimator: A ZScript animation framework, allowing you to make first-person animations in blender usable in GZDoom.
    // Copyright (C) 2025 Recurracy

    // This program is free software: you can redistribute it and/or modify
    // it under the terms of the GNU General Public License as published by
    // the Free Software Foundation, either version 3 of the License, or
    // (at your option) any later version.

    // This program is distributed in the hope that it will be useful,
    // but WITHOUT ANY WARRANTY; without even the implied warranty of
    // MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    // GNU General Public License for more details.

    // You should have received a copy of the GNU General Public License
    // along with this program.  If not, see https://www.gnu.org/licenses.

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

    // The ID of this zsaPsp instance.
    int pspId;
    // The psprite this ZSAPSP instance wraps. For initialization this can be null but MUST be filled in by ZSAnimator directly after.
    PSprite psp;
    // Store Viewport TRS matrices.
    zsaGMMatrix4 trsMatrix, prevTRSMatrix;
    int parentPspId;
    // This psp's parent. Can be null.
    ZSAPSP parent;
    // The children of this ZSAPSP.
    Array<ZSAPSP> children;
    // Pointer to the animator. Must not be null!
    ZSAnimator animator;

    // Local transform information. I should probably figure out a way to determine the order these are stored in.
    // Reason for that is because in Blender animations are stored as -X, Y, Z. That's not always desirable.
    Vector3 localOffs, localAngs, localScale;
    // Previous transform information.
    Vector3 prevOffs, prevAngs, prevScale;

    // If true the result of the TRS matrix gets *added* to the PSP instead of hard-setting it.
    // Big fucking can of worms and I'm not sure if I can get it working right. We'll see.
    // TODO
    bool isAdditive;

    // If the psp is destroyed destroy all children as well if this is true.
    bool destroyCascade;

    static ZSAPsp GetFromPSP(PSprite psp, ZSAnimator animator)
    {
        let zsaPsp = animator.zsaPspDict.GetIfExists(psp.id);
        return zsaPsp;
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
    // and skewing its corners depending on the sprite's size.
    // This does not adjust the actual .rotation and .scale of the psprite.
    virtual play void ApplyToPSP()
    {
        self.prevOffs = self.localOffs;
        self.prevAngs = self.localAngs;
        self.prevScale = self.localScale;

        self.psp.bPivotPercent = true;
        self.psp.bAddWeapon = false;
		self.psp.pivot = (0.5,0.5);
        let viewTrs = LocalTRSToViewportTRS();
        self.trsMatrix = viewTrs;

        // !firstTic makes all transformations done, including Coord0-3, interpolate.
        // Setting it to true makes it not interpolate.
        // I think.
        if (!self.psp.bInterpolate && !self.psp.firstTic)
        {
            console.printf("setting firsttic for %d", pspId);
            self.psp.firstTic = true;
        }

        ApplyTRSMatrix(viewTrs);
    }

    virtual play void SetInterpolation(bool interp)
    {
        console.printf("%d set interp %d firsttic %d", pspId, interp);
        self.psp.bInterpolate = interp;
        if (!self.psp.bInterpolate && !self.psp.FirstTic)
        {
            console.printf("making firsstic true for %d", pspId);
            self.psp.FirstTic = true;
        }
    }

    // Fully applies a TRS matrix to the PSprite.
    virtual play void ApplyTRSMatrix(zsaGMMatrix4 matrix)
    {
        Vector3 t = (matrix.values[0][3], matrix.values[1][3], 0);
        ApplyTranslation(t);
        TransformCorners(matrix);
    }

    // Transform the corners of the psprite. This allows you to skew a sprite if desired, seperately of 
    // the psprite's own rotation and scale.
    virtual play void TransformCorners(zsaGMMatrix4 matrix)
    {
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
    virtual play void ApplyTranslation(Vector3 t)
    {
        // Todo: Take out the flipx handling and similar stuff and move it to the ZSAnimation pipeline, as it's related to the Blender plugin.
        // bool flipx = flags & ZSAnimator.LF_FLIPX != 0;
        // float x, y;

        // if (!(flags & ZSAnimator.LF_DontCenterPSP == ZSAnimator.LF_DontCenterPSP))
        // {
        //     x = t.x - 160.0;
        //     y = t.y - 100.0;
        // }
        // else
        // {
        //     x = t.x;
        //     y = t.y + (psp.id == PSP_WEAPON ? WEAPONTOP : 0);
        // }

        // x = x * (flipx ? 1:-1);
        // y = y * -1;

        self.psp.x = t.x;
        self.psp.y = t.y;

        // psp.bInterpolate = !psp.firstTic;

        // Immediately set the oldx and y if interpolation is disabled otherwise it will still interpolate and we don't want that in this case.
        if (psp.firstTic)
        {
            psp.bInterpolate = false;
        }
        console.printf("binterp: %d firsttic: %d", psp.bInterpolate, psp.firstTic);
        if (!psp.bInterpolate || psp.firstTic)
        {
            console.printf("setting old");
            self.psp.oldx = psp.x;
            self.psp.oldy = psp.y;
        }
    }

    // Convert the local offsets into a viewport TRS.
    // This includes multiplying the local TRS by the parents' local TRS recursively, if the depth arg is > -1 (-1 by default)
    // Returns a full TRS matrix that can be applied to the viewport.
    virtual clearscope ZSAGMMatrix4 LocalTRSToViewportTRS(int depth = -1)
    {
        // Todo: applying a perspective matrix, perhaps? Might be interesting.
        // This would require the Z part of localOffs to not be omitted.
        let angs = self.localAngs;
        ZSAGMMatrix4 ret = zsaGMMatrix4.CreateTRSEuler((localOffs.x, localOffs.y, 0), angs.x, angs.y, angs.z, (localScale.x, localScale.y, 1));
        if (parent && depth > 0)
        {
            let parentMatrix = parent.LocalTRSToViewportTRS(depth-1);
            ret = parentMatrix.multiplyMatrix(ret);
        }
        return ret;
    }

    // Parent this ZSAPSP to a new PSP.
    // Todo: make keepViewport convert the viewport transform
    // into local transform... Somehow.
    virtual void ParentTo(ZSAPSP newParent, bool keepViewport = false)
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
    virtual void Unparent(bool keepViewport = false)
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
    virtual void SetTRS(Vector3 t, Vector3 r, Vector3 s)
    {
        self.localOffs = t;
        self.localAngs = r;
        self.localScale = s;
    }

    override void OnDestroy()
    {
        console.printf("destroying %d", pspid);
        if (destroyCascade)
        {
            foreach(c : children)
            {
                if (!c.bDestroyed)
                {
                    c.Destroy();
                }
            }
        }
        super.OnDestroy();
    }
}