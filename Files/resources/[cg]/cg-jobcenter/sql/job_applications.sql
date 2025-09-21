CREATE TABLE IF NOT EXISTS `job_applications` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(64) NOT NULL,
  `job` VARCHAR(50) NOT NULL,
  `motivation` TEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_identifier` (`identifier`),
  INDEX `idx_job` (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
