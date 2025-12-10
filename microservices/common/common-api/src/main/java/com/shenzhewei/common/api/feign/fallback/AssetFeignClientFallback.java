package com.shenzhewei.common.api.feign.fallback;

import com.shenzhewei.common.api.dto.AssetDTO;
import com.shenzhewei.common.api.dto.BalanceChangeRequest;
import com.shenzhewei.common.api.feign.AssetFeignClient;
import com.shenzhewei.common.core.Result;
import com.shenzhewei.common.core.ResultCode;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.Collections;
import java.util.List;

/**
 * 资产服务Feign客户端降级实现
 */
@Slf4j
@Component
public class AssetFeignClientFallback implements AssetFeignClient {

    @Override
    public Result<AssetDTO> getById(Long id) {
        log.warn("资产服务不可用，降级处理：getById({})", id);
        return Result.fail(ResultCode.SERVICE_DEGRADED, "资产服务暂时不可用，请稍后重试");
    }

    @Override
    public Result<List<AssetDTO>> listByUserId(Long userId) {
        log.warn("资产服务不可用，降级处理：listByUserId({})", userId);
        return Result.fail(ResultCode.SERVICE_DEGRADED, "资产服务暂时不可用，请稍后重试");
    }

    @Override
    public Result<AssetDTO> debit(Long id, BalanceChangeRequest request) {
        log.warn("资产服务不可用，降级处理：debit({}, {})", id, request);
        return Result.fail(ResultCode.SERVICE_DEGRADED, "记账排队中，请稍后查看");
    }

    @Override
    public Result<AssetDTO> credit(Long id, BalanceChangeRequest request) {
        log.warn("资产服务不可用，降级处理：credit({}, {})", id, request);
        return Result.fail(ResultCode.SERVICE_DEGRADED, "记账排队中，请稍后查看");
    }
}
