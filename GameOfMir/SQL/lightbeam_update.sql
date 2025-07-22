-- 物品光柱功能数据库更新脚本
-- 为StdItems表添加光柱相关字段

-- 添加光柱效果开关字段
ALTER TABLE StdItems ADD COLUMN LightBeamEnabled INTEGER DEFAULT 0;

-- 添加光柱类型字段
ALTER TABLE StdItems ADD COLUMN LightBeamType INTEGER DEFAULT 0;

-- 添加光柱动画帧数字段
ALTER TABLE StdItems ADD COLUMN LightBeamFrameCount INTEGER DEFAULT 10;

-- 添加光柱动画帧间隔字段
ALTER TABLE StdItems ADD COLUMN LightBeamFrameTime INTEGER DEFAULT 100;

-- 为一些重要物品设置光柱效果示例
-- 设置屠龙刀为金色光柱
UPDATE StdItems SET 
    LightBeamEnabled = 1,
    LightBeamType = 1,
    LightBeamFrameCount = 12,
    LightBeamFrameTime = 80
WHERE Name = '屠龙刀';

-- 设置裁决之杖为蓝色光柱
UPDATE StdItems SET 
    LightBeamEnabled = 1,
    LightBeamType = 2,
    LightBeamFrameCount = 10,
    LightBeamFrameTime = 100
WHERE Name = '裁决之杖';

-- 设置骨玉权杖为红色光柱
UPDATE StdItems SET 
    LightBeamEnabled = 1,
    LightBeamType = 3,
    LightBeamFrameCount = 8,
    LightBeamFrameTime = 120
WHERE Name = '骨玉权杖';

-- 设置无极棍为绿色光柱
UPDATE StdItems SET 
    LightBeamEnabled = 1,
    LightBeamType = 4,
    LightBeamFrameCount = 15,
    LightBeamFrameTime = 60
WHERE Name = '无极棍';

-- 设置龙纹剑为紫色光柱
UPDATE StdItems SET 
    LightBeamEnabled = 1,
    LightBeamType = 5,
    LightBeamFrameCount = 20,
    LightBeamFrameTime = 50
WHERE Name = '龙纹剑';

-- 为一些稀有装备设置光柱效果
UPDATE StdItems SET 
    LightBeamEnabled = 1,
    LightBeamType = 1,
    LightBeamFrameCount = 10,
    LightBeamFrameTime = 100
WHERE Price >= 1000000 AND LightBeamEnabled = 0;

-- 为一些特殊物品设置光柱效果
UPDATE StdItems SET 
    LightBeamEnabled = 1,
    LightBeamType = 2,
    LightBeamFrameCount = 8,
    LightBeamFrameTime = 120
WHERE Reserved IN (8, 9, 10) AND LightBeamEnabled = 0; 