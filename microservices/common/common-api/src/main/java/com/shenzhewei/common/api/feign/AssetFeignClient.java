package com.shenzhewei.common.api.feign;

import com.shenzhewei.common.api.dto.AssetDTO;
import com.shenzhewei.common.api.dto.BalanceChangeRequest;
import com.shenzhewei.common.api.feign.fallback.AssetFeignClientFallback;
import com.shenzhewei.common.core.Result;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 资产服务Feign客户端
 */
@FeignClient(name = "asset-service", fallback = AssetFeignClientFallback.class)
public interface AssetFeignClient {

    /**
     * 根据ID查询资产
     */
    @GetMapping("/api/assets/{id}")
    Result<AssetDTO> getById(@PathVariable("id") Long id);

    /**
     * 查询用户资产列表
     */
    @GetMapping("/api/assets/user/{userId}")
    Result<List<AssetDTO>> listByUserId(@PathVariable("userId") Long userId);

    /**
     * 扣款（支出）
     */
    @PostMapping("/api/assets/{id}/debit")
    Result<AssetDTO> debit(@PathVariable("id") Long id, @RequestBody BalanceChangeRequest request);

    /**
     * 入账（收入）
     */
    @PostMapping("/api/assets/{id}/credit")
    Result<AssetDTO> credit(@PathVariable("id") Long id, @RequestBody BalanceChangeRequest request);
}
