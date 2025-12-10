package com.shenzhewei.transaction.service;

import com.shenzhewei.common.api.dto.TransactionDTO;
import com.shenzhewei.transaction.entity.Transaction;

import java.util.List;

/**
 * 交易服务接口
 */
public interface TransactionService {

    /**
     * 新增记账
     */
    Transaction addTransaction(TransactionDTO dto);

    /**
     * 根据用户ID查询流水
     */
    List<Transaction> listByUserId(Long userId);

    /**
     * 根据资产ID查询流水
     */
    List<Transaction> listByAssetId(Long assetId);

    /**
     * 删除流水（自动回滚余额）
     */
    void deleteTransaction(Long id);
}
