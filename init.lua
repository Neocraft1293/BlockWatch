local S = minetest.get_translator("BlockWatch") -- Récupérer le traducteur pour ce mod

-- Chemin vers le fichier JSON pour les événements
local events_json_file_path = minetest.get_worldpath() .. "/blockwatch_data.json"

-- Initialiser la variable events en dehors de load_database
local events = {}
local events_backup = {}


-- Fonction pour charger la base de données des événements
local function load_events_database()
    local json_file = io.open(events_json_file_path, "r")
    if json_file then
        events = minetest.deserialize(json_file:read("*all"))
        json_file:close()
        minetest.log("action", S("[blockwatch] Event database loaded successfully."))
    else
        -- Créer le fichier JSON s'il n'existe pas
        local new_json_file = io.open(events_json_file_path, "w")
        new_json_file:write(minetest.serialize(events))
        new_json_file:close()
        minetest.log("action", S("[blockwatch] New event database created."))
    end
end

-- Fonction pour sauvegarder les événements dans le fichier JSON
local function save_events()
    local json_file = io.open(events_json_file_path, "w")
    if json_file then
        json_file:write(minetest.serialize(events))
        json_file:close()
    end
    --envoie la taille de la base de donnée dans le chat et utilise la meme logique que la commande /events_stats
    
end

-- Charge les données depuis le fichier JSON
local function load_blockwatch_data()
    minetest.log("action", S("[blockwatch] Loading data from JSON file: ") .. events_json_file_path)
    local file = io.open(events_json_file_path, "r")

    if not file then
        minetest.log("action", S("[blockwatch] The JSON file does not exist."))
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

-- Créez d'abord la fonction events_stats
local function events_stats()
    local num_events = 0
    local total_size = 0

    for key, event_list in pairs(events) do
        num_events = num_events + #event_list

        local json_data = minetest.write_json(event_list)
        if json_data then
            total_size = total_size + #json_data
        else
            minetest.log("error", S("[blockwatch] Error during JSON serialization for events."))
        end
    end

    local average_size_per_entry = num_events > 0 and total_size / num_events or 0
    -- Retourne les statistiques sous forme de variables
    return num_events, total_size, average_size_per_entry
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
        -- apelle la fonction pour avoir les le nombre d'event
        local num_events, total_size, average_size_per_entry = events_stats()
        -- envoie le nombre d'event dans le chat
        --minetest.chat_send_all("Nombre d'event : " .. num_events)
        -- si le nombre d'event est superieur a 1000 alors créer une sauvegarde de la base de donnée actuelle et vide la base de donnée
        if num_events > 10000 then
            -- sauvegarde la base de donnée actuelle dans un fichier json dans le dossier world dans un docier nommé blockwatch_data_backup dans un fichier nommé blockwatch_data_backup(numero de la backup).json
            -- verrifie que le dossier blockwatch_data_backup existe
            if not minetest.mkdir(minetest.get_worldpath() .. "/blockwatch_data_backup") then
                minetest.log("error", S("[blockwatch] Error creating the blockwatch_data_backup directory."))
            end
            -- utilise la date et l'heure pour nommer le fichier json
            local json_file = io.open(minetest.get_worldpath() .. "/blockwatch_data_backup/blockwatch_data_backup" .. os.date("%Y-%m-%dT%H:%M:%S") .. ".json", "w")
            if json_file then
                json_file:write(minetest.serialize(events))
                json_file:close()
            end
            -- vide la base de donnée
            events = {}
            save_events()
            -- envoie un message dans le chat pour dire que la base de donnée a été sauvegarder et vider
            --minetest.chat_send_all("La base de donnée a été sauvegarder et vider")

        end
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
    -- envoie le node_name dans le chat
    --minetest.chat_send_all("Le node_name est : " .. node_name .. "")

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
        minetest.chat_send_all(S("[blockwatch] The events database is loaded."))
    else
        minetest.chat_send_all(S("[blockwatch] The events database is not loaded."))
    end
end

-- Définir une permission personnalisée
minetest.register_privilege("blockwatch_perm", {
    description = S("Allows access to Blockwatch commands."),
    give_to_singleplayer = false,  -- Permettre à un joueur unique de posséder cette permission
})

-- Commande pour recharger la base de données des événements
minetest.register_chatcommand("reload_database_blockwatch", {
    privs = {blockwatch_perm=true},
    description = S("Reloads the events database."),
    func = function(name, param)
        load_events_database()
        return true, S("[blockwatch] Events database reloaded successfully.")
    end,
})

-- Commande pour vérifier si la base de données des événements est chargée
minetest.register_chatcommand("check_events_database_blockwatch", {
    privs = {blockwatch_perm=true},
    description = S("Check if the events database is loaded."),
    func = function(name, param)
        check_events_database()
        return true, S("[blockwatch] Events database verification complete.")
    end,
})

-- Appeler la fonction load_events_database lors du chargement des mods
minetest.register_on_mods_loaded(load_events_database)

-- Commande pour vérifier les données d'un bloc
minetest.register_chatcommand("check_block_data_blockwatch", {
    privs = {blockwatch_perm=true},
    description = S("Check data for a specific block."),
    params = "<x> <y> <z>",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)

        if not player then
            return false, "Le joueur n'est pas trouvé."
        end

        local x, y, z = param:match("(%S+)%s+(%S+)%s+(%S+)")
        if not x or not y or not z then
            return false, S("Please specify the coordinates of the block (e.g., /check_block_data 10 20 30).")
        end

        x, y, z = tonumber(x), tonumber(y), tonumber(z)

        if not x or not y or not z then
            return false, S("The coordinates of the block are not valid.")
        end

        local pos = {x = x, y = y, z = z}
        local key = minetest.pos_to_string(pos)

        local blockwatch_data = load_blockwatch_data()

        if not next(blockwatch_data) then
            return false, S("The database is empty.")
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

            minetest.chat_send_player(name, S("Block data at ") .. minetest.pos_to_string(pos) .. " : \n" .. formatted_data)
            minetest.log("action", "[blockwatch] " .. S("Block data at ") .. minetest.pos_to_string(pos) .. " : \n" .. json_data)

        else
            minetest.chat_send_player(name, S("No data found for the block at ") .. minetest.pos_to_string(pos))
        end

        return true, S("Block data verification successful.")
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
        minetest.chat_send_player(user:get_player_name(), S("The database is empty."))
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

        minetest.chat_send_player(user:get_player_name(), S("Block data at ") .. minetest.pos_to_string(pos) .. " : \n" .. formatted_data)
    else
        minetest.chat_send_player(user:get_player_name(), S("No data found for the block at ") .. minetest.pos_to_string(pos))
    end
end

-- Enregistrement de l'item avec le préfixe "blockwatch:"
minetest.register_craftitem("blockwatch:block_data_checker", {
    description = S("Block Data Checker"),
    inventory_image = "blockwatch.png",  
    on_use = check_block_data_item,
})




-- Enregistrez ensuite la commande pour obtenir des statistiques sur la base de données des événements
minetest.register_chatcommand("events_stats", {
    privs = {blockwatch_perm=true},
    description = S("Event Database Statistics"),
    func = function(name, param)
        -- Utilisez la fonction events_stats pour obtenir les statistiques
        local num_events, total_size, average_size_per_entry = events_stats()

        -- Affiche les statistiques dans le chat du joueur
        minetest.chat_send_player(name, S("Total number of events: ") .. num_events)
        minetest.chat_send_player(name, S("Total size of the database: ") .. total_size)
        minetest.chat_send_player(name, S("Average size per entry: ") .. average_size_per_entry)

        return true, S("[blockwatch] Event statistics sent to player ") .. name .. "."
    end,
})


-- ce que renvoie la fonction events_stats comme variable
-- events_stats = {num_events = num_events, total_size = total_size, average_size_per_entry = average_size_per_entry}
--comment utiliser les variable de la fonction events_stats
--local events_stats = events_stats()
--minetest.chat_send_player(name, S("Total number of events: ") .. events_stats.num_events)


-- surveille les joueurs qui ouvre les coffres
minetest.register_on_player_receive_fields(function(player, formname, fields)
    -- vérifie que le joueur a ouvert un coffre
    --minetest.chat_send_all("Le joueur " .. player:get_player_name() .. " a ouvert un coffre l'uid du coffre est : " .. formname .. "")

-- Si le nom du formulaire commence par "mcl_core:chest"
if formname:find("^mcl_chests:chest") then
    -- Extraire les coordonnées du nom du formulaire
    local x, y, z = formname:match("^mcl_chests:chest_(%-?%d+)_([%d-]+)_([%d-]+)")

    if x and y and z then
        -- Convertir les coordonnées en nombres
        x, y, z = tonumber(x), tonumber(y), tonumber(z)

        -- Vérifie si le joueur a quitté le formulaire
        if fields.quit then
            -- Envoie un message global indiquant que le joueur a ouvert un coffre
            --minetest.chat_send_all("Le joueur " .. player:get_player_name() .. " a ouvert un coffre aux coordonnées : (" .. x .. ", " .. y .. ", " .. z .. ")")
            -- Ajoute un événement à la base de données
            log_event({x = x, y = y, z = z}, "interact", player:get_player_name(), "mcl_chests:chest")
        end
    end
end

    -- vérifie que le joueur a ouvert un coffre (protector:chest)
    if formname:find("^protector:chest_") then
        --minetest.chat_send_all("Le joueur " .. player:get_player_name() .. " a ouvert un coffre l'uid du coffre est : " .. formname .. "")
        -- Extraire les coordonnées du nom du formulaire c'est separer par des , comme ca : protector:chest_(-1,0,0)
        local x, y, z = formname:match("^protector:chest_%((-?%d+),(-?%d+),(-?%d+)%)")

        if x and y and z then
            -- Convertir les coordonnées en nombres
            x, y, z = tonumber(x), tonumber(y), tonumber(z)
            --minetest.chat_send_all("Le joueur " .. player:get_player_name() .. " a ouvert un coffre aux coordonnées : (" .. x .. ", " .. y .. ", " .. z .. ")")
            -- Ajoute un événement à la base de données
            log_event({x = x, y = y, z = z}, "interact", player:get_player_name(), "protector:chest")
        end
    end

    if formname == "default:chest" then
        -- vérifie que le joueur a ouvert un coffre
        if fields.quit then
            -- envoie un message dans le chat pour dire que le joueur a ouvert un coffre
            --minetest.chat_send_all("Le joueur " .. player:get_player_name() .. " a ouvert un coffre")
            -- ajoute un event dans la base de donnée
            log_event(player:get_pos(), "open", player:get_player_name(), "default:chest")
        end
    end
end)











































--chrger les base de donnée de backup
local function load_backup_database()
    -- chemin vers le dossier blockwatch_data_backup
    local blockwatch_data_backup_path = minetest.get_worldpath() .. "/blockwatch_data_backup"
    -- vérifie que le dossier blockwatch_data_backup existe
    if not minetest.mkdir(blockwatch_data_backup_path) then
        minetest.log("error", S("[blockwatch] Error creating the blockwatch_data_backup directory."))
    end
    -- liste les fichiers dans le dossier blockwatch_data_backup
    local blockwatch_data_backup_list = minetest.get_dir_list(blockwatch_data_backup_path, false)
    -- vérifie que la liste n'est pas vide
    if not blockwatch_data_backup_list then
        minetest.log("error", S("[blockwatch] Error listing the blockwatch_data_backup directory."))
    end
    -- boucle pour lire les fichiers de log de backup
    for _, blockwatch_data_backup_file in ipairs(blockwatch_data_backup_list) do
        -- chemin vers le fichier de log de backup
        local blockwatch_data_backup_file_path = blockwatch_data_backup_path .. "/" .. blockwatch_data_backup_file
        -- charge le fichier de log de backup
        local blockwatch_data_backup_file_data = minetest.deserialize(io.open(blockwatch_data_backup_file_path, "r"):read("*all"))
        -- vérifie que le fichier de log de backup est bien chargé
        if not blockwatch_data_backup_file_data then
            minetest.log("error", S("[blockwatch] Error loading the blockwatch_data_backup file."))
        end
        -- boucle pour lire les entrées du fichier de log de backup
        for key, event_list in pairs(blockwatch_data_backup_file_data) do
            -- vérifie que la base de données n'est pas vide
            if not events_backup[key] then
                events_backup[key] = {}
            end
            -- boucle pour lire les entrées du fichier de log de backup
            for _, event in ipairs(event_list) do
                -- ajoute les entrées du fichier de log de backup à la base de données
                table.insert(events_backup[key], event)
            end
        end
    end
    -- envoie un message dans le chat pour dire que la base de données a été chargée
    minetest.chat_send_all("La base de données a été chargée")
end

-- enregistrer la permission pour la base de donnée de backup
minetest.register_privilege("blockwatch_perm_backup", {
    description = S("Allows access to Blockwatch commands for backup database."),
    give_to_singleplayer = false,  -- Permettre à un joueur unique de posséder cette permission
})




-- Commande pour charger les bases de données des backups
minetest.register_chatcommand("load_backup_database", {
    params = "",
    description = "Charge les bases de données des backups.",
    privs = {blockwatch_perm_backup=true},
    func = function(name, param)
        -- appelle la fonction pour charger les bases de données des backups
        load_backup_database()
        -- envoie un message dans le chat pour dire que la base de données a été chargée
        minetest.chat_send_all("La base de données a été chargée")
    end,
})



-- Commande pour donner le nombre d'events dans les bases de données de backup
minetest.register_chatcommand("events_stats_backup", {
    params = "",
    perm = "blockwatch_perm_backup",
    description = "Donne le nombre d'events dans les bases de données de backup.",
    privs = {blockwatch_perm_backup=true},
    func = function(name, param)
        -- initialise les variables
        local num_events = 0
        local total_size = 0
        local average_size_per_entry = 0
        -- boucle pour lire les bases de données de backup
        for _, event_list in pairs(events_backup) do
            -- ajoute le nombre d'events dans la variable num_events
            num_events = num_events + #event_list
            -- boucle pour lire les entrées des bases de données de backup
            for _, event in ipairs(event_list) do
                -- ajoute la taille de l'entrée dans la variable total_size
                total_size = total_size + #event
            end
        end
        -- calcule la taille moyenne des entrées
        average_size_per_entry = num_events > 0 and total_size / num_events or 0
        -- envoie le nombre d'events dans le chat
        minetest.chat_send_all("Nombre d'events : " .. num_events)
        -- envoie la taille totale des entrées dans le chat
        minetest.chat_send_all("Taille totale des entrées : " .. total_size)
        -- envoie la taille moyenne des entrées dans le chat
        minetest.chat_send_all("Taille moyenne des entrées : " .. average_size_per_entry)
    end,
})

-- Commande pour vérifier un block dans les bases de données de backup
minetest.register_chatcommand("check_block_data_blockwatch_backup", {
    privs = {blockwatch_perm_backup=true},
    description = S("Check data for a specific block."),
    params = "<x> <y> <z>",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)

        if not player then
            return false, "Le joueur n'est pas trouvé."
        end

        local x, y, z = param:match("(%S+)%s+(%S+)%s+(%S+)")
        if not x or not y or not z then
            return false, S("Please specify the coordinates of the block (e.g., /check_block_data 10 20 30).")
        end

        x, y, z = tonumber(x), tonumber(y), tonumber(z)

        if not x or not y or not z then
            return false, S("The coordinates of the block are not valid.")
        end

        local pos = {x = x, y = y, z = z}
        local key = minetest.pos_to_string(pos)

        local blockwatch_data_backup = events_backup
        
        -- vérifie que la base de données n'est pas vide

        if not next(blockwatch_data_backup) then
            return false, S("The database is empty.")
        end
        -- recherche les entrées du block dans les bases de données de backup
        if blockwatch_data_backup[key] and #blockwatch_data_backup[key] > 0 then
            local json_data = minetest.write_json(blockwatch_data_backup[key])

            -- Formater les données pour les rendre plus lisibles
            local formatted_data = ""
            for _, event in ipairs(blockwatch_data_backup[key]) do
                formatted_data = formatted_data .. "entity: " .. event.entity .. "\n"
                formatted_data = formatted_data .. "event_type: " .. event.event_type .. "\n"
                formatted_data = formatted_data .. "node_name: " .. event.node_name .. "\n"
                formatted_data = formatted_data .. "timestamp: " .. event.timestamp .. "\n\n"
            end

            minetest.chat_send_player(name, S("Block data at ") .. minetest.pos_to_string(pos) .. " : \n" .. formatted_data)
            minetest.log("action", "[blockwatch] " .. S("Block data at ") .. minetest.pos_to_string(pos) .. " : \n" .. json_data)

        else
            minetest.chat_send_player(name, S("No data found for the block at ") .. minetest.pos_to_string(pos))
        end
    end,
})

-- crée un item qui permet de vérifier les données d'un bloc dans les bases de données de backup
local function check_block_data_item_backup(itemstack, user, pointed_thing)
    if not user or not pointed_thing or not pointed_thing.under then
        return
    end

    local pos = pointed_thing.under
    local key = minetest.pos_to_string(pos)
    
    local blockwatch_data_backup = events_backup

    if not next(blockwatch_data_backup) then
        minetest.chat_send_player(user:get_player_name(), S("The database is empty."))
        return
    end

    if blockwatch_data_backup[key] and #blockwatch_data_backup[key] > 0 then
        local formatted_data = ""
        for _, event in ipairs(blockwatch_data_backup[key]) do
            formatted_data = formatted_data .. "entity: " .. event.entity .. "\n"
            formatted_data = formatted_data .. "event_type: " .. event.event_type .. "\n"
            formatted_data = formatted_data .. "node_name: " .. event.node_name .. "\n"
            formatted_data = formatted_data .. "timestamp: " .. event.timestamp .. "\n\n"
        end

        minetest.chat_send_player(user:get_player_name(), S("Block data at ") .. minetest.pos_to_string(pos) .. " : \n" .. formatted_data)
    else
        minetest.chat_send_player(user:get_player_name(), S("No data found for the block at ") .. minetest.pos_to_string(pos))
    end
end

-- Enregistrement de l'item avec le préfixe "blockwatch:"
minetest.register_craftitem("blockwatch:block_data_checker_backup", {
    description = S("Block Data Checker Backup"),
    inventory_image = "blockwatch_backup.png",  
    on_use = check_block_data_item_backup,
})


