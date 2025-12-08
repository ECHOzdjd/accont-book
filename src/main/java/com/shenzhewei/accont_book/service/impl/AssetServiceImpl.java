package com.shenzhewei.accont_book.service.impl;

import com.shenzhewei.accont_book.common.ResultCode;
import com.shenzhewei.accont_book.exception.BizException;
import com.shenzhewei.accont_book.model.entity.Asset;
import com.shenzhewei.accont_book.repository.AssetMapper;
import com.shenzhewei.accont_book.repository.TransactionMapper;
import com.shenzhewei.accont_book.service.AssetService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

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
    private final TransactionMapper transactionMapper;

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
    public void updateBalance(Long id, BigDecimal amount) {
        // 查询当前资产
        Asset asset = assetMapper.findById(id)
                .orElseThrow(() -> new BizException(ResultCode.NOT_FOUND, "资产不存在"));

        // 使用乐观锁更新余额
        int rows = assetMapper.updateBalanceWithOptimisticLock(id, amount, asset.getVersion());

        if (rows == 0) {
            log.warn("乐观锁冲突: assetId={}, version={}", id, asset.getVersion());
            throw new BizException(ResultCode.OPTIMISTIC_LOCK_ERROR);
        }

        log.info("资产余额更新成功: assetId={}, amount={}", id, amount);
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

        // 检查是否有关联的流水记录
        int transactionCount = transactionMapper.countByAssetId(id);
        if (transactionCount > 0) {
            throw new BizException(ResultCode.BIZ_ERROR, 
                    "该资产下有 " + transactionCount + " 条流水记录，请先清空流水后再删除");
        }

        assetMapper.deleteById(id);
        log.info("资产删除成功: assetId={}", id);
    }
}
