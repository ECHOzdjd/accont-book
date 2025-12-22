package com.shenzhewei.user.dto;

import com.shenzhewei.common.api.dto.UserDTO;
import lombok.Data;

/**
 * 登录响应 DTO
 */
@Data
public class LoginResponse {

    /**
     * JWT Token
     */
    private String token;

    /**
     * Token 类型
     */
    private String tokenType;

    /**
     * 用户信息
     */
    private UserDTO user;

    public LoginResponse(String token, UserDTO user) {
        this.token = token;
        this.tokenType = "Bearer";
        this.user = user;
    }
}
