package com.shenzhewei.asset.service.impl;

import com.shenzhewei.asset.entity.Asset;
import com.shenzhewei.asset.mapper.AssetMapper;
import com.shenzhewei.asset.service.AssetService;
import com.shenzhewei.common.core.ResultCode;
import com.shenzhewei.common.core.exception.BizException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * 资产服务实现
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AssetServiceImpl implements AssetService {

    private final AssetMapper assetMapper;

    @Override
    public Optional<Asset> findById(Long id) {
        return assetMapper.findById(id);
    }

    @Override
    public List<Asset> findByUserId(Long userId) {
        return assetMapper.findByUserId(userId);
    }

    @Override
    public Asset create(Asset asset) {
        asset.setVersion(1);
        asset.setCreateTime(LocalDateTime.now());
        assetMapper.insert(asset);
        return asset;
    }

    @Override
    @Transactional
    public Asset updateBalance(Long id, BigDecimal amount, Integer version) {
        // 查询当前资产
        Asset asset = assetMapper.findById(id)
                .orElseThrow(() -> new BizException(ResultCode.NOT_FOUND, "资产不存在"));

        // 如果传入了版本号，校验版本
        Integer currentVersion = version != null ? version : asset.getVersion();

        // 检查余额是否足够（如果是扣款）
        if (amount.compareTo(BigDecimal.ZERO) < 0) {
            BigDecimal newBalance = asset.getBalance().add(amount);
            if (newBalance.compareTo(BigDecimal.ZERO) < 0) {
                throw new BizException(ResultCode.BIZ_ERROR, "余额不足");
            }
        }

        // 使用乐观锁更新余额
        int rows = assetMapper.updateBalanceWithOptimisticLock(id, amount, currentVersion);

        if (rows == 0) {
            log.warn("乐观锁冲突: assetId={}, version={}", id, currentVersion);
            throw new BizException(ResultCode.OPTIMISTIC_LOCK_ERROR);
        }

        log.info("资产余额更新成功: assetId={}, amount={}", id, amount);

        // 返回更新后的资产
        return assetMapper.findById(id).orElseThrow();
    }

    @Override
    @Transactional
    public Asset debit(Long id, BigDecimal amount, Integer version) {
        // 扣款使用负数
        return updateBalance(id, amount.negate(), version);
    }

    @Override
    @Transactional
    public Asset credit(Long id, BigDecimal amount, Integer version) {
        // 入账使用正数
        return updateBalance(id, amount, version);
    }

    @Override
    public void updateName(Long id, String name) {
        // 校验资产是否存在
        assetMapper.findById(id)
                .orElseThrow(() -> new BizException(ResultCode.NOT_FOUND, "资产不存在"));

        assetMapper.updateName(id, name);
        log.info("资产名称更新成功: assetId={}, name={}", id, name);
    }

    @Override
    public void delete(Long id) {
        // 校验资产是否存在
        assetMapper.findById(id)
                .orElseThrow(() -> new BizException(ResultCode.NOT_FOUND, "资产不存在"));

        // 注意：在微服务架构中，检查流水记录需要通过Feign调用transaction-service
        // 这里暂时跳过该检查，或者可以通过RPC调用

        assetMapper.deleteById(id);
        log.info("资产删除成功: assetId={}", id);
    }
}
