-- Chemin vers le fichier JSON pour les événements
local events_json_file_path = minetest.get_worldpath() .. "/blockwatch_data.json"

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

-- Charge les données depuis le fichier JSON
local function load_blockwatch_data()
    minetest.log("action", "[Modname] Chargement des données depuis le fichier JSON : " .. events_json_file_path)
    local file = io.open(events_json_file_path, "r")

    if not file then
        minetest.log("action", "[Modname] Le fichier JSON n'existe pas.")
        return {}
    end

    local data = minetest.deserialize(file:read("*a"))
    io.close(file)
    return data or {}
end

-- Fonction pour sauvegarder les données sur le bloc pointé dans le fichier JSON
local function save_blockwatch_data(data)
    local json_file = io.open(events_json_file_path, "w")
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

--  enregistrez un événement lorsque le joueur casse ou place un bloc
minetest.register_on_dignode(function(pos, oldnode, digger)
    local node_name = oldnode.name

    local entity = minetest.get_node_or_nil(pos) -- Récupérer le nœud à la position actuelle

    -- Vérifier si un joueur est impliqué
    if digger and digger:is_player() then
        log_event(pos, "break", digger:get_player_name(), node_name)
    elseif entity then
        -- Vérifier si c'est une entité autre qu'un joueur
        local entity_type = entity.type
        if entity_type and entity_type ~= "player" then
            log_event(pos, "break", "Entity:" .. entity_type, node_name)
        else
            log_event(pos, "break", "Unknown", node_name)
        end
    else
        log_event(pos, "break", "Unknown", node_name)
    end
end)

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    local node_name = newnode.name

    local entity = minetest.get_node_or_nil(pos) -- Récupérer le nœud à la position actuelle

    -- Vérifier si un joueur est impliqué
    if placer and placer:is_player() then
        log_event(pos, "place", placer:get_player_name(), node_name)
    elseif entity then
        -- Vérifier si c'est une entité autre qu'un joueur
        local entity_type = entity.type
        if entity_type and entity_type ~= "player" then
            log_event(pos, "place", "Entity:" .. entity_type, node_name)
        else
            log_event(pos, "place", "Unknown", node_name)
        end
    else
        log_event(pos, "place", "Unknown", node_name)
    end
end)




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

-- Commande pour vérifier les données d'un bloc
minetest.register_chatcommand("check_block_data", {
    description = "Vérifie les données d'un bloc spécifique.",
    params = "<x> <y> <z>",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)

        if not player then
            return false, "Le joueur n'est pas trouvé."
        end

        local x, y, z = param:match("(%S+)%s+(%S+)%s+(%S+)")
        if not x or not y or not z then
            return false, "Veuillez spécifier les coordonnées du bloc (ex. /check_block_data 10 20 30)."
        end

        x, y, z = tonumber(x), tonumber(y), tonumber(z)

        if not x or not y or not z then
            return false, "Les coordonnées du bloc ne sont pas valides."
        end

        local pos = {x = x, y = y, z = z}
        local key = minetest.pos_to_string(pos)

        local blockwatch_data = load_blockwatch_data()

        if not next(blockwatch_data) then
            return false, "La base de données est vide."
        end

        if blockwatch_data[key] and #blockwatch_data[key] > 0 then
            local json_data = minetest.write_json(blockwatch_data[key])

            -- Formater les données pour les rendre plus lisibles
            local formatted_data = ""
            for _, event in ipairs(blockwatch_data[key]) do
                formatted_data = formatted_data .. "entity: " .. event.entity .. "\n"
                formatted_data = formatted_data .. "event_type: " .. event.event_type .. "\n"
                formatted_data = formatted_data .. "node_name: " .. event.node_name .. "\n"
                formatted_data = formatted_data .. "timestamp: " .. event.timestamp .. "\n\n"
            end

            minetest.chat_send_player(name, "Données du bloc à " .. minetest.pos_to_string(pos) .. " : \n" .. formatted_data)
            minetest.log("action", "[Modname] Données du bloc à " .. minetest.pos_to_string(pos) .. " : \n" .. json_data)
        else
            minetest.chat_send_player(name, "Aucune donnée trouvée pour le bloc à " .. minetest.pos_to_string(pos))
        end

        return true, "Vérification des données du bloc effectuée."
    end,
})


-- Fonction pour vérifier les données d'un bloc
local function check_block_data_item(itemstack, user, pointed_thing)
    if not user or not pointed_thing or not pointed_thing.under then
        return
    end

    local pos = pointed_thing.under
    local key = minetest.pos_to_string(pos)
    
    local blockwatch_data = load_blockwatch_data()

    if not next(blockwatch_data) then
        minetest.chat_send_player(user:get_player_name(), "La base de données est vide.")
        return
    end

    if blockwatch_data[key] and #blockwatch_data[key] > 0 then
        local formatted_data = ""
        for _, event in ipairs(blockwatch_data[key]) do
            formatted_data = formatted_data .. "entity: " .. event.entity .. "\n"
            formatted_data = formatted_data .. "event_type: " .. event.event_type .. "\n"
            formatted_data = formatted_data .. "node_name: " .. event.node_name .. "\n"
            formatted_data = formatted_data .. "timestamp: " .. event.timestamp .. "\n\n"
        end

        minetest.chat_send_player(user:get_player_name(), "Données du bloc à " .. minetest.pos_to_string(pos) .. " : \n" .. formatted_data)
    else
        minetest.chat_send_player(user:get_player_name(), "Aucune donnée trouvée pour le bloc à " .. minetest.pos_to_string(pos))
    end
end

-- Enregistrement de l'item avec le préfixe "blockwatch:"
minetest.register_craftitem("blockwatch:block_data_checker", {
    description = "Vérificateur de données de bloc",
    inventory_image = "blockwatch.png",  
    on_use = check_block_data_item,
})

