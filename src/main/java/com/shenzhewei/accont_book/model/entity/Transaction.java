package com.shenzhewei.accont_book.model.entity;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 流水实体
 * 对应表: tb_transaction
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Transaction {

    /**
     * 主键ID
     */
    private Long id;

    /**
     * 用户ID
     */
    private Long userId;

    /**
     * 资产ID
     */
    private Long assetId;

    /**
     * 金额
     */
    private BigDecimal amount;

    /**
     * 类型：1-支出，2-收入
     */
    private Integer type;

    /**
     * 分类
     */
    private String category;

    /**
     * 交易时间
     */
    private LocalDateTime transTime;

    /**
     * 交易类型常量
     */
    public static final int TYPE_EXPENSE = 1;  // 支出
    public static final int TYPE_INCOME = 2;   // 收入
}
