#if defined _all_inclusive_included
	#endinput
#endif
#define _all_inclusive_included

native is_visible_range(entity, target, Float: range = 8192.0, no_monsters = 0);
native UTIL_Sparks(const Float: position[]);
native UTIL_DrawBeamPoints(Float: start[], Float: end[], sprite_index, starting_frame = 0, frame_rate = 0, life_time, line_width = 10, noise_amplitude = 0, r, g, b, brightness = 255, scroll_speed = 0);
native set_rendering(index, fx = kRenderFxNone, r = 255, g = 255, b = 255, render = kRenderNormal, amount = 16);

#include "include/all_inclusive/common.sma"
#include "include/all_inclusive/multilingual.sma"
#include "include/all_inclusive/sv_maxrate_patch.sma"
#include "include/all_inclusive/slap_slay_menu.sma"
#include "include/all_inclusive/auto_close_menu.sma"

#if defined RADIO_CONTROL_MODULE
  #include "include/all_inclusive/radio_control.sma"
#endif

#if defined MAPMANAGER_MODULE
  #include "include/all_inclusive/mapmanager.sma"
#endif

#if defined CSDM_VERSION
  #include "include/all_inclusive/spawn_manager.sma"
  #include "include/all_inclusive/csdm.sma"
#endif

#if defined MULTIJUMP_MODULE
  #include "include/all_inclusive/multi_jump.sma"
#endif

#if defined QUALITY_CONNECTION_MODULE
  #include "include/all_inclusive/quality_connection.sma"
#endif

#if defined LEVEL_SYSTEM_MODULE
  #include "include/all_inclusive/level_system.sma"
#endif

#if defined LASERMINE_MODULE
  #include "include/all_inclusive/lasermine.sma"
#endif

#if defined DISPENSER_MODULE
  #include "include/all_inclusive/dispenser.sma"
#endif

#if defined SENTRYGUNS_MODULE
  #include "include/all_inclusive/sentryguns.sma"
#endif

#if defined SENTRYGUNS_MODULE || defined DISPENSER_MODULE || defined LASERMINE_MODULE
  #include "include/all_inclusive/control_menu.sma"
#endif

#if defined VIP_MENU_MODULE
  #include "include/all_inclusive/vip_menu.sma"
#endif

#if defined SHOP_MODULE
  #include "include/all_inclusive/shop.sma"
#endif

#if defined CHAT_MODULE
  #include "include/all_inclusive/chat.sma"
#endif

#if defined DEMO_MODULE
  #include "include/all_inclusive/demo.sma"
#endif

#if defined DAMAGER_MODULE
  #include "include/all_inclusive/damager.sma"
#endif


#if defined TRANSFER_MONEY_MODULE
  #include "include/all_inclusive/transfer_money.sma"
#endif

#if defined COLOR_FLASH_SCREEN_MODULE
  #include "include/all_inclusive/color_flash_screen.sma"
#endif

#if defined CSDM_AUTO_BALANCE
  #include "include/all_inclusive/csdm_auto_balance.sma"
#endif

#if defined CSDM_WEAPON_MENU
  #include "include/all_inclusive/csdm_weapon_menu.sma"
#endif

#if defined AIM_DETECTOR
  #include "include/all_inclusive/aim_detector.sma"
#endif

#if defined QUICK_MENU_MODULE
  #include "include/all_inclusive/quick_menu.sma"
#endif

#if defined GAG_ME_MODULE
  #include "include/all_inclusive/gag_me.sma"
#endif

#if defined KICK_MENU_MODULE
  #include "include/all_inclusive/kick_menu.sma"
#endif

#if defined VOTEBAN_MODULE
  #include "include/all_inclusive/voteban.sma"
#endif

#if defined HATS_MODULE
  #include "include/all_inclusive/hats.sma"
#endif
