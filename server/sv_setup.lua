MySQL.ready(function()
    -- Check if maximgm_plants table exists
    local success, result = pcall(MySQL.scalar.await, 'SELECT 1 FROM `maximgm_plants` LIMIT 1')

    if not success then
        utils.print('Creating maximgm_plants table')

        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `maximgm_plants` (
                `id` int(11) NOT NULL AUTO_INCREMENT,
                `coords` longtext NOT NULL CHECK (json_valid(`coords`)),
                `time` datetime NOT NULL,
                `fertilizer` longtext NOT NULL CHECK (json_valid(`fertilizer`)),
                `water` longtext NOT NULL CHECK (json_valid(`water`)),
                `plantType` varchar(50) NOT NULL,
                PRIMARY KEY (`id`)
            )
        ]])
    end
end)


--- Database Update
--- Adds owner column to plants table

MySQL.ready(function()
    -- Check if owner column exists
    local columnExists = MySQL.scalar.await([[
        SELECT COUNT(*) 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = 'maximgm_plants' 
        AND COLUMN_NAME = 'owner'
    ]])

    if columnExists == 0 then
        utils.print('Adding owner column to maximgm_plants table...')
        
        MySQL.query([[
            ALTER TABLE `maximgm_plants` 
            ADD COLUMN `owner` VARCHAR(50) NOT NULL DEFAULT '' AFTER `plantType`
        ]])
        
        utils.print('Owner column added successfully!')
    end
end)