package com.shenzhewei.asset.mapper;

import com.shenzhewei.asset.entity.Asset;
import org.apache.ibatis.annotations.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

/**
 * 资产 Mapper
 */
@Mapper
public interface AssetMapper {

    /**
     * 根据ID查询资产
     */
    @Select("SELECT id, user_id, name, balance, version, create_time FROM tb_asset WHERE id = #{id}")
    Optional<Asset> findById(@Param("id") Long id);

    /**
     * 根据用户ID查询资产列表
     */
    @Select("SELECT id, user_id, name, balance, version, create_time FROM tb_asset WHERE user_id = #{userId}")
    List<Asset> findByUserId(@Param("userId") Long userId);

    /**
     * 插入资产
     */
    @Insert("INSERT INTO tb_asset (user_id, name, balance, version, create_time) VALUES (#{userId}, #{name}, #{balance}, #{version}, #{createTime})")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(Asset asset);

    /**
     * 使用乐观锁更新余额
     * 
     * @param id      资产ID
     * @param amount  变动金额（正数增加，负数减少）
     * @param version 当前版本号
     * @return 更新的行数（0表示乐观锁冲突）
     */
    @Update("UPDATE tb_asset SET balance = balance + #{amount}, version = version + 1 WHERE id = #{id} AND version = #{version}")
    int updateBalanceWithOptimisticLock(@Param("id") Long id, @Param("amount") BigDecimal amount, @Param("version") Integer version);

    /**
     * 更新资产名称
     */
    @Update("UPDATE tb_asset SET name = #{name} WHERE id = #{id}")
    int updateName(@Param("id") Long id, @Param("name") String name);

    /**
     * 删除资产
     */
    @Delete("DELETE FROM tb_asset WHERE id = #{id}")
    int deleteById(@Param("id") Long id);
}
