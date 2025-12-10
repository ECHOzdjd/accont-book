package com.shenzhewei.common.api.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * 余额变更请求DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BalanceChangeRequest {

    /**
     * 变更金额（正数）
     */
    @NotNull(message = "金额不能为空")
    @DecimalMin(value = "0.01", message = "金额必须大于0")
    private BigDecimal amount;

    /**
     * 当前版本号（用于乐观锁）
     */
    private Integer version;

    /**
     * 幂等键（可选，防止重复扣款）
     */
    private String idempotentKey;
}
