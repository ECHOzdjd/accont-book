package com.shenzhewei.asset.service;

import com.shenzhewei.asset.entity.Asset;
import com.shenzhewei.common.api.dto.AssetDTO;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

/**
 * 资产服务接口
 */
public interface AssetService {

    /**
     * 根据ID查询资产
     */
    Optional<Asset> findById(Long id);

    /**
     * 根据用户ID查询资产列表
     */
    List<Asset> findByUserId(Long userId);

    /**
     * 创建资产
     */
    Asset create(Asset asset);

    /**
     * 更新余额（使用乐观锁）
     *
     * @param id      资产ID
     * @param amount  变动金额（正数增加，负数减少）
     * @param version 可选的版本号（用于乐观锁校验）
     * @return 更新后的资产
     */
    Asset updateBalance(Long id, BigDecimal amount, Integer version);

    /**
     * 扣款（支出）
     */
    Asset debit(Long id, BigDecimal amount, Integer version);

    /**
     * 入账（收入）
     */
    Asset credit(Long id, BigDecimal amount, Integer version);

    /**
     * 修改资产名称
     */
    void updateName(Long id, String name);

    /**
     * 删除资产
     */
    void delete(Long id);
}
