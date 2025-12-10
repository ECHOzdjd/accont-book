package com.shenzhewei.statistics.service;

import com.shenzhewei.statistics.entity.CategoryStatistics;
import com.shenzhewei.statistics.entity.MonthlyStatistics;

import java.util.List;

/**
 * 统计服务接口
 */
public interface StatisticsService {

    /**
     * 更新统计数据（由消息触发）
     */
    void updateStatistics(Long userId, Long transactionId);

    /**
     * 获取用户月度统计
     */
    List<MonthlyStatistics> getMonthlyStatistics(Long userId, int months);

    /**
     * 获取用户分类统计
     */
    List<CategoryStatistics> getCategoryStatistics(Long userId, String month, Integer type);

    /**
     * 获取用户当月概览
     */
    MonthlyStatistics getCurrentMonthSummary(Long userId);
}
