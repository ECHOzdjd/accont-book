package com.shenzhewei.statistics.controller;

import com.shenzhewei.common.core.Result;
import com.shenzhewei.statistics.entity.CategoryStatistics;
import com.shenzhewei.statistics.entity.MonthlyStatistics;
import com.shenzhewei.statistics.service.StatisticsService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;

/**
 * 统计控制器
 */
@RestController
@RequestMapping("/api/stats")
@RequiredArgsConstructor
public class StatisticsController {

    private final StatisticsService statisticsService;

    /**
     * 获取用户月度统计（最近N个月）
     */
    @GetMapping("/monthly/{userId}")
    public Result<List<MonthlyStatistics>> getMonthlyStatistics(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "6") int months) {
        List<MonthlyStatistics> stats = statisticsService.getMonthlyStatistics(userId, months);
        return Result.success(stats);
    }

    /**
     * 获取用户当月概览
     */
    @GetMapping("/summary/{userId}")
    public Result<MonthlyStatistics> getCurrentMonthSummary(@PathVariable Long userId) {
        MonthlyStatistics summary = statisticsService.getCurrentMonthSummary(userId);
        return Result.success(summary);
    }

    /**
     * 获取用户分类统计
     */
    @GetMapping("/category/{userId}")
    public Result<List<CategoryStatistics>> getCategoryStatistics(
            @PathVariable Long userId,
            @RequestParam(required = false) String month,
            @RequestParam(required = false) Integer type) {
        
        // 默认当月
        if (month == null) {
            month = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy-MM"));
        }
        
        List<CategoryStatistics> stats = statisticsService.getCategoryStatistics(userId, month, type);
        return Result.success(stats);
    }
}
