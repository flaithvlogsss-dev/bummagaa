"""Квартал 9 — the outdoor district (scenes/world/District.tscn).

Layout (x → east, z → south; the camera looks north, so +Z faces are the visible ones):
  main street z -5..5 · Дом 12 (shelter) north-west · narrow street → small square · pharmacy and
  the radio station with its mast north-east · Дом 7 flats, the shop, the alley south-west ·
  garages, parking and the substation south-east · courtyard with the tent camp north-west.
"""
import math, random
from tscn import Scene, V3, Col, NP, Rect, Tr
from builder import (Builder, S_PICK, S_LEVEL_DOOR, S_LOOT, S_EXAM, S_HIDE, S_STATION, S_LOC, S_INDOOR, S_HEAT,
                     S_LIGHT, S_SPAWNER, S_INFO)

WALK = (0.42, 0.43, 0.46)
ASPHALT = (0.2, 0.21, 0.23)
ROAD = dict(has_collision=False, fadeable=False, cast_shadows=False)
FLAT = dict(has_collision=False, fadeable=False, cast_shadows=False)


def district():
    random.seed(9)
    s = Scene("District", "Node3D", {
        "level_id": "district", "display_name": "Квартал 9", "is_interior": False,
        "bounds": Rect(-80, -66, 160, 122), "default_spawn": "shelter_door", "ambient_profile": "outdoor",
    }, script="res://scripts/world/district.gd")
    b = Builder(s)
    env = s.sub("Environment", {
        "background_mode": 1, "background_color": Col(0.1, 0.1, 0.16), "ambient_light_source": 2,
        "ambient_light_color": Col(0.12, 0.13, 0.2), "ambient_light_energy": 1.0, "tonemap_mode": 2,
        "ssao_enabled": True, "ssao_radius": 1.5, "ssao_intensity": 1.4, "glow_enabled": True,
        "glow_intensity": 0.55, "glow_bloom": 0.05, "fog_enabled": True, "fog_light_color": Col(0.1, 0.1, 0.16),
        "fog_density": 0.025, "fog_sky_affect": 1.0, "volumetric_fog_enabled": True,
        "volumetric_fog_density": 0.006, "volumetric_fog_albedo": Col(0.9, 0.92, 1.0),
        "volumetric_fog_length": 48.0, "adjustment_enabled": True,
    })
    s.node("Environment", "WorldEnvironment", ".", {"environment": env})
    s.node("Sun", "DirectionalLight3D", ".", {"transform": Tr(0, 30, 0, yaw=35, pitch=-52), "light_color": Col(0.6, 0.7, 1.0),
        "light_energy": 0.2, "shadow_enabled": True, "directional_shadow_max_distance": 70.0})
    s.node("Lighting", "Node", ".", {"environment_path": NP("../Environment"), "sun_path": NP("../Sun"), "outdoor": True}, script=S_LIGHT)

    nav = s.sub("NavigationMesh", {"geometry_parsed_geometry_type": 1, "cell_size": 0.25, "cell_height": 0.25,
        "agent_height": 2.0, "agent_radius": 0.5, "agent_max_climb": 0.25})
    s.node("NavRegion", "NavigationRegion3D", ".", {"navigation_mesh": nav})
    G = s.node("Ground", "Node3D", "NavRegion")
    R = s.node("Roads", "Node3D", "NavRegion")
    B = s.node("Buildings", "Node3D", "NavRegion")
    P = s.node("Props", "Node3D", "NavRegion")
    D = s.node("Decals", "Node3D", ".")
    I = s.node("Interactables", "Node3D", ".")

    ground(b, G, R, D)
    shelter_block(b, B, P, I)
    north_side(b, B, P, I)
    square(b, B, P, I)
    pharmacy(b, B, P, I)
    radio_station(b, B, P, I)
    house7(b, B, P, I)
    shop(b, B, P, I)
    alley(b, B, P, I, D)
    south_side(b, B, P, I)
    garages(b, B, P, I, D)
    main_street(b, P, I, D)
    courtyard(b, B, P, I)
    edges(b, s, P, I)
    zones(b, s)
    spawns(b, s)
    b.report("District")
    return s


# =====================================================================================
# Ground, roads, decals
# =====================================================================================

def ground(b, G, R, D):
    b.block(G, "Snow", (0, -0.2, -5), (260, 0.2, 230), (0.8, 0.83, 0.88), material="snow", fadeable=False, cast_shadows=False)
    b.block(R, "MainStreet", (0, 0, 0), (170, 0.03, 10), ASPHALT, snow_mask=0.55, material="asphalt", **ROAD)
    b.block(R, "SidewalkN", (0, 0, -6.5), (170, 0.045, 3), WALK, snow_mask=0.8, material="sidewalk", **ROAD)
    b.block(R, "SidewalkS", (0, 0, 6.5), (170, 0.045, 3), WALK, snow_mask=0.8, material="sidewalk", **ROAD)
    b.block(R, "CurbN", (0, 0, -5.05), (170, 0.12, 0.2), (0.5, 0.5, 0.52), snow_mask=0.9, material="concrete", **ROAD)
    b.block(R, "CurbS", (0, 0, 5.05), (170, 0.12, 0.2), (0.5, 0.5, 0.52), snow_mask=0.9, material="concrete", **ROAD)
    b.block(R, "NarrowStreet", (0, 0, -19), (7, 0.03, 20), ASPHALT, snow_mask=0.6, material="asphalt", **ROAD)
    b.block(R, "Square", (0, 0, -44), (40, 0.035, 28), (0.42, 0.41, 0.42), snow_mask=0.75, material="cobble", **ROAD)
    b.block(R, "NorthRoad", (0, 0, -63), (8, 0.03, 8), ASPHALT, snow_mask=0.7, material="asphalt", **ROAD)
    b.block(R, "Alley", (-38, 0, 27), (6, 0.03, 38), (0.32, 0.31, 0.32), snow_mask=0.65, material="slush", **ROAD)
    b.block(R, "PharmacyPath", (22, 0, -46), (4, 0.035, 16), WALK, snow_mask=0.8, material="sidewalk", **ROAD)
    b.block(R, "Lane", (-49, 0, -30.5), (58, 0.03, 5), WALK, snow_mask=0.92, material="sidewalk", **ROAD)
    b.block(R, "Passage", (-39.25, 0, -18.5), (3.5, 0.03, 19), WALK, snow_mask=0.9, material="sidewalk", **ROAD)
    b.block(R, "WestPath", (-71, 0, -20.5), (5, 0.03, 25), (0.5, 0.5, 0.52), snow_mask=0.95, material="snow", **ROAD)
    b.block(R, "RadioYard", (33, 0, -23), (22, 0.035, 26), (0.45, 0.45, 0.47), snow_mask=0.85, material="concrete", **ROAD)
    b.block(R, "GarageLane", (41.5, 0, 24), (7, 0.03, 32), ASPHALT, snow_mask=0.75, material="asphalt", **ROAD)
    b.block(R, "Parking", (55, 0, 47), (50, 0.03, 14), ASPHALT, snow_mask=0.7, material="asphalt", **ROAD)
    b.block(R, "GarageApron", (62, 0, 39.5), (32, 0.035, 2), (0.45, 0.45, 0.47), snow_mask=0.8, material="concrete", **ROAD)
    b.block(R, "BoilerPath", (2, 0, 21), (3, 0.03, 26), WALK, snow_mask=0.9, material="sidewalk", **ROAD)
    b.block(R, "Playground", (-62, 0, -45), (11, 0.03, 9), (0.4, 0.3, 0.26), snow_mask=0.95, material="dirt", **ROAD)
    # Road markings, crosswalks, manholes.
    for x in (-70, -50, -30, -10, 10, 30, 50, 70):
        b.prop(D, "road_line", (x, 0, 0), size=(1, 1, 1), has_collision=False)
    for x in (0, -51.5, 41.5):
        b.prop(D, "crosswalk", (x, 0, 0), size=(0.9, 1, 1), has_collision=False)
    for (x, z) in ((-20, -2.2), (15, 2.0), (52, -1.4), (-62, 2.4), (-6, -40)):
        b.prop(D, "manhole", (x, 0, z), has_collision=False)
    # Stains: oil (black), soot, dried blood (dark red), meltwater (slush).
    stains = [((-10, 0, 2.8), (0.08, 0.07, 0.07), 1.2), ((26, 0, 1.2), (0.08, 0.07, 0.07), 1.0), ((64, 0, 3.5), (0.08, 0.07, 0.07), 1.8),
              ((66, 0, -4.2), (0.28, 0.06, 0.05), 0.9), ((0, 0, -44), (0.12, 0.1, 0.09), 1.6), ((15, 0, 2.0), (0.34, 0.36, 0.38), 1.5),
              ((-72, 0, -51), (0.12, 0.1, 0.09), 1.2), ((31, 0, 1.2), (0.3, 0.07, 0.06), 0.6), ((52, 0, 42.5), (0.28, 0.06, 0.05), 0.7)]
    for pos, c, sc in stains:
        b.prop(D, "stain", pos, color=c, size=(sc, 1, sc), has_collision=False)
    for (x, z, yaw) in ((-40, -6.2, 10), (5, -40, 40), (12, 6.4, -20), (-58, -8.4, 70), (-6, -36.5, 0), (46, 44, 30), (33, -12, 15)):
        b.prop(D, "paper", (x, 0, z), yaw=yaw, has_collision=False)


# =====================================================================================
# Дом 12 — the shelter building (interior is the Shelter level)
# =====================================================================================

def shelter_block(b, B, P, I):
    b.building(B, "Shelter", -62, -28, -41, -10, 11, (0.46, 0.28, 0.22), material="brick", floors=4,
               trim_color=(0.62, 0.6, 0.56), roof_type="gable", roof_color=(0.26, 0.22, 0.22), window_faces="swe",
               lit_windows=0.1, boarded_windows=0.12, balconies=0.3, has_entrance=True, entrance_x=0, seed_value=12,
               show_on_map=True, map_label="Дом 12", fade="shelter12")
    b.prop(P, "lamp", (-47, 0, -7.2), lit=True, flicker=True, light_color=(1.0, 0.7, 0.4), light_energy=1.6, light_range=9.0, light_shadows=True)
    b.prop(P, "bench", (-56, 0, -8.4))
    b.prop(P, "bin", (-44.2, 0, -8.6), yaw=0)
    b.prop(P, "bike", (-58.5, 0, -9.5), yaw=10, color=(0.55, 0.2, 0.2))
    b.prop(P, "drift", (-58.6, 0, -9.4), size=(1.8, 0.7, 1.2), has_collision=False)
    b.area(I, "ShelterDoor", S_LEVEL_DOOR, (-51.5, 0, -9.2), {"display_name": "Дом 12 — убежище", "interaction_text": "Войти",
        "target_level": "shelter", "target_spawn": "default"}, shape=("box", (2.4, 2.4, 1.6)))
    b.hide(I, "ShelterBin", (-44.2, 0, -7.8), "Мусорный бак", shape=(2.0, 2.0, 1.4))


# =====================================================================================
# North side of the main street: Дом 10, Дом 5, Дом 6, Дом 3, Дом 16
# =====================================================================================

def north_side(b, B, P, I):
    b.building(B, "Dom10", -37.5, -26, -23, -10, 9, (0.62, 0.55, 0.4), material="plaster", floors=3,
               trim_color=(0.68, 0.64, 0.56), window_faces="sw", shop_front=True, sign_color=(0.52, 0.3, 0.22),
               has_entrance=True, entrance_x=4.5, balconies=0.35, lit_windows=0.08, seed_value=10,
               show_on_map=True, map_label="Дом 10", fade="dom10")
    b.building(B, "BuildingA", -22, -28, -3.5, -9, 9, (0.42, 0.45, 0.5), material="concrete", floors=3,
               trim_color=(0.6, 0.62, 0.64), window_faces="se", shop_front=True, sign_color=(0.25, 0.4, 0.44),
               has_entrance=True, entrance_x=-6, seed_value=5, show_on_map=True, map_label="Дом 5", fade="bldA")
    b.building(B, "BuildingB", 3.5, -28, 22, -9, 8, (0.48, 0.36, 0.3), material="brick", floors=3,
               trim_color=(0.62, 0.58, 0.52), roof_type="gable", roof_color=(0.26, 0.2, 0.18), window_faces="sw",
               balconies=0.35, has_entrance=True, entrance_x=4, lit_windows=0.1, seed_value=6,
               show_on_map=True, map_label="Дом 6", fade="bldB")
    b.building(B, "House3", -46, -56, -24, -33, 12, (0.45, 0.5, 0.44), material="plaster", floors=4,
               trim_color=(0.62, 0.64, 0.6), window_faces="se", has_entrance=True, entrance_x=5, balconies=0.3,
               seed_value=3, show_on_map=True, map_label="Дом 3", fade="house3")
    b.building(B, "Dom16", 46, -33, 70, -15, 10, (0.5, 0.5, 0.54), material="concrete", floors=3,
               trim_color=(0.64, 0.64, 0.66), window_faces="sw", shop_front=True, sign_color=(0.3, 0.35, 0.5),
               has_entrance=True, entrance_x=-6, seed_value=16, show_on_map=True, map_label="Дом 16", fade="east1")
    # Street furniture along the north side.
    b.prop(P, "ac_unit", (-33.5, 5.5, -9.95), color=(0.7, 0.72, 0.72))
    b.prop(P, "ac_unit", (-11.1, 4.4, -8.95))
    b.prop(P, "ac_unit", (14.4, 3.4, -8.95))
    b.prop(P, "street_sign", (-3.9, 0, -8.7), color=(0.2, 0.32, 0.55))
    b.prop(P, "hydrant", (20.5, 0, -8.4))
    b.prop(P, "billboard", (58, 0, -12.5), color=(0.62, 0.3, 0.22))
    b.exam(I, "Billboard", (58, 0, -11.2), "Рекламный щит",
           "«ЗИМА — ВРЕМЯ ДЛЯ СЕМЬИ», — улыбается нарисованная семья у камина. Поверх, красным баллончиком, "
           "в полный рост: «ГДЕ ВЫ ВСЕ?» Краска потекла и замёрзла сосульками.", shape=(5.0, 2.0, 1.6), label="Рекламный щит")
    b.prop(P, "bench", (-30, 0, -8.6))
    b.prop(P, "planter", (-17, 0, -8.5), size=(1.4, 1, 1))
    b.prop(P, "planter", (-8, 0, -8.5), size=(1.4, 1, 1))
    b.prop(P, "bike", (9.5, 0, -8.5), yaw=-8)
    b.prop(P, "trash_bags", (23.2, 0, -8.4))
    b.loot(I, "Dom10Door", (-25.75, 0, -9.0), "Подъезд дома 10", "trash", interaction_text="Обыскать", shape=(1.8, 2.0, 1.4),
           found_text="В подъезде пахнет гарью. Под лестницей — чьи-то брошенные пакеты.")
    b.hide(I, "PassageBin", (-39.2, 0, -12.5), "Мусорный бак", shape=(1.4, 2.0, 2.0))
    b.prop(P, "bin", (-39.9, 0, -12.5), yaw=90)
    b.exam(I, "ShopBread", (-33, 0, -9.0), "Витрина «Хлеб»",
           "За мутным стеклом — пустые лотки и ценник: «Батон — 42». Кто-то пальцем вывел на инее: «ВСЁ ВЫНЕСЛИ 4.11».",
           shape=(2.6, 2.0, 1.4), label="Витрина булочной")


# =====================================================================================
# Small square, narrow street, north road
# =====================================================================================

def square(b, B, P, I):
    b.prop(P, "barrel_fire", (0, 0, -44), lit=True, light_energy=1.6, light_range=9.0)
    b.prop(P, "bench", (-3.6, 0, -44), yaw=90)
    b.prop(P, "bench", (3.6, 0, -44), yaw=-90)
    b.prop(P, "bench", (0, 0, -47.6))
    b.prop(P, "notice_board", (-9, 0, -32.2))
    b.prop(P, "pallet", (-17, 0, -46))
    b.prop(P, "pine", (-17, 0, -57))
    b.prop(P, "pine", (-17.5, 0, -33), size=(1, 0.8, 1))
    b.prop(P, "kiosk", (12, 0, -53), lit=True)
    b.prop(P, "antenna", (16, 0, -56), size=(1, 1.3, 1))
    b.prop(P, "crate", (14.3, 0, -51.9), color=(0.3, 0.33, 0.4), size=(0.8, 1.2, 0.8))
    b.prop(P, "lamp", (18, 0, -31), lit=True, light_color=(0.75, 0.85, 1.0), light_energy=1.2, light_range=10.0)
    b.prop(P, "bin", (-18.4, 0, -41), yaw=90)
    b.prop(P, "fountain", (-9, 0, -50))
    b.prop(P, "snowman", (6, 0, -47.5), lit=True)
    b.prop(P, "loudspeaker", (-14, 0, -34.5))
    b.prop(P, "phone_booth", (17, 0, -34.5))
    b.prop(P, "kiosk", (-14, 0, -55), lit=False, name="NewsKiosk")
    # Civil defence point: locker, a tent and the queue that never reached it.
    b.prop(P, "wardrobe", (8.6, 0, -38.8), yaw=90, color=(0.36, 0.42, 0.36))
    b.prop(P, "tent", (11.5, 0, -39), yaw=90, color=(0.34, 0.4, 0.3), size=(1.5, 1, 1))
    queue = [("suitcase", (6.0, -36.3), 10, (0.3, 0.2, 0.35)), ("boxes", (4.6, -36.5), 0, None), ("suitcase", (3.2, -36.2), -20, (0.5, 0.35, 0.2)),
             ("sled", (1.8, -36.4), 80, None), ("suitcase", (0.4, -36.3), 5, (0.2, 0.3, 0.35)), ("boxes", (-1.0, -36.6), 30, None),
             ("suitcase", (-2.4, -36.2), -10, (0.45, 0.2, 0.2))]
    for kind, (x, z), yaw, c in queue:
        if c:
            b.prop(P, kind, (x, 0, z), yaw=yaw, color=c, has_collision=False)
        else:
            b.prop(P, kind, (x, 0, z), yaw=yaw, has_collision=False)
    # North road.
    b.prop(P, "barricade", (0, 0, -60.5), size=(1.6, 1, 1))
    for (x, z, sx, sy, sz) in ((-6, -64, 4, 2.2, 3), (6, -63.5, 4.5, 2.5, 3), (0, -66.5, 6, 3.0, 3), (-11, -61, 3, 1.6, 3), (11, -61, 3, 1.8, 3)):
        b.prop(P, "drift", (x, 0, z), size=(sx, sy, sz))
    b.prop(P, "cone", (-3.2, 0, -59.3))
    b.prop(P, "cone", (3.4, 0, -59.5), yaw=40)
    # Narrow street.
    b.prop(P, "bin", (-2.5, 0, -13.5), yaw=90)
    b.prop(P, "crate", (2.5, 0, -26))
    b.prop(P, "rubble", (2.4, 0, -15))
    b.prop(P, "hydrant", (-2.9, 0, -24))
    b.prop(P, "traffic_light", (4.5, 0, -7.7), lit=True)
    b.prop(P, "trash_bags", (-2.9, 0, -20), yaw=40)

    b.info(I, "NoticeBoard", (-9, 0, -31.4), "note_evac", interaction_text="Прочитать", shape=(2.2, 2, 1.2))
    b.loot(I, "WoodPile", (-17, 0, -45.2), "Поддоны", "woodpile", interaction_text="Разобрать")
    b.pick(I, "SquareWater", (6, 0, -38.2), "water_bottle", radius=0.7)
    b.loot(I, "SquareCDLocker", (8.0, 0, -38.8), "Пункт выдачи ГО", "civil_defense_locker", interaction_text="Вскрыть",
           found_text="Сорванная пломба. Кто-то был здесь раньше — но не взял всё.", shape=(1.4, 2, 1.4))
    b.loot(I, "CDTent", (13.3, 0, -39.0), "Палатка ГО", "civil_defense_locker", shape=(2.4, 2, 1.4),
           found_text="Под раскладушкой — коробка с маркировкой «ГО. Выдавать по списку». Список пуст.")
    b.area(I, "RadioPoint", S_STATION, (12, 0, -51.2), {"display_name": "Радиоточка", "interaction_text": "Настроить приёмник", "panel": "radio",
        "station_id": "radio_point", "consequences": [{"set_flag": "radio_point_used"}]}, shape=("box", (2.4, 2, 1.4)))
    b.loot(I, "RadioLocker", (14.3, 0, -51.1), "Шкафчик радиоточки", "radio_equipment", items={"electronics": 2}, interaction_text="Открыть",
           conditions=[{"any": [{"item": "crowbar"}, {"tier_min": ["vera", "cooperative"]}, {"flag": "vera_locker_ok"}, {"npc_not_at": ["vera", "district"]}]}],
           requirement_text="Шкафчик заперт, Вера следит за ним. Можно вскрыть монтировкой — или заслужить её доверие.", shape=(1.2, 2, 1.2))
    b.hide(I, "SquareBin", (-17.6, 0, -41), "Мусорный бак")
    b.hide(I, "NarrowBin", (-1.7, 0, -13.5), "Мусорный бак")
    b.loot(I, "NarrowCrate", (2.4, 0, -25.3), "Ящик", "rubble")
    b.info(I, "Newspaper", (-14, 0, -53.6), "newspaper_nov2", interaction_text="Взять газету", shape=(2.0, 2, 1.2))
    b.loot(I, "NewsKioskShelf", (-12.2, 0, -55), "Киоск «Союзпечать»", "shop_counter", shape=(1.2, 2, 1.8))
    b.area(I, "NorthRoad", S_EXAM, (0, 0, -58.6), {"display_name": "Северная дорога", "interaction_text": "Осмотреть дорогу", "dialogue_id": "north_road"},
           shape=("box", (9, 2, 1.8)))
    # Stories.
    b.exam(I, "Queue", (2, 0, -35.4), "Очередь",
           "Чемоданы, сумки, санки — выстроены в линию к пункту ГО, как стояли люди. Сами люди ушли. "
           "Или их увели. На ручке одного чемодана — бирка: «Семья Громовых, 4 чел.»", shape=(9.0, 2.0, 1.4), label="Вещи в очереди")
    b.exam(I, "Snowman", (6, 0, -46.3), "Снеговик в противогазе",
           "Кто-то слепил снеговика и надел на него настоящий противогаз. Детская рука — нос-морковка валяется рядом. "
           "Фильтр давно пустой. Стёкла смотрят на север, на дорогу.", shape=(1.6, 2.0, 1.4), label="Снеговик")
    b.exam(I, "Fountain", (-9, 0, -47.4), "Замёрзший фонтан",
           "Фонтан замёрз на лету: струи превратились в сосульки, вода — в стекло. В ледяной чаше — монеты "
           "и детская варежка, вмёрзшая пальцами вверх.", shape=(4.6, 2.0, 1.4), label="Фонтан")
    b.exam(I, "Loudspeaker", (-14, 0, -33.4), "Громкоговоритель ГО",
           "Кабель громкоговорителя перерезан — аккуратно, кусачками, на высоте трёх метров. Кто-то очень не хотел, "
           "чтобы он снова заговорил.", shape=(1.6, 2.0, 1.4), label="Громкоговоритель", consequences=[{"set_flag": "seen_cut_speaker"}])
    b.exam(I, "PhoneBooth", (17, 0, -33.3), "Телефонная будка",
           "Трубка висит на проводе и тихо качается. На стекле процарапано: «МАМА, МЫ НА ВОКЗАЛЕ. НЕ ЖДИ». "
           "Вокзал — на другом конце города.", shape=(1.6, 2.0, 1.4), label="Телефонная будка")


# =====================================================================================
# Pharmacy (enterable) — locked back room
# =====================================================================================

def pharmacy(b, B, P, I):
    ph = b.s.node("Pharmacy", "Node3D", B)
    b.indoor_parents.add(ph)
    wall = (0.75, 0.78, 0.8)
    b.block(ph, "Floor", (32, 0, -46), (16, 0.06, 16), (0.62, 0.64, 0.62), snow_mask=0.0, material="floor_tiles",
            has_collision=False, fadeable=False, show_on_map=True, map_label="Аптека")
    b.walls(ph, "pharmacy", 24, -54, 40, -38, 3.6, wall, [("w", -46, 2.4)], material="plaster")
    b.inner_wall(ph, "z", 36, -54, -38, [(-46, 1.2)], h=3.4, color=(0.7, 0.72, 0.74), material="wall_tiles")
    b.block(ph, "Roof", (32, 3.6, -46), (16.6, 0.35, 16.6), (0.3, 0.32, 0.34), groups=["cutaway:pharmacy"], has_collision=False,
            fade="pharmacy", material="roof")
    for (y, z, sx, sz) in ((2.3, -49, 0.12, 0.3), (2.6, -49, 0.12, 0.9)):
        b.block(ph, "Cross", (23.8, y, z), (sx, 0.9 if sz < 0.5 else 0.3, sz), (0.2, 1.0, 0.45), emission=2.0, snow_mask=0.0, has_collision=False, material="plastic")
    b.block(ph, "CrossS", (38.5, 2.3, -37.8), (0.3, 0.9, 0.12), (0.2, 1.0, 0.45), emission=2.0, snow_mask=0.0, has_collision=False, material="plastic")
    b.block(ph, "CrossS2", (38.5, 2.6, -37.8), (0.9, 0.3, 0.12), (0.2, 1.0, 0.45), emission=2.0, snow_mask=0.0, has_collision=False, material="plastic")
    for x in (27.5, 32.5):
        b.prop(ph, "window", (x, 1.7, -37.95), size=(1.8, 1.1, 1), lit=False, has_collision=False, fade="pharmacy", groups=["cutaway:pharmacy"])
    b.prop(ph, "counter", (28, 0, -46), yaw=90, size=(1.4, 1, 1))
    b.prop(ph, "shelf", (30, 0, -53.4))
    b.prop(ph, "shelf", (33.5, 0, -53.4))
    b.prop(ph, "shelf", (31, 0, -38.6), yaw=180)
    b.prop(ph, "table", (31, 0, -41.5))
    b.prop(ph, "chair", (33.5, 0, -44.5), yaw=60)
    b.prop(ph, "rubble", (34.4, 0, -50.5), color=(0.7, 0.72, 0.74))
    b.prop(ph, "ceiling_lamp", (31, 0, -46), lit=True, flicker=True, light_color=(0.8, 0.95, 1.0), light_energy=0.8, light_range=8.0)
    for (x, z, yaw) in ((26.5, -44, 20), (27.5, -48, 70), (29.8, -45.2, 0)):
        b.prop(ph, "paper", (x, 0.01, z), yaw=yaw, has_collision=False)
    # Back room.
    b.prop(ph, "rack", (38.8, 0, -52.6), yaw=-90, lit=False, color=(0.75, 0.78, 0.8))
    b.prop(ph, "bed", (38.6, 0, -41.3), color=(0.3, 0.4, 0.45))
    b.prop(ph, "desk", (38.5, 0, -48.8), yaw=-90)
    b.prop(ph, "boxes", (37.2, 0, -39.0))
    b.door(I, "PharmacyBackDoor", (36, 0, -46), yaw=90, width=1.2, color=(0.62, 0.64, 0.6), fade="pharmacy",
           display_name="Дверь подсобки", locked=True, key_item="pharmacy_key",
           locked_text="Дверь подсобки заперта. Нужен ключ — или монтировка.", consequences=[{"set_flag": "pharmacy_backroom_opened"}])
    b.loot(I, "PharmacyCounter", (27.2, 0, -46), "Прилавок", "pharmacy_shelf", items={"bandage": 1}, shape=(1.4, 2, 2.4))
    b.loot(I, "PharmacyBackroom", (38.4, 0, -45.5), "Сейф подсобки", "pharmacy_backroom", items={"medicine": 2, "protective_mask": 1},
           interaction_text="Открыть", found_text="Сейф не заперт — хозяйка, видно, собиралась вернуться. Лекарства и маска.",
           shape=(1.6, 2.2, 2.0))
    b.loot(I, "PharmacyCabinet", (38.4, 0, -52.4), "Шкаф с препаратами", "medicine_cabinet", shape=(1.4, 2, 1.6))
    b.info(I, "PharmacyNote", (31, 0, -41.5), "note_pharmacy", shape=(1.6, 2, 1.2))
    b.loot(I, "PharmacyShelf", (31.7, 0, -52.8), "Пустые полки", empty_text="Всё выгребли. Остались только пустые коробки.", shape=(3.4, 2, 1.2))
    b.loot(I, "PharmacyShelfS", (31, 0, -39.2), "Витрина", "pharmacy_shelf", shape=(1.8, 2, 1.2))
    b.exam(I, "PharmacyTickets", (27.6, 0, -43.6), "Талончики",
           "По полу рассыпаны талончики электронной очереди: 214, 215, 216… Последний вызванный номер на табло — 188.",
           shape=(2.0, 2.0, 1.6), label="Талончики на полу")
    b.exam(I, "PharmacyDesk", (38.2, 0, -48.8), "Журнал провизора",
           "Журнал выдачи: «3.11 — термоодеяла отправлены на «Меридиан» (12 шт.). Жителям — отказано, «нет в наличии». "
           "Стыдно. Н. К.» Ниже — ключ нарисован на полях и зачёркнут.", shape=(1.6, 2.0, 1.8), label="Стол провизора")


# =====================================================================================
# Radio station (enterable) with walkable roof, exterior stairs and the mast
# =====================================================================================

def radio_station(b, B, P, I):
    rs = b.s.node("RadioStation", "Node3D", B)
    b.indoor_parents.add(rs)
    b.block(rs, "Floor", (32, 0, -29), (12, 0.06, 10), (0.4, 0.4, 0.42), snow_mask=0.0, material="floor_tiles",
            has_collision=False, fadeable=False, show_on_map=True, map_label="Радиоузел")
    b.walls(rs, "radio", 26, -34, 38, -24, 3.7, (0.5, 0.52, 0.55), [("s", 30, 1.3)], material="concrete")
    # Walkable flat roof with parapets (open to the east where the stair landing is).
    b.block(rs, "Roof", (32, 3.7, -29), (12.4, 0.3, 10.4), (0.3, 0.3, 0.33), groups=["cutaway:radio"], fade="radio", material="roof")
    par = (0.5, 0.52, 0.55)
    b.block(rs, "ParapetN", (32, 4.0, -34.05), (12.4, 0.55, 0.3), par, material="concrete", fade="radio", groups=["cutaway:radio"])
    b.block(rs, "ParapetS", (32, 4.0, -23.95), (12.4, 0.55, 0.3), par, material="concrete", fade="radio", groups=["cutaway:radio"])
    b.block(rs, "ParapetW", (25.95, 4.0, -29), (0.3, 0.55, 10.4), par, material="concrete", fade="radio", groups=["cutaway:radio"])
    b.block(rs, "ParapetE", (38.05, 4.0, -27.3), (0.3, 0.55, 7.0), par, material="concrete", fade="radio", groups=["cutaway:radio"])
    b.prop(rs, "stairs", (39.2, 0, -27.75), size=(1.4, 4.0, 6.5), color=(0.45, 0.46, 0.48), snow_scale=1.0)
    b.block(rs, "Landing", (39.1, 3.85, -32.4), (2.2, 0.15, 3.0), (0.3, 0.3, 0.32), material="metal")
    b.block(rs, "LandingRail", (40.15, 4.0, -32.4), (0.08, 1.0, 3.0), (0.25, 0.25, 0.27), material="metal")
    for z in (-31.2, -33.6):
        b.block(rs, "LandingPost", (40.0, 0, z), (0.14, 3.85, 0.14), (0.25, 0.25, 0.27), material="metal")
    for x in (28.5, 34.5):
        b.prop(rs, "window", (x, 1.8, -23.95), size=(1.6, 1.0, 1), lit=(x == 34.5), light_color=(0.6, 0.9, 0.7),
               has_collision=False, fade="radio", groups=["cutaway:radio"])
    b.block(rs, "Plate", (31.4, 2.3, -23.9), (0.8, 0.35, 0.05), (0.15, 0.3, 0.6), snow_mask=0.0, has_collision=False, material="paint")
    # Roof clutter + hidden antenna module under a tarp.
    roof = dict(snow_scale=1.0, fade="radio", groups=["cutaway:radio"])
    b.prop(rs, "antenna", (28, 4.0, -32.5), size=(1, 0.6, 1), **roof)
    b.prop(rs, "vent", (30.5, 4.0, -26.5), **roof)
    b.prop(rs, "ac_unit", (33.5, 4.0, -33.4), **roof)
    b.prop(rs, "boxes", (36.6, 4.0, -26.8), color=(0.4, 0.45, 0.35), **roof)
    b.block(rs, "Tarp", (36.7, 4.0, -26.2), (1.8, 0.6, 1.4), (0.25, 0.34, 0.3), material="fabric", has_collision=False, snow_mask=1.0,
            fade="radio", groups=["cutaway:radio"])
    b.prop(P, "radio_tower", (41, 0, -18), size=(1, 1.4, 1), lit=True)
    b.prop(P, "fence", (44.2, 0, -30), yaw=90, size=(2.4, 1, 1))
    b.prop(P, "fence", (44.2, 0, -16), yaw=90, size=(2.4, 1, 1))
    b.prop(P, "fence", (33, 0, -36.2), size=(2.4, 1, 1))
    b.prop(P, "tires", (27, 0, -21), size=(1, 0.75, 1))
    b.prop(P, "barrel", (24, 0, -12.5), color=(0.5, 0.3, 0.2))
    b.prop(P, "barrel", (24.8, 0, -12.1), color=(0.25, 0.35, 0.5))
    # Interior.
    b.prop(rs, "rack", (27.0, 0, -33.3), lit=True)
    b.prop(rs, "rack", (28.0, 0, -33.3), lit=False)
    b.prop(rs, "transmitter", (31.5, 0, -33.4))
    b.prop(rs, "desk", (35.5, 0, -33.2))
    b.prop(rs, "tape_recorder", (35.2, 0.8, -33.2))
    b.prop(rs, "chair", (35.5, 0, -32.2), yaw=180)
    b.prop(rs, "lockers", (37.4, 0, -29), yaw=-90)
    b.prop(rs, "bunk_bed", (26.8, 0, -26.5))
    b.prop(rs, "heater", (33, 0, -24.5), yaw=180, lit=False)
    b.prop(rs, "ceiling_lamp", (32, 0, -29), lit=True, flicker=True, light_color=(0.7, 1.0, 0.8), light_energy=0.7, light_range=7.0)
    b.door(I, "RadioDoor", (30, 0, -24.15), width=1.2, color=(0.35, 0.38, 0.4), fade="radio", display_name="Дверь радиоузла",
           locked=True, open_flag="radio_station_open", locked_text="Стальная дверь заперта. Замок простой — поддастся отмычке или монтировке.")
    b.info(I, "RadioLogbook", (35.5, 0, -32.2), "radio_logbook", interaction_text="Читать журнал", shape=(1.6, 2, 1.6))
    b.loot(I, "RadioLockers", (36.8, 0, -29), "Шкафчики дежурных", "radio_equipment", items={"cassette_tape": 1}, shape=(1.4, 2, 1.8),
           found_text="В шкафчике — аккуратно подписанная кассета: «Для Веры». Почерк ровный, инженерный.")
    b.loot(I, "RadioBunk", (27.6, 0, -26.5), "Койка дежурного", "wardrobe", shape=(1.6, 2, 2.2))
    b.exam(I, "Transmitter", (31.5, 0, -32.4), "Передатчик радиоузла",
           "Старый ламповый передатчик. Все платы на месте, питание есть — но выходной разъём антенны пуст. "
           "Без антенного блока он поёт в пустоту.", shape=(2.0, 2.0, 1.6), label="Передатчик")
    b.exam(I, "TapeRecorder", (34.0, 0, -32.2), "Магнитофон",
           "Бобина крутится вхолостую — лента кончилась давно. На панели фломастером: «Эфир 3.11 — сохранить». "
           "Ленты в магнитофоне нет.", shape=(1.2, 2.0, 1.6), label="Магнитофон")
    b.area(I, "AntennaModule", S_PICK, (35.3, 4.0, -26.4), {"item_id": "antenna_module", "count": 1}, shape=("sphere", 0.9), groups=["cutaway:radio"])
    b.exam(I, "RadioTower", (40.5, 0, -15.6), "Мачта радиоузла",
           "На макушке мачты мигает красный огонь — питание ещё есть. Площадка под антенной пуста: "
           "антенный блок кто-то аккуратно снял. Скобы на опоре срезаны до высоты трёх метров.",
           shape=(3.0, 2.0, 1.6), label="Радиомачта", consequences=[{"set_flag": "seen_radio_tower"}])
    b.exam(I, "RoofView", (29.5, 4.0, -31.5), "Вид с крыши",
           "С крыши виден весь квартал: дымок над домом 12, чёрная коробка подстанции, мачта. "
           "На севере, за снежной пеленой, мерцает красный огонь «Меридиана». Он мигает в такт мачте.",
           shape=(2.0, 2.0, 2.0), label="Край крыши")


# =====================================================================================
# Дом 7 (enterable ground floor): corridor, Elias's flat, the family flat + secret room
# =====================================================================================

def house7(b, B, P, I):
    h = b.s.node("House7", "Node3D", B)
    b.indoor_parents.add(h)
    ext = (0.62, 0.58, 0.5)
    inner = (0.6, 0.52, 0.44)
    b.block(h, "FloorFlats", (-51, 0, 18), (18, 0.06, 16), (0.42, 0.3, 0.2), snow_mask=0.0, material="parquet",
            has_collision=False, fadeable=False, show_on_map=True, map_label="Дом 7")
    b.block(h, "FloorHall", (-51, 0.005, 18), (6, 0.06, 16), (0.45, 0.45, 0.46), snow_mask=0.0, material="floor_tiles",
            has_collision=False, fadeable=False)
    b.walls(h, "house", -60, 10, -42, 26, 3.6, ext, [("n", -51, 1.6)], material="plaster")
    b.inner_wall(h, "z", -54, 10, 26, [(20, 1.1)], color=inner)
    b.inner_wall(h, "z", -48, 10, 26, [(14, 1.1)], color=inner)
    b.inner_wall(h, "x", 22, -60, -54, [(-57, 1.2)], color=inner)
    b.building(B, "House7Upper", -60, 10, -42, 26, 3.4, ext, y=3.6, material="plaster", floors=1, trim_color=(0.66, 0.62, 0.55),
               roof_type="gable", roof_color=(0.3, 0.2, 0.18), window_faces="snew", lit_windows=0.1, boarded_windows=0.2,
               seed_value=7, has_collision=False, groups=["cutaway:house"], fade="house")
    # Ground-floor windows: street side and the (visible) back side.
    for x in (-57, -45):
        b.prop(h, "window", (x, 1.7, 9.96), yaw=180, lit=False, has_collision=False, fade="house")
    b.prop(h, "window", (-45, 1.7, 26.04), lit=True, has_collision=False, fade="house", groups=["cutaway:house"])
    b.prop(h, "window", (-51, 1.9, 26.04), size=(0.8, 0.8, 1), lit=False, has_collision=False, fade="house", groups=["cutaway:house"])
    b.prop(h, "window_boarded", (-57, 1.6, 26.06), has_collision=False, fade="house", groups=["cutaway:house"], snow_scale=1.0)
    b.prop(h, "drainpipe", (-59.6, 0, 26.0), size=(1, 0.85, 1), snow_scale=1.0)
    b.block(h, "Plate", (-49.6, 2.3, 9.9), (0.5, 0.3, 0.04), (0.15, 0.3, 0.6), snow_mask=0.0, has_collision=False, material="paint")
    b.prop(h, "canopy", (-51, 0, 9.85), yaw=180, size=(0.8, 1, 1), snow_scale=1.0)
    # Corridor.
    b.prop(h, "mailboxes", (-53.85, 0, 12.4), yaw=90)
    b.prop(h, "radiator", (-48.2, 0, 17.5), yaw=-90)
    b.prop(h, "stairs", (-51, 0, 24.5), yaw=180, size=(2.4, 2.0, 3.0), color=(0.5, 0.48, 0.46))
    b.prop(h, "barricade", (-51, 1.2, 24.4), size=(1.3, 1, 1))
    b.prop(h, "chair", (-50.2, 1.6, 24.9), yaw=35)
    b.prop(h, "table", (-51.6, 1.8, 25.2), yaw=-20, size=(0.8, 1, 1))
    b.prop(h, "ceiling_lamp", (-51, 0, 16), lit=False)
    # Elias's flat (east).
    b.prop(h, "counter", (-44.5, 0, 10.5), size=(1.2, 1, 1))
    b.prop(h, "stove", (-42.8, 0, 10.6), lit=False)
    b.prop(h, "table", (-46.5, 0, 19.5))
    b.prop(h, "radio_set", (-46.5, 0.82, 19.5), yaw=180, lit=False)
    b.prop(h, "chair", (-56, 0, 20.3), name="ChairFamily")
    b.prop(h, "chair", (-46.5, 0, 18.6))
    b.prop(h, "crate", (-42.7, 0, 16.2), size=(0.8, 0.6, 0.6), color=(0.6, 0.15, 0.12))
    b.prop(h, "bed", (-46.6, 0, 24.3))
    b.prop(h, "wardrobe", (-42.6, 0, 12.2), yaw=-90)
    b.prop(h, "desk", (-43.8, 0, 25.2), yaw=180)
    b.prop(h, "bookshelf", (-42.3, 0, 20.5), yaw=-90)
    b.prop(h, "candle", (-44.2, 0.82, 25.1), light_energy=0.8, light_range=5.0)
    b.prop(h, "plant", (-47.5, 0, 25.4))
    # Family flat (west): a table laid for three, a child's corner, the wardrobe that moves.
    b.prop(h, "table", (-57, 0, 15), size=(1.2, 1, 1.2))
    for (x, z, yaw) in ((-57, 14.1, 0), (-57, 15.9, 180), (-58.1, 15, 90)):
        b.prop(h, "chair", (x, 0, z), yaw=yaw + random.uniform(-25, 25))
    for (x, z) in ((-57, 14.6), (-57, 15.4), (-57.6, 15)):
        b.block(h, "Plate", (x, 0.83, z), (0.26, 0.03, 0.26), (0.9, 0.9, 0.86), snow_mask=0.0, has_collision=False, material="plastic", fadeable=False)
    b.block(h, "Pot", (-56.5, 0.83, 15.1), (0.3, 0.22, 0.3), (0.3, 0.32, 0.35), shape="cylinder", snow_mask=0.0, has_collision=False, material="metal", fadeable=False)
    b.prop(h, "fridge", (-59.55, 0, 11.0), yaw=90)
    b.prop(h, "counter", (-59.6, 0, 13.3), yaw=90, size=(0.9, 1, 1))
    b.prop(h, "sofa", (-54.7, 0, 12.5), yaw=-90, color=(0.4, 0.28, 0.3))
    b.prop(h, "tv", (-57.6, 0, 10.65), lit=False)
    b.prop(h, "bed", (-58.9, 0, 19.2), color=(0.3, 0.45, 0.6), size=(0.8, 1, 0.8))
    b.prop(h, "wardrobe", (-59.6, 0, 17.0), yaw=90, name="Dresser", color=(0.45, 0.32, 0.22))
    for i in range(4):
        b.block(h, "Scratch", (-57.2 + i * 0.25, 0.035, 20.9 - i * 0.12), (0.9, 0.01, 0.03), (0.2, 0.14, 0.1), yaw=10 + i * 12,
                snow_mask=0.0, has_collision=False, fadeable=False, cast_shadows=False, material="plain")
    # Secret room behind the wardrobe.
    b.prop(h, "bed", (-58.6, 0, 24.4), yaw=90, color=(0.45, 0.4, 0.3))
    b.prop(h, "candle", (-55.2, 0, 22.7), lit=False)
    b.prop(h, "boxes", (-55.4, 0, 25.2))
    for (x, c) in ((-58.0, (0.9, 0.6, 0.2)), (-57.2, (0.3, 0.5, 0.8)), (-56.4, (0.8, 0.3, 0.3))):
        b.block(h, "Drawing", (x, 1.3, 25.68), (0.5, 0.4, 0.02), c, snow_mask=0.0, has_collision=False, fadeable=False, material="paint")
    # Doors.
    b.door(I, "HouseEntrance", (-51, 0, 10.15), yaw=180, width=1.6, color=(0.3, 0.26, 0.2), fade="house", display_name="Дверь подъезда")
    b.door(I, "FlatFamilyDoor", (-54, 0, 20), yaw=90, width=1.1, color=(0.42, 0.3, 0.2), fade="house", display_name="Квартира 1")
    b.door(I, "FlatEliasDoor", (-48, 0, 14), yaw=-90, width=1.1, color=(0.36, 0.26, 0.2), fade="house", display_name="Квартира 2 — Элиас")
    b.door(I, "SecretWardrobe", (-57, 0, 22), width=1.2, visual="prop", open_mode="slide", slide_distance=1.3,
           visual_kw={"kind": "wardrobe", "pos": (0, 0, -0.44), "color": (0.34, 0.25, 0.18), "snow_scale": 0.0}, blocker=(1.2, 2.4, 0.3),
           interact=(2.0, 2.2, 1.4), display_name="Тяжёлый шкаф", interaction_text="Сдвинуть шкаф",
           open_text="Шкаф с натугой отъезжает в сторону. За ним — пролом в стене и темнота.",
           consequences=[{"set_flag": "found_family_hideout"}])
    # Interactables.
    b.loot(I, "HouseKitchen", (-45.0, 0, 11.3), "Кухонный шкаф", "kitchen_cabinet", items={"canned_food": 1}, shape=(1.6, 2.0, 1.2))
    b.loot(I, "HouseToolbox", (-43.3, 0, 16.2), "Ящик с инструментами", "toolbox", items={"crowbar": 1},
           found_text="Под отвёртками — тяжёлая монтировка.")
    b.loot(I, "HouseWardrobe", (-43.2, 0, 12.6), "Шкаф", "wardrobe", items={"warm_jacket": 1}, found_text="Старый пуховик. Велик, но тёплый.")
    b.loot(I, "HouseChair", (-56, 0, 19.6), "Сломанный стул", "woodpile", interaction_text="Разобрать на доски", shape=(1.2, 2.0, 1.2))
    b.exam(I, "HouseDesk", (-43.8, 0, 24.4), "Стол Элиаса",
           "Паяльник, лупа, разобранный приёмник. На листке — начатая схема передатчика и надпись: «не хватает питания и трёх плат».",
           shape=(2.0, 2, 1.4), label="Стол с деталями")
    b.loot(I, "EliasBookshelf", (-42.9, 0, 20.5), "Книжная полка", "bookshelf", items={"elias_diary": 1}, shape=(1.4, 2, 1.6),
           found_text="За справочниками по радиотехнике — потёртая тетрадь в клетку.")
    b.exam(I, "Mailboxes", (-53.2, 0, 12.4), "Почтовые ящики",
           "Все ящики распахнуты и пусты. Кроме одного — №2. На нём скотчем приклеено: «Элиасу. Не трогать». "
           "Внутри — счёт за электричество на 4 ноября. Кто-то всё ещё платил.", shape=(1.4, 2.0, 1.8))
    b.exam(I, "BlockedStairs", (-51, 0, 22.2), "Завал на лестнице",
           "Лестница на второй этаж завалена мебелью — изнутри, сверху. Баррикада. На верхней ступеньке — "
           "детская варежка. Вы зовёте — сверху никто не отвечает.", shape=(2.4, 2.0, 1.6), label="Лестница")
    b.exam(I, "FamilyTable", (-57, 0, 16.6), "Накрытый стол",
           "Стол накрыт на троих. Суп замёрз в кастрюле, ложки лежат в тарелках. Стулья отодвинуты — встали разом, "
           "посреди обеда, и ушли.", shape=(2.0, 2.0, 1.2), label="Стол")
    b.info(I, "FamilyFridge", (-58.9, 0, 11.0), "note_family", interaction_text="Прочитать записку", shape=(1.4, 2.0, 1.4))
    b.loot(I, "FamilyKitchen", (-58.9, 0, 13.3), "Кухонный шкаф", "kitchen_cabinet", shape=(1.2, 2.0, 1.4))
    b.loot(I, "FamilyDresser", (-58.9, 0, 17.0), "Комод", "wardrobe", items={"family_photo": 1}, shape=(1.4, 2.0, 1.6),
           found_text="Под свитерами — фотография в рамке. Мужчина, женщина и мальчик у ёлки.")
    b.exam(I, "FloorScratches", (-56.2, 0, 20.4), "Царапины на полу",
           "Полукруглые царапины на паркете у шкафа. Его двигали много раз — туда и обратно.",
           shape=(1.2, 2.0, 1.0), label="Царапины на полу", consequences=[{"set_flag": "noticed_wardrobe_scratches"}])
    b.exam(I, "Hideout", (-57.2, 0, 23.8), "Тайная комната",
           "Здесь жили: матрас, огарки свечей, детские рисунки на стене — солнце, дом, трое. Окно заколочено изнутри. "
           "Следов борьбы нет. Они просто ушли — вместе.", shape=(2.0, 2.0, 1.6), label="Тайник")
    b.loot(I, "HideoutStash", (-55.4, 0, 24.6), "Тайник семьи", "pantry", items={"checkpoint_pass": 1, "canned_food": 1},
           shape=(1.4, 2.0, 1.6), found_text="Среди консервов — ламинированный пропуск на КПП. Один. Им так и не воспользовались.")
    b.hide(I, "HouseWardrobeHide", (-46.6, 0, 22.8), "Под кроватью", shape=(1.4, 2.0, 1.2))


# =====================================================================================
# Shop «Северный» (enterable) with storeroom and back door to the alley
# =====================================================================================

def shop(b, B, P, I):
    sh = b.s.node("Shop", "Node3D", B)
    b.indoor_parents.add(sh)
    b.block(sh, "Floor", (-26, 0, 16), (16, 0.06, 12), (0.5, 0.5, 0.5), snow_mask=0.0, material="floor_tiles",
            has_collision=False, fadeable=False, show_on_map=True, map_label="Магазин")
    b.walls(sh, "shop", -34, 10, -18, 22, 3.6, (0.6, 0.52, 0.42), [("n", -26.5, 2.4), ("w", 19, 1.2)], material="plaster")
    b.inner_wall(sh, "z", -29, 10, 22, [(13, 1.2)], h=3.4, color=(0.55, 0.55, 0.52), material="wall_tiles")
    b.block(sh, "Roof", (-26, 3.6, 16), (16.6, 0.35, 12.6), (0.25, 0.25, 0.27), groups=["cutaway:shop"], has_collision=False,
            fade="shop", material="roof")
    b.prop(sh, "vent", (-21, 3.95, 18), groups=["cutaway:shop"], fade="shop", snow_scale=1.0)
    b.prop(sh, "ac_unit", (-31, 3.95, 20.5), groups=["cutaway:shop"], fade="shop", snow_scale=1.0)
    b.block(sh, "Sign", (-26.5, 2.75, 9.86), (5.5, 0.7, 0.08), (0.22, 0.32, 0.46), emission=0.3, snow_mask=1.0, has_collision=False, material="paint")
    b.block(sh, "SignText", (-26.5, 2.75, 9.8), (4.2, 0.3, 0.02), (0.85, 0.86, 0.8), emission=0.4, snow_mask=0.0, has_collision=False, material="paint")
    b.block(sh, "BladeSign", (-18.0, 2.4, 10.6), (0.14, 1.2, 1.3), (0.26, 0.38, 0.55), emission=0.35, snow_mask=0.3, has_collision=False, material="paint")
    b.block(sh, "BladeSignText", (-17.92, 2.4, 10.6), (0.02, 0.8, 0.9), (0.85, 0.88, 0.9), emission=0.5, snow_mask=0.0, has_collision=False, material="paint")
    for x in (-23.5, -30.5):
        b.prop(sh, "window", (x, 1.6, 9.96), yaw=180, size=(2.2, 1.3, 1), lit=False, has_collision=False, fade="shop")
    b.prop(sh, "window", (-22, 1.9, 22.04), size=(1.2, 0.8, 1), lit=False, has_collision=False, fade="shop", groups=["cutaway:shop"])
    # Hall.
    b.prop(sh, "shelf", (-28.4, 0, 16), yaw=90)
    b.prop(sh, "shelf", (-28.4, 0, 20), yaw=90)
    b.prop(sh, "shelf", (-24.5, 0, 15.2), size=(1.4, 1, 1))
    for x in (-26.2, -25.4):
        b.prop(sh, "fridge", (x, 0, 21.4), yaw=180, color=(0.8, 0.82, 0.84))
    b.prop(sh, "counter", (-20.8, 0, 13.4), yaw=90)
    b.prop(sh, "counter", (-22.5, 0, 20.9), size=(1.0, 1, 1), color=(0.7, 0.72, 0.74), name="Freezer")
    b.prop(sh, "cart", (-23.2, 0, 12.2), yaw=30)
    b.prop(sh, "rubble", (-25, 0, 13.8), color=(0.55, 0.45, 0.35))
    b.prop(sh, "ceiling_lamp", (-23.5, 0, 16), lit=False)
    # Storeroom.
    b.prop(sh, "shelf", (-31.5, 0, 21.4), yaw=180, size=(1.4, 1, 1))
    b.prop(sh, "crate", (-30.5, 0, 16.6), size=(1.2, 1.2, 1.2))
    b.prop(sh, "boxes", (-33.2, 0, 15.5))
    b.prop(sh, "bed", (-31.6, 0, 11.6), yaw=90, color=(0.35, 0.3, 0.25))
    b.prop(sh, "candle", (-33.3, 0, 10.6), lit=False)
    b.prop(sh, "boxes", (-30.2, 0, 10.8), color=(0.55, 0.5, 0.45))
    b.door(I, "ShopBackDoor", (-33.85, 0, 19), yaw=90, width=1.2, color=(0.3, 0.32, 0.34), fade="shop",
           display_name="Задняя дверь", interaction_text="Отодвинуть засов", open_text="Засов поддаётся. Дверь выходит в переулок.")
    b.loot(I, "ShopShelf1", (-27.8, 0, 16), "Полка с консервами", "shop_food", items={"canned_food": 1})
    b.loot(I, "ShopShelf2", (-27.8, 0, 20), "Полка с водой", "shop_food", items={"water_bottle": 1})
    b.loot(I, "ShopShelf3", (-24.5, 0, 15.9), "Стеллаж", "shop_food", shape=(1.8, 2.0, 1.0))
    b.loot(I, "ShopFridge", (-25.8, 0, 20.6), "Холодильники", "fridge", shape=(2.0, 2.0, 1.2),
           found_text="Холодильники давно не гудят — но и не нужно: внутри холоднее, чем в морозилке.")
    b.loot(I, "ShopFreezer", (-22.5, 0, 20.2), "Морозильный ларь", "fridge", shape=(1.4, 2.0, 1.2))
    b.loot(I, "ShopStock", (-31.5, 0, 20.6), "Коробки со склада", "shop_stock")
    b.loot(I, "ShopRegister", (-21.6, 0, 13.4), "Касса", "shop_counter", items={"electronics": 1}, interaction_text="Разобрать",
           found_text="Касса открыта, деньги на месте — никому не нужны. Из кассы выходит пригоршня плат и проводов.")
    b.loot(I, "ShopCart", (-23.2, 0, 11.6), "Брошенная тележка", "shop_food", shape=(1.4, 2.0, 1.4))
    b.hide(I, "ShopDoor", (-30.5, 0, 17.6), "За ящиками", shape=(1.4, 2, 1.4))
    b.exam(I, "TomasCorner", (-31.6, 0, 12.8), "Чей-то угол",
           "На складе кто-то жил: матрас, огарки свечей, пирамида из пустых банок. На стене — список адресов, "
           "все зачёркнуты, кроме одного: «Меридиан, лаб. 4».", shape=(2.0, 2.0, 1.4), label="Матрас на складе")


# =====================================================================================
# Alley: device, symbol, tracks, blood trail, stalker nest; the dig spot behind the shop
# =====================================================================================

def alley(b, B, P, I, D):
    b.block(B, "AlleyWall", (-34.8, 0, 34), (0.4, 3.0, 16), (0.36, 0.34, 0.33), snow_mask=0.8, material="brick")
    b.block(B, "AlleyWallW", (-41.2, 0, 36), (0.4, 3.0, 20), (0.36, 0.34, 0.33), snow_mask=0.8, material="brick")
    b.prop(P, "bin", (-39.9, 0, 16), yaw=90)
    b.prop(P, "bin", (-36.1, 0, 31), yaw=-90)
    b.prop(P, "pallet", (-39.7, 0, 23.5))
    b.prop(P, "crate", (-36.2, 0, 37.5))
    b.prop(P, "fence", (-38, 0, 46), size=(1.6, 1, 1))
    b.prop(P, "device", (-38, 0, 43), lit=True)
    b.prop(P, "symbol", (-41.94, 0, 22), yaw=90, has_collision=False, fade="house")
    b.prop(P, "pipe", (-35.4, 2.2, 30), yaw=90, size=(2.0, 1, 1), has_collision=False)
    b.prop(P, "trash_bags", (-36.0, 0, 25.5))
    # Blood trail towards the nest.
    for i, (x, z) in enumerate(((-37.2, 28.5), (-37.6, 30.8), (-38.1, 33.2), (-38.5, 35.6), (-38.9, 38.0))):
        b.prop(D, "stain", (x, 0, z), yaw=i * 37, color=(0.3, 0.06, 0.05), size=(0.8, 1, 0.8), has_collision=False)
    # Stalker nest: rags laid in a ring, bones, melted snow.
    b.prop(P, "rubble", (-39.6, 0, 40.4), color=(0.35, 0.3, 0.28))
    for i in range(7):
        a = i / 7.0 * math.tau
        c = [(0.3, 0.32, 0.36), (0.45, 0.2, 0.18), (0.8, 0.8, 0.78), (0.25, 0.3, 0.25)][i % 4]
        b.block(D, "Rag", (-39.4 + math.cos(a) * 1.1, 0.02, 40.6 + math.sin(a) * 0.9), (0.5, 0.06, 0.35), c, yaw=i * 51,
                snow_mask=0.3, material="fabric", **FLAT)
    for i in range(4):
        b.block(D, "Bone", (-39.0 + i * 0.3, 0.04, 40.2 + (i % 2) * 0.4), (0.4, 0.06, 0.06), (0.85, 0.82, 0.74), yaw=i * 40,
                snow_mask=0.2, material="plain", **FLAT)
    b.prop(D, "stain", (-39.4, 0, 40.6), color=(0.34, 0.36, 0.38), size=(1.6, 1, 1.6), has_collision=False)
    # Secret #3 — a marked snowdrift behind the shop hides a courier's cellar.
    b.block(P, "MarkerStick", (-28.2, 0, 27.6), (0.05, 1.6, 0.05), (0.35, 0.25, 0.15), yaw=8, material="planks", has_collision=False, snow_mask=0.5)
    b.block(P, "MarkerRag", (-28.05, 1.35, 27.6), (0.3, 0.2, 0.03), (0.75, 0.12, 0.1), material="fabric", has_collision=False, snow_mask=0.4)
    b.door(I, "CellarDrift", (-29.5, 0, 28.5), visual="prop", open_mode="hide", blocker=(0.2, 0.2, 0.2),
           visual_kw={"kind": "drift", "size": (2.2, 1.1, 2.0), "has_collision": False}, interact=(2.6, 2.2, 2.6),
           display_name="Сугроб с отметкой", interaction_text="Раскопать",
           open_text="Под снегом — деревянный люк погреба. Кто-то очень хотел, чтобы его не нашли.",
           consequences=[{"set_flag": "found_courier_cellar"}])
    cellar = b.loot(I, "CellarStash", (-29.5, 0, 28.5), "Погреб курьера", "pantry",
                    items={"canned_meat": 2, "batteries": 2, "chocolate": 1}, interaction_text="Спуститься",
                    available_if=[{"flag": "found_courier_cellar"}], hide_when_unavailable=True, shape=(1.8, 2.0, 1.8),
                    found_text="Внизу — аккуратные стопки посылок с адресами. И еда.")
    b.block(cellar, "Hatch", (0, 0.02, 0), (1.2, 0.08, 1.2), (0.4, 0.3, 0.2), material="planks", snow_mask=0.4, **FLAT)
    b.block(cellar, "Hole", (0.3, 0.07, 0), (0.6, 0.02, 1.0), (0.03, 0.03, 0.04), material="plain", snow_mask=0.0, **FLAT)
    b.info(I, "CellarNote", (-27.4, 0, 29.4), "note_courier", shape=(1.2, 2.0, 1.2),
           available_if=[{"flag": "found_courier_cellar"}], hide_when_unavailable=True)
    # Interactables.
    b.hide(I, "AlleyBin1", (-39.1, 0, 16), "Мусорный бак")
    b.hide(I, "AlleyBin2", (-36.9, 0, 31), "Мусорный бак")
    b.loot(I, "AlleyPallets", (-39.0, 0, 23.5), "Поддоны", items={"wood": 2}, interaction_text="Разобрать")
    b.loot(I, "AlleyCrate", (-36.9, 0, 37.5), "Ящик", "trash")
    b.loot(I, "AlleyBags", (-36.0, 0, 25.5), "Мешки с мусором", "trash", shape=(1.6, 2.0, 1.4))
    b.exam(I, "Device", (-38, 0, 42.2), "Тёплый предмет",
           "Тёмный металлический цилиндр высотой по колено. Он тёплый — как живое существо. Снег тает вокруг него идеальным кругом, "
           "асфальт под ним сухой. На крышке выгравирован знак: круг и три черты.\n\nЛучше его не трогать.",
           consequences=[{"add_info": "device_warm"}], shape=(2.2, 2.0, 2.2))
    b.exam(I, "Symbol", (-40.9, 0, 22), "Знак", "Свежая краска поверх кирпича: круг и три вертикальные черты внутри, как падающий снег. Краска не замёрзла.",
           consequences=[{"set_flag": "seen_symbol"}], shape=(1.2, 2.4, 1.6), label="Знак на стене")
    tr1 = b.exam(I, "TracksAlley", (-38, 0, 19), "Следы",
                 "Цепочка трёхпалых следов уходит в глубь переулка. Шаг — почти два метра. Края отпечатков оплавлены, "
                 "будто то, что прошло здесь, было тёплым.", available_if=[{"day_min": 2}], hide_when_unavailable=True,
                 consequences=[{"set_flag": "q04_alley_tracks"}], shape=(2.4, 2, 3), label="Странные следы")
    b.prop(tr1, "tracks", (0, 0, 0), yaw=180, size=(1, 1, 3.5), has_collision=False, name="Prints")
    b.exam(I, "BloodTrail", (-37.8, 0, 32.4), "Бурый след",
           "Бурые пятна тянутся от бака вглубь переулка, к стене. Кого-то тащили. Пятна замёрзли — но не выцвели.",
           shape=(1.8, 2.0, 2.2), label="Пятна на снегу")
    b.loot(I, "StalkerNest", (-39.6, 0, 40.4), "Гнездо", "stalker_remains", interaction_text="Порыться",
           shape=(2.0, 2.0, 1.8), found_text="Среди тряпья — куртка с нашивкой «Скорая помощь. П/с 3». Рукав оторван.",
           consequences=[{"set_flag": "found_partner_jacket"}])
    b.exam(I, "NestLook", (-36.2, 0, 41.2), "Гнездо",
           "Тряпьё уложено кругом, как в птичьем гнезде. Снег внутри круга подтаял. Кости не звериные. "
           "Отсюда хорошо видно двор и заднюю дверь магазина.", shape=(1.4, 2.0, 1.6), label="Круг из тряпья")


# =====================================================================================
# South side: post office, substation + loading dock, boiler house, bus stop
# =====================================================================================

def south_side(b, B, P, I):
    b.building(B, "PostOffice", -14, 12, 0, 22, 4.5, (0.6, 0.6, 0.62), yaw=180, material="plaster", floors=1,
               trim_color=(0.7, 0.7, 0.72), window_faces="snew", shop_front=True, sign_color=(0.3, 0.4, 0.55),
               has_entrance=True, entrance_x=3, seed_value=20, show_on_map=True, map_label="Почта", fade="post")
    b.building(B, "Substation", 20, 13, 38, 28, 7, (0.52, 0.52, 0.54), yaw=180, material="concrete", floors=2,
               trim_color=(0.62, 0.62, 0.64), window_faces="sn", boarded_windows=0.5, lit_windows=0.0, has_entrance=True,
               entrance_x=0, seed_value=9, show_on_map=True, map_label="Подстанция №9", fade="substation")
    b.building(B, "House14", 45, 10, 72, 30, 12, (0.36, 0.4, 0.46), yaw=180, material="plaster", floors=4,
               trim_color=(0.58, 0.6, 0.64), roof_type="gable", roof_color=(0.22, 0.22, 0.26), window_faces="sn",
               balconies=0.3, has_entrance=True, entrance_x=0, lit_windows=0.1, seed_value=14,
               show_on_map=True, map_label="Дом 14", fade="house14")
    b.building(B, "BoilerHouse", -20, 34, -8, 42, 5, (0.45, 0.3, 0.25), yaw=180, material="brick", floors=1,
               trim_color=(0.55, 0.5, 0.45), window_faces="snew", boarded_windows=0.35, has_entrance=True, entrance_x=2,
               rooftop=False, seed_value=30, show_on_map=True, map_label="Котельная", fade="boiler")
    b.block(B, "Chimney", (-10.5, 0, 39.5), (1.8, 20, 1.8), (0.45, 0.28, 0.22), shape="cylinder", material="brick", fade="boiler")
    b.block(B, "ChimneyBand", (-10.5, 17.5, 39.5), (1.9, 0.5, 1.9), (0.8, 0.8, 0.78), shape="cylinder", material="paint", fade="boiler", has_collision=False)
    b.prop(P, "symbol", (33.5, 0, 12.9), yaw=180, has_collision=False, fade="substation")
    b.prop(P, "fence", (22.5, 0, 10), size=(2.25, 1, 1))
    b.prop(P, "fence", (35.5, 0, 10), size=(2.25, 1, 1))
    b.prop(P, "crate", (37.2, 0, 11.6), color=(0.3, 0.35, 0.3), size=(1.2, 1, 1))
    b.prop(P, "crate", (22, 0, 12), color=(0.35, 0.35, 0.38), size=(2.2, 1.6, 1.4))
    # Loading dock behind the substation.
    b.block(B, "Dock", (35, 0, 32.5), (6, 1.2, 9), (0.5, 0.5, 0.52), material="concrete")
    b.prop(P, "stairs", (35, 0, 38.25), size=(1.6, 1.2, 2.5))
    b.prop(P, "garage_door", (35, 1.2, 28.06), size=(1.2, 1, 1), color=(0.4, 0.42, 0.45))
    b.prop(P, "pallet", (33.2, 1.2, 31.5))
    b.prop(P, "boxes", (36.8, 1.2, 31.2))
    b.prop(P, "crate", (33.6, 1.2, 35.2), size=(1.0, 1.0, 1.0), color=(0.3, 0.38, 0.3))
    # Post office / boiler dressing.
    b.prop(P, "mailboxes", (-4.5, 0, 11.7), yaw=180, color=(0.2, 0.35, 0.6))
    b.prop(P, "rubble", (-16.5, 0, 31.5), color=(0.12, 0.12, 0.13), name="CoalPile")
    b.prop(P, "barrel", (-12.5, 0, 32.8), color=(0.2, 0.25, 0.2))
    b.prop(P, "bus_stop", (12, 0, 8.4), yaw=180)
    b.prop(P, "bench", (8, 0, 30), yaw=180)
    b.prop(P, "fence", (8, 0, 26), size=(4.0, 1, 1))
    b.prop(P, "street_sign", (44.6, 0, 8.6), color=(0.4, 0.42, 0.45))
    b.area(I, "SubstationDoor", S_EXAM, (29, 0, 12.2), {"display_name": "Дверь подстанции", "interaction_text": "Осмотреть", "title": "Подстанция №9",
        "text": "Заперто изнутри. Сквозь металл идёт низкий ровный гул — будто что-то внутри всё ещё работает. Когда-нибудь вы узнаете, что там.",
        "consequences": [{"add_info": "note_substation"}, {"set_flag": "saw_substation"}]}, shape=("box", (2.2, 2.4, 1.2)))
    b.loot(I, "SubstationBox", (37.2, 0, 11.0), "Ящик у забора", "electrical_box", items={"pistol_ammo": 2}, shape=(1.6, 1.6, 1.4))
    b.loot(I, "DockCrate", (33.6, 1.2, 35.2), "Ящики на рампе", "shop_stock", shape=(1.6, 2.0, 1.6))
    b.exam(I, "DockGate", (35, 1.2, 29.3), "Задние ворота подстанции",
           "Ворота заварены изнутри — шов свежий. Из-под них тянет сухим теплом, а снег у порога растаял до бетона.",
           shape=(2.6, 2.0, 1.4), label="Ворота подстанции")
    b.loot(I, "PostBox", (-4.5, 0, 10.9), "Почтовые ящики", "office_desk", interaction_text="Порыться", shape=(1.6, 2.0, 1.2),
           found_text="Непрочитанные извещения. Все — на одно число, 3 ноября.")
    b.loot(I, "CoalPile", (-16.5, 0, 31.5), "Угольная куча", "woodpile", interaction_text="Набрать топлива", shape=(1.8, 2.0, 1.8))
    b.exam(I, "BoilerDoor", (-16, 0, 33.2), "Котельная",
           "Котельная остыла. Дверь заварена снаружи — по приказу, написанному прямо на ней мелом: «ОТКЛЮЧЕНО. МЕРИДИАН». "
           "Весь квартал замёрз, потому что кто-то решил, что так нужно.", shape=(2.2, 2.0, 1.4), label="Дверь котельной",
           consequences=[{"set_flag": "seen_boiler_order"}])
    b.exam(I, "BusStop", (12, 0, 9.6), "Остановка",
           "В расписании кто-то обвёл последний рейс: «18:40, 3 ноября». Рядом приписано: «НЕ ПРИШЁЛ». И ниже, другой рукой: «И не придёт».",
           shape=(3.6, 2.0, 1.4), label="Автобусная остановка")


# =====================================================================================
# Garages (Гараж 14 enterable), lane, parking lot
# =====================================================================================

def garages(b, B, P, I, D):
    gc = (0.5, 0.5, 0.52)
    for (x0, x1, name) in ((47, 65, "GaragesW"), (71, 80, "GaragesE")):
        b.block(B, name, ((x0 + x1) / 2.0, 0, 36), (x1 - x0, 3.0, 8), gc, material="concrete", fade="garages", show_on_map=True, map_label="Гаражи")
        b.block(B, name + "Roof", ((x0 + x1) / 2.0, 3.0, 36), (x1 - x0, 0.2, 8.4), (0.28, 0.28, 0.3), material="roof", fade="garages", has_collision=False)
    for x in (50, 56):
        b.prop(P, "garage_door", (x, 0, 40.06), fade="garages", color=(0.45, 0.5, 0.48) if x == 50 else (0.5, 0.42, 0.36))
    b.block(P, "GarageDoorHalf", (62, 1.1, 40.06), (3.0, 1.5, 0.1), (0.42, 0.45, 0.5), material="container", snow_mask=0.4, fade="garages")
    b.block(P, "GarageGap", (62, 0, 40.03), (3.0, 1.1, 0.02), (0.03, 0.03, 0.04), material="plain", snow_mask=0.0, has_collision=False, fade="garages")
    b.prop(P, "drift", (62, 0, 40.8), size=(2.4, 0.5, 1.2), has_collision=False)
    b.prop(P, "garage_door", (74, 0, 40.06), fade="garages", color=(0.35, 0.4, 0.45))
    b.prop(P, "garage_door", (78.2, 0, 40.06), size=(0.6, 1, 1), fade="garages", color=(0.5, 0.5, 0.45))
    # Гараж 14.
    g = b.s.node("Garage14", "Node3D", B)
    b.indoor_parents.add(g)
    b.block(g, "Floor", (68, 0, 36), (6, 0.06, 8), (0.36, 0.36, 0.38), snow_mask=0.0, material="concrete", has_collision=False, fadeable=False,
            show_on_map=True, map_label="Гараж 14")
    b.walls(g, "garage14", 65, 32, 71, 40, 3.0, gc, [("s", 68, 3.0)], material="concrete", t=0.25)
    b.block(g, "Roof", (68, 3.0, 36), (6.0, 0.2, 8.4), (0.28, 0.28, 0.3), groups=["cutaway:garage14"], has_collision=False, fade="garage14", material="roof")
    b.block(g, "Number", (69.9, 2.75, 40.02), (0.5, 0.3, 0.04), (0.9, 0.85, 0.6), snow_mask=0.0, has_collision=False, material="paint")
    b.prop(g, "sedan", (68.9, 0, 35.9), yaw=90, color=(0.3, 0.36, 0.28))
    b.prop(g, "workbench", (65.7, 0, 38.2), yaw=90)
    b.prop(g, "tool_wall", (65.3, 0, 35.0), yaw=90)
    b.prop(g, "shelf", (66.5, 0, 32.55))
    b.prop(g, "tires", (70.3, 0, 38.9), size=(1, 0.75, 1))
    b.prop(g, "ceiling_lamp", (68, 0, 36), lit=False)
    b.prop(g, "stain", (68.9, 0.02, 35.5), color=(0.06, 0.06, 0.06), size=(1.2, 1, 1.2), has_collision=False)
    b.door(I, "Garage14Door", (68, 0, 39.875), width=3.0, height=2.4, visual="rollup", color=(0.46, 0.44, 0.38), fade="garage14",
           display_name="Гараж 14", locked=True, key_item="garage_key",
           locked_text="Гараж 14. Висячий замок, крепкий. Нужен ключ — или монтировка, или отмычка.",
           open_text="Ворота со скрежетом уходят вверх.", interact=(3.4, 2.2, 2.4), blocker=(3.0, 2.4, 0.3))
    b.door(I, "GaragePit", (66.4, 0, 36.3), width=1.1, height=1.9, visual="hatch", color=(0.3, 0.32, 0.3), open_mode="hide",
           blocker=(0.1, 0.1, 0.1), interact=(1.4, 2.0, 2.2), display_name="Смотровая яма", interaction_text="Поднять люк",
           open_text="Под люком — смотровая яма. На дне — зелёный армейский ящик.", consequences=[{"set_flag": "garage_pit_opened"}])
    pit = b.loot(I, "GaragePitCrate", (66.4, 0, 36.3), "Ящик в яме", "military_crate", items={"dog_tag": 1, "pistol_ammo": 6},
                 available_if=[{"flag": "garage_pit_opened"}], hide_when_unavailable=True, interaction_text="Открыть ящик",
                 shape=(1.4, 2.0, 2.2), found_text="Армейский ящик. Сверху — жетон на цепочке: «К. СОРЕЛЬ». Номер части затёрт ножом.")
    b.block(pit, "Pit", (0, 0.035, 0), (1.0, 0.02, 1.8), (0.03, 0.03, 0.04), material="plain", snow_mask=0.0, **FLAT)
    b.prop(pit, "crate", (0, 0.0, 0.3), size=(0.7, 0.35, 0.5), color=(0.28, 0.34, 0.24), has_collision=False)
    b.info(I, "GarageNote", (68.9, 0, 33.3), "note_garage", interaction_text="Прочитать записку", shape=(2.0, 2.0, 1.2))
    b.loot(I, "GarageShelf", (66.5, 0, 33.1), "Полки", "garage_shelf", shape=(1.8, 2.0, 1.2))
    b.loot(I, "GarageBench", (66.2, 0, 38.4), "Верстак", "toolbox", items={"repair_kit": 1}, shape=(1.2, 2.0, 1.8))
    b.pick(I, "GarageFuel", (70.0, 0, 32.9), "fuel_can", radius=0.7)
    b.loot(I, "GarageCar", (67.4, 0, 38.5), "Машина Антона", "car_trunk", shape=(1.0, 2.0, 1.6))
    b.loot(I, "GarageHalfOpen", (62, 0, 41.0), "Приоткрытый гараж", "garage_shelf", interaction_text="Пролезть",
           shape=(2.6, 2.0, 1.4), found_text="Под воротами можно пролезть ползком. Внутри — ржавые полки и мешок с ветошью.")
    b.exam(I, "GarageSign", (44, 0, 9.6), "ГСК «Север»",
           "Табличка гаражного кооператива: «Въезд только для членов ГСК». Ниже приклеено: «Сбор взносов отменяется. Председатель уехал».",
           shape=(1.6, 2.0, 1.4), label="Табличка ГСК")
    # Parking lot.
    b.prop(P, "sedan", (40.5, 0, 46), yaw=90, color=(0.3, 0.42, 0.3))
    b.prop(P, "van", (48, 0, 51.5), color=(0.6, 0.6, 0.58))
    b.prop(P, "sedan", (60, 0, 46), yaw=95, color=(0.5, 0.45, 0.3))
    b.prop(P, "drift", (60.6, 0, 46.2), size=(3.4, 1.0, 2.4), has_collision=False)
    b.prop(P, "sedan", (75.5, 0, 50.5), yaw=80, color=(0.25, 0.25, 0.3))
    b.prop(P, "cart", (44.2, 0, 43.2), yaw=40)
    b.prop(P, "corpse", (52, 0, 43.4), yaw=30, color=(0.3, 0.3, 0.2))
    b.prop(P, "bin", (36.5, 0, 52.4), yaw=90)
    b.prop(P, "trash_bags", (38.2, 0, 53.2))
    b.prop(P, "lamp", (56, 0, 53.4), yaw=180, lit=False)
    b.prop(P, "lamp", (42, 0, 53.4), yaw=180, lit=False)
    b.prop(P, "tires", (44.5, 0, 38.6), size=(1, 0.5, 1))
    b.loot(I, "ParkedCar1", (42.0, 0, 46), "Машина на стоянке", "car_glovebox", shape=(1.4, 2.0, 2.6))
    b.loot(I, "ParkedVan", (48, 0, 49.8), "Фургон", "car_trunk", shape=(2.6, 2.0, 1.4))
    b.loot(I, "ParkedCar2", (73.8, 0, 50.5), "Машина у забора", "car_glovebox", shape=(1.4, 2.0, 2.6))
    b.loot(I, "ParkingCart", (44.2, 0, 43.2), "Тележка", "trash", shape=(1.4, 2.0, 1.4))
    b.loot(I, "Scavenger", (52, 0, 43.4), "Замёрзший человек", "corpse_scavenger", items={"garage_key": 1}, interaction_text="Обыскать",
           shape=(1.6, 2.0, 1.6), found_text="В кулаке — ломик, в кармане — ключ с биркой «Гараж 14 — Антон» и сложенный листок.")
    b.info(I, "ScavengerNote", (53.8, 0, 44.4), "note_scavenger", interaction_text="Поднять листок", shape=(1.2, 2.0, 1.2))
    b.hide(I, "ParkingBin", (36.5, 0, 51.6), "Мусорный контейнер", shape=(2.0, 2.0, 1.4))


# =====================================================================================
# Main street: cars, blockade, poles and wires, lamps, stories
# =====================================================================================

def main_street(b, P, I, D):
    b.prop(P, "car", (-10, 0, 1.2), yaw=8, color=(0.42, 0.18, 0.16))
    b.prop(P, "police_car", (-24, 0, 3.0), yaw=-15, lit=True)
    b.prop(P, "sedan", (8, 0, -2.8), yaw=-5, color=(0.25, 0.35, 0.5), name="Car2")
    b.prop(P, "ambulance", (31, 0, 2.8), yaw=172)
    b.prop(P, "van", (48, 0, -2.5), yaw=5, color=(0.72, 0.7, 0.62))
    b.prop(P, "sedan", (-66, 0, 2), yaw=-3, color=(0.5, 0.48, 0.45), name="BuriedCar")
    b.prop(P, "drift", (-66.3, 0, 2.3), size=(5.2, 1.5, 2.8), has_collision=False)
    b.block(P, "Shovel", (-64.2, 0, 3.6), (0.06, 1.3, 0.06), (0.35, 0.25, 0.15), yaw=20, material="planks", has_collision=False, snow_mask=0.4)
    # East blockade.
    b.prop(P, "truck", (64, 0, 1), yaw=55)
    b.prop(P, "bus", (74, 0, -2), yaw=100)
    b.prop(P, "barricade", (68, 0, -5.2), size=(1.4, 1, 1))
    for (x, z, yaw) in ((60, -3.6, 0), (61.2, -2.8, 30), (59.5, 3.2, 0), (60.8, 4.0, 60), (62.3, -4.1, 80)):
        b.prop(P, "cone", (x, 0, z), yaw=yaw)
    b.prop(P, "drift", (70, 0, 4.5), size=(4, 1.4, 2.5))
    b.prop(P, "drift", (77, 0, -6), size=(4, 2.0, 3))
    # Poles and sagging wires along the south sidewalk.
    poles = [-74, -58, -43, -30, -14, 2, 18, 34, 50, 66]
    for x in poles:
        b.prop(P, "power_pole", (x, 0, 8.6))
    for a, c in zip(poles, poles[1:]):
        b.prop(P, "wires", ((a + c) / 2.0, 0, 8.6), size=((c - a) / 10.0, 1, 1), has_collision=False)
    for x in (-62, -30, 8, 44):
        b.prop(P, "lamp", (x, 0, -7.0), lit=False)
    for x in (-22, 22, 56):
        b.prop(P, "lamp", (x, 0, 7.0), yaw=180, lit=False)
    b.prop(P, "bin", (18, 0, 7.4))
    b.prop(P, "street_sign", (-44.8, 0, 8.4), yaw=180, color=(0.2, 0.32, 0.55))
    for (x, z, sx) in ((-35, 8.4, 2.4), (-5, 8.6, 3.0), (27, -8.6, 2.6), (40, 8.5, 2.0), (-66, -8.6, 3.2), (-20, -8.8, 1.8), (58, 8.5, 2.8)):
        b.prop(P, "drift", (x, 0, z), size=(sx, 0.5, 1.2), has_collision=False)
    # Car interactables (names kept for tests / saves).
    b.loot(I, "CarInterior", (-10.3, 0, 2.6), "Брошенная машина", "car_glovebox", items={"pistol": 1, "pistol_ammo": 4}, shape=(2.6, 2, 1.4),
           found_text="В бардачке — старый пистолет, завёрнутый в тряпку. Патронов мало.")
    b.loot(I, "CarTrunk", (-12.9, 0, 1.0), "Багажник", "car_trunk", items={"electronics": 1}, interaction_text="Вскрыть",
           required_item="crowbar", requirement_text="Багажник заклинило. Нужна монтировка.", shape=(1.2, 2, 2.2))
    b.loot(I, "Car2", (8, 0, -1.4), "Машина", "car_glovebox", shape=(2.6, 2, 1.4))
    b.loot(I, "PoliceCar", (-23.6, 0, 4.6), "Патрульная машина", "car_glovebox", items={"evac_map": 1}, shape=(2.6, 2.0, 1.4),
           found_text="Под сиденьем — сложенная карта района с красными стрелками к северному КПП.")
    b.info(I, "PoliceLog", (-23.6, 0, 1.4), "police_log", interaction_text="Взять журнал", shape=(2.2, 2.0, 1.2))
    b.loot(I, "Ambulance", (31.2, 0, 1.3), "Машина скорой помощи", "medicine_cabinet", items={"locket": 1}, shape=(2.8, 2.0, 1.4),
           found_text="Задние двери распахнуты, носилки пусты. В кабине, под сиденьем водителя — медальон на порванной цепочке.")
    b.loot(I, "VanDelivery", (48, 0, -1.0), "Фургон доставки", "car_trunk", shape=(2.8, 2.0, 1.4))
    b.loot(I, "Bus", (71.4, 0, -2.4), "Автобус", "car_trunk", shape=(1.4, 2.0, 3.0))
    b.loot(I, "TruckCargo", (61.2, 0, 3.8), "Кузов грузовика", "shop_stock", interaction_text="Вскрыть кузов", shape=(2.0, 2.0, 2.0))
    b.loot(I, "BuriedCarLoot", (-66, 0, 3.6), "Машина под снегом", "car_glovebox", interaction_text="Пролезть в салон", shape=(2.6, 2.0, 1.4))
    b.hide(I, "StreetBin", (18, 0, 6.6), "Мусорный бак", shape=(2.0, 2, 1.4))
    # Stories.
    b.exam(I, "PoliceRadio", (-26.9, 0, 3.4), "Патрульная машина",
           "Мигалка до сих пор моргает — аккумулятор держится третью неделю. Рация на панели шипит на одной ноте, "
           "и иногда сквозь шум — щелчок, будто кто-то нажимает кнопку и молчит.", shape=(1.2, 2.0, 1.8), label="Мигалка")
    b.exam(I, "Blockade", (58.6, 0, 0.5), "Затор",
           "Грузовик сложился поперёк дороги, автобус влетел в него боком. Все двери распахнуты. Людей нет. "
           "Следы уходят на восток — и через десять шагов обрываются, будто люди растворились в метели.",
           shape=(2.0, 2.0, 6.0), label="Затор на дороге", consequences=[{"set_flag": "seen_blockade"}])
    b.exam(I, "BuriedCar", (-69.2, 0, 2.0), "Машина под снегом",
           "Из-под снега торчит только крыша. Кто-то прокопал лаз к водительской двери — и бросил на полпути. "
           "Лопата так и стоит, воткнутая в сугроб.", shape=(1.4, 2.0, 2.0), label="Сугроб-машина")
    b.exam(I, "SteamManhole", (15, 0, 2.0), "Люк теплотрассы",
           "Снег вокруг люка растаял, из щели поднимается пар. Где-то под городом теплотрасса ещё жива. "
           "Здесь можно отогреть руки.", shape=(1.6, 2.0, 1.6), label="Тёплый люк")
    b.exam(I, "AmbulanceLook", (34.6, 0, 2.6), "Скорая",
           "Скорую занесло у подстанции. На борту — «П/с 3». Водительская дверь открыта, ключ в замке зажигания. "
           "Бак пуст до последней капли.", shape=(1.4, 2.0, 2.0), label="Скорая помощь")


# =====================================================================================
# Courtyard (north-west): playground, tent camp, laundry, kennel; west path
# =====================================================================================

def courtyard(b, B, P, I):
    b.prop(P, "swing", (-64.5, 0, -46.5))
    b.prop(P, "slide", (-59.5, 0, -48.5), yaw=30)
    b.prop(P, "sled", (-61.8, 0, -43.0), yaw=20)
    b.prop(P, "bench", (-56, 0, -44), yaw=-90)
    b.prop(P, "laundry_line", (-55, 0, -54), size=(1.4, 1, 1))
    b.prop(P, "kennel", (-51.5, 0, -39.5), yaw=-90)
    for (x, z, yaw, c) in ((-72, -52, 20, (0.3, 0.42, 0.34)), (-67.5, -55, -10, (0.5, 0.35, 0.25)), (-74.5, -46.5, 70, (0.25, 0.35, 0.5))):
        b.prop(P, "tent", (x, 0, z), yaw=yaw, color=c)
    b.prop(P, "barrel_fire", (-70, 0, -49.5), lit=False, name="ColdFire")
    b.prop(P, "pallet", (-68.5, 0, -47.4), yaw=30)
    b.prop(P, "boxes", (-73.5, 0, -55.5))
    b.prop(P, "sedan", (-54, 0, -35.5), yaw=85, color=(0.45, 0.2, 0.2), name="CourtyardCar")
    b.prop(P, "drift", (-54.2, 0, -35.2), size=(2.6, 1.2, 4.4), has_collision=False)
    b.prop(P, "bin", (-49.5, 0, -45), yaw=90)
    b.prop(P, "trash_bags", (-49.8, 0, -47.2))
    b.prop(P, "lamp", (-60, 0, -34), lit=False)
    for (x, z, sc) in ((-77, -40, 1.1), (-58, -57, 1.0), (-76, -58, 1.2), (-66, -35, 0.9)):
        b.prop(P, "pine", (x, 0, z), size=(1, sc, 1))
    # West path: fallen pole, ski track.
    b.prop(P, "power_pole", (-76, 0, -18))
    b.block(P, "FallenPole", (-72.5, 0.0, -27.5), (0.3, 0.3, 7.5), (0.3, 0.22, 0.15), yaw=35, material="planks", snow_mask=1.0, has_collision=False)
    for i in range(6):
        b.block(P, "SkiTrack", (-73.5 - i * 0.2, 0.02, -12 - i * 3.2), (0.08, 0.01, 3.0), (0.62, 0.66, 0.72), yaw=4,
                material="plain", snow_mask=0.0, **FLAT)
        b.block(P, "SkiTrack", (-73.0 - i * 0.2, 0.02, -12 - i * 3.2), (0.08, 0.01, 3.0), (0.62, 0.66, 0.72), yaw=4,
                material="plain", snow_mask=0.0, **FLAT)
    b.pick(I, "PlushBear", (-61.3, 0, -42.5), "plush_bear", radius=0.7)
    b.loot(I, "TentChild", (-71.6, 0, -50.3), "Палатка", "wardrobe", items={"child_drawing": 1}, interaction_text="Заглянуть",
           shape=(2.2, 2.0, 1.4), found_text="Детский спальник, фонарик без батареек и рисунок, приколотый к стенке палатки.")
    b.loot(I, "TentPharmacist", (-67.7, 0, -53.2), "Палатка", "trash", items={"pharmacy_key": 1}, interaction_text="Заглянуть",
           shape=(2.2, 2.0, 1.4), found_text="Белый халат, аккуратно сложенный. В кармане — ключ с зелёным крестиком.")
    b.loot(I, "TentBlue", (-72.9, 0, -45.9), "Палатка", "corpse_civilian", interaction_text="Заглянуть", shape=(1.4, 2.0, 2.2),
           found_text="Внутри кто-то лежит, укрытый с головой. Вы не поднимаете одеяло. Рядом — сумка.")
    b.loot(I, "CourtyardCar", (-52.3, 0, -35.5), "Машина во дворе", "car_trunk", shape=(1.4, 2.0, 2.6))
    b.hide(I, "CourtyardBin", (-50.3, 0, -45), "Мусорный бак")
    b.exam(I, "Camp", (-70, 0, -48.2), "Лагерь во дворе",
           "Три палатки вокруг остывшего бочонка-очага. На растяжке маркером: «ЖДЁМ АВТОБУС ГО. НЕ УХОДИМ». "
           "Угли давно покрылись инеем.", shape=(2.0, 2.0, 1.6), label="Остывший очаг")
    b.exam(I, "Swing", (-64.5, 0, -45.0), "Качели",
           "Качели раскачиваются сами — ветер. Цепи звенят тонко, как колокольчик. На сиденье — отпечаток маленького ботинка.",
           shape=(2.0, 2.0, 1.4), label="Качели")
    b.exam(I, "Sled", (-62.5, 0, -43.8), "Санки",
           "Детские санки брошены посреди двора. Верёвка перерезана — ровно, ножом. Кто-то тянул их — и отпустил.",
           shape=(1.4, 2.0, 1.4), label="Санки")
    b.exam(I, "Laundry", (-55, 0, -52.8), "Бельё на верёвке",
           "Бельё замёрзло колом — висит ровно, как нарисованное. Его вывесили сушиться утром третьего ноября.",
           shape=(4.6, 2.0, 1.4), label="Бельё")
    b.exam(I, "Kennel", (-53.2, 0, -39.5), "Будка",
           "Будка пуста. Цепь не перерезана — перекушена. Миска вылизана дочиста, а снег вокруг утоптан кругами.",
           shape=(1.4, 2.0, 1.8), label="Собачья будка")
    b.exam(I, "SkiTrail", (-73.2, 0, -20), "Лыжня",
           "Свежая лыжня уходит на запад — за край квартала, в белое. Кто-то уходит отсюда. Ночью. Один.",
           shape=(2.4, 2.0, 3.0), label="Лыжня", consequences=[{"set_flag": "seen_ski_trail"}])


# =====================================================================================
# Trees, drifts, bounds, skyline, construction site
# =====================================================================================

def edges(b, s, P, I):
    # Construction site north-east.
    b.prop(P, "fence", (54, 0, -36), size=(2.6, 1, 1))
    b.prop(P, "fence", (70, 0, -36), size=(2.6, 1, 1))
    b.block(P, "SiteCabin", (60, 0, -46), (6, 2.6, 2.6), (0.32, 0.42, 0.36), material="container")
    b.block(P, "Foundation", (66, 0, -54), (14, 0.8, 8), (0.52, 0.52, 0.54), material="concrete")
    for i, x in enumerate((50, 51.9, 53.8)):
        b.block(P, "ConcreteRing", (x, 0, -44), (1.8, 1.2, 1.8), (0.55, 0.55, 0.56), shape="cylinder", material="concrete")
    b.prop(P, "pipe", (56, 0, -52), size=(1.5, 1, 1))
    b.prop(P, "pipe", (56, 0.4, -52.6), size=(1.5, 1, 1))
    b.prop(P, "tires", (73, 0, -44), size=(1, 1.0, 1))
    b.prop(P, "barrel", (62.6, 0, -44.2), color=(0.6, 0.45, 0.15))
    b.exam(I, "SiteSign", (60, 0, -43.6), "Стройка",
           "Табличка на бытовке: «Объект проекта «Меридиан». Ретранслятор №2. Срок сдачи — 1 декабря». "
           "Фундамент залит, дальше дело не пошло.", shape=(3.0, 2.0, 1.4), label="Бытовка")
    b.loot(I, "SiteCabinLoot", (57.6, 0, -44.2), "Бытовка", "toolbox", interaction_text="Открыть", shape=(1.6, 2.0, 1.4))
    for (x, z, sc) in ((-30, 40, 1.0), (-25, 50, 1.2), (5, 45, 0.9), (15, 38, 1.1), (-66, 40, 1.0), (70, -60, 1.0),
                       (-4, 52, 0.8), (28, 46, 1.0), (22, 52, 1.2), (-72, 20, 1.1), (-68, 30, 0.9), (48, -60, 1.1), (76, -40, 1.0)):
        b.prop(P, "pine", (x, 0, z), size=(1, sc, 1))
    for i in range(26):
        x = random.uniform(-76, 76)
        z = random.uniform(8, 54) if random.random() < 0.6 else random.uniform(-64, -34)
        # Keep paths, buildings and yards free.
        if (-62 < x < -40 and 8 < z < 28) or (-35 < x < -17 and 9 < z < 23) or (-42 < x < -33) or (30 < x < 80 and 30 < z < 54):
            continue
        if (-47 < x < 44 and -58 < z < -30) or (-21 < x < 7 and 11 < z < 43) or (19 < x < 39 and 12 < z < 40) or (44 < x < 73 and 9 < z < 31):
            continue
        b.prop(P, "drift", (x, 0, z), size=(random.uniform(1.5, 3.5), random.uniform(0.6, 1.4), random.uniform(1.5, 3.0)), has_collision=False)
    for x in range(-78, 80, 8):
        b.prop(P, "drift", (x, 0, 55), size=(5, 2.5, 3), has_collision=False)
    for z in range(-60, 56, 8):
        b.prop(P, "drift", (-79, 0, z), size=(3, 2.5, 5), has_collision=False)
        b.prop(P, "drift", (79, 0, z), size=(3, 2.5, 5), has_collision=False)
    for x in range(-78, -8, 8):
        b.prop(P, "drift", (x, 0, -65), size=(5, 2.8, 3), has_collision=False)
    for x in range(14, 80, 8):
        b.prop(P, "drift", (x, 0, -65), size=(5, 2.8, 3), has_collision=False)

    bounds = s.node("Bounds", "Node3D", ".")
    for (name, pos, size) in (("West", (-81, 3, -5), (2, 6, 130)), ("East", (81, 3, -5), (2, 6, 130)), ("North", (0, 3, -67.5), (170, 6, 2)), ("South", (0, 3, 57), (170, 6, 2))):
        body = s.node(name, "StaticBody3D", bounds, {"transform": Tr(*pos)})
        s.node("Shape", "CollisionShape3D", body, {"shape": s.sub("BoxShape3D", {"size": V3(*size)})})

    sky = s.node("Skyline", "Node3D", ".")
    for i in range(26):
        ang = i / 26.0 * 6.283 + random.uniform(-0.1, 0.1)
        r = random.uniform(115, 150)
        x, z = math.cos(ang) * r, math.sin(ang) * r * 0.9 - 5
        h = random.uniform(16, 38)
        b.block(sky, "Tower", (x, 0, z), (random.uniform(12, 22), h, random.uniform(12, 20)), (0.2, 0.22, 0.27), material="concrete",
                snow_mask=0.5, **FLAT)
        if random.random() < 0.3:
            b.block(sky, "LitWindow", (x, h * 0.6, z + 10.2), (1.2, 1.4, 0.2), (1.0, 0.75, 0.45), emission=2.5, snow_mask=0.0, material="glass", **FLAT)
    b.block(sky, "Meridian", (0, 0, -175), (10, 60, 10), (0.16, 0.17, 0.2), material="concrete", **FLAT)
    b.block(sky, "MeridianLight", (0, 60, -175), (1.5, 1.5, 1.5), (1.0, 0.2, 0.15), emission=6.0, snow_mask=0.0, material="glass", **FLAT)


# =====================================================================================
# Zones, spawns, enemy routes
# =====================================================================================

def zones(b, s):
    Z = s.node("Zones", "Node3D", ".")
    locs = [
        ("shelter_street", "У дома 12", (-51, 0, -4), (26, 4, 12)),
        ("main_street", "Главная улица", (0, 0, 0), (150, 4, 14)),
        ("car", "Брошенная машина", (-10, 0, 1.5), (9, 4, 7)),
        ("narrow_street", "Узкая улица", (0, 0, -19), (7, 4, 20)),
        ("square", "Малая площадь", (0, 0, -44), (40, 4, 28)),
        ("radio_point", "Радиоточка", (12, 0, -51), (9, 4, 7)),
        ("pharmacy", "Аптека", (32, 0, -46), (16, 4, 16)),
        ("house", "Жилой дом №7", (-51, 0, 18), (18, 4, 16)),
        ("shop", "Магазин «Северный»", (-26, 0, 16), (16, 4, 12)),
        ("alley", "Переулок", (-38, 0, 27), (6, 4, 38)),
        ("substation", "Подстанция №9", (29, 0, 11), (22, 4, 6)),
        ("north_road", "Северная дорога", (0, 0, -61), (12, 4, 8)),
        ("radio_station", "Радиоузел", (33, 0, -23), (22, 8, 26)),
        ("courtyard", "Двор за домом 12", (-63, 0, -45.5), (30, 4, 25)),
        ("west_path", "Западная тропа", (-71, 0, -20.5), (14, 4, 25)),
        ("passage", "Проход у дома 12", (-39.25, 0, -18.5), (3.5, 4, 19)),
        ("garages", "Гаражи ГСК «Север»", (62, 0, 36), (36, 4, 8)),
        ("garage_lane", "Гаражный проезд", (41.5, 0, 24), (7, 4, 32)),
        ("parking", "Стоянка", (55, 0, 47), (50, 4, 14)),
        ("east_blockade", "Затор на востоке", (68, 0, 0), (24, 4, 14)),
        ("boiler", "Котельная", (-14, 0, 33), (16, 4, 18)),
        ("backyard", "Задворки магазина", (-26, 0, 28), (16, 4, 12)),
        ("post", "Почта", (-7, 0, 17), (14, 4, 10)),
        ("construction", "Стройка", (62, 0, -50), (32, 4, 28)),
    ]
    for (lid, name, pos, size) in locs:
        b.area(Z, "Loc_" + lid, S_LOC, pos, {"location_id": lid, "display_name": name}, shape=("box", size))
    b.area(Z, "Indoor_shop", S_INDOOR, (-26, 0, 16), {"building_id": "shop"}, shape=("box", (15.2, 3.0, 11.2)))
    b.area(Z, "Indoor_house", S_INDOOR, (-51, 0, 18), {"building_id": "house"}, shape=("box", (17.2, 3.0, 15.2)))
    b.area(Z, "Indoor_pharmacy", S_INDOOR, (32, 0, -46), {"building_id": "pharmacy"}, shape=("box", (15.2, 3.0, 15.2)))
    b.area(Z, "Indoor_garage14", S_INDOOR, (68, 0, 36), {"building_id": "garage14"}, shape=("box", (5.4, 2.6, 7.4)))
    b.area(Z, "Indoor_radio", S_INDOOR, (32, 0, -29), {"building_id": "radio"}, shape=("box", (11.4, 3.2, 9.4)))
    b.area(Z, "Heat_barrel", S_HEAT, (0, 0, -44), {"strength": 1.7, "first_warm_flag": "found_heat_source"}, shape=("sphere", 3.4))
    b.area(Z, "Heat_device", S_HEAT, (-38, 0, 43), {"strength": 0.6}, shape=("sphere", 2.2))
    b.area(Z, "Heat_manhole", S_HEAT, (15, 0, 2), {"strength": 0.45}, shape=("sphere", 1.8))


def spawns(b, s):
    SP = s.node("Spawns", "Node3D", ".")
    for (name, pos, yaw) in (("spawn_shelter_door", (-51.5, 0, -7.6), 180), ("spawn_default", (-51.5, 0, -7.6), 180), ("spawn_square", (0, 0, -37), 0),
            ("spawn_pharmacy", (21, 0, -46), -90), ("spawn_alley", (-38, 0, 12), 180), ("spawn_north_road", (0, 0, -55), 0),
            ("spawn_house", (-51, 0, 7.5), 180), ("spawn_shop", (-26.5, 0, 7.5), 180), ("spawn_narrow_street", (0, 0, -9), 0),
            ("spawn_garages", (55, 0, 43), 0), ("spawn_radio", (33, 0, -13), 0), ("spawn_courtyard", (-64, 0, -38), 0),
            ("npc_mara_street", (2.1, 0, -19.5), 90), ("npc_elias_house", (-45.2, 0, 21.4), 0), ("npc_vera_radio", (9.2, 0, -50.4), 0),
            ("npc_anton_car", (-6.6, 0, 3.5), 90), ("npc_tomas_shop", (-23.5, 0, 17), 90), ("npc_grey_alley", (-37, 0, 40.2), 0),
            ("npc_mara_pharmacy", (31, 0, -43.5), 90), ("npc_tomas_alley", (-36.8, 0, 34), 90)):
        b.marker(SP, name, pos, yaw)
    s.node("Actors", "Node3D", ".")
    s.node("EnemySpawner", "Node3D", ".", script=S_SPAWNER)
    routes = s.node("Routes", "Node3D", "EnemySpawner")
    for (rname, pts) in (("Alley", [(-38, 0, 12), (-38, 0, 40), (-37, 0, 26)]),
                         ("Square", [(-14, 0, -55), (14, 0, -56), (14, 0, -34), (-14, 0, -34)]),
                         ("East", [(28, 0, 1), (62, 0, 2), (44, 0, -5)]),
                         ("North", [(-20, 0, -30.5), (22, 0, -30.5), (0, 0, -24)]),
                         ("Courtyard", [(-70, 0, -40), (-56, 0, -50), (-64, 0, -36)]),
                         ("Parking", [(40, 0, 44), (70, 0, 48), (55, 0, 42)])):
        r = s.node(rname, "Node3D", routes)
        for i, p in enumerate(pts):
            b.marker(r, "P%d" % i, p)
