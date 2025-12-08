package com.shenzhewei.accont_book.service;

import com.shenzhewei.accont_book.model.entity.Asset;

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
     * @param id     资产ID
     * @param amount 变动金额（正数增加，负数减少）
     */
    void updateBalance(Long id, BigDecimal amount);

    /**
     * 修改资产名称
     *
     * @param id   资产ID
     * @param name 新名称
     */
    void updateName(Long id, String name);

    /**
     * 删除资产（需确保无流水记录）
     *
     * @param id 资产ID
     */
    void delete(Long id);
}
