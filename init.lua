blockwatch = {}

local S = minetest.get_translator("BlockWatch") -- Récupérer le traducteur pour ce mod

-- Chemin vers le fichier JSON pour les événements
local events_json_file_path = minetest.get_worldpath() .. "/blockwatch_data.json"

-- Initialiser la variable events en dehors de load_database
local events = {}
local events_backup = {}

-- Fonction pour charger la base de données des événements
function blockwatch.load_events_database()
    local json_file = io.open(events_json_file_path, "r")
    if json_file then
        events = minetest.deserialize(json_file:read("*all"))
        json_file:close()
        minetest.log("action", S("[blockwatch] Base de données d'événements chargée avec succès."))
    else
        -- Créer le fichier JSON s'il n'existe pas
        local new_json_file = io.open(events_json_file_path, "w")
        new_json_file:write(minetest.serialize(events))
        new_json_file:close()
        minetest.log("action", S("[blockwatch] Nouvelle base de données d'événements créée."))
    end
end

-- Fonction pour sauvegarder les événements dans le fichier JSON
function blockwatch.save_events()
    local json_file = io.open(events_json_file_path, "w")
    if json_file then
        json_file:write(minetest.serialize(events))
        json_file:close()
    end
end

-- Charge les données depuis le fichier JSON
function blockwatch.load_blockwatch_data()
    minetest.log("action", S("[blockwatch] Chargement des données depuis le fichier JSON : ") .. events_json_file_path)
    local file = io.open(events_json_file_path, "r")

    if not file then
        minetest.log("action", S("[blockwatch] Le fichier JSON n'existe pas."))
        return {}
    end

    local data = minetest.deserialize(file:read("*a"))
    io.close(file)
    return data or {}
end

-- Fonction pour sauvegarder les données sur le bloc pointé dans le fichier JSON
function blockwatch.save_blockwatch_data(data)
    local json_file = io.open(events_json_file_path, "w")
    if json_file then
        json_file:write(minetest.serialize(data))
        json_file:close() 
    end
end

-- Créez d'abord la fonction events_stats
function blockwatch.events_stats()
    local num_events = 0
    local total_size = 0

    for key, event_list in pairs(events) do
        num_events = num_events + #event_list

        local json_data = minetest.write_json(event_list)
        if json_data then
            total_size = total_size + #json_data
        else
            minetest.log("error", S("[blockwatch] Erreur pendant la sérialisation JSON des événements."))
        end
    end

    local average_size_per_entry = num_events > 0 and total_size / num_events or 0
    -- Retourne les statistiques sous forme de variables
    return num_events, total_size, average_size_per_entry
end

-- Fonction pour nettoyer les anciennes sauvegardes
function blockwatch.clean_old_backups(max_backups)
    local backup_dir = minetest.get_worldpath() .. "/blockwatch_data_backup"
    local backups = {}

    -- Récupère la liste des fichiers de sauvegarde
    local dir_list = minetest.get_dir_list(backup_dir) or {}
    for _, file in ipairs(dir_list) do
        table.insert(backups, file)
    end

    -- Trie les fichiers par date (les plus anciens d'abord)
    table.sort(backups)

    -- Supprime les fichiers excédant le nombre maximal autorisé
    while #backups > max_backups do
        local file_to_remove = backups[1]
        local file_path = backup_dir .. "/" .. file_to_remove

        -- Supprime le fichier
        os.remove(file_path)

        -- Supprime le fichier de la liste des sauvegardes
        table.remove(backups, 1)
        -- compte le nombre de fichier dans le dossier blockwatch_data_backup
        local dir_list = minetest.get_dir_list(backup_dir) or {}
        -- envoie le nombre de fichier dans le chat
        --minetest.chat_send_all("Nombre de fichiers dans le dossier blockwatch_data_backup : " .. #dir_list .. "")
    end
end

-- Fonction pour enregistrer un nouvel événement
function blockwatch.log_event(pos, event_type, entity, node_name)
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
    blockwatch.save_events()
    
    -- appelle la fonction pour obtenir le nombre d'événements
    local num_events, total_size, average_size_per_entry = blockwatch.events_stats()
    
    -- envoie le nombre d'événements dans le chat
    --minetest.chat_send_all("Nombre d'événements : " .. num_events)
    
    -- si le nombre d'événements est supérieur à 10000 alors créer une sauvegarde de la base de données actuelle et vide la base de données
    if num_events > 10000 then
        -- sauvegarde la base de données actuelle dans un fichier JSON dans le dossier world dans un dossier nommé blockwatch_data_backup dans un fichier nommé blockwatch_data_backup(numero de la backup).json
        -- vérifie que le dossier blockwatch_data_backup existe
        if not minetest.mkdir(minetest.get_worldpath() .. "/blockwatch_data_backup") then
            minetest.log("error", S("[blockwatch] Erreur lors de la création du répertoire blockwatch_data_backup."))
        end
        -- utilise la date et l'heure pour nommer le fichier JSON
        local json_file = io.open(minetest.get_worldpath() .. "/blockwatch_data_backup/blockwatch_data_backup" .. os.date("%Y-%m-%dT%H:%M:%S") .. ".json", "w")
        if json_file then
            json_file:write(minetest.serialize(events))
            json_file:close()
        end
        blockwatch.clean_old_backups(100)
        -- vide la base de données
        events = {}
        blockwatch.save_events()
        -- envoie un message dans le chat pour dire que la base de données a été sauvegardée et vidée
        --minetest.chat_send_all("La base de données a été sauvegardée et vidée")
    end
end


minetest.register_craftitem("blockwatch:block_data_checker", {
    description = "Block Data Checker",
    inventory_image = "blockwatch.png", -- Assurez-vous de remplacer "blockwatch_block_data_checker.png" par le chemin correct de votre image d'inventaire
    on_use = function(itemstack, user, pointed_thing)
        if pointed_thing.type == "node" then
            local pos = minetest.get_pointed_thing_position(pointed_thing, false)
            local key = minetest.pos_to_string(pos)
            
            -- Vérifie si des événements sont enregistrés pour cette position
            if events[key] then
                minetest.chat_send_player(user:get_player_name(), "Événements enregistrés pour la position " .. key .. ":")
                for _, event in ipairs(events[key]) do
                    local event_msg = string.format("[%s] %s %s - Node: %s",
                        event.timestamp, event.event_type, event.entity or "Unknown", event.node_name)
                    minetest.chat_send_player(user:get_player_name(), event_msg)
                end
            else
                minetest.chat_send_player(user:get_player_name(), "Aucun événement enregistré pour la position " .. key)
            end
        end
    end,
})


minetest.register_on_dignode(function(pos, oldnode, digger)
    local node_name = oldnode.name
    local entity = minetest.get_node_or_nil(pos)

    if digger and digger:is_player() then
        blockwatch.log_event(pos, "break", digger:get_player_name(), node_name)
    elseif entity then
        local entity_type = entity.type
        if entity_type and entity_type ~= "player" then
            blockwatch.log_event(pos, "break", "Entity:" .. entity_type, node_name)
        else
            blockwatch.log_event(pos, "break", "Unknown", node_name)
        end
    else
        blockwatch.log_event(pos, "break", "Unknown", node_name)
    end
end)


minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    local node_name = newnode.name
    local entity = minetest.get_node_or_nil(pos)

    if placer and placer:is_player() then
        blockwatch.log_event(pos, "place", placer:get_player_name(), node_name)
    elseif entity then
        local entity_type = entity.type
        if entity_type and entity_type ~= "player" then
            blockwatch.log_event(pos, "place", "Entity:" .. entity_type, node_name)
        else
            blockwatch.log_event(pos, "place", "Unknown", node_name)
        end
    else
        blockwatch.log_event(pos, "place", "Unknown", node_name)
    end
end)

-- Définir une permission personnalisée
minetest.register_privilege("blockwatch_perm", {
    description = S("Allows access to Blockwatch commands."),
    give_to_singleplayer = false,  -- Permettre à un joueur unique de posséder cette permission
})


minetest.register_chatcommand("events_stats", {
    privs = {blockwatch_perm=true},
    description = S("Event Database Statistics"),
    func = function(name, param)
        -- Utilisez la fonction events_stats pour obtenir les statistiques
        local num_events, total_size, average_size_per_entry = blockwatch.events_stats()

        -- Affiche les statistiques dans le chat du joueur
        minetest.chat_send_player(name, S("Total number of events: ") .. num_events)
        minetest.chat_send_player(name, S("Total size of the database: ") .. total_size)
        minetest.chat_send_player(name, S("Average size per entry: ") .. average_size_per_entry)

        return true, S("[blockwatch] Event statistics sent to player ") .. name .. "."
    end,
})


-- Fonction pour recharger la base de données des événements
function blockwatch.reload_events_database()
    events = {}
    blockwatch.load_events_database()
    minetest.chat_send_all("[blockwatch] Base de données d'événements rechargée.")
end

-- Commande pour recharger la base de données des événements
minetest.register_chatcommand("reload_events", {
    privs = {blockwatch_perm=true},
    description = S("Reload the events database"),
    func = function(name, param)
        blockwatch.reload_events_database()
        return true, S("[blockwatch] Events database reloaded.")
    end,
})

-- Enregistrez la fonction de chargement de la base de données au démarrage
minetest.register_on_mods_loaded(function()
    blockwatch.load_events_database()
end)


-- commande pour rechercher les event en fonction des filtre choisi
-- /search_events <pos> <event_type> <entity> <node_name>
-- l'utilisateur peut se servir de "all" pour ne pas utiliser un filtre 
-- exemple : /search_events all all all all
--ou 
-- /search_events 0,0,0 all all all qui affichera tout les event a la position 0,0,0
--ou 
-- /search_events all place all all qui affichera tout les event de type place
--ou
-- /search_events all all all default:stone qui affichera tout les event avec le nom de bloc default:stone
--ou
-- /search_events all all neo all qui affichera tout les event avec le pseudo neo
--ou
-- /search_events 0,0,0 place neo default:stone qui affichera tout les event a la position 0,0,0 de type place avec le pseudo neo et le nom de bloc default:stone

minetest.register_chatcommand("search_events", {
    privs = {blockwatch_perm=true},
    description = S("Rechercher des événements basés sur des filtres"),
    params = "<pos> <event_type> <entity> <node_name>",
    func = function(name, param)
        -- Diviser les paramètres en utilisant l'espace comme séparateur
        local params = param:split(" ")
        
        -- Initialiser les filtres avec des valeurs par défaut
        local pos_filter = params[1] or "all"
        local event_type_filter = params[2] or "all"
        local entity_filter = params[3] or "all"
        local node_name_filter = params[4] or "all"

        -- Boucle pour filtrer les événements en fonction des critères
        local matching_events = {}
        for key, event_list in pairs(events) do
            for _, event in ipairs(event_list) do
                -- envoie le key dans le chat 
                minetest.chat_send_all("key :" .. key .. "")
                if (pos_filter == "all" or key == pos_filter)
                    and (event_type_filter == "all" or event.event_type == event_type_filter)
                    and (entity_filter == "all" or event.entity == entity_filter)
                    and (node_name_filter == "all" or event.node_name == node_name_filter) then
                    table.insert(matching_events, { key = key, event = event })
                end
            end
        end

        -- Fonction de tri en fonction de l'horodatage (timestamp)
        table.sort(matching_events, function(a, b)
            return a.event.timestamp < b.event.timestamp
        end)

        local numero_event = 0

        -- Envoyer les événements filtrés au joueur
        for _, item in ipairs(matching_events) do
            local key = item.key
            local event = item.event

            numero_event = numero_event + 1
            minetest.chat_send_player(name, "pos: " .. key .. " entity: " .. event.entity .. " event_type: " .. event.event_type .. " node_name: " .. event.node_name .. " timestamp: " .. event.timestamp)
        end

        minetest.chat_send_all("Nombre d'events : " .. numero_event)

        return true, S("[blockwatch] Événements correspondants envoyés au joueur ") .. name .. "."
    end,
})











































































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
        blockwatch.log_event({x=x, y=y, z=z}, "place", random_pseudo, random_block_name)

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
    blockwatch.log_event({x=x, y=y, z=z}, "place", random_pseudo, random_block_name)
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





minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    -- Vérifie si le nœud posé est un seau d'eau
    if newnode.name == "bucket:bucket_water" or newnode.name == "bucket:bucket_river_water" then
        -- Vérifie si le placer (joueur) est un objet joueur valide
        if placer and placer:is_player() then
            -- Envoie un message dans le chat indiquant que le joueur a posé un seau d'eau
            minetest.chat_send_all("Le joueur " .. placer:get_player_name() .. " a posé un seau d'eau à la position : (" .. pos.x .. ", " .. pos.y .. ", " .. pos.z .. ")")
            
            -- Vous pouvez également ajouter d'autres actions ici en fonction de vos besoins
        end
    end
end)
