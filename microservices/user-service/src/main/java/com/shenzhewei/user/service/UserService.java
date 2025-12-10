package com.shenzhewei.user.service;

import com.shenzhewei.common.api.dto.UserDTO;
import com.shenzhewei.user.entity.User;

import java.util.List;
import java.util.Optional;

/**
 * 用户服务接口
 */
public interface UserService {

    /**
     * 用户注册
     */
    UserDTO register(String username, String password);

    /**
     * 用户登录
     */
    UserDTO login(String username, String password);

    /**
     * 根据ID查询用户
     */
    Optional<UserDTO> findById(Long id);

    /**
     * 根据用户名查询用户
     */
    Optional<UserDTO> findByUsername(String username);

    /**
     * 查询所有用户
     */
    List<UserDTO> findAll();
}
