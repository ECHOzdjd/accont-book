package com.shenzhewei.statistics.entity;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * 月度统计实体
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MonthlyStatistics {

    private Long userId;
    private String month;  // 格式：yyyy-MM
    private BigDecimal totalIncome;
    private BigDecimal totalExpense;
    private BigDecimal netAmount;
    private Integer transactionCount;
}
