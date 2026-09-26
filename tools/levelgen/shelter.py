"""Убежище — the shelter interior (scenes/shelter/Shelter.tscn).

The room changes with the shelter level: level 1 is a cold, cluttered flat (group
"shelter_level_1_only"), level 2 brings bunks, a rug, a heater and garlands, level 3 the radio
station, curtains and a lived-in corner (groups "shelter_level_2" / "shelter_level_3").
"""
from tscn import Scene, Col, NP, Rect, Tr
from builder import (Builder, S_LEVEL_DOOR, S_LOOT, S_PICK, S_EXAM, S_PHONE, S_BED, S_STATION, S_GEN, S_STOVE,
                     S_HEAT, S_LIGHT, S_SHELTER)

L1 = ["shelter_level_1_only"]
L2 = ["shelter_level_2"]
L3 = ["shelter_level_3"]


def shelter():
    s = Scene("Shelter", "Node3D", {
        "level_id": "shelter", "display_name": "Убежище", "is_interior": True,
        "heated_conditions": [{"any": [{"flag": "stove_lit"}, {"all": [{"flag": "generator_repaired"}, {"not_flag": "generator_failed"}]}]}],
        "bounds": Rect(-12, -9, 24, 18), "default_spawn": "default", "ambient_profile": "indoor",
    }, script="res://scripts/core/level.gd")
    b = Builder(s, indoor_snow=0.0)
    env = s.sub("Environment", {
        "background_mode": 1, "background_color": Col(0.0, 0.0, 0.0), "ambient_light_source": 2,
        "ambient_light_color": Col(0.3, 0.3, 0.38), "ambient_light_energy": 1.0, "tonemap_mode": 2,
        "ssao_enabled": True, "ssao_radius": 1.0, "ssao_intensity": 1.4, "glow_enabled": True, "glow_intensity": 0.6,
        "adjustment_enabled": True,
    })
    s.node("Environment", "WorldEnvironment", ".", {"environment": env})
    s.node("Lighting", "Node", ".", {"environment_path": NP("../Environment"), "outdoor": False}, script=S_LIGHT)
    s.node("ShelterController", "Node", ".", script=S_SHELTER)
    s.node("Moonlight", "SpotLight3D", ".", {"transform": Tr(-4.5, 2.7, -5.5, yaw=0, pitch=-58), "light_color": Col(0.55, 0.65, 1.0),
        "light_energy": 2.6, "spot_range": 9.0, "spot_angle": 42.0, "shadow_enabled": True})

    geo = s.node("Geometry", "Node3D", ".")
    wall = (0.56, 0.5, 0.44)
    inner = (0.5, 0.46, 0.4)
    b.block(geo, "Floor", (0, -0.1, 0), (18.6, 0.1, 12.6), (0.36, 0.26, 0.18), snow_mask=0.0, fadeable=False, material="parquet")
    b.block(geo, "FloorStorage", (6, 0, -3), (5.8, 0.02, 5.8), (0.38, 0.38, 0.4), snow_mask=0.0, has_collision=False, fadeable=False, material="concrete")
    b.block(geo, "FloorWorkshop", (6, 0, 3), (5.8, 0.02, 5.8), (0.34, 0.32, 0.3), snow_mask=0.0, has_collision=False, fadeable=False, material="planks")
    b.walls(geo, "", -9, -6, 9, 6, 3.0, wall, [("s", 0, 2.0)], cut_sides=(), low_sides={"s": 1.0}, material="wallpaper", snow=0.0)
    b.block(geo, "Baseboard", (0, 0, -5.82), (18, 0.14, 0.06), (0.3, 0.22, 0.16), snow_mask=0.0, has_collision=False, fadeable=False, material="planks")
    # Interior partitions.
    for (name, pos, size, mat) in (("WallMid1", (3, 0, -4.9), (0.25, 3.0, 2.2), "plaster"), ("WallMid2", (3, 0, -0.1), (0.25, 3.0, 3.6), "plaster"),
                                   ("WallMid3", (3, 0, 4.9), (0.25, 1.0, 2.2), "plaster"), ("WallStorageW", (4.1, 0, 0), (2.2, 1.2, 0.25), "brick"),
                                   ("WallStorageE", (8.1, 0, 0), (1.8, 1.2, 0.25), "brick"), ("WallRadioN1", (-7.8, 0, 1.5), (2.4, 3.0, 0.25), "wallpaper"),
                                   ("WallRadioN2", (-3.9, 0, 1.5), (1.8, 3.0, 0.25), "wallpaper"), ("WallRadioE", (-3, 0, 4.4), (0.25, 1.0, 3.2), "wallpaper")):
        b.block(geo, name, pos, size, inner, snow_mask=0.0, material=mat)

    P = s.node("Props", "Node3D", ".")
    b.prop(P, "bed", (-7.6, 0, -4.4))
    b.prop(P, "window", (-4.5, 1.7, -5.64), lit=True, light_color=(0.45, 0.55, 0.85), has_collision=False)
    b.prop(P, "phone", (-1.4, 0, -5.4))
    b.prop(P, "table", (-2.2, 0, -1.6))
    b.prop(P, "chair", (-2.2, 0, -0.6), yaw=180)
    b.prop(P, "chair", (-3.3, 0, -1.9), yaw=80, groups=L2)
    b.prop(P, "candle", (-2.4, 0.83, -1.6), lit=True, light_energy=1.8, light_range=8.5)
    b.prop(P, "stove", (1.7, 0, -5.3), lit=False, light_energy=1.8, light_range=8.0, groups=["shelter_stove"])
    b.prop(P, "counter", (-8.4, 0, -1.4), yaw=90)
    b.prop(P, "board", (-8.9, 0, 0.6), yaw=90, color=(0.8, 0.8, 0.78))
    b.block(P, "RedCross", (-8.83, 1.45, 0.6), (0.05, 0.25, 0.08), (0.9, 0.1, 0.1), snow_mask=0.0, has_collision=False, material="paint")
    b.prop(P, "ceiling_lamp", (-5, 0, -2), lit=True, light_color=(1.0, 0.85, 0.65), light_energy=1.5, light_range=8.5, groups=["power_light"])
    b.prop(P, "ceiling_lamp", (0, 0, 2.5), lit=True, light_color=(1.0, 0.85, 0.65), light_energy=1.3, light_range=7.5, groups=["power_light"])
    b.prop(P, "ceiling_lamp", (6, 0, -3), lit=True, light_color=(1.0, 0.9, 0.75), light_energy=1.1, light_range=6.5, groups=["power_light"])
    b.prop(P, "door_frame", (0, 0, 5.95), color=(0.28, 0.22, 0.16), has_collision=False)
    b.prop(P, "wardrobe", (2.3, 0, 5.45), yaw=180, color=(0.36, 0.42, 0.36))
    b.block(P, "CDSign", (2.3, 1.55, 5.14), (0.3, 0.3, 0.04), (0.85, 0.72, 0.2), snow_mask=0.0, has_collision=False, material="paint")
    b.block(P, "Calendar", (2.86, 1.5, 0.2), (0.02, 0.5, 0.38), (0.9, 0.88, 0.82), snow_mask=0.0, has_collision=False, material="cardboard")
    b.block(P, "CalendarMark", (2.84, 1.45, 0.25), (0.02, 0.08, 0.08), (0.8, 0.1, 0.1), snow_mask=0.0, has_collision=False, material="paint")
    # Storage.
    b.prop(P, "shelf", (8.4, 0, -3.2), yaw=-90)
    b.prop(P, "shelf", (4.4, 0, -5.4))
    b.prop(P, "crate", (6.4, 0, -5.3), size=(2.2, 1.4, 1.2), color=(0.34, 0.3, 0.24))
    b.prop(P, "generator", (7.8, 0, -1.0), lit=False, groups=["shelter_generator"])
    # Workshop.
    b.prop(P, "workbench", (6, 0, 5.3), yaw=180)
    b.prop(P, "board", (8.9, 0, 2.6), yaw=-90)
    b.prop(P, "ceiling_lamp", (6, 0, 3), lit=True, light_color=(1.0, 0.95, 0.8), light_energy=1.4, light_range=7.0, groups=["power_light", "shelter_level_2"])
    b.prop(P, "shelf", (3.5, 0, 3.0), yaw=90, groups=L2)
    b.prop(P, "crate", (8.2, 0, 4.8), size=(0.9, 0.8, 0.9), color=(0.25, 0.3, 0.35), groups=L2)
    b.prop(P, "tool_wall", (8.95, 0, 4.4), yaw=-90, groups=L2)
    # Radio room.
    b.prop(P, "radio_set", (-8.3, 0, 3.6), yaw=90, lit=False, groups=["shelter_radio"])
    b.prop(P, "table", (-6.5, 0, 5.2), size=(1.2, 1, 1))
    b.prop(P, "tape_recorder", (-6.2, 0.82, 5.2))
    b.prop(P, "candle", (-6.9, 0.82, 5.3), lit=True, light_energy=1.0, light_range=5.0)
    b.prop(P, "candle", (-8.4, 1.05, -2.1), lit=True, light_energy=0.9, light_range=5.5)
    b.prop(P, "transmitter", (-5.0, 0, 5.4), yaw=180, groups=L3)
    b.prop(P, "antenna", (-8.0, 0, 5.3), size=(1, 0.4, 1), groups=L3, has_collision=False)
    b.prop(P, "ceiling_lamp", (-6, 0, 3.5), lit=True, light_color=(0.9, 1.0, 0.9), light_energy=0.9, light_range=5.0, groups=["power_light", "shelter_level_3"])

    # --- Level 1: the flat as the snow found it -------------------------------------------------
    b.prop(P, "rubble", (4.8, 0, 2.2), groups=L1)
    b.prop(P, "boxes", (-1.8, 0, 4.9), groups=L1)
    b.prop(P, "trash_bags", (-8.0, 0, 5.0), groups=L1)
    b.prop(P, "boxes", (-4.0, 0, 2.4), yaw=40, color=(0.5, 0.42, 0.3), groups=L1)
    b.block(P, "Bucket", (-5.6, 0, -0.4), (0.4, 0.42, 0.4), (0.45, 0.47, 0.5), shape="cylinder", snow_mask=0.0, material="metal", groups=L1)
    b.block(P, "Puddle", (-5.6, 0.005, -0.4), (1.2, 0.01, 0.9), (0.2, 0.24, 0.3), snow_mask=0.0, has_collision=False, fadeable=False, material="ice", groups=L1)
    b.block(P, "Cardboard", (-1.2, 0.01, 2.2), (1.4, 0.02, 1.0), (0.55, 0.45, 0.3), yaw=15, snow_mask=0.0, has_collision=False, fadeable=False, material="cardboard", groups=L1)
    b.block(P, "Planks", (8.4, 0, 0.9), (0.2, 2.2, 1.2), (0.48, 0.36, 0.24), yaw=0, snow_mask=0.0, material="planks", groups=L1)
    b.prop(P, "paper", (0.8, 0.01, -2.4), yaw=20, has_collision=False, groups=L1)
    b.prop(P, "paper", (-6.6, 0.01, 1.0), yaw=70, has_collision=False, groups=L1)

    # --- Level 2: a place people live in -----------------------------------------------------------
    b.prop(P, "bunk_bed", (1.9, 0, 1.8), groups=L2)
    b.block(P, "Rug", (-2.2, 0.012, -1.4), (3.2, 0.02, 2.2), (0.5, 0.2, 0.18), snow_mask=0.0, has_collision=False, fadeable=False, material="fabric", groups=L2)
    b.block(P, "RugBorder", (-2.2, 0.01, -1.4), (3.5, 0.02, 2.5), (0.75, 0.6, 0.35), snow_mask=0.0, has_collision=False, fadeable=False, material="fabric", groups=L2)
    b.prop(P, "string_lights", (-2.5, 0, -5.6), size=(1.5, 1, 1), lit=True, groups=["power_light", "shelter_level_2"])
    b.prop(P, "heater", (-0.4, 0, -5.55), lit=True, groups=["power_light", "shelter_level_2"])
    b.prop(P, "plant", (-3.3, 0, -5.45), groups=L2)
    b.prop(P, "sofa", (-1.9, 0, 3.4), yaw=180, color=(0.32, 0.36, 0.3), groups=L2)
    b.prop(P, "boxes", (4.3, 0, -3.6), color=(0.4, 0.5, 0.35), groups=L2)

    # --- Level 3: the station and a home ------------------------------------------------------------
    b.prop(P, "bookshelf", (-6.0, 0, -5.7), groups=L3)
    b.prop(P, "string_lights", (-6.0, 0, 5.7), size=(1.3, 1, 1), lit=True, groups=["power_light", "shelter_level_3"])
    b.prop(P, "string_lights", (6.0, 0, 5.75), size=(1.2, 1, 1), lit=True, groups=["power_light", "shelter_level_3"])
    b.prop(P, "plant", (8.2, 0, 3.8), groups=L3)
    b.prop(P, "plant", (-8.5, 0, -0.1), groups=L3)
    b.block(P, "CurtainL", (-5.35, 1.1, -5.8), (0.4, 1.7, 0.05), (0.55, 0.28, 0.22), snow_mask=0.0, has_collision=False, fadeable=False, material="fabric", groups=L3)
    b.block(P, "CurtainR", (-3.65, 1.1, -5.8), (0.4, 1.7, 0.05), (0.55, 0.28, 0.22), snow_mask=0.0, has_collision=False, fadeable=False, material="fabric", groups=L3)
    b.block(P, "MapBoard", (-8.93, 1.0, 3.4), (0.04, 1.1, 1.5), (0.78, 0.74, 0.62), snow_mask=0.0, has_collision=False, fadeable=False, material="cardboard", groups=L3)
    for (z, y, c) in ((3.0, 1.8, (0.9, 0.2, 0.15)), (3.7, 1.4, (0.2, 0.7, 0.3)), (3.3, 1.2, (0.9, 0.8, 0.2))):
        b.block(P, "Pin", (-8.9, y, z), (0.04, 0.07, 0.07), c, snow_mask=0.0, has_collision=False, fadeable=False, material="plastic", groups=L3)

    Z = s.node("Zones", "Node3D", ".")
    b.area(Z, "StoveHeat", S_HEAT, (1.7, 0, -4.3), {"strength": 1.2, "active_flag": "stove_lit"}, shape=("sphere", 2.6))

    I = s.node("Interactables", "Node3D", ".")
    b.area(I, "Bed", S_BED, (-7.6, 0, -3.2), {"conditions": [{"any": [{"flag": "first_squall_done"}, {"day_min": 2}, {"hour_between": [23, 7]}]}],
        "requirement_text": "Не уснуть. Сначала нужно понять, что происходит снаружи."}, shape=("box", (1.6, 2, 2.4)))
    b.area(I, "Phone", S_PHONE, (-1.4, 0, -4.7), {"display_name": "Телефон", "interaction_text": "Ответить", "dialogue_id": "intro_phone",
        "available_if": [{"not_flag": "phone_answered"}]}, shape=("box", (1.4, 2, 1.4)))
    b.area(I, "PhoneDead", S_EXAM, (-1.4, 0, -4.7), {"display_name": "Телефон", "interaction_text": "Снять трубку", "title": "Телефон",
        "text": "Тишина. Даже гудка нет. Сообщение Элиаса осталось на автоответчике — оно в журнале [Q].", "available_if": [{"flag": "phone_answered"}]}, shape=("box", (1.4, 2, 1.4)))
    b.area(I, "WindowIntro", S_EXAM, (-4.5, 0, -5.1), {"display_name": "Окно", "interaction_text": "Посмотреть", "dialogue_id": "intro_window",
        "available_if": [{"flag": "phone_answered"}, {"not_flag": "intro_done"}]}, shape=("box", (2.0, 2, 1.4)))
    b.area(I, "Window", S_EXAM, (-4.5, 0, -5.1), {"display_name": "Окно", "interaction_text": "Посмотреть", "dialogue_id": "window_view",
        "available_if": [{"flag": "intro_done"}]}, shape=("box", (2.0, 2, 1.4)))
    b.loot(I, "Kitchen", (-7.8, 0, -1.4), "Кухонный шкаф", items={"canned_food": 1, "water_bottle": 1})
    b.loot(I, "FirstAid", (-8.2, 0, 0.7), "Аптечка", items={"bandage": 1, "medicine": 1}, shape=(1.4, 2, 1.2))
    b.pick(I, "Flashlight", (7.7, 0.3, -3.5), "flashlight")
    b.loot(I, "CDLocker", (2.3, 0, 4.7), "Шкафчик ГО", items={"filter_standard": 1, "filter_old": 1, "iodine_pills": 1}, interaction_text="Открыть",
           found_text="Жёлтая наклейка «Средства защиты». Внутри — то, что раздавали в первую неделю.",
           container_hint="Фильтры вставляются в маску из рюкзака: [I] → «Вставить в маску».", shape=(1.4, 2, 1.2))
    b.loot(I, "StorageShelf", (4.4, 0, -4.7), "Полки", items={"cloth": 1}, shape=(1.8, 2, 1.2))
    b.area(I, "Storage", S_STATION, (6.4, 0, -4.4), {"display_name": "Склад", "interaction_text": "Открыть", "panel": "storage", "station_id": "storage"}, shape=("box", (2.2, 2, 1.2)))
    b.area(I, "Generator", S_GEN, (7.3, 0, -1.6), {}, shape=("box", (1.8, 2, 1.2)))
    b.area(I, "Stove", S_STOVE, (1.7, 0, -4.6), {}, shape=("box", (1.4, 2, 1.2)))
    b.area(I, "Workbench", S_STATION, (6, 0, 4.5), {"display_name": "Верстак", "interaction_text": "Мастерская", "panel": "crafting", "station_id": "workbench",
        "available_if": [{"flag": "intro_done"}]}, shape=("box", (2.2, 2, 1.2)))
    b.area(I, "UpgradeBoard", S_STATION, (8.3, 0, 2.6), {"display_name": "План убежища", "interaction_text": "Улучшения", "panel": "shelter", "station_id": "shelter",
        "available_if": [{"flag": "intro_done"}]}, shape=("box", (1.2, 2, 1.8)))
    b.area(I, "RadioBasic", S_STATION, (-7.6, 0, 3.6), {"display_name": "Радиоприёмник", "interaction_text": "Включить радио", "panel": "radio", "station_id": "shelter_basic",
        "available_if": [{"not": {"shelter_level_min": 3}}, {"flag": "intro_done"}], "consequences": [{"set_flag": "shelter_radio_used"}]}, shape=("box", (1.2, 2, 1.6)))
    b.area(I, "RadioStation", S_STATION, (-7.6, 0, 3.6), {"display_name": "Радиостанция", "interaction_text": "Сканировать эфир", "panel": "radio", "station_id": "shelter_station",
        "available_if": [{"shelter_level_min": 3}]}, shape=("box", (1.2, 2, 1.6)))
    b.area(I, "Transmitter", S_EXAM, (-5.0, 0, 4.6), {"display_name": "Передатчик", "interaction_text": "Выйти в эфир", "dialogue_id": "transmitter",
        "available_if": [{"shelter_level_min": 3}]}, shape=("box", (1.6, 2, 1.2)))
    b.area(I, "Exit", S_LEVEL_DOOR, (0, 0, 5.3), {"display_name": "Выход на улицу", "interaction_text": "Выйти", "target_level": "district", "target_spawn": "shelter_door",
        "required_flag": "intro_done", "requirement_text": "Сначала нужно понять, что происходит."}, shape=("box", (2.2, 2, 1.4)))
    b.exam(I, "Calendar", (2.2, 0, 0.2), "Календарь",
           "Отрывной календарь застыл на 3 ноября. Дата обведена красным: «Эфир, 19:00. Не опоздать!» "
           "Вы не опоздали. Эфира просто не было.", shape=(1.0, 2.0, 1.2), label="Календарь")
    b.exam(I, "Tapes", (-6.3, 0, 4.9), "Кассеты с эфирами",
           "Коробка кассет, подписанных вашей рукой: «Утро с Алексом, выпуск 212», «…213». Последняя — пустая, "
           "с наклейкой «Для нового эфира». Может, ещё пригодится.", shape=(1.0, 2.0, 1.0), label="Кассеты")
    b.exam(I, "Leak", (-5.6, 0, -0.4), "Капель",
           "С потолка капает талая вода — сверху кто-то ещё топит. Или топил. Ведро наполовину полное, вода подёрнулась льдом.",
           shape=(1.2, 2.0, 1.2), label="Ведро под капелью", available_if=[{"not": {"shelter_level_min": 2}}], hide_when_unavailable=True)

    SP = s.node("Spawns", "Node3D", ".")
    for (name, pos, yaw) in (("spawn_start", (-6.4, 0, -2.6), 0), ("spawn_default", (0, 0, 4.1), 0),
            ("npc_shelter_mara", (-4.2, 0, 0.6), 180), ("npc_shelter_elias", (5.0, 0, 1.6), 90), ("npc_shelter_vera", (-5.8, 0, 3.2), 90),
            ("npc_shelter_anton", (0.6, 0, -2.6), 0), ("npc_shelter_tomas", (5.4, 0, -2.4), 0), ("npc_shelter_grey", (-0.6, 0, 3.6), 0)):
        b.marker(SP, name, pos, yaw)
    s.node("Actors", "Node3D", ".")
    b.report("Shelter")
    return s
