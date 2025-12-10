package com.shenzhewei.asset.controller;

import com.shenzhewei.asset.entity.Asset;
import com.shenzhewei.asset.service.AssetService;
import com.shenzhewei.common.api.dto.AssetDTO;
import com.shenzhewei.common.api.dto.BalanceChangeRequest;
import com.shenzhewei.common.core.Result;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.net.InetAddress;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 资产控制器
 */
@RestController
@RequestMapping("/api/assets")
@RequiredArgsConstructor
public class AssetController {

    private final AssetService assetService;
    private final Environment environment;

    /**
     * 获取实例信息 - 用于负载均衡测试
     */
    @GetMapping("/instance")
    public Result<Map<String, String>> getInstance() {
        Map<String, String> info = new HashMap<>();
        try {
            info.put("ip", InetAddress.getLocalHost().getHostAddress());
            info.put("hostname", InetAddress.getLocalHost().getHostName());
        } catch (Exception e) {
            info.put("ip", "unknown");
            info.put("hostname", "unknown");
        }
        info.put("port", environment.getProperty("server.port", "8082"));
        return Result.success(info);
    }

    /**
     * 查询资产详情
     */
    @GetMapping("/{id}")
    public Result<AssetDTO> getById(@PathVariable Long id) {
        return assetService.findById(id)
                .map(this::toDTO)
                .map(Result::success)
                .orElse(Result.fail(404, "资产不存在"));
    }

    /**
     * 查询用户资产列表
     */
    @GetMapping("/user/{userId}")
    public Result<List<AssetDTO>> listByUserId(@PathVariable Long userId) {
        List<AssetDTO> assets = assetService.findByUserId(userId).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
        return Result.success(assets);
    }

    /**
     * 创建资产账户
     */
    @PostMapping
    public Result<AssetDTO> create(@RequestBody CreateAssetRequest request) {
        Asset asset = Asset.builder()
                .userId(request.getUserId())
                .name(request.getName())
                .balance(request.getBalance() != null ? request.getBalance() : BigDecimal.ZERO)
                .build();
        Asset created = assetService.create(asset);
        return Result.success(toDTO(created));
    }

    /**
     * 扣款（支出）- 供transaction-service调用
     */
    @PostMapping("/{id}/debit")
    public Result<AssetDTO> debit(@PathVariable Long id, @RequestBody BalanceChangeRequest request) {
        Asset updated = assetService.debit(id, request.getAmount(), request.getVersion());
        return Result.success(toDTO(updated));
    }

    /**
     * 入账（收入）- 供transaction-service调用
     */
    @PostMapping("/{id}/credit")
    public Result<AssetDTO> credit(@PathVariable Long id, @RequestBody BalanceChangeRequest request) {
        Asset updated = assetService.credit(id, request.getAmount(), request.getVersion());
        return Result.success(toDTO(updated));
    }

    /**
     * 修改资产名称
     */
    @PutMapping("/{id}")
    public Result<Void> updateName(@PathVariable Long id, @RequestBody UpdateAssetRequest request) {
        assetService.updateName(id, request.getName());
        return Result.success();
    }

    /**
     * 删除资产
     */
    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        assetService.delete(id);
        return Result.success();
    }

    private AssetDTO toDTO(Asset asset) {
        return AssetDTO.builder()
                .id(asset.getId())
                .userId(asset.getUserId())
                .name(asset.getName())
                .balance(asset.getBalance())
                .version(asset.getVersion())
                .createTime(asset.getCreateTime())
                .build();
    }

    /**
     * 创建资产请求
     */
    @lombok.Data
    public static class CreateAssetRequest {
        private Long userId;
        private String name;
        private BigDecimal balance;
    }

    /**
     * 修改资产请求
     */
    @lombok.Data
    public static class UpdateAssetRequest {
        private String name;
    }
}
