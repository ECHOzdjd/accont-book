package com.shenzhewei.statistics.entity;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 日统计预计算实体类
 * 用于存储每日的收支统计数据，支持增量更新
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DailyStatistics {
    
    /**
     * 主键ID
     */
    private Long id;
    
    /**
     * 用户ID
     */
    private Long userId;
    
    /**
     * 统计日期
     */
    private LocalDate statDate;
    
    /**
     * 当日收入总额
     */
    private BigDecimal totalIncome;
    
    /**
     * 当日支出总额
     */
    private BigDecimal totalExpense;
    
    /**
     * 交易笔数
     */
    private Integer transCount;
    
    /**
     * 更新时间
     */
    private LocalDateTime updateTime;
}
