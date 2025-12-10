package com.shenzhewei.common.api.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 资产DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AssetDTO {

    private Long id;
    private Long userId;
    private String name;
    private BigDecimal balance;
    private Integer version;
    private LocalDateTime createTime;
}
