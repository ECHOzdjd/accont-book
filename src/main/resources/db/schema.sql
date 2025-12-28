-- 个人记账系统数据库初始化脚本

-- 创建数据库 (如果不存在)
CREATE DATABASE IF NOT EXISTS accont_book DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE accont_book;

-- 用户表
DROP TABLE IF EXISTS sys_user;
CREATE TABLE sys_user (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    username VARCHAR(50) NOT NULL UNIQUE COMMENT '用户名',
    password VARCHAR(100) NOT NULL COMMENT '密码',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    INDEX idx_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

-- 资产表
DROP TABLE IF EXISTS tb_asset;
CREATE TABLE tb_asset (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    name VARCHAR(50) NOT NULL COMMENT '账户名称',
    balance DECIMAL(15, 2) DEFAULT 0.00 COMMENT '余额',
    version INT DEFAULT 1 COMMENT '版本号(乐观锁)',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='资产表';

-- 流水表
DROP TABLE IF EXISTS tb_transaction;
CREATE TABLE tb_transaction (
    id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键ID',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    asset_id BIGINT NOT NULL COMMENT '资产ID',
    amount DECIMAL(15, 2) NOT NULL COMMENT '金额',
    type TINYINT NOT NULL COMMENT '类型: 1-支出, 2-收入',
    category VARCHAR(50) NOT NULL COMMENT '分类',
    trans_time DATETIME NOT NULL COMMENT '交易时间',
    INDEX idx_user_id (user_id),
    INDEX idx_asset_id (asset_id),
    INDEX idx_trans_time (trans_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='流水表';

-- 测试数据
INSERT INTO sys_user (username, password) VALUES ('admin', '123456');

INSERT INTO tb_asset (user_id, name, balance, version) VALUES 
(1, '现金钱包', 10000.00, 1),
(1, '银行卡', 50000.00, 1),
(1, '支付宝', 2000.00, 1);

INSERT INTO tb_transaction (user_id, asset_id, amount, type, category, trans_time) VALUES
(1, 1, 100.00, 1, '餐饮', NOW()),
(1, 2, 5000.00, 2, '工资', NOW());
