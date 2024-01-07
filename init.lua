local S = minetest.get_translator("BlockWatch") -- Récupérer le traducteur pour ce mod

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
        minetest.chat_send_all("Nombre d'event : " .. num_events)
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
            minetest.chat_send_all("La base de donnée a été sauvegarder et vider")

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
    privs = { basic_privs = true, blockwatch_perm = true },
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











-- fonction pour generer de faux entre pour test le mod 

-- random_pseudo_mod/init.lua

-- Fonction pour générer un pseudo aléatoire
local function generate_random_pseudo()
    local adjectives = {"Red", "Blue", "Green", "Happy", "Sad", "Fast", "Slow", "Big", "Small", "Tall", "Short", "neo", "super", "ultra", "mega", "giga", "hyper", "ultra", "uber", "omega", "alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa", "lambda", "mu", "nu", "xi", "omicron", "pi", "rho", "sigma", "tau", "upsilon", "phi", "chi", "psi", "omega"}
    local nouns = {"Cat", "Dog", "Bird", "Tree", "Mountain", "Ocean", "Star", "firite", "diamant", "ruby", "saphir", "emeraude", "topaze", "amethyste", "onyx", "perle", "agate", "citrine", "quartz", "tourmaline", "zircon", "jade", "lapis-lazuli", "malachite", "obsidienne", "opale", "ambre", "corail", "ivoire", "ambre", "manger", "boire", "dormir", "courir", "marcher", "sauter", "voler", "nager", "chanter", "danser", "jouer", "rire", "pleurer", "penser", "parler", "ecouter", "regarder", "sentir", "toucher", "gouter", "manger", "boire", "dormir", "courir", "marcher", "sauter", "voler", "nager", "chanter", "danser", "jouer", "rire", "pleurer", "penser", "parler", "ecouter", "regarder", "sentir", "toucher", "gouter"}

    local random_adjective = adjectives[math.random(1, #adjectives)]
    local random_noun = nouns[math.random(1, #nouns)]

    return random_adjective .. random_noun
end

-- Commande pour générer un pseudo aléatoire
minetest.register_chatcommand("randompseudo", {
    params = "",
    description = "Génère un pseudo aléatoire.",
    func = function(name, param)
        local random_pseudo = generate_random_pseudo()
        minetest.chat_send_player(name, "Votre pseudo aléatoire : " .. random_pseudo)
    end,
})

-- random_coordinates_mod/init.lua

-- Fonction pour générer des coordonnées aléatoires
local function generate_random_coordinates()
    local random_x = math.random(-100, 100)
    local random_y = math.random(1, 50)
    local random_z = math.random(-100, 100)

    return random_x, random_y, random_z
end

-- Commande pour générer des coordonnées aléatoires
minetest.register_chatcommand("randomcoords", {
    params = "",
    description = "Génère des coordonnées aléatoires.",
    func = function(name, param)
        -- Appeler la fonction pour générer les coordonnées
        local x, y, z = generate_random_coordinates()

        -- Envoyer les coordonnées au joueur
        minetest.chat_send_player(name, "Vos coordonnées aléatoires : X=" .. x .. " Y=" .. y .. " Z=" .. z)
    end,
})

-- random_block_mod/init.lua

-- Fonction pour obtenir un nom de bloc aléatoire
local function generate_random_block_name()
    local registered_nodes = minetest.registered_nodes
    local node_names = {}

    -- Collecter les noms de blocs disponibles
    for name, _ in pairs(registered_nodes) do
        table.insert(node_names, name)
    end

    -- Vérifier s'il y a des blocs disponibles
    if #node_names > 0 then
        -- Choisir un nom de bloc au hasard
        local random_block_name = node_names[math.random(1, #node_names)]
        return random_block_name
    else
        return "Aucun bloc disponible"
    end
end

-- Commande pour générer un nom de bloc aléatoire
minetest.register_chatcommand("randomblock", {
    params = "",
    description = "Génère un nom de bloc aléatoire.",
    func = function(name, param)
        -- Appeler la fonction pour générer le nom de bloc
        local random_block_name = generate_random_block_name()

        -- Envoyer le nom de bloc au joueur
        minetest.chat_send_player(name, "Votre bloc aléatoire : " .. random_block_name)
    end,
})

-- commande pour générer des log de bloc aléatoire puis les placer
minetest.register_chatcommand("randomblocklog", {
    params = "",
    description = "Génère un nom de bloc aléatoire.",
    func = function(name, param)
        -- Appeler la fonction pour générer le nom de bloc
        local random_block_name = generate_random_block_name()
        --speudo aleatoire
        local random_pseudo = generate_random_pseudo()
        --cordonner aleatoire
        local x, y, z = generate_random_coordinates()
        --pose le bloc au cordonner
        minetest.set_node({x=x, y=y, z=z}, {name=random_block_name})
        --ajoute au log 
        log_event({x=x, y=y, z=z}, "place", random_pseudo, random_block_name)

        -- Envoyer le nom de bloc au joueur
        minetest.chat_send_player(name, "Votre bloc aléatoire : " .. random_block_name .. " placer a la position : X=" .. x .. " Y=" .. y .. " Z=" .. z .. " par le joueur : " .. random_pseudo)
        minetest.set_node({x=0, y=0, z=0}, {name=random_block_name})
    end,
})

-- cree une fonction qui fait la meme chose que la commande /randomblocklog
local function randomblocklog()
    -- Appeler la fonction pour générer le nom de bloc
    local random_block_name = generate_random_block_name()
    --speudo aleatoire
    local random_pseudo = generate_random_pseudo()
    --cordonner aleatoire
    local x, y, z = generate_random_coordinates()
    --pose le bloc au cordonner
    minetest.set_node({x=x, y=y, z=z}, {name=random_block_name})
    --ajoute au log 
    log_event({x=x, y=y, z=z}, "place", random_pseudo, random_block_name)
    minetest.chat_send_all("Votre bloc aléatoire : " .. random_block_name .. " placer a la position : X=" .. x .. " Y=" .. y .. " Z=" .. z)
end


-- Commande pour placer un bloc aléatoire un certain nombre de fois
minetest.register_chatcommand("randomplacebatch", {
    params = "<nombre>",
    description = "Place un bloc aléatoire un certain nombre de fois.",
    func = function(name, params)
        -- Récupérer le nombre de fois spécifié en paramètre
        local count = tonumber(params)

        -- Vérifier si le nombre est valide
        if not count or count <= 0 then
            minetest.chat_send_player(name, "Utilisation incorrecte. Utilisez /randomplacebatch <nombre>")
            --nom de block restant
            minetest.chat_send_player(name, "Il reste " .. #node_names .. " blocs disponible")
            return
        end

        -- Exécuter la fonction randomblocklog le nombre de fois spécifié
        for i = 1, count do
            randomblocklog()
        end

        -- Envoyer un message au joueur
        minetest.chat_send_player(name, "Blocs placés avec succès.")
    end,
})


-- fonction pour lire les fichier de log de backup et crée une base de donnée par fichier de log
local function load_backup_database()
    --chemin vers le dossier blockwatch_data_backup
    local blockwatch_data_backup_path = minetest.get_worldpath() .. "/blockwatch_data_backup"
    --verifie que le dossier blockwatch_data_backup existe
    if not minetest.mkdir(blockwatch_data_backup_path) then
        minetest.log("error", S("[blockwatch] Error creating the blockwatch_data_backup directory."))
    end
    --liste les fichier dans le dossier blockwatch_data_backup
    local blockwatch_data_backup_list = minetest.get_dir_list(blockwatch_data_backup_path, false)
    --verifie que la liste n'est pas vide
    if not blockwatch_data_backup_list then
        minetest.log("error", S("[blockwatch] Error listing the blockwatch_data_backup directory."))
    end
    --boucle pour lire les fichier de log de backup
    for _, blockwatch_data_backup_file in ipairs(blockwatch_data_backup_list) do
        --chemin vers le fichier de log de backup
        local blockwatch_data_backup_file_path = blockwatch_data_backup_path .. "/" .. blockwatch_data_backup_file
        --charge le fichier de log de backup
        local blockwatch_data_backup_file_data = minetest.deserialize(io.open(blockwatch_data_backup_file_path, "r"):read("*all"))
        --verifie que le fichier de log de backup est bien charger
        if not blockwatch_data_backup_file_data then
            minetest.log("error", S("[blockwatch] Error loading the blockwatch_data_backup file."))
        end
        --boucle pour lire les entrer du fichier de log de backup
        for key, event_list in pairs(blockwatch_data_backup_file_data) do
            --verifie que la base de donnée n'est pas vide
            if not events[key] then
                events[key] = {}
            end
            --boucle pour lire les entrer du fichier de log de backup
            for _, event in ipairs(event_list) do
                --ajoute les entrer du fichier de log de backup a la base de donnée
                table.insert(events[key], event)
            end
        end
    end
    --sauvegarde la base de donnée
    save_events()
    --envoie un message dans le chat pour dire que la base de donnée a été charger
    minetest.chat_send_all("La base de donnée a été charger")
end
-- ajoute le meme item que blockwatch:block_data_checker mais avec un autre nom et regarde uniquement dans la base de donnée des backup

-- Enregistrement de l'item avec le préfixe "blockwatch:"
minetest.register_craftitem("blockwatch:block_data_checker_backup", {
    description = S("Block Data Checker Backup"),
    inventory_image = "blockwatch.png",  
    on_use = check_block_data_item_backup,
})



