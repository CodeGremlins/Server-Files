-- SQL database for the blackmarket stock
-- Adjust table name prefix if needed to avoid conflicts with other resources

CREATE TABLE IF NOT EXISTS `cg_blackmarket_stock` (
  `item` varchar(64) NOT NULL,
  `amount` int NOT NULL DEFAULT 0,
  PRIMARY KEY (`item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed rows are optional; script will insert missing on first start
 INSERT INTO `cg_blackmarket_stock` (item, amount) VALUES
 ('weapon_pistol', 3),
 ('pistol_ammo', 15),
 ('lockpick', 40),
 ('bandage', 50);
