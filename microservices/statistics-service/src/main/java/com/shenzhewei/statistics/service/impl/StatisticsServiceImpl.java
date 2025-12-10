package com.shenzhewei.statistics.service.impl;

import com.shenzhewei.statistics.entity.CategoryStatistics;
import com.shenzhewei.statistics.entity.MonthlyStatistics;
import com.shenzhewei.statistics.service.StatisticsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * 统计服务实现
 * 通过SQL聚合计算统计数据
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StatisticsServiceImpl implements StatisticsService {

    private final JdbcTemplate jdbcTemplate;
    private static final DateTimeFormatter MONTH_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM");

    @Override
    public void updateStatistics(Long userId, Long transactionId) {
        // 此方法由消息触发，可以用于预计算和缓存统计数据
        // 当前实现采用实时查询，后续可优化为预计算
        log.info("统计数据更新触发: userId={}, transactionId={}", userId, transactionId);
    }

    @Override
    public List<MonthlyStatistics> getMonthlyStatistics(Long userId, int months) {
        String sql = """
            SELECT 
                DATE_FORMAT(trans_time, '%Y-%m') as month,
                SUM(CASE WHEN type = 2 THEN amount ELSE 0 END) as total_income,
                SUM(CASE WHEN type = 1 THEN amount ELSE 0 END) as total_expense,
                COUNT(*) as transaction_count
            FROM tb_transaction 
            WHERE user_id = ? 
                AND trans_time >= DATE_SUB(CURDATE(), INTERVAL ? MONTH)
            GROUP BY DATE_FORMAT(trans_time, '%Y-%m')
            ORDER BY month DESC
            """;

        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql, userId, months);
        
        List<MonthlyStatistics> result = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            BigDecimal income = (BigDecimal) row.get("total_income");
            BigDecimal expense = (BigDecimal) row.get("total_expense");
            
            result.add(MonthlyStatistics.builder()
                    .userId(userId)
                    .month((String) row.get("month"))
                    .totalIncome(income)
                    .totalExpense(expense)
                    .netAmount(income.subtract(expense))
                    .transactionCount(((Number) row.get("transaction_count")).intValue())
                    .build());
        }
        
        return result;
    }

    @Override
    public List<CategoryStatistics> getCategoryStatistics(Long userId, String month, Integer type) {
        String sql = """
            SELECT 
                category,
                type,
                SUM(amount) as total_amount,
                COUNT(*) as transaction_count
            FROM tb_transaction 
            WHERE user_id = ? 
                AND DATE_FORMAT(trans_time, '%Y-%m') = ?
                AND (? IS NULL OR type = ?)
            GROUP BY category, type
            ORDER BY total_amount DESC
            """;

        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql, userId, month, type, type);
        
        // 计算总金额用于百分比
        BigDecimal totalSum = rows.stream()
                .map(row -> (BigDecimal) row.get("total_amount"))
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        List<CategoryStatistics> result = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            BigDecimal amount = (BigDecimal) row.get("total_amount");
            double percentage = totalSum.compareTo(BigDecimal.ZERO) > 0 
                    ? amount.divide(totalSum, 4, RoundingMode.HALF_UP).doubleValue() * 100 
                    : 0;
            
            result.add(CategoryStatistics.builder()
                    .userId(userId)
                    .category((String) row.get("category"))
                    .type((Integer) row.get("type"))
                    .totalAmount(amount)
                    .transactionCount(((Number) row.get("transaction_count")).intValue())
                    .percentage(percentage)
                    .build());
        }
        
        return result;
    }

    @Override
    public MonthlyStatistics getCurrentMonthSummary(Long userId) {
        String currentMonth = LocalDate.now().format(MONTH_FORMATTER);
        
        String sql = """
            SELECT 
                SUM(CASE WHEN type = 2 THEN amount ELSE 0 END) as total_income,
                SUM(CASE WHEN type = 1 THEN amount ELSE 0 END) as total_expense,
                COUNT(*) as transaction_count
            FROM tb_transaction 
            WHERE user_id = ? 
                AND DATE_FORMAT(trans_time, '%Y-%m') = ?
            """;

        Map<String, Object> row = jdbcTemplate.queryForMap(sql, userId, currentMonth);
        
        BigDecimal income = row.get("total_income") != null 
                ? (BigDecimal) row.get("total_income") 
                : BigDecimal.ZERO;
        BigDecimal expense = row.get("total_expense") != null 
                ? (BigDecimal) row.get("total_expense") 
                : BigDecimal.ZERO;
        
        return MonthlyStatistics.builder()
                .userId(userId)
                .month(currentMonth)
                .totalIncome(income)
                .totalExpense(expense)
                .netAmount(income.subtract(expense))
                .transactionCount(((Number) row.get("transaction_count")).intValue())
                .build();
    }
}
