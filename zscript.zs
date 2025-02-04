version "4.12"

#include "zsaGutamatics/Include.zsc"

#include "zsanimator.zs"
#include "animations/sg_fire.zs"
// #include "animations/zsa_shotgun.zs"
#include "animations/sg_select.zs"

#include "animations/pist_fire.zs"

#include "animations/ssg_fire.zs"
// #include "ssgfire.zs"
// #include "shotgunfire.zs"

class ZSAShotgun : Shotgun replaces Shotgun
{
	ZSAnimator animator;
	
	override void PostBeginPlay()
	{
		if (!animator)
		{
			animator = ZSAnimator(New("ZSAnimator"));
		}
	}
	
	action void A_ZSAWeaponReady(int flags = 0)
	{
		if (!player) return;
														DoReadyWeaponToSwitch(player, !(flags & WRF_NoSwitch));
		if ((flags & WRF_NoFire) != WRF_NoFire)			DoReadyWeaponToFire(player.mo, !(flags & WRF_NoPrimary), !(flags & WRF_NoSecondary));
		//if (!(flags & WRF_NoBob))						DoReadyWeaponToBob(player);

		player.WeaponState |= GetButtonStateFlags(flags);
		DoReadyWeaponDisableSwitch(player, flags & WRF_DisableSwitch);
	}
	
	Default
	{
		Weapon.SlotNumber 3;
	}
	
	States
	{
		Ready:
			ZSSG A 1 A_ZSAWeaponReady();
			loop;
		Select:
			ZSSG A 9 {
				let anim = ZSAnimator.GetAnimationFromClassName("ZSAnimationShotgunSelect");
				anim.spritesLinked = true;
				invoker.animator.StartAnimation(player, anim, playbackSpeed: 1.0);
			}
			goto Ready;
		Fire:
			ZSSG A 0 {
				let anim = ZSAnimator.GetAnimationFromClassName("ZSAnimationShotgunFire");
				anim.spritesLinked = true;
				anim.SetFlags(ZSAnimator.LF_FlipX, random(0, 2) == 0);
				// anim.flipanimx = true;
				invoker.animator.StartAnimation(player, anim, playbackSpeed: 1.0);
			}
			ZSSG A 0 A_FireShotgun();
			ZSSG A 10;
			ZSSG BC 5;
			ZSSG D 4;
			ZSSG CB 5;
			ZSSG A 3;
			ZSSG A 7 A_Refire;
			goto Ready;	
		Flash:
			SHTF A 0 A_OverlayFlags(OverlayID(), PSPF_ADDWEAPON, false);
			ZSSG EF 1 bright;
			stop;
	}
}

class ZSASSG : SuperShotgun replaces SuperShotgun
{
	ZSAnimator animator;
	
	override void PostBeginPlay()
	{
		if (!animator)
		{
			animator = ZSAnimator(New("ZSAnimator"));
		}
	}
	
	action void A_ZSAWeaponReady(int flags = 0)
	{
		if (!player) return;
														DoReadyWeaponToSwitch(player, !(flags & WRF_NoSwitch));
		if ((flags & WRF_NoFire) != WRF_NoFire)			DoReadyWeaponToFire(player.mo, !(flags & WRF_NoPrimary), !(flags & WRF_NoSecondary));
		//if (!(flags & WRF_NoBob))						DoReadyWeaponToBob(player);

		player.WeaponState |= GetButtonStateFlags(flags);
		DoReadyWeaponDisableSwitch(player, flags & WRF_DisableSwitch);
	}
	
	Default
	{
		Weapon.SlotNumber 3;
	}
	
	States
	{
		Ready:
			ZSAG A 1 A_ZSAWeaponReady();
			loop;
		Select:
			ZSAG A 9 {
				let anim = ZSAnimator.GetAnimationFromClassName("ZSAnimationShotgunSelect");
				anim.spritesLinked = true;
				invoker.animator.StartAnimation(player, anim, playbackSpeed: 1.0);
			}
			goto Ready;
		Fire:
			ZSAG A 0 {
				let anim = ZSAnimator.GetAnimationFromClassName("ZSAnimationSSGFire");
				anim.spritesLinked = true;
				// anim.flipanimx = true;
				invoker.animator.StartAnimation(player, anim, playbackSpeed: 1.0);
			}
			ZSAG A 0 A_FireShotgun2();
			ZSAG A 11;
			ZSAG C 14;
			ZSAG J 10 A_Overlay(PSP_WEAPON + 1, "LeftHand");
			ZSAG E 6;
			ZSAG C 9;
			goto Ready;	
		Flash:
			SHTF A 0 A_OverlayFlags(OverlayID(), PSPF_ADDWEAPON, false);
			ZSAG HI 1 bright;
			stop;
	}
}

class ZSAPistol : Pistol replaces Pistol
{
	ZSAnimator animator;
	
	override void PostBeginPlay()
	{
		if (!animator)
		{
			animator = ZSAnimator(New("ZSAnimator"));
		}
	}
	
	action void A_ZSAWeaponReady(int flags = 0)
	{
		if (!player) return;
														DoReadyWeaponToSwitch(player, !(flags & WRF_NoSwitch));
		if ((flags & WRF_NoFire) != WRF_NoFire)			DoReadyWeaponToFire(player.mo, !(flags & WRF_NoPrimary), !(flags & WRF_NoSecondary));
		//if (!(flags & WRF_NoBob))						DoReadyWeaponToBob(player);

		player.WeaponState |= GetButtonStateFlags(flags);
		DoReadyWeaponDisableSwitch(player, flags & WRF_DisableSwitch);
	}
	
	Default
	{
		Weapon.SlotNumber 2;
	}
	
	States
	{
		Ready:
			SHIT B 1 A_ZSAWeaponReady();
			loop;
		Select:
			SHIT B 9 {
				let anim = ZSAnimator.GetAnimationFromClassName("ZSAnimationShotgunSelect");
				anim.spritesLinked = true;
				invoker.animator.StartAnimation(player, anim, playbackSpeed: 1.0);
			}
			goto Ready;
		Fire:
			SHIT B 0 {
				let anim = ZSAnimator.GetAnimationFromClassName("ZSAnimationPistolFire");
				anim.SetFlags(ZSAnimator.LF_FlipX, random(0, 2) == 0);
				// anim.spritesLinked = true;
				// anim.flipanimx = true;
				invoker.animator.StartAnimation(player, anim, playbackSpeed: 1.0);
			}
			SHIT B 0 A_FirePistol;	
			SHIT D 1;
			SHIT E 3;
			SHIT D 2;
			SHIT B 4;
			goto Ready;	
		Flash:
			SHTF A 0 A_OverlayFlags(OverlayID(), PSPF_ADDWEAPON, false);
			SHIT F 1 bright;
			stop;
	}
}

class ZSAChaingun : Chaingun replaces Chaingun
{
	ZSAnimator animator;
	
	override void PostBeginPlay()
	{
		if (!animator)
		{
			animator = ZSAnimator(New("ZSAnimator"));
		}
	}
	
	action void A_ZSAWeaponReady(int flags = 0)
	{
		if (!player) return;
														DoReadyWeaponToSwitch(player, !(flags & WRF_NoSwitch));
		if ((flags & WRF_NoFire) != WRF_NoFire)			DoReadyWeaponToFire(player.mo, !(flags & WRF_NoPrimary), !(flags & WRF_NoSecondary));
		if (!(flags & WRF_NoBob))						DoReadyWeaponToBob(player);

		player.WeaponState |= GetButtonStateFlags(flags);
		DoReadyWeaponDisableSwitch(player, flags & WRF_DisableSwitch);
	}
	
	Default
	{
		Weapon.SlotNumber 4;
	}
	
	States
	{
		Ready:
			CHGG A 1 A_ZSAWeaponReady();
			loop;
		Fire:
			CHGG AB 4 {
				A_FireCGun();
				let psp = player.FindPSPrite(PSP_Weapon);
				let p = (frandom(-3, 3), frandom(-1.5, 1.5));
				invoker.animator.AnimatePSPTo(self.player, psp, p, (1, 1), 0, 4);
			}
			CHGG B 0 A_Refire;
			goto Ready;
	}
}