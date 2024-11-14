//￿
#if defined _sm_module_included
  #endinput
#endif
#define _sm_module_included

#define get_spawn_origin(%0)    _:spawn_point[%0][SPAWN_ORIGIN]
#define set_spawn_origin(%0,%1) vec_copy(Float: spawn_point[%0][SPAWN_ORIGIN], %1)

#define get_spawn_angles(%0)    _:spawn_point[%0][SPAWN_ANGLES]
#define set_spawn_angles(%0,%1) vec_copy(Float: spawn_point[%0][SPAWN_ANGLES], %1)

#define get_spawn_v_angle(%0)    _:spawn_point[%0][SPAWN_V_ANGLE]
#define set_spawn_v_angle(%0,%1) vec_copy(Float: spawn_point[%0][SPAWN_V_ANGLE], %1)

const MAX_SPAWNS            = 90;
const MAX_GENERATE_SPAWNS   = 60;
new const SPAWN_CLASSNAME[] = "spawn_point";

enum ( <<= 1 )
{
  IGNORE_VISITED = 1,
  IGNORE_VISIBLE,
  ONLY_NEAR_PLANT,
  VISITED_RESETTED
}

enum spawn_data
{
  SPAWN_ENTITY,
  SPAWN_ORDER,
  SPAWN_TEAM,
  SPAWN_INVADER,
  SPAWN_OWNER,
  Float: SPAWN_CAPTURE_END_TIME,
  vec(SPAWN_ORIGIN),
  vec(SPAWN_ANGLES),
  vec(SPAWN_V_ANGLE)
}

enum hologram_map
{
  RENDERFX          = 0,
  RENDERCOLOR_RED   = 1,
  RENDERCOLOR_GREEN = 2,
  RENDERCOLOR_BLUE  = 3,
  RENDERMODE        = 4,
  RENDERAMT         = 5
}

new const HOLOGRAM_DATA[][hologram_map] = {
  {kRenderFxGlowShell, 128, 128, 128, kRenderTransColor, 10},
  {kRenderFxGlowShell, 255, 0, 0, kRenderTransColor, 20},
  {kRenderFxGlowShell, 0, 0, 255, kRenderTransColor, 20},
  {kRenderFxHologram, 128, 128, 128, kRenderTransAdd, 128}
};

new spawns_cfg_filename[FILENAME_LEN];
new spawn_point[MAX_SPAWNS][spawn_data];
new spawn_num_by_player[MAX_CLIENTS + 1];
new captured_spawns[MAX_TEAMS];
new total_spawns;
new spawn_manager_enabled;
new spawn_editor_menu_cid;
new info_target_string_id;
new hologram_type;
new spawn_progress_bar;

new closest_spawn_index[MAX_CLIENTS + 1] = {-1, ...};
new spawn_visited_num[MAX_CLIENTS + 1];
new spawn_visited[MAX_CLIENTS + 1][MAX_SPAWNS];
new spawn_not_valid_num[MAX_CLIENTS + 1];
new spawn_not_valid[MAX_CLIENTS + 1][MAX_SPAWNS];

new block_respawn;
new Float: sm_spawn_wait_time;
new Float: sm_spawn_enemy_distance;
new sm_reset_visited_spawn_percent;
new sm_spawn_model[CVAR_LEN];
new sm_spawn_capture_bonus;
new Float: sm_give_capture_bonus_delay;
new sm_captured_spawns_max_percent;
new Float: sm_spawn_capture_time;
new Float: sm_captured_map_end_delay;

sm_plugin_init()
{
  if (!info_target_string_id) {
    info_target_string_id = engfunc(EngFunc_AllocString, "info_target");
  }
  
  register_concmd("spawn_editor", "concmd_spawn_editor");
  spawn_editor_menu_cid = menu_makecallback("spawn_editor_menu_callback");
}

sm_plugin_cfg()
{
  formatex(spawns_cfg_filename, charsmax(spawns_cfg_filename), "%s/csdm/%s.spawns.cfg", amxx_configsdir, map_name);

  if (read_spawns()) {
    delete_spawn_point_ents();
    create_spawn_point_ents();
    hide_spawn_point_ents();
  }
  else {
    //generate_spawn_list(MAX_GENERATE_SPAWNS);
  }
}

sm_init_cvars()
{
  register_cvar_ex ("sm_spawn_wait_time"            , "0.75"                     , _, _, "Задержка перед возрождением");
  register_cvar_ex ("sm_reset_visited_spawn_percent", "75"                       , _, _, "Процент посещенных точек возрождения, при достижении которого сбрасывается информация о посещении");
  register_cvar_ex ("sm_spawn_enemy_distance"       , "175.0"                    , _, _, "Минимальное расстояние от точки возрождения на котором должен находиться противник^n// Если противник находится ближе, точка возрождения будет заблокирована");
  register_cvar_ex ("sm_spawn_model"                , "models/player/vip/vip.mdl", _, _, "Путь к модели, которая будет отображаться на месте точки возрождения");
  register_cvar_ex ("sm_spawn_capture_bonus"        , "100"                      , _, _, "Количество денег за захват точки возрождения каждые sm_give_capture_bonus_delay секунд");
  register_cvar_ex ("sm_give_capture_bonus_delay"   , "15"                       , _, _, "Задержка начисления бонуса за захват точки возрождения (в секундах)");
  register_cvar_ex ("sm_captured_spawns_max_percent", "80"                       , _, _, "Процент захваченных одной командой точек возрождения для завершения карты");
  register_cvar_ex ("sm_spawn_capture_time"         , "10"                       , _, _, "Время необходимое для захвата точки возрождения в ручном режиме (нажатие кнопки R)");
  register_cvar_ex ("sm_captured_map_end_delay"     , "60"                       , _, _, "Время через которое сменится карта после ее захвата одной из команд, при условии что процент захваченных точек не упадет меньше необходимого");
  
}

sm_load_cvars()
{
  sm_spawn_wait_time             = get_cvar_float("sm_spawn_wait_time");
  sm_spawn_enemy_distance        = get_cvar_float("sm_spawn_enemy_distance");
  sm_reset_visited_spawn_percent = clamp(get_cvar_num("sm_reset_visited_spawn_percent"), 0, 100);
  sm_captured_spawns_max_percent = clamp(get_cvar_num("sm_captured_spawns_max_percent"), 0, 100);
  get_cvar_string("sm_spawn_model", sm_spawn_model, charsmax(sm_spawn_model));
  sm_spawn_capture_bonus         = clamp(get_cvar_num("sm_spawn_capture_bonus"), 1, ai_max_money);
  sm_give_capture_bonus_delay    = get_cvar_float("sm_give_capture_bonus_delay");
  sm_spawn_capture_time          = get_cvar_float("sm_spawn_capture_time");
  sm_captured_map_end_delay      = get_cvar_float("sm_captured_map_end_delay");
}

sm_plugin_precache()
{
  if (!is_str_empty(sm_spawn_model)) {
    precache_model(sm_spawn_model);
  }
}

public concmd_spawn_editor(id)
{
  if (!is_has_access(id, AI_MAIN_ADMIN_FLAGS)) {
    console_print(id, "%L", id, "NO_ACC_COM");
    return PH;
  }
  
  new arg_str[5];

  read_argv (1, arg_str, charsmax(arg_str));
  remove_quotes (arg_str);

  if (equali(arg_str, "0") || equali(arg_str, "off")) {
    disable_spawn_manager();
    close_menu(id);
    client_print(id, print_console, "Spawn Manager DISABLED");
  }
  else {
    if (equali(arg_str, "1") || equali(arg_str, "on")) {
      enable_spawn_manager(id);
    }
    
    if (spawn_manager_enabled) {
      spawn_editor_menu(id);
    }
  }

  return PH;
}

enable_spawn_manager(id)
{
  if (spawn_manager_enabled) {
    return;
  }
  
  show_spawn_point_ents();
  spawn_manager_enabled = 1;
  
  client_print(id, print_console, "Spawn Manager ENABLED");
}

disable_spawn_manager()
{
  spawn_manager_enabled = 0;
  arrayset(closest_spawn_index, -1, sizeof closest_spawn_index);

  if (total_spawns) {
    set_pgame_int(m_iSpawnPointCount_CT, total_spawns);
    set_pgame_int(m_iSpawnPointCount_Terrorist, total_spawns);
    
    save_spawns();
    hide_spawn_point_ents();
  }
}

spawn_editor_menu(id)
{
  formatex(title_name, charsmax(title_name), FMT_ML, id, get_ml_key(SPAWN_EDITOR_MENU), total_spawns, MAX_SPAWNS);
  new spawn_editor_mid = menu_create(title_name, "spawn_editor_menu_handler");

  menu_additem(spawn_editor_mid, get_ml_string(id, get_ml_key(SPAWN_EDITOR_MENU_ITEM1)), .callback = spawn_editor_menu_cid);
  menu_additem(spawn_editor_mid, get_ml_string(id, get_ml_key(SPAWN_EDITOR_MENU_ITEM2)));
  menu_additem(spawn_editor_mid, get_ml_string(id, get_ml_key(SPAWN_EDITOR_MENU_ITEM3)), .callback = spawn_editor_menu_cid);

  menu_set_color(spawn_editor_mid, MENU_COLOR_YELLOW);
  menu_set_exitname_ml(spawn_editor_mid, id, get_ml_key(AI_MENU_EXIT));
  
  menu_display_ex( id, spawn_editor_mid);
}

public spawn_editor_menu_callback(id, menu, item)
{
  if (item == 2 && get_bad_spawn(id) == -1) {
    return ITEM_DISABLED;
  }
  
  return (total_spawns == MAX_SPAWNS) ? ITEM_DISABLED : ITEM_ENABLED;
}

public spawn_editor_menu_handler(id, menu, item)
{
  menu_destroy(menu);
  
  if (item != MENU_EXIT) {
    if (total_spawns <= MAX_SPAWNS) {
      switch(item) {
        case 0: add_spawn_point(id);
        case 1: delete_spawn_point(id);
        case 2: {
          new bad_spawn_index = get_bad_spawn(id);
          
          if (bad_spawn_index != -1) {
            locate_player_at_spawn(id, bad_spawn_index);
          }
        }
      }
    }
    
    spawn_editor_menu(id);
  }

  return PH;
}

sm_player_Spawn_Post(id)
{
  if (total_spawns < 2) {
    return 1;
  }
  
  generate_spawn_order();
  
  spawn_not_valid_num[id] = 0;
  arrayset (spawn_not_valid[id], 0, sizeof spawn_not_valid[]);
  
  if (select_spawn(id, IGNORE_VISITED) == -1) {
    return 0;
  }

  return 1;
}

stock generate_spawn_order()
{
  static i, j, t; j = 0;
  
  for (i = 0; i < total_spawns; ++i) {
    spawn_point[i][SPAWN_ORDER] = i;
  }
  
  for (i = 0; i < total_spawns; ++i) {
    j = random_num (0, total_spawns - 1);
    t = spawn_point[i][SPAWN_ORDER];
    spawn_point[i][SPAWN_ORDER] = spawn_point[j][SPAWN_ORDER];
    spawn_point[j][SPAWN_ORDER] = t;
  }
}

stock try_capture_spawn_point(spawn_index, entity)
{
  if (!spawn_point[spawn_index][SPAWN_INVADER]) {
    if (is_client(entity)) {
      hide_progress_bar(entity, spawn_progress_bar);
      show_progress_bar(entity, floatround(sm_spawn_capture_time), 0, spawn_progress_bar);
    }

    spawn_point[spawn_index][SPAWN_INVADER] = entity;
    spawn_point[spawn_index][SPAWN_CAPTURE_END_TIME] = _: (ctime + sm_spawn_capture_time - 0.2);
    return 1;
  }
  else {
    if (ctime > spawn_point[spawn_index][SPAWN_CAPTURE_END_TIME]) {
      reset_captured_spawn(spawn_index, spawn_point[spawn_index][SPAWN_OWNER]);
      capture_spawn(spawn_index, entity);
    }
    else {
      if (is_client(entity)) {
        show_progress_bar(entity, floatround(spawn_point[spawn_index][SPAWN_CAPTURE_END_TIME] - ctime), 0, spawn_progress_bar);
      }
    }
    
    return 1;
  }

  return 0;
}

stock get_spawn_capturable(entity, Float: distance)
{
  for (new i; i < total_spawns; i++) {
    if (is_spawn_capturable(i, entity, distance)) {
      return i;
    }
  }
  
  return -1;
}

is_spawn_capturable(spawn_index, entity, Float: distance)
{
  if (is_valid_client(entity) && !is_alive(entity)) {
    return 0;
  }
  
  if (spawn_point[spawn_index][SPAWN_OWNER]) {
    if (spawn_point[spawn_index][SPAWN_OWNER] == entity) {
      return 0;
    }
    
    if (!is_client(spawn_point[spawn_index][SPAWN_OWNER]) || !is_client(entity)) {
      return 0;
    }
  }

  if (spawn_point[spawn_index][SPAWN_INVADER] && spawn_point[spawn_index][SPAWN_INVADER] != entity) {
    return 0;
  }

  if (spawn_point[spawn_index][SPAWN_TEAM] == ai_get_team(entity)) {
    return 0;
  }

  if (!is_visible_range(entity, spawn_point[spawn_index][SPAWN_ENTITY], distance, IGNORE_MONSTERS)) {
    return 0;
  }
  
  return 1;
}

stock in_spawns_list(const Float:vec1[])
{
  for (new i; i < total_spawns; i++) {
    if (absF(vec1[X] - spawn_point[i][SPAWN_ORIGIN][X]) <= 16.0 &&  absF(vec1[Y] - spawn_point[i][SPAWN_ORIGIN][Y]) <= 16.0 && absF(vec1[Z] - spawn_point[i][SPAWN_ORIGIN][Z]) <= 16.0) {
      return i;
    }
  }
  
  return -1;
}

capture_spawn(index, entity)
{
  hologram_type = ai_get_team(entity);
  set_rendering(spawn_point[index][SPAWN_ENTITY], HOLOGRAM_DATA[hologram_type][RENDERFX], HOLOGRAM_DATA[hologram_type][RENDERCOLOR_RED], HOLOGRAM_DATA[hologram_type][RENDERCOLOR_GREEN], HOLOGRAM_DATA[hologram_type][RENDERCOLOR_BLUE], HOLOGRAM_DATA[hologram_type][RENDERMODE], HOLOGRAM_DATA[hologram_type][RENDERAMT]);
  
  spawn_point[index][SPAWN_TEAM]    = ai_get_team(entity);
  spawn_point[index][SPAWN_INVADER] = 0;
  spawn_point[index][SPAWN_OWNER]   = entity;
  spawn_num_by_player[ai_get_owner(entity)]++;
}

reset_all_captured_spawns(entity)
{
  for (new i; i < total_spawns; i++) {
    reset_captured_spawn(i, entity);
  }
}

reset_capture_data(spawn_index, entity)
{
  spawn_point[spawn_index][SPAWN_INVADER] = 0;
  spawn_point[spawn_index][SPAWN_CAPTURE_END_TIME] = _: 0.0;

  if (is_valid_client(entity)) {
    hide_progress_bar(entity, spawn_progress_bar);
  }
}

reset_captured_spawn(spawn_index, entity)
{
  if (spawn_point[spawn_index][SPAWN_INVADER] && spawn_point[spawn_index][SPAWN_INVADER] == entity) {
    reset_capture_data(spawn_index, entity);
  }
  
  if (!spawn_point[spawn_index][SPAWN_OWNER] || spawn_point[spawn_index][SPAWN_OWNER] != entity) {
    return 0;
  }

  if (spawn_point[spawn_index][SPAWN_OWNER]) {
    if (!entity) {
      spawn_num_by_player[ai_get_owner(spawn_point[spawn_index][SPAWN_OWNER])]--;
    }
    else {
      spawn_num_by_player[ai_get_owner(entity)]--;
    }
  }
  
  spawn_point[spawn_index][SPAWN_TEAM]  = TEAM_UNASSIGNED;
  spawn_point[spawn_index][SPAWN_OWNER] = 0;

  hologram_type = 0;
  set_rendering(spawn_point[spawn_index][SPAWN_ENTITY], HOLOGRAM_DATA[hologram_type][RENDERFX], HOLOGRAM_DATA[hologram_type][RENDERCOLOR_RED], HOLOGRAM_DATA[hologram_type][RENDERCOLOR_GREEN], HOLOGRAM_DATA[hologram_type][RENDERCOLOR_BLUE], HOLOGRAM_DATA[hologram_type][RENDERMODE], HOLOGRAM_DATA[hologram_type][RENDERAMT]);

  return 1;
}

stock select_spawn(id, flags)
{
  static final, i, j, pl_num, n, is_enemy_very_close, vec(pl_origin[MAX_CLIENTS + 1]);
  final = -1;
  pl_num = 0;
  
  for (i = 1; i <= max_players; ++i) {
    if (user_team[i] != user_team[id] && is_alive(i)) {
      vec_copy(pl_origin[pl_num], ai_get_origin(i));
      pl_num++;
    }
  }
  
  for (i = 0; i < total_spawns; i++) {
    n = spawn_point[i][SPAWN_ORDER], is_enemy_very_close = 0;
    
    if (spawn_not_valid[id][n]) {
      continue;
    }
    
    if (get_bit(flags, IGNORE_VISITED) && spawn_visited[id][n]) {
      continue;
    }

    if (spawn_point[n][SPAWN_TEAM]) {
      if (user_team[id] != spawn_point[n][SPAWN_TEAM]) {
        ++spawn_not_valid_num[id];
        spawn_not_valid[id][n] = 1;
        continue;
      }
    }

    for (j = 0; j < pl_num; ++j) {
      if (get_distance_f(spawn_point[n][SPAWN_ORIGIN], pl_origin[j]) <= sm_spawn_enemy_distance) {
        is_enemy_very_close = 1;
        break;
      }
    }
    
    if (is_enemy_very_close) {
      ++spawn_not_valid_num[id];
      spawn_not_valid[id][n] = 1;
      continue;
    }
    
    if (trace_hull(spawn_point[n][SPAWN_ORIGIN], HULL_HUMAN, 0, DONT_IGNORE_MONSTERS)) {
      ++spawn_not_valid_num[id];
      spawn_not_valid[id][n] = 1;
      continue;
    }

    final = n;
    ++spawn_visited_num[id];
    spawn_visited[id][n] = 1;
    break;
  }

  if (final == -1) {
    if (get_bit(flags, IGNORE_VISITED)) {
      if (get_bit(flags, VISITED_RESETTED)) {
        clr_bit(flags, IGNORE_VISITED);
      }
      else {
        if ((spawn_visited_num[id] * 100 / total_spawns) > sm_reset_visited_spawn_percent ||
            (spawn_not_valid_num[id] * 100 / total_spawns) > sm_reset_visited_spawn_percent) {
          arrayset (spawn_visited[id], 0, sizeof spawn_visited[]);
          spawn_visited_num[id] = 0;
          set_bit(flags, VISITED_RESETTED);
        }
      }
    }
    else if (get_bit(flags, IGNORE_VISIBLE)) {
      flags = 0;
    }
    else {
      //_debug && log_to_file(debug_log_filename, "[DEBUG] some spawns blocked on %s!", map_name);
      return final;
    }
    
    select_spawn (id, flags);
  }

  locate_player_at_spawn(id, final);
  return final;
}

stock locate_player_at_spawn(id, index)
{
  entity_set_origin(id, spawn_point[index][SPAWN_ORIGIN]);
  entity_set_int(id, EV_INT_fixangle, 1);
  set_angles(id, spawn_point[index][SPAWN_ANGLES]);
  set_v_angle(id, spawn_point[index][SPAWN_V_ANGLE]);
}

stock read_spawns()
{
  new need_save;
  total_spawns = 0;

  new file_handle = fopen(spawns_cfg_filename, "rt");
      
  if (!file_handle) {
    _debug && log_amx("[:(] Error opening ^"%s^" file!", spawns_cfg_filename);
    pause("ad");
    return 0;
  }
  
  new text_buffer[256];
  new pos[11][8];
  new bad_spawn_counter;
  
  while (!feof(file_handle) && total_spawns < MAX_SPAWNS) {
    fgets(file_handle, text_buffer, charsmax(text_buffer));
    trim(text_buffer);
    
    if (is_str_empty(text_buffer)) {
      continue;
    }
    
    parse(text_buffer, pos[1], charsmax(pos[]), pos[2], charsmax(pos[]), pos[3], charsmax(pos[]), pos[4], charsmax(pos[]), pos[5], charsmax(pos[]), pos[6], charsmax(pos[]), pos[7], charsmax(pos[]), pos[8], charsmax(pos[]), pos[9], charsmax(pos[]), pos[10], charsmax(pos[]));
  
    spawn_point[total_spawns][SPAWN_ORIGIN][X]  = _: float(str_to_num(pos[1]));
    spawn_point[total_spawns][SPAWN_ORIGIN][Y]  = _: float(str_to_num(pos[2]));
    spawn_point[total_spawns][SPAWN_ORIGIN][Z]  = _: float(str_to_num(pos[3]));

    if (xs_vec_equal(spawn_point[total_spawns][SPAWN_ORIGIN], vec_zero)) {
      need_save = 1;
      continue;
    }

    if (in_spawns_list(spawn_point[total_spawns][SPAWN_ORIGIN]) != -1) {
      print_vector(map_name, spawn_point[total_spawns][SPAWN_ORIGIN], .log = _debug);
      need_save = 1;
      continue;
    }
    
    if (trace_hull(spawn_point[total_spawns][SPAWN_ORIGIN], HULL_HUMAN, 0, DONT_IGNORE_MONSTERS)) {
      bad_spawn_counter++;
    }
    
    spawn_point[total_spawns][SPAWN_ANGLES][X]  = _: str_to_float(pos[4]);
    spawn_point[total_spawns][SPAWN_ANGLES][Y]  = _: str_to_float(pos[5]);
    spawn_point[total_spawns][SPAWN_ANGLES][Z]  = _: str_to_float(pos[6]);

    //Team - ignore - 7
    
    spawn_point[total_spawns][SPAWN_V_ANGLE][X] = _: str_to_float(pos[8]);
    spawn_point[total_spawns][SPAWN_V_ANGLE][Y] = _: str_to_float(pos[9]);
    spawn_point[total_spawns][SPAWN_V_ANGLE][Z] = _: str_to_float(pos[10]);
    
    total_spawns++;
  }

  fclose(file_handle);
  
  if (total_spawns) {
    if (need_save) {
      save_spawns();
    }
    
    if (bad_spawn_counter) {
      log_to_file(debug_log_filename, "[%s] Found %d bad spawn points", map_name, bad_spawn_counter);
    }
    
    _debug && log_amx("[OK] Loaded %d spawn_point points for map %s", total_spawns, map_name);
  }
  else {
    _debug && log_amx("[;(] File %s is empty and not contain spawn_point points", spawns_cfg_filename);
  }
  
  return 1;
}

stock save_spawns()
{
  if (!total_spawns) {
    return;
  }
  
  new file_handle = fopen(spawns_cfg_filename, "wt");

  if (!file_handle) {
    log_amx("Error opening ^"%s^" file", spawns_cfg_filename);
    return;
  }
  
  fprintf(file_handle, "// Origin (x, y, z),  Angles (p, y, r), Team, View Angle (p, y, r)^n");
  
  new text_buffer[256];
  
  for (new i; i < total_spawns; i++) {
    formatex(text_buffer, charsmax(text_buffer), "%d %d %d %d %d %d 0 %d %d %d^n",
    floatround(spawn_point[i][SPAWN_ORIGIN][X]), floatround(spawn_point[i][SPAWN_ORIGIN][Y]), floatround(spawn_point[i][SPAWN_ORIGIN][Z]),
    floatround(spawn_point[i][SPAWN_ANGLES][P]), floatround(spawn_point[i][SPAWN_ANGLES][Y]), floatround(spawn_point[i][SPAWN_ANGLES][R]),
    floatround(spawn_point[i][SPAWN_V_ANGLE][P]), floatround(spawn_point[i][SPAWN_V_ANGLE][Y]), floatround(spawn_point[i][SPAWN_V_ANGLE][R]));
    
    fprintf(file_handle, text_buffer);
  }

  fclose(file_handle);
}

add_spawn_point(id)
{
  static vec(player_origin), vec(player_angles), vec(player_v_angle);
  
  vec_copy(player_origin, ai_get_origin(id));
  pev(id, pev_angles, player_angles);
  pev(id, pev_v_angle, player_v_angle);

  player_origin[Z] += 15.0;

  set_spawn_origin(total_spawns, player_origin);
  
  if (trace_hull(spawn_point[total_spawns][SPAWN_ORIGIN], HULL_HUMAN, id, IGNORE_MONSTERS)) {
    client_print_color(id, print_team_default, FMT_ML, id, get_ml_key(SM_BAD_SPAWN));
    return;
  }
  
  set_spawn_angles(total_spawns, player_angles);
  set_spawn_v_angle(total_spawns, player_v_angle);

  closest_spawn_index[id] = total_spawns;
  create_spawn_point_ent(closest_spawn_index[id]);

  total_spawns++;
}
  
delete_spawn_point(id)
{
  if (update_closest_spawn(id) != -1) {
    new spawn_index = closest_spawn_index[id];
    reset_captured_spawn(spawn_index, 0);
    
    if (is_valid_ent(spawn_point[spawn_index][SPAWN_ENTITY])) {
      fm_remove_entity(spawn_point[spawn_index][SPAWN_ENTITY]);
    }
    
    copy_spawn_point(total_spawns - 1, spawn_index);
    total_spawns--;
  }

  update_closest_spawn(id);
}

copy_spawn_point(src_spawn_index, dest_spawn_index)
{
  spawn_point[dest_spawn_index][SPAWN_ENTITY] = spawn_point[src_spawn_index][SPAWN_ENTITY];
  spawn_point[dest_spawn_index][SPAWN_ORDER]  = spawn_point[src_spawn_index][SPAWN_ORDER];
  spawn_point[dest_spawn_index][SPAWN_TEAM]   = spawn_point[src_spawn_index][SPAWN_TEAM];
  ai_set_common_index(spawn_point[dest_spawn_index][SPAWN_ENTITY], src_spawn_index);

  vec_copy(spawn_point[dest_spawn_index][SPAWN_ORIGIN], spawn_point[src_spawn_index][SPAWN_ORIGIN]);
  vec_copy(spawn_point[dest_spawn_index][SPAWN_ANGLES], spawn_point[src_spawn_index][SPAWN_ANGLES]);
  vec_copy(spawn_point[dest_spawn_index][SPAWN_V_ANGLE], spawn_point[src_spawn_index][SPAWN_V_ANGLE]);
}

stock write_spawn_file(spawn_index)
{
  new text_buffer[256];
  formatex(text_buffer, charsmax(text_buffer), "%.0f %.0f %.0f %.0f %.0f %.0f 0 %.0f %.0f %.0f",
  spawn_point[spawn_index][SPAWN_ORIGIN][X], spawn_point[spawn_index][SPAWN_ORIGIN][Y], spawn_point[spawn_index][SPAWN_ORIGIN][Z],
  spawn_point[spawn_index][SPAWN_ANGLES][P], spawn_point[spawn_index][SPAWN_ANGLES][Y], spawn_point[spawn_index][SPAWN_ANGLES][R],
  spawn_point[spawn_index][SPAWN_V_ANGLE][P], spawn_point[spawn_index][SPAWN_V_ANGLE][Y], spawn_point[spawn_index][SPAWN_V_ANGLE][R]);
  
  write_file(spawns_cfg_filename, text_buffer, -1);
}

stock update_closest_spawn(id)
{
  new Float: distance, Float: last_distance;

  closest_spawn_index[id] = -1;
  last_distance = MAX_MAP_RANGE;
  
  for (new i; i < total_spawns; i++) {
    distance = get_distance_f(ai_get_origin(id), spawn_point[i][SPAWN_ORIGIN]);
    
    if (distance <= sm_spawn_enemy_distance && distance < last_distance) {
      last_distance = distance;
      closest_spawn_index[id] = i;
    }
  }
  
  return closest_spawn_index[id];
}

create_spawn_point_ents()
{
  for (new i; i < total_spawns; i++) {
    if (!create_spawn_point_ent(i)) {
      break;
    }
  }
}

delete_spawn_point_ents()
{
  for (new i; i < total_spawns; i++) {
    if (is_valid_ent(spawn_point[i][SPAWN_ENTITY])) {
      fm_remove_entity(spawn_point[i][SPAWN_ENTITY]);
      spawn_point[i][SPAWN_ENTITY] = 0;
    }
  }
}

hide_spawn_point_ents()
{
  for (new i; i < total_spawns; i++) {
    hide_spawn_point_ent(i);
  }
}

show_spawn_point_ents()
{
  for (new i; i < total_spawns; i++) {
    show_spawn_point_ent(i);
  }
}

hide_spawn_point_ent(spawn_index)
{
  new entity = spawn_point[spawn_index][SPAWN_ENTITY];

  if (is_valid_ent(entity)) {
    set_pev(entity, pev_effects, pev(entity, pev_effects) | EF_NODRAW);
  }
}

show_spawn_point_ent(spawn_index)
{
  new entity = spawn_point[spawn_index][SPAWN_ENTITY];
    
  if (is_valid_ent(entity)) {
    set_pev(entity, pev_effects, pev(entity, pev_effects) & ~EF_NODRAW);
    
    hologram_type = spawn_manager_enabled ? 3 : spawn_point[spawn_index][SPAWN_TEAM];
    set_rendering(entity, HOLOGRAM_DATA[hologram_type][RENDERFX], HOLOGRAM_DATA[hologram_type][RENDERCOLOR_RED], HOLOGRAM_DATA[hologram_type][RENDERCOLOR_GREEN], HOLOGRAM_DATA[hologram_type][RENDERCOLOR_BLUE], HOLOGRAM_DATA[hologram_type][RENDERMODE], HOLOGRAM_DATA[hologram_type][RENDERAMT]);
  }
}

create_spawn_point_ent(spawn_index)
{
  new entity = engfunc(EngFunc_CreateNamedEntity, info_target_string_id);
    
  if (entity <= 0) {
    return 0;
  }
  
  set_pev(entity, pev_classname, SPAWN_CLASSNAME);
  set_model(entity, sm_spawn_model);
  set_pev(entity, pev_solid, SOLID_NOT);
  set_pev(entity, pev_movetype, MOVETYPE_NOCLIP);
  set_pev(entity, pev_sequence, 1);
  set_pev(entity, pev_flags, pev(entity, pev_flags) & FL_ONGROUND);
  
  set_pev(entity, pev_origin, spawn_point[spawn_index][SPAWN_ORIGIN]);
  set_pev(entity, pev_view_ofs, {0.0, 0.0, VEC_VIEW});
  set_pev(entity, pev_angles, spawn_point[spawn_index][SPAWN_ANGLES]);
  set_pev(entity, pev_v_angle, spawn_point[spawn_index][SPAWN_V_ANGLE]);
  
  hologram_type = 3;
  set_rendering(entity, HOLOGRAM_DATA[hologram_type][RENDERFX], HOLOGRAM_DATA[hologram_type][RENDERCOLOR_RED], HOLOGRAM_DATA[hologram_type][RENDERCOLOR_GREEN], HOLOGRAM_DATA[hologram_type][RENDERCOLOR_BLUE], HOLOGRAM_DATA[hologram_type][RENDERMODE], HOLOGRAM_DATA[hologram_type][RENDERAMT]);

  spawn_point[spawn_index][SPAWN_ENTITY] = entity;
  ai_set_common_index(entity, spawn_index);

  return 1;
}

process_spawn_point()
{
  static need_show, entity,
         dominated_team,
         Float: captured_map_end_time,
         captured_spawns_t_percent,
         captured_spawns_ct_percent;

  captured_spawns[TEAM_TERRORIST] = 0;
  captured_spawns[TEAM_CT]        = 0;
  
  new is_capturing_spawn[MAX_CLIENTS + 1];
  
  for (new i; i < total_spawns; i++) {
    need_show = 0;
    entity    = spawn_point[i][SPAWN_ENTITY];
    
    if (is_valid_ent(entity)) {
#if defined MAPMANAGER_MODULE
      if (players_num >= 2 && sm_captured_map_end_delay > 0.0) {
        captured_spawns[spawn_point[i][SPAWN_TEAM]]++;
      }
#endif

      new invader;
      for (new id = 1; id <= max_players; id++) {
        if (is_connected(id)) {
          if (entity_range(entity, id) <= sm_spawn_enemy_distance) {
            need_show = 1;
          }

          if (is_spawn_capturable(i, id, sm_spawn_enemy_distance)) {
            if (!spawn_point[i][SPAWN_INVADER] || spawn_point[i][SPAWN_INVADER] == id) {
              if (!invader && !is_capturing_spawn[id]) {
                invader = id;
                is_capturing_spawn[id] = 1;
              }
            }
          }
          else if (spawn_point[i][SPAWN_INVADER] == id) {
            reset_capture_data(i, id);
          }
        }
      }

      if (invader) {
        try_capture_spawn_point(i, invader);
      }
      
      if (spawn_point[i][SPAWN_OWNER] && spawn_point[i][SPAWN_TEAM] != ai_get_team(spawn_point[i][SPAWN_OWNER])) {
        reset_captured_spawn(i, spawn_point[i][SPAWN_OWNER]);
      }
      
      if (need_show) {
        show_spawn_point_ent(i);
      }
      else {
        hide_spawn_point_ent(i);
      }
    }
  }

  if (is_maptime_expired || is_early_map_change) {
    return;
  }
  
  captured_spawns_ct_percent = captured_spawns[TEAM_CT] * 100 / total_spawns;
  captured_spawns_t_percent  = captured_spawns[TEAM_TERRORIST] * 100 / total_spawns;
  
  if (captured_spawns_ct_percent >= sm_captured_spawns_max_percent) {
    if (!dominated_team) {
      captured_map_end_time = ctime + sm_captured_map_end_delay;
    }
    
    dominated_team = TEAM_CT;
    
    if (ctime >= captured_map_end_time) {
      get_ml_status(SM_EARLY_ENDED_MAP_CT) && client_print_color (ALL, print_team_default, FMT_ML, LANG_PLAYER, get_ml_key(SM_EARLY_ENDED_MAP_CT), captured_spawns_ct_percent);
      is_maptime_expired  = 1;
      is_early_map_change = 1;
    }
    else {
      new timeleft = floatround(captured_map_end_time - ctime);
      
      if (timeleft) {
        set_hudmessage (220, 160, 0, -1.0, 0.80, 1, 0.0,  1.1, 0.0, 0.0, -1);
        ShowSyncHudMsg(ALL, hso_map_manager, FMT_ML, LANG_PLAYER, get_ml_key(MM_HUD_TEAM_CT_DOMINATING), timeleft, LANG_PLAYER, get_ending(timeleft, get_ml_key(WORD_ENDING_SECOND1), get_ml_key(WORD_ENDING_SECOND4), get_ml_key(WORD_ENDING_SECOND3)));
      }
    }
  }
  else if (captured_spawns_t_percent >= sm_captured_spawns_max_percent) {
    if (!dominated_team) {
      captured_map_end_time = ctime + sm_captured_map_end_delay;
    }
    
    dominated_team = TEAM_TERRORIST;
    
    if (ctime >= captured_map_end_time) {
      get_ml_status(SM_EARLY_ENDED_MAP_T) && client_print_color (ALL, print_team_default, FMT_ML, LANG_PLAYER, get_ml_key(SM_EARLY_ENDED_MAP_T), captured_spawns_t_percent);
      is_maptime_expired  = 1;
      is_early_map_change = 1;
    }
    else {
      new timeleft = floatround(captured_map_end_time - ctime);
      
      if (timeleft) {
        set_hudmessage (220, 160, 0, -1.0, 0.80, 1, 0.0,  1.1, 0.0, 0.0, -1);
        ShowSyncHudMsg(ALL, hso_map_manager, FMT_ML, LANG_PLAYER, get_ml_key(MM_HUD_TEAM_T_DOMINATING), timeleft, LANG_PLAYER, get_ending(timeleft, get_ml_key(WORD_ENDING_SECOND1), get_ml_key(WORD_ENDING_SECOND4), get_ml_key(WORD_ENDING_SECOND3)));
      }
    }
  }
  else {
    switch (dominated_team) {
      case TEAM_CT: {
        set_hudmessage (220, 160, 0, -1.0, 0.80, 1, 0.0,  10.0, 0.0, 0.0, -1);
        ShowSyncHudMsg(ALL, hso_map_manager, FMT_ML, LANG_PLAYER, get_ml_key(MM_HUD_TEAM_CT_STOP_DOMINATING));
      }
      case TEAM_TERRORIST: {
        set_hudmessage (220, 160, 0, -1.0, 0.80, 1, 0.0,  10.0, 0.0, 0.0, -1);
        ShowSyncHudMsg(ALL, hso_map_manager, FMT_ML, LANG_PLAYER, get_ml_key(MM_HUD_TEAM_T_STOP_DOMINATING));
        
      }
    }
    
    dominated_team = TEAM_UNASSIGNED;
  }
}

give_capture_bonus()
{
  static Float: next_give_capture_bonus_time;
  static entity, owner;
  new capture_bonus[MAX_CLIENTS + 1];
  
  if (ctime < next_give_capture_bonus_time) {
    return;
  }
  
  for (new i; i < total_spawns; i++) {
    entity = spawn_point[i][SPAWN_OWNER];

    if (is_valid_ent(entity)) {
      owner = ai_get_owner(entity);
      
      if (is_valid_client(owner)) {
        capture_bonus[owner] += sm_spawn_capture_bonus;
      }
    }
  }
  
  for (new i; i < pl_num; i++) {
    index = players[i];
    
    if (capture_bonus[index]) {
      add_money(index, capture_bonus[index], 1);
      capture_bonus[index] = 0;
    }
  }
  
  next_give_capture_bonus_time = ctime + sm_give_capture_bonus_delay;
}

get_bad_spawn(ignore_ent = 0)
{
  new tr_handle = create_tr2(), trace_result, bad_spawn_index = -1;
  
  for (new i; i < total_spawns; i++) {
    engfunc(EngFunc_TraceHull, spawn_point[i][SPAWN_ORIGIN], spawn_point[i][SPAWN_ORIGIN], DONT_IGNORE_MONSTERS, HULL_HUMAN, ignore_ent, tr_handle);
    
    if (get_tr2(tr_handle, TR_StartSolid)) {
      trace_result += 1;
    }
    
    if (get_tr2(tr_handle, TR_AllSolid)) {
      trace_result += 2;
    }
    
    if (!get_tr2(tr_handle, TR_InOpen)) {
      trace_result += 4;
    }
    
    if (get_tr2 (tr_handle, TR_pHit) != FM_NULLENT) {
      trace_result += 8;
    }

    if (trace_result) {
      bad_spawn_index = i;
      break;
    }
  }
  
  free_tr2(tr_handle);
  return bad_spawn_index;
}

stock generate_spawn_list (num_origins_to_find)
{
  if (!start_time) {
    start_time = last_time = get_systime();
    server_print("[Spawn Generator] Start generate spawnlist");
    
    num_find_origins = num_origins_to_find;
  
    if (num_find_origins > MAX_GENERATE_SPAWNS) {
      num_find_origins = MAX_GENERATE_SPAWNS;
    }

    test_ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
    
    if (test_ent > 0) {
      set_pev(test_ent, pev_classname, "origin_finder");
      set_pev(test_ent, pev_movetype, MOVETYPE_FLY);
      set_pev(test_ent, pev_solid, SOLID_BBOX);
      set_pev(test_ent, pev_maxs, max_size);
      set_pev(test_ent, pev_mins, min_size);
      set_pev(test_ent, pev_size, size);
      engfunc(EngFunc_SetSize, test_ent, min_size, max_size);

      end_time = SEARCH_TIME + start_time;
      
      total_spawns = 0;
      find_location();
    }
  }
}

stock find_location()
{
  static systime;
  
  start_find_location:
  spawn_origin[total_spawns][0] = random_float(-MAX_MAP_RANGE, MAX_MAP_RANGE);
  spawn_origin[total_spawns][Y] = random_float(-MAX_MAP_RANGE, MAX_MAP_RANGE);
  spawn_origin[total_spawns][2] = random_float(-MAX_MAP_RANGE, MAX_MAP_RANGE);
  
  for (j = 0; j < total_spawns; j++) {
    if (floatsqroot(((spawn_origin[total_spawns][0] - spawn_origin[j][0]) * (spawn_origin[total_spawns][0] - spawn_origin[j][0])) + ((spawn_origin[total_spawns][Y] - spawn_origin[j][Y]) * (spawn_origin[total_spawns][Y] - spawn_origin[j][Y]))) < MIN_DISTANCE) {
      goto start_find_location;
    }
  }
  
  systime = get_systime();
  
  if (systime <= end_time) {
    if (systime - last_time >= 1) {
      server_print("[Spawn Generator] Searching progress %d seconds. Tatal spawns: %d", systime - start_time, total_spawns);
      last_time = systime;
    }
    
    engfunc (EngFunc_SetOrigin, test_ent, spawn_origin[total_spawns]);
    
    t_origin[0] = spawn_origin[total_spawns][0];
    t_origin[Y] = spawn_origin[total_spawns][Y];
    t_origin[2] = -MAX_MAP_RANGE;

    engfunc(EngFunc_TraceLine, spawn_origin[total_spawns], t_origin, 0, test_ent, 0);
    get_tr2(0, TR_vecEndPos, spawn_origin[total_spawns]);

    spawn_origin[total_spawns][2] += 51.0;
    
    if (!trace_hull(spawn_origin[total_spawns], HULL_HUMAN, test_ent, DONT_IGNORE_MONSTERS)) {
      total_spawns++;
    }

    if (total_spawns < num_find_origins) {
      goto start_find_location;
    }
  }
  
  save_locations();
}

stock save_locations()
{
  server_print("[Spawn Generator] Found %d spawn locations in %f seconds.", total_spawns, get_systime() - start_time);
  engfunc(EngFunc_RemoveEntity, test_ent);
  start_time = end_time = test_ent = 0;
  
  for (new i; i < total_spawns; i++) {
    write_spawn_file(i);
  }
}

sm_client_disconnect(id)
{
  arrayset (spawn_visited[id], 0, sizeof spawn_visited[]);
  spawn_visited_num[id]   = 0;

  reset_all_captured_spawns(id);
  clr_bit(block_respawn, id);
  clr_bit(spawn_progress_bar, id);
}

sm_plugin_end()
{
  if (spawn_manager_enabled) {
    disable_spawn_manager();
  }
}
