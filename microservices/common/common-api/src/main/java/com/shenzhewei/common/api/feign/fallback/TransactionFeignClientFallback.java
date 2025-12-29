package com.shenzhewei.common.api.feign.fallback;

import com.shenzhewei.common.api.dto.CategoryStatisticsDTO;
import com.shenzhewei.common.api.feign.TransactionFeignClient;
import com.shenzhewei.common.core.Result;
import com.shenzhewei.common.core.ResultCode;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.Collections;
import java.util.List;

/**
 * 交易服务Feign客户端降级实现
 */
@Slf4j
@Component
public class TransactionFeignClientFallback implements TransactionFeignClient {

    @Override
    public Result<List<CategoryStatisticsDTO>> getCategoryStatistics(Long userId, String month, Integer type) {
        log.warn("交易服务不可用，降级处理：getCategoryStatistics({}, {}, {})", userId, month, type);
        return Result.success(Collections.emptyList());
    }
}
