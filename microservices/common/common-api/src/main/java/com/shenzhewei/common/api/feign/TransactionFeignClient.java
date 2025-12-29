package com.shenzhewei.common.api.feign;

import com.shenzhewei.common.api.dto.CategoryStatisticsDTO;
import com.shenzhewei.common.api.feign.fallback.TransactionFeignClientFallback;
import com.shenzhewei.common.core.Result;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 交易服务Feign客户端
 */
@FeignClient(name = "transaction-service", fallback = TransactionFeignClientFallback.class)
public interface TransactionFeignClient {

    /**
     * 获取分类统计数据
     * 
     * @param userId 用户ID
     * @param month 月份（格式：yyyy-MM）
     * @param type 交易类型（可选）：1-支出，2-收入，null-全部
     * @return 分类统计列表
     */
    @GetMapping("/api/transactions/statistics/category")
    Result<List<CategoryStatisticsDTO>> getCategoryStatistics(
            @RequestParam("userId") Long userId,
            @RequestParam("month") String month,
            @RequestParam(value = "type", required = false) Integer type);
}
