--- Plot System Setup (copy dari v1, tidak ada perubahan)
MySQL.ready(function()
    local success = pcall(MySQL.scalar.await, 'SELECT 1 FROM `maximgm_plots` LIMIT 1')
    if not success then
        utils.print('Creating maximgm_plots table...')
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `maximgm_plots` (
                `id`     INT(11) NOT NULL AUTO_INCREMENT,
                `owner`  VARCHAR(50) NOT NULL DEFAULT '',
                `coords` LONGTEXT NOT NULL CHECK (json_valid(`coords`)),
                `tier`   INT(11) NOT NULL DEFAULT 1,
                `time`   DATETIME NOT NULL,
                PRIMARY KEY (`id`),
                INDEX `idx_owner` (`owner`)
            )
        ]])
        utils.print('maximgm_plots table created!')
    end
end)