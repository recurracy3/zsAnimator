version "4.12"

#include "zsanimator.zs"
#include "ssgfire.zs"

class ZSASSG : SuperShotgun replaces SuperShotgun
{
	Default
	{
		Weapon.sLotNumber 3;
	}
	
	states
	{
		Fire:
			SHTG A 0 {
				A_FireBullets(11.2, 7.1, 20, 5, "BulletPuff");
				A_StartSound("weapons/sshotf", CHAN_WEAPON);
				A_Overlay(PSP_FLASH, "Flash");
				A_OverlayFlags(PSP_FLASH, PSPF_ADDWEAPON, true);
			}
			SHTG A 0 {
				ZSAnimator animator = ZSanimator(New("ZSAnimator"));
				animator.StartAnimation(player, "ZSAnimationSSGFire");
			}
			SHT2 A 25;
			SHT2 B 3;
			SHT2 C 12;
			SHT2 B 2;
			SHT2 K 3;
			SHT2 K 0 A_Overlay(ZSAnimator.PSP_HANDS, "HandsReload");
			SHT2 K 20;
			SHT2 B 4;
			SHT2 C 11;
			SHT2 A 16;
			goto Ready;
		Flash:
			SHT2 IJ 2 bright;
			stop;
		HandsReload:
			SHT2 L 20;
			stop;
	}
}

/*class ZSAShotgun : Shotgun replaces Shotgun
{
	Default
	{
		Weapon.SlotNumber 3;
	}
	
	action void A_Test()
	{
		ZSAnimator animator = ZSanimator(New("ZSAnimator"));
		animator.StartAnimation(player, "ZSAnimationShotgunFire");
	}
	
	States
	{
		Fire:
			SHTG A 0 A_FireShotgun();
			SHTG A 0 A_Test();
			SHTG A 20;
			SHTG B 3;
			SHTG C 8;
			SHTG D 5;
			SHTG C 3;
			SHTG B 4;
			SHTG A 7;
			goto Ready;	
		Flash:
			SHTF AB 1 bright;
			stop;
	}
}*/