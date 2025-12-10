package com.shenzhewei.user.service.impl;

import com.shenzhewei.common.api.dto.UserDTO;
import com.shenzhewei.common.core.ResultCode;
import com.shenzhewei.common.core.exception.BizException;
import com.shenzhewei.user.entity.User;
import com.shenzhewei.user.mapper.UserMapper;
import com.shenzhewei.user.service.UserService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * 用户服务实现
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class UserServiceImpl implements UserService {

    private final UserMapper userMapper;

    @Override
    public UserDTO register(String username, String password) {
        // 检查用户名是否已存在
        if (userMapper.findByUsername(username).isPresent()) {
            throw new BizException(ResultCode.BIZ_ERROR, "用户名已存在");
        }

        User user = User.builder()
                .username(username)
                .password(password)  // TODO: 实际项目应加密存储
                .createTime(LocalDateTime.now())
                .build();

        userMapper.insert(user);
        log.info("用户注册成功: {}", username);

        return toDTO(user);
    }

    @Override
    public UserDTO login(String username, String password) {
        User user = userMapper.findByUsername(username)
                .orElseThrow(() -> new BizException(ResultCode.BIZ_ERROR, "用户名或密码错误"));

        if (!password.equals(user.getPassword())) {  // TODO: 实际项目应加密比对
            throw new BizException(ResultCode.BIZ_ERROR, "用户名或密码错误");
        }

        log.info("用户登录成功: {}", username);
        return toDTO(user);
    }

    @Override
    public Optional<UserDTO> findById(Long id) {
        return userMapper.findById(id).map(this::toDTO);
    }

    @Override
    public Optional<UserDTO> findByUsername(String username) {
        return userMapper.findByUsername(username).map(this::toDTO);
    }

    @Override
    public List<UserDTO> findAll() {
        return userMapper.findAll().stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    private UserDTO toDTO(User user) {
        return UserDTO.builder()
                .id(user.getId())
                .username(user.getUsername())
                .createTime(user.getCreateTime())
                .build();
    }
}
