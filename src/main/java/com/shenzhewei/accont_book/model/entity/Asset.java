package com.shenzhewei.accont_book.model.entity;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 资产实体
 * 对应表: tb_asset
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Asset {

    /**
     * 主键ID
     */
    private Long id;

    /**
     * 用户ID
     */
    private Long userId;

    /**
     * 账户名称
     */
    private String name;

    /**
     * 余额
     */
    private BigDecimal balance;

    /**
     * 版本号（乐观锁）
     */
    private Integer version;

    /**
     * 创建时间
     */
    private LocalDateTime createTime;
}
