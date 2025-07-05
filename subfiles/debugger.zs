class ZSAnimatorDebugger : EventHandler
{
    Font confont;
    Vector2 canvasSize;
    ZSAnimator animator;

    override void OnRegister()
    {
        confont = Font.GetFont("CONFONT");
        canvasSize = (1280, 720);
    }

    static ZSAnimatorDebugger Fetch()
    {
        return ZSAnimatorDebugger(EventHandler.Find("ZSAnimatorDebugger"));
    }

    void SetAnimator(ZSAnimator animator)
    {
        self.animator = animator;
    }

	override void RenderOverlay(RenderEvent e)
	{
        let ply = players[consoleplayer];
        DrawZSAnimator(ply);
	}

    clearscope Vector2 GetScreenDimensions()
    {
        return (Screen.GetWidth(), Screen.GetHeight());
    }

    // xy size, xy scale
    clearscope Vector2, Vector2 GetCanvasSize()
    {
        Vector2 size, scale;
        Vector2 scrSz = GetScreenDimensions();
        size = canvasSize;
        scale = (scrSz.x/size.x,scrSz.y/size.y);
        return size, scale;
    }

    clearscope void BreakString(string txt, out Array<string> lines, out float szx, out float szy)
    {
        let [csz, csc] = GetCanvasSize();
        szx = confont.StringWidth(txt);
        int height = confont.GetHeight();
        txt.Split(lines, "\n");
        int numLines = lines.Size();
        szy = height * numLines;

        szx *= csc.x;
        szy *= csc.y;
    }

    ui void DrawText(string txt, Vector2 pos, out float txtSizeX, out float txtSizeY)
    {
        Array<string> lines;
        BreakString(txt, lines, txtSizeX, txtSizeY);
        let [sz, sc] = GetCanvasSize();
        Screen.DrawText(confont, Font.CR_WHITE, pos.x, pos.y, txt, DTA_SCALEX, sc.x, DTA_SCALEY, sc.y);
    }

    ui void DrawZSAPSP(PlayerInfo ply, int key, ZSAPSP zpsp, out float posx, out float posy)
    {
        Vector2 origPos = (posx, posy);
        string txt = String.Format("k %d\n", key);
        txt = txt .. String.Format("t (%.1f %.1f %.1f)\n", zpsp.localOffs.x, zpsp.localoffs.y, zpsp.localOffs.z);
        txt = txt .. String.Format("r (%.1f %.1f %.1f)\n", zpsp.localAngs.x, zpsp.localAngs.y, zpsp.localAngs.z);
        txt = txt .. String.Format("s (%.1f %.1f %.1f)\n", zpsp.localScale.x, zpsp.localScale.y, zpsp.localScale.z);
        if (!zpsp.psp)
        {
            txt = txt .. "no psp";
        }

        float szx, szy;
        DrawText(txt, (posx, posy), szx, szy);
        posy += szy;

        if (zpsp.psp && !zpsp.psp.bDestroyed && zpsp.psp.caller && zpsp.psp.curstate)
        {
            let [canvasSize, canvasScale] = GetCanvasSize();
            let texid = zpsp.psp.curstate.GetSpriteTexture(0, spritenum: zpsp.psp.sprite, framenum: zpsp.psp.frame);
            float w,h;
            [w,h] = TexMan.GetSize(texid);

            Vector2 boxSize = (40.0*canvasScale.X, 40.0*canvasScale.Y);
            Vector2 scl = (w/boxSize.x, h/boxSize.y);
            Vector2 sprPos = (origPos.x + szx + boxSize.x, origPos.y + (szy/2));

            Screen.DrawTexture(texid, false, sprPos.x, sprPos.y, DTA_DestWidthF, boxSize.x, DTA_DestHeightF, boxSize.y);
        }
    }

    ui void DrawFrame(PlayerInfo ply, ZSAnimationFrame frame, out float posx, out float posy)
    {
        string txt = String.Format("a (%.1f, %.1f, %.1f) ", frame.angles.x, frame.angles.y, frame.angles.z);
        txt = txt .. String.Format("p (%.1f, %.1f, %.1f) ", frame.pspOffsets.x, frame.pspOffsets.y, frame.pspOffsets.z);
        txt = txt .. String.Format("s (%.3f, %.3f)", frame.pspScale.x, frame.pspScale.y);
        if (frame.interpolate)
        {
            txt = txt .. "\ninterpolated";
        }
        if (frame.reference)
        {
            txt = txt .. string.format("\nref %s", frame.reference);
        }

        float szx, szy;
        DrawText(txt, (posx, posy), szx, szy);
        posy += szy;
    }

    ui void DrawNode(PlayerInfo ply, int key, ZSAnimationFrameNode node, out float posx, out float posy)
    {
        string txt = String.Format("%d %p %p %p", key, node.prev, node, node.next);
        float szx, szy;
        DrawText(txt, (posx, posy), szx, szy);
        posy += szy;

        let framePos = (posx + 32, posy);
        DrawFrame(ply, node.frame, framePos.x, framePos.y);
        posy = framePos.y;
    }

    ui void DrawAnimation(PlayerInfo ply, ZSAnimation animation, out float posx, out float posy)
    {
        string txt = "";
        txt = txt .. String.Format("anim %s\n", animation.GetClassName());
        txt = txt .. String.format("ticks %.2f \ frames %d\n", animation.currentTicks, animation.frameCount);
        float szx, szy;
        DrawText(txt, (posx, posy), szx, szy);
        posy += szy;

        let nodepos = (posx + 32, posy+16);
        DrawText(String.Format("%d nodes", animation.currentNodes.CountUsed()), nodepos, szx, szy);
        nodepos.y += szy;
        foreach(k, v : animation.currentNodes)
        {
            DrawNode(ply, k, v, nodepos.x, nodepos.y);
        }
        posy = nodepos.y;
    }

    ui void DrawZSAnimator(PlayerInfo ply)
    {
        if (!Cvar.GetCVar("zsa_debug", ply).GetBool())
        {
            return;
        }

        if (!animator)
        {
            float dmy;
            DrawText("No animator", (16, 64), dmy, dmy);
            return;
        }

        
		string txt = String.Format("current anims: %d", animator.currentAnimations.Size());

        let pos = (16, 64);
        float szx, szy;
        DrawText(txt, pos, szx, szy);

        pos.y += szy;
        let animPos = (pos.x + 32, pos.y+16);

        for (int i = 0; i < animator.currentAnimations.Size(); i++)
        {
            let anim = animator.currentAnimations[i];
            DrawText(String.Format("%d", i), animPos, szx, szy);
            animPos.y += szy;
            if (!anim || anim.bDestroyed)
            {
                continue;
            }

            DrawAnimation(ply, anim, animPos.x, animPos.y);
        }

        let [canvasSize, canvasScale] = GetCanvasSize();
        let zsapPos = ((canvasSize.x/2)*canvasScale.x, 64);
        int cnt = animator.zsaPspDict.CountUsed();
        DrawText(String.Format("zsapsp count: %d", cnt), zsapPos, szx, szy);
        zsapPos.y += szy;
        foreach(k, v : animator.zsaPspDict)
        {
            if (v && !v.bDestroyed)
            {
                DrawZSAPSP(ply, k, v, zsapPos.x, zsapPos.y);
            }
        }
    }
}