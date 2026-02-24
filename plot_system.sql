-- ============================================================
-- MaximGM Farming + Plot System - Complete Database Setup
-- Jalankan query ini di database lo (via HeidiSQL, phpMyAdmin, dll)
-- ============================================================

-- ------------------------------------------------------------
-- 1. Tabel plants (maximgm_plants)
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `maximgm_plants` (
    `id`          INT(11) NOT NULL AUTO_INCREMENT,
    `coords`      LONGTEXT NOT NULL CHECK (json_valid(`coords`)),
    `time`        DATETIME NOT NULL,
    `fertilizer`  LONGTEXT NOT NULL CHECK (json_valid(`fertilizer`)),
    `water`       LONGTEXT NOT NULL CHECK (json_valid(`water`)),
    `plantType`   VARCHAR(50) NOT NULL,
    `owner`       VARCHAR(50) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`)
);

-- Kalau tabel sudah ada tapi kolom owner belum ada, jalankan ini:
ALTER TABLE `maximgm_plants`
    ADD COLUMN IF NOT EXISTS `owner` VARCHAR(50) NOT NULL DEFAULT '' AFTER `plantType`;

-- ------------------------------------------------------------
-- 2. Tabel plots (maximgm_plots)
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `maximgm_plots` (
    `id`     INT(11) NOT NULL AUTO_INCREMENT,
    `owner`  VARCHAR(50) NOT NULL DEFAULT '',
    `coords` LONGTEXT NOT NULL CHECK (json_valid(`coords`)),
    `tier`   INT(11) NOT NULL DEFAULT 1,
    `time`   DATETIME NOT NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_owner` (`owner`)
);