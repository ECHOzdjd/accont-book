package com.shenzhewei.accont_book.controller;

import com.shenzhewei.accont_book.common.Result;
import com.shenzhewei.accont_book.model.dto.TransactionDTO;
import com.shenzhewei.accont_book.model.entity.Transaction;
import com.shenzhewei.accont_book.service.TransactionService;
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
}
