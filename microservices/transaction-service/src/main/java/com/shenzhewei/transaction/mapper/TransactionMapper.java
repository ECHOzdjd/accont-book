package com.shenzhewei.transaction.mapper;

import com.shenzhewei.transaction.entity.Transaction;
import org.apache.ibatis.annotations.*;

import java.util.List;
import java.util.Optional;

/**
 * 流水 Mapper
 */
@Mapper
public interface TransactionMapper {

    /**
     * 根据ID查询流水
     */
    @Select("SELECT id, user_id, asset_id, amount, type, category, trans_time FROM tb_transaction WHERE id = #{id} AND is_deleted = 0")
    Optional<Transaction> findById(@Param("id") Long id);

    /**
     * 根据用户ID查询流水列表
     */
    @Select("SELECT id, user_id, asset_id, amount, type, category, trans_time FROM tb_transaction WHERE user_id = #{userId} AND is_deleted = 0 ORDER BY trans_time DESC")
    List<Transaction> findByUserId(@Param("userId") Long userId);

    /**
     * 根据资产ID查询流水列表
     */
    @Select("SELECT id, user_id, asset_id, amount, type, category, trans_time FROM tb_transaction WHERE asset_id = #{assetId} AND is_deleted = 0 ORDER BY trans_time DESC")
    List<Transaction> findByAssetId(@Param("assetId") Long assetId);

    /**
     * 插入流水记录
     */
    @Insert("INSERT INTO tb_transaction (user_id, asset_id, amount, type, category, trans_time, is_deleted) VALUES (#{userId}, #{assetId}, #{amount}, #{type}, #{category}, #{transTime}, 0)")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(Transaction transaction);

    /**
     * 软删除流水记录
     */
    @Update("UPDATE tb_transaction SET is_deleted = 1 WHERE id = #{id}")
    int deleteById(@Param("id") Long id);

    /**
     * 统计资产下的流水数量
     */
    @Select("SELECT COUNT(*) FROM tb_transaction WHERE asset_id = #{assetId} AND is_deleted = 0")
    int countByAssetId(@Param("assetId") Long assetId);
}
