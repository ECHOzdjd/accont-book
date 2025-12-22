package com.shenzhewei.user.controller;

import com.shenzhewei.common.api.dto.UserDTO;
import com.shenzhewei.common.core.Result;
import com.shenzhewei.user.dto.LoginResponse;
import com.shenzhewei.user.service.UserService;
import com.shenzhewei.user.util.JwtUtil;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 用户控制器
 */
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;
    private final JwtUtil jwtUtil;

    /**
     * 用户注册
     */
    @PostMapping("/register")
    public Result<UserDTO> register(@Valid @RequestBody RegisterRequest request) {
        UserDTO user = userService.register(request.getUsername(), request.getPassword());
        return Result.success(user);
    }

    /**
     * 用户登录
     */
    @PostMapping("/login")
    public Result<LoginResponse> login(@Valid @RequestBody LoginRequest request) {
        UserDTO user = userService.login(request.getUsername(), request.getPassword());
        
        // 生成 JWT Token
        String token = jwtUtil.generateToken(user.getId(), user.getUsername());
        
        LoginResponse response = new LoginResponse(token, user);
        return Result.success(response);
    }

    /**
     * 根据ID查询用户
     */
    @GetMapping("/{id}")
    public Result<UserDTO> getById(@PathVariable Long id) {
        return userService.findById(id)
                .map(Result::success)
                .orElse(Result.fail(404, "用户不存在"));
    }

    /**
     * 查询所有用户
     */
    @GetMapping
    public Result<List<UserDTO>> list() {
        return Result.success(userService.findAll());
    }

    /**
     * 注册请求
     */
    @Data
    public static class RegisterRequest {
        @NotBlank(message = "用户名不能为空")
        private String username;

        @NotBlank(message = "密码不能为空")
        private String password;
    }

    /**
     * 登录请求
     */
    @Data
    public static class LoginRequest {
        @NotBlank(message = "用户名不能为空")
        private String username;

        @NotBlank(message = "密码不能为空")
        private String password;
    }
}
