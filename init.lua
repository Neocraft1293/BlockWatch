-- [Modname]/init.lua

-- Chemin vers le fichier JSON pour les événements
local events_json_file_path = minetest.get_worldpath() .. "/eventsbw.json"

-- Chemin vers le fichier JSON pour les données sur le bloc pointé
local blockwatch_data_json_file_path = minetest.get_worldpath() .. "/blockwatch_data.json"

-- Initialiser la variable events en dehors de load_database
local events = {}

-- Fonction pour charger la base de données des événements
local function load_events_database()
    local json_file = io.open(events_json_file_path, "r")
    if json_file then
        events = minetest.deserialize(json_file:read("*all"))
        json_file:close()
        minetest.log("action", "[Modname] Base de données des événements chargée avec succès.")
    else
        -- Créer le fichier JSON s'il n'existe pas
        local new_json_file = io.open(events_json_file_path, "w")
        new_json_file:write(minetest.serialize(events))
        new_json_file:close()
        minetest.log("action", "[Modname] Nouvelle base de données des événements créée.")
    end
end

-- Fonction pour sauvegarder les événements dans le fichier JSON
local function save_events()
    local json_file = io.open(events_json_file_path, "w")
    if json_file then
        json_file:write(minetest.serialize(events))
        json_file:close()
    end
end

-- Fonction pour charger les données sur le bloc pointé depuis la base de données
local function load_blockwatch_data()
    local json_file = io.open(blockwatch_data_json_file_path, "r")
    if json_file then
        local data = minetest.deserialize(json_file:read("*all"))
        json_file:close()
        return data or {}
    else
        return {}
    end
end

-- Fonction pour sauvegarder les données sur le bloc pointé dans le fichier JSON
local function save_blockwatch_data(data)
    local json_file = io.open(blockwatch_data_json_file_path, "w")
    if json_file then
        json_file:write(minetest.serialize(data))
        json_file:close()
    end
end

-- Fonction pour enregistrer un nouvel événement
local function log_event(pos, event_type, entity, node_name)
    local key = minetest.pos_to_string(pos)

    if not events[key] then
        events[key] = {}
    end

    local event = {
        event_type = event_type,
        entity = entity,
        node_name = node_name,
        timestamp = os.date("%Y-%m-%dT%H:%M:%S")
    }

    table.insert(events[key], event)
    save_events()
end

-- enregistrez un événement lorsque le joueur casse ou place un bloc
minetest.register_on_dignode(function(pos, oldnode, digger)
    if digger then
        local node_name = oldnode.name
        log_event(pos, "break", digger:get_player_name(), node_name)
    end
end)

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    if placer then
        local node_name = newnode.name
        log_event(pos, "place", placer:get_player_name(), node_name)
    end
end)

--  enregistrez un événement lorsque le joueur utilise l'outil d'information sur le bloc pointé
minetest.register_craftitem("blockwatch:selected_block_info_tool", {
    description = "Outil d'information sur le bloc pointé",
    inventory_image = "blockwatch_selected_block_info_tool.png", -- Assurez-vous d'avoir une image valide
    on_use = function(itemstack, user, pointed_thing)
        if pointed_thing and pointed_thing.under then
            local player_name = user:get_player_name()
            local pos = pointed_thing.under

            -- Charger les données depuis la base de données
            local blockwatch_data = load_blockwatch_data()

            -- Vérifier si des données existent pour la position
            if blockwatch_data[player_name] and blockwatch_data[player_name][pos] then
                local block_data = blockwatch_data[player_name][pos]

                -- Envoyer les informations au joueur
                minetest.chat_send_player(player_name, "Données récupérées pour le bloc à " .. minetest.pos_to_string(pos) ..
                    ": " .. minetest.write_json(block_data))
            else
                minetest.chat_send_player(player_name, "Aucune donnée trouvée pour le bloc à " .. minetest.pos_to_string(pos))
            end

            -- Enregistrez les données mises à jour dans le fichier
            save_blockwatch_data(blockwatch_data)
        end
    end,
})

-- Fonction pour vérifier si la base de données des événements est chargée
local function check_events_database()
    if next(events) then
        minetest.chat_send_all("[Modname] La base de données des événements est chargée.")
    else
        minetest.chat_send_all("[Modname] La base de données des événements n'est pas chargée.")
    end
end

-- Commande pour recharger la base de données des événements
minetest.register_chatcommand("rdatab", {
    description = "Recharge la base de données des événements.",
    func = function(name, param)
        load_events_database()
        return true, "[Modname] Base de données des événements rechargée avec succès."
    end,
})

-- Commande pour vérifier si la base de données des événements est chargée
minetest.register_chatcommand("check_events_database", {
    description = "Vérifie si la base de données des événements est chargée.",
    func = function(name, param)
        check_events_database()
        return true, "[Modname] Vérification de la base de données des événements effectuée."
    end,
})

-- Appeler la fonction load_events_database lors du chargement des mods
minetest.register_on_mods_loaded(load_events_database)
