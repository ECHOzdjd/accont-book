package com.shenzhewei.transaction.controller;

import com.shenzhewei.common.api.dto.CategoryStatisticsDTO;
import com.shenzhewei.common.api.dto.TransactionDTO;
import com.shenzhewei.common.core.Result;
import com.shenzhewei.transaction.entity.Transaction;
import com.shenzhewei.transaction.service.TransactionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 流水控制器
 */
@RestController
@RequestMapping("/api/transactions")
@RequiredArgsConstructor
public class TransactionController {

    private final TransactionService transactionService;

    /**
     * 新增记账
     */
    @PostMapping
    public Result<Transaction> addTransaction(@Valid @RequestBody TransactionDTO dto) {
        Transaction transaction = transactionService.addTransaction(dto);
        return Result.success(transaction);
    }

    /**
     * 查询用户流水列表
     */
    @GetMapping("/user/{userId}")
    public Result<List<Transaction>> listByUserId(@PathVariable Long userId) {
        List<Transaction> transactions = transactionService.listByUserId(userId);
        return Result.success(transactions);
    }

    /**
     * 查询资产流水列表
     */
    @GetMapping("/asset/{assetId}")
    public Result<List<Transaction>> listByAssetId(@PathVariable Long assetId) {
        List<Transaction> transactions = transactionService.listByAssetId(assetId);
        return Result.success(transactions);
    }

    /**
     * 删除流水（自动回滚余额）
     */
    @DeleteMapping("/{id}")
    public Result<Void> deleteTransaction(@PathVariable Long id) {
        transactionService.deleteTransaction(id);
        return Result.success();
    }

    /**
     * 获取分类统计数据
     * 用于统计服务的跨服务调用
     * 
     * @param userId 用户ID
     * @param month 月份（格式：yyyy-MM）
     * @param type 交易类型（可选）：1-支出，2-收入，null-全部
     * @return 分类统计列表
     */
    @GetMapping("/statistics/category")
    public Result<List<CategoryStatisticsDTO>> getCategoryStatistics(
            @RequestParam("userId") Long userId,
            @RequestParam("month") String month,
            @RequestParam(value = "type", required = false) Integer type) {
        List<CategoryStatisticsDTO> statistics = transactionService.getCategoryStatistics(userId, month, type);
        return Result.success(statistics);
    }
}
