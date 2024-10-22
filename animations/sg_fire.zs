class ZSAnimationShotgunFire : ZSAnimation {
	override void Initialize() {
		frameCount = 41; 
		filledIn = False;	}
	override void MakeFrameList() {
	frames.Push(ZSAnimationFrame.Create(ZSAnimator.PlayerView, 0, (0.0, 0.0, 0.0), (0.0, 0.0), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(PSP_FLASH, 0, (0.0, 0.0, 0.0), (2.056572675704956, -47.39257049560547), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 0, (0.0, 0.0, 0.0), (5.283334255218506, -77.53437805175781), (1.1270842552185059, 1.1270841360092163), True));
	frames.Push(ZSAnimationFrame.Create(PSP_FLASH, 1, (0.0, 0.0, 0.0), (1.316206693649292, -51.876895904541016), (1.5696182250976562, 1.5696182250976562), True));
	frames.Push(ZSAnimationFrame.Create(ZSAnimator.PlayerView, 2, (0.0, 0.0, -1.02578604221344), (0.0, 0.0), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 2, (0.0, 0.0, 0.0), (5.283334732055664, -97.54574584960938), (1.4901819229125977, 1.4901820421218872), True));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 5, (0.0, 0.0, 0.0), (5.283334732055664, -80.56710815429688), (1.2801039218902588, 1.2801040410995483), True));
	frames.Push(ZSAnimationFrame.Create(ZSAnimator.PlayerView, 9, (0.0, 0.0, 0.0), (0.0, 0.0), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 9, (0.0, 0.0, 0.0), (5.283334255218506, -79.67664337158203), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 10, (-9.526158332824707, 0.0, 0.0), (19.165199279785156, -107.314697265625), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 14, (1.8153389692306519, 0.0, 0.0), (41.99315643310547, -50.86177444458008), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(ZSAnimator.PlayerView, 19, (0.8486192226409912, 0.35824352502822876, -0.598082423210144), (0.0, 0.0), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 19, (8.987022399902344, 0.0, 0.0), (78.05337524414062, -37.63288116455078), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(ZSAnimator.PlayerView, 22, (0.8539120554924011, 0.3454371392726898, 0.263813316822052), (0.0, 0.0), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 22, (0.8936195969581604, 0.0, 0.0), (89.56309509277344, -58.47284698486328), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 24, (-2.911996841430664, 0.0, 0.0), (71.29531860351562, -39.08399963378906), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(ZSAnimator.PlayerView, 26, (-1.013328194618225, -0.15164729952812195, -0.3303326368331909), (0.0, 0.0), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 28, (-3.7414863109588623, 0.0, 0.0), (50.70853805541992, -38.218345642089844), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 29, (-4.776376724243164, 0.0, 0.0), (50.556922912597656, -53.6788215637207), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 33, (-9.863944053649902, 0.0, 0.0), (25.28255844116211, -113.76280975341797), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 34, (-3.456594944000244, 0.0, 0.0), (13.859251022338867, -92.21121978759766), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(ZSAnimator.PlayerView, 41, (0.0, 0.0, 0.0), (0.0, 0.0), (1.0, 1.0), True));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 41, (0.0, 0.0, 0.0), (5.283334255218506, -79.67664337158203), (1.0, 1.0), True));

}
}