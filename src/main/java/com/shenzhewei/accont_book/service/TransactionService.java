package com.shenzhewei.accont_book.service;

import com.shenzhewei.accont_book.model.dto.TransactionDTO;
import com.shenzhewei.accont_book.model.entity.Transaction;

import java.util.List;

/**
 * 流水服务接口
 */
public interface TransactionService {

    /**
     * 新增记账
     *
     * @param dto 记账请求
     * @return 流水记录
     */
    Transaction addTransaction(TransactionDTO dto);

    /**
     * 查询用户流水列表
     */
    List<Transaction> listByUserId(Long userId);

    /**
     * 查询资产流水列表
     */
    List<Transaction> listByAssetId(Long assetId);

    /**
     * 删除流水并回滚余额
     *
     * @param id 流水ID
     */
    void deleteTransaction(Long id);

    /**
     * 统计资产下的流水数量
     */
    int countByAssetId(Long assetId);
}
