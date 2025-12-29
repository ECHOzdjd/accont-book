package com.shenzhewei.common.api.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * 分类统计DTO
 * 用于跨服务传输分类统计数据
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CategoryStatisticsDTO {

    /**
     * 用户ID
     */
    private Long userId;
    
    /**
     * 分类名称
     */
    private String category;
    
    /**
     * 交易类型: 1-支出, 2-收入
     */
    private Integer type;
    
    /**
     * 总金额
     */
    private BigDecimal totalAmount;
    
    /**
     * 交易笔数
     */
    private Integer transactionCount;
}
