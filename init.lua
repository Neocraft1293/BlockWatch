-- modname/init.lua

-- Chemin vers le fichier JSON
local json_file_path = minetest.get_worldpath() .. "/events.json"

-- Initialiser la variable events en dehors de load_database
local events = {}

-- Fonction pour charger la base de données
local function load_database()
    local json_file = io.open(json_file_path, "r")
    if json_file then
        events = minetest.deserialize(json_file:read("*all"))
        json_file:close()
        minetest.log("action", "[Modname] Base de données chargée avec succès.")
    else
        -- Créer le fichier JSON s'il n'existe pas
        local new_json_file = io.open(json_file_path, "w")
        new_json_file:write(minetest.serialize(events))
        new_json_file:close()
        minetest.log("action", "[Modname] Nouvelle base de données créée.")
    end
end

-- Fonction pour sauvegarder les événements dans le fichier JSON
local function save_events()
    local json_file = io.open(json_file_path, "w")
    if json_file then
        json_file:write(minetest.serialize(events))
        json_file:close()
    end
end

-- Fonction pour enregistrer un nouvel événement
local function log_event(pos, event_type, entity)
    local key = minetest.pos_to_string(pos)

    if not events[key] then
        events[key] = {}
    end

    local event = {
        event_type = event_type,
        entity = entity,
        timestamp = os.date("%Y-%m-%dT%H:%M:%S")
    }

    table.insert(events[key], event)
    save_events()
end

-- Exemple d'utilisation : enregistrez un événement lorsque le joueur casse ou place un bloc
minetest.register_on_dignode(function(pos, oldnode, digger)
    if digger then
        log_event(pos, "break", digger:get_player_name())
    end
end)

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    if placer then
        log_event(pos, "place", placer:get_player_name())
    end
end)

-- Fonction pour vérifier si la base de données est chargée
local function check_database()
    if next(events) then
        minetest.chat_send_all("[Modname] La base de données est chargée.")
    else
        minetest.chat_send_all("[Modname] La base de données n'est pas chargée.")
    end
end

-- Commande pour recharger la base de données
minetest.register_chatcommand("rdatab", {
    description = "Recharge la base de données.",
    func = function(name, param)
        load_database()
        return true, "[Modname] Base de données rechargée avec succès."
    end,
})

-- Commande pour vérifier si la base de données est chargée
minetest.register_chatcommand("check_database", {
    description = "Vérifie si la base de données est chargée.",
    func = function(name, param)
        check_database()
        return true, "[Modname] Vérification de la base de données effectuée."
    end,
})

-- Appeler la fonction load_database lors du chargement des mods
minetest.register_on_mods_loaded(load_database)
