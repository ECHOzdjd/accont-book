package com.shenzhewei.user.mapper;

import com.shenzhewei.user.entity.User;
import org.apache.ibatis.annotations.*;

import java.util.Optional;

/**
 * 用户 Mapper
 */
@Mapper
public interface UserMapper {

    /**
     * 根据ID查询用户
     */
    @Select("SELECT id, username, password, create_time FROM sys_user WHERE id = #{id} AND is_deleted = 0")
    Optional<User> findById(@Param("id") Long id);

    /**
     * 根据用户名查询用户
     */
    @Select("SELECT id, username, password, create_time FROM sys_user WHERE username = #{username} AND is_deleted = 0")
    Optional<User> findByUsername(@Param("username") String username);

    /**
     * 插入用户
     */
    @Insert("INSERT INTO sys_user (username, password, create_time, is_deleted) VALUES (#{username}, #{password}, #{createTime}, 0)")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(User user);

    /**
     * 查询所有用户
     */
    @Select("SELECT id, username, password, create_time FROM sys_user WHERE is_deleted = 0 ORDER BY id")
    java.util.List<User> findAll();

    /**
     * 软删除用户
     */
    @Update("UPDATE sys_user SET is_deleted = 1 WHERE id = #{id}")
    int softDelete(@Param("id") Long id);
}
