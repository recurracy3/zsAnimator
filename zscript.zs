version "4.12"

#include "zsanimator.zs"
#include "animations/sg_fire.zs"
// #include "animations/zsa_shotgun.zs"
#include "animations/sg_select.zs"
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
			SHTG A 1 A_ZSAWeaponReady();
			loop;
		Select:
			SHTG A 9 {
				let anim = ZSAnimator.GetAnimationFromClassName("ZSAnimationShotgunSelect");
				anim.spritesLinked = true;
				invoker.animator.StartAnimation(player, anim, playbackSpeed: 1.0);
			}
			goto Ready;
		Fire:
			SHTG A 0 {
				let anim = ZSAnimator.GetAnimationFromClassName("ZSAnimationShotgunFire");
				anim.spritesLinked = true;
				invoker.animator.StartAnimation(player, anim, playbackSpeed: 1.0);
			}
			SHTG A 0 A_FireShotgun();
			SHTG A 9;
			SHTG BC 5;
			SHTG D 4;
			SHTG CB 4;
			SHTG A 3;
			SHTG A 7 A_Refire;
			goto Ready;	
		Flash:
			SHTF A 0 A_OverlayFlags(OverlayID(), PSPF_ADDWEAPON, false);
			SHTF AB 1 bright;
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