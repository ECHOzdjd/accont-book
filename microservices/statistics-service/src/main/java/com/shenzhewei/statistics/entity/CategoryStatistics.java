package com.shenzhewei.statistics.entity;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * 分类统计实体
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CategoryStatistics {

    private Long userId;
    private String category;
    private Integer type;  // 1-支出，2-收入
    private BigDecimal totalAmount;
    private Integer transactionCount;
    private Double percentage;
}
