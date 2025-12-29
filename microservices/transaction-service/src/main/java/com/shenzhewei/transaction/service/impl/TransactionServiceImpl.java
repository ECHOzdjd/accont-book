package com.shenzhewei.transaction.service.impl;

import com.shenzhewei.common.api.dto.AssetDTO;
import com.shenzhewei.common.api.dto.BalanceChangeRequest;
import com.shenzhewei.common.api.dto.CategoryStatisticsDTO;
import com.shenzhewei.common.api.dto.TransactionDTO;
import com.shenzhewei.common.api.feign.AssetFeignClient;
import com.shenzhewei.common.core.Result;
import com.shenzhewei.common.core.ResultCode;
import com.shenzhewei.common.core.exception.BizException;
import com.shenzhewei.transaction.entity.Transaction;
import com.shenzhewei.transaction.mapper.TransactionMapper;
import com.shenzhewei.transaction.mq.TransactionMessageSender;
import com.shenzhewei.transaction.service.TransactionService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * 交易服务实现
 * 通过Feign调用asset-service，支持熔断降级
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TransactionServiceImpl implements TransactionService {

    private final TransactionMapper transactionMapper;
    private final AssetFeignClient assetFeignClient;
    private final TransactionMessageSender messageSender;
    private final JdbcTemplate jdbcTemplate;

    /**
     * 新增记账
     * 核心逻辑：先通过Feign调用更新余额，再插入流水记录
     */
    @Override
    @Transactional(rollbackFor = Exception.class)
    public Transaction addTransaction(TransactionDTO dto) {
        // 1. 校验交易类型
        if (dto.getType() != TransactionDTO.TYPE_EXPENSE && dto.getType() != TransactionDTO.TYPE_INCOME) {
            throw new BizException(ResultCode.PARAM_ERROR, "交易类型无效，1-支出，2-收入");
        }

        // 2. 通过Feign调用资产服务更新余额
        BalanceChangeRequest balanceRequest = BalanceChangeRequest.builder()
                .amount(dto.getAmount())
                .build();

        Result<AssetDTO> assetResult;
        if (dto.getType() == TransactionDTO.TYPE_EXPENSE) {
            // 支出 -> 扣款
            assetResult = assetFeignClient.debit(dto.getAssetId(), balanceRequest);
        } else {
            // 收入 -> 入账
            assetResult = assetFeignClient.credit(dto.getAssetId(), balanceRequest);
        }

        // 3. 检查远程调用结果
        if (assetResult.getCode() != 200) {
            log.warn("资产服务调用失败: code={}, message={}", assetResult.getCode(), assetResult.getMessage());
            throw new BizException(assetResult.getCode(), assetResult.getMessage());
        }

        // 4. 构建流水实体并插入
        Transaction transaction = Transaction.builder()
                .userId(dto.getUserId())
                .assetId(dto.getAssetId())
                .amount(dto.getAmount())
                .type(dto.getType())
                .category(dto.getCategory())
                .transTime(dto.getTransTime() != null ? dto.getTransTime() : LocalDateTime.now())
                .build();

        transactionMapper.insert(transaction);
        log.info("流水记录插入成功: id={}", transaction.getId());

        // 5. 发送RabbitMQ消息通知统计服务
        messageSender.sendTransactionSuccessMessage(transaction);

        log.info("记账成功: transactionId={}, assetId={}, type={}, amount={}",
                transaction.getId(), dto.getAssetId(), dto.getType(), dto.getAmount());

        return transaction;
    }

    @Override
    public List<Transaction> listByUserId(Long userId) {
        return transactionMapper.findByUserId(userId);
    }

    @Override
    public List<Transaction> listByAssetId(Long assetId) {
        return transactionMapper.findByAssetId(assetId);
    }

    /**
     * 删除流水并回滚余额
     */
    @Override
    @Transactional(rollbackFor = Exception.class)
    public void deleteTransaction(Long id) {
        // 1. 查询该笔流水
        Transaction transaction = transactionMapper.findById(id)
                .orElseThrow(() -> new BizException(ResultCode.NOT_FOUND, "流水记录不存在"));

        // 2. 通过Feign调用资产服务回滚余额
        BalanceChangeRequest balanceRequest = BalanceChangeRequest.builder()
                .amount(transaction.getAmount())
                .build();

        Result<AssetDTO> assetResult;
        if (transaction.getType() == Transaction.TYPE_EXPENSE) {
            // 删除支出 -> 入账（加回来）
            assetResult = assetFeignClient.credit(transaction.getAssetId(), balanceRequest);
        } else {
            // 删除收入 -> 扣款（减回去）
            assetResult = assetFeignClient.debit(transaction.getAssetId(), balanceRequest);
        }

        // 3. 检查远程调用结果
        if (assetResult.getCode() != 200) {
            log.warn("资产服务调用失败: code={}, message={}", assetResult.getCode(), assetResult.getMessage());
            throw new BizException(assetResult.getCode(), assetResult.getMessage());
        }

        // 4. 删除流水记录
        transactionMapper.deleteById(id);

        log.info("流水删除成功，余额已回滚: transactionId={}, assetId={}",
                id, transaction.getAssetId());
    }

    /**
     * 获取分类统计数据
     * 通过SQL聚合计算各分类的统计数据
     */
    @Override
    public List<CategoryStatisticsDTO> getCategoryStatistics(Long userId, String month, Integer type) {
        String sql = """
            SELECT 
                category,
                type,
                SUM(amount) as total_amount,
                COUNT(*) as transaction_count
            FROM tb_transaction 
            WHERE user_id = ? 
                AND DATE_FORMAT(trans_time, '%Y-%m') = ?
                AND (? IS NULL OR type = ?)
                AND is_deleted = 0
            GROUP BY category, type
            ORDER BY total_amount DESC
            """;

        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql, userId, month, type, type);
        
        List<CategoryStatisticsDTO> result = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            result.add(CategoryStatisticsDTO.builder()
                    .userId(userId)
                    .category((String) row.get("category"))
                    .type((Integer) row.get("type"))
                    .totalAmount((BigDecimal) row.get("total_amount"))
                    .transactionCount(((Number) row.get("transaction_count")).intValue())
                    .build());
        }
        
        log.info("分类统计查询成功: userId={}, month={}, type={}, count={}", 
                 userId, month, type, result.size());
        
        return result;
    }
}
