class ZSAPSP
{
    enum corners
    {
        CORNER_TOPLEFT,
        CORNER_BOTTOMLEFT,
        CORNER_TOPRIGHT,
        CORNER_BOTTOMRIGHT
    }

    PSprite psp;
    zsaGMMatrix4 prevTrsMatrix;
    zsaGMMatrix4 trsMatrix;
    ZSAPSP parent;
    Array<ZSAPSP> children;
    ZSAnimator animator;

    void ApplyTRSMatrix(zsaGMMatrix4 matrix)
    {

    }

    ZSAGMMatrix4 LocalTRSToGlobalTRS()
    {
        
    }

    ZSAGMMatrix4 GetTRSMatrixFromFrame(ZSAnimationFrame frame)
    {
        
    }

    void ParentTo(ZSAPSP newParent, bool keepGlobal = false)
    {

    }

    void TransformCorners()
    {
        
    }
}