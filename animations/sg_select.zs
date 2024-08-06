class ZSAnimationShotgunSelect : ZSAnimation {
	override void Initialize() {
		frameCount = 8; 
		spritesLinked = False; 
		layered = False; 
	}
	override void MakeFrameList() {
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 0, (13.774106979370117, 0.0, 0.0), (59.478126525878906, -148.30628967285156), (1.0, 1.0), True, layered: False));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 1, (13.011109352111816, 0.0, 0.0), (50.1544303894043, -133.4871826171875), (1.0, 1.0), True, layered: False));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 2, (11.043379783630371, 0.0, 0.0), (31.25360107421875, -104.78229522705078), (1.0, 1.0), True, layered: False));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 3, (8.352811813354492, 0.0, 0.0), (16.38104820251465, -85.82025909423828), (1.0, 1.0), True, layered: False));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 4, (5.421296119689941, 0.0, 0.0), (9.965180397033691, -81.02998352050781), (1.0, 1.0), True, layered: False));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 5, (2.7307276725769043, 0.0, 0.0), (6.670548915863037, -78.57011413574219), (1.0, 1.0), True, layered: False));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 6, (0.7629987001419067, 0.0, 0.0), (5.456738471984863, -77.6638412475586), (1.0, 1.0), True, layered: False));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 7, (0.0, 0.0, 0.0), (5.283334255218506, -77.53437805175781), (1.0, 1.0), True, layered: False));
	frames.Push(ZSAnimationFrame.Create(PSP_WEAPON, 8, (0.0, 0.0, 0.0), (5.283334255218506, -77.53437805175781), (1.0, 1.0), True, layered: False));

}
}